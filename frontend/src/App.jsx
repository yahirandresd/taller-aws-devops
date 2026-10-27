import { useEffect, useMemo, useState } from 'react'
import axios from 'axios'
import {
  CloudRain, CarFront, Mountain, Droplets, LayoutDashboard, Plus,
  RefreshCw, MapPin, CalendarDays, Activity, AlertTriangle, CheckCircle2,
  Waves, ExternalLink, Menu
} from 'lucide-react'

const API = (import.meta.env.VITE_API_URL || 'http://localhost:8080').replace(/\/$/, '')
const today = new Date().toISOString().slice(0, 10)
const sectors = ['Centro', 'Chipre', 'Palogrande', 'La Enea', 'Villamaría - referencia', 'Sector de prueba']
const navItems = [
  { id: 'dashboard', label: 'Resumen general', icon: LayoutDashboard },
  { id: 'rain', label: 'Precipitaciones', icon: CloudRain },
  { id: 'traffic', label: 'Caos vehicular', icon: CarFront },
  { id: 'landslides', label: 'Deslizamientos', icon: Mountain },
]

function fmt(value, digits = 1) {
  return Number(value || 0).toLocaleString('es-CO', { maximumFractionDigits: digits })
}
function dateLabel(value) {
  if (!value) return 'Sin fecha'
  return new Date(`${value}T12:00:00`).toLocaleDateString('es-CO', { day: '2-digit', month: 'short', year: 'numeric' })
}
function Tag({ children, tone = 'neutral' }) { return <span className={`tag ${tone}`}>{children}</span> }

export default function App() {
  const [active, setActive] = useState('dashboard')
  const [date, setDate] = useState(today)
  const [rain, setRain] = useState([])
  const [traffic, setTraffic] = useState([])
  const [landslides, setLandslides] = useState([])
  const [summary, setSummary] = useState({})
  const [loading, setLoading] = useState(false)
  const [notice, setNotice] = useState({ type: '', text: '' })
  const [showForm, setShowForm] = useState(false)
  const [mobileNav, setMobileNav] = useState(false)

  async function loadData() {
    setLoading(true)
    try {
      const [r, t, l, s] = await Promise.all([
        axios.get(`${API}/api/precipitations`, { params: { date } }),
        axios.get(`${API}/api/traffic-incidents`, { params: { date } }),
        axios.get(`${API}/api/landslides`, { params: { date } }),
        axios.get(`${API}/api/dashboard/summary`, { params: { date } })
      ])
      setRain(r.data); setTraffic(t.data); setLandslides(l.data); setSummary(s.data)
      setNotice({ type: '', text: '' })
    } catch {
      setNotice({ type: 'error', text: 'No fue posible conectar con la API. Verifica que el backend y la base de datos estén ejecutándose.' })
    } finally { setLoading(false) }
  }

  useEffect(() => { loadData() }, [date])

  const totalRain = Number(summary.precipitationTotalMm || 0)
  const rainMax = useMemo(() => Math.max(1, ...rain.map(x => Number(x.precipitationMm || 0))), [rain])
  const currentNav = navItems.find(x => x.id === active) || navItems[0]

  async function createRecord(event) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const val = Object.fromEntries(form.entries())
    try {
      let path = ''
      let payload = {}
      if (active === 'rain') {
        path = '/api/precipitations'
        payload = { recordDate: val.recordDate, sector: val.sector, stationName: val.stationName || val.sector,
          precipitationMm: Number(val.precipitationMm), source: val.source || 'Registro académico', observations: val.description || '' }
      } else if (active === 'traffic') {
        path = '/api/traffic-incidents'
        payload = { recordDate: val.recordDate, recordTime: val.recordTime, sector: val.sector,
          locationDescription: val.locationDescription, congestionLevel: val.congestionLevel, cause: val.cause,
          status: 'REPORTADO', description: val.description || '' }
      } else {
        path = '/api/landslides'
        payload = { recordDate: val.recordDate, recordTime: val.recordTime, sector: val.sector,
          locationDescription: val.locationDescription, severity: val.severity, affectedArea: val.affectedArea,
          status: 'REPORTADO', source: val.source || 'Registro académico', description: val.description || '' }
      }
      const formElement = event.currentTarget

      await axios.post(`${API}${path}`, payload)

      setShowForm(false)
      formElement.reset()

      setNotice({
        type: 'success',
        text: 'Registro guardado correctamente.'
      })

      await loadData()
    } catch (e) {
      const message = e?.response?.data?.message || 'No fue posible guardar el registro. Revisa los campos y la conexión con la API.'
      setNotice({ type: 'error', text: message })
    }
  }

  return <div className="app-shell">
    <aside className={`sidebar ${mobileNav ? 'open' : ''}`}>
      <div className="brand">
        <div className="brand-mark"><CloudRain size={23} /></div>
        <div><strong>OBSERVATORIO</strong><span>MANIZALES · DEMO</span></div>
      </div>
      <div className="side-caption">PLATAFORMA DE MONITOREO</div>
      <nav>{navItems.map(item => {
        const Icon = item.icon
        return <button key={item.id} className={`nav-item ${active === item.id ? 'selected' : ''}`}
          onClick={() => { setActive(item.id); setShowForm(false); setMobileNav(false); setNotice({ type: '', text: '' }) }}>
          <Icon size={18} /><span>{item.label}</span>
          {active === item.id && <span className="nav-dot" />}
        </button>
      })}</nav>
      <div className="sidebar-bottom">
        <div className="status-pill"><span className="pulse" /> Aplicación académica</div>
        <p>Datos de demostración. No es un sistema oficial de alertas.</p>
      </div>
    </aside>

    <main className="main">
      <header className="topbar">
        <button className="mobile-menu icon-button" onClick={() => setMobileNav(!mobileNav)} aria-label="Abrir menú"><Menu size={20}/></button>
        <div className="breadcrumb">Observatorio <span>/</span> {currentNav.label}</div>
        <div className="top-actions">
          <span className="env-badge"><span /> AMBIENTE CONFIGURABLE</span>
          <button className="icon-button" onClick={loadData} title="Actualizar datos" aria-label="Actualizar datos"><RefreshCw size={17} className={loading ? 'spin' : ''}/></button>
        </div>
      </header>

      <section className="content">
        <div className="page-heading">
          <div>
            <div className="eyebrow"><MapPin size={13}/> MANIZALES, CALDAS</div>
            <h1>{active === 'dashboard' ? 'Resumen de eventos' : currentNav.label}</h1>
            <p>Consulta y registra precipitaciones, movilidad y eventos de ladera.</p>
          </div>
          {active !== 'dashboard' && <button className="primary-button" onClick={() => { setShowForm(!showForm); setNotice({ type: '', text: '' }) }}>
            <Plus size={17}/>{showForm ? 'Cerrar formulario' : 'Nuevo registro'}
          </button>}
        </div>

        <div className="filter-bar">
          <div className="filter-label"><CalendarDays size={16}/><span>Fecha de consulta</span></div>
          <input type="date" value={date} onChange={e => setDate(e.target.value)} aria-label="Fecha de consulta"/>
          <span className="filter-hint">Datos registrados para {dateLabel(date)}</span>
        </div>

        {notice.text && <div className={`notice ${notice.type}`} role="status">{notice.type === 'success' ? <CheckCircle2 size={18}/> : <AlertTriangle size={18}/>}<span>{notice.text}</span></div>}

        {showForm && active !== 'dashboard' && <section className="panel form-panel">
          <div className="panel-heading"><div><span className="section-kicker">CAPTURA DE INFORMACIÓN</span><h2>Nuevo registro</h2></div><Tag tone="blue">Formulario</Tag></div>
          <form className="record-form" onSubmit={createRecord}>
            <label>Fecha <input name="recordDate" type="date" defaultValue={date} required /></label>
            <label>Sector
              <select name="sector" required defaultValue="">
                <option value="" disabled>Selecciona un sector</option>
                {sectors.map(s => <option key={s}>{s}</option>)}
              </select>
            </label>
            {active === 'rain' && <>
              <label>Estación / referencia <input name="stationName" placeholder="Ej. estación sector Centro" /></label>
              <label>Precipitación (mm) <input name="precipitationMm" type="number" min="0" step="0.1" placeholder="Ej. 12.5" required /></label>
              <label>Fuente del dato <input name="source" placeholder="Ej. medición de práctica" /></label>
              <label className="full">Observaciones <textarea name="description" rows="2" placeholder="Información adicional..." /></label>
            </>}
            {active === 'traffic' && <>
              <label>Hora <input name="recordTime" type="time" defaultValue="08:00" required /></label>
              <label>Vía o intersección <input name="locationDescription" placeholder="Describe el punto" required /></label>
              <label>Nivel de congestión <select name="congestionLevel"><option value="BAJO">Bajo</option><option value="MEDIO">Medio</option><option value="ALTO">Alto</option><option value="CRITICO">Crítico</option></select></label>
              <label>Causa <select name="cause"><option value="LLUVIA">Lluvia</option><option value="ACCIDENTE">Accidente</option><option value="CIERRE_VIAL">Cierre vial</option><option value="OBRA">Obra</option><option value="OTRA">Otra</option></select></label>
              <label className="full">Descripción <textarea name="description" rows="2" placeholder="Carriles afectados, fila estimada..." /></label>
            </>}
            {active === 'landslides' && <>
              <label>Hora <input name="recordTime" type="time" defaultValue="08:00" required /></label>
              <label>Ubicación <input name="locationDescription" placeholder="Describe el lugar" required /></label>
              <label>Severidad <select name="severity"><option value="BAJA">Baja</option><option value="MEDIA">Media</option><option value="ALTA">Alta</option><option value="CRITICA">Crítica</option></select></label>
              <label>Área afectada <select name="affectedArea"><option value="VIA">Vía</option><option value="VIVIENDA">Vivienda</option><option value="TALUD">Talud</option><option value="OTRA">Otra</option></select></label>
              <label>Fuente del dato <input name="source" placeholder="Ej. registro de práctica" /></label>
              <label className="full">Descripción <textarea name="description" rows="2" placeholder="Describe la afectación..." /></label>
            </>}
            <div className="form-actions full"><button type="button" className="secondary-button" onClick={() => setShowForm(false)}>Cancelar</button><button className="primary-button" type="submit">Guardar registro</button></div>
          </form>
        </section>}

        {active === 'dashboard' && <>
          <div className="hero-card">
            <div className="hero-copy">
              <span className="hero-overline"><Activity size={14}/> CENTRO DE OBSERVACIÓN</span>
              <h2>Clima, movilidad y territorio.<br/><em>Una sola vista.</em></h2>
              <p>Información capturada por el equipo para facilitar la consulta diaria de eventos.</p>
              <button className="hero-button" onClick={() => setActive('rain')}>Registrar precipitación <ExternalLink size={15}/></button>
            </div>
            <div className="rain-art" aria-hidden="true"><div className="sun-halo"/><CloudRain size={112} strokeWidth={1.05}/><div className="rain-drops">╱ ╱ ╱ ╱ ╱</div><div className="hill hill-one"/><div className="hill hill-two"/></div>
            <div className="hero-foot"><span><span className="live-dot"/> DATOS REGISTRADOS EN LA PLATAFORMA</span><span>{dateLabel(date)}</span></div>
          </div>

          <div className="section-title-row"><div><span className="section-kicker">INDICADORES DIARIOS</span><h2>Panorama del día</h2></div><span className="muted">{loading ? 'Actualizando…' : 'Última consulta: ' + dateLabel(date)}</span></div>
          <div className="metrics-grid">
            <Metric icon={Droplets} tone="teal" label="Lluvia acumulada" value={`${fmt(totalRain, 2)} mm`} foot={`${summary.precipitationRecords || 0} mediciones registradas`} />
            <Metric icon={CarFront} tone="amber" label="Incidentes viales" value={summary.trafficIncidents || 0} foot="Reportes para la fecha" />
            <Metric icon={Mountain} tone="coral" label="Deslizamientos" value={summary.landslides || 0} foot="Reportes para la fecha" />
            <Metric icon={Waves} tone="blue" label="Volumen de agua" value="—" foot="Requiere definir área en m²" />
          </div>

          <div className="dashboard-columns">
            <section className="panel">
              <div className="panel-heading"><div><span className="section-kicker">REGISTROS POR SECTOR</span><h2>Precipitaciones</h2></div><button className="text-button" onClick={() => setActive('rain')}>Ver registros →</button></div>
              {rain.length ? <div className="rain-list">{rain.slice(0,5).map(item => <div className="rain-row" key={item.id}>
                <div className="rain-icon"><CloudRain size={17}/></div><div className="rain-info"><strong>{item.sector}</strong><span>{item.stationName || 'Sin estación'} · {dateLabel(item.recordDate)}</span></div>
                <div className="rain-amount"><strong>{fmt(item.precipitationMm,2)} <small>mm</small></strong><div className="mini-bar"><span style={{width:`${Math.max(4,Number(item.precipitationMm)/rainMax*100)}%`}}/></div></div>
              </div>)}</div> : <EmptyState text="No hay mediciones de lluvia para esta fecha." />}
            </section>
            <section className="panel">
              <div className="panel-heading"><div><span className="section-kicker">EVENTOS REPORTADOS</span><h2>Actividad reciente</h2></div><Tag>{traffic.length + landslides.length} eventos</Tag></div>
              <div className="event-list">
                {[...traffic.map(x=>({...x,kind:'traffic'})),...landslides.map(x=>({...x,kind:'landslide'}))]
                  .sort((a,b)=>String(b.recordTime||'').localeCompare(String(a.recordTime||''))).slice(0,5).map((item,i) =>
                  <div className="event-row" key={`${item.kind}-${item.id || i}`}>
                    <div className={`event-icon ${item.kind}`} >{item.kind === 'traffic' ? <CarFront size={17}/> : <Mountain size={17}/>}</div>
                    <div className="event-info"><strong>{item.locationDescription}</strong><span>{item.sector} · {item.recordTime || 'Hora no indicada'}</span></div>
                    <Tag tone={String(item.congestionLevel || item.severity).includes('CRIT') ? 'red' : 'amber'}>{item.congestionLevel || item.severity}</Tag>
                  </div>)}
                {!traffic.length && !landslides.length && <EmptyState text="Aún no hay eventos registrados para esta fecha." />}
              </div>
            </section>
          </div>
          <div className="disclaimer"><AlertTriangle size={16}/><p><strong>Importante:</strong> esta es una aplicación académica. Los registros son aportados por usuarios y no representan datos oficiales ni alertas de emergencia de Manizales.</p></div>
        </>}

        {active === 'rain' && <RecordsPanel title="Registros de precipitación" subtitle="Mediciones por fecha y sector" icon={CloudRain}>
          {rain.length ? <div className="table-wrap"><table><thead><tr><th>Sector</th><th>Estación</th><th>Precipitación</th><th>Fuente</th><th>Observaciones</th></tr></thead><tbody>{rain.map(x=><tr key={x.id}><td><strong>{x.sector}</strong></td><td>{x.stationName}</td><td><span className="number-chip">{fmt(x.precipitationMm,2)} mm</span></td><td>{x.source || '—'}</td><td>{x.observations || '—'}</td></tr>)}</tbody></table></div> : <EmptyState text="No hay registros de lluvia para la fecha seleccionada." />}
        </RecordsPanel>}

        {active === 'traffic' && <RecordsPanel title="Incidentes de movilidad" subtitle="Reportes de congestión y afectación vial" icon={CarFront}>
          {traffic.length ? <div className="table-wrap"><table><thead><tr><th>Hora</th><th>Sector</th><th>Ubicación</th><th>Nivel</th><th>Causa</th><th>Estado</th></tr></thead><tbody>{traffic.map(x=><tr key={x.id}><td>{x.recordTime}</td><td>{x.sector}</td><td>{x.locationDescription}</td><td><Tag tone={x.congestionLevel?.includes('CRIT')?'red':'amber'}>{x.congestionLevel}</Tag></td><td>{x.cause}</td><td>{x.status}</td></tr>)}</tbody></table></div> : <EmptyState text="No hay incidentes viales para la fecha seleccionada." />}
        </RecordsPanel>}

        {active === 'landslides' && <RecordsPanel title="Reportes de deslizamientos" subtitle="Seguimiento de eventos de ladera" icon={Mountain}>
          {landslides.length ? <div className="table-wrap"><table><thead><tr><th>Hora</th><th>Sector</th><th>Ubicación</th><th>Severidad</th><th>Afectación</th><th>Estado</th></tr></thead><tbody>{landslides.map(x=><tr key={x.id}><td>{x.recordTime}</td><td>{x.sector}</td><td>{x.locationDescription}</td><td><Tag tone={x.severity?.includes('CRIT')?'red':'amber'}>{x.severity}</Tag></td><td>{x.affectedArea}</td><td>{x.status}</td></tr>)}</tbody></table></div> : <EmptyState text="No hay deslizamientos para la fecha seleccionada." />}
        </RecordsPanel>}
        <footer className="footer"><span>OBSERVATORIO · PROYECTO ACADÉMICO DEVOPS</span><span>React · Spring Boot · PostgreSQL</span></footer>
      </section>
    </main>
  </div>
}

function Metric({icon: Icon,tone,label,value,foot}) {
  return <div className="metric-card"><div className={`metric-icon ${tone}`}><Icon size={20}/></div><div className="metric-label">{label}</div><div className="metric-value">{value}</div><div className="metric-foot">{foot}</div></div>
}
function EmptyState({text}) { return <div className="empty-state"><div className="empty-icon"><Activity size={20}/></div><p>{text}</p><span>Los registros aparecerán aquí al guardar información.</span></div> }
function RecordsPanel({title,subtitle,icon:Icon,children}) {
  return <section className="panel records-panel"><div className="panel-heading"><div className="record-title"><div className="record-title-icon"><Icon size={20}/></div><div><span className="section-kicker">OBSERVATORIO / REGISTROS</span><h2>{title}</h2><p>{subtitle}</p></div></div><Tag tone="blue">Listado</Tag></div>{children}</section>
}
