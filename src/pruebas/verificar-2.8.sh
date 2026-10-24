#!/bin/bash
# Verifica el ARTEFACTO de Willy Linux 2.8: monta la ISO entregada y lee lo que
# realmente esta dentro. No se fia del log del build ni del arbol de E:.
#
#   wsl.exe -d Debian -u root -- bash "/mnt/e/Willy Linux/2.8/verificar-2.8.sh"
#
# Sale distinto a 0 si algo no esta, para poder encadenarlo en un monitor.
set -uo pipefail

ISO="${1:-/mnt/e/Willy Linux/2.8/iso/willylinux-v2.8-kde-amd64.iso}"
FALLOS=0
OK()   { printf 'OK      %s\n' "$*"; }
MAL()  { printf 'FALTA   %s\n' "$*"; FALLOS=$(( FALLOS + 1 )); }
INFO() { printf '        %s\n' "$*"; }

[ -f "$ISO" ] || { echo "NO EXISTE la ISO: $ISO"; exit 1; }
echo "=== ISO: $ISO ($(stat -c %s "$ISO") bytes) ==="

TMP=$(mktemp -d)
LOOP2=""
trap 'for m in "$TMP/sq" "$TMP/iso"; do umount -R "$m" 2>/dev/null; done
	[ -n "${LOOP:-}" ] && losetup -d "$LOOP" 2>/dev/null
	[ -n "${LOOP2:-}" ] && losetup -d "$LOOP2" 2>/dev/null
	rmdir "$TMP/sq" "$TMP/iso" 2>/dev/null; rm -rf "$TMP"' EXIT
chmod 755 "$TMP"; mkdir -p "$TMP/iso" "$TMP/sq"

LOOP=$(losetup -f --show "$ISO") || { echo "no hay loop libre"; exit 1; }
mount -o ro,loop "$LOOP" "$TMP/iso" || { echo "no monto la ISO"; exit 1; }
SQ=$(find "$TMP/iso/live" -maxdepth 1 -name 'filesystem.squashfs' | head -1)
[ -n "$SQ" ] || { echo "no hay filesystem.squashfs en la ISO"; exit 1; }
mount -t squashfs -o ro,loop "$SQ" "$TMP/sq" || { echo "no monto el squashfs"; exit 1; }
R="$TMP/sq"
OK "squashfs montado"

# ---------- 1) identidad ----------
echo; echo "=== 1) identidad del sistema ==="
grep -q '^VERSION_ID="2.8"' "$R/usr/lib/os-release" 2>/dev/null \
	&& OK "os-release dice 2.8 ($(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' "$R/usr/lib/os-release"))" \
	|| MAL "os-release no dice 2.8: $(sed -n 's/^VERSION_ID=//p' "$R/usr/lib/os-release" 2>/dev/null)"
# El volumen se lee del Primary Volume Descriptor (sector 16, campo de 32 bytes que
# empieza en el offset 40 del descriptor => 32768+40). isoinfo no esta instalado en
# el WSL y python3 tampoco, asi que dd + tr: la unica forma de verlo sin depender de
# que el entorno del host traiga una herramienta concreta.
ETI=$(dd if="$ISO" bs=1 skip=32808 count=32 2>/dev/null | tr -d ' ')
[ "${ETI:-}" = "WILLYLINUX28" ] && OK "volumen ISO = $ETI" || MAL "volumen ISO = '${ETI:-desconocido}' (esperado WILLYLINUX28)"

# ---------- 2) el codigo REAL del instalador ----------
echo; echo "=== 2) willy-instalar instalado (no el del arbol) ==="
INS="$R/usr/local/bin/willy-instalar"
[ -f "$INS" ] && OK "existe /usr/local/bin/willy-instalar" || { MAL "no existe willy-instalar"; }
# Version del script SIN las lineas de comentario: los arregos van documentados en el
# propio fichero y un grep ingenuo encontraba "# INISWAP - 512" o "# panelIds" y gritaba
# FALTA contra un artefacto que estaba bien (paso el 20-10 sobre la primera 2.8).
CODIGO="$TMP/willy-instalar.codigo"; grep -v '^[[:space:]]*#' "$INS" > "$CODIGO"
PERM=$(stat -c %a "$INS" 2>/dev/null)
[ "${PERM:-}" = "755" ] && OK "permisos $PERM" || MAL "permisos '$PERM' (esperado 755)"
sh -n "$INS" 2>/dev/null && OK "sintaxis sh valida" || MAL "sintaxis sh ROTA"
grep -q 'mkpart primary ext4' "$CODIGO" \
	&& OK "rama BIOS: mkpart primary ext4" || MAL "rama BIOS sin 'mkpart primary' (volvera a dar invalid token)"
grep -q 'mkpart Willy ext4' "$CODIGO" \
	&& OK "rama UEFI: nombres solo en GPT" || MAL "rama UEFI sin 'mkpart Willy ext4'"
grep -q 'INISWAP - 1024 \* 1024' "$CODIGO" \
	&& OK "final de raiz separado 1 MiB del swap" || MAL "el final de la raiz sigue pegado al swap (parted: Can't have a partition inside another)"
grep -q 'bios_grub' "$CODIGO" \
	&& OK "avisa de GPT sin bios_grub en modo BIOS" || MAL "no comprueba bios_grub (disco copiado pero sin arrancar)"
grep -q 'PERR' "$CODIGO" \
	&& OK "ensena el error real de parted" || MAL "parted sigue fallando en silencio"
grep -q 'UUIDRAIZ' "$CODIGO" \
	&& OK "corta si la raiz sale sin UUID (no escribe fstab roto)" || MAL "puede escribir un fstab con UUID vacio"
grep -q 'GRUBOK' "$CODIGO" \
	&& OK "aborta si grub-install no deja cargador" || MAL "grub-install puede fallar y aun decir 'instalado' (disco sin arrancar)"

# ---------- 3) binarios que llama el instalador ----------
echo; echo "=== 3) herramientas del instalador y de la barra ==="
for b in usr/sbin/parted usr/sbin/partprobe usr/bin/rsync usr/sbin/mkfs.ext4 usr/sbin/mkfs.vfat \
	usr/sbin/grub-install usr/sbin/grub-bios-setup usr/sbin/grub-mkconfig usr/bin/efibootmgr \
	usr/bin/yad usr/bin/konsole usr/bin/kwriteconfig6 usr/bin/kreadconfig6 \
	usr/bin/dbus-send usr/bin/killall usr/sbin/chpasswd usr/bin/cfdisk; do
	[ -f "$R/$b" ] && OK "/$b" || MAL "/$b"
done

# ---------- 4) paquetes declarados vs imagen ----------
# filesystem.packages vive JUNTO al squashfs (live/ dentro de la ISO), no dentro del
# squashfs: buscarlo bajo $R daba "no lo encontre" sobre una ISO perfecta.
echo; echo "=== 4) lista de paquetes de la imagen ==="
PKG="$TMP/iso/live/filesystem.packages"
if [ -f "$PKG" ]; then
	INFO "imagen: $(wc -l < "$PKG") paquetes instalados"
	FALTAN=0
	# En filesystem.packages los paquetes nativos salen como "nombre:arquitectura"
	# (pipewire:amd64); compararlos exactos los declaraba falsamente ausentes.
	NOMBRES="$TMP/imagen.nombres"
	awk -F'\t' '{split($1,a,":"); print a[1]}' "$PKG" | sort -u > "$NOMBRES"
	for p in parted dosfstools rsync yad konsole plasma-workspace plasma-desktop \
		sddm libkf6config-bin dbus-x11 psmisc grub-pc grub2-common efibootmgr \
		gdisk e2fsprogs pipewire wireplumber flatpak plasma-discover; do
		grep -qx "$p" "$NOMBRES" || { MAL "paquete no instalado: $p"; FALTAN=$(( FALTAN + 1 )); }
	done
	[ "$FALTAN" = 0 ] && OK "estan los paquetes clave sueltos"
	# Los 238 declarados por el arbol, uno por uno, contra la imagen. Con
	# --apt-recommends false un nombre mal escrito desaparece en silencio y el script
	# que lo llama falla dias despues en casa del usuario.
	DECL=$(mktemp)
	cat "/mnt/e/Willy Linux/2.8/tree"/config/package-lists/*.list.chroot 2>/dev/null \
		| grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | awk '{print $1}' | sort -u > "$DECL"
	AUSENTES=$(comm -23 "$DECL" "$NOMBRES")
	if [ -z "$AUSENTES" ]; then
		OK "los $(wc -l < "$DECL") paquetes declarados por el arbol estan en la imagen"
	else
		MAL "declarados y AUSENTES en la imagen: $(echo "$AUSENTES" | tr '\n' ' ')"
	fi
	rm -f "$DECL"
else
	MAL "no esta live/filesystem.packages dentro de la ISO"
fi

# ---------- 5) arranque grafico ----------
echo; echo "=== 5) arranque grafico ==="
[ -L "$R/etc/systemd/system/display-manager.service" ] && OK "sddm es el gestor de pantalla" || MAL "sddm no esta en display-manager.service"
S=$(cat "$R/etc/sddm.conf.d/willy.conf" 2>/dev/null)
echo "$S" | grep -q 'Session=plasmax11.desktop' && OK "sesion fijada a plasmax11" || INFO "sesion SDDM: $(echo "$S" | tr '\n' ' ')"
PV="$R/usr/local/bin/willy-panel"
[ -f "$PV" ] && sh -n "$PV" 2>/dev/null && OK "willy-panel instalado y con sintaxis valida" || MAL "willy-panel"
grep -q 'willy-panel centrar' "$R/usr/local/bin/willy-primera-vez" 2>/dev/null \
	&& OK "la primera sesion centra la barra" || MAL "willy-primera-vez no centra la barra"
# igual que con el instalador: el fichero explica en un comentario que Plasma 6 NO tiene
# panelIds, y ese comentario no puede contar como el bug que describe.
grep -v '^[[:space:]]*#' "$PV" > "$TMP/panel.codigo" 2>/dev/null || : > "$TMP/panel.codigo"
grep -q 'panelIds' "$TMP/panel.codigo" \
	&& MAL "willy-panel sigue leyendo el global inexistente panelIds" || OK "willy-panel usa el arbol Cm.rootItem"

# ---------- 6) el artefacto vs el arbol del que se compilo ----------
echo; echo "=== 6) same codigo en el arbol y en la ISO ==="
HOOK="/mnt/e/Willy Linux/2.8/tree/config/hooks/live/0400-instalador.hook.chroot"
[ -f "$HOOK" ] && OK "arbol: 0400-instalador" || MAL "falta el hook 0400 en el arbol de E:"
# Lo que de verdad importa: que el willy-instalar dentro de la ISO sea byte a byte el
# que esta en el arbol hoy. Un arbol arreglado despues del build da una ISO vieja con
# nombre nuevo, y eso es exactamente lo que se le col6 a la 2.5.5.
for par in WLYINSTALL:willy-instalar WLYPERSIST:willy-persistencia \
	WLYUPDATE:willy-actualizar-run WLYUPDGUI:willy-actualizar; do
	marca=${par%%:*}; bin=${par##*:}
	[ -f "$R/usr/local/bin/$bin" ] || { MAL "$bin no esta en la imagen"; continue; }
	generado="$TMP/$bin.del-arbol"
	awk "/<<'$marca'/{f=1;next} /^$marca\$/{f=0} f" "$HOOK" > "$generado"
	if [ -s "$generado" ] && cmp -s "$generado" "$R/usr/local/bin/$bin"; then
		OK "$bin: identico al arbol ($(wc -l < "$generado") lineas)"
	else
		MAL "$bin: la ISO lleva otra version distinta del arbol (rebuild pendiente)"
	fi
done

echo
if [ "$FALLOS" = 0 ]; then
	echo "=== VERIFICADO: la ISO entregada es la 2.8 con el instalador corregido ==="
else
	echo "=== HAY $FALLOS COMPROBACIONES FALLIDAS: NO entregar esta ISO ==="
fi
exit "$FALLOS"
