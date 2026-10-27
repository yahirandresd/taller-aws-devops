#!/usr/bin/env bash
# Alerta de costos: avisa por correo al 80 % de un presupuesto mensual.
# Uso: BUDGET_EMAIL=correo@dominio ./infra/00-budget.sh [monto_usd]
source "$(dirname "$0")/config.sh"
EMAIL="${BUDGET_EMAIL:?Defina BUDGET_EMAIL}"
AMOUNT="${1:-10}"

if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$PROJECT-mensual" >/dev/null 2>&1; then
  log "El presupuesto $PROJECT-mensual ya existe"; exit 0
fi
aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget "{\"BudgetName\":\"$PROJECT-mensual\",\"BudgetLimit\":{\"Amount\":\"$AMOUNT\",\"Unit\":\"USD\"},\"TimeUnit\":\"MONTHLY\",\"BudgetType\":\"COST\"}" \
  --notifications-with-subscribers "[{\"Notification\":{\"NotificationType\":\"ACTUAL\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":80,\"ThresholdType\":\"PERCENTAGE\"},\"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$EMAIL\"}]}]"
log "Presupuesto de USD $AMOUNT creado; alerta a $EMAIL"
