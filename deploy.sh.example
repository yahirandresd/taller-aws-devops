#!/usr/bin/env sh
# Copiar a deploy.sh y adaptar al proveedor/infraestructura de despliegue.
# No agregue claves, tokens ni contraseñas a este archivo.
set -eu
ENVIRONMENT="${1:?Uso: ./deploy.sh dev|qa|prod}"
case "$ENVIRONMENT" in
  dev|qa|prod) echo "Configurar aquí el despliegue del ambiente: $ENVIRONMENT" ;;
  *) echo "Ambiente inválido: $ENVIRONMENT" >&2; exit 2 ;;
esac
