#!/usr/bin/env bash
# Configuración compartida por los scripts de infraestructura.
# Uso: los scripts hacen `source "$(dirname "$0")/config.sh"`.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""
export MSYS_NO_PATHCONV=1   # Git Bash en Windows: no convertir "/actuator/health" en rutas

PROJECT="observatorio"
ENVS=(dev qa prod)
GITHUB_REPO="${GITHUB_REPO:-yahirandresd/taller-aws-devops}"
ECR_REPO="observatorio-api"
DB_INSTANCE="observatorio-db"
DB_ADMIN_USER="observatorio_admin"
DB_ADMIN_SECRET="observatorio/rds-master"
SG_RDS_NAME="observatorio-rds-sg"
SG_CONNECTOR_NAME="observatorio-apprunner-sg"
VPC_CONNECTOR="observatorio-vpc"
AUTOSCALING_NAME="observatorio-1-instancia"
ROLE_ECR_ACCESS="observatorio-apprunner-ecr-access"
ROLE_INSTANCE="observatorio-apprunner-instance"
ROLE_GITHUB="observatorio-github-actions"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO"

# Rama de Git que alimenta cada ambiente.
branch_of() { case "$1" in dev) echo develop ;; qa) echo qa ;; prod) echo main ;; esac; }
label_of() { case "$1" in dev) echo DEV ;; qa) echo QA ;; prod) echo PDN ;; esac; }
service_name() { echo "$PROJECT-api-$1"; }
db_secret() { echo "$PROJECT/$1/db-password"; }

default_vpc() { aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text; }
sg_id() { aws ec2 describe-security-groups --filters "Name=group-name,Values=$1" --query 'SecurityGroups[0].GroupId' --output text; }
service_arn() {
  aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='$(service_name "$1")'].ServiceArn | [0]" --output text
}
service_url() {
  aws apprunner describe-service --service-arn "$(service_arn "$1")" --query 'Service.ServiceUrl' --output text
}
log() { printf '\n==> %s\n' "$*"; }
