#!/usr/bin/env bash
# Elimina TODOS los recursos del taller para que no sigan generando cargos.
# Uso: AMPLIFY_APP_ID=d123abc ./infra/99-cleanup.sh [--yes]
# Irreversible: borra la base de datos sin snapshot final.
source "$(dirname "$0")/config.sh"

if [ "${1:-}" != "--yes" ]; then
  read -r -p "Se eliminarán App Runner, RDS (sin snapshot), ECR, secretos, roles y Amplify en $ACCOUNT_ID/$AWS_REGION. Escriba ELIMINAR: " ok
  [ "$ok" = "ELIMINAR" ] || { echo "Cancelado"; exit 1; }
fi
try() { "$@" >/dev/null 2>&1 || true; }

log "1. Servicios App Runner"
for env in "${ENVS[@]}"; do
  arn="$(service_arn "$env")"
  [ "$arn" != "None" ] && try aws apprunner delete-service --service-arn "$arn"
done
for env in "${ENVS[@]}"; do
  while [ "$(service_arn "$env")" != "None" ] && \
        [ "$(aws apprunner describe-service --service-arn "$(service_arn "$env")" --query Service.Status --output text 2>/dev/null)" != "DELETED" ]; do
    sleep 15
  done
done

log "2. VPC connector y auto scaling"
for arn in $(aws apprunner list-vpc-connectors --query "VpcConnectors[?VpcConnectorName=='$VPC_CONNECTOR'].VpcConnectorArn" --output text); do
  try aws apprunner delete-vpc-connector --vpc-connector-arn "$arn"
done
for arn in $(aws apprunner list-auto-scaling-configurations --auto-scaling-configuration-name "$AUTOSCALING_NAME" \
    --query 'AutoScalingConfigurationSummaryList[].AutoScalingConfigurationArn' --output text); do
  try aws apprunner delete-auto-scaling-configuration --auto-scaling-configuration-arn "$arn"
done

log "3. RDS (sin snapshot final)"
if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" >/dev/null 2>&1; then
  aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE" --skip-final-snapshot --delete-automated-backups >/dev/null
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_INSTANCE"
fi

log "4. Grupos de seguridad (las ENI del connector pueden tardar en liberarse)"
for name in "$SG_RDS_NAME" "$SG_CONNECTOR_NAME"; do
  id="$(sg_id "$name")"
  [ "$id" = "None" ] && continue
  for _ in $(seq 1 20); do aws ec2 delete-security-group --group-id "$id" >/dev/null 2>&1 && break; sleep 30; done
done

log "5. Secretos"
try aws secretsmanager delete-secret --secret-id "$DB_ADMIN_SECRET" --force-delete-without-recovery
for env in "${ENVS[@]}"; do
  try aws secretsmanager delete-secret --secret-id "$(db_secret "$env")" --force-delete-without-recovery
done

log "6. Repositorio ECR"
try aws ecr delete-repository --repository-name "$ECR_REPO" --force

log "7. Roles IAM y proveedor OIDC"
try aws iam detach-role-policy --role-name "$ROLE_ECR_ACCESS" --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess
try aws iam delete-role --role-name "$ROLE_ECR_ACCESS"
try aws iam delete-role-policy --role-name "$ROLE_INSTANCE" --policy-name leer-secretos-bd
try aws iam delete-role --role-name "$ROLE_INSTANCE"
try aws iam delete-role-policy --role-name "$ROLE_GITHUB" --policy-name despliegue-observatorio
try aws iam delete-role --role-name "$ROLE_GITHUB"
try aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"

log "8. Amplify"
if [ -n "${AMPLIFY_APP_ID:-}" ]; then
  try aws amplify delete-app --app-id "$AMPLIFY_APP_ID"
else
  echo "AMPLIFY_APP_ID no definido: elimine la app manualmente en la consola de Amplify."
fi

log "9. Presupuesto"
try aws budgets delete-budget --account-id "$ACCOUNT_ID" --budget-name "$PROJECT-mensual"

log "Limpieza terminada. Verifique en Billing > Bills que no queden cargos activos."
