#!/usr/bin/env bash
# Crea una base y un usuario por ambiente (observatorio_dev / _qa / _prod) y guarda
# cada clave en Secrets Manager. RDS es privada, así que el script la abre
# TEMPORALMENTE solo a la IP pública de quien lo ejecuta y la vuelve a cerrar al final.
# Requiere Docker (usa la imagen postgres para tener psql).
source "$(dirname "$0")/config.sh"

SG_RDS="$(sg_id "$SG_RDS_NAME")"
MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
ADMIN_PASSWORD="$(aws secretsmanager get-secret-value --secret-id "$DB_ADMIN_SECRET" --query SecretString --output text)"

close_access() {
  log "Cerrando acceso público a RDS"
  aws ec2 revoke-security-group-ingress --group-id "$SG_RDS" --protocol tcp --port 5432 --cidr "$MY_IP/32" >/dev/null 2>&1 || true
  aws rds modify-db-instance --db-instance-identifier "$DB_INSTANCE" --no-publicly-accessible --apply-immediately >/dev/null
}
trap close_access EXIT

log "Abriendo RDS temporalmente a $MY_IP/32"
aws ec2 authorize-security-group-ingress --group-id "$SG_RDS" --protocol tcp --port 5432 --cidr "$MY_IP/32" >/dev/null 2>&1 || true
aws rds modify-db-instance --db-instance-identifier "$DB_INSTANCE" --publicly-accessible --apply-immediately >/dev/null
sleep 30
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"
HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[0].Endpoint.Address' --output text)"

psql_admin() {
  docker run --rm -i -e PGPASSWORD="$ADMIN_PASSWORD" -e PGSSLMODE=require postgres:16-alpine \
    psql -v ON_ERROR_STOP=1 -h "$HOST" -U "$DB_ADMIN_USER" -d postgres "$@"
}

log "Esperando a que $HOST acepte conexiones"
for _ in $(seq 1 30); do psql_admin -c 'select 1' >/dev/null 2>&1 && break; sleep 10; done

for env in "${ENVS[@]}"; do
  user="${PROJECT}_$env"
  secret="$(db_secret "$env")"
  if ! aws secretsmanager describe-secret --secret-id "$secret" >/dev/null 2>&1; then
    aws secretsmanager create-secret --name "$secret" --secret-string "$(openssl rand -hex 16)" >/dev/null
  fi
  pass="$(aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text)"
  log "Base y usuario $user"
  printf '%s\n' \
    "SELECT format('CREATE ROLE %I LOGIN', '$user') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$user')\\gexec" \
    "ALTER ROLE $user PASSWORD '$pass';" \
    "GRANT $user TO $DB_ADMIN_USER;" \
    "SELECT format('CREATE DATABASE %I OWNER %I', '$user', '$user') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$user')\\gexec" \
    "REVOKE ALL ON DATABASE $user FROM PUBLIC;" \
    | psql_admin
done
log "Bases creadas: observatorio_dev, observatorio_qa, observatorio_prod"
