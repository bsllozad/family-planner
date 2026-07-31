-- F06: reward catalogue, atomic XP reservations and Friday cash redemptions.
-- Converting the closed enum avoids PostgreSQL's "new enum value" transaction
-- restriction while keeping an explicit, extensible ledger-kind constraint.
alter table public.xp_transactions alter column kind type text using kind::text,
  alter column mission_instance_id drop not null;
alter table public.xp_transactions add constraint xp_transaction_kind_allowed check(kind in (
  'completion','reversal','penalty','excuse','reward_spend','reward_refund','cash_spend','cash_refund'
));

create type public.redemption_status as enum ('requested','approved','fulfilled','rejected','cancelled');

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title_es text not null check(char_length(trim(title_es)) between 2 and 100),
  title_en text not null check(char_length(trim(title_en)) between 2 and 100),
  description_es text check(char_length(description_es)<=500),
  description_en text check(char_length(description_en)<=500),
  icon text not null check(char_length(trim(icon)) between 1 and 20),
  xp_cost integer not null check(xp_cost>0),
  is_available boolean not null default true,
  archived_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,family_id)
);
create table public.reward_assignees (
  reward_id uuid not null, family_id uuid not null, profile_id uuid not null,
  primary key(reward_id,profile_id),
  foreign key(reward_id,family_id) references public.rewards(id,family_id) on delete cascade,
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create table public.reward_redemptions (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  reward_id uuid not null, profile_id uuid not null, title text not null, icon text not null, xp_cost integer not null check(xp_cost>0),
  status public.redemption_status not null default 'requested', requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), handled_by uuid references auth.users(id), fulfilled_at timestamptz,
  foreign key(reward_id,family_id) references public.rewards(id,family_id) on delete restrict,
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create table public.cash_redemptions (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null, xp_amount integer not null check(xp_amount between 175 and 700 and xp_amount%35=0),
  cad_amount numeric(6,2) not null check(cad_amount=xp_amount/35.0), rate_xp_per_cad integer not null default 35 check(rate_xp_per_cad=35),
  week_start date not null, status public.redemption_status not null default 'requested', requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), handled_by uuid references auth.users(id), paid_at timestamptz,
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create unique index cash_one_active_week on public.cash_redemptions(profile_id,week_start)
  where status in ('requested','approved','fulfilled');
create index reward_redemptions_family_created on public.reward_redemptions(family_id,requested_at desc);
create index cash_redemptions_family_created on public.cash_redemptions(family_id,requested_at desc);

alter table public.xp_transactions add column reward_redemption_id uuid references public.reward_redemptions(id) on delete restrict,
  add column cash_redemption_id uuid references public.cash_redemptions(id) on delete restrict,
  add constraint xp_transaction_source check (
    (mission_instance_id is not null)::integer+(reward_redemption_id is not null)::integer+(cash_redemption_id is not null)::integer=1
  );
create unique index xp_one_reward_spend on public.xp_transactions(reward_redemption_id) where kind='reward_spend';
create unique index xp_one_reward_refund on public.xp_transactions(reward_redemption_id) where kind='reward_refund';
create unique index xp_one_cash_spend on public.xp_transactions(cash_redemption_id) where kind='cash_spend';
create unique index xp_one_cash_refund on public.xp_transactions(cash_redemption_id) where kind='cash_refund';

alter table public.rewards enable row level security; alter table public.reward_assignees enable row level security;
alter table public.reward_redemptions enable row level security; alter table public.cash_redemptions enable row level security;
create policy "admins read rewards" on public.rewards for select to authenticated using(public.is_family_admin(family_id));
create policy "admins read reward assignees" on public.reward_assignees for select to authenticated using(public.is_family_admin(family_id));
create policy "family reads reward redemptions" on public.reward_redemptions for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));
create policy "family reads cash redemptions" on public.cash_redemptions for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));

create or replace function public.save_reward(p_reward_id uuid,p_title_es text,p_title_en text,p_description_es text,p_description_en text,p_icon text,p_xp_cost integer,p_is_available boolean,p_assignee_ids uuid[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare f uuid; result uuid; child uuid;
begin
  select family_id into f from public.family_members where user_id=auth.uid() and role='admin';
  if f is null or not public.is_family_admin(f) then raise exception 'admin required'; end if;
  if p_xp_cost<=0 then raise exception 'invalid cost'; end if;
  if p_reward_id is null then
    insert into public.rewards(family_id,title_es,title_en,description_es,description_en,icon,xp_cost,is_available,created_by)
    values(f,trim(p_title_es),trim(p_title_en),nullif(trim(p_description_es),''),nullif(trim(p_description_en),''),trim(p_icon),p_xp_cost,p_is_available,auth.uid()) returning id into result;
  else
    update public.rewards set title_es=trim(p_title_es),title_en=trim(p_title_en),description_es=nullif(trim(p_description_es),''),description_en=nullif(trim(p_description_en),''),icon=trim(p_icon),xp_cost=p_xp_cost,is_available=p_is_available,updated_at=now()
    where id=p_reward_id and family_id=f and archived_at is null returning id into result;
    if result is null then raise exception 'reward not found'; end if;
    delete from public.reward_assignees where reward_id=result;
  end if;
  foreach child in array coalesce(p_assignee_ids,'{}') loop
    if not exists(select 1 from public.profiles where id=child and family_id=f and role='child' and archived_at is null) then raise exception 'invalid assignee'; end if;
    insert into public.reward_assignees values(result,f,child);
  end loop;
  return result;
end $$;
create or replace function public.archive_reward(p_reward_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare f uuid; begin select family_id into f from public.rewards where id=p_reward_id; if not public.is_family_admin(f) then raise exception 'admin required'; end if; update public.rewards set archived_at=now(),is_available=false,updated_at=now() where id=p_reward_id; end $$;

create or replace function public.list_rewards_admin() returns setof jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(r)||jsonb_build_object('assignee_ids',coalesce((select jsonb_agg(a.profile_id) from public.reward_assignees a where a.reward_id=r.id),'[]'::jsonb)) from public.rewards r where public.is_family_admin(r.family_id) order by r.created_at desc
$$;
create or replace function public.list_redemptions_admin() returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',x.id,'kind',x.kind,'profile_name',p.display_name,'title',x.title,'icon',x.icon,'xp_amount',x.xp_amount,'cad_amount',x.cad_amount,'status',x.status,'requested_at',x.requested_at)
  from (
    select rr.id,'reward'::text kind,rr.profile_id,rr.title,rr.icon,rr.xp_cost xp_amount,null::numeric cad_amount,rr.status,rr.requested_at,rr.family_id from public.reward_redemptions rr
    union all select cr.id,'cash',cr.profile_id,'Canje en efectivo','💵',cr.xp_amount,cr.cad_amount,cr.status,cr.requested_at,cr.family_id from public.cash_redemptions cr
  ) x join public.profiles p on p.id=x.profile_id where public.is_family_admin(x.family_id) order by x.requested_at desc
$$;

create or replace function public.get_child_rewards() returns setof jsonb language plpgsql security definer set search_path='' as $$
declare child_id uuid; f uuid; lang text; tz text; available integer; today date; result jsonb;
begin
  select s.active_child_profile_id,s.family_id,p.language,fam.timezone into child_id,f,lang,tz from public.shared_device_states s join public.profiles p on p.id=s.active_child_profile_id join public.families fam on fam.id=s.family_id where s.user_id=auth.uid();
  if child_id is null then raise exception 'child mode required'; end if;
  today:=(now() at time zone tz)::date;
  select greatest(coalesce(sum(amount),0),0)::integer into available from public.xp_transactions where profile_id=child_id;
  select jsonb_build_object('available_xp',available,'cash_available',extract(isodow from today)=5,
    'rewards',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',case when lang='en' then r.title_en else r.title_es end,'description',case when lang='en' then r.description_en else r.description_es end,'icon',r.icon,'xp_cost',r.xp_cost) order by r.xp_cost) from public.rewards r where r.family_id=f and r.archived_at is null and r.is_available and (not exists(select 1 from public.reward_assignees a where a.reward_id=r.id) or exists(select 1 from public.reward_assignees a where a.reward_id=r.id and a.profile_id=child_id))),'[]'::jsonb),
    'redemptions',coalesce((select jsonb_agg(q order by q.requested_at desc) from (select id,'reward' kind,title,icon,xp_cost xp_amount,null::numeric cad_amount,status,requested_at from public.reward_redemptions where profile_id=child_id union all select id,'cash','Canje en efectivo','💵',xp_amount,cad_amount,status,requested_at from public.cash_redemptions where profile_id=child_id) q),'[]'::jsonb)
  ) into result; return next result;
end $$;

create or replace function public.request_reward(p_reward_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare child_id uuid; r public.rewards%rowtype; available integer; redemption uuid;
begin
  select active_child_profile_id into child_id from public.shared_device_states where user_id=auth.uid(); if child_id is null then raise exception 'child mode required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(child_id::text,0));
  select * into r from public.rewards where id=p_reward_id and archived_at is null and is_available for update;
  if r.id is null or r.family_id<>(select family_id from public.profiles where id=child_id) or (exists(select 1 from public.reward_assignees where reward_id=r.id) and not exists(select 1 from public.reward_assignees where reward_id=r.id and profile_id=child_id)) then raise exception 'reward unavailable'; end if;
  select coalesce(sum(amount),0)::integer into available from public.xp_transactions where profile_id=child_id; if available<r.xp_cost then raise exception 'insufficient xp'; end if;
  insert into public.reward_redemptions(family_id,reward_id,profile_id,title,icon,xp_cost) values(r.family_id,r.id,child_id,case when (select language from public.profiles where id=child_id)='en' then r.title_en else r.title_es end,r.icon,r.xp_cost) returning id into redemption;
  insert into public.xp_transactions(family_id,profile_id,reward_redemption_id,kind,amount,created_by) values(r.family_id,child_id,redemption,'reward_spend',-r.xp_cost,auth.uid()); return redemption;
end $$;

create or replace function public.request_cash_redemption(p_xp_amount integer) returns uuid language plpgsql security definer set search_path='' as $$
declare child_id uuid; f uuid; tz text; today date; week date; available integer; redemption uuid;
begin
  select s.active_child_profile_id,s.family_id,fam.timezone into child_id,f,tz from public.shared_device_states s join public.families fam on fam.id=s.family_id where s.user_id=auth.uid(); if child_id is null then raise exception 'child mode required'; end if;
  today:=(now() at time zone tz)::date; if extract(isodow from today)<>5 then raise exception 'cash redemption is Friday only'; end if;
  if p_xp_amount<175 or p_xp_amount>700 or p_xp_amount%35<>0 then raise exception 'invalid cash amount'; end if;
  week:=today-(extract(isodow from today)::integer-1); perform pg_advisory_xact_lock(hashtextextended(child_id::text,0));
  if exists(select 1 from public.cash_redemptions where profile_id=child_id and week_start=week and status in ('requested','approved','fulfilled')) then raise exception 'weekly limit reached'; end if;
  select coalesce(sum(amount),0)::integer into available from public.xp_transactions where profile_id=child_id; if available<p_xp_amount then raise exception 'insufficient xp'; end if;
  insert into public.cash_redemptions(family_id,profile_id,xp_amount,cad_amount,week_start) values(f,child_id,p_xp_amount,p_xp_amount/35.0,week) returning id into redemption;
  insert into public.xp_transactions(family_id,profile_id,cash_redemption_id,kind,amount,created_by) values(f,child_id,redemption,'cash_spend',-p_xp_amount,auth.uid()); return redemption;
end $$;

create or replace function public.update_redemption_status(p_kind text,p_redemption_id uuid,p_status public.redemption_status) returns void language plpgsql security definer set search_path='' as $$
declare old_status public.redemption_status; f uuid; child uuid; xp integer;
begin
  if p_status not in ('approved','fulfilled','rejected','cancelled') then raise exception 'invalid status'; end if;
  if p_kind='reward' then select status,family_id,profile_id,xp_cost into old_status,f,child,xp from public.reward_redemptions where id=p_redemption_id for update;
  elsif p_kind='cash' then select status,family_id,profile_id,xp_amount into old_status,f,child,xp from public.cash_redemptions where id=p_redemption_id for update;
  else raise exception 'invalid kind'; end if;
  if f is null or not public.is_family_admin(f) then raise exception 'admin required'; end if;
  if not ((old_status='requested' and p_status in ('approved','rejected','cancelled')) or (old_status='approved' and p_status in ('fulfilled','cancelled'))) then raise exception 'invalid transition'; end if;
  if p_kind='reward' then update public.reward_redemptions set status=p_status,updated_at=now(),handled_by=auth.uid(),fulfilled_at=case when p_status='fulfilled' then now() else fulfilled_at end where id=p_redemption_id;
  else update public.cash_redemptions set status=p_status,updated_at=now(),handled_by=auth.uid(),paid_at=case when p_status='fulfilled' then now() else paid_at end where id=p_redemption_id; end if;
  if p_status in ('rejected','cancelled') then
    if p_kind='reward' then insert into public.xp_transactions(family_id,profile_id,reward_redemption_id,kind,amount,created_by) values(f,child,p_redemption_id,'reward_refund',xp,auth.uid());
    else insert into public.xp_transactions(family_id,profile_id,cash_redemption_id,kind,amount,created_by) values(f,child,p_redemption_id,'cash_refund',xp,auth.uid()); end if;
  end if;
end $$;

revoke all on public.rewards,public.reward_assignees,public.reward_redemptions,public.cash_redemptions from anon,authenticated;
grant select on public.rewards,public.reward_assignees,public.reward_redemptions,public.cash_redemptions to authenticated;
revoke all on function public.save_reward(uuid,text,text,text,text,text,integer,boolean,uuid[]),public.archive_reward(uuid),public.list_rewards_admin(),public.list_redemptions_admin(),public.get_child_rewards(),public.request_reward(uuid),public.request_cash_redemption(integer),public.update_redemption_status(text,uuid,public.redemption_status) from public;
grant execute on function public.save_reward(uuid,text,text,text,text,text,integer,boolean,uuid[]),public.archive_reward(uuid),public.list_rewards_admin(),public.list_redemptions_admin(),public.get_child_rewards(),public.request_reward(uuid),public.request_cash_redemption(integer),public.update_redemption_status(text,uuid,public.redemption_status) to authenticated;
