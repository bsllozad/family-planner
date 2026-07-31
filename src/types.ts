export type Role = 'admin' | 'child'
export type FamilyContext = {
  family_id: string
  family_name: string
  timezone: string
  role: Role
  profile_id: string | null
  profile_name: string | null
}

export type ChildProfile = {
  id: string
  family_id: string
  display_name: string
  role: 'child'
  birth_date: string | null
  language: 'es' | 'en'
  avatar_key: 'sprout' | 'rocket' | 'star' | 'fox' | 'panda' | 'dino' | 'unicorn' | 'robot' | 'butterfly' | 'koala' | 'cat' | 'soccer' | 'artist'
  archived_at: string | null
  created_at: string
}

export type Recurrence = 'once' | 'daily' | 'weekly'
export type MissionTemplate = {
  id: string; family_id: string; title_es: string; title_en: string
  description_es: string | null; description_en: string | null
  icon: string; category: string; xp_value: number; is_required: boolean
  recurrence: Recurrence; weekly_days: number[]; weekly_flexible: boolean
  starts_on: string; archived_at: string | null; created_at: string
  assignee_ids: string[]
}
export type MissionInstance = {
  id: string; mission_template_id: string; profile_id: string
  scheduled_for: string; due_at: string; status: 'pending' | 'completed'
  xp_value: number; xp_awarded: number; is_excused: boolean
  completed_at: string | null; profile_name?: string; title_es?: string
}

export type ChildMission = {
  id: string; scheduled_for: string; due_at: string
  status: 'pending' | 'completed'; completed_at: string | null
  title: string; description: string | null; icon: string; category: string
  is_required: boolean; weekly_flexible: boolean
  xp_value: number; xp_available: number; xp_awarded: number
  is_overdue: boolean
}

export type ChildMissionSummary = {
  available_xp: number; historical_xp: number
  completed_count: number; total_count: number
  level: 'Rookie' | 'Explorer' | 'Hero' | 'Champion'
  level_number: number; level_floor_xp: number
  next_level: 'Explorer' | 'Hero' | 'Champion' | null
  next_level_xp: number | null; level_progress_percent: number
  current_streak: number; best_streak: number
  missions: ChildMission[]
}

export type RedemptionStatus = 'requested' | 'approved' | 'fulfilled' | 'rejected' | 'cancelled'
export type Reward = {
  id:string; family_id?:string; title_es:string; title_en:string
  description_es:string|null; description_en:string|null; icon:string
  xp_cost:number; is_available:boolean; archived_at:string|null; assignee_ids:string[]
}
export type ChildReward = {id:string;title:string;description:string|null;icon:string;xp_cost:number}
export type Redemption = {
  id:string;kind:'reward'|'cash';profile_name?:string;title:string;icon:string
  xp_amount:number;cad_amount:number|null;status:RedemptionStatus;requested_at:string
}
export type ChildRewardsSummary = {available_xp:number;cash_available:boolean;rewards:ChildReward[];redemptions:Redemption[]}
