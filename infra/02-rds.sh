#!/usr/bin/env bash
# Base de datos: una instancia RDS PostgreSQL privada (free tier) en la VPC por defecto.
# Cada ambiente tendrá su propia base y su propio usuario (ver 02b-init-db.sh).
source "$(dirname "$0")/config.sh"

VPC_ID="$(default_vpc)"
log "VPC por defecto: $VPC_ID"

ensure_sg() {
  local name="$1" desc="$2" id
  id="$(sg_id "$name")"
  if [ "$id" = "None" ]; then
    id="$(aws ec2 create-security-group --group-name "$name" --description "$desc" --vpc-id "$VPC_ID" --query GroupId --output text)"
  fi
  echo "$id"
}
SG_CONNECTOR="$(ensure_sg "$SG_CONNECTOR_NAME" "Salida de App Runner hacia RDS")"
SG_RDS="$(ensure_sg "$SG_RDS_NAME" "PostgreSQL solo desde App Runner")"
aws ec2 authorize-security-group-ingress --group-id "$SG_RDS" \
  --ip-permissions "IpProtocol=tcp,FromPort=5432,ToPort=5432,UserIdGroupPairs=[{GroupId=$SG_CONNECTOR}]" >/dev/null 2>&1 || true

log "Secreto de la clave maestra ($DB_ADMIN_SECRET)"
if ! aws secretsmanager describe-secret --secret-id "$DB_ADMIN_SECRET" >/dev/null 2>&1; then
  aws secretsmanager create-secret --name "$DB_ADMIN_SECRET" \
    --secret-string "$(openssl rand -hex 20)" >/dev/null
fi
ADMIN_PASSWORD="$(aws secretsmanager get-secret-value --secret-id "$DB_ADMIN_SECRET" --query SecretString --output text)"

if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" >/dev/null 2>&1; then
  log "La instancia $DB_INSTANCE ya existe"
else
  log "Creando RDS $DB_INSTANCE (db.t4g.micro, 20 GB, privada) — tarda ~10 min"
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE" \
    --engine postgres \
    --db-instance-class db.t4g.micro \
    --allocated-storage 20 --storage-type gp2 --storage-encrypted \
    --master-username "$DB_ADMIN_USER" --master-user-password "$ADMIN_PASSWORD" \
    --vpc-security-group-ids "$SG_RDS" \
    --no-publicly-accessible --no-multi-az \
    --backup-retention-period 1 \
    --no-deletion-protection \
    --tags Key=project,Value="$PROJECT" >/dev/null
fi
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"
log "RDS disponible: $(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[0].Endpoint.Address' --output text)"
