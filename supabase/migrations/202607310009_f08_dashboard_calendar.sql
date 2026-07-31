-- F08: role-scoped dashboard summaries and timezone-safe mission calendar.

create or replace function public.get_admin_dashboard() returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare f uuid; tz text; today date; week_start date; result jsonb;
begin
  select fm.family_id,fam.timezone into f,tz from public.family_members fm join public.families fam on fam.id=fm.family_id where fm.user_id=auth.uid() and fm.role='admin';
  if f is null or not public.is_family_admin(f) then raise exception 'admin required'; end if;
  today:=(now() at time zone tz)::date; week_start:=today-(extract(isodow from today)::integer-1);
  select jsonb_build_object(
    'week_start',week_start,'week_end',week_start+6,
    'pending_redemptions',(select count(*) from (select id from public.reward_redemptions where family_id=f and status='requested' union all select id from public.cash_redemptions where family_id=f and status='requested') requests),
    'children',coalesce((select jsonb_agg(jsonb_build_object(
      'profile_id',p.id,'display_name',p.display_name,'avatar_key',p.avatar_key,
      'assigned_count',coalesce(s.assigned_count,0),'completed_count',coalesce(s.completed_count,0),
      'xp_earned',coalesce(s.xp_earned,0),'missed_count',coalesce(s.missed_count,0),
      'penalized_count',coalesce(s.penalized_count,0),'excused_count',coalesce(s.excused_count,0)
    ) order by p.created_at) from public.profiles p left join lateral (
      select count(*)::integer assigned_count,count(*) filter(where i.status='completed')::integer completed_count,
        coalesce(sum(i.xp_awarded) filter(where i.status='completed'),0)::integer xp_earned,
        count(*) filter(where i.status='pending' and not i.is_excused and now()>i.due_at)::integer missed_count,
        count(*) filter(where i.penalty_xp>0)::integer penalized_count,
        count(*) filter(where i.is_excused)::integer excused_count
      from public.mission_instances i where i.profile_id=p.id and i.scheduled_for between week_start and week_start+6
    ) s on true where p.family_id=f and p.role='child' and p.archived_at is null),'[]'::jsonb)
  ) into result;
  return next result;
end $$;

create or replace function public.get_mission_calendar(p_month date,p_profile_id uuid default null) returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare f uuid; tz text; child_id uuid; lang text; first_day date; last_day date; today date; result jsonb;
begin
  first_day:=date_trunc('month',p_month)::date; last_day:=(first_day+interval '1 month-1 day')::date;
  select fm.family_id,fam.timezone into f,tz from public.family_members fm join public.families fam on fam.id=fm.family_id where fm.user_id=auth.uid() and fm.role='admin';
  if f is not null and public.is_family_admin(f) then
    child_id:=p_profile_id;
    if child_id is null or not exists(select 1 from public.profiles where id=child_id and family_id=f and role='child' and archived_at is null) then raise exception 'valid child profile required'; end if;
  else
    select s.family_id,s.active_child_profile_id,fam.timezone into f,child_id,tz from public.shared_device_states s join public.families fam on fam.id=s.family_id where s.user_id=auth.uid();
    if child_id is null or (p_profile_id is not null and p_profile_id<>child_id) then raise exception 'child mode required'; end if;
  end if;
  select language into lang from public.profiles where id=child_id; today:=(now() at time zone tz)::date;
  select jsonb_build_object('month',first_day,'today',today,'profile_id',child_id,
    'profile_name',(select display_name from public.profiles where id=child_id),
    'days',coalesce(jsonb_agg(jsonb_build_object('date',d.day,'status',case
      when coalesce(m.total_count,0)=0 then 'none'
      when m.pending_count=0 then 'complete'
      when m.completed_count>0 or m.excused_count>0 then 'partial'
      else 'pending' end,
      'completed_count',coalesce(m.completed_count,0),'total_count',coalesce(m.total_count,0),
      'missions',coalesce(m.missions,'[]'::jsonb)) order by d.day),'[]'::jsonb)
  ) into result from generate_series(first_day,last_day,interval '1 day') d(day) left join lateral (
    select count(*)::integer total_count,count(*) filter(where i.status='completed')::integer completed_count,
      count(*) filter(where i.status='pending' and not i.is_excused)::integer pending_count,
      count(*) filter(where i.is_excused)::integer excused_count,
      jsonb_agg(jsonb_build_object('id',i.id,'title',case when lang='en' then t.title_en else t.title_es end,
        'icon',t.icon,'status',i.status,'is_required',i.is_required,'is_excused',i.is_excused,
        'penalty_xp',i.penalty_xp,'xp_awarded',i.xp_awarded) order by i.is_required desc,t.title_es) missions
    from public.mission_instances i join public.mission_templates t on t.id=i.mission_template_id
    where i.profile_id=child_id and i.scheduled_for=d.day::date
  ) m on true;
  return next result;
end $$;

revoke all on function public.get_admin_dashboard(),public.get_mission_calendar(date,uuid) from public;
grant execute on function public.get_admin_dashboard(),public.get_mission_calendar(date,uuid) to authenticated;

comment on function public.get_mission_calendar(date,uuid) is 'Returns one profile month with dates interpreted in the family timezone; child mode cannot select another profile.';
