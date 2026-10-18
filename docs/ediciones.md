# Ediciones de Willy Linux

Seis ediciones publicadas desde cero. Cada una conserva su imagen anterior: **ninguna ISO se
borra**, las versiones previas quedan como `.bak-día.hora` junto a su `.sha256`.

## Tabla comparativa

| | 1.0 | 1.1 | 2.0 | 2.1 | 2.5 | 2.5.5 |
|---|---|---|---|---|---|---|
| Nombre de la ISO | `willylinux-amd64.iso` | `willylinux-v1.1-amd64.iso` | `willylinux-v2.0-minimalista-amd64.iso` | `willylinux-v2.1-amd64.iso` | `willylinux-v2.5-kde-amd64.iso` | `willylinux-v2.5.5-kde-amd64.iso` |
| Entrega | 2026-10-11 | 2026-10-12 | 2026-10-17 (16:16) | 2026-10-17 (16:52) | 2026-10-17 | 2026-10-17 |
| Tamaño | 703.594.496 B (671 MB) | 993.001.472 B (947 MB) | 1.110.900.736 B (1059 MB) | 1.142.931.456 B (1089 MB) | 1.849.540.608 B (1763 MB) | 1.849.540.608 B (1763 MB) |
| Tope autoimpuesto | 2 GB | 3 GB | 4 GB | 4 GB | 8 GB | 8 GB |
| % del tope | 34 % | 30 % | 26 % | 27 % | 21 % | 21 % |
| Escritorio | IceWM | IceWM | IceWM | IceWM | **KDE Plasma 6** | KDE Plasma 6 |
| RAM objetivo | 2 GB | 2–3 GB | 3–4 GB | 3–4 GB | 6–7 GB | 6–7 GB |
| Paquetes instalados | 565 | 710 | 896 | 965 | ~1592 | ~1592 |
| Arranque BIOS + UEFI | sí | sí | sí | sí | sí | sí |
| Instalador a disco | no | no | no | **sí** | sí | sí |
| USB persistente | no | no | no | **sí** | sí | sí |
| Impresión (CUPS) | no | no | no | **sí** | sí | sí |
| Bluetooth | no | no | no | **sí** | sí | sí |
| Botón de actualizar | no | no | no | **sí** | sí | sí |
| Audio PipeWire | no (PulseAudio) | no | no | no | **sí** | sí |
| Tienda Discover + Flathub | no | no | no | no | **sí** | sí |
| Sistema bóveda (Vault + KeePassXC + Back In Time) | no | no | no | no | **sí** | sí |
| Vídeo por GPU (VA-API) | no | no | **sí** (desde 2026-10-17) | **sí** (desde 2026-10-17) | **sí** (desde 2026-10-17) | sí |
| SHA-256 de la entrega | `446a54c0…f8aa3c` | `f01a95f6…fcc6b0fb` | `cca27c81…d663bcce` | `10432e43…001cbc5c77` | `1f3e2f60…506cc349` | `43b66af8…d9a8a8c8` |

Hashes completos y lineage de cada recompilación: [historial](historial.md).

---

## 1.0 — la prueba de concepto

Primera imagen arrancable: Debian live con IceWM, Firefox ESR, LibreOffice, reproductor y las
utilidades mínimas. Demostró que la ISO arrancaba en BIOS, UEFI, USB y VirtualBox, y se guardó
como copia de seguridad porque funcionaba.

- Fichero: `willylinux-amd64.iso` (703.594.496 B), SHA-256
  `446a54c08709d8f23d80f2126cc6acfe716bcf5dc14bf365bbf60c05adf8aa3c`, verificado idéntico
  desde Windows y desde WSL.
- 565 paquetes. Sin instalador a disco: era solo sistema live.

## 1.1 — más programas sin salirse del tope

Se mantuvo la filosofía ligera y se amplió el contenido (juegos de mesa, utilidades, códecs)
subiendo el tope autoimpuesto de 2 GB a 3 GB. 710 paquetes en 947 MB, un 30 % del tope.

- Copias: `Escritorio/Willy Linux 1.1/willylinux-v1.1-amd64.iso` y `out/` del espacio de trabajo.
- Intermedia `bak-intermedio-16.23` (985.661.440 B, `cb5a68bc…`) conservada: muestra el
  crecimiento real entre intentos.

## 2.0 Minimalista — la más ligera, congelada

Pensada para equipos con 3–4 GB de RAM y CPU limitada, solo 64 bits. IceWM con menú propio en
español, panel de consumo con Conky, capturas, monitor de tráfico y el primer asistente de
ajustes.

Quedó **congelada a propósito con dos defectos** que solo se arreglaron en la 2.1:

1. Iconos de catálogo inexistentes en el menú (Adwaita en trixie solo trae versiones
   `-symbolic`, y el menú pedía nombres que no estaban).
2. `mousepad.desktop` mal referenciado en `mimeapps.list`.

El usuario mandó no recompilarla («si no es mucho problema déjalo así, concéntrate en la
2.1»), así que se conservó como referencia. De esa 2.0 **sí quedaba la ISO** en
`E:\WILLIAM\Willy Linux 2.0\` (1.102.970.880 B); lo que se borró para liberar espacio fue la
carpeta `Escritorio\Willy Linux 2.0`, de la que solo quedaron el `.sha256` en `out/` y el árbol
de configuración (`src/tree-2.0/` en este repositorio).

El 17-10 se recompiló igualmente, porque los seis arreglos de la ronda final (VA-API,
`alsa-ucm-conf`/`topology`, `ping` sin root, `willy-red` y su entrada en el menú, alturas del
asistente) también le servían. **Aclaración importante sobre el instalador:** la 2.0 nunca tuvo
`willy-instalar`; esa función es propia de la 2.1 y de la 2.5. Por tanto el defecto de
`grub-install` descubierto el 14-10 **no aplica a la 2.0**: si alguien la copia a un disco con
otra herramienta, ese disco tampoco arrancará, pero no es un fallo de la edición, es que la 2.0
se diseñó como sistema live. Su Release dice expresamente «sin instalador a disco».

- ISO: `willylinux-v2.0-minimalista-amd64.iso`, 1.110.900.736 B, SHA-256
  `cca27c81fcb556d47c867d7675d3af70b038eaaea45a1860e6aa7d0cd663bcce` (construcción del 17-10 a
  las 16:16, 896 paquetes).
- La construcción de las 14:37 (`eadfb215…de02`) aún traía el defecto 2: `mimeapps.list`
  referenciaba `mousepad.desktop`, cuando el lanzador real de trixie es
  `org.xfce.mousepad.desktop`. Se corrigió en el árbol, se volvió a compilar el mismo día y esa
  ISO quedó conservada como `.bak-17.16.14`. La Release `v2.0` lleva la ISO corregida; dentro de
  ella se comprobó que **los siete lanzadores** referenciados en `mimeapps.list` existen de
  verdad (`feh`, `firefox-esr`, `mpv`, `mupdf`, `org.xfce.mousepad`, `pcmanfm`, `xarchiver`).

## 2.1 Minimalista — la ligera que se instala

Sobre la 2.0 se añadieron las cinco funciones que la convierten en un sistema operativo usable
en un equipo viejo:

| Mejora | Herramienta |
|---|---|
| Instalador al disco | `willy-instalar` |
| Persistencia en el USB | `willy-persistencia`, `willy-guardado` |
| Impresión | CUPS + su configurador gráfico |
| Bluetooth | BlueZ + gestor gráfico |
| Actualizar el sistema | `willy-actualizar` / `willy-actualizar-run` |

Además: iconos verificados dentro del squashfs, `mimeapps.list` corregido, título del menú BIOS
`WILLY LINUX 2.1`, rótulo 2.1 en el monitor y **seis** correcciones del instalador (las mismas
de la 2.5: tamaños negativos, holgura raíz–swap, EFI y swap por GUID, exclusión de `zram0`,
filtro `TYPE=part` y columnas de `lsblk -r`). El instalador se comprueba con un ensayo de siete
escenarios y 57 comprobaciones sobre un mundo simulado (`lsblk`, `parted`, `mkfs`, `mount`,
`grub-install` y `yad` falsos), sin tocar ningún disco real.

- ISO: `willylinux-v2.1-amd64.iso`, 1.142.931.456 B, SHA-256
  `10432e437bbfb245e0bc84c970d89c5e5562f4325758631a9364d6001cbc5c77` (entregada 17-10 a las
  16:52, 965 paquetes). Dentro de ella se comprobó `grub-install` y `grub-bios-setup` en
  `/usr/sbin`, 304 módulos `i386-pc`, 286 `x86_64-efi`, `grub2-common` y `grub-pc` 2.12-9,
  `efibootmgr` 18-2, `os-prober` 1.83, las dos guardas previas del instalador, la exclusión de
  `zram0`, la detección de EFI por GUID y **cero** tamaños negativos para `parted`.
- **Limitación conocida de esta ISO, descubierta el 2026-10-17 en el ensayo real de VirtualBox:**
  su instalador sigue comprobando `/lib/live/mount/medium`, y live-boot monta el medio en
  `/run/live/medium`, así que **se niega a instalar** («Esto solo funciona desde el USB…») incluso
  arrancando desde el USB. El arreglo (`willy-medio`, el mismo de la 2.5) está en
  `src/tree-2.1/config/hooks/live/0400-instalador.hook.chroot` y en la puerta de
  `recompilar-21.sh`, pero todavía no en la ISO publicada. La comprobación que faltó es la de
  `verificar-la-iso.md` («0 guardas con la ruta vieja»): se había hecho siempre sobre la 2.5 y no
  sobre la 2.1.
- **Segundo defecto del mismo ensayo (2026-10-17), común a la 2.1 y a la 2.5/2.5.5 publicadas:** en
  un equipo **BIOS** el instalador aborta en el particionado con `parted: invalid token: Willy`. En
  una tabla msdos el argumento que sigue a `mkpart` es el **tipo** (`primary`), no un nombre — los
  nombres solo los admite GPT —, así que la ruta UEFI funcionaba y la de BIOS no. Corregido en
  `src/tree-2.1` y `src/tree-2.5` (raiz `mkpart primary ext4 …`, swap con `$TIPOSW`, y la
  partición persistente del USB elegida por `blkid PTTYPE`) y vigilado por dos puertas nuevas:
  `comprobar-parted-mkpart.sh` (texto del hook) y `probar-parted-real.sh` (`parted` de verdad sobre
  archivos-image montados en `/dev/loop`, con un escenario que exige que el comando viejo siga
  fallando). El ensayo de lógica no podía verlo: su `parted` es burlado y solo anota la orden.
  La 2.5 y la 2.5.5 sí instalan en UEFI; en BIOS hay que recompilar.
- Ninguna 2.1 anterior se borró: se conservan como `.bak-12.21.06` (la primera, hash
  `3e3c8965…a8c4`), `.bak-17.15.05`, `.bak-17.15.44` y `.bak-17.16.51`.

## 2.5 — escritorio completo

Edición para equipos actuales (6–7 GB de RAM), con **KDE Plasma 6** elegido frente a GNOME y
Hyprland. Todo lo que la hace distinta está listado en
[por qué es diferente](../README.md#qué-la-diferencia-de-otra-distribución-live); aquí, el
resumen de contenido por bloque:

- **Escritorio:** Plasma 6 con Wayland (`plasma.desktop`) y sesión X11 alternativa
  (`plasmax11.desktop`), SDDM, Dolphin, Konsole, Okular, Discover, tema propio `willy-dark`.
- **Audio:** PipeWire + WirePlumber + `pavucontrol-qt`, `alsa-ucm-conf` y
  `alsa-topology-conf` (perfiles de portátil), `libcanberra-pulse` (pitido del panel).
- **Vídeo:** GStreamer good/bad/ugly/libav, FFmpeg, VLC, mpv, Audacity y **VA-API** con sus
  controladores (`i965-va-driver`, `intel-media-va-driver`, `mesa-va-drivers`,
  `mesa-vdpau-drivers`, `va-driver-all`, `vainfo`).
- **Tienda:** Discover + PackageKit + Flatpak con el remoto de Flathub y `desktop-file-utils`.
- **Bóveda:** Plasma Vault con cryfs, KeePassXC, Back In Time y Borg.
- **Sistema:** instalador propio, persistencia, `willy-red`, `zram-tools`, `earlyoom`,
  microcódigo de CPU y firmware propietario de WiFi/Bluetooth/sonido/gráfica.

## 2.5.5 — la misma imagen, con su etiqueta

Comparando las dos ISO montando el squashfs: **mismo tamaño, 1.7 GB de squashfs, inventario
idéntico de 120.493 ficheros y cero rutas exclusivas** entre una y otra. Solo difieren seis
textos por el número de versión (`/etc/issue`, `/etc/issue.net`, `.bashrc`, `usr/lib/os-release`,
`willy-bienvenida`, `willy-monitor`), el `splash.png` del arranque, el `initrd` (83 bytes de
marca de tiempo), `efi.img` (Volume ID) y los menús `menu.cfg`/`live.cfg`/`grub.cfg`.

**Conclusión honesta: la 2.5.5 es la 2.5 rebautizada, sin ningún cambio funcional.** Se mantiene
como edición propia porque así queda registrado el reintento, pero para usar, elige la 2.5: son
el mismo sistema.
