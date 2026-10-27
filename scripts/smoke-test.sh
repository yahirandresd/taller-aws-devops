#!/usr/bin/env bash
# Pruebas de humo de un ambiente desplegado.
# Uso: ./scripts/smoke-test.sh <url_api> [url_frontend]
# Falla (exit != 0) si algún chequeo no pasa, lo que detiene el pipeline.
set -euo pipefail

API_URL="${1:?Uso: smoke-test.sh <url_api> [url_frontend]}"
FRONT_URL="${2:-}"
API_URL="${API_URL%/}"
RETRIES="${SMOKE_RETRIES:-10}"
WAIT="${SMOKE_WAIT:-15}"

check() {
  local name="$1" url="$2" expect="$3"
  for i in $(seq 1 "$RETRIES"); do
    if body="$(curl -fsS --max-time 20 "$url")" && grep -q "$expect" <<<"$body"; then
      echo "OK   $name -> $url"
      return 0
    fi
    echo "...  $name intento $i/$RETRIES falló, reintentando en ${WAIT}s"
    sleep "$WAIT"
  done
  echo "FAIL $name -> $url (no contiene '$expect')" >&2
  return 1
}

check "health"    "$API_URL/actuator/health"   '"status":"UP"'
check "dashboard" "$API_URL/api/dashboard/summary" '"precipitationTotalMm"'
check "lluvias"   "$API_URL/api/precipitations" '^\['

if [ -n "$FRONT_URL" ]; then
  check "frontend" "${FRONT_URL%/}/" 'Observatorio'
fi

echo "Pruebas de humo superadas."
