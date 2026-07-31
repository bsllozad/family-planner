-- F05: permanent XP progression, levels and required-mission streaks.
-- xp_transactions remains the single source of truth: only completion and its
-- reversal affect historical XP, while every transaction affects spendable XP.

create unique index xp_one_completion_per_instance
  on public.xp_transactions(mission_instance_id) where kind='completion';

create or replace function public.get_child_missions() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare
  child_id uuid; family_tz text; lang text; today date; result jsonb;
  available integer; historical integer; level_name text; level_no integer;
  level_floor integer; next_name text; next_xp integer; level_percent integer;
  streak integer:=0; best integer:=0; duty record;
begin
  select s.active_child_profile_id,p.language,f.timezone into child_id,lang,family_tz
  from public.shared_device_states s
  join public.profiles p on p.id=s.active_child_profile_id
  join public.families f on f.id=s.family_id
  where s.user_id=auth.uid();
  if child_id is null then raise exception 'child mode required'; end if;

  perform public.apply_due_mission_penalties(child_id);
  today:=(now() at time zone family_tz)::date;
  select greatest(coalesce(sum(amount),0),0)::integer,
    greatest(coalesce(sum(amount) filter(where kind in ('completion','reversal')),0),0)::integer
  into available,historical from public.xp_transactions where profile_id=child_id;

  if historical>=3500 then level_name:='Champion'; level_no:=4; level_floor:=3500; next_name:=null; next_xp:=null; level_percent:=100;
  elsif historical>=1500 then level_name:='Hero'; level_no:=3; level_floor:=1500; next_name:='Champion'; next_xp:=3500; level_percent:=floor((historical-1500)*100.0/2000);
  elsif historical>=500 then level_name:='Explorer'; level_no:=2; level_floor:=500; next_name:='Hero'; next_xp:=1500; level_percent:=floor((historical-500)*100.0/1000);
  else level_name:='Rookie'; level_no:=1; level_floor:=0; next_name:='Explorer'; next_xp:=500; level_percent:=floor(historical*100.0/500);
  end if;

  -- Missing calendar dates are absent from this loop and therefore do not
  -- break a streak. Optional and excused instances do not create a duty day.
  for duty in
    select scheduled_for,bool_and(status='completed') as complete
    from public.mission_instances
    where profile_id=child_id and is_required and not is_excused and scheduled_for<=today
    group by scheduled_for order by scheduled_for
  loop
    if duty.complete then streak:=streak+1; best:=greatest(best,streak); else streak:=0; end if;
  end loop;

  select jsonb_build_object(
    'available_xp',available,'historical_xp',historical,
    'level',level_name,'level_number',level_no,'level_floor_xp',level_floor,
    'next_level',next_name,'next_level_xp',next_xp,'level_progress_percent',level_percent,
    'current_streak',streak,'best_streak',best,
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

revoke all on function public.get_child_missions() from public;
grant execute on function public.get_child_missions() to authenticated;

comment on function public.get_child_missions() is 'Returns the child mission feed plus ledger-derived XP, level progress, and required-duty streaks.';
