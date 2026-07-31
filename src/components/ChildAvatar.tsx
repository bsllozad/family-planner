import { useCallback, useEffect, useMemo, useState } from 'react'
import { Award, LockKeyhole, Palette, Sparkles } from 'lucide-react'
import { supabase } from '../lib/supabase'
import type { AvatarItem, AvatarItemCategory, ChildAvatarSummary } from '../types'
import { avatars } from '../profileAvatars'

const empty:ChildAvatarSummary={avatar_key:'sprout',historical_xp:0,items:[],badges:[],new_badges:[],new_items:[]}
const categoryLabels:Record<AvatarItemCategory,string>={clothing:'Ropa',pet:'Mascotas',background:'Fondos',accessory:'Accesorios'}

export function ChildAvatar(){
  const [data,setData]=useState(empty),[category,setCategory]=useState<AvatarItemCategory>('clothing')
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[celebration,setCelebration]=useState<string|null>(null)
  const load=useCallback(async()=>{const {data:d,error:e}=await supabase.rpc('get_child_avatar');if(e){setError('No pudimos cargar tu avatar e insignias.');return}const next=(d?.[0] as ChildAvatarSummary|undefined)??empty;setData(next);const unlocked=[...next.new_badges.map(x=>`${x.icon} ${x.name}`),...next.new_items.map(x=>`${x.icon} ${x.name}`)];if(unlocked.length){setCelebration(`¡Nuevo desbloqueo! ${unlocked.join(' · ')}`);await supabase.rpc('acknowledge_child_unlocks');window.setTimeout(()=>setCelebration(null),4500)}},[])
  useEffect(()=>{void load();const refresh=()=>void load();window.addEventListener('xp-changed',refresh);return()=>window.removeEventListener('xp-changed',refresh)},[load])
  const equipped=useMemo(()=>Object.fromEntries(data.items.filter(x=>x.equipped).map(x=>[x.category,x])) as Partial<Record<AvatarItemCategory,AvatarItem>>,[data.items])
  const equip=async(item:AvatarItem)=>{if(!item.unlocked||busy)return;setBusy(true);setError('');const {error:e}=await supabase.rpc('equip_avatar_item',{p_item_id:item.equipped?null:item.id,p_category:item.category});setBusy(false);if(e){setError('No pudimos guardar este cambio.');return}await load()}
  return <section className="avatar-hub">
    {celebration&&<div className="unlock-celebration" role="status"><Sparkles/><strong>{celebration}</strong></div>}
    <div className="child-mission-heading"><div><span className="eyebrow"><Palette/> Avatar</span><h2>Tu personaje</h2></div><span>{data.items.filter(x=>x.unlocked).length} objetos desbloqueados</span></div>
    {error&&<div className="alert error">{error}</div>}
    <div className="avatar-workshop"><article className={`avatar-stage background-${equipped.background?.key??'meadow'}`}><span className="equipped accessory">{equipped.accessory?.icon}</span><span className="avatar-base">{avatars[data.avatar_key]}</span><span className="equipped clothing">{equipped.clothing?.icon}</span><span className="equipped pet">{equipped.pet?.icon}</span><small>{[equipped.background,equipped.clothing,equipped.accessory,equipped.pet].filter(Boolean).map(x=>x?.name).join(' · ')||'Tu avatar básico'}</small></article>
      <div className="avatar-catalog"><div className="avatar-tabs">{(Object.keys(categoryLabels) as AvatarItemCategory[]).map(key=><button key={key} className={category===key?'active':''} onClick={()=>setCategory(key)}>{categoryLabels[key]}</button>)}</div><div className="avatar-item-grid">{data.items.filter(x=>x.category===category).map(item=><button key={item.id} className={`${item.equipped?'equipped':''} ${item.unlocked?'':'locked'}`} disabled={!item.unlocked||busy} onClick={()=>void equip(item)} title={item.unlocked?item.name:item.unlock_hint??'Bloqueado'}><span>{item.unlocked?item.icon:<LockKeyhole/>}</span><strong>{item.name}</strong><small>{item.equipped?'Equipado':item.unlocked?'Usar':item.unlock_hint}</small></button>)}</div></div></div>
    <div className="badge-heading"><div><Award/><div><h3>Tus insignias</h3><p>Logros conseguidos y próximos retos.</p></div></div><strong>{data.badges.filter(x=>x.earned).length}/{data.badges.length}</strong></div>
    <div className="badge-grid">{data.badges.map(b=><article key={b.id} className={b.earned?'earned':''}><span>{b.earned?b.icon:<LockKeyhole/>}</span><div><strong>{b.name}</strong><p>{b.description}</p><div className="progress-track"><span style={{width:`${Math.min(100,Math.round(b.progress/b.target*100))}%`}}/></div><small>{b.earned?'¡Conseguida!':`${Math.min(b.progress,b.target)} / ${b.target}`}</small></div></article>)}</div>
  </section>
}
