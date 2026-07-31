import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, CheckCircle2, ClipboardPlus, Gift, History, Inbox, Sparkles } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { avatars } from '../profileAvatars'
import type { AdminDashboardSummary } from '../types'

const empty:AdminDashboardSummary={pending_redemptions:0,week_start:'',week_end:'',children:[]}

export function AdminOverview(){
  const [summary,setSummary]=useState(empty),[error,setError]=useState('')
  const load=useCallback(async()=>{const {data,error:e}=await supabase.rpc('get_admin_dashboard');if(e){setError('No se pudo cargar el resumen familiar.');return}setSummary((data?.[0] as AdminDashboardSummary|undefined)??empty)},[])
  useEffect(()=>{void load()},[load])
  const jump=(id:string)=>document.getElementById(id)?.scrollIntoView({behavior:'smooth',block:'start'})
  return <section className="admin-overview">
    <div className="overview-heading"><div><span className="eyebrow"><Sparkles/> Esta semana</span><h2>En un vistazo</h2></div><div className="quick-actions"><button onClick={()=>jump('mission-management')}><ClipboardPlus/>Crear misión</button><button onClick={()=>jump('reward-management')}><Gift/>Crear recompensa</button><button onClick={()=>jump('mission-history')}><History/>Corregir historial</button></div></div>
    {error&&<div className="alert error">{error}</div>}
    <div className="family-summary-grid">{summary.children.map(child=>{const percent=child.assigned_count?Math.round(child.completed_count/child.assigned_count*100):0;return <article key={child.profile_id}><div className="summary-child"><span>{avatars[child.avatar_key]}</span><div><strong>{child.display_name}</strong><small>{child.xp_earned} XP esta semana</small></div><b>{percent}%</b></div><div className="progress-track"><span style={{width:`${percent}%`}}/></div><div className="summary-counts"><span><CheckCircle2/>{child.completed_count}/{child.assigned_count} hechas</span><span className={child.missed_count?'warning':''}><AlertTriangle/>{child.missed_count} omitidas</span><span>{child.penalized_count} penalizadas · {child.excused_count} justificadas</span></div></article>})}{!summary.children.length&&!error&&<p className="muted">Añade un perfil infantil para ver su progreso.</p>}</div>
    <div className={`pending-redemptions ${summary.pending_redemptions?'has-pending':''}`}><Inbox/><div><strong>{summary.pending_redemptions} solicitudes de canje pendientes</strong><span>{summary.pending_redemptions?'Revísalas en la sección de recompensas.':'No hay solicitudes por revisar.'}</span></div>{summary.pending_redemptions>0&&<button onClick={()=>jump('reward-management')}>Revisar</button>}</div>
  </section>
}
