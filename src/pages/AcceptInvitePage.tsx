import { useEffect, useState } from 'react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { Check, Users } from 'lucide-react'
import { useAuth } from '../auth/AuthProvider'
import { supabase } from '../lib/supabase'

export function AcceptInvitePage(){const {token}=useParams();const nav=useNavigate();const {session,refreshContext}=useAuth();const [state,setState]=useState<'ready'|'busy'|'done'|'error'>('ready');const accept=async()=>{if(!token)return;setState('busy');const {error}=await supabase.rpc('accept_family_invitation',{p_token:token});if(error){setState('error');return}await refreshContext();setState('done');setTimeout(()=>nav('/'),900)};useEffect(()=>{if(session&&state==='ready')void accept()},[session]);if(!session)return <Navigate to={`/login?next=${encodeURIComponent(`/invite/${token}`)}`} replace/>;return <main className="center-page"><section className="onboarding-card compact"><div className="invite-icon">{state==='done'?<Check/>:<Users/>}</div><h1>{state==='done'?'¡Ya eres parte del equipo!':'Uniéndote a la familia…'}</h1><p>{state==='error'?'La invitación expiró, ya fue utilizada o pertenece a otro correo. Pide un enlace nuevo.':'Estamos preparando tu espacio compartido.'}</p>{state==='error'&&<button className="secondary" onClick={()=>nav('/')}>Volver</button>}</section></main>}
