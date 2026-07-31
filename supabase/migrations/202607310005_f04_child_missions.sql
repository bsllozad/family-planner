-- F04: child mission feed, reduced late XP, idempotent completion and weekly penalties.
alter table public.mission_instances
  add column recurrence public.mission_recurrence,
  add column weekly_flexible boolean,
  add column penalty_xp integer not null default 0 check (penalty_xp >= 0),
  add column penalty_applied_at timestamptz;

update public.mission_instances i set
  recurrence=t.recurrence, weekly_flexible=t.weekly_flexible
from public.mission_templates t where t.id=i.mission_template_id;

alter table public.mission_instances
  alter column recurrence set not null,
  alter column weekly_flexible set not null;

create unique index xp_one_penalty_per_instance
  on public.xp_transactions(mission_instance_id) where kind='penalty';

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
        insert into public.mission_instances(family_id,mission_template_id,profile_id,scheduled_for,due_at,xp_value,is_required,recurrence,weekly_flexible)
        values(t.family_id,t.id,a.profile_id,d,case when t.recurrence='weekly' and t.weekly_flexible then ((d+6)::timestamp+time '23:59:59') at time zone family_tz else (d::timestamp+time '23:59:59') at time zone family_tz end,t.xp_value,t.is_required,t.recurrence,t.weekly_flexible)
        on conflict(mission_template_id,profile_id,scheduled_for) do nothing;
      end if;
      exit when t.recurrence='once'; d:=d+1;
    end loop;
  end loop;
end $$;

-- This catch-up function is intentionally called whenever the child feed is read.
-- The row lock and partial unique index make every weekly penalty exactly-once.
create or replace function public.apply_due_mission_penalties(p_profile_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare i public.mission_instances%rowtype; family_tz text; week_close timestamptz; balance integer; deduction integer;
begin
  for i in select mi.* from public.mission_instances mi join public.families f on f.id=mi.family_id
    where mi.profile_id=p_profile_id and mi.status='pending' and mi.is_required and not mi.is_excused
      and mi.penalty_applied_at is null
    order by mi.scheduled_for for update of mi
  loop
    select timezone into family_tz from public.families where id=i.family_id;
    week_close:=((i.scheduled_for+((7-extract(dow from i.scheduled_for)::integer)%7))::timestamp+time '23:59:59') at time zone family_tz;
    if now()>week_close then
      select greatest(coalesce(sum(x.amount),0),0)::integer into balance from public.xp_transactions x where x.profile_id=i.profile_id;
      deduction:=least(balance,greatest(1,round(i.xp_value*.25)::integer));
      insert into public.xp_transactions(family_id,profile_id,mission_instance_id,kind,amount,reason)
      values(i.family_id,i.profile_id,i.id,'penalty',-deduction,'Required mission pending at weekly close');
      update public.mission_instances set penalty_xp=deduction,penalty_applied_at=now() where id=i.id;
    end if;
  end loop;
end $$;

create or replace function public.complete_mission_instance(p_instance_id uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare i public.mission_instances%rowtype; family_tz text; local_today date; week_end date; award integer; permitted boolean;
begin
  select * into i from public.mission_instances where id=p_instance_id for update;
  permitted:=i.id is not null and (public.is_family_admin(i.family_id) or i.profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));
  if not permitted or i.is_excused then raise exception 'not permitted'; end if;
  if i.status='completed' then return i.xp_awarded; end if;
  perform public.apply_due_mission_penalties(i.profile_id);
  select timezone into family_tz from public.families where id=i.family_id;
  local_today:=(now() at time zone family_tz)::date;
  week_end:=i.scheduled_for+((7-extract(dow from i.scheduled_for)::integer)%7);
  if i.weekly_flexible then
    award:=case when now()<=i.due_at then i.xp_value else greatest(1,round(i.xp_value*.25)::integer) end;
  elsif local_today<=i.scheduled_for then
    award:=i.xp_value;
  elsif local_today<=week_end then
    award:=greatest(1,round(i.xp_value*.5)::integer);
  else
    award:=greatest(1,round(i.xp_value*.25)::integer);
  end if;
  update public.mission_instances set status='completed',completed_at=now(),xp_awarded=award where id=i.id;
  insert into public.xp_transactions(family_id,profile_id,mission_instance_id,kind,amount,created_by)
  values(i.family_id,i.profile_id,i.id,'completion',award,auth.uid());
  return award;
end $$;

create or replace function public.get_child_missions() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare child_id uuid; family_tz text; lang text; today date; result jsonb;
begin
  select s.active_child_profile_id,p.language,f.timezone into child_id,lang,family_tz
  from public.shared_device_states s join public.profiles p on p.id=s.active_child_profile_id join public.families f on f.id=s.family_id
  where s.user_id=auth.uid();
  if child_id is null then raise exception 'child mode required'; end if;
  perform public.apply_due_mission_penalties(child_id);
  today:=(now() at time zone family_tz)::date;
  select jsonb_build_object(
    'available_xp',greatest(coalesce((select sum(amount) from public.xp_transactions where profile_id=child_id),0),0),
    'historical_xp',greatest(coalesce((select sum(amount) from public.xp_transactions where profile_id=child_id and kind in ('completion','reversal')),0),0),
    'completed_count',count(*) filter(where q.status='completed'),'total_count',count(*),
    'missions',coalesce(jsonb_agg(q.payload order by q.is_required desc,q.status desc,q.scheduled_for,q.id) filter(where q.id is not null),'[]'::jsonb)
  ) into result from (
    select i.id,i.is_required,i.status,i.scheduled_for,
      to_jsonb(i)||jsonb_build_object(
        'title',case when lang='en' then t.title_en else t.title_es end,
        'description',case when lang='en' then t.description_en else t.description_es end,
        'icon',t.icon,'category',t.category,
        'is_overdue',i.status='pending' and now()>i.due_at,
        'xp_available',case when i.weekly_flexible then case when now()<=i.due_at then i.xp_value else greatest(1,round(i.xp_value*.25)::integer) end
          when today<=i.scheduled_for then i.xp_value
          when today<=i.scheduled_for+((7-extract(dow from i.scheduled_for)::integer)%7) then greatest(1,round(i.xp_value*.5)::integer)
          else greatest(1,round(i.xp_value*.25)::integer) end) payload
    from public.mission_instances i join public.mission_templates t on t.id=i.mission_template_id
    where i.profile_id=child_id and not i.is_excused and (
      (i.status='pending' and i.scheduled_for<=today) or
      (i.status='completed' and (i.completed_at at time zone family_tz)::date=today))
  ) q;
  return next result;
end $$;

revoke all on function public.apply_due_mission_penalties(uuid),public.get_child_missions() from public;
grant execute on function public.get_child_missions() to authenticated;

comment on function public.apply_due_mission_penalties(uuid) is 'Applies missed required-mission penalties once; intended for a scheduled call and child-feed catch-up.';
