#!/bin/bash
# Audita la ISO 2.5.5 ya entregada: lee el instalador que hay DENTRO del squashfs.
# Sirve para saber si el bug del particionado esta de verdad en el artefacto, no solo
# deducirlo por las fechas de los ficheros.
set -u
ISO="${1:-/mnt/e/Willy Linux/2.5/iso/willylinux-v2.5.5-kde-amd64.iso}"
T=/tmp/auditoria-willy
rm -rf "$T"; mkdir -p "$T/iso" "$T/sq"
umount "$T/sq" 2>/dev/null; umount "$T/iso" 2>/dev/null

echo "ISO: $ISO"
if ! mount -o ro,loop "$ISO" "$T/iso"; then echo "FALLO montando la ISO"; rm -rf "$T"; exit 1; fi
SQ=$(find "$T/iso/live" -maxdepth 1 -name 'filesystem.squashfs' | head -1)
echo "squashfs: ${SQ:-NO ENCONTRADO}"
[ -n "$SQ" ] || { rm -rf "$T"; exit 1; }
if ! mount -t squashfs -o ro,loop "$SQ" "$T/sq"; then echo "FALLO montando el squashfs"; umount "$T/iso"; rm -rf "$T"; exit 1; fi

I="$T/sq/usr/local/bin/willy-instalar"
echo "=== instalador instalado: $(stat -c '%s bytes' "$I" 2>/dev/null || echo ausente) ==="
grep -n 'mkpart' "$I" 2>/dev/null | sed 's/^/  /'
echo "=== marcadores de los arreglos ==="
echo "  bios_grub (comprobacion GPT+BIOS): $(grep -c bios_grub "$I" 2>/dev/null)"
echo "  UUIDRAIZ  (fstab blindado):        $(grep -c UUIDRAIZ "$I" 2>/dev/null)"
echo "  PERR      (error visible de parted): $(grep -c PERR "$I" 2>/dev/null)"
echo "  INISWAP-512 (final de raiz viejo):  $(grep -c 'INISWAP - 512' "$I" 2>/dev/null)"
echo "  separacion 1MiB (final nuevo):      $(grep -c 'INISWAP - 1024 \* 1024' "$I" 2>/dev/null)"
echo "=== version y paquetes clave ==="
sed -n 's/^PRETTY_NAME="\(.*\)"/  os-release: \1/p' "$T/sq/usr/lib/os-release" 2>/dev/null
for b in usr/sbin/parted usr/bin/kwriteconfig6 usr/bin/dbus-send usr/bin/killall; do
	[ -f "$T/sq/$b" ] && echo "  SI  /$b" || echo "  NO  /$b"
done
echo "  paquetes en la imagen: $(find "$T/sq" -maxdepth 2 -name filesystem.packages 2>/dev/null | head -1 | xargs -r wc -l | awk '{print $1}')"

echo "=== willy-panel instalado: lea el global roto de Plasma 6? ==="
V="$T/sq/usr/local/bin/willy-panel"
echo "  tamano: $(stat -c '%s bytes' "$V" 2>/dev/null || echo ausente)"
echo "  lee panelIds (inexistente en Plasma 6): $(grep -c panelIds "$V" 2>/dev/null)"
echo "  recorre Cm.rootItem (arbol real):        $(grep -c 'Cm.rootItem' "$V" 2>/dev/null)"
echo "  la primera sesion centra la barra:       $(grep -c 'willy-panel centrar' "$T/sq/usr/local/bin/willy-primera-vez" 2>/dev/null)"
echo "=== quien aporta kwriteconfig6/dbus-send/killall (¿llegaban solos?) ==="
PKG=$(find "$T/sq" -maxdepth 2 -name 'filesystem.packages*' 2>/dev/null | head -1)
echo "  fichero de paquetes: ${PKG:-no esta en el squashfs}"
for x in dbus-x11 libkf6config-bin psmisc; do
  echo "  $x en la 2.5.5: $(grep -cx "$x" "$PKG" 2>/dev/null || echo '?')"
done
umount "$T/sq" 2>/dev/null; umount "$T/iso" 2>/dev/null; rm -rf "$T"
