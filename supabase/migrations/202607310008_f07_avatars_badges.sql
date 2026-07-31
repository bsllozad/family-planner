-- F07: permanent badges, avatar unlocks and one equipped item per category.
create type public.avatar_item_category as enum ('clothing','pet','background','accessory');

create table public.badges (
  id uuid primary key, key text not null unique, name_es text not null, name_en text not null,
  description_es text not null, description_en text not null, icon text not null,
  criterion text not null, target integer not null check(target>0), sort_order integer not null,
  unique(criterion,target)
);
create table public.profile_badges (
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null, badge_id uuid not null references public.badges(id) on delete restrict,
  earned_at timestamptz not null default now(), celebrated_at timestamptz,
  primary key(profile_id,badge_id), foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete cascade
);
create table public.avatar_items (
  id uuid primary key, key text not null unique, category public.avatar_item_category not null,
  name_es text not null, name_en text not null, icon text not null,
  unlock_badge_id uuid references public.badges(id) on delete restrict,
  unlock_hint_es text, unlock_hint_en text, is_default boolean not null default false, sort_order integer not null
);
create table public.profile_avatar_items (
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null, avatar_item_id uuid not null references public.avatar_items(id) on delete restrict,
  unlocked_at timestamptz not null default now(), celebrated_at timestamptz,
  primary key(profile_id,avatar_item_id), foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete cascade
);
create table public.profile_avatar_loadouts (
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid not null, category public.avatar_item_category not null,
  avatar_item_id uuid not null references public.avatar_items(id) on delete restrict, equipped_at timestamptz not null default now(),
  primary key(profile_id,category), foreign key(profile_id,family_id) references public.profiles(id,family_id) on delete cascade
);

insert into public.badges values
('b0000000-0000-0000-0000-000000000001','first_mission','Primera aventura','First adventure','Completa tu primera misión.','Complete your first mission.','🚀','completed_missions',1,1),
('b0000000-0000-0000-0000-000000000002','streak_7','En llamas','On fire','Consigue una racha de 7 días.','Reach a 7-day streak.','🔥','best_streak',7,2),
('b0000000-0000-0000-0000-000000000003','xp_100','Primer centenar','First hundred','Consigue 100 XP históricos.','Earn 100 lifetime XP.','⭐','historical_xp',100,3),
('b0000000-0000-0000-0000-000000000004','xp_500','Gran explorador','Great explorer','Consigue 500 XP históricos.','Earn 500 lifetime XP.','🧭','historical_xp',500,4),
('b0000000-0000-0000-0000-000000000005','xp_1000','Héroe de mil','Thousand hero','Consigue 1.000 XP históricos.','Earn 1,000 lifetime XP.','🏆','historical_xp',1000,5),
('b0000000-0000-0000-0000-000000000006','perfect_week','Semana perfecta','Perfect week','Completa todas las misiones obligatorias de una semana.','Complete every required mission in one week.','💫','perfect_weeks',1,6);

insert into public.avatar_items values
('a0000000-0000-0000-0000-000000000001','green-cape','clothing','Capa verde','Green cape','🧥',null,null,null,true,1),
('a0000000-0000-0000-0000-000000000002','hero-crown','clothing','Capa de héroe','Hero cape','🦸','b0000000-0000-0000-0000-000000000004','Alcanza 500 XP','Reach 500 XP',false,2),
('a0000000-0000-0000-0000-000000000003','champion-shirt','clothing','Camiseta campeona','Champion shirt','👕','b0000000-0000-0000-0000-000000000005','Alcanza 1.000 XP','Reach 1,000 XP',false,3),
('a0000000-0000-0000-0000-000000000004','fox-pet','pet','Zorrito','Little fox','🦊','b0000000-0000-0000-0000-000000000001','Completa tu primera misión','Complete your first mission',false,1),
('a0000000-0000-0000-0000-000000000005','dragon-pet','pet','Dragón','Dragon','🐉','b0000000-0000-0000-0000-000000000002','Logra una racha de 7 días','Reach a 7-day streak',false,2),
('a0000000-0000-0000-0000-000000000006','meadow','background','Pradera','Meadow','🌿',null,null,null,true,1),
('a0000000-0000-0000-0000-000000000007','night-sky','background','Cielo nocturno','Night sky','🌙','b0000000-0000-0000-0000-000000000003','Alcanza 100 XP','Reach 100 XP',false,2),
('a0000000-0000-0000-0000-000000000008','space','background','Espacio','Space','🌌','b0000000-0000-0000-0000-000000000005','Alcanza 1.000 XP','Reach 1,000 XP',false,3),
('a0000000-0000-0000-0000-000000000009','sunrise','background','Amanecer','Sunrise','🌅','b0000000-0000-0000-0000-000000000006','Completa una semana perfecta','Complete a perfect week',false,4),
('a0000000-0000-0000-0000-000000000010','explorer-hat','accessory','Sombrero explorador','Explorer hat','🤠',null,null,null,true,1),
('a0000000-0000-0000-0000-000000000011','star-glasses','accessory','Gafas estrella','Star glasses','🤩','b0000000-0000-0000-0000-000000000003','Alcanza 100 XP','Reach 100 XP',false,2),
('a0000000-0000-0000-0000-000000000012','gold-crown','accessory','Corona dorada','Golden crown','👑','b0000000-0000-0000-0000-000000000006','Completa una semana perfecta','Complete a perfect week',false,3);

alter table public.badges enable row level security; alter table public.avatar_items enable row level security;
alter table public.profile_badges enable row level security; alter table public.profile_avatar_items enable row level security; alter table public.profile_avatar_loadouts enable row level security;
create policy "authenticated reads badge catalogue" on public.badges for select to authenticated using(true);
create policy "authenticated reads avatar catalogue" on public.avatar_items for select to authenticated using(true);
create policy "family reads profile badges" on public.profile_badges for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));
create policy "family reads avatar unlocks" on public.profile_avatar_items for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));
create policy "family reads avatar loadouts" on public.profile_avatar_loadouts for select to authenticated using(public.is_family_admin(family_id) or profile_id=(select active_child_profile_id from public.shared_device_states where user_id=auth.uid()));

create or replace function public.sync_child_achievements(p_profile_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare f uuid; historical integer; completed integer; streak integer:=0; best integer:=0; duty record; perfect integer; badge record;
begin
  select family_id into f from public.profiles where id=p_profile_id and role='child' and archived_at is null;
  if f is null then return; end if;
  select greatest(coalesce(sum(amount) filter(where kind in ('completion','reversal')),0),0)::integer into historical from public.xp_transactions where profile_id=p_profile_id;
  select count(*)::integer into completed from public.mission_instances where profile_id=p_profile_id and status='completed';
  for duty in select scheduled_for,bool_and(status='completed') complete from public.mission_instances where profile_id=p_profile_id and is_required and not is_excused group by scheduled_for order by scheduled_for loop
    if duty.complete then streak:=streak+1; best:=greatest(best,streak); else streak:=0; end if;
  end loop;
  select count(*)::integer into perfect from (select date_trunc('week',scheduled_for)::date from public.mission_instances where profile_id=p_profile_id and is_required and not is_excused group by 1 having count(*)>0 and bool_and(status='completed')) weeks;
  for badge in select * from public.badges loop
    if (case badge.criterion when 'completed_missions' then completed when 'best_streak' then best when 'historical_xp' then historical when 'perfect_weeks' then perfect else 0 end) >= badge.target then
      insert into public.profile_badges(family_id,profile_id,badge_id) values(f,p_profile_id,badge.id) on conflict do nothing;
    end if;
  end loop;
  insert into public.profile_avatar_items(family_id,profile_id,avatar_item_id)
    select f,p_profile_id,i.id from public.avatar_items i where i.is_default or exists(select 1 from public.profile_badges pb where pb.profile_id=p_profile_id and pb.badge_id=i.unlock_badge_id) on conflict do nothing;
  insert into public.profile_avatar_loadouts(family_id,profile_id,category,avatar_item_id)
    select f,p_profile_id,i.category,i.id from public.avatar_items i where i.is_default on conflict(profile_id,category) do nothing;
end $$;

create or replace function public.sync_child_achievements_trigger() returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform public.sync_child_achievements(coalesce((to_jsonb(new)->>'profile_id')::uuid,(to_jsonb(new)->>'id')::uuid));
  return new;
end $$;
create trigger sync_new_child_avatar after insert on public.profiles for each row execute function public.sync_child_achievements_trigger();
create trigger sync_achievements_after_xp after insert on public.xp_transactions for each row execute function public.sync_child_achievements_trigger();

create or replace function public.get_child_avatar() returns setof jsonb language plpgsql security definer set search_path='' as $$
declare child_id uuid; lang text; historical integer; completed integer; best integer:=0; streak integer:=0; perfect integer; duty record; result jsonb;
begin
  select s.active_child_profile_id,p.language into child_id,lang from public.shared_device_states s join public.profiles p on p.id=s.active_child_profile_id where s.user_id=auth.uid();
  if child_id is null then raise exception 'child mode required'; end if;
  perform public.sync_child_achievements(child_id);
  select greatest(coalesce(sum(amount) filter(where kind in ('completion','reversal')),0),0)::integer into historical from public.xp_transactions where profile_id=child_id;
  select count(*)::integer into completed from public.mission_instances where profile_id=child_id and status='completed';
  for duty in select scheduled_for,bool_and(status='completed') complete from public.mission_instances where profile_id=child_id and is_required and not is_excused group by scheduled_for order by scheduled_for loop if duty.complete then streak:=streak+1; best:=greatest(best,streak); else streak:=0; end if; end loop;
  select count(*)::integer into perfect from (select date_trunc('week',scheduled_for)::date from public.mission_instances where profile_id=child_id and is_required and not is_excused group by 1 having count(*)>0 and bool_and(status='completed')) weeks;
  select jsonb_build_object('avatar_key',p.avatar_key,'historical_xp',historical,
    'items',(select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'key',i.key,'category',i.category,'name',case when lang='en' then i.name_en else i.name_es end,'icon',i.icon,'unlocked',u.avatar_item_id is not null,'equipped',l.avatar_item_id=i.id,'unlock_hint',case when lang='en' then i.unlock_hint_en else i.unlock_hint_es end) order by i.category,i.sort_order),'[]') from public.avatar_items i left join public.profile_avatar_items u on u.profile_id=child_id and u.avatar_item_id=i.id left join public.profile_avatar_loadouts l on l.profile_id=child_id and l.category=i.category),
    'badges',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'key',b.key,'name',case when lang='en' then b.name_en else b.name_es end,'description',case when lang='en' then b.description_en else b.description_es end,'icon',b.icon,'earned',pb.badge_id is not null,'earned_at',pb.earned_at,'progress',case b.criterion when 'completed_missions' then completed when 'best_streak' then best when 'historical_xp' then historical when 'perfect_weeks' then perfect else 0 end,'target',b.target) order by b.sort_order),'[]') from public.badges b left join public.profile_badges pb on pb.profile_id=child_id and pb.badge_id=b.id),
    'new_badges',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'key',b.key,'name',case when lang='en' then b.name_en else b.name_es end,'description','','icon',b.icon,'earned',true,'earned_at',pb.earned_at,'progress',b.target,'target',b.target)),'[]') from public.profile_badges pb join public.badges b on b.id=pb.badge_id where pb.profile_id=child_id and pb.celebrated_at is null),
    'new_items',(select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'key',i.key,'category',i.category,'name',case when lang='en' then i.name_en else i.name_es end,'icon',i.icon,'unlocked',true,'equipped',false,'unlock_hint',null)) filter(where not i.is_default),'[]') from public.profile_avatar_items u join public.avatar_items i on i.id=u.avatar_item_id where u.profile_id=child_id and u.celebrated_at is null)
  ) into result from public.profiles p where p.id=child_id; return next result;
end $$;

create or replace function public.equip_avatar_item(p_item_id uuid,p_category public.avatar_item_category) returns void language plpgsql security definer set search_path='' as $$
declare child_id uuid; f uuid;
begin
  select active_child_profile_id,family_id into child_id,f from public.shared_device_states where user_id=auth.uid(); if child_id is null then raise exception 'child mode required'; end if;
  if p_item_id is null then delete from public.profile_avatar_loadouts where profile_id=child_id and category=p_category; return; end if;
  if not exists(select 1 from public.profile_avatar_items u join public.avatar_items i on i.id=u.avatar_item_id where u.profile_id=child_id and u.avatar_item_id=p_item_id and i.category=p_category) then raise exception 'item locked or invalid category'; end if;
  insert into public.profile_avatar_loadouts(family_id,profile_id,category,avatar_item_id) values(f,child_id,p_category,p_item_id) on conflict(profile_id,category) do update set avatar_item_id=excluded.avatar_item_id,equipped_at=now();
end $$;
create or replace function public.acknowledge_child_unlocks() returns void language plpgsql security definer set search_path='' as $$
declare child_id uuid; begin select active_child_profile_id into child_id from public.shared_device_states where user_id=auth.uid(); if child_id is null then raise exception 'child mode required'; end if; update public.profile_badges set celebrated_at=now() where profile_id=child_id and celebrated_at is null; update public.profile_avatar_items u set celebrated_at=now() from public.avatar_items i where u.profile_id=child_id and u.avatar_item_id=i.id and not i.is_default and u.celebrated_at is null; end $$;

revoke all on public.badges,public.avatar_items,public.profile_badges,public.profile_avatar_items,public.profile_avatar_loadouts from anon,authenticated;
grant select on public.badges,public.avatar_items,public.profile_badges,public.profile_avatar_items,public.profile_avatar_loadouts to authenticated;
revoke all on function public.sync_child_achievements(uuid),public.sync_child_achievements_trigger(),public.get_child_avatar(),public.equip_avatar_item(uuid,public.avatar_item_category),public.acknowledge_child_unlocks() from public;
grant execute on function public.get_child_avatar(),public.equip_avatar_item(uuid,public.avatar_item_category),public.acknowledge_child_unlocks() to authenticated;
