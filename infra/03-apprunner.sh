#!/usr/bin/env bash
# API Spring Boot en AWS App Runner: un servicio por ambiente, conectado a RDS por un
# VPC connector. La clave de BD se inyecta desde Secrets Manager (nunca va en el repo).
#
# Primera vez:   ./infra/03-apprunner.sh
# Tras crear Amplify (para fijar CORS a las URLs reales):
#                AMPLIFY_APP_ID=d123abc ./infra/03-apprunner.sh
source "$(dirname "$0")/config.sh"

VPC_ID="$(default_vpc)"
SG_CONNECTOR="$(sg_id "$SG_CONNECTOR_NAME")"
DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[0].Endpoint.Address' --output text)"

ensure_role() {
  local name="$1" service="$2"
  if ! aws iam get-role --role-name "$name" >/dev/null 2>&1; then
    aws iam create-role --role-name "$name" --assume-role-policy-document \
      "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"$service\"},\"Action\":\"sts:AssumeRole\"}]}" >/dev/null
    sleep 10   # propagación de IAM
  fi
  aws iam get-role --role-name "$name" --query Role.Arn --output text
}

log "Roles IAM"
ECR_ROLE_ARN="$(ensure_role "$ROLE_ECR_ACCESS" build.apprunner.amazonaws.com)"
aws iam attach-role-policy --role-name "$ROLE_ECR_ACCESS" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess
INSTANCE_ROLE_ARN="$(ensure_role "$ROLE_INSTANCE" tasks.apprunner.amazonaws.com)"
aws iam put-role-policy --role-name "$ROLE_INSTANCE" --policy-name leer-secretos-bd --policy-document \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"secretsmanager:GetSecretValue\",\"Resource\":\"arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:$PROJECT/*\"}]}"

log "VPC connector $VPC_CONNECTOR"
CONNECTOR_ARN="$(aws apprunner list-vpc-connectors --query "VpcConnectors[?VpcConnectorName=='$VPC_CONNECTOR' && Status=='ACTIVE'].VpcConnectorArn | [0]" --output text)"
if [ "$CONNECTOR_ARN" = "None" ]; then
  # use1-az3 no es compatible con App Runner; se excluye.
  SUBNETS="$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[?AvailabilityZoneId!='use1-az3'].SubnetId" --output text)"
  CONNECTOR_ARN="$(aws apprunner create-vpc-connector --vpc-connector-name "$VPC_CONNECTOR" \
    --subnets $SUBNETS --security-groups "$SG_CONNECTOR" --query VpcConnector.VpcConnectorArn --output text)"
fi

log "Auto scaling (máximo 1 instancia para controlar costos)"
SCALING_ARN="$(aws apprunner list-auto-scaling-configurations --auto-scaling-configuration-name "$AUTOSCALING_NAME" \
  --query 'AutoScalingConfigurationSummaryList[0].AutoScalingConfigurationArn' --output text)"
if [ "$SCALING_ARN" = "None" ]; then
  SCALING_ARN="$(aws apprunner create-auto-scaling-configuration --auto-scaling-configuration-name "$AUTOSCALING_NAME" \
    --min-size 1 --max-size 1 --max-concurrency 100 \
    --query AutoScalingConfiguration.AutoScalingConfigurationArn --output text)"
fi

cors_for() {
  if [ -n "${AMPLIFY_APP_ID:-}" ]; then
    echo "https://$(branch_of "$1").$AMPLIFY_APP_ID.amplifyapp.com"
  else
    echo "http://localhost:5173"
  fi
}

wait_running() {
  local arn="$1" status
  for _ in $(seq 1 90); do
    status="$(aws apprunner describe-service --service-arn "$arn" --query Service.Status --output text)"
    case "$status" in
      RUNNING) return 0 ;;
      CREATE_FAILED|DELETED) echo "El servicio quedó en $status" >&2; return 1 ;;
    esac
    sleep 10
  done
  echo "Tiempo de espera agotado ($status)" >&2; return 1
}

for env in "${ENVS[@]}"; do
  name="$(service_name "$env")"
  secret_arn="$(aws secretsmanager describe-secret --secret-id "$(db_secret "$env")" --query ARN --output text)"
  source_cfg="$(printf '{"ImageRepository":{"ImageIdentifier":"%s:%s","ImageRepositoryType":"ECR","ImageConfiguration":{"Port":"8080","RuntimeEnvironmentVariables":{"SPRING_DATASOURCE_URL":"jdbc:postgresql://%s:5432/%s_%s","SPRING_DATASOURCE_USERNAME":"%s_%s","APP_CORS_ORIGINS":"%s"},"RuntimeEnvironmentSecrets":{"SPRING_DATASOURCE_PASSWORD":"%s"}}},"AutoDeploymentsEnabled":false,"AuthenticationConfiguration":{"AccessRoleArn":"%s"}}' \
    "$ECR_URI" "$env" "$DB_HOST" "$PROJECT" "$env" "$PROJECT" "$env" "$(cors_for "$env")" "$secret_arn" "$ECR_ROLE_ARN")"
  instance_cfg="{\"Cpu\":\"0.25 vCPU\",\"Memory\":\"1 GB\",\"InstanceRoleArn\":\"$INSTANCE_ROLE_ARN\"}"
  health_cfg='{"Protocol":"HTTP","Path":"/actuator/health","Interval":10,"Timeout":5,"HealthyThreshold":1,"UnhealthyThreshold":10}'
  network_cfg="{\"EgressConfiguration\":{\"EgressType\":\"VPC\",\"VpcConnectorArn\":\"$CONNECTOR_ARN\"}}"

  arn="$(service_arn "$env")"
  if [ "$arn" = "None" ]; then
    log "Creando $name"
    arn="$(aws apprunner create-service --service-name "$name" \
      --source-configuration "$source_cfg" --instance-configuration "$instance_cfg" \
      --health-check-configuration "$health_cfg" --network-configuration "$network_cfg" \
      --auto-scaling-configuration-arn "$SCALING_ARN" \
      --tags Key=project,Value="$PROJECT" Key=environment,Value="$env" \
      --query Service.ServiceArn --output text)"
  else
    log "Actualizando $name"
    wait_running "$arn"
    aws apprunner update-service --service-arn "$arn" \
      --source-configuration "$source_cfg" --instance-configuration "$instance_cfg" \
      --health-check-configuration "$health_cfg" --network-configuration "$network_cfg" \
      --auto-scaling-configuration-arn "$SCALING_ARN" >/dev/null
  fi
done

log "Esperando a que los servicios estén en RUNNING (puede tardar varios minutos)"
for env in "${ENVS[@]}"; do
  wait_running "$(service_arn "$env")"
  printf '%-5s https://%s\n' "$(label_of "$env")" "$(service_url "$env")"
done
