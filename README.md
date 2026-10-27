# Observatorio de Lluvias y Eventos de Manizales

Aplicación del taller **Laboratorio DevOps – Despliegue en AWS**: frontend React + Vite, API REST Spring Boot y PostgreSQL, desplegados en **tres ambientes (DEV, QA y PDN)** con AWS Amplify, AWS App Runner y Amazon RDS.

> Los datos iniciales son ficticios y sirven únicamente para pruebas académicas. No es un sistema oficial de alertas ni debe usarse para decisiones de emergencia.

## Ambientes

| Ambiente | Rama | Aplicación | API |
|----------|------|------------|-----|
| DEV | `develop` | https://develop.APP_ID.amplifyapp.com | https://API_DEV.awsapprunner.com |
| QA | `qa` | https://qa.APP_ID.amplifyapp.com | https://API_QA.awsapprunner.com |
| PDN | `main` | https://main.APP_ID.amplifyapp.com | https://API_PROD.awsapprunner.com |

Las URLs definitivas están en [`ENTREGA.md`](ENTREGA.md). La base de datos no se expone: se valida a través de la aplicación.

## Documentación
- [Arquitectura, ambientes, variables y rollback](docs/ARQUITECTURA.md)
- [Servicios, seguridad y costos](docs/SERVICIOS_SEGURIDAD_COSTOS.md)
- [Plan de pruebas y evidencias](docs/PLAN_PRUEBAS.md)
- [Desactivar y eliminar recursos](docs/LIMPIEZA.md)
- [Formato de entrega](ENTREGA.md)

## Componentes
- `frontend/`: React + Vite, dashboard y formularios. Pruebas con Vitest.
- `backend/`: Java 17 + Spring Boot + Spring Data JPA. Pruebas con JUnit, MockMvc y H2.
- `amplify.yml`: build del frontend en AWS Amplify (instala, prueba y compila por rama).
- `.github/workflows/`: `frontend.yml` (CI en PRs) y `backend.yml` (CI/CD del API a App Runner).
- `infra/`: scripts AWS CLI reproducibles para crear y eliminar la infraestructura.
- `scripts/smoke-test.sh`: pruebas de humo usadas por el pipeline.
- `docker-compose.yml`: PostgreSQL, API y frontend para ejecución local.
- `Jenkinsfile` / `deploy.sh.example`: pipeline de referencia alternativo (no usado en este despliegue).

## Pipeline

```
feature/* ──PR──> develop ──PR──> qa ──PR──> main
                    │              │           │
                  DEV            QA         PDN (aprobación manual)
```

| Evento | Frontend (Amplify) | API (GitHub Actions) |
|--------|--------------------|----------------------|
| Pull request | `frontend.yml`: `npm ci`, `npm test`, `npm run build` | `mvn test`, `mvn package` |
| Merge a `develop` | build + test + publicación DEV | test → imagen `dev` en ECR → App Runner DEV → smoke test |
| Merge a `qa` | publicación QA | imagen `qa` → App Runner QA → smoke test → aceptación manual |
| Merge a `main` | publicación PDN | **espera aprobación** (environment `production`) → imagen `prod` → App Runner PDN → smoke test |

Si falla una prueba, el build o el smoke test, el pipeline se detiene y la versión no avanza.

## Despliegue desde cero

Requisitos: cuenta AWS, [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure`), Docker y Bash (Git Bash en Windows).

```bash
BUDGET_EMAIL=tu@correo.com ./infra/00-budget.sh     # alerta de costos
./infra/01-ecr.sh                                   # repositorio ECR + imagen inicial
./infra/02-rds.sh                                   # RDS PostgreSQL privada (~10 min)
./infra/02b-init-db.sh                              # bases y usuarios dev/qa/prod
./infra/03-apprunner.sh                             # 3 servicios App Runner (imprime las URLs)
./infra/04-github-oidc.sh                           # rol para GitHub Actions (imprime AWS_ROLE_ARN)
```

1. **GitHub** > Settings > Secrets and variables > Actions > *Variables*: `AWS_ROLE_ARN` (salida del paso anterior).
2. **GitHub** > Settings > Environments: crear `development`, `qa` y `production` con la variable `FRONTEND_URL` de cada ambiente; en `production` activar *Required reviewers*.
3. **GitHub** > Settings > Branches: proteger `qa` y `main` (solo por pull request).
4. **Amplify** > Create new app > GitHub > este repositorio, rama `develop`, marcar *monorepo* con carpeta `frontend`. Luego *Add branch* para `qa` y `main`.
5. Con el ID de la app: `AMPLIFY_APP_ID=<id> ./infra/05-amplify-env.sh` (variables por rama, CORS y redeploy).

## Ejecutar localmente con Docker
Requisitos: Docker Desktop y Docker Compose.

```bash
docker compose up --build
```
- Frontend: http://localhost:5173
- API: http://localhost:8080/api/dashboard/summary
- Health: http://localhost:8080/actuator/health

Para detener: `docker compose down` (agregar `-v` para borrar también la base de datos local).

## Ejecutar sin Docker
### Backend
Requisitos: Java 17+, Maven 3.9+, PostgreSQL 15+. Configurar `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` y ejecutar:
```bash
cd backend
mvn spring-boot:run
```
Sin variables, usa H2 en memoria.

### Frontend
Requisitos: Node.js 20+.
```bash
cd frontend
npm install
npm run dev
```
Por defecto usa `http://localhost:8080` como API. Para otro destino, crear `frontend/.env.local`:
```env
VITE_API_URL=http://localhost:8080
VITE_APP_ENV=LOCAL
```

### Pruebas
```bash
cd frontend && npm test
cd backend && mvn test
./scripts/smoke-test.sh http://localhost:8080 http://localhost:5173
```

## Funcionalidades
- Registrar precipitación en milímetros por fecha y sector.
- Consultar registros de lluvia y acumulado diario.
- Registrar incidentes de congestión vehicular.
- Registrar reportes de deslizamientos.
- Ver resumen diario: lluvia acumulada, cantidad de incidentes y deslizamientos.
- Filtrar listados por fecha.

## Unidades
Se almacena precipitación en mm. El volumen estimado en litros solo se calcula si se proporciona el área de referencia en m²:
`litros_estimados = precipitación_mm × área_m²`.
No se debe presentar el resultado como volumen real de toda Manizales sin definir el área y la metodología.

## Equipo y roles

| Rol | Integrante |
|-----|------------|
| DevOps Lead / Release Manager | Yahir Rangel |
| Cloud / Infraestructura AWS | Carlos |
| CI/CD Backend | Kevin López |
| QA / Testing | Jhoan Zarza |
| Arquitectura, Seguridad y Documentación | Andrés Salazar |
