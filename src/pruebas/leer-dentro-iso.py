# -*- coding: utf-8 -*-
"""Leer un fichero que esta DENTRO de una ISO sin montar nada.

Recorre el ISO9660: el PVD (magic CD001) vive en el sector 16 y su puntero de
directorio raiz da el LBA donde empezar; cada directorio es una sucesion de
registros [len, ext_len, LBA, ...][nombre].  Se usa para cruzar lo declarado en
config/package-lists con lo que realmente entro en la imagen, que es donde la
2.8 del 20-10 tenia cfdisk ausente pese a estar en la lista.

  python leer-dentro-iso.py <iso> [ruta/en/la/iso]
"""
import re
import sys

SECTOR = 2048


def leer(fh, off, n):
    fh.seek(off)
    return fh.read(n)


def registros(buf):
    """Cada registro: [0]=len, [2:6]=LBA, [10:14]=tamano, [25]=flags, [33:]=nombre."""
    off = 0
    while off < len(buf):
        ln = buf[off]
        if ln == 0:
            off = (off // SECTOR + 1) * SECTOR
            continue
        rec = buf[off:off + ln]
        if len(rec) < 34:
            break
        nombre_len = rec[32]
        nombre = rec[33:33 + nombre_len].decode("latin-1")
        yield nombre, int.from_bytes(rec[2:6], "little"), int.from_bytes(rec[10:14], "little")
        off += ln


def buscar(ruta_iso, partes):
    with open(ruta_iso, "rb") as fh:
        pvd = leer(fh, 16 * SECTOR, SECTOR)
        # el PVD empieza con el byte de tipo (1) y luego viene la firma: CD001 esta en [1:6]
        if pvd[1:6] != b"CD001":
            raise SystemExit("no hay PVD CD001 en el sector 16: no parece un ISO9660")
        # el registro del directorio raiz ocupa los bytes 156..189 del PVD; dentro de
        # un registro el LBA esta en +2 y el tamano en +10
        lba = int.from_bytes(pvd[158:162], "little")
        tam = int.from_bytes(pvd[166:170], "little")
        for i, parte in enumerate(partes):
            buf = leer(fh, lba * SECTOR, tam)
            siguiente = None
            for nombre, ext, esz in registros(buf):
                if nombre in (".", "..", ""):
                    continue
                if nombre.split(";")[0].upper() == parte.upper():
                    siguiente = (ext, esz)
                    break
            if siguiente is None:
                raise SystemExit("no existe %s dentro del ISO" % "/".join(partes[:i + 1]))
            lba, tam = siguiente
        return leer(fh, lba * SECTOR, tam).decode("latin-1", "replace")


COMPROBAR = [
    "fdisk", "dbus-x11", "libkf6config-bin", "psmisc", "ufw",
    "libspa-0.2-bluetooth", "smbclient", "hplip", "sane-utils", "skanpage",
    "7zip", "unar", "kimageformat-plugins", "adwaita-icon-theme",
    "fonts-liberation", "fonts-crosextra-carlito", "mobile-broadband-provider-info",
    "grub2-common", "grub-pc-bin", "grub-efi-amd64-bin", "efibootmgr", "os-prober",
    "desktop-file-utils", "live-boot", "live-config", "user-setup",
    "plasma-workspace", "pipewire", "flatpak", "discover",
]

# binarios que no son paquetes con su mismo nombre y hay que buscar por path
BINARIOS = ["cfdisk", "kreadconfig6", "dbus-send", "killall", "grub-bios-setup",
            "update-desktop-database", "plasma-apply-wallpaperimage"]


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    iso = sys.argv[1]
    ruta = sys.argv[2] if len(sys.argv) > 2 else "live/filesystem.packages"
    contenido = buscar(iso, ruta.split("/"))
    nombres = set()
    for linea in contenido.splitlines():
        m = re.match(r"\s*([A-Za-z0-9.+-]+)", linea)
        if m:
            nombres.add(m.group(1))
    print("%s\n  %s: %d lineas, %d nombres unicos" % (iso, ruta, len(contenido.splitlines()), len(nombres)))
    faltan = []
    for p in COMPROBAR:
        esta = p in nombres
        if not esta:
            faltan.append(p)
        print("  %-32s %s" % (p, "esta" if esta else "-- NO esta"))
    print("\n  faltan: %s" % (", ".join(faltan) if faltan else "ninguno"))
    # cfdisk no es un paquete: es un fichero dentro de fdisk, y aqui solo se ve
    # el nombre del paquete.  Se comprueba aparte, descomprimiendo el squashfs.
    print("\n  (los binarios %s se comprueban dentro del squashfs, no en esta lista)"
          % ", ".join(BINARIOS))


if __name__ == "__main__":
    main()
