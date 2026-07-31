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
