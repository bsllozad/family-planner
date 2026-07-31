import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './auth/AuthProvider'
import { LoginPage } from './pages/LoginPage'
import { OnboardingPage } from './pages/OnboardingPage'
import { AcceptInvitePage } from './pages/AcceptInvitePage'
import { DashboardPage } from './pages/DashboardPage'
import { useI18n } from './i18n'

function Home(){const {session,context,loading}=useAuth();const {t}=useI18n();if(loading)return <div className="splash"><span className="brand-mark">K</span><p>{t('loading')}</p></div>;if(!session)return <Navigate to="/login" replace/>;if(!context)return <Navigate to="/onboarding" replace/>;return <DashboardPage/>}
export function App(){return <Routes><Route path="/" element={<Home/>}/><Route path="/login" element={<LoginPage/>}/><Route path="/onboarding" element={<OnboardingPage/>}/><Route path="/invite/:token" element={<AcceptInvitePage/>}/><Route path="*" element={<Navigate to="/" replace/>}/></Routes>}
