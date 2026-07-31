export type Role = 'admin' | 'child'
export type FamilyContext = {
  family_id: string
  family_name: string
  timezone: string
  role: Role
  profile_id: string | null
  profile_name: string | null
}
