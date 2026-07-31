-- F03: mission templates, recurrence, immutable instance snapshots and audited corrections.
alter table public.families add column mission_xp_min integer not null default 1 check (mission_xp_min > 0),
  add column mission_xp_max integer not null default 1000 check (mission_xp_max >= mission_xp_min);

create type public.mission_recurrence as enum ('once','daily','weekly');
create type public.mission_status as enum ('pending','completed');
create type public.xp_transaction_kind as enum ('completion','reversal','penalty','excuse');

create table public.mission_templates (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  title_es text not null check (char_length(trim(title_es)) between 2 and 100), title_en text not null check (char_length(trim(title_en)) between 2 and 100),
  description_es text check (char_length(description_es)<=500), description_en text check (char_length(description_en)<=500),
  icon text not null check (char_length(trim(icon)) between 1 and 20), category text not null check (char_length(trim(category)) between 1 and 50),
  xp_value integer not null check (xp_value>0), is_required boolean not null default true,
  recurrence public.mission_recurrence not null, weekly_days smallint[] not null default '{}', weekly_flexible boolean not null default false,
  starts_on date not null, archived_at timestamptz, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,family_id), check (recurrence='weekly' or (cardinality(weekly_days)=0 and not weekly_flexible)),
  check (recurrence<>'weekly' or weekly_flexible or cardinality(weekly_days)>0), check (not weekly_flexible or cardinality(weekly_days)=0),
  check (weekly_days <@ array[0,1,2,3,4,5,6]::smallint[])
);
create table public.mission_assignees (
  mission_template_id uuid not null, family_id uuid not null, profile_id uuid not null,
  primary key(mission_template_id,profile_id), foreign key(mission_template_id,family_id) references public.mission_templates(id,family_id) on delete cascade,
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create table public.mission_instances (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  mission_template_id uuid not null, profile_id uuid not null, scheduled_for date not null, due_at timestamptz not null,
  status public.mission_status not null default 'pending', xp_value integer not null check(xp_value>0), xp_awarded integer not null default 0 check(xp_awarded>=0),
  is_required boolean not null, is_excused boolean not null default false, completed_at timestamptz, reviewed_at timestamptz, reviewed_by uuid references auth.users(id), created_at timestamptz not null default now(),
  foreign key(mission_template_id,family_id) references public.mission_templates(id,family_id) on delete restrict,
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict,
  unique(mission_template_id,profile_id,scheduled_for), check(not is_excused or status='pending')
);
create table public.xp_transactions (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null, mission_instance_id uuid not null references public.mission_instances(id) on delete restrict,
  kind public.xp_transaction_kind not null, amount integer not null, reason text, created_by uuid references auth.users(id), created_at timestamptz not null default now(),
  foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete restrict
);
create index mission_instances_family_date on public.mission_instances(family_id,scheduled_for desc);

alter table public.mission_templates enable row level security; alter table public.mission_assignees enable row level security;
alter table public.mission_instances enable row level security; alter table public.xp_transactions enable row level security;
create policy "admins read templates" on public.mission_templates for select to authenticated using(public.is_family_admin(family_id));
create policy "admins read assignees" on public.mission_assignees for select to authenticated using(public.is_family_admin(family_id));
create policy "family reads permitted instances" on public.mission_instances for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select s.active_child_profile_id from public.shared_device_states s where s.user_id=auth.uid()));
create policy "family reads permitted xp" on public.xp_transactions for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select s.active_child_profile_id from public.shared_device_states s where s.user_id=auth.uid()));

create or replace function public.generate_mission_instances(p_template_id uuid,p_through date default current_date+interval '56 days') returns void
language plpgsql security definer set search_path='' as $$
declare t public.mission_templates%rowtype; d date; a record; family_tz text;
begin
  select * into t from public.mission_templates where id=p_template_id; if t.id is null or t.archived_at is not null then return; end if;
  select timezone into family_tz from public.families where id=t.family_id;
  for a in select profile_id from public.mission_assignees where mission_template_id=t.id loop
    d:=t.starts_on;
    while d<=p_through loop
      if (t.recurrence='once' and d=t.starts_on) or t.recurrence='daily' or (t.recurrence='weekly' and ((t.weekly_flexible and extract(dow from d)=1) or extract(dow from d)::smallint=any(t.weekly_days))) then
        insert into public.mission_instances(family_id,mission_template_id,profile_id,scheduled_for,due_at,xp_value,is_required)
        values(t.family_id,t.id,a.profile_id,d,case when t.recurrence='weekly' and t.weekly_flexible then ((d+6)::timestamp+time '23:59:59') at time zone family_tz else (d::timestamp+time '23:59:59') at time zone family_tz end,t.xp_value,t.is_required)
        on conflict(mission_template_id,profile_id,scheduled_for) do nothing;
      end if;
      exit when t.recurrence='once'; d:=d+1;
    end loop;
  end loop;
end $$;

create or replace function public.create_mission_template(p_title_es text,p_title_en text,p_description_es text,p_description_en text,p_icon text,p_category text,p_xp_value integer,p_is_required boolean,p_recurrence public.mission_recurrence,p_weekly_days smallint[],p_weekly_flexible boolean,p_starts_on date,p_assignee_ids uuid[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare f uuid; id uuid; child uuid; lo integer; hi integer;
begin
  select family_id into f from public.family_members where user_id=auth.uid() and role='admin'; if f is null or not public.is_family_admin(f) then raise exception 'admin required'; end if;
  select mission_xp_min,mission_xp_max into lo,hi from public.families where families.id=f; if p_xp_value not between lo and hi then raise exception 'xp outside family limits'; end if;
  if cardinality(p_assignee_ids)=0 then raise exception 'assignee required'; end if;
  insert into public.mission_templates(family_id,title_es,title_en,description_es,description_en,icon,category,xp_value,is_required,recurrence,weekly_days,weekly_flexible,starts_on,created_by)
  values(f,trim(p_title_es),trim(p_title_en),nullif(trim(p_description_es),''),nullif(trim(p_description_en),''),trim(p_icon),trim(p_category),p_xp_value,p_is_required,p_recurrence,coalesce(p_weekly_days,'{}'),p_weekly_flexible,p_starts_on,auth.uid()) returning mission_templates.id into id;
  foreach child in array p_assignee_ids loop if not exists(select 1 from public.profiles where profiles.id=child and family_id=f and role='child' and archived_at is null) then raise exception 'invalid assignee'; end if; insert into public.mission_assignees values(id,f,child); end loop;
  perform public.generate_mission_instances(id); return id;
end $$;

create or replace function public.update_mission_template(p_template_id uuid,p_title_es text,p_title_en text,p_description_es text,p_description_en text,p_icon text,p_category text,p_xp_value integer,p_is_required boolean,p_recurrence public.mission_recurrence,p_weekly_days smallint[],p_weekly_flexible boolean,p_starts_on date,p_assignee_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare f uuid; child uuid; lo integer; hi integer;
begin
  select family_id into f from public.mission_templates where id=p_template_id; if f is null or not public.is_family_admin(f) then raise exception 'admin required'; end if;
  select mission_xp_min,mission_xp_max into lo,hi from public.families where id=f; if p_xp_value not between lo and hi then raise exception 'xp outside family limits'; end if;
  update public.mission_templates set title_es=trim(p_title_es),title_en=trim(p_title_en),description_es=nullif(trim(p_description_es),''),description_en=nullif(trim(p_description_en),''),icon=trim(p_icon),category=trim(p_category),xp_value=p_xp_value,is_required=p_is_required,recurrence=p_recurrence,weekly_days=coalesce(p_weekly_days,'{}'),weekly_flexible=p_weekly_flexible,starts_on=p_starts_on,updated_at=now() where id=p_template_id and archived_at is null;
  delete from public.mission_instances where mission_template_id=p_template_id and status='pending' and not is_excused and scheduled_for>=current_date;
  delete from public.mission_assignees where mission_template_id=p_template_id;
  foreach child in array p_assignee_ids loop if not exists(select 1 from public.profiles where id=child and family_id=f and role='child' and archived_at is null) then raise exception 'invalid assignee'; end if; insert into public.mission_assignees values(p_template_id,f,child); end loop;
  perform public.generate_mission_instances(p_template_id);
end $$;

create or replace function public.archive_mission_template(p_template_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare f uuid; begin select family_id into f from public.mission_templates where id=p_template_id; if not public.is_family_admin(f) then raise exception 'admin required'; end if; update public.mission_templates set archived_at=now(),updated_at=now() where id=p_template_id; delete from public.mission_instances where mission_template_id=p_template_id and scheduled_for>current_date and status='pending'; end $$;

create or replace function public.complete_mission_instance(p_instance_id uuid) returns integer language plpgsql security definer set search_path='' as $$
declare i public.mission_instances%rowtype; begin select * into i from public.mission_instances where id=p_instance_id for update; if i.id is null or i.is_excused or i.status<>'pending' or not (public.is_family_admin(i.family_id) or i.profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid())) then raise exception 'not permitted'; end if; update public.mission_instances set status='completed',completed_at=now(),xp_awarded=xp_value where id=i.id; insert into public.xp_transactions(family_id,profile_id,mission_instance_id,kind,amount,created_by) values(i.family_id,i.profile_id,i.id,'completion',i.xp_value,auth.uid()); return i.xp_value; end $$;
create or replace function public.revert_mission_completion(p_instance_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare i public.mission_instances%rowtype; begin select * into i from public.mission_instances where id=p_instance_id for update; if i.status<>'completed' or not public.is_family_admin(i.family_id) then raise exception 'admin completed instance required'; end if; insert into public.xp_transactions(family_id,profile_id,mission_instance_id,kind,amount,reason,created_by) values(i.family_id,i.profile_id,i.id,'reversal',-i.xp_awarded,p_reason,auth.uid()); update public.mission_instances set status='pending',completed_at=null,xp_awarded=0,reviewed_at=now(),reviewed_by=auth.uid() where id=i.id; end $$;
create or replace function public.excuse_mission_instance(p_instance_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare i public.mission_instances%rowtype; begin select * into i from public.mission_instances where id=p_instance_id and status='pending' for update; if i.id is null or not public.is_family_admin(i.family_id) then raise exception 'admin pending instance required'; end if; update public.mission_instances set is_excused=true,reviewed_at=now(),reviewed_by=auth.uid() where id=p_instance_id; insert into public.xp_transactions(family_id,profile_id,mission_instance_id,kind,amount,reason,created_by) values(i.family_id,i.profile_id,i.id,'excuse',0,p_reason,auth.uid()); end $$;

create or replace function public.list_mission_templates() returns setof jsonb language sql stable security definer set search_path='' as $$ select to_jsonb(t)||jsonb_build_object('assignee_ids',coalesce((select jsonb_agg(a.profile_id) from public.mission_assignees a where a.mission_template_id=t.id),'[]'::jsonb)) from public.mission_templates t where public.is_family_admin(t.family_id) order by t.created_at desc $$;
create or replace function public.list_mission_instances(p_limit integer default 20) returns setof jsonb language sql stable security definer set search_path='' as $$ select to_jsonb(i)||jsonb_build_object('profile_name',p.display_name,'title_es',t.title_es) from public.mission_instances i join public.profiles p on p.id=i.profile_id join public.mission_templates t on t.id=i.mission_template_id where public.is_family_admin(i.family_id) order by i.scheduled_for desc limit least(greatest(p_limit,1),100) $$;

revoke all on public.mission_templates,public.mission_assignees,public.mission_instances,public.xp_transactions from anon,authenticated;
grant select on public.mission_templates,public.mission_assignees,public.mission_instances,public.xp_transactions to authenticated;
revoke all on function public.generate_mission_instances(uuid,date) from public;
revoke all on function public.create_mission_template(text,text,text,text,text,text,integer,boolean,public.mission_recurrence,smallint[],boolean,date,uuid[]),public.update_mission_template(uuid,text,text,text,text,text,text,integer,boolean,public.mission_recurrence,smallint[],boolean,date,uuid[]),public.archive_mission_template(uuid),public.complete_mission_instance(uuid),public.revert_mission_completion(uuid,text),public.excuse_mission_instance(uuid,text),public.list_mission_templates(),public.list_mission_instances(integer) from public;
grant execute on function public.create_mission_template(text,text,text,text,text,text,integer,boolean,public.mission_recurrence,smallint[],boolean,date,uuid[]),public.update_mission_template(uuid,text,text,text,text,text,text,integer,boolean,public.mission_recurrence,smallint[],boolean,date,uuid[]),public.archive_mission_template(uuid),public.complete_mission_instance(uuid),public.revert_mission_completion(uuid,text),public.excuse_mission_instance(uuid,text),public.list_mission_templates(),public.list_mission_instances(integer) to authenticated;
