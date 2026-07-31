import { useCallback, useEffect, useState } from 'react'
import { Check, Clock3, Sparkles, Star, Trophy } from 'lucide-react'
import { supabase } from '../lib/supabase'
import type { ChildMission, ChildMissionSummary } from '../types'

const empty:ChildMissionSummary={available_xp:0,historical_xp:0,completed_count:0,total_count:0,missions:[]}

export function ChildMissions(){
  const [summary,setSummary]=useState(empty),[busy,setBusy]=useState<string|null>(null)
  const [error,setError]=useState(''),[celebration,setCelebration]=useState<number|null>(null)
  const load=useCallback(async()=>{const {data,error:e}=await supabase.rpc('get_child_missions');if(e){setError('No pudimos cargar tus misiones.');return}setSummary((data?.[0] as ChildMissionSummary|undefined)??empty)},[])
  useEffect(()=>{void load()},[load])
  const complete=async(mission:ChildMission)=>{if(busy||mission.status==='completed')return;setBusy(mission.id);setError('');const {data,error:e}=await supabase.rpc('complete_mission_instance',{p_instance_id:mission.id});setBusy(null);if(e){setError('No pudimos completar la misión. Inténtalo otra vez.');return}setCelebration(Number(data));await load();window.setTimeout(()=>setCelebration(null),2600)}
  const percent=summary.total_count?Math.round(summary.completed_count/summary.total_count*100):0
  return <section className="child-missions">
    {celebration!==null&&<div className="xp-celebration" role="status"><Sparkles/><strong>¡Misión completada!</strong><span>+{celebration} XP</span></div>}
    <div className="child-stats"><article><Star/><div><span>XP disponible</span><strong>{summary.available_xp}</strong></div></article><article><Trophy/><div><span>XP conseguido</span><strong>{summary.historical_xp}</strong></div></article><article className="daily-progress"><div><span>Progreso de tus misiones</span><strong>{summary.completed_count} de {summary.total_count}</strong></div><div className="progress-track" aria-label={`${percent}% completado`}><span style={{width:`${percent}%`}}/></div></article></div>
    <div className="child-mission-heading"><div><span className="eyebrow"><Sparkles/> Misiones</span><h2>Tus aventuras</h2></div><span>{summary.missions.filter(m=>m.status==='pending').length} pendientes</span></div>
    {error&&<div className="alert error">{error}</div>}
    <div className="child-mission-list">{summary.missions.map(m=><article key={m.id} className={`${m.status} ${m.is_overdue?'overdue':''}`}><span className="child-mission-icon">{m.icon}</span><div className="child-mission-copy"><div><span className={`mission-kind ${m.is_required?'required':'optional'}`}>{m.is_required?'Obligatoria':'Opcional'}</span>{m.is_overdue&&<span className="late-label"><Clock3/>Atrasada</span>}</div><h3>{m.title}</h3>{m.description&&<p>{m.description}</p>}<small>{m.weekly_flexible?`Fecha límite: ${new Date(m.due_at).toLocaleDateString([], {weekday:'long',day:'numeric',month:'short'})}`:m.category}</small></div><div className="mission-reward"><strong>{m.status==='completed'?m.xp_awarded:m.xp_available} XP</strong>{m.is_overdue&&m.status==='pending'&&<small>de {m.xp_value} XP</small>}</div><button className={m.status==='completed'?'mission-done':'complete-mission'} disabled={Boolean(busy)||m.status==='completed'} onClick={()=>void complete(m)}>{m.status==='completed'?<><Check/>Hecha</>:busy===m.id?'Sumando XP…':<><Check/>Completar</>}</button></article>)}{!summary.missions.length&&<div className="empty-child-missions"><span>🧭</span><h2>¡Todo listo por ahora!</h2><p>Cuando tengas una nueva aventura aparecerá aquí.</p></div>}</div>
  </section>
}
