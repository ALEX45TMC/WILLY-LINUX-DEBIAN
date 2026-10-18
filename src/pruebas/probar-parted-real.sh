#!/bin/bash
# Ensayo de PARTICIONADO CON PARTED DE VERDAD sobre discos falsos (archivo image +
# dispositivo de loop), sin tocar ningun disco real.
#
# Hace falta porque el ensayo de logica (probar-logica-instalador.sh y
# probar-logica-21.sh) lleva parted burlado: la burla apunta la orden y responde 0,
# asi que no puede ver errores de SINTAXIS de parted. Por esa burla paso el
# "mkpart Willy ext4 ..." en tabla msdos; el fallo solo salio al instalar de verdad
# en VirtualBox: "parted: invalid token: Willy / Error: Expecting a partition type".
#
# Que comprueba, con el parted real de trixie y el preparar() sacado del propio hook:
#  1) BIOS: tabla msdos, raiz + swap creadas de cabo a rabo y la particion 1 con flag boot.
#  2) UEFI: tabla gpt, EFI de 512 MB con flag esp, raiz, swap y los nombres Willy*.
#  3) Dientes: el comando viejo "mkpart Willy" en msdos TIENE que fallar. Si alguna
#     version de parted lo aceptara, este ensayo ya no valdria y hay que avisar.
#  4) Persistencia: blkid -o value -s PTTYPE da "dos" en msdos y "gpt" en gpt, de lo
#     que depende que el hook elija "primary" o "Persistent".
#
# Uso (dentro de WSL, como root):
#   tr -d '\r' < /mnt/c/.../probar-parted-real.sh > /root/ppr.sh && bash /root/ppr.sh
# Se le pueden pasar rutas de hooks como argumentos; sin argumentos prueba los dos
# arboles publicados (2.1 y 2.5).
set -u
WS=/mnt/c/Users/DORA/Documents/Qoder/2026-10-12/8792315c
T=/root/willy-parted-test
GIB=$(( 1024 * 1024 * 1024 ))
fallos=0
ok()  { printf 'OK    %s\n' "$1"; }
mal() { printf 'FALLO %s\n' "$1"; fallos=$(( fallos + 1 )); }

command -v parted >/dev/null || { echo "FALLO: no hay parted aqui"; exit 1; }
echo "parted: $(parted --version 2>/dev/null | head -1)"
echo "blkid:  $(blkid -V 2>&1 | head -1)"
rm -rf "$T"; mkdir -p "$T" || exit 1

LOOPS=""
nuevo_disco() { # $1=nombre  $2=tamano  -> deja en IMG el archivo y en DEV lo que parted vera
	IMG=$T/$1.img
	truncate -s "$2" "$IMG" || { echo "FALLO: no se pudo crear $IMG"; exit 1; }
	DEV=""
	if command -v losetup >/dev/null; then
		DEV=$(losetup --find --show "$IMG" 2>/dev/null) || DEV=""
	fi
	if [ -n "$DEV" ]; then
		LOOPS="$LOOPS $DEV"
	else
		DEV=$IMG
		echo "aviso: sin losetup, se prueba sobre el archivo directamente"
	fi
}
cerrar_disco() {
	case "${DEV:-}" in /dev/loop*) losetup -d "$DEV" 2>/dev/null ;; esac
}
limpiar() { for l in $LOOPS; do losetup -d "$l" 2>/dev/null; done; }
trap limpiar EXIT

sacar_preparar() { # $1=hook  $2=salida
	awk '/^preparar\(\) \{/{d=1} d{print} d&&/^\}$/{exit}' "$1" > "$2"
	local n=$(wc -l < "$2")
	[ "$n" -ge 15 ] || { echo "FALLO: preparar() solo tiene $n lineas en $1"; exit 1; }
	grep -q 'mklabel' "$2" || { echo "FALLO: preparar() sin mklabel en $1"; exit 1; }
	grep -q 'mkpart'  "$2" || { echo "FALLO: preparar() sin mkpart en $1"; exit 1; }
}

# Variables que preparar() espera encontrarse puestas, calcadas del instalador con un
# disco de 8 GiB y 2 GiB de swap: la raiz para 512 bytes antes del inicio de la swap.
DISKB=$(( 8 * GIB ))
SWAPSI=2
INISWAP=$(( (DISKB / GIB - SWAPSI) * GIB ))
FINRAIZ="$(( INISWAP - 512 ))B"
SUDO=""
OBJ=$T/no-existe
LOG=$T/preparar.log

num_particiones() { parted -s "$1" print 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {n++} END{print n+0}'; }

correr_preparar() { # $1=script extraido  $2=modo (bios|uefi) -> deja RC y la salida en $T/print-<modo>.txt
	nuevo_disco "auto-$2" 8GiB
	DISK=$DEV MODO=$2 SUF='' NUMRAIZ=1
	[ "$2" = uefi ] && NUMRAIZ=2
	: > "$LOG"
	( . "$1"; preparar )
	RC=$?
	parted -s "$DISK" unit B print > "$T/print-$2.txt" 2>&1
	blkid -o value -s PTTYPE "$DISK" > "$T/pttype-$2.txt" 2>&1
	PARTS=$(num_particiones "$DISK")
	grep -q . "$LOG" && cp "$LOG" "$T/log-$2.txt"
	cerrar_disco
}

probar_arbol() { # $1=nombre  $2=camino del hook
	local nombre=$1 hook=$2 p=$T/preparar-$nombre.sh
	[ -f "$hook" ] || { echo "  (sin arbol: $hook no existe)"; return 0; }
	echo
	echo "########## $nombre : $hook"
	sacar_preparar "$hook" "$p"

	correr_preparar "$p" bios
	[ "$RC" = 0 ] && ok "preparar() en BIOS termino bien" || { mal "preparar() en BIOS devolvio $RC"; sed -n 's/^/        /p' "$T/log-bios.txt" 2>/dev/null | tail -6; }
	[ "$(cat "$T/pttype-bios.txt")" = dos ] && ok 'la tabla de BIOS es msdos (PTTYPE=dos)' || mal "PTTYPE en BIOS: $(cat "$T/pttype-bios.txt")"
	[ "$PARTS" = 2 ] && ok "quedan 2 particiones (raiz + swap)" || mal "en BIOS hay $PARTS particiones, se esperaban 2"
	grep -q 'linux-swap' "$T/print-bios.txt" && ok 'la segunda es linux-swap' || mal 'no hay linux-swap en la tabla BIOS'
	grep -q 'boot' "$T/print-bios.txt" && ok 'la raiz lleva el flag boot' || mal 'sin flag boot en la raiz BIOS'

	correr_preparar "$p" uefi
	[ "$RC" = 0 ] && ok "preparar() en UEFI termino bien" || { mal "preparar() en UEFI devolvio $RC"; sed -n 's/^/        /p' "$T/log-uefi.txt" 2>/dev/null | tail -6; }
	[ "$(cat "$T/pttype-uefi.txt")" = gpt ] && ok 'la tabla de UEFI es gpt' || mal "PTTYPE en UEFI: $(cat "$T/pttype-uefi.txt")"
	[ "$PARTS" = 3 ] && ok "quedan 3 particiones (EFI + raiz + swap)" || mal "en UEFI hay $PARTS particiones, se esperaban 3"
	grep -q 'WillyEFI' "$T/print-uefi.txt" && ok 'la EFI se llama WillyEFI' || mal 'la EFI gpt no tiene nombre WillyEFI'
	grep -q 'esp'     "$T/print-uefi.txt" && ok 'la EFI lleva el flag esp' || mal 'sin flag esp'
}

# ========================= dientes: el bug conocido ===========================
dientes() {
	echo
	echo "########## el comando viejo tiene que seguir fallando ##########"
	nuevo_disco viejo 8GiB
	parted -s "$DEV" mklabel msdos > "$T/viejo.txt" 2>&1
	if parted -s "$DEV" mkpart Willy ext4 1MiB "$FINRAIZ" >> "$T/viejo.txt" 2>&1; then
		mal "parted ACEPTO 'mkpart Willy' en msdos: este ensayo ha perdido su razon de ser"
	else
		ok "parted rechaza 'mkpart Willy' en msdos"
		grep -q 'invalid token' "$T/viejo.txt" \
			&& ok 'y el mensaje es el del ensayo real (invalid token)' \
			|| mal "rechazo con otro mensaje: $(head -2 "$T/viejo.txt" | tr '\n' ' ')"
	fi
	cerrar_disco
}

# ===================== la particion persistente del USB =======================
persistencia() { # $1=tabla (msdos|gpt)
	local tabla=$1
	nuevo_disco "usb-$tabla" 4GiB
	parted -s "$DEV" mklabel "$tabla" > "$T/persist-$tabla.txt" 2>&1
	local t; t=$(blkid -o value -s PTTYPE "$DEV" 2>/dev/null)
	local NOMBREP; [ "$t" = gpt ] && NOMBREP=Persistent || NOMBREP=primary
	parted -s "$DEV" mkpart $NOMBREP ext4 512MiB 1024MiB >> "$T/persist-$tabla.txt" 2>&1 \
		&& ok "USB en $tabla: el idiom del hook crea la persistencia ($NOMBREP)" \
		|| mal "USB en $tabla: no se creo la persistencia -> $(head -2 "$T/persist-$tabla.txt" | tr '\n' ' ')"
	if [ "$tabla" = msdos ]; then
		[ "$t" = dos ] && ok 'PTTYPE de una msdos es "dos", asi que [ = gpt ] elige primary' \
			|| mal "PTTYPE de una msdos salio '$t': hay que revisar la condicion del hook"
		parted -s "$DEV" mkpart Persistent ext4 1536MiB 2048MiB >> "$T/persist-$tabla.txt" 2>&1 \
			&& mal "con nombre 'Persistent' en msdos SI creo una particion (parted cambio de reglas?)" \
			|| ok 'y con nombre en msdos sigue fallando, como se espera'
	else
		[ "$t" = gpt ] && ok 'PTTYPE de una gpt es "gpt", asi que se conserva el nombre' \
			|| mal "PTTYPE de una gpt salio '$t'"
		parted -s "$DEV" print 2>/dev/null | grep -q Persistent \
			&& ok 'la particion gpt conserva el nombre Persistent' \
			|| mal 'la gpt no muestra el nombre Persistent'
	fi
	cerrar_disco
}

echo "=== 4) persistencia en el USB segun la tabla ==="
persistencia msdos
persistencia gpt
dientes

echo
echo "=== arboles probados ==="
if [ "$#" -gt 0 ]; then
	i=0
	for h in "$@"; do i=$(( i + 1 )); probar_arbol "arg$i" "$h"; done
else
	probar_arbol 2.1 "$WS/github-willylinux/src/tree-2.1/config/hooks/live/0400-instalador.hook.chroot"
	probar_arbol 2.5 "$WS/github-willylinux/src/tree-2.5/config/hooks/live/0400-instalador.hook.chroot"
fi

echo
if [ "$fallos" -eq 0 ]; then echo "TODO CORRECTO"; else echo "HAY $fallos FALLOS"; exit 1; fi
