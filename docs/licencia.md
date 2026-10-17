# Licencia

**Willy Linux es software de código abierto.**

No se atribuyen autorías personales ni créditos individuales: el proyecto se
publica como obra abierta, reutilizable y modificable por cualquier persona.

## Qué significa esto en la práctica

| Puedes | Cómo |
|---|---|
| Usar | En cualquier equipo, en casa, en una escuela, en un negocio, sin coste y sin registrar |
| Estudiar | Todo el árbol de compilación (`src/`) está en el repositorio |
| Modificar | Cambiar paquetes, escritorio, fondos, herramientas o el instalador |
| Redistribuir | Copiar la ISO, grabarla, prestarla, subirla a otro sitio |
| Vender | Permitido, manteniendo la licencia y el código abierto |

## Bases legales

Willy Linux no es un sistema operativo independiente: es una **reconstrucción
(debian-live / live-build)** sobre **Debian 13 “trixie”**. Por tanto:

- **La base del sistema ( Debian )** mantiene sus propias licencias. Cada
  paquete `.deb` conserva la licencia declarada por su autor upstream; el
  índice completo está en `/usr/share/doc/*/copyright` dentro del sistema
  instalado y en <https://www.debian.org/legal/>.
- **`debian-live` y `live-build`** son software GPL de Debian; se usan tal cual,
  sin modificar su código.
- **El material propio del proyecto** — los `hooks/*.chroot`, `hooks/*.binary`,
  los ficheros de `config/includes.chroot/`, las listas
  `config/package-lists/*.list.chroot`, las utilidades `willy-*`, el instalador
  `willy-instalar`, los scripts de `auto/` y esta documentación — se distribuye
  bajo **GNU General Public License v3.0 or later** (texto íntegro en
  [`LICENSE`](../LICENSE)).
- **El arte gráfico** (logotipo “lobito” y fondos de pantalla) se publica bajo
  **CC BY-SA 4.0** para que pueda reutilizarse y adaptarse libremente.
- **Marca**: “Willy Linux” es solo un nombre descriptivo de esta construcción;
  no se reivindica registro ni exclusividad. Una derivada puede llamarse de
  otra forma o conservar el nombre indicando que es una versión modificada.

## Requisitos al redistribuir o modificar

1. Incluir la licencia (GPL-3.0 para el código, CC BY-SA 4.0 para el arte).
2. Publicar los cambios en el árbol de compilación bajo la misma licencia.
3. No presentar una derivada como si fuera la construcción original.
4. Conservar los avisos de terceros de los paquetes de Debian.

## Aviso de uso

El instalador particiona discos. Aunque nunca toca la partición EFI de Windows y
avisa antes de formatear, **una instalación mal dirigida puede borrar datos**.
Se ofrece tal cual, sin garantía de idoneidad para un fin concreto, tal y como
permite la GPL-3.0 (§15). Haz copia de seguridad antes de instalar.

## Terceros

Los códecs Multimedia, el plugin Widevine de Firefox y las aplicaciones de
Flathub no forman parte de esta ISO: se instalan en el equipo del usuario y
cada elemento bajo sus propios términos. El proyecto no los embute ni los
redistribuye.
