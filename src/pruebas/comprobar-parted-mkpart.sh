#!/bin/bash
# Puerta estatica contra el fallo que dio la instalacion real en VirtualBox:
#   parted: invalid token: Willy / Error: Expecting a partition type.
# En una tabla msdos (arranque BIOS) lo que va despues de "mkpart" es el TIPO de
# particion (primary/extended/logical), NO un nombre. Los nombres solo los admite
# GPT. El ensayo de logica no lo podia pillar porque lleva parted burlado.
#
# Uso: bash comprobar-parted-mkpart.sh <hook> [<hook> ...]
# Sin argumentos revisa los cinco arboles que tienen instalador.
set -u
WS=/mnt/c/Users/DORA/Documents/Qoder/2026-10-12/8792315c
fallos=0
mal() { printf 'FALLO %s\n' "$1"; fallos=$(( fallos + 1 )); }
ok()  { printf 'OK    %s\n' "$1"; }

revisar() { # $1=camino del hook 0400
	local h=$1 rama tot bien sw asig
	[ -f "$h" ] || { mal "$h no existe"; return; }
	printf -- '--- %s\n' "$h"
	# Rama BIOS: desde el mklabel msdos hasta el fi que cierra el if de MODO.
	rama=$(awk '/mklabel msdos/{d=1} d && /^[ \t]*fi[ \t]*$/{d=0} d {print}' "$h")
	tot=$(printf '%s\n' "$rama" | grep -c 'mkpart')
	bien=$(printf '%s\n' "$rama" | grep -c 'mkpart \(primary\|extended\|logical\)')
	[ "$tot" -gt 0 ] || { mal "la rama msdos no tiene ninguna mkpart (hook cambiado?)"; }
	if [ "$tot" = "$bien" ]; then
		ok "las $tot mkpart de la rama msdos van por tipo, sin nombre"
	else
		mal "rama msdos con $(( tot - bien )) mkpart con nombre: $(printf '%s\n' "$rama" | grep mkpart | grep -v 'mkpart \(primary\|extended\|logical\)')"
	fi
	# La swap se comparte entre las dos ramas: solo vale si usa el tipo variable.
	sw=$(grep -c 'mkpart \$TIPOSW linux-swap' "$h")
	asig=$(grep -c '^\s*TIPOSW=' "$h")
	if [ "$sw" = 1 ] && [ "$asig" = 2 ]; then
		ok "la swap usa \$TIPOSW, asignado en las dos ramas"
	else
		mal "swap: lineas 'mkpart \$TIPOSW'=$sw (se espera 1), asignaciones de TIPOSW=$asig (se espera 2)"
	fi
	# La particion persistente del USB tambien depende de la tabla del medio.
	if grep -q 'Guardar en el USB' "$h"; then
		if grep -q 'mkpart Persistent ext4' "$h"; then
			mal "la persistencia del USB lleva el nombre fijo 'Persistent' (falla en un USB con msdos)"
		elif grep -q 'mkpart \$NOMBREP' "$h" && grep -q 's PTTYPE' "$h"; then
			ok "la persistencia del USB elige el nombre segun la tabla (blkid PTTYPE)"
		else
			mal "la persistencia del USB no usa \$NOMBREP ni consulta PTTYPE"
		fi
	fi
}

if [ "$#" -gt 0 ]; then
	for h in "$@"; do revisar "$h"; done
else
	for h in "$WS/github-willylinux/src/tree-2.1/config/hooks/live/0400-instalador.hook.chroot" \
		"$WS/github-willylinux/src/tree-2.5/config/hooks/live/0400-instalador.hook.chroot" \
		"$WS/tree-2.5/config/hooks/live/0400-instalador.hook.chroot" \
		"/mnt/e/Willy Linux/2.5/tree/config/hooks/live/0400-instalador.hook.chroot" \
		"/mnt/e/Willy Linux/2.5/tree-25-reintento/config/hooks/live/0400-instalador.hook.chroot"; do
		[ -f "$h" ] && revisar "$h"
	done
fi

echo
if [ "$fallos" -eq 0 ]; then echo "parted: todas las ramas BIOS sin nombres"; else echo "HAY $fallos FALLOS"; exit 1; fi
