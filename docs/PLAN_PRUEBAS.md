# Plan de pruebas – Observatorio de Lluvias Manizales

Responsable QA: Jhoan Zarza (jhoan.zarza45081@ucaldas.edu.co)

## 1. Niveles de prueba

| Nivel | Herramienta | Dónde corre | Qué cubre | ¿Bloquea el despliegue? |
|-------|-------------|-------------|-----------|-------------------------|
| Unitarias frontend | Vitest + Testing Library (`frontend/src/App.test.jsx`) | Build de Amplify (`amplify.yml`) | Render del dashboard, llamadas a los 4 endpoints, mensaje de error si la API no responde | Sí: si falla `npm test` Amplify no publica |
| Integración backend | JUnit 5 + MockMvc + H2 (`backend/src/test/...`) | GitHub Actions `backend.yml` | Arranque del contexto, crear/listar lluvia, resumen diario, validación (precipitación negativa → 400), cambio de estado de incidente, `/actuator/health` | Sí: si falla `mvn test` no se construye ni publica la imagen |
| Humo (smoke) | `scripts/smoke-test.sh` | GitHub Actions después de cada despliegue | API arriba (`/actuator/health` = UP), dashboard y listado responden, frontend responde | Sí: marca el job en rojo y no se promueve |
| Aceptación (manual) | Checklist de la sección 3 | Ambiente QA | Flujos de usuario de punta a punta | Sí: sin aprobación de QA no se abre PR `qa → main` |

## 2. Ejecución local

```bash
# Frontend
cd frontend && npm ci && npm test

# Backend (requiere Maven; alternativa con Docker)
cd backend && mvn test
docker run --rm -v "$PWD/backend:/app" -w /app maven:3.9-eclipse-temurin-17 mvn -B test

# Humo contra un ambiente
./scripts/smoke-test.sh https://<api-del-ambiente> https://<frontend-del-ambiente>
```

## 3. Checklist de aceptación en QA

| # | Caso | Pasos | Resultado esperado | Resultado |
|---|------|-------|--------------------|-----------|
| A1 | Carga del dashboard | Abrir URL QA | Se ve "Resumen de eventos", badge de ambiente **QA**, sin mensaje de error de API | ☐ |
| A2 | Registrar lluvia | Lluvias → Nuevo registro → sector, mm, fecha → Guardar | "Registro guardado correctamente." y aparece en el listado | ☐ |
| A3 | Acumulado diario | Registrar dos lluvias el mismo día | El total del resumen = suma de ambas | ☐ |
| A4 | Validación | Registrar lluvia con mm negativos | La API rechaza (400) y se muestra mensaje de error | ☐ |
| A5 | Incidente vehicular | Registrar congestión | Aparece en listado con estado REPORTADO | ☐ |
| A6 | Deslizamiento | Registrar deslizamiento | Aparece en listado y suma en el resumen | ☐ |
| A7 | Filtro por fecha | Cambiar la fecha | Listados y resumen cambian a esa fecha | ☐ |
| A8 | Aislamiento de ambientes | Crear un registro en DEV | **No** aparece en QA ni en PDN | ☐ |
| A9 | HTTPS | Revisar candado en las 3 URLs | Certificado válido en frontend y API | ☐ |

## 4. Evidencias por ambiente

| Ambiente | Build Amplify | Run GitHub Actions | Smoke test | Aceptación | Fecha |
|----------|---------------|--------------------|------------|------------|-------|
| DEV | _enlace_ | _enlace_ | ☐ | n/a | |
| QA | _enlace_ | _enlace_ | ☐ | ☐ A1–A9 | |
| PDN | _enlace_ | _enlace_ | ☐ | ☐ A1, A9 | |

## 5. Criterio de salida
- 0 pruebas automáticas fallidas.
- Smoke test verde en el ambiente.
- Para promover a PDN: checklist A1–A9 aprobado en QA y aprobación del Release Manager en GitHub (environment `production`).
