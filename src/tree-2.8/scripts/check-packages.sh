#!/bin/sh
set -e

DIST="${WILLY_DIST:-trixie}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod 755 "$TMP"
mkdir -p "$TMP/lists/partial"
echo "deb http://deb.debian.org/debian $DIST main non-free-firmware" > "$TMP/sources.list"

APT_OPTS="-o Dir::Etc::SourceList=$TMP/sources.list -o Dir::Etc::SourceParts=$TMP/none \
-o Dir::State::Lists=$TMP/lists -o Dir::Cache::pkgcache= -o Dir::Cache::srcpkgcache="

# shellcheck disable=SC2086
apt-get $APT_OPTS -qq update

missing=0
for p in $(grep -hv '^[[:space:]]*#' config/package-lists/*.list.chroot* | tr -s ' \t\r' '\n' | sort -u); do
	# shellcheck disable=SC2086
	c="$(apt-cache $APT_OPTS policy "$p" 2>/dev/null | awk '/Candidate:/ {print $2}')"
	if [ -z "$c" ] || [ "$c" = "(none)" ]; then
		echo "Paquete no encontrado en $DIST: $p"
		missing=1
	fi
done

[ "$missing" -eq 0 ] && echo "Todos los paquetes existen en $DIST."
exit "$missing"
