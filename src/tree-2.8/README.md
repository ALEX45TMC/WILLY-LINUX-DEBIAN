# Willy Linux 2.8 — edición de escritorio moderno

![Willy Linux](config/includes.chroot/usr/share/backgrounds/willylinux/willylinux.png)

Basada en **Debian 13 (trixie)** con **KDE Plasma 6.3**. Nace del árbol de la **2.5.5**
(copiado íntegro a `2.8/tree` el 17-10-2026) y mantiene su objetivo de consumo:
**6–7 GB de RAM** con el escritorio, el navegador y una tarea de IA abiertos.
Tope de la ISO: **8 GB**.

Convive con la **2.1 Minimalista** (IceWM, PCs viejos) y con la **2.5.5** ya entregada:
son árboles de configuración separados, no ramas del mismo fichero.

## Qué trae

| Bloque | Qué incluye |
|---|---|
| Escritorio | Plasma 6.3 con SDDM (autologin del usuario `live`), tema Breeze oscuro, iconos `willy-dark`, `kwin-x11` y `kwin-wayland`, Dolphin, Konsole, Kate, Okular, Gwenview, Ark, Spectacle |
| Barra | Centrada y a 54 px, estilo Windows 11, aplicada en la primera sesión (`willy-panel`) |
| Audio | PipeWire + WirePlumber + pipewire-pulse, `plasma-pa` en el panel y `pavucontrol-qt` |
| Idioma, teclado y país | KCM nativos (`kcm_regionandlang`) y el asistente `willy-bienvenida`, que abre cada ajuste |
| Tienda | Plasma Discover con backend Flatpak, remoto Flathub en `/etc/flatpak/remotes.d` y fwupd |
| Bóveda | Carpetas acorazadas (Plasma Vault + cryfs), KeePassXC, Back In Time y Borg backup |
| Bienvenida / Qoder | Asistente de primer arranque: Qoder se instala si el usuario quiere y se puede quitar desde el mismo sitio |
| Hardware | `non-free-firmware`, microcode AMD e Intel, mesa con llvmpipe, Wacom, ntfs-3g, exfatprogs |
| Bajo consumo | zram, earlyoom (con `plasmashell` y `Xorg` protegidos) y `power-profiles-daemon` |
| Instalador | `willy-instalar` (BIOS y UEFI, respeta la ESP de Windows) y `willy-persistencia` para el USB |

Arranca en BIOS (isolinux) y UEFI (GRUB), en USB escrito en modo DD de Rufus y en
VirtualBox. La compresión del squashfs sigue siendo **gzip**: se probó `zstd` y se volvió
atrás, porque si el kernel no trae `CONFIG_SQUASHFS_ZSTD` la ISO no arranca y con 6 GB
de margen bajo el tope no compensa el riesgo.

## Qué cambia frente a la 2.5.5

| Bloque | Cambio |
|---|---|
| Identidad | `2.8` en os-release, `/etc/issue`, menú de arranque, panel de consumo, asistente de bienvenida, `.bashrc` y etiqueta de volumen `WILLYLINUX28` |
| Barra de tareas | **Centrada y más alta (54 px)**, aplicada en la primera sesión con reintentos |
| Instalador | Particionado arreglado, **capaz de decir qué falló** y cortando cuando el disco no va a arrancar |
| Instalador: acceso | El disco instalado **pide la contraseña** elegida: se vacía `User=` en `/etc/sddm.conf` *y* en `sddm.conf.d/willy.conf` y se comprueba después de editar |
| Instalador: entorno | Lleva al disco la **zona horaria, el idioma y el teclado** de la línea de arranque y pasa `journald` a `Storage=persistent` (antes el disco arrancaba en UTC y sin historial) |
| Cortafuegos | **`ufw` activado desde el primer arranque** (`ENABLED=yes` + `ufw.service`), que es lo que necesitaba el widget *Cortafuegos* del panel para funcionar |
| Sesión live | La contraseña `willy` de la cuenta live se escribe **en la propia imagen** (hook 0050). Probado el 07-11 en VirtualBox: el bloqueo automático de Plasma dejaba la sesión inservible porque la cuenta no tenía hash y ni `willy` ni `live` abrían la pantalla |
| Paquetes | `dbus-x11`, `libkf6config-bin`, `psmisc` en `core.list.chroot` y **`fdisk`** en `instalador.list.chroot` (250 declarados en total) |
| Paquetes (uso diario) | `libspa-0.2-bluetooth` (audio bluetooth), `ufw`, `smbclient` (carpetas `smb://`), `mobile-broadband-provider-info` (4G), `hplip` (impresoras HP), `sane-utils` + `skanpage` (escáner), `7zip` + `unar` (`.7z`/`.rar` en Ark), `kimageformat-plugins`, `adwaita-icon-theme` y las fuentes `liberation`/`carlito`/`caladea` |

## Los siete fallos del instalador que se cerraron

El ensayo del 17-10-2026 en `willy-inst-bios` dejó el VDI en 3 MB: la copia nunca empezó
porque el particionado abortó.

1. **`parted: invalid token: Willy`** — en una tabla `msdos` el argumento que sigue a
   `mkpart` es el *tipo* (primary/extended/logical), no un nombre. **Comprobado montando
   la 2.5.5 entregada** (`scripts/auditar-iso.sh`): su `/usr/local/bin/willy-instalar`
   tiene `mkpart Willy ext4` tambien en la rama BIOS. El arbol ya estaba corregido, pero
   el ISO se compilo antes de esa correccion.
2. **`mkpart WillySwap linux-swap`** — el mismo error, pero en la particion de swap y en
   **ambas** ramas: en msdos `WillySwap` no es un tipo valido, y el swap solo se crea en
   equipos de menos de 8 GB de RAM, o sea que el fallo aparecia justo en los portatiles
   de 4 GB para los que esta pensada la edicion.
3. **Choque raíz/swap** — el final de la raíz se dejaba en `INISWAP - 512` bytes. parted
   redondea cada posición al sector más cercano, y con discos que no son un número entero
   de MiB ese redondeo sube el final de la raíz hasta el inicio del swap (`Can't have a
   partition inside another`). Ahora la separación es de **1 MiB**, que el redondeo no
   puede cruzar, y el swap sigue cayendo alineado porque `INISWAP` es un número de GiB
   enteros.
4. **Fallo mudo** — cada `mkpart` devolvía 1 y el único aviso era *"No se pudo
   particionar. Mira el registro"*, que nadie lee. Se añadió `P()`, que captura la salida
   de parted y la enseña en el diálogo.
5. **`/etc/fstab` con `UUID=` vacío** — si `blkid` no devolvía UUID (partición recién
   creada que el kernel aún no registró, disco lleno), el instalador escribía
   `UUID= / ext4 ...` y el disco instalado **no arrancaba sin decir por qué**. Ahora corta
   y avisa, y si el UUID que falta es el del swap o de la EFI se documenta y se deja fuera
   del fstab en vez de escribir una linea rota.

Comprobación nueva además: **disco GPT arrancado en BIOS**. Sin una partición `bios_grub`
GRUB no tiene dónde escribir el segundo arranque, así que el disco quedaba copiado y
perfecto pero **no encendía**. Ahora se detecta antes de borrar nada y se le dice al
usuario que cree esa partición con cfdisk o que arranque en UEFI.

6. **`grub-install` fallando y dando la instalación por buena** — el único control que
   había era `test -s /boot/grub/grub.cfg`, y **`grub-mkconfig` escribe ese fichero aunque
   el cargador no se haya instalado**. Un `grub-install` roto (BIOS sin `bios_grub`, ESP sin
   sitio, NVRAM que no acepta la entrada) terminaba con el diálogo de éxito en un disco que
   no encendía. Ahora hay un `GRUBOK` que solo se pone cuando `grub-install` devuelve 0, con
   segundo intento en BIOS y, en UEFI, la prueba física de que quede algún `.efi` en la ESP;
   sin eso el instalador corta y lo dice.
7. **`cfdisk` no existía en la ISO** — la opción *"particionar antes con cfdisk"* ejecuta
   `konsole -e sh -c "sudo cfdisk $DISK"`, y `cfdisk` viene en el paquete `fdisk`, que no
   estaba declarado. El ensayo del 20-10 sobre la 2.8 lo dio como FALTA montando el
   squashfs: se abrió una consola sin binario y sin explicación. Añadido a
   `instalador.list.chroot`.

## Lo que se rompió al entregar (20-10, fuera del instalador)

* **`sha256sum` sobre `/mnt/e` reventó con `Cannot allocate memory`** y, como el guion va
  con `set -euo pipefail`, el build **murió en el paso 5 de 6**: dejó `.sha256` en 0 bytes y
  no llegó a la limpieza. El hash se calcula del original dentro de ext4 —los mismos bytes
  que `cmp` acaba de comparar— y a E: solo se le escribe el texto.
* **Cuatro FALTA falsos del primer verificador**: `isoinfo` y `python3` no existen en el WSL
  (la etiqueta de volumen se lee ahora con `dd` desde el PVD, offset 32808),
  `filesystem.packages` vive **junto** al squashfs (`live/` dentro de la ISO) y no dentro,
  `pipewire` y compañía salen listados como **`nombre:arquitectura`**, y los comentarios del
  propio script (`# INISWAP - 512`, `# panelIds`) casaban con los greps que buscaban el bug.
  Ahora el verificador compara **contra el árbol** (`cmp` de cada `willy-*` generado) y eso
  es lo que pilló que la ISO en tránsito no llevaba aún el arreglo de `grub-install`.
* **Guiones con CRLF**: un `wsl.exe -- bash -c '...'` con comillas dobles sale con las
  comillas rotas, y `bash /mnt/e/.../guion.sh` se traga el `\r`. El lanzador pasa los guiones
  a LF (`tr -d '\r'`) dentro de WSL antes de ejecutarlos.

## Los tres paquetes declarados "por si acaso"

Se añadieron a `core.list.chroot` porque `willy-panel` y el instalador los usan. Al
auditar la ISO 2.5.5 montándola resultó que **los tres binarios ya estaban** en la
imagen (`/usr/bin/dbus-send`, `/usr/bin/kwriteconfig6`, `/usr/bin/killall`): llegaban
como dependencias (`dbus-send` viene en `dbus-bin`, que es `Depends` de `dbus`). No
arreglan nada, es blindaje: con `--apt-recommends false` conviene declarar lo que se
usa en vez de confiar en que otro paquete lo arrastre.

| Paquete | Aporta | Ya estaba en la 2.5.5 |
|---|---|---|
| `dbus-x11` | (nada que usemos: `dbus-send` es de `dbus-bin`) | sí el binario |
| `libkf6config-bin` | `kreadconfig6`, `kwriteconfig6` | sí |
| `psmisc` | `killall` | sí |

## Cómo se centra la barra (y qué pasa si no se puede)

`willy-panel` tiene dos rutas, en este orden:

1. **API de scripts de Plasma 6.** Ya no lee el global `panelIds`, que **no existe** en
   Plasma 6 —por eso la versión anterior no tocaba ninguna barra y salía con 0, en
   silencio—. Recorre el árbol de `ShellObject` desde `Cm.rootItem` buscando los
   `pluginName` que empiezan por `org.kde.panel` y escribe `alignment` y `height`.
2. **`plasmashellrc` con kwriteconfig6** sobre las secciones `[Containments][N][General]`
   que ya tienen clave `alignment` (las barras; los contenedores de escritorio no la
   tienen y se dejan), y reinicio de plasmashell.

En la primera sesión solo se usa la ruta 1 (`--callado`): si Plasma no contesta se deja
la barra clásica y el usuario la centra desde el asistente de bienvenida (opción 14), que
sí puede reiniciar plasmashell porque está delante.

**Esto no está probado en una sesión real.** Las dos rutas y el valor exacto de `height`
que respeta Plasma 6.3 hay que verlos en la VM antes de dar la 2.8 por buena.

## Arranque gráfico

SDDM fija **`Session=plasmax11.desktop`** con `DisplayServer=x11`. En trixie
`plasma.desktop` solo existe como sesión **Wayland** (el X11 se llama `plasmax11`), y
dejar la mezcla hubiese hecho el arranque depender de OpenGL en el equipo; con X11
arranca en VirtualBox sin aceleración 3D y en gráficas antiguas. `kwin-wayland` sigue
instalado: para probarlo se cambia esa línea.

## Compile y entrega

```sh
# 1) Hyper-V encendido (restore-hyperv.cmd) y reinicio hecho
wsl.exe -d Debian -u root -- bash "/mnt/e/Willy Linux/2.8/wsl-build-2.8.sh"
# 2) verificar el ARTEFACTO, no el log
wsl.exe -d Debian -u root -- bash "/mnt/e/Willy Linux/2.8/verificar-2.8.sh"
```

Para un **cambio en el árbol después de un build completo** no hace falta recompilar del
todo: `rebuild-2.8.sh` sincroniza `tree/` al proyecto de WSL, borra los sellos de
`.build/` de `chroot_package-lists`, `chroot_install-packages`, `chroot_hooks` y todos los
`binary_*`, y vuelve con `lb build noauto`. El bootstrap queda por su sello y por
`bootstrap_cache.save`, así que se rehace el squashfs y la ISO (unos 25 min con la caché de
`.deb` puesta) en vez de la hora y media del build entero. Se lanza desacoplado con
`lanzar-rebuild.sh`, que además pasa los guiones a LF.

| Qué | Dónde |
|---|---|
| Árbol de configuración | `E:\Willy Linux\2.8\tree` |
| Guión de compilación | `E:\Willy Linux\2.8\wsl-build-2.8.sh` (entero) y `rebuild-2.8.sh` (desde el chroot) |
| Verificador de artefacto | `E:\Willy Linux\2.8\verificar-2.8.sh` |
| Distro WSL (ext4.vhdx) | `E:\Willy Linux\wsl-build\Debian` |
| Caché de .deb | arranca enlazando `/root/willy-cache-2.5`, se guarda en `/root/willy-cache-2.8` |
| ISO entregada | `E:\Willy Linux\2.8\iso\willylinux-v2.8-kde-amd64.iso` |

Antes de compilar, los nombres de los 250 paquetes se validan contra el índice de trixie
(`scripts/check-packages.sh`). **Ninguna copia anterior se borra:** si ya existe una ISO
con el mismo nombre se conserva con sufijo `.bak-DD.HH.MM` junto a su `.sha256`.

Tres lecciones del proceso, ya incorporadas en los guiones: **`cp` de WSL a `/mnt/e`
revienta con `Cannot allocate memory`** y hay que entregar con
`rsync --append --partial`; **`lb clean` se lleva el `.iso` generado dentro de WSL**, así
que primero se entrega y verifica y después se limpia; y **el log del build no prueba el
artefacto**, por eso existe `verificar-2.8.sh`, que monta la ISO entregada y lee el
código real de `willy-instalar`.

## Pendiente de verificar en la primera arrancada

1. **Instalación real en disco** en BIOS y en UEFI, con swap (VM de 4 GB) y sin él (VM de
   8 GB), y que el disco instalado **encienda** sin el USB.
2. Que la barra quede centrada y a 54 px, y qué pasa al elegir el modo clásico.
3. Que `willy-panel` funcione por D-Bus o tenga que caer al fichero (la salida debe decir
   `barras=N`).
4. `willy-persistencia` sobre el esquema nuevo.
5. Los 250 paquetes declarados contra `live/filesystem.packages` de la ISO.
