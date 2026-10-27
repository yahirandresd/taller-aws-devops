#!/usr/bin/env bash
# Enlaza cada rama de Amplify con la API de su ambiente y fija CORS en App Runner.
# Requisito: haber creado la app en la consola de Amplify conectando el repo GitHub
# (monorepo, carpeta frontend) con las ramas develop, qa y main.
# Uso: AMPLIFY_APP_ID=d123abc ./infra/05-amplify-env.sh
source "$(dirname "$0")/config.sh"
export AMPLIFY_APP_ID="${AMPLIFY_APP_ID:?Defina AMPLIFY_APP_ID (Amplify > App settings > General)}"

for env in "${ENVS[@]}"; do
  branch="$(branch_of "$env")"
  api="https://$(service_url "$env")"
  log "Rama $branch -> $(label_of "$env") -> $api"
  aws amplify update-branch --app-id "$AMPLIFY_APP_ID" --branch-name "$branch" \
    --stage "$( [ "$env" = prod ] && echo PRODUCTION || echo DEVELOPMENT )" \
    --environment-variables "VITE_API_URL=$api,VITE_APP_ENV=$(label_of "$env"),AMPLIFY_MONOREPO_APP_ROOT=frontend" >/dev/null
done

log "Actualizando CORS de las APIs con las URLs de Amplify"
"$(dirname "$0")/03-apprunner.sh"

for env in "${ENVS[@]}"; do
  branch="$(branch_of "$env")"
  log "Reconstruyendo frontend $branch"
  aws amplify start-job --app-id "$AMPLIFY_APP_ID" --branch-name "$branch" --job-type RELEASE --query jobSummary.jobId --output text
  printf '%-5s https://%s.%s.amplifyapp.com\n' "$(label_of "$env")" "$branch" "$AMPLIFY_APP_ID"
done
