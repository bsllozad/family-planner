import { useCallback, useEffect, useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { supabase } from '../lib/supabase'
import type { ChildProfile, MissionCalendarSummary } from '../types'

const weekday=['Lun','Mar','Mié','Jue','Vie','Sáb','Dom']
const statusLabel={complete:'Completo',partial:'Parcial',pending:'Pendiente',none:'Sin misiones'} as const
const isoMonth=(date:Date)=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-01`

export function MissionCalendar({children,isChild}:{children:ChildProfile[];isChild:boolean}){
  const [month,setMonth]=useState(()=>isoMonth(new Date())),[profileId,setProfileId]=useState(''),[summary,setSummary]=useState<MissionCalendarSummary|null>(null),[selected,setSelected]=useState(''),[error,setError]=useState('')
  useEffect(()=>{if(!isChild&&!profileId&&children[0])setProfileId(children[0].id)},[children,isChild,profileId])
  const load=useCallback(async()=>{if(!isChild&&!profileId){setSummary(null);return}const {data,error:e}=await supabase.rpc('get_mission_calendar',{p_month:month,p_profile_id:isChild?null:profileId});if(e){setError('No se pudo cargar el calendario.');return}const next=(data?.[0] as MissionCalendarSummary|undefined)??null;setSummary(next);setSelected(current=>current&&next?.days.some(d=>d.date===current)?current:(next?.today.startsWith(month.slice(0,7))?next.today:''));setError('')},[isChild,month,profileId])
  useEffect(()=>{void load()},[load])
  const move=(delta:number)=>{const [year,m]=month.split('-').map(Number);setMonth(isoMonth(new Date(year,m-1+delta,1)));setSelected('')}
  const leading=useMemo(()=>{const d=new Date(`${month}T12:00:00`);return (d.getDay()+6)%7},[month])
  const selectedDay=summary?.days.find(d=>d.date===selected)
  const title=new Intl.DateTimeFormat('es',{month:'long',year:'numeric'}).format(new Date(`${month}T12:00:00`))
  return <section className="mission-calendar"><div className="calendar-toolbar"><div><span className="eyebrow">Historial</span><h2>Calendario de misiones</h2><p>{isChild?'Tu progreso día a día.':'Cambia de perfil para consultar el historial familiar.'}</p></div>{!isChild&&<select aria-label="Perfil del calendario" value={profileId} onChange={e=>setProfileId(e.target.value)}><option value="">Selecciona un niño</option>{children.map(c=><option key={c.id} value={c.id}>{c.display_name}</option>)}</select>}</div>
    <div className="calendar-card"><div className="month-nav"><button aria-label="Mes anterior" onClick={()=>move(-1)}><ChevronLeft/></button><strong>{title}</strong><button aria-label="Mes siguiente" onClick={()=>move(1)}><ChevronRight/></button></div>{error&&<div className="alert error">{error}</div>}<div className="calendar-legend">{Object.entries(statusLabel).map(([status,label])=><span key={status}><i className={status}/>{label}</span>)}</div><div className="calendar-grid">{weekday.map(d=><b key={d}>{d}</b>)}{Array.from({length:leading},(_,i)=><span className="calendar-blank" key={`blank-${i}`}/>)}{summary?.days.map(day=><button key={day.date} className={`${day.status} ${selected===day.date?'selected':''} ${day.date===summary.today?'today':''}`} onClick={()=>setSelected(day.date)}><time>{Number(day.date.slice(-2))}</time>{day.status!=='none'&&<small>{day.completed_count}/{day.total_count}</small>}<i/></button>)}</div></div>
    {selectedDay&&<div className="calendar-detail"><h3>{new Date(`${selectedDay.date}T12:00:00`).toLocaleDateString('es',{weekday:'long',day:'numeric',month:'long'})}</h3>{selectedDay.missions.map(m=><article key={m.id}><span>{m.icon}</span><div><strong>{m.title}</strong><small>{m.is_excused?'Justificada':m.status==='completed'?`${m.xp_awarded} XP conseguidos`:m.penalty_xp?`Penalización: ${m.penalty_xp} XP`:'Pendiente'} · {m.is_required?'Obligatoria':'Extra'}</small></div><i className={m.is_excused?'excused':m.status}/></article>)}{!selectedDay.missions.length&&<p className="muted">No hubo misiones este día.</p>}</div>}
  </section>
}
