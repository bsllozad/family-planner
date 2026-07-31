import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { CalendarDays, Copy, Home, LogOut, Settings, ShieldCheck, Sparkles, Users } from 'lucide-react'
import { useAuth } from '../auth/AuthProvider'
import { MissionManager } from '../components/MissionManager'
import { ChildMissions } from '../components/ChildMissions'
import { ProfileManager } from '../components/ProfileManager'
import { RewardManager } from '../components/RewardManager'
import { ChildRewards } from '../components/ChildRewards'
import { ChildAvatar } from '../components/ChildAvatar'
import { AdminOverview } from '../components/AdminOverview'
import { MissionCalendar } from '../components/MissionCalendar'
import { supabase } from '../lib/supabase'
import type { ChildProfile } from '../types'
import { avatars } from '../profileAvatars'

export function DashboardPage(){
  const {context,signOut,refreshContext}=useAuth()
  const [children,setChildren]=useState<ChildProfile[]>([])
  const [view,setView]=useState<'home'|'calendar'>('home')
  const [openInvite,setOpenInvite]=useState(false),[openPin,setOpenPin]=useState(false)
  const [pinPurpose,setPinPurpose]=useState<'set'|'unlock'>('set')
  const [email,setEmail]=useState(''),[link,setLink]=useState(''),[pin,setPin]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false)
  const child=context?.role==='child'
  const loadChildren=useCallback(async()=>{if(!context||child)return;const {data}=await supabase.from('profiles').select('*').eq('family_id',context.family_id).eq('role','child').is('archived_at',null).order('created_at');setChildren((data??[]) as ChildProfile[])},[context,child])
  useEffect(()=>{void loadChildren()},[loadChildren])
  if(!context)return null
  const invite=async(e:FormEvent)=>{e.preventDefault();setBusy(true);setError('');const {data,error:e2}=await supabase.rpc('create_family_invitation',{p_email:email.trim()});setBusy(false);if(e2){setError('No se pudo crear la invitación. Comprueba el correo.');return}setLink(`${location.origin}/invite/${data}`)}
  const chooseChild=async(id:string)=>{if(!id)return;setBusy(true);setError('');const {error:e}=await supabase.rpc('activate_child_profile',{p_profile_id:id});setBusy(false);if(e){setPinPurpose('set');setPin('');setOpenPin(true);return}await refreshContext()}
  const submitPin=async(e:FormEvent)=>{e.preventDefault();setBusy(true);setError('');if(pinPurpose==='set'){const {error:e2}=await supabase.rpc('set_adult_pin',{p_pin:pin});setBusy(false);if(e2){setError('El PIN debe tener entre 4 y 6 dígitos.');return}setOpenPin(false);setPin('');return}const {data,error:e2}=await supabase.rpc('unlock_adult_mode',{p_pin:pin});setBusy(false);const result=data?.[0] as {success:boolean;locked_until:string|null}|undefined;if(e2||!result?.success){setError(result?.locked_until?`Demasiados intentos. Inténtalo después de ${new Date(result.locked_until).toLocaleTimeString()}.`:'PIN incorrecto.');return}setOpenPin(false);setPin('');await refreshContext()}
  return <main className={`app-page ${child?'child-mode':''}`}>
    <header className="topbar"><a className="logo dark" href="/"><span className="brand-mark">K</span><span>kinquest</span></a><div className="profile-switcher">{child?<button className="secondary compact" onClick={()=>{setPinPurpose('unlock');setPin('');setError('');setOpenPin(true)}}><ShieldCheck/>Modo adulto</button>:<select aria-label="Cambiar a perfil infantil" defaultValue="" onChange={e=>void chooseChild(e.target.value)} disabled={busy||children.length===0}><option value="">Cambiar de perfil…</option>{children.map(p=><option key={p.id} value={p.id}>{avatars[p.avatar_key]} {p.display_name}</option>)}</select>}<div className="account-pill"><span>{context.profile_name?.slice(0,1).toUpperCase()??'F'}</span><div><strong>{context.profile_name}</strong><small>{child?'Explorador':context.family_name}</small></div><button aria-label="Cerrar sesión" onClick={signOut}><LogOut/></button></div></div></header>
    <div className="dashboard"><aside><nav><button className={view==='home'?'active':''} onClick={()=>setView('home')}><Home/>Inicio</button><button className={view==='calendar'?'active':''} onClick={()=>setView('calendar')}><CalendarDays/>Calendario</button>{!child&&<><button onClick={()=>{setView('home');setTimeout(()=>document.getElementById('family-management')?.scrollIntoView({behavior:'smooth'}),0)}}><Users/>Familia</button><button onClick={()=>{setView('home');setTimeout(()=>document.getElementById('family-management')?.scrollIntoView({behavior:'smooth'}),0)}}><Settings/>Configuración</button></>}</nav><div className="privacy-badge"><ShieldCheck/><span><strong>{child?'Modo infantil':'Espacio privado'}</strong>{child?'Acciones de adulto bloqueadas.':'Solo tu familia puede verlo.'}</span></div></aside>
      <section className="content"><span className="eyebrow"><Sparkles/> {view==='calendar'?'Tu historial':child?'Tu aventura':'Centro de mando familiar'}</span><h1>{view==='calendar'?'Calendario':child?`¡Hola, ${context.profile_name}!`:`Bienvenido, ${context.profile_name}`}</h1><p className="lead">{view==='calendar'?`Fechas calculadas en la zona horaria ${context.timezone}.`:child?'Este es tu espacio. Solo verás tus propias aventuras.':`Todo listo para organizar a ${context.family_name}.`}</p>
        {view==='calendar'?<MissionCalendar children={children} isChild={child}/>:child?<><ChildMissions/><ChildAvatar/><ChildRewards/></>:<><AdminOverview/><div id="mission-management"><MissionManager familyId={context.family_id} children={children}/></div><div id="reward-management"><RewardManager familyId={context.family_id} children={children}/></div><div id="family-management"><ProfileManager familyId={context.family_id} onChanged={()=>void loadChildren()}/></div><button className="secondary fit invite-admin" onClick={()=>setOpenInvite(true)}><Users/>Invitar administrador</button></>}
      </section>
    </div>
    {openInvite&&<div className="modal-backdrop" onMouseDown={()=>setOpenInvite(false)}><section className="modal" role="dialog" aria-modal="true" onMouseDown={e=>e.stopPropagation()}><button className="modal-close" onClick={()=>setOpenInvite(false)}>×</button><span className="invite-icon"><Users/></span><h2>Invita a otro adulto</h2><p>Compartirá los mismos permisos administrativos dentro de {context.family_name}.</p>{!link?<form onSubmit={invite}><label>Correo electrónico<input type="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="persona@correo.com"/></label>{error&&<div className="alert error">{error}</div>}<button className="primary" disabled={busy}>{busy?'Creando…':'Crear invitación segura'}</button></form>:<div className="invite-result"><div className="alert success">Invitación creada. Caduca en 7 días.</div><label>Enlace para compartir<div className="copy-row"><input readOnly value={link}/><button onClick={()=>navigator.clipboard.writeText(link)} aria-label="Copiar enlace"><Copy/></button></div></label></div>}</section></div>}
    {openPin&&<div className="modal-backdrop"><section className="modal pin-modal" role="dialog" aria-modal="true"><button className="modal-close" onClick={()=>setOpenPin(false)}>×</button><span className="invite-icon"><ShieldCheck/></span><h2>{pinPurpose==='set'?'Configura el PIN adulto':'Acceso de adulto'}</h2><p>{pinPurpose==='set'?'Se solicitará para salir del modo infantil.':'Introduce tu PIN para recuperar las funciones administrativas.'}</p><form onSubmit={submitPin}><label>PIN<input autoFocus inputMode="numeric" type="password" pattern="[0-9]{4,6}" minLength={4} maxLength={6} required value={pin} onChange={e=>setPin(e.target.value.replace(/\D/g,'').slice(0,6))} autoComplete="off"/></label>{error&&<div className="alert error" role="alert">{error}</div>}<button className="primary" disabled={busy}>{busy?'Verificando…':pinPurpose==='set'?'Guardar PIN':'Desbloquear'}</button></form></section></div>}
  </main>
}
