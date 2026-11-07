# -*- coding: utf-8 -*-
"""Comprobar en la propia ISO por qué Secure Boot la rechaza, sin montar nada.

Lee, dentro del ISO9660, el `live/filesystem.packages` (busca `shim-signed` y
`mokutil`) y la imagen FAT que arranca en UEFI (`boot/efi.img`), recorre esa FAT
y mira si cada `.efi` trae tabla de certificados PE (directorio de datos nº 4, el
de Authenticode). Un binario EFI sin esa tabla es justo lo que un firmware con
Secure Boot activado se niega a ejecutar: aqui no es una opinion, es lo que hay
dentro del artefacto.

  python comprobar-seguro-arranque.py <iso>
"""
import importlib.util
import pathlib
import sys

# el lector de ISO9660 se llama con guiones, asi que no se puede importar con «from»
_espec = importlib.util.spec_from_file_location(
    "leer_dentro_iso", pathlib.Path(__file__).with_name("leer-dentro-iso.py"))
_lector = importlib.util.module_from_spec(_espec)
_espec.loader.exec_module(_lector)
buscar = _lector.buscar


# ---------------------------------------------------------------- ISO -> FAT
def imagen_efi(iso):
    """La imagen FAT que el firmware lee en UEFI: live-build la deja en /EFI.IMG."""
    for ruta in ("EFI.IMG", "boot/efi.img", "boot/efiboot.img", "boot/x86_64/efi"):
        try:
            return ruta, buscar(iso, ruta.split("/")).encode("latin-1")
        except SystemExit:
            continue
    raise SystemExit("no hay imagen EFI dentro del ISO: esta imagen no arranca en UEFI")


class Fat:
    """Lectura minima de FAT12/FAT16: la que usan las imagenes EFI de live-build."""

    def __init__(self, buf):
        self.b = buf
        self.bps = int.from_bytes(buf[11:13], "little")
        self.spc = buf[13]
        reservado = int.from_bytes(buf[14:16], "little")
        nfats = buf[16]
        self.rootent = int.from_bytes(buf[17:19], "little")
        self.spfat = int.from_bytes(buf[22:24], "little") or int.from_bytes(buf[36:40], "little")
        self.total = int.from_bytes(buf[19:21], "little") or int.from_bytes(buf[32:36], "little")
        if not self.spc or not self.spfat or self.bps == 0:
            raise SystemExit("BPB ilegible en la imagen EFI")
        self.fat_ini = reservado * self.bps
        self.raiz_ini = self.fat_ini + nfats * self.spfat * self.bps
        raiz_bytes = self.rootent * 32
        self.datos_ini = self.raiz_ini + raiz_bytes
        sectores_raiz = (raiz_bytes + self.bps - 1) // self.bps
        clusters = (self.total - reservado - nfats * self.spfat - sectores_raiz) // self.spc
        self.ancho = 12 if clusters < 4085 else (16 if clusters < 65525 else 0)
        if self.ancho == 0:
            raise SystemExit("FAT32 no soportada por este comprobador (%d clusters)" % clusters)
        self.fat = self._cadena_fat(nfats)   # tabla de clusters

    def _cadena_fat(self, nfats):
        bruto = self.b[self.fat_ini:self.fat_ini + self.spfat * self.bps]
        cad = []
        if self.ancho == 12:
            for i in range(0, len(bruto) - 2, 3):
                v = bruto[i] | (bruto[i + 1] << 8) | (bruto[i + 2] << 16)
                cad += [v & 0xFFF, (v >> 12) & 0xFFF]
        else:
            for i in range(0, len(bruto) - 1, 2):
                cad.append(int.from_bytes(bruto[i:i + 2], "little"))
        return cad

    def cadena(self, inicial):
        fin = 0xFF8 if self.ancho == 12 else 0xFFF8
        out, c = [], inicial
        while 2 <= c < len(self.fat) and c < fin:
            out.append(c)
            c = self.fat[c]
        return out

    def datos(self, inicial, tam=None):
        bruto = b"".join(
            self.b[self.datos_ini + (c - 2) * self.spc * self.bps:
                   self.datos_ini + (c - 1) * self.spc * self.bps]
            for c in self.cadena(inicial))
        return bruto[:tam] if tam is not None else bruto

    def entradas(self, inicial=None):
        """Hijos de un directorio: la raiz si no se pasa cluster."""
        bruto = (self.b[self.raiz_ini:self.raiz_ini + self.rootent * 32]
                 if inicial is None else self.datos(inicial))
        for off in range(0, len(bruto) - 31, 32):
            e = bruto[off:off + 32]
            if e[0] == 0x00:
                return
            if e[0] == 0xE5 or e[11] == 0x0F:      # borrado o nombre largo VFAT
                continue
            primario = e[0:8].decode("latin-1").strip()
            ext = e[8:11].decode("latin-1").strip()
            nombre = (primario + "." + ext).strip(".") if ext else primario
            cluster = int.from_bytes(e[26:28], "little")
            tam = int.from_bytes(e[28:32], "little")
            yield {"nombre": nombre, "cluster": cluster, "bytes": tam,
                   "es_dir": bool(e[11] & 0x10)}

    def arbol(self, inicial=None, prefijo=""):
        for e in self.entradas(inicial):
            if e["nombre"] in (".", ".."):
                continue
            ruta = prefijo + "/" + e["nombre"]
            if e["es_dir"]:
                yield from self.arbol(e["cluster"], ruta)
            else:
                yield ruta, e["bytes"], self.datos(e["cluster"], e["bytes"])


# ------------------------------------------------------------------- fichero PE
def info_pe(pe):
    if pe[:2] != b"MZ" or len(pe) < 0x100:
        return None
    e_lfanew = int.from_bytes(pe[60:64], "little")
    if pe[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        return None
    cab = e_lfanew + 4
    maquina = int.from_bytes(pe[cab:cab + 2], "little")
    magic = int.from_bytes(pe[cab + 20:cab + 22], "little")
    if magic == 0x20B:                       # PE32+ : 112 bytes hasta los directorios
        base = cab + 20 + 112
    elif magic == 0x10B:                     # PE32   : 96 bytes
        base = cab + 20 + 96
    else:
        return {"maquina": "0x%04X" % maquina, "magic": "0x%04X" % magic, "leible": False}
    rva = int.from_bytes(pe[base:base + 4], "little")
    tam = int.from_bytes(pe[base + 4:base + 8], "little")
    return {"maquina": "0x%04X" % maquina, "magic": "0x%04X" % magic, "leible": True,
            "firmado": tam > 0, "bytes_cert": tam, "rva_cert": rva}


# ------------------------------------------------------------------------ main
def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    iso = sys.argv[1]

    paquetes = buscar(iso, ["live", "filesystem.packages"]).encode("latin-1").decode("utf-8", "replace")
    nombres = set()
    for linea in paquetes.splitlines():
        for parte in linea.split():
            if parte and parte[0].isalnum():
                nombres.add(parte)
                break
    print("== paquetes dentro del ISO ==")
    for p in ("shim-signed", "grub-efi-amd64-bin", "grub2-common", "mokutil", "efibootmgr"):
        print("  %-22s %s" % (p, "esta" if p in nombres else "-- NO esta"))

    ruta, buf = imagen_efi(iso)
    fat = Fat(buf)
    print("\n== %s: %d bytes, FAT%d, %d bytes/sector, %d sectores/cluster =="
          % (ruta, len(buf), fat.ancho, fat.bps, fat.spc))
    sin_firma = 0
    todos = list(fat.arbol())
    print("  ficheros dentro de la FAT: %s" % (", ".join(sorted(n for n, _, _ in todos)) or "ninguno"))
    for nombre, tam, datos in todos:
        if not nombre.lower().endswith(".efi"):
            continue
        info = info_pe(datos)
        if info is None or not info.get("leible"):
            print("  %-40s %9d B  PE no reconocible" % (nombre, tam))
            continue
        marca = "FIRMADO (Authenticode)" if info["firmado"] else "SIN FIRMA"
        if not info["firmado"]:
            sin_firma += 1
        print("  %-40s %9d B  %s  [tabla %d bytes, RVA 0x%X]"
              % (nombre, tam, marca, info["bytes_cert"], info["rva_cert"]))
    print("\n  binarios EFI sin firma de Microsoft en el arrancador: %d" % sin_firma)
    print("  veredicto: %s" % ("con Secure Boot activado este arrancador NO pasa"
                               if sin_firma else "hay al menos un binario firmado"))


main()
