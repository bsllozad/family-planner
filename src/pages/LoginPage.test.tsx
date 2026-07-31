import { cleanup, render,screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { LoginPage } from './LoginPage'

vi.mock('../auth/AuthProvider',()=>({useAuth:()=>({session:null})}))
vi.mock('../lib/supabase',()=>({isSupabaseConfigured:true,supabase:{auth:{signInWithPassword:vi.fn(async()=>({error:{message:'bad'}})),signUp:vi.fn(),signInWithOtp:vi.fn()}}}))
afterEach(cleanup)
describe('LoginPage',()=>{it('valida datos sin enviar información',async()=>{render(<MemoryRouter><LoginPage/></MemoryRouter>);await userEvent.click(screen.getByRole('button',{name:'Entrar a mi familia'}));expect(screen.getByRole('alert')).toHaveTextContent('correo válido')});it('muestra un error genérico para credenciales inválidas',async()=>{render(<MemoryRouter><LoginPage/></MemoryRouter>);await userEvent.type(screen.getByLabelText('Correo electrónico'),'padre@example.com');await userEvent.type(screen.getByLabelText('Contraseña'),'secreto');await userEvent.click(screen.getByRole('button',{name:'Entrar a mi familia'}));expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos iniciar sesión')})})
