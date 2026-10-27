import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import App from './App.jsx'
import axios from 'axios'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn()
  }
}))

const summary = {
  date: '2026-10-21', precipitationRecords: 0, precipitationTotalMm: 0, trafficIncidents: 0, landslides: 0
}

describe('Observatorio', () => {
  beforeEach(() => {
    axios.get.mockReset()
    axios.get.mockImplementation((url) => Promise.resolve({ data: url.includes('dashboard') ? summary : [] }))
  })

  it('muestra el nombre del sistema', async () => {
    render(<App />)
    expect(await screen.findByText('Resumen de eventos')).toBeInTheDocument()
    expect(screen.getByText('OBSERVATORIO')).toBeInTheDocument()
  })

  it('consulta los cuatro endpoints de la API al cargar', async () => {
    render(<App />)
    await screen.findByText('Resumen de eventos')
    const urls = axios.get.mock.calls.map(([url]) => url)
    expect(urls.some(u => u.endsWith('/api/precipitations'))).toBe(true)
    expect(urls.some(u => u.endsWith('/api/traffic-incidents'))).toBe(true)
    expect(urls.some(u => u.endsWith('/api/landslides'))).toBe(true)
    expect(urls.some(u => u.endsWith('/api/dashboard/summary'))).toBe(true)
  })

  it('informa cuando la API no responde', async () => {
    axios.get.mockImplementation(() => Promise.reject(new Error('Network Error')))
    render(<App />)
    expect(await screen.findByText(/No fue posible conectar con la API/)).toBeInTheDocument()
  })
})
