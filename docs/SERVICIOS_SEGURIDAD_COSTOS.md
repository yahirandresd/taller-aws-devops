# Servicios, seguridad y costos

Región: `us-east-1`. Precios de referencia de lista (pueden variar); verificar en la [calculadora de AWS](https://calculator.aws/).

## Servicios utilizados

| Servicio | Uso | Configuración de seguridad | Costo estimado / mes |
|----------|-----|----------------------------|----------------------|
| **AWS Amplify Hosting** | Build y hosting del frontend, 3 ramas | HTTPS gestionado (CloudFront). Variables por rama, sin secretos (todo lo que va en `VITE_*` es público en el navegador). Acceso a GitHub vía GitHub App con permisos solo al repo. | ≈ USD 0 (free tier: 1 000 min de build, 5 GB almacenados, 15 GB servidos). Fuera de free tier: USD 0.01/min de build. |
| **AWS App Runner** ×3 | API Spring Boot por ambiente | HTTPS por defecto. Contenedor sin credenciales embebidas; la clave de BD llega desde Secrets Manager por el rol de instancia (solo `GetSecretValue` sobre `observatorio/*`). Auto scaling limitado a 1 instancia. Salida por VPC connector. | 1 GB en reposo × 730 h × USD 0.007 ≈ **USD 5.1 por servicio** → ≈ **USD 15** + uso activo (USD 0.064/vCPU-h mientras atiende peticiones). |
| **Amazon ECR** | Imágenes del API (`dev`, `qa`, `prod`, `<env>-<sha>`) | Escaneo de vulnerabilidades al subir. Política de ciclo de vida: máximo 15 imágenes. Solo el rol de GitHub puede publicar. | < USD 0.20 (USD 0.10/GB). |
| **Amazon RDS PostgreSQL** | Persistencia, `db.t4g.micro`, 20 GB gp2 | **No accesible públicamente.** SG que solo admite 5432 desde el SG del VPC connector. Almacenamiento cifrado (KMS). Usuario y base distintos por ambiente. Backups automáticos 1 día. | Free tier (750 h + 20 GB) si la cuenta lo tiene; si no ≈ USD 11.7 instancia + USD 2.3 almacenamiento ≈ **USD 14**. |
| **AWS Secrets Manager** | Clave maestra + 3 claves de BD | Cifrado KMS; acceso solo por IAM. Nada de esto está en Git. | 4 × USD 0.40 = **USD 1.6**. |
| **IAM + OIDC** | Rol para GitHub Actions | Sin access keys en GitHub. El rol solo confía en `repo:yahirandresd/taller-aws-devops:*` y solo puede publicar en el repo ECR y desplegar los servicios `observatorio-api-*`. | Gratis. |
| **CloudWatch Logs** | Logs de App Runner | Retención por defecto; revisar al cerrar. | Free tier 5 GB. |
| **AWS Budgets** | Alerta al 80 % de USD 10 | Notificación por correo. | Gratis (2 presupuestos). |

**Total aproximado:** USD 17 – 33 / mes con los tres ambientes encendidos (el rango depende de si aplica el free tier de RDS). Por eso existe [`LIMPIEZA.md`](LIMPIEZA.md).

### Recursos que generan cargos aunque nadie use la app
1. App Runner (memoria aprovisionada de los 3 servicios).
2. RDS (horas de instancia y almacenamiento).
3. Secrets Manager (por secreto, por mes).

Para pausar sin borrar: `aws apprunner pause-service --service-arn <arn>` (deja de cobrar cómputo) y `aws rds stop-db-instance --db-instance-identifier observatorio-db` (se reinicia sola a los 7 días).

## Medidas de seguridad aplicadas
- **Sin secretos en el repositorio:** `.gitignore` excluye `.env*`; las claves se generan con `openssl rand` dentro de los scripts y se guardan solo en Secrets Manager.
- **Mínimo privilegio:** tres roles IAM separados (acceso a ECR de App Runner, instancia de App Runner, despliegue de GitHub) con permisos acotados a los recursos `observatorio`.
- **Base privada:** RDS sin IP pública. `infra/02b-init-db.sh` la abre temporalmente solo a la IP de quien ejecuta la inicialización y la cierra al terminar (`trap`).
- **HTTPS extremo a extremo** en frontend y API; la conexión API → RDS usa SSL (PostgreSQL de RDS exige SSL por defecto).
- **CORS restringido:** cada API solo acepta el origen de la URL Amplify de su ambiente.
- **Promoción controlada:** PDN exige aprobación en el environment `production` de GitHub y ramas protegidas (`qa` y `main` solo por PR).

## Pendiente para un sistema real (fuera del alcance del taller)
- Autenticación/autorización para crear y editar reportes (hoy la API es abierta).
- Instancia RDS dedicada y Multi-AZ para PDN, backups de más días.
- WAF delante de Amplify/App Runner y límites de tasa.
- Dominio propio con certificados ACM.
