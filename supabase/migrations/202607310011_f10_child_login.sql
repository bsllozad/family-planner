-- F10: secure, single-use invitations that bind an Auth user to a child profile.
create table public.child_login_invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  email text not null,
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (email = lower(trim(email)))
);

create index child_login_invitations_profile_idx
  on public.child_login_invitations(profile_id, created_at desc);

alter table public.child_login_invitations enable row level security;
create policy "admins read child login invitations"
  on public.child_login_invitations for select to authenticated
  using (public.is_family_admin(family_id));

create or replace function public.create_child_login_invitation(p_profile_id uuid,p_email text)
returns text language plpgsql security definer set search_path='' as $$
declare v_family uuid; v_token text; v_email text:=lower(trim(p_email));
begin
  select p.family_id into v_family from public.profiles p
  where p.id=p_profile_id and p.role='child' and p.archived_at is null;
  if v_family is null or not public.is_family_admin(v_family) then raise exception 'admin required'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid email'; end if;
  if exists(select 1 from public.family_members m where m.profile_id=p_profile_id) then raise exception 'profile already has login'; end if;
  if exists(select 1 from auth.users u join public.family_members m on m.user_id=u.id where lower(u.email)=v_email) then raise exception 'email already belongs to a family'; end if;
  update public.child_login_invitations set expires_at=now()
    where profile_id=p_profile_id and accepted_at is null and expires_at>now();
  v_token:=encode(gen_random_bytes(32),'hex');
  insert into public.child_login_invitations(family_id,profile_id,email,token_hash,invited_by)
  values(v_family,p_profile_id,v_email,encode(public.digest(v_token,'sha256'),'hex'),auth.uid());
  return v_token;
end $$;

create or replace function public.accept_child_login_invitation(p_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_inv public.child_login_invitations%rowtype; v_email text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select lower(email) into v_email from auth.users where id=auth.uid();
  select * into v_inv from public.child_login_invitations
    where token_hash=encode(public.digest(p_token,'sha256'),'hex') for update;
  if v_inv.id is null or v_inv.accepted_at is not null or v_inv.expires_at<=now() or v_inv.email<>v_email then
    raise exception 'invalid invitation';
  end if;
  if exists(select 1 from public.family_members where user_id=auth.uid()) then raise exception 'already belongs to a family'; end if;
  if exists(select 1 from public.family_members where profile_id=v_inv.profile_id) then raise exception 'profile already has login'; end if;
  insert into public.family_members(family_id,user_id,profile_id,role)
    values(v_inv.family_id,auth.uid(),v_inv.profile_id,'child');
  -- Existing child RPCs resolve the active profile through this server-side state.
  insert into public.shared_device_states(user_id,family_id,active_child_profile_id)
    values(auth.uid(),v_inv.family_id,v_inv.profile_id);
  update public.child_login_invitations set accepted_at=now(),accepted_by=auth.uid() where id=v_inv.id;
  return v_inv.profile_id;
end $$;

drop function if exists public.get_my_family_context();
create function public.get_my_family_context()
returns table(
  family_id uuid, family_name text, timezone text, role public.family_role,
  profile_id uuid, profile_name text, language text, access_mode text
)
language sql stable security definer set search_path='' as $$
  select f.id,f.name,f.timezone,
    case when s.active_child_profile_id is not null then 'child'::public.family_role else m.role end,
    coalesce(s.active_child_profile_id,p.id),coalesce(cp.display_name,p.display_name),
    coalesce(cp.language,p.language,'es'),
    case when m.role='child' then 'direct_child'
         when s.active_child_profile_id is not null then 'shared_child'
         else 'admin' end
  from public.family_members m join public.families f on f.id=m.family_id
  left join public.profiles p on p.id=m.profile_id
  left join public.shared_device_states s on s.user_id=m.user_id
  left join public.profiles cp on cp.id=s.active_child_profile_id
  where m.user_id=auth.uid()
$$;

revoke all on public.child_login_invitations from anon,authenticated;
grant select on public.child_login_invitations to authenticated;
revoke all on function public.create_child_login_invitation(uuid,text),public.accept_child_login_invitation(text),public.get_my_family_context() from public;
grant execute on function public.create_child_login_invitation(uuid,text),public.accept_child_login_invitation(text),public.get_my_family_context() to authenticated;

