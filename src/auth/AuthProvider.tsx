import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import type { FamilyContext } from '../types'

type AuthState = {session:Session|null; context:FamilyContext|null; loading:boolean; refreshContext:()=>Promise<void>; signOut:()=>Promise<void>}
const AuthContext = createContext<AuthState|null>(null)

export function AuthProvider({children}:{children:ReactNode}) {
  const [session,setSession]=useState<Session|null>(null)
  const [context,setContext]=useState<FamilyContext|null>(null)
  const [loading,setLoading]=useState(true)
  const loadContext=async(current:Session|null)=>{
    if(!current){setContext(null);return}
    const {data}=await supabase.rpc('get_my_family_context')
    setContext((data?.[0] as FamilyContext|undefined)??null)
  }
  const refreshContext=()=>loadContext(session)
  useEffect(()=>{
    supabase.auth.getSession().then(async({data})=>{setSession(data.session);await loadContext(data.session);setLoading(false)})
    const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{
      setSession(next); setTimeout(()=>loadContext(next).finally(()=>setLoading(false)),0)
    })
    return()=>subscription.unsubscribe()
  },[])
  const value=useMemo(()=>({session,context,loading,refreshContext,signOut:async()=>{await supabase.auth.signOut()}}),[session,context,loading])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(){const value=useContext(AuthContext);if(!value)throw new Error('useAuth requiere AuthProvider');return value}
