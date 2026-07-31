-- F09: one language preference per profile, exposed in the active context.
drop function if exists public.get_my_family_context();
create function public.get_my_family_context()
returns table(
  family_id uuid, family_name text, timezone text, role public.family_role,
  profile_id uuid, profile_name text, language text
)
language sql stable security definer set search_path='' as $$
  select f.id, f.name, f.timezone,
    case when s.active_child_profile_id is not null then 'child'::public.family_role else m.role end,
    coalesce(s.active_child_profile_id,p.id), coalesce(cp.display_name,p.display_name),
    coalesce(cp.language,p.language,'es')
  from public.family_members m
  join public.families f on f.id=m.family_id
  left join public.profiles p on p.id=m.profile_id
  left join public.shared_device_states s on s.user_id=m.user_id
  left join public.profiles cp on cp.id=s.active_child_profile_id
  where m.user_id=auth.uid()
$$;

create function public.set_my_language(p_language text)
returns void language plpgsql security definer set search_path='' as $$
declare v_profile uuid;
begin
  if p_language not in ('es','en') then raise exception 'invalid language'; end if;
  select coalesce(s.active_child_profile_id,m.profile_id) into v_profile
  from public.family_members m left join public.shared_device_states s on s.user_id=m.user_id
  where m.user_id=auth.uid();
  if v_profile is null then raise exception 'profile required'; end if;
  update public.profiles set language=p_language where id=v_profile;
end $$;

revoke all on function public.get_my_family_context(),public.set_my_language(text) from public;
grant execute on function public.get_my_family_context(),public.set_my_language(text) to authenticated;
