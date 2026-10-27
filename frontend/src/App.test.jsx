import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import App from './App.jsx'
import axios from 'axios'
import { vi } from 'vitest'

vi.mock('axios', () => ({
  default: {
    get: vi.fn((url) => Promise.resolve({ data: url.includes('dashboard') ? {
      date: '2026-10-21', precipitationRecords: 0, precipitationTotalMm: 0, trafficIncidents: 0, landslides: 0
    } : [] })),
    post: vi.fn()
  }
}))

describe('Observatorio', () => {
  it('muestra el nombre del sistema', async () => {
    render(<App />)
    expect(await screen.findByText('Resumen de eventos')).toBeInTheDocument()
    expect(screen.getByText('OBSERVATORIO')).toBeInTheDocument()
  })
})
