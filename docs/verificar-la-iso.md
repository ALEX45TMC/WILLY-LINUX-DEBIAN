# Verificar una ISO sin fiarse del log

Regla del proyecto: **`P: Build completed successfully` no significa que la ISO esté bien.** En
todos los defectos graves que se encontraron, el build había terminado limpio. La única prueba
válida es montar la imagen y mirar dentro.

## 1. Montar y mirar

```sh
mkdir -p /mnt/willy
sudo mount -o loop,ro willylinux-v2.5-kde-amd64.iso /mnt/willy
ls /mnt/willy/live/
#  filesystem.packages  filesystem.squashfs  initrd.img  vmlinuz  ...

mkdir -p /tmp/wsq
sudo mount -o loop,ro /mnt/willy/live/filesystem.squashfs /tmp/wsq
```

Sin `squashfs-tools` o sin root, alternativa: `unsquashfs -d /tmp/wsq /mnt/willy/live/filesystem.squashfs`
(ocupa ~4 GB descomprimido).

### Comprobaciones del artefacto

| Comprobar | Comando dentro de `/tmp/wsq` | Por qué |
|---|---|---|
| GRUB del instalador | `usr/sbin/grub-install`, `usr/sbin/grub-bios-setup`, `usr/bin/efibootmgr` | sin ellos el disco instalado no arranca |
| Módulos GRUB | `usr/lib/grub/i386-pc/` y `usr/lib/grub/x86_64-efi/` | uno por cada modo de arranque |
| VA-API | `usr/bin/vainfo` y `usr/lib/x86_64-linux-gnu/dri/*_drv_video.so` | decodificación de vídeo por GPU |
| Perfiles ALSA | `usr/share/alsa/ucm2/` | que la barra de volumen mande de verdad |
| Pitido del panel | `usr/lib/x86_64-linux-gnu/libcanberra-0.30/libcanberra-pulse.so` | feedback al cambiar volumen |
| Tienda | `usr/bin/update-desktop-database` | refrescar el menú al instalar de Flathub |
| Ping sin root | `etc/sysctl.d/90-willylinux.conf` con `ping_group_range` | squashfs pierde capabilities |
| Identidad | `etc/os-release` (`PRETTY_NAME`, `VERSION_ID`, `LOGO=`), `etc/hostname`, `etc/hosts` con contenido | el `sudo` se cuelga si `hosts` está vacío |
| Asistente | `usr/local/bin/willy-bienvenida` con 16 filas sueltas y 0 empaquetadas | `--hide-column` ocultaba media lista |
| Menú de red | `willy-ajustes` con el caso `14) … willy-red` y `willy-red` existente | la opción debe existir |
| Rutas del medio | `grep -R "/lib/live/mount" usr/local/bin` debe dar **0** guardas antiguas | live-boot cambió a `/run/live/medium` |
| Sintaxis | `bash -n` / `sh -n` sobre los ~22 scripts de `usr/local/bin` | un error de sintaxis no aparece hasta que se usa |

## 2. El formato de `filesystem.packages`

**Trampa confirmada:** el fichero usa `nombre:arquitectura<TAB>versión`, así que un
`grep -P "^paquete( |$)"` da **falsos negativos** (`pipewire`, `flatpak`, `vainfo` aparecen como
`pipewire:amd64`). La forma correcta:

```sh
awk -F'\t' -v P=libcanberra-pulse '{n=$1; sub(/:.*/,"",n); if(n==P) {print "ESTÁ: " $0; found=1}}
     END{if(!found) print "NO ESTÁ: " P}' /mnt/willy/live/filesystem.packages
```

Y **no uses `dpkg-query --root=/tmp/wsq`**: miente, porque la base de datos de dpkg dentro del
squashfs no refleja el estado final de la imagen. Lee los ficheros o `filesystem.packages`.

## 3. Cruce declarado ↔ construido

Antes de compilar, hay que cruzar lo que **se escribió** en `config/package-lists/*.list.chroot`
con lo que **salió** en `filesystem.packages`. Así se descubrió que los 6 paquetes VA-API estaban
declarados pero no en la ISO: se habían añadido después del último build.

```sh
# todos los paquetes declarados, sin comentarios ni líneas vacías
cat config/package-lists/*.list.chroot | grep -vE '^\s*#|^\s*$' | sort -u > /tmp/declarados
awk -F'\t' '{n=$1; sub(/:.*/,"",n); print n}' /mnt/willy/live/filesystem.packages | sort -u > /tmp/eniso
comm -23 /tmp/declarados /tmp/eniso        # declarados y AUSENTES en la imagen
```

## 4. Barrido de *Recommends*

Con `--apt-recommends false`, el barrido sistemático es: para cada paquete declarado, listar sus
`Recommends` con `apt-cache show` y comprobar cuáles no están en la imagen. Muchos Recommends
faltantes están instalados igualmente como Depends de otro; solo cuenta el que falta de verdad.
Ese barrido es el que encontró `desktop-file-utils` y `libcanberra-pulse`.

## 5. Probar el instalador sin discos reales

`probar-logica-instalador.sh` extrae `willy-instalar` del hook y lo ejecuta con `dash -x` dentro
de `unshare -m`, con `/sys/firmware`, `/proc/meminfo` y `/usr/sbin` fingidos y burlas de `lsblk`,
`parted`, `sudo`, `yad` y **el `willy-medio` real sacado del hook 0700** (sin él, el instalador
cree que no está en un USB live y aborta antes de tocar nada).

Siete escenarios:

| | Situación | Qué debe pasar |
|---|---|---|
| A | UEFI con Windows en el mismo disco | usa la ESP existente, no la formatea, añade Windows al menú |
| B | BIOS, 2 GB de RAM, disco de 30 GB | crea swap, parted en bytes absolutos, `grub-bios-setup` |
| C | el usuario cancela | no toca nada |
| D | UEFI, 6 GB, Secure Boot activado | avisa del Secure Boot y continúa si se le confirma |
| E | ISO sin `grub2-common` | **aborta antes de borrar** |
| F | ISO sin `grub-bios-setup` | **aborta antes de borrar** |
| G | rama manual con `cfdisk`, `PARTFLAGS` vacío | detecta la ESP por GUID y no dice «no hay partición EFI» |

Los tamaños se comprueban en bytes (`497142464000B` en el escenario B, `246960619520B` en el D),
porque `parted` rechaza tamaños negativos y trata el último byte como incluido.

**Lo que este ensayo no puede ver.** Su `parted` es burlado: anota la orden y devuelve 0, así que
no comprueba la **sintaxis** de `parted`. Por eso pasó desapercibido el `mkpart Willy ext4 …` de la
rama BIOS, que un `parted` real rechaza con `invalid token` (en msdos va el tipo, no el nombre). El
ensayo real de VirtualBox del 2026-10-17 lo descubrió, y desde entonces hay dos piezas más:

- `probar-parted-real.sh`: crea el `preparar()` tal cual está en el hook, lo corre contra un
  `parted` **de verdad** sobre archivos-image montados en `/dev/loop` (nunca un disco real) y
  comprueba tabla, número de particiones y flags en BIOS y en UEFI. Incluye un escenario de
  *dientes*: el comando viejo con nombre en msdos **tiene** que fallar; si alguna vez pasa, el
  ensayo avisa de que ha perdido su razón de ser. Necesita `root` y `losetup` (se corre en WSL).
- `comprobar-parted-mkpart.sh`: puerta estática sobre el texto del hook — ninguna `mkpart` de la
  rama msdos puede llevar nombre, la swap ha de usar `$TIPOSW` y la persistencia del USB ha de
  elegir `$NOMBREP` según `blkid PTTYPE`. Va dentro de los guiones de compilación **y también sobre
  el artefacto**: `verificar-iso-25-nueva.sh` la corre contra el `/usr/local/bin/willy-instalar` y
  el `willy-persistencia` que ya están dentro de la ISO montada, que es el sitio donde la 2.1 tenía
  el defecto y nadie miraba.

## 6. Puertas antes de compilar

El guion de compilación aborta si:

- hay otro build corriendo o algún montaje pendiente;
- los **5 hooks** no son idénticos byte a byte entre el árbol maestro y los dos árboles de
  compilación;
- **todos** los `*.list.chroot` no son idénticos entre las dos ediciones y el maestro (un paquete
  añadido solo en un sitio se compilaría en una ISO y no en la otra);
- falta `grub2-common`, el *preflight* o el guardado USB-en-disco en los árboles;
- alguna `mkpart` de la rama BIOS lleva nombre de partición (`comprobar-parted-mkpart.sh`);
- la 2.1 conserva la comprobación de ruta vieja `/lib/live/mount/medium` en vez de `willy-medio`;
- el espacio libre real del disco del host es menor de 40 GB.

## 7. Entrega

- Se copia la ISO con `rsync --append --partial` y reintentos (el canal 9p de WSL puede fallar a
  mitad con `Cannot allocate memory`).
- Se escribe el `.sha256` junto a la ISO.
- La ISO anterior se **renombra** a `.bak-día.hora` con su hash: **ninguna imagen se borra**.
- `lb clean` se lleva por delante la ISO generada dentro de WSL: primero se copia y se verifica,
  y solo después se limpia.
- El tamaño se comprueba contra el tope de la edición antes de dar la entrega por buena.

## 8. Trampas de las herramientas de este PC

- `grep -c $'\r'` en Git Bash **cuenta líneas, no retornos de carro**: dio la alarma falsa de que
  los árboles estaban en CRLF. Medida real: `tr -dc '\r' < fichero | wc -c`.
- El `mtime` de una ISO en `/mnt/e` **no es la hora de entrega** (conserva el del árbol de build,
  y 9p muestra horas visiblemente falsas). Para saber si es de hoy, mira el `.sha256` o el log.
- WSL (root) no tiene `python3`: los guiones de mantenimiento van en POSIX shell + `awk` + `sed`
  (y `awk` es *mawk*: sin `gensub`).
- `pkill -f "nombre"` lanzado desde el mismo `wsl.exe` **se mata a sí mismo** (su `cmdline`
  contiene el patrón): devuelve exit 15 y salida vacía. Mata por PID.
- Para saber en qué fase va un build: `grep -a "^P: " log`, los marcadores de
  `<árbol>/.build/*` por su mtime, y si no conoces la ruta del log, `ls -l /proc/<pid>/fd`.
