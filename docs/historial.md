# Historial de versiones y cambios

Cada ISO entregada, con lo que cambió respecto a la anterior, su tamaño y su SHA-256.
Las imágenes anteriores **nunca se borran**: se renombran `.bak-día.hora` con su `.sha256`.

---

## 2026-10-17 (tarde) — 2.0 y 2.1 recompiladas: el instalador deja de ser una promesa

Las dos ediciones ligeras se compilaron otra vez el mismo día, cada una por un motivo distinto.

**ISO 2.0:** `willylinux-v2.0-minimalista-amd64.iso`, 1.110.900.736 B (1059 MB, 26 % del tope),
SHA-256 `cca27c81fcb556d47c867d7675d3af70b038eaaea45a1860e6aa7d0cd663bcce` (entregada 16:16,
896 paquetes). Es la misma construcción de las 14:37 (`eadfb215…de02`, conservada como
`.bak-17.16.14`) más el último defecto que le quedaba: `mimeapps.list` apuntaba a
`mousepad.desktop`, y el lanzador real de trixie es `org.xfce.mousepad.desktop`, así que
`xdg-open` no abría ni textos ni escritorios. Dentro de la ISO entregada se comprobó que **los
siete** lanzadores referenciados existen: `feh`, `firefox-esr`, `mpv`, `mupdf`,
`org.xfce.mousepad`, `pcmanfm`, `xarchiver`.

**ISO 2.1:** `willylinux-v2.1-amd64.iso`, 1.142.931.456 B (1089 MB, 27 % del tope),
SHA-256 `10432e437bbfb245e0bc84c970d89c5e5562f4325758631a9364d6001cbc5c77` (entregada 16:52,
965 paquetes). A la 2.1 se le portaron las **seis** correcciones de particionado que solo
estaban en la 2.5:

| # | Arreglo | Efecto |
|---|---|---|
| 1 | `parted` ya no recibe `-2GiB`, se calculan bytes absolutos con sufijo `B` | la rama automática dejaba de abortar con `opción inválida -- '2'` |
| 2 | `FINRAIZ = INISWAP − 512` bytes y swap redondeada a GiB | desaparece el `the closest location we can manage` y el aviso de alineación |
| 3 | EFI y swap detectadas por **GUID** (`PARTTYPE` `c12a7328-…` / `0657fd6d-…`) | la rama manual dejaba de decir «No hay partición EFI (esp)» con `PARTFLAGS` vacío |
| 4 | El selector de raíz filtra `TYPE=part` | ya no ofrece el disco entero como raíz |
| 5 | El selector de disco excluye `zram0`, `loop*`, `ram*`, `fd*` | la RAM comprimida deja de aparecer como destino (borrarla mataría la sesión en marcha) |
| 6 | En `lsblk -r` lo opcional va al final de cada fila | las celdas dejan de desplazarse cuando el sistema no tiene formato |

**Cómo se probó sin arriesgar un disco.** El instalador se extrae tal cual del hook y se ejecuta
contra `lsblk`, `parted`, `mkfs`, `mount`, `rsync`, `grub-install` y `yad` falsos, con
`/proc/meminfo` y `/sys/firmware` fingidos en un espacio de nombres aparte. Siete escenarios
(UEFI con Windows al lado, BIOS con 2 GB, UEFI con 2 GB en NVMe, ISO sin `grub2-common`, BIOS
sin `grub-pc`, cancelación en el aviso de borrado y `cfdisk` manual) suman **57 comprobaciones,
todas en verde**, incluidas «ningún tamaño negativo llega a `parted`», «`zram0` no sale como
destino» y el `fstab` por UUID de los tres esquemas.

**Comprobado dentro de la ISO 2.1 entregada:** `grub-install` y `grub-bios-setup` en
`/usr/sbin`, 304 módulos `i386-pc` y 286 `x86_64-efi`, `grub2-common` y `grub-pc` 2.12-9+deb13u2,
`efibootmgr` 18-2, `os-prober` 1.83, las dos guardas previas del instalador, la exclusión de
`zram0`, dos referencias al GUID EFI y **cero** órdenes `mkpart` con tamaño negativo.

**Puertas nuevas para que esto no vuelva a pasar.** Los guiones de recompilación de la 2.0 y de
la 2.1 ahora comparan la receta viva contra `src/tree-2.0` y `src/tree-2.1` byte a byte y abortan
si difieren (antes una corrección podía quedarse solo en un lado), se niegan a arrancar si hay
otra compilación en marcha, y exigen que el hash de la ISO nueva sea distinto del de la entregada
para no reentregar la misma imagen después de un `lb build` que dijo `already done`. Las ISO
anteriores se renombra a `.bak-día.hora`: ninguna se borra.

### 19:00–20:15 — el ensayo real en VirtualBox tumba las 57 en verde

Con Hyper-V apagado y VirtualBox usando AMD-V directamente, se arrancaron las ISO de verdad y se
llevó el instalador hasta el final en una máquina virtual con disco de 30 GB. Dos defectos que
ninguna de las 57 comprobaciones podía ver:

1. **La 2.1 no instalaba desde ningún medio.** Su instalador comprobaba `/lib/live/mount/medium`
   y live-boot de trixie monta en `/run/live/medium`, así que respondía «Esto solo funciona desde
   el USB…». Portado `willy-medio` a `src/tree-2.1`, añadida la puerta en `recompilar-21.sh` y
   dos escenarios nuevos al ensayo (ruta vieja y estar fuera de una sesión live).
2. **`mkpart` con nombre en tabla msdos**, compartido con la 2.5 y la 2.5.5: el registro de
   `/tmp/willy-instalar.log` decía `parted: invalid token: Willy` / `Error: Expecting a partition
   type.` y el particionado abortaba. En msdos el argumento que sigue a `mkpart` es el **tipo**
   (`primary`), y los nombres solo los admite GPT — por eso la ruta UEFI funcionaba y la BIOS no.
   Corregido en los cinco árboles con el hook idéntico (rama BIOS `mkpart primary ext4 …`, swap
   con `$TIPOSW` asignado en las dos ramas y persistencia del USB elegida por `blkid PTTYPE`).

**Por qué el ensayo de lógica no lo vio:** su `parted` es burlado y se limita a anotar la orden,
así que no valida la sintaxis de `parted`. Desde hoy hay dos piezas más (`src/pruebas/`):
`comprobar-parted-mkpart.sh`, puerta estática sobre el texto del hook que ya va dentro de los
guiones de compilación, y `probar-parted-real.sh`, que ejecuta el `preparar()` extraído del hook
contra un `parted` **real** sobre archivos-image montados en `/dev/loop` — con un escenario que
exige que el comando viejo con nombre siga fallando, para que el ensayo no se quede sin dientes.
Los 57 checks siguen valiendo: el `fstab` por UUID, los tamaños en bytes y la detección por GUID
no los da nadie más. Lo que no dan es la sintaxis de las herramientas que se burlan.

### 20:34–20:58 — la 2.5 publicada instala en UEFI y arranca de su disco

Quedaba por demostrar la otra mitad de lo que se acababa de escribir: que la 2.5 **sí** instala
por UEFI, porque ahí la tabla es GPT y los nombres de partición valen. Ensayo completo en la VM
`willy-inst-efi` (firmware EFI, 4 GB de RAM, Secure Boot apagado, disco `willy-inst-efi.vdi` de
32 GB) con la ISO entregada tal cual, sin recompilar:

| Paso | Hora | Prueba |
|---|---|---|
| Escritorio live pintado | 20:37:30 | 135 s después de encender; la primera vez (20:22) no había aparecido en 215 s |
| `willy-instalar` → disco, `BORRAR`, esquema, dos veces la contraseña | 20:38–20:39 | pantallazos `7-25-efi-03` a `-05c`, con el `/dev/sda 32 GB VBOX HARDDISK` y «Borrar el disco entero y particionar solo» |
| Copia | 20:41–20:48 | el VDI del host pasa de 4 MB a **5.139 MB** y se queda quieto 3 min |
| Arranque del disco instalado | 20:52:36 | `willyroot: clean, 122511/1802240 files, 1363404/7208704 blocks` — el fsck del sistema instalado, antes de que salga el escritorio |
| Verificación dentro del sistema instalado | 20:57:59 | `/dev/sda2 27G 4,7G 21G 19% /`, `/dev/sda1 511M … /boot/efi`, `efivarfs` montado, `ls /home` → `live`, `PRETTY_NAME="Willy Linux 2.5"`, `ID=willylinux` |

O sea: GPT con ESP de 511 MB, root de 27 GB, GRUB EFI instalado y el equipo arrancando del disco
sin el DVD. El defecto de `mkpart` queda entonces **solo** para la ruta BIOS/msdos, que es la que
hay que recompilar.

**Dos trampas del propio arnés**, corregidas en `src/pruebas/probar-instalacion-vbox.ps1` y
contadas en [verificar-la-iso.md](verificar-la-iso.md): esperar un número fijo de segundos al
escritorio (el primer intento envió todas las teclas a una pantalla en negro y siguió adelante) y
declarar «copia terminada» solo porque el VDI dejaba de crecer (lo cumplía también un disco al que
nunca se copió nada). Ahora hay un umbral de píxel real —un PNG de pantalla en negro pesa 3-7 KB
frente a los 150 KB del escritorio pintado— y un suelo de 1 GB antes de dar la copia por buena.


---

## 2026-10-17 — cuarta 2.5 (y 2.5.5 gemela) con los arreglos del particionado

**Árbol:** `src/tree-2.5/` de este repositorio (maestro en el espacio de trabajo, sincronizado
byte a byte con los dos árboles de compilación).

**ISO 2.5:** `willylinux-v2.5-kde-amd64.iso`, 1.849.540.608 B (1763 MB, 21 % del tope),
SHA-256 `1f3e2f6018b2c442ad8d20537468b4acb3525ef19831334bc6a84b3f506cc349` (entregada 12:32).

**ISO 2.5.5:** `willylinux-v2.5.5-kde-amd64.iso`, 1.849.540.608 B,
SHA-256 `43b66af845d6426e2a290633c76c000043956568904a9e90379eaea1d9a8a8c8` (entregada 13:40).
Es **la misma construcción** con otra etiqueta: cambia `PRETTY_NAME` («Willy Linux 2.5.5»),
el volumen ISO (`WILLYLINUX255`) y el título del asistente. Ocupa exactamente los mismos
bytes; el hash distinto lo producen esas cadenas de identidad.

**Qué cambió respecto a la del 14-10:**

| # | Arreglo | Síntoma que quitaba |
|---|---|---|
| 1 | `parted` ya no recibe tamaños negativos (`-2GiB`), se calculan en bytes absolutos con sufijo `B` | la rama automática del instalador abortaba con `opción inválida -- '2'` |
| 2 | El final de la raíz y el inicio del swap ya no coinciden (`FINRAIZ = INISWAP-512` bytes, swap redondeado a GiB) | `Error: You requested a partition from 30,1GB to 32,2GB` y aviso de alineación |
| 3 | Las particiones se detectan por **GUID** (`PARTTYPE`: `c12a7328-…` EFI, `0657fd6d-…` swap) en vez de `PARTFLAGS` | «No hay partición EFI (esp)» aunque `parted print` la mostrara |
| 4 | El selector de raíz filtra `TYPE=part` | ofrecía el disco entero como raíz; elegirlo habría formateado la tabla |
| 5 | El selector de disco pasa las celdas correctas y excluye `zram0` (que `lsblk` reporta como `disk`) | filas descuadradas y un disco fantasma de 1,7 GB como destino |
| 6 | Añadidos los 6 paquetes **VA-API** (`mesa-va-drivers`, `mesa-vdpau-drivers`, `i965-va-driver`, `intel-media-va-driver`, `va-driver-all`, `vainfo`) | todo el vídeo se decodificaba en la CPU |
| 7 | Añadido `desktop-file-utils` | las apps instaladas desde Flathub no refrescaban el menú |
| 8 | Añadido `libcanberra-pulse` | el altavoz del panel se animaba sin emitir sonido |
| 9 | `usermod -c "Willy Linux"` en el hook de Plasma | el lanzador de Plasma decía «Debian Live user» |
| 10 | `net.ipv4.ping_group_range = 0 2147483647` en `90-willylinux.conf` | `ping` sin root: squashfs pierde la capability `cap_net_raw` de `/bin/ping` |
| 11 | Asistente y diálogos en **celdas sueltas** de `yad --list` | filas empaquetadas (`"11|Instalar"`) que `--hide-column=1` ocultaba a medias |
| 12 | Altura de las listas corregida | la última opción quedaba recortada fuera de la pantalla |

**Comprobado en el artefacto** (montando ISO + squashfs, no en el log): `vainfo`,
`update-desktop-database`, `libcanberra-pulse.so`, los `*_drv_video.so` de DRI, `/usr/share/alsa/ucm2`,
`grub-install`, `grub-bios-setup`, `efibootmgr`, módulos `i386-pc` y `x86_64-efi`, el sysctl del
ping, la fila `"1" "Teclado"` y el caso `14) setsid lxterminal -e willy-red`.
**Las dos ISO se montaron y se comprobaron por separado** con el mismo guion de 9 pasos
(herramientas del instalador, paquetes grub, identidad, preflight, textos de modo,
etiqueta de versión, arreglos del round final, paquetes manuales y limpieza): sin `FALLO`
ni `ERROR` en el registro.

**Puertas antes de compilar:** los 5 hooks y **todos** los `*.list.chroot` se comparan byte a
byte entre el maestro y los dos árboles; si uno difiere, el build aborta. Esto existe porque un
paquete añadido solo en el maestro se compilaba en una ISO y no en la otra.

---

## 2026-10-14 — 2.5 y 2.5.5 instalables a disco

**ISOs:** `willylinux-v2.5-kde-amd64.iso` y `willylinux-v2.5.5-kde-amd64.iso`,
1.841.889.280 B las dos. SHA-256 `17d9cb88c7821a54b699971164517fee8a323d42ab21e82291cac100a50ccc7d`
(2.5) y `455a97ea2075e0fe4a7489ebe2690dd62b1801335d0e7074cfec8a16a4532ca9` (2.5.5).

**El defecto que se arregló:** `instalador.list.chroot` solo llevaba `grub-pc-bin`,
`grub-efi-amd64-bin` y `grub-common`, y **ninguno trae `/usr/sbin/grub-install`** — lo trae
`grub2-common`; en BIOS además hace falta `grub-bios-setup`, que viene en `grub-pc`. El
instalador llegaba al paso 8, fallaba en silencio y dejaba un disco copiado **pero no
arrancable**. Afectaba a las 2.0, 2.1, 2.5 y 2.5.5 anteriores.

**Endurecidos del instalador en esa fecha:**

- Preflight: comprueba `[ -x /usr/sbin/grub-install ]` (y `grub-bios-setup` en BIOS) **antes de
  borrar nada**; si falta, cancela sin tocar el disco.
- `willy-medio`: helper único que localiza el USB live. live-boot 1:20250815 montó en
  `/run/live/medium` y los 7 sitios que comprobaban `/lib/live/mount/medium` tomaban un USB por
  disco instalado (el instalador se negaba a empezar y el panel decía «estás en el disco
  instalado»).
- `/etc/hostname` (`willylinux`) y `/etc/hosts` con contenido: estaban en `localhost.localdomain`
  y vacío, y el `sudo` del disco instalado se colgaba resolviendo el nombre. Van en
  `includes.chroot/etc/` porque `chroot_hostname`/`chroot_hosts` los sobrescriben durante la fase
  de instalación.
- `willy-sudo`: la contraseña viaja en el entorno, nunca en un archivo; el instalador borra
  `sudoers.d/willy-live` (el sudo sin clave es solo para la sesión live).
- Contraseña obligatoria aplicada con `chroot chpasswd`; `willy-primera-vez` ya no escribe la
  contraseña `willy` en un disco instalado; quita el autologin de SDDM y renueva `machine-id`.
- `mount -t efivarfs` para que GRUB se registre en el NVRAM; aviso de Secure Boot; aviso si hay
  NTFS/BitLocker.
- Swap si RAM < 8192 MB y disco ≥ 20 GB (los equipos objetivo tienen 6–7 GB).
- `usermod -aG sudo` + `dpkg --configure -a` tras purgar `live-config`/`user-setup` (esos
  paquetes crean al usuario `live` al arrancar, no en el chroot).
- Orden correcto: purgar live-boot/live-config **antes** de `update-initramfs -u -k all`.
- `GRUB_DISABLE_OS_PROBER=false` para que Windows aparezca en el menú.
- `willy-persistencia` avisa con normalidad cuando el sistema ya está instalado (no hay USB que
  guardar) en vez de decir «No localizo el USB».
- `pipewire-audio` añadido a la lista de multimedia: sin él el volumen no subía ni bajaba.
- Filas del `yad --list` del asistente reescritas en celdas sueltas (16 filas, 0 empaquetadas).

**Verificado en el squashfs de las dos ISO:** `grub-install`, `grub-bios-setup`, `efibootmgr`,
módulos `i386-pc`/`x86_64-efi`, `os-prober`, `hostname=willylinux`, `/etc/hosts` con 5 líneas,
preflight del instalador, `pipewire-audio`, cero guardas con la ruta antigua `/lib/live/mount`,
y los 22 scripts de `/usr/local/bin` pasan `sh -n` / `bash -n`.

---

## 2026-10-13 — 2.5 original, reintento y nacimiento de la 2.5.5

| Hora | Hecho | SHA-256 |
|---|---|---|
| 16:52 | **primera 2.5 compilada y entregada** (1.840.087.040 B) | `67f9326160d4b7f93c01fda3b52ff5276a5b9528c27049e85bec10e45f2b2dbd` |
| 18:10 | 2.5 recompilada tras el arreglo del panel y la identidad | `ebb5f62acee14f9ae0bd45626e0a1e4c45c5b2ab571aaebd4ec7b9fcc0a6eecc` |
| 20:16 | **2.5.5 entregada** (rebautizo de la 2.5, sin cambios funcionales) | `cf161eb2fcac317dd2f9eed64d5d9b3274312f0a5dad8a3c9b0cbf1efef8c663` |
| 21:05 | reintento de la 2.5 conservando la anterior | `b75c8187df70993b3c75ee8861da7936fc761ba961cdecf5b8069f9ad388a3e9` |

Contenido de la 2.5 al nacer: KDE Plasma 6, PipeWire, Discover + Flathub (con el remoto
corregido: `Url=` y no `URL=`, que era lo que hacía que Flathub no apareciera en Discover),
sistema bóveda completo, asistente de bienvenida propio con 10 opciones, instalador al disco y
persistencia sobre Plasma. Arranque BIOS (isolinux con `splash.png`, menú en español, timeout 5 s)
y UEFI (GRUB con `live-theme/theme.txt`).

Ese día se confirmó con `flatpak remotes` → `flathub system`, `flatpak search gimp` devolviendo
decenas de aplicaciones, y `wpctl status` con su sink por defecto.

---

## 2026-10-12 — 2.1, 2.0 y 1.1

| Hora | Hecho | Tamaño | SHA-256 |
|---|---|---|---|
| 17:17 | **1.1 entregada** (710 paquetes) | 993.001.472 B | `f01a95f699ee574b64f67468498c8049c40da6260e2a7bddcc7a04cefcc6b0fb` |
| 20:26 | **2.0 entregada** tras corregir el `sed` de colores de GRUB | 1.102.970.880 B | `5ce290b17fc9a01d040a2f4b8ab8d7ccf257c500ad859aaf3f874a23994c0510` |
| ~19:33 | primera 2.1 | 1.134.166.016 B | `3e3c8965…a8c4` (conservada como `.bak-12.21.06`) |
| 21:08 | **2.1 resubida** con iconos verificados, `mimeapps.list`, título BIOS 2.1 y cuatro correcciones del instalador | 1.134.166.016 B | `41cfee2d6ca0ccd0a52db7cba78543598584666b75386efa39990d8fa5f41373` |

También el 12-10: la distro WSL de compilación se movió al disco E: con
`wsl --manage Debian --move`, porque C: se quedaba corto para una edición de 8 GB.

## 2026-10-11 — 1.0

Primera imagen arrancable, 565 paquetes, 703.594.496 B, SHA-256
`446a54c08709d8f23d80f2126cc6acfe716bcf5dc14bf365bbf60c05adf8aa3c`. Copia de seguridad y
`.bak-2026-10-12` verificadas idénticas.

---

## Defectos encontrados «en el artefacto», no en el log

Sirven como lección: en todos los casos el build decía `P: Build completed successfully`.

| Defecto | Cómo se detectó | Familia |
|---|---|---|
| Falta de `pipewire-audio`, `alsa-ucm-conf`, `alsa-topology-conf` | el icono de volumen aparecía pero no subía ni bajaba | `--apt-recommends false` |
| Falta de los 6 paquetes VA-API | `ls .../dri` sin ningún `*_drv_video.so` | `--apt-recommends false` |
| Falta de `grub2-common` / `grub-pc` | `find` dentro del chroot no encontraba `grub-install` | `--apt-recommends false` |
| Falta de `desktop-file-utils`, `libcanberra-pulse` | cruce sistemático `Recommends` ↔ `filesystem.packages` | `--apt-recommends false` |
| Ruta del medio live (`/run/live/medium`) | desmontando el `initrd` de la ISO (3 cpio + gzip) | cambio de nombre entre versiones |
| `ping` sin root | `ls -l /bin/ping` sin setuid ni capability | squashfs pierde xattrs |
| Flathub invisible en Discover | `Url=` frente a `URL=` en el archivo del remoto | clave de fichero |
| Filas empaquetadas en `yad --list` | captura de pantalla del asistente | argumento = una celda |
| Iconos de catálogo inexistentes | `find` dentro del squashfs de `/usr/share/icons` | tema Adwaita symbolic |
| `mkpart` con nombre en tabla msdos (la 2.1 y la 2.5 en BIOS) | ensayo de instalación real en VirtualBox: `parted: invalid token: Willy` en `/tmp/willy-instalar.log` | la burla de `parted` no valida sintaxis |

**Regla que salió de todo esto:** antes de dar una ISO por buena, se monta y se mira dentro.
Ver [verificar-la-iso](verificar-la-iso.md).
