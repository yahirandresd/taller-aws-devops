# Entrega – Taller práctico: Despliegue de aplicaciones e infraestructura en la nube

| Campo | Respuesta del equipo |
|-------|----------------------|
| Integrantes | Yahir Rangel · Carlos · Kevin López · Jhoan Zarza · Andrés Salazar |
| Modalidad | A – Aplicación base proporcionada por el docente (Observatorio de Lluvias Manizales) |
| Plataforma principal | AWS Amplify (frontend) + AWS App Runner (API) + Amazon RDS PostgreSQL; CI/CD con Amplify y GitHub Actions |
| Repositorio | https://github.com/yahirandresd/taller-aws-devops |
| URL DEV | _pendiente_ |
| URL QA | _pendiente_ |
| URL PDN/Producción | _pendiente_ |
| API DEV / QA / PDN | _pendiente_ / _pendiente_ / _pendiente_ |
| Base de datos y estrategia de persistencia | Amazon RDS for PostgreSQL (`db.t4g.micro`, privada, cifrada). Una base y un usuario por ambiente (`observatorio_dev`, `observatorio_qa`, `observatorio_prod`); claves en AWS Secrets Manager inyectadas en App Runner. Sin acceso público. |
| Pipeline | Frontend: builds de Amplify por rama (`amplify.yml`). API: [GitHub Actions – Backend CI/CD](https://github.com/yahirandresd/taller-aws-devops/actions). Evidencias en [`docs/PLAN_PRUEBAS.md`](docs/PLAN_PRUEBAS.md). |
| Video | No aplica para esta entrega. |
| Costos y limpieza | ≈ USD 17–33/mes con los tres ambientes (App Runner ×3, RDS, Secrets Manager). Detalle en [`docs/SERVICIOS_SEGURIDAD_COSTOS.md`](docs/SERVICIOS_SEGURIDAD_COSTOS.md); eliminación con `infra/99-cleanup.sh` según [`docs/LIMPIEZA.md`](docs/LIMPIEZA.md). |

## URLs por ambiente

| Ambiente | URL de la aplicación | URL de API | Estado |
|----------|----------------------|------------|--------|
| DEV | _pendiente_ | _pendiente_ | Pendiente de validar |
| QA | _pendiente_ | _pendiente_ | Pendiente de validar |
| PDN / Producción | _pendiente_ | _pendiente_ | Pendiente de validar |

## Roles del equipo

| Rol | Integrante | Entregables |
|-----|------------|-------------|
| DevOps Lead / Release Manager | Yahir Rangel | Repositorio y ramas, `amplify.yml`, Amplify, aprobación de PDN, esta entrega |
| Cloud / Infraestructura AWS | Carlos | `infra/` (ECR, RDS, App Runner, OIDC, limpieza) |
| CI/CD Backend | Kevin López | `.github/workflows/` |
| QA / Testing | Jhoan Zarza | Pruebas automatizadas, `scripts/smoke-test.sh`, `docs/PLAN_PRUEBAS.md` |
| Arquitectura, Seguridad y Documentación | Andrés Salazar | `README.md`, `docs/` |
