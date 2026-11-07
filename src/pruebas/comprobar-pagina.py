#!/usr/bin/env python3
# Comprueba la pagina publica antes de subirla: que todo href/src local exista,
# que todo ancla #id apunte a un id real, que el JSON de datos se lea y que las
# claves data-dato usadas tengan su ruta dentro de datos-iso.json.
# Sale con codigo 0 si todo esta bien; imprime cada problema encontrado.
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

RAIZ = Path(__file__).resolve().parent.parent.parent
FALLOS = []


def ids_de(ruta: Path):
    return set(re.findall(r'\bid\s*=\s*"([^"]+)"', ruta.read_text(encoding="utf-8")))


def revisar_html(ruta: Path):
    texto = ruta.read_text(encoding="utf-8")
    referencias = re.findall(r'(?:href|src)\s*=\s*"([^"]+)"', texto)
    ids_propios = ids_de(ruta)
    cache = {ruta.name: ids_propios}
    for ref in referencias:
        parsed = urlparse(ref)
        if parsed.scheme in {"http", "https", "mailto"} or ref.startswith("//"):
            continue
        objetivo = unquote(parsed.path)
        if not objetivo:
            destino = ruta
        else:
            destino = RAIZ / objetivo
            if not destino.exists():
                FALLOS.append(f"{ruta.name}: enlace roto -> {ref}")
                continue
        if parsed.fragment:
            if destino.suffix != ".html":
                continue
            if destino.name not in cache:
                cache[destino.name] = ids_de(destino)
            if parsed.fragment not in cache[destino.name]:
                FALLOS.append(f"{ruta.name}: ancla inexistente -> {ref}")
    if "<!DOCTYPE html>" not in texto:
        FALLOS.append(f"{ruta.name}: falta el DOCTYPE")
    for etiqueta in ("html", "body", "main"):
        if texto.count(f"<{etiqueta}") != texto.count(f"</{etiqueta}>"):
            FALLOS.append(f"{ruta.name}: <{etiqueta}> sin cerrar")
    if "assets/css/estilo.css" not in texto:
        FALLOS.append(f"{ruta.name}: no enlaza la hoja de estilos")


def revisar_datos():
    datos = json.loads((RAIZ / "datos-iso.json").read_text(encoding="utf-8"))

    def valor(objeto, ruta):
        for parte in ruta.split("."):
            if not isinstance(objeto, dict) or parte not in objeto:
                return None
            objeto = objeto[parte]
        return objeto

    for ruta_html in sorted(RAIZ.glob("*.html")):
        texto = ruta_html.read_text(encoding="utf-8")
        for clave in re.findall(r'data-dato="([^"]+)"', texto):
            if valor(datos, clave) is None:
                FALLOS.append(f"{ruta_html.name}: data-dato sin valor en datos-iso.json -> {clave}")
    return datos


def main():
    paginas = sorted(RAIZ.glob("*.html"))
    if not paginas:
        print("no hay paginas HTML en la raiz")
        return 1
    for pagina in paginas:
        revisar_html(pagina)
    datos = revisar_datos()

    navegacion = {"index.html", "descargas.html", "capturas.html",
                  "documentacion.html", "ayuda.html", "licencias.html"}
    presentes = {p.name for p in paginas}
    if navegacion - presentes:
        FALLOS.append(f"faltan paginas del menu: {sorted(navegacion - presentes)}")

    print(f"paginas revisadas: {len(paginas)}")
    print(f"sha256 en datos-iso.json: {datos['iso']['sha256'][:12]}... "
          f"({datos['iso']['bytes']} B, {datos['iso']['paquetes']} paquetes)")
    if FALLOS:
        print("\nPROBLEMAS:")
        for f in FALLOS:
            print("  -", f)
        return 1
    print("\nOK: enlaces, anclas, clases y datos cuadran")
    return 0


if __name__ == "__main__":
    sys.exit(main())
