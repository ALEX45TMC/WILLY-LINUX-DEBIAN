# Especificaciones técnicas

## Base

| | |
|---|---|
| Distribución padre | **Debian 13 *trixie*** (estable), modo `debian` de live-build |
| Arquitectura | `amd64` (solo 64 bits) |
| Áreas de archivo | `main` + `non-free-firmware` |
| Herramienta | `live-build` (`lb config` / `lb build`) |
| Bootstrap | `debootstrap --variant=minbase` |
| Resolución de dependencias | **`--apt-recommends false`** |
| Índices apt en la imagen | `--apt-indices false` (no se guarda la lista de paquetes) |
| Firmware | `--firmware-chroot false` / `--firmware-binary false`: el firmware se declara a mano en `firmware.list.chroot` |
| Instalador de Debian | `none` (el instalador es propio, `willy-instalar`) |
| Imagen | `--binary-image iso-hybrid`: un mismo fichero arranca en BIOS y en UEFI |
| Compresión del sistema | squashfs con `gzip` (arranca en cualquier equipo, sin depender de zstd/xz) |
| Volumen ISO | `WILLYLINUX` (ediciones ligeras) / `WILLYLINUX255` (2.5.x) |

### Por qué `--apt-recommends false`

Es la decisión que más explica el proyecto. Con `Recommends` activados, una imagen live de
Plasma se dispara de tamaño y arrastra samba, servicios y dependencias que los equipos objetivo
no necesitan. Con ella apagada, **cada paquete que entra en la ISO está escrito a mano** en
`package-lists/*.list.chroot`, y el control del tamaño es exacto.

El precio es una familia de defectos que hay que conocer: si un paquete necesita un *Recommends*
para funcionar y nadie lo escribió, **la ISO compila bien, arranca bien y falla en un detalle**.
Esto pasó con `pipewire-audio` (el volumen no subía), `alsa-ucm-conf`/`alsa-topology-conf`
(perfiles de portátil), los 6 paquetes VA-API (vídeo en el procesador), `grub2-common` y
`grub-pc` (el disco no quedaba arrancable), `desktop-file-utils` (menú sin refrescar) y
`libcanberra-pulse` (sin pitido). Por eso existe el barrido sistemático descrito en
[verificar-la-iso](verificar-la-iso.md).

## Parámetros de arranque por defecto

```
boot=live components quiet persistence username=live hostname=willylinux
locales=es_ES.UTF-8 keyboard-layouts=latam timezone=America/Bogota
```

Definidos en `src/tree-2.5/auto/config` (y su equivalente en `src/tree-2.0/auto/config`, sin
`persistence`). Las variables de entorno `WILLY_ARCH`, `WILLY_DIST`, `WILLY_LOCALE`,
`WILLY_KEYBOARD` y `WILLY_TZ` permiten cambiarlas sin editar el archivo.

## Menús de arranque

- **BIOS:** isolinux con `splash.png`, `menu title WILLY LINUX <versión>`, `timeout 50`
  (5 s), textos en español y color corporativo `3d8c7a`.
- **UEFI:** GRUB con `boot/grub/live-theme/theme.txt` (dibuja el logo), `config.cfg` con
  `set timeout=5` escrito a mano (live-build no lo pone) y submenús traducidos
  («Opciones avanzadas de arranque», «Utilidades», «Ajustes del firmware UEFI», «Comprobar la
  integridad del USB»).
- Los textos se reescriben en `hooks/live/0200-bootmenu.hook.binary`, un hook de fase *binary*
  porque actúa sobre el contenido de la ISO ya generada.
- **Trampa documentada:** en `menu.cfg` y `utilities.cfg` las líneas de submenú empiezan con
  TAB, así que los patrones `sed` no pueden llevar `^`; si los llevan, no encuentran nada y el
  menú sale en inglés **sin ningún aviso**.

## Listas de paquetes

### Edición 2.5 / 2.5.5 — 234 paquetes declarados en 19 listas

| Lista | Paquetes | Contenido |
|---|---|---|
| `core` | 15 | `systemd-sysv`, `libpam-systemd` y la base del sistema |
| `live` | 4 | `live-boot`, `live-config` y sus utilidades |
| `x` | 7 | Xorg, `libinput`, fuentes |
| `escritorio` | 56 | KDE Plasma 6 al detalle: plasmashell, Dolphin, Konsole, Okular, SDDM, KDE Frameworks 6 |
| `apps` | 19 | LibreOffice, Firefox ESR, navegador de archivos, cliente de correo, gráficos |
| `multimedia` | 30 | PipeWire, WirePlumber, `pavucontrol-qt`, ALSA con `ucm2`/`tplg`, GStreamer good/bad/ugly/libav, FFmpeg, **VA-API**, VLC, mpv, Audacity, fuentes Noto/Hack |
| `tienda` | 13 | Discover, PackageKit, Flatpak, remoto de Flathub, `desktop-file-utils` |
| `boveda` | 9 | Plasma Vault, cryfs, KeePassXC, Back In Time, Borg |
| `red` | 7 | NetworkManager, su applet, herramientas de diagnóstico |
| `instalador` | 11 | `grub2-common`, `grub-pc`, `grub-pc-bin`, `grub-efi-amd64-bin`, `efibootmgr`, `os-prober`, parted, rsync, dosfstools |
| `impresion` | 7 | CUPS y su configurador |
| `bluetooth` | 3 | BlueZ y Bluedevil |
| `hardware` | 13 | microcódigo de CPU, `llvmpipe`, utilidades de hardware |
| `firmware` | 12 | `firmware-linux-free`/`-nonfree`/`-unofficial` |
| `rendimiento` | 2 | `zram-tools`, `earlyoom` |
| `monitoreo` | 6 | monitor de sistema y utilidades de estado |
| `utilidades` | 14 | `mc`, compresores, edición, descarga |
| `juegos` | 5 | juegos de mesa ligeros |
| `ajustes` | 1 | `yad`, para los diálogos propios |

### Ediciones ligeras (2.0 / 2.1) — 126 paquetes declarados en 14 listas

`core` 15, `escritorio` 27 (IceWM y sus complementos), `utilidades` 13, `apps` 12,
`multimedia` 12, `hardware` 8, `firmware` 7, `x` 7, `ajustes` 4, `live` 4, `monitoreo` 5,
`juegos` 5, `red` 5, `rendimiento` 2. La 2.1 añade además las listas de instalador, impresión y
Bluetooth.

## Hooks de personalización

Cinco hooks de fase *chroot* más dos de fase *binary* / *bootstrap*:

| Hook | Qué instala |
|---|---|
| `0050-willylinux.hook.chroot` | identidad visual: icono del lobito en todas las resoluciones, fondos, `LOGO=` en `os-release` (lo leen «Acerca del sistema» y Discover) |
| `0100-minimal.hook.chroot` | recortes mínimos de la base |
| `0200-bootmenu.hook.binary` | menús BIOS y UEFI en español, colores, timeout, splash |
| `0300-herramientas.hook.chroot` | `willy-info`, `willy-monitor`, `willy-captura`, `willy-sudo`, `willy-ajustes`, `willy-trafico`, `willy-red` |
| `0400-instalador.hook.chroot` | `willy-instalar`, `willy-persistencia`, `willy-actualizar`, `willy-actualizar-run` |
| `0500-bienvenida.hook.chroot` | `willy-bienvenida` (asistente de 16 opciones) |
| `0600-plasma.hook.chroot` | configuración de Plasma 6: tema `willy-dark`, paneles, sesiones, lanzador, `usermod -c "Willy Linux"` |
| `0700-identidad.hook.chroot` | `willy-medio`, `willy-guardado`, `willy-renombre-aplicar`, `willy-identidad`, `/etc/issue`, `.bashrc` |

## Identidad del sistema

| Elemento | Valor |
|---|---|
| Usuario live | `live` |
| Contraseña live | `willy` |
| Nombre de equipo | `willylinux` (`/etc/hostname` y `/etc/hosts` reales, en `includes.chroot/etc/`) |
| `PRETTY_NAME` | `Willy Linux <versión>`; `VERSION_ID` y `VERSION` coherentes por edición |
| Logo | `/usr/share/icons/hicolor/128x128/apps/willylinux.png`, referenciado por `LOGO=` en `os-release` |
| Tema de Plasma | `willy-dark` en `kdeglobals` |
| Sesiones | `plasma.desktop` (Wayland) y `plasmax11.desktop` (X11) |
| Servicios habilitados | SDDM como gestor de pantalla, NetworkManager, avahi, cups, zramswap |
| Sysctl propio | `net.ipv4.ping_group_range = 0 2147483647` en `/etc/sysctl.d/90-willylinux.conf` |

> **Por qué `/etc/hostname` y `/etc/hosts` van en `includes.chroot/etc/` y no en un hook:**
> `chroot_hostname` escribe `localhost.localdomain` y además desvía (`dpkg-divert`)
> `/usr/bin/hostname` con un *stub*; `chroot_hosts` escribe un `/etc/hosts` falso y guarda el
> original como `hosts.orig`. Solo la acción `remove`, al final de la fase chroot, copia los
> archivos de `includes.chroot/etc/` y quita la desviación. Si se ponen en un hook, se pierden.
> Y ojo: live-build aborta si hay un archivo a la vez en `includes.chroot` y en
> `includes.chroot_after_packages`.

## Por qué el `ping` necesita un sysctl

Debian no usa setuid en `/bin/ping`: le da la capability `cap_net_raw` mediante un atributo
extendido `security.capability`. Al empaquetar el chroot en squashfs **ese xattr se pierde**, así
que en el USB live `ping` devuelve `missing cap_net_raw+p capability or setuid?`. El sysctl
`ping_group_range` abre el socket ICMP a cualquier grupo y lo arregla sin tocar permisos, tanto
en vivo como instalado.

## Tamaños reales

| | ISO | squashfs | Sistema descomprimido |
|---|---|---|---|
| 2.5 / 2.5.5 | 1.849.540.608 B (1763 MB) | ~1,7 GB | ~4,1 GB |
| 2.1 | 1.134.166.016 B (1081 MB) | ~1,0 GB | ~2,5 GB |

El tope de cada edición se comprueba al final del build (`scripts/check-size.sh`); hay que
actualizarlo si se cambia el tope.

## Estructura del árbol de configuración

```
tree-2.5/
  auto/config                     opciones de lb config
  config/
    package-lists/*.list.chroot   cada paquete, declarado a mano
    hooks/live/*.hook.chroot      herramientas, instalador, asistente, Plasma, identidad
    includes.chroot/etc/          hostname, hosts, sysctl, skel
    bootloaders/                  splash.svg
  scripts/check-size.sh           control del tope
```

Los dos árboles completos están en [`src/`](../src).
