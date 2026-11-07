#!/bin/sh
# Comprueba que la ISO no pase del tope de Willy Linux 2.8 (8 GB).
# Uso: sh scripts/check-size.sh [ruta-a-iso]
set -e

ISO=${1:-live-image-amd64.hybrid.iso}
LIMIT=$((8 * 1024 * 1024 * 1024))

[ -f "$ISO" ] || { echo "No existe la ISO: $ISO"; exit 1; }

SIZE=$(stat -c %s "$ISO")
MB=$((SIZE / 1024 / 1024))
PCT=$((SIZE * 100 / LIMIT))
echo "$ISO: ${MB} MB (${PCT}% del tope de 8 GB)"

if [ "$SIZE" -gt "$LIMIT" ]; then
	echo "FALLO: supera el tope de 8 GB. Quita paquetes de config/package-lists/ y vuelve a construir."
	exit 1
fi
echo "OK: dentro del tope."
