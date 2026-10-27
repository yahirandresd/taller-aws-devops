# Procedimiento para desactivar y eliminar recursos

Al terminar la evaluación del taller se deben eliminar los recursos para que no sigan generando cargos.

## Opción 1: script (recomendada)

```bash
AMPLIFY_APP_ID=<id-de-la-app> ./infra/99-cleanup.sh
# pide escribir ELIMINAR para confirmar
```

El script elimina, en este orden (respetando dependencias):

| # | Recurso | Por qué en este orden |
|---|---------|------------------------|
| 1 | Servicios App Runner `observatorio-api-dev/qa/prod` | Dejan de usar el VPC connector y las imágenes |
| 2 | VPC connector y configuración de auto scaling | Libera las interfaces de red en la VPC |
| 3 | RDS `observatorio-db` **sin snapshot final** | Ya no hay servicios conectados |
| 4 | Security groups `observatorio-rds-sg` y `observatorio-apprunner-sg` | Solo se pueden borrar cuando nada los usa |
| 5 | Secretos `observatorio/*` (sin periodo de recuperación) | Dejan de cobrar de inmediato |
| 6 | Repositorio ECR `observatorio-api` con sus imágenes | |
| 7 | Roles IAM y proveedor OIDC de GitHub | Quita el acceso de GitHub Actions a la cuenta |
| 8 | App de Amplify | Elimina las tres URLs de frontend |
| 9 | Presupuesto `observatorio-mensual` | |

> ⚠️ Es irreversible: los datos de las tres bases se pierden. Si se quiere conservar evidencia, exportar antes con `pg_dump` o tomar un snapshot manual (que también cobra almacenamiento).

## Opción 2: consola de AWS
Mismo orden de la tabla: App Runner → (Networking) VPC connectors → RDS → EC2 > Security groups → Secrets Manager → ECR → IAM (roles `observatorio-*` e Identity providers) → Amplify → Billing > Budgets.

## Verificación final
1. **Billing > Bills**: el mes en curso no muestra nuevos cargos de App Runner, RDS ni Secrets Manager.
2. **Resource Groups > Tag Editor**: buscar la etiqueta `project = observatorio` en todas las regiones → sin resultados.
3. En GitHub, desactivar los workflows (Actions > workflow > *Disable workflow*) o borrar la variable `AWS_ROLE_ARN`.

## Pausar en vez de eliminar (entre clases)
```bash
source infra/config.sh
for env in dev qa prod; do aws apprunner pause-service --service-arn "$(service_arn $env)"; done
aws rds stop-db-instance --db-instance-identifier observatorio-db
# Reanudar: resume-service y start-db-instance
```
