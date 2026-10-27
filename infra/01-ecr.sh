#!/usr/bin/env bash
# Repositorio ECR para la imagen del API y primera imagen por ambiente (tags dev/qa/prod).
source "$(dirname "$0")/config.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log "Repositorio ECR $ECR_REPO"
aws ecr describe-repositories --repository-names "$ECR_REPO" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR_REPO" \
    --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE >/dev/null

# Conservar solo las 15 imágenes más recientes para no pagar almacenamiento de más.
aws ecr put-lifecycle-policy --repository-name "$ECR_REPO" --lifecycle-policy-text \
  '{"rules":[{"rulePriority":1,"description":"Conservar 15 imagenes","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":15},"action":{"type":"expire"}}]}' >/dev/null

log "Construyendo y publicando la imagen inicial"
aws ecr get-login-password | docker login --username AWS --password-stdin "${ECR_URI%%/*}"
docker build -t "$ECR_URI:bootstrap" "$ROOT/backend"
docker push "$ECR_URI:bootstrap"
for env in "${ENVS[@]}"; do
  docker tag "$ECR_URI:bootstrap" "$ECR_URI:$env"
  docker push "$ECR_URI:$env"
done
log "Listo: $ECR_URI:{dev,qa,prod}"
