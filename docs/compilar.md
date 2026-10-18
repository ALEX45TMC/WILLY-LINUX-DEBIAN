# Cómo se compila

## Requisitos

| | |
|---|---|
| Sistema donde se compila | Debian 13 *trixie* (en la práctica, **WSL2** sobre Windows) |
| Herramientas | `live-build`, `debootstrap`, `squashfs-tools`, `xorriso`, `dosfstools`, `mtools`, `cpio`, `rsync`, `zstd`, `ca-certificates` |
| Espacio libre real | **40 GB** para la 2.5 (chroot Plasma + binary + ISO); 15 GB para las ligeras |
| Tiempo | 25–45 min por edición (la 2.5, más) |
| En WSL2 | la plataforma de hipervisor debe estar **activada**; eso impide usar VirtualBox al mismo tiempo |

```sh
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  live-build debootstrap squashfs-tools xorriso dosfstools mtools \
  cpio rsync zstd ca-certificates
```

## Pasos

```sh
cp -a src/tree-2.5/. /root/mi-build/          # el árbol de configuración
cd /root/mi-build
chmod +x auto/* scripts/*.sh config/hooks/live/*.hook.* 2>/dev/null || true
lb clean 2>/dev/null || true                  # empezar limpio
lb config                                     # lee auto/config
test -f .build/config || { echo "FALLO lb config"; exit 1; }
lb bootstrap                                  # base mínima
lb build                                      # paquetes, hooks, kernel, squashfs, ISO
```

El resultado es `live-image-amd64.hybrid.iso` en la raíz del árbol.

### Comprobaciones que hace el guion de compilación

1. **Sin otro build corriendo** y sin montajes pendientes.
2. **Puertas de sincronización:** los 5 hooks y **todos** los `*.list.chroot` idénticos byte a
   byte entre el árbol maestro y los árboles de compilación de cada edición. Si difieren, aborta.
3. **Base correcta:** `dpkg-query -W -f='${Version}' libc6` debe dar `2.41-12+deb13*`, o sea
   trixie. Un `sid` colado en la base rompe cosas de forma difícil de diagnosticar.
4. **Tope de tamaño** (`scripts/check-size.sh`): la 2.5 no pasa de 8 GB; si se cambia el tope,
   hay que actualizar el script.
5. **Verificación montando la ISO** ([verificar-la-iso](verificar-la-iso.md)).

## Caché de paquetes

Para no volver a bajar 1,6 GB de `.deb` en cada intento, los `.deb` se guardan fuera del árbol
y se enlazan antes de compilar:

```sh
KEEP=/root/willy-cache-2.5
mkdir -p cache/packages.chroot
cp -al "$KEEP/packages.chroot/." cache/packages.chroot/    # enlaces duros, no copia
```

Cada edición tiene su caché (`/root/willy-cache-2.1`, `/root/willy-cache-2.5`) para no pisarse.

## Entregar

```sh
# 1) copiar con reintentos (el canal 9p de WSL puede fallar a mitad)
rsync --append --partial -h live-image-amd64.hybrid.iso "/mnt/e/Willy Linux/2.5/iso/willylinux-v2.5-kde-amd64.iso.tmp"
mv "...iso.tmp" "...iso"
# 2) hash
sha256sum willylinux-v2.5-kde-amd64.iso > willylinux-v2.5-kde-amd64.iso.sha256
# 3) conservar la anterior, nunca borrarla
[ -f anterior.iso ] && mv anterior.iso anterior.iso.bak-$(date +%d.%H.%M)
# 4) y solo DESPUÉS de verificar: lb clean
```

> `lb clean` **se lleva por delante la ISO** generada dentro del árbol. Primero se copia, se
> verifica y se hash; después se limpia.

## Cambiar la etiqueta de versión

Para sacar una `.5` o una revisión nueva hay que tocar, todos a la vez:

- `auto/config`: `--iso-volume` y `--iso-application`;
- `hooks/live/0050-willylinux.hook.chroot`: `PRETTY_NAME`, `VERSION_ID`, `VERSION` en
  `os-release`;
- `hooks/live/0200-bootmenu.hook.binary`: la variable `VERSION` del menú BIOS y del GRUB;
- `hooks/live/0500-bienvenida.hook.chroot` y `0300-herramientas.hook.chroot`: el rótulo del
  asistente y del monitor;
- `bootloaders/splash.svg` / el `splash.png` generado, que dibuja el número.

**Advertencia documentada:** rebautizar **solo cambia etiquetas**. La 2.5 y la 2.5.5 del
2026-10-13 dieron en un inventario idéntico de 120.493 ficheros y cero rutas exclusivas: son el
mismo sistema. Un número nuevo de versión tiene que traer cambios reales, o no lo subas.

## Cómo lanzar un build que no se muera

Dos métodos probados:

- **Acoplado desde una llamada en segundo plano de la CLI** (`wsl -u root -- bash <ruta>.sh` con
  el ejecutor en background) y que el script redirija toda su salida a un log en `/mnt/e`.
  Sobrevive aunque la CLI se corte.
- **Desacoplado dentro de WSL** con `setsid nohup … &`, pero **lanzado desde un fichero**
  (`bash /root/lanzar-detached.sh <script> <log>`). Escrito en línea dentro de
  `wsl.exe -- bash -lc`, el escapado de MSYS lo rompe y devuelve exit 127 sin dejar proceso.

Nunca pases comandos con `$` o comillas anidadas por `wsl.exe -- bash -c '…'`: las variables se
expanden antes de llegar, el comando **devuelve 0** y parece que funcionó. Escribe un `.sh` y
ejecútalo por ruta.

## Probar en VirtualBox después de compilar

Orden práctico en un PC con WSL2:

1. `restore-hyperv.cmd` + reiniciar → **compilar** y entregar la ISO.
2. `disable-hyperv.cmd` + reiniciar → **probar** en VirtualBox.
3. Volver a 1 para la siguiente ronda.

Con Hyper-V activo, cualquier `VBoxManage startvm` termina en `gurumeditation`. Y para manejar la
VM sin ratón: `VBoxManage controlvm keyboardputscancode` con códigos crudos PS/2 (`Meta` abre el
lanzador de Plasma), porque mover el puntero del host no se traduce de forma fiable al invitado.

## Estructura del árbol

```
auto/config                          opciones de lb config
config/package-lists/*.list.chroot   cada paquete, a mano
config/hooks/live/*.hook.chroot      8 hooks: identidad, minimal, bootmenu,
                                     herramientas, instalador, bienvenida, plasma, identidad
config/includes.chroot/etc/          hostname, hosts, sysctl, skel
config/bootloaders/                  splash.svg
scripts/check-size.sh                control del tope
```

Los árboles completos están en [`src/`](../src). Los ensayos del instalador, en
**[`src/pruebas/`](../src/pruebas)**: `probar-logica-instalador.sh` y `probar-logica-21.sh` (mundo
simulado, burlas de `parted`/`lsblk`/`yad`), `probar-parted-real.sh` (`parted` de verdad sobre
archivos-image en `/dev/loop`) y `comprobar-parted-mkpart.sh` (puerta estática del texto del hook).
Ninguno toca un disco real. Los tres ensayos se corren como `root` (el de lógica crea nodos en
`/dev` y usa `unshare -m`; el de `parted` necesita `losetup`); la puerta estática no necesita nada
de eso y es la que va dentro de los guiones de compilación.
