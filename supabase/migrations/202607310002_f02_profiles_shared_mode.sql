-- F02: child profiles and a server-enforced shared-device mode.
alter table public.profiles
  add column birth_date date,
  add column language text not null default 'es' check (language in ('es', 'en')),
  add column avatar_key text not null default 'sprout'
    check (avatar_key in ('sprout', 'rocket', 'star', 'fox', 'panda'));

create table public.shared_device_states (
  user_id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  active_child_profile_id uuid,
  adult_pin_hash text,
  failed_attempts smallint not null default 0 check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (active_child_profile_id, family_id)
    references public.profiles(id, family_id) on delete restrict
);

alter table public.shared_device_states enable row level security;
revoke all on public.shared_device_states from anon, authenticated;

-- A shared child mode removes the authenticated adult's administrative
-- capability at the policy layer, not merely in the React interface.
create or replace function public.is_family_admin(p_family_id uuid)
returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(
    select 1
    from public.family_members m
    where m.family_id=p_family_id and m.user_id=auth.uid() and m.role='admin'
      and not exists (
        select 1 from public.shared_device_states s
        where s.user_id=auth.uid() and s.active_child_profile_id is not null
      )
  )
$$;

drop policy "members read family profiles" on public.profiles;
create policy "members read permitted profiles" on public.profiles
for select to authenticated using (
  public.is_family_admin(family_id)
  or id=(select m.profile_id from public.family_members m where m.user_id=auth.uid())
  or id=(select s.active_child_profile_id from public.shared_device_states s where s.user_id=auth.uid())
);

create or replace function public.get_my_family_context()
returns table(
  family_id uuid, family_name text, timezone text, role public.family_role,
  profile_id uuid, profile_name text
)
language sql stable security definer set search_path='' as $$
  select f.id, f.name, f.timezone,
    case when s.active_child_profile_id is not null then 'child'::public.family_role else m.role end,
    coalesce(s.active_child_profile_id,p.id), coalesce(cp.display_name,p.display_name)
  from public.family_members m
  join public.families f on f.id=m.family_id
  left join public.profiles p on p.id=m.profile_id
  left join public.shared_device_states s on s.user_id=m.user_id
  left join public.profiles cp on cp.id=s.active_child_profile_id
  where m.user_id=auth.uid()
$$;

create or replace function public.set_adult_pin(p_pin text)
returns void language plpgsql security definer set search_path='' as $$
declare v_family uuid;
begin
  select family_id into v_family from public.family_members
    where user_id=auth.uid() and role='admin';
  if v_family is null or not public.is_family_admin(v_family) then
    raise exception 'admin required';
  end if;
  if p_pin !~ '^[0-9]{4,6}$' then raise exception 'invalid pin format'; end if;
  insert into public.shared_device_states(user_id,family_id,adult_pin_hash)
  values(auth.uid(),v_family,public.crypt(p_pin,public.gen_salt('bf',10)))
  on conflict(user_id) do update set
    adult_pin_hash=excluded.adult_pin_hash, failed_attempts=0,
    locked_until=null, updated_at=now();
end $$;

create or replace function public.activate_child_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_family uuid;
begin
  select family_id into v_family from public.family_members
    where user_id=auth.uid() and role='admin';
  if v_family is null or not public.is_family_admin(v_family) then
    raise exception 'admin required';
  end if;
  if not exists(select 1 from public.profiles where id=p_profile_id
    and family_id=v_family and role='child' and archived_at is null) then
    raise exception 'invalid profile';
  end if;
  if not exists(select 1 from public.shared_device_states
    where user_id=auth.uid() and adult_pin_hash is not null) then
    raise exception 'pin required';
  end if;
  update public.shared_device_states set active_child_profile_id=p_profile_id,
    failed_attempts=0, locked_until=null, updated_at=now()
    where user_id=auth.uid();
end $$;

create or replace function public.unlock_adult_mode(p_pin text)
returns table(success boolean, locked_until timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_state public.shared_device_states%rowtype;
begin
  select * into v_state from public.shared_device_states
    where user_id=auth.uid() for update;
  if v_state.user_id is null or v_state.active_child_profile_id is null then
    return query select false, null::timestamptz; return;
  end if;
  if v_state.locked_until is not null and v_state.locked_until>now() then
    return query select false, v_state.locked_until; return;
  end if;
  if v_state.adult_pin_hash=public.crypt(p_pin,v_state.adult_pin_hash) then
    update public.shared_device_states set active_child_profile_id=null,
      failed_attempts=0, locked_until=null, updated_at=now()
      where user_id=auth.uid();
    return query select true, null::timestamptz; return;
  end if;
  update public.shared_device_states set
    failed_attempts=least(failed_attempts+1,5),
    locked_until=case when failed_attempts+1>=5 then now()+interval '5 minutes' else null end,
    updated_at=now()
    where user_id=auth.uid()
    returning shared_device_states.locked_until into v_state.locked_until;
  return query select false, v_state.locked_until;
end $$;

revoke all on function public.set_adult_pin(text), public.activate_child_profile(uuid),
  public.unlock_adult_mode(text) from public;
grant execute on function public.set_adult_pin(text), public.activate_child_profile(uuid),
  public.unlock_adult_mode(text) to authenticated;

comment on table public.shared_device_states is
  'Server-side shared-device capability state. PIN values are persisted only as bcrypt hashes.';
