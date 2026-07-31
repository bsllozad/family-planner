import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useAuth } from './auth/AuthProvider'
import { supabase } from './lib/supabase'

export type Language = 'es' | 'en'

const messages = {
  es: {
    loading:'Preparando tu aventura…', adultMode:'Modo adulto', switchProfile:'Cambiar de perfil…', signOut:'Cerrar sesión',
    explorer:'Explorador', home:'Inicio', calendar:'Calendario', family:'Familia', settings:'Configuración', childMode:'Modo infantil',
    privateSpace:'Espacio privado', childLocked:'Acciones de adulto bloqueadas.', familyPrivate:'Solo tu familia puede verlo.', history:'Tu historial',
    adventure:'Tu aventura', commandCenter:'Centro de mando familiar', hello:'¡Hola, {name}!', welcome:'Bienvenido, {name}',
    timezone:'Fechas calculadas en la zona horaria {timezone}.', childIntro:'Este es tu espacio. Solo verás tus propias aventuras.',
    adminIntro:'Todo listo para organizar a {family}.', inviteAdmin:'Invitar administrador', language:'Idioma', offline:'Estás sin conexión. Puedes consultar los últimos datos sincronizados.',
    xpOnline:'Las acciones que cambian XP necesitan conexión.', skip:'Saltar al contenido', close:'Cerrar',
  },
  en: {
    loading:'Preparing your adventure…', adultMode:'Adult mode', switchProfile:'Switch profile…', signOut:'Sign out',
    explorer:'Explorer', home:'Home', calendar:'Calendar', family:'Family', settings:'Settings', childMode:'Child mode',
    privateSpace:'Private space', childLocked:'Adult actions are locked.', familyPrivate:'Only your family can see this.', history:'Your history',
    adventure:'Your adventure', commandCenter:'Family command center', hello:'Hi, {name}!', welcome:'Welcome, {name}',
    timezone:'Dates are calculated in the {timezone} time zone.', childIntro:'This is your space. You will only see your own adventures.',
    adminIntro:'Everything is ready to organize {family}.', inviteAdmin:'Invite administrator', language:'Language', offline:'You are offline. Your latest synced data is still available.',
    xpOnline:'Actions that change XP require a connection.', skip:'Skip to content', close:'Close',
  },
} as const

type Key = keyof typeof messages.es
type I18nValue = {language:Language; setLanguage:(language:Language)=>Promise<void>; t:(key:Key, values?:Record<string,string>)=>string}
const I18nContext=createContext<I18nValue|null>(null)

export function I18nProvider({children}:{children:ReactNode}){
  const {context,refreshContext}=useAuth()
  const [selected,setSelected]=useState<Language>(()=>(localStorage.getItem('kinquest-language') as Language|null)??(navigator.language.startsWith('en')?'en':'es'))
  const language=selected
  useEffect(()=>{if(context?.language)setSelected(context.language)},[context?.language])
  useEffect(()=>{document.documentElement.lang=language;localStorage.setItem('kinquest-language',language)},[language])
  const value=useMemo<I18nValue>(()=>({language,setLanguage:async(next)=>{
    setSelected(next);localStorage.setItem('kinquest-language',next);document.documentElement.lang=next
    if(context?.profile_id){const {error}=await supabase.rpc('set_my_language',{p_language:next});if(error){setSelected(language);throw error}await refreshContext()}
  },t:(key,values={})=>Object.entries(values).reduce((text,[name,value])=>text.replace(`{${name}}`,value),messages[language][key] as string)}),[context?.profile_id,language,refreshContext])
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>
}

export function useI18n(){const value=useContext(I18nContext);if(!value)throw new Error('useI18n requires I18nProvider');return value}
