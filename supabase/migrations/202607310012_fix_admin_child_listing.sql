-- Keep admin child selectors consistent with the security-definer dashboard RPC.
-- Direct profile reads can be restricted by shared-device RLS state and must not
-- silently make existing children disappear from mission/reward assignment.
create or replace function public.list_child_profiles_admin()
returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare f uuid;
begin
  select fm.family_id into f
  from public.family_members fm
  where fm.user_id=auth.uid() and fm.role='admin';

  if f is null or not public.is_family_admin(f) then
    raise exception 'admin required';
  end if;

  return query
  select to_jsonb(p)
  from public.profiles p
  where p.family_id=f and p.role='child'
  order by p.created_at;
end $$;

revoke all on function public.list_child_profiles_admin() from public;
grant execute on function public.list_child_profiles_admin() to authenticated;

