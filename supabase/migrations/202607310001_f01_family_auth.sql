-- F01: family accounts, roles, profiles and single-use invitations.
create extension if not exists pgcrypto;

create type public.family_role as enum ('admin', 'child');
create type public.profile_role as enum ('adult', 'child');

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  timezone text not null default 'UTC',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 80),
  role public.profile_role not null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, family_id)
);

create table public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid,
  role public.family_role not null,
  created_at timestamptz not null default now(),
  primary key (family_id, user_id),
  unique (user_id),
  foreign key (profile_id, family_id) references public.profiles(id, family_id) on delete restrict
);

create table public.family_invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  email text not null,
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (email = lower(trim(email)))
);

create index family_members_user_idx on public.family_members(user_id);
create index family_invitations_family_idx on public.family_invitations(family_id);

alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invitations enable row level security;

-- SECURITY DEFINER avoids recursive family_members RLS checks. This function
-- exposes only a boolean and cannot be used to enumerate memberships.
create or replace function public.is_family_member(p_family_id uuid)
returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from public.family_members m where m.family_id=p_family_id and m.user_id=auth.uid())
$$;
create or replace function public.is_family_admin(p_family_id uuid)
returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from public.family_members m where m.family_id=p_family_id and m.user_id=auth.uid() and m.role='admin')
$$;
revoke all on function public.is_family_member(uuid) from public;
revoke all on function public.is_family_admin(uuid) from public;
grant execute on function public.is_family_member(uuid), public.is_family_admin(uuid) to authenticated;

create policy "members read own family" on public.families for select to authenticated using (public.is_family_member(id));
create policy "members read family profiles" on public.profiles for select to authenticated using (public.is_family_member(family_id));
create policy "admins manage family profiles" on public.profiles for all to authenticated using (public.is_family_admin(family_id)) with check (public.is_family_admin(family_id));
create policy "members read own membership" on public.family_members for select to authenticated using (user_id=auth.uid());
create policy "admins read family memberships" on public.family_members for select to authenticated using (public.is_family_admin(family_id));
create policy "admins read invitations" on public.family_invitations for select to authenticated using (public.is_family_admin(family_id));

-- The only creation route creates the family, adult profile and membership atomically.
create or replace function public.create_family(p_family_name text,p_display_name text,p_timezone text default 'UTC')
returns uuid language plpgsql security definer set search_path='' as $$
declare v_family uuid; v_profile uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if exists(select 1 from public.family_members where user_id=auth.uid()) then raise exception 'already belongs to a family'; end if;
  if char_length(trim(p_family_name)) not between 2 and 80 or char_length(trim(p_display_name)) not between 2 and 80 then raise exception 'invalid input'; end if;
  insert into public.families(name,timezone) values(trim(p_family_name),coalesce(nullif(trim(p_timezone),''),'UTC')) returning id into v_family;
  insert into public.profiles(family_id,display_name,role) values(v_family,trim(p_display_name),'adult') returning id into v_profile;
  insert into public.family_members(family_id,user_id,profile_id,role) values(v_family,auth.uid(),v_profile,'admin');
  return v_family;
end $$;

create or replace function public.get_my_family_context()
returns table(family_id uuid,family_name text,timezone text,role public.family_role,profile_id uuid,profile_name text)
language sql stable security definer set search_path='' as $$
  select f.id,f.name,f.timezone,m.role,p.id,p.display_name
  from public.family_members m join public.families f on f.id=m.family_id
  left join public.profiles p on p.id=m.profile_id
  where m.user_id=auth.uid()
$$;

-- Returns the raw token exactly once. Only its SHA-256 digest is persisted.
create or replace function public.create_family_invitation(p_email text)
returns text language plpgsql security definer set search_path='' as $$
declare v_family uuid; v_token text; v_email text:=lower(trim(p_email));
begin
  select family_id into v_family from public.family_members where user_id=auth.uid() and role='admin';
  if v_family is null then raise exception 'admin required'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid email'; end if;
  if exists(select 1 from auth.users u join public.family_members m on m.user_id=u.id where lower(u.email)=v_email) then raise exception 'email already belongs to a family'; end if;
  update public.family_invitations set expires_at=now() where family_id=v_family and email=v_email and accepted_at is null and expires_at>now();
  v_token:=encode(gen_random_bytes(32),'hex');
  insert into public.family_invitations(family_id,email,token_hash,invited_by) values(v_family,v_email,encode(digest(v_token,'sha256'),'hex'),auth.uid());
  return v_token;
end $$;

create or replace function public.accept_family_invitation(p_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_inv public.family_invitations%rowtype; v_email text; v_profile uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select lower(email) into v_email from auth.users where id=auth.uid();
  select * into v_inv from public.family_invitations where token_hash=encode(digest(p_token,'sha256'),'hex') for update;
  if v_inv.id is null or v_inv.accepted_at is not null or v_inv.expires_at<=now() or v_inv.email<>v_email then raise exception 'invalid invitation'; end if;
  if exists(select 1 from public.family_members where user_id=auth.uid()) then raise exception 'already belongs to a family'; end if;
  insert into public.profiles(family_id,display_name,role) values(v_inv.family_id,coalesce(nullif(split_part(v_email,'@',1),''),'Adulto'),'adult') returning id into v_profile;
  insert into public.family_members(family_id,user_id,profile_id,role) values(v_inv.family_id,auth.uid(),v_profile,'admin');
  update public.family_invitations set accepted_at=now(),accepted_by=auth.uid() where id=v_inv.id;
  return v_inv.family_id;
end $$;

revoke all on function public.create_family(text,text,text),public.get_my_family_context(),public.create_family_invitation(text),public.accept_family_invitation(text) from public;
grant execute on function public.create_family(text,text,text),public.get_my_family_context(),public.create_family_invitation(text),public.accept_family_invitation(text) to authenticated;
revoke all on public.families,public.profiles,public.family_members,public.family_invitations from anon;
grant select on public.families,public.profiles,public.family_members,public.family_invitations to authenticated;
grant insert,update,delete on public.profiles to authenticated;

comment on table public.family_members is 'One authenticated user belongs to exactly one family in the MVP.';
comment on function public.accept_family_invitation(text) is 'Atomically accepts a single-use invitation only when the authenticated email matches.';
