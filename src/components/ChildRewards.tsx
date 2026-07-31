import { useCallback, useEffect, useState } from 'react'
import { Banknote, Gift, ShoppingBag } from 'lucide-react'
import { supabase } from '../lib/supabase'
import type { ChildReward, ChildRewardsSummary, RedemptionStatus } from '../types'

const empty:ChildRewardsSummary={available_xp:0,cash_available:false,rewards:[],redemptions:[]}
const labels:Record<RedemptionStatus,string>={requested:'Esperando aprobación',approved:'Aprobado',fulfilled:'Entregado',rejected:'Rechazado',cancelled:'Cancelado'}
export function ChildRewards(){
  const [data,setData]=useState(empty),[busy,setBusy]=useState(false),[cash,setCash]=useState(175),[error,setError]=useState(''),[notice,setNotice]=useState('')
  const load=useCallback(async()=>{const {data:d,error:e}=await supabase.rpc('get_child_rewards');if(e){setError('No pudimos cargar las recompensas.');return}setData((d?.[0] as ChildRewardsSummary|undefined)??empty)},[])
  useEffect(()=>{void load();const refresh=()=>void load();window.addEventListener('xp-changed',refresh);return()=>window.removeEventListener('xp-changed',refresh)},[load])
  const request=async(reward:ChildReward)=>{setBusy(true);setError('');const {error:e}=await supabase.rpc('request_reward',{p_reward_id:reward.id});setBusy(false);if(e){setError(e.message.includes('insufficient')?'Necesitas más XP para esta recompensa.':'No pudimos solicitar la recompensa.');return}setNotice(`¡${reward.title} solicitada! Un adulto la revisará.`);await load()}
  const requestCash=async()=>{setBusy(true);setError('');const {error:e}=await supabase.rpc('request_cash_redemption',{p_xp_amount:cash});setBusy(false);if(e){setError(e.message.includes('weekly')?'Ya hiciste un canje esta semana.':e.message.includes('insufficient')?'No tienes suficiente XP.':'No pudimos solicitar el canje.');return}setNotice('Canje solicitado. Un adulto debe aprobar y confirmar el pago.');await load()}
  return <section className="child-rewards"><div className="child-mission-heading"><div><span className="eyebrow"><Gift/> Recompensas</span><h2>Usa tu XP</h2></div><span>{data.available_xp} XP disponibles</span></div>{notice&&<div className="alert success">{notice}</div>}{error&&<div className="alert error">{error}</div>}
    <div className="child-reward-grid">{data.rewards.map(r=><article key={r.id}><span>{r.icon}</span><h3>{r.title}</h3>{r.description&&<p>{r.description}</p>}<strong>{r.xp_cost} XP</strong><button className="primary" disabled={busy||data.available_xp<r.xp_cost} onClick={()=>void request(r)}><ShoppingBag/>Solicitar</button></article>)}{!data.rewards.length&&<p className="muted">Pronto habrá nuevas recompensas.</p>}</div>
    <article className={`cash-card ${data.cash_available?'':'disabled'}`}><Banknote/><div><h3>Cambiar XP por dinero</h3><p>{data.cash_available?'Disponible hoy: entre CAD $5 y $20.':'Disponible cada viernes según la zona horaria de tu familia.'}</p></div><label>XP<select value={cash} onChange={e=>setCash(Number(e.target.value))} disabled={!data.cash_available}>{Array.from({length:16},(_,i)=>175+i*35).map(x=><option key={x} value={x}>{x} XP = CAD ${x/35}</option>)}</select></label><button className="secondary fit" disabled={busy||!data.cash_available||data.available_xp<cash} onClick={()=>void requestCash()}>Solicitar</button></article>
    {!!data.redemptions.length&&<div className="child-redemption-history"><h3>Tus solicitudes</h3>{data.redemptions.map(r=><article key={`${r.kind}-${r.id}`}><span>{r.icon}</span><div><strong>{r.title}</strong><small>{r.xp_amount} XP{r.cad_amount!==null?` · CAD $${Number(r.cad_amount).toFixed(2)}`:''}</small></div><span className={`status ${r.status}`}>{labels[r.status]}</span></article>)}</div>}
  </section>
}
