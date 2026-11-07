# Solución de problemas

Síntoma → causa → qué hacer. Todo lo de aquí pasó de verdad en alguno de los equipos o
máquinas virtuales donde se probó Willy Linux.

---

## Arranque

### El equipo no arranca desde el USB

1. Entra al firmware (`F12`, `F8`, `Esc`, `F2` o `Del` al encender) y elige el USB en el menú de
   arranque temporal.
2. **Desactiva Secure Boot** o pon «Other OS». El `BOOTX64.EFI` de la ISO no está firmado por
   Microsoft, así que un firmware con Secure Boot impuesto lo rechaza; abajo está todo.
3. Prueba el otro modo: si grabaste pensando en UEFI, prueba Legacy/CSM, y al revés.
4. Cambia de puerto: algunos portátiles ignoran USB 3.0 en el arranque.
5. Vuelve a grabar en **modo DD** con Rufus, o con `dd`. Copiar la ISO con el explorador no
   deja un disco arrancable.
6. Con el USB ya arrancado, usa el menú **Comprobar la integridad del USB**.

### Secure Boot: qué rechaza de esta ISO y las tres salidas

Secure Boot es una comprobación del firmware UEFI: antes de ejecutar un arrancador mira si lleva
una firma digital (Authenticode) reconocida por las claves de la máquina. Si no la lleva, **no lo
ejecuta** y aparece el menú de la BIOS otra vez o un
`Verification failed: (0x1A) Security Violation`. No es un mensaje de Willy Linux: es el firmware,
antes de que arranque nada.

**Qué hay dentro de la ISO**, comprobado sobre el artefacto con
`src/pruebas/comprobar-seguro-arranque.py` (no sobre el log de la compilación):

```
== paquetes dentro del ISO ==
  shim-signed            -- NO esta
  grub-efi-amd64-bin     esta
  mokutil                -- NO esta

== EFI.IMG: 622592 bytes, FAT12, 512 bytes/sector, 4 sectores/cluster ==
  /EFI/BOOT/BOOTX64.EFI    585728 B  SIN FIRMA  [tabla 0 bytes, RVA 0x0]

  veredicto: con Secure Boot activado este arrancador NO pasa
```

El mismo programa, aplicado a `bootmgfw.efi` y `memtest.efi` de Windows, sí encuentra la tabla de
certificados (52 bytes): la diferencia entre firmado y sin firmar está medida con el mismo código.

| caso | qué ejecuta el firmware | con Secure Boot activado |
|---|---|---|
| USB en UEFI | `/EFI/BOOT/BOOTX64.EFI` de `EFI.IMG` (585.728 B, sin firma) | lo esperado es que no arranque |
| disco instalado en UEFI | `grubx64.efi` que `grub-install` saca de `grub-efi-amd64-bin` (tampoco firmado por Microsoft) | **no arranca**; el instalador avisa antes de empezar |
| cualquier caso en BIOS | `isolinux` y el sector de arranque | da igual: en BIOS no existe Secure Boot |

El caso del USB está **deducido del artefacto, no medido en un equipo real**: en VirtualBox el
firmware EFI de las pruebas venía con Secure Boot apagado. El del disco instalado sí es lo que se ve
en pantalla.

**Saber si lo tienes activado, sin `mokutil`** (la imagen no lo trae, está comprobado arriba), leyendo
la variable EFI igual que hace el instalador:

```sh
for v in /sys/firmware/efi/efivars/SecureBoot-*; do
    printf '%s  ' "$(basename "$v")"
    od -An -tu1 -j4 -N1 "$v" 2>/dev/null
done          # 1 = activado, 0 = apagado
```

Si sale `1` pero la máquina está en *Setup Mode*, la comprobación no se está aplicando; con las
claves instaladas (*User Mode*) sí.

**Las tres salidas.**

1. **Apagarlo o poner «Other OS»** — lo recomendado. En el firmware (`F2`, `Del`, `F10`, `Esc`) suele
   estar en *Boot*, *Security* o *Authentication*; muchos portátiles tienen un conmutador
   «Other OS» / «Installs other operating systems» que hace lo mismo. Es una decisión de una vez.
   **Si el equipo tiene Windows con BitLocker**, cambiar Secure Boot mueve la medida PCR7 y Windows
   puede pedir la *clave de recuperación*: suspende la protección antes de tocar nada o ten la clave
   a mano.
2. **Firmar el arrancador tú mismo** — ruta de laboratorio: clave propia, firmware en *Setup Mode*,
   enrolar el certificado y firmar `BOOTX64.EFI` y `grubx64.efi` con `sbsign`. Vale para un parque
   cerrado de equipos propios; una ISO pública no puede llevar la clave privada dentro.
3. **`shim-signed` en el disco instalado** — lo que hacen las distribuciones firmadas: un segundo
   arrancador pequeño firmado por Microsoft que arranca GRUB y pide enrolar la clave de la
   distribución. Se puede hacer después de instalar, con red:

   ```sh
   sudo apt update
   sudo apt install shim-signed mokutil     # deja la clave en /etc/uefi/certs/*.crt
   sudo grub-install --force-extra-removable
   sudo mokutil --import /etc/uefi/certs/*.crt   # pide una contraseña de una sola vez
   sudo reboot                                     # y sale la pantalla azul de enrolar MOK
   ```

   No se incluye en la imagen a propósito: unos **40 MB más** en cada ISO, un segundo arranque con
   pantalla azul y una clave de terceros metida en la máquina. Los equipos donde se usa esta
   distribución van en BIOS o con Secure Boot apagado.

**El instalador ya avisa**: en UEFI lee la variable y, si está a `1`, saca el aviso antes de borrar
nada («Willy Linux usa su propio cargador sin firmar, así que con Secure Boot puesto no arrancará
desde el disco») y deja cancelar ahí.

### Arranca y queda la pantalla en negro

Aceleración gráfica incompatible. En el menú, pulsa `TAB` (BIOS) o `e` (UEFI) y añade
`nomodeset`, o elige **modo seguro**. Si funciona, el problema es el controlador de la GPU:
arranca con `nomodeset` y busca el controlador propietario correspondiente.

### Tarda mucho en aparecer el escritorio

En equipos con 3–4 GB de RAM y disco mecánico, Plasma tarda. `willy-monitor` muestra qué está
ocupando. Si el equipo tiene 3 GB o menos, usa la edición 2.1, que es IceWM.

---

## Teclado e idioma

### Las teclas `Ñ`, `¿`, `{`, `}`, `|` no salen donde deben

El teclado no está en latinoamericano. Opción **13 · Teclado** del asistente, o
*Teclado* en el panel de ajustes. Para comprobarlo desde el terminal:
`setxkbmap -query`.

> Bajo Wayland, `setxkbmap` avisa `Running setxkbmap against an Xwayland server` y puede
> responder `layout: us` aunque las aplicaciones nativas estén en latam. **No te fíes de esa
> salida**: prueba escribiendo.

### El teclado se comporta raro dentro de VirtualBox

Es el layout de VirtualBox, no el del sistema: Dispositivos → Teclado → Distribución →
*Latin American*. Además, si alguna tecla de `-`, `/` o `=` sale cambiada, se debe a la
conversión de VirtualBox con teclado latam.

---

## Audio

### No se escucha nada

```sh
wpctl status                     # ¿PipeWire vive y ve la tarjeta?
wpctl get-volume @DEFAULT_AUDIO_SINK@
amixer contents | head           # ¿algún control está en [mute]?
```

- Si `wpctl status` no lista ninguna *Sink*: PipeWire no arrancó. `systemctl --user status pipewire`.
- Si hay un *device* pero el volumen está en `0.00` o `[MUTE]`: sube desde
  *Mezclador de volumen* (opción 6) o con `amixer set Master unmute`.
- En muchos portátiles (Realtek con amplificador, Intel SSE/CHT) hace falta un perfil ALSA:
  `alsa-ucm-conf` y `alsa-topology-conf` están incluidos desde la 2.5 del 2026-10-17. Si tu
  tarjeta no tiene perfil `ucm2`, el icono aparece pero la barra no manda nada: usa `amixer` o
  `pavucontrol` y repórtalo.

### El icono del volumen se mueve pero no suena el pitido de confirmación

Faltaba `libcanberra-pulse` (es *Recommends* de `plasma-pa` y la compilación no instala
recomendaciones). Está incluido desde el 2026-10-17.

### El Bluetooth se empareja pero el audio sigue saliendo por el altavoz interno

En *Mezclador de volumen*, pestaña **Salida**, selecciona los auriculares. PipeWire cambia el
dispositivo por defecto, pero si el perfil del auricular está en *off* no aparecerá.

---

## Vídeo, navegador y red

### Los vídeos van a tirones o no arrancan

Ejecuta **`willy-red`** (asistente → opción 16 del panel de ajustes, «Comprobar la red»). Mide
interfaz y puerta, pérdida, retardo y temblor contra la puerta y contra `1.1.1.1`, tiempo de DNS
de tres dominios y **velocidad HTTPS real**, y cierra con un veredicto:

- *red inestable* → el problema es el enlace;
- *enlace justo* → prueba por cable o acerca el router;
- ***la red está bien, la causa está en el navegador o en la página*** → mira lo otro.

En las pruebas de referencia se midió 0 % de pérdida, 59 ms de retardo con 0,24 ms de temblor y
59 MB/s de descarga real: con esos números un vídeo HD (pide ~0,6 MB/s) no puede fallar por red.

### Netflix, Disney+, Prime Video o Max no reproducen

**No tiene arreglo en esta ISO.** El `firefox-esr` de Debian no incluye Widevine (solo
`gmp-clearkey`), y en los repositorios de Debian no existe ese paquete. Solución: instala
**Chromium** desde Discover y usa ese navegador para esos servicios.

### El vídeo se decodifica en el procesador y el portátil se calienta

Comprueba si hay controlador VA-API:

```sh
vainfo --display drm | head
ls /usr/lib/x86_64-linux-gnu/dri | grep drv_video
```

Si aparecen `i965_drv_video.so`, `i915_drv_video.so` o `radeonsi_drv_video.so`, tu GPU está
soportada: activa en `about:config` de Firefox
`media.ffmpeg.vaapi.enabled = true`. **No se fuerza en la imagen** porque en equipos sin GPU
adecuada da pantalla verde. Si `vainfo` no encuentra driver, el vídeo se decodifica por CPU y es
lo que hay.

### `ping` dice `missing cap_net_raw+p capability or setuid?`

Squashfs pierde la capability de `/bin/ping`. En las ISO desde el 2026-10-17 está el sysctl
`net.ipv4.ping_group_range = 0 2147483647` y funciona sin root. En ISO anteriores:
`sudo ping -c 4 1.1.1.1`, o `getent ahostsv4 debian.org` para medir DNS sin root.

### Flathub no aparece en Discover

Causa real, ya corregida: el archivo del remoto ponía `URL=` y Discover espera `Url=`.
Compruébalo por terminal:

```sh
flatpak remotes                 # debe salir: flathub  system
flatpak search gimp
```

Si `flathub` no está: `flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo`.

### Instalo una app de Flathub y no aparece en el menú, o sale sin icono

Faltaba `desktop-file-utils` (sin `update-desktop-database` el menú no se refresca). Incluido
desde el 2026-10-17. En una ISO anterior, sal y vuelve a entrar, o ejecuta
`update-desktop-database ~/.local/share/applications`.

---

## Instalación en el disco

### El instalador dice que no localiza el USB

live-boot 1:20250815 monta el medio en `/run/live/medium`; versiones anteriores usaban
`/lib/live/mount/medium`. En ISO anteriores a 2026-10-14 las comprobaciones estaban escritas con
la ruta vieja y tomaban el USB por disco instalado. Desde entonces hay un helper único,
`willy-medio`, que prueba las cuatro rutas posibles. Compruébalo con:

```sh
willy-medio                     # debe devolver /run/live/medium o /lib/live/mount/medium
```

**Qué ediciones están afectadas todavía.** El helper se aplicó primero a la 2.5 y a la 2.5.5, así
que esas dos instalan. La **2.1 publicada el 2026-10-17 (SHA-256 `10432e43…cbc5c77`) no lo
lleva**: su instalador comprueba la ruta vieja y, arrancando desde el USB o desde el DVD, responde
«Esto solo funciona desde el USB de Willy Linux (sesión live), no desde un sistema ya
instalado» y sale sin tocar el disco. Se detectó el 2026-10-17 en el ensayo real de VirtualBox. La
receta del repositorio ya está corregida; mientras tanto, para instalar una 2.1 hay que compilarla
con `src/tree-2.1` (o usar la 2.5 **en un equipo UEFI**, que es donde sí llega al final: el
2026-10-17 se ensayó completo en una máquina virtual y el disco instalado arrancó con su ESP en
`/boot/efi` — ver el siguiente apartado). La 2.0 no tiene instalador.

### «No se pudo particionar» al elegir el esquema recomendado en un equipo BIOS

En las ISO publicadas hasta el 2026-10-17 el instalador se queda en el paso del esquema, con el aviso
`No se pudo particionar. Mira el registro /tmp/willy-instalar.log`. Dentro del registro está el
motivo real:

```
parted: invalid token: Willy
Error: Expecting a partition type.
```

Es un error de sintaxis de `parted`, no del disco: en una tabla **msdos** (arranque BIOS/legacy) lo
que va después de `mkpart` es el **tipo** de partición (`primary`/`extended`/`logical`), y los nombres
de partición solo los admite **GPT**. El instalador pedía `mkpart Willy ext4 …` en las dos ramas, así
que la ruta UEFI funcionaba y la de BIOS abortaba antes de formatear nada. El disco no se toca: si
falla el particionado, el instalador sale sin copiar.

**Qué ediciones están afectadas.** La 2.1 y la 2.5/2.5.5 publicadas antes de esta corrección. En un
equipo **UEFI** la 2.5 instala normal (usa GPT, donde los nombres sí valen). En un equipo **BIOS** no:
hay que compilar con la receta corregida (`src/tree-2.5` o `src/tree-2.1`), que ya particiona con
`mkpart primary ext4 …` y deja el nombre solo para la rama GPT. La 2.0 no tiene instalador.

**Comprobación mientras tanto** (sin reinstalar): arranca el USB en modo UEFI y usa el esquema
recomendado; o particiona a mano con *Particiono antes con cfdisk*, que es la otra rama del instalador
y no depende de `parted mkpart`.

### El instalador aborta sin tocar el disco

Es el *preflight* funcionando: faltan `grub-install` o `grub-bios-setup` y copiar el sistema no
lo dejaría arrancable. **Cualquier ISO anterior al 2026-10-14 tiene ese defecto** y no sirve para
instalar. Usa una ISO de esa fecha o posterior.

### Instalé bien pero el disco no arranca

Casi siempre es **Secure Boot**: el GRUB de la ISO no está firmado y la imagen no incluye
`shim-signed`. El instalador avisa antes de empezar. Soluciones:

1. Desactiva Secure Boot o pon «Other OS» en el firmware, o
2. Instala de nuevo con Secure Boot apagado y, si lo necesitas firmado, enrola el clave MOK tú
   mismo (no está soportado por defecto en esta imagen).

También puede ser que el firmware siga apuntando a la otra entrada: revisa con
`efibootmgr -v` y sube `ubuntu`/`Willy Linux` en el orden de arranque.

### Windows no aparece en el menú GRUB

El instalador escribe `GRUB_DISABLE_OS_PROBER=false` en `/etc/default/grub`, así que debería
estar. Si falta: `sudo update-grub` y revisa que la partición de Windows no esté en BitLocker
suspendido.

### El `sudo` del sistema instalado se queda colgado

`/etc/hostname` decía `localhost.localdomain` y `/etc/hosts` estaba vacío (0 bytes) en ISO
anteriores: `sudo` intentaba resolver el nombre del equipo y esperaba. Está corregido; si te
pasa en una instalación vieja:

```sh
echo willylinux > /etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\twillylinux\n' > /etc/hosts
```

### Instalé desde un USB con cambios guardados y el equipo sigue arrancando el USB

Quita el USB antes de encender, o baja el USB en el orden de arranque del firmware.

### «No localizo el USB» al pulsar *Guardar en el USB* estando ya instalado

Es correcto: en un disco instalado no hay USB que guardar, y el aviso lo dice en vez de fallar.
Los cambios ya se guardan solos.

---

## Persistencia

### Guardé los cambios y al reiniciar desaparecieron

1. ¿Ejecutaste *Guardar mis cambios* y elegiste un modo (`/home` o `/`)? Sin eso la sesión es
   volátil por diseño.
2. ¿El arranque lleva `persistence` en la línea de comandos? Todas las ISO lo llevan; si lo
   editaste a mano, compruébalo.
3. `willy-guardado` te dice en qué modo estás. Si dice `volatil`, la partición `persistence` no
   se montó.
4. Algunos firmware necesitan que el USB se vuelva a conectar tras crear la partición.

### El USB se quedó sin espacio

El modo «todo» (`/`) guarda también las actualizaciones del sistema. Cambia a «solo `/home`» o
limpia la partición desde *Guardar mis cambios*.

---

## Rendimiento

### Va lento

- `willy-monitor` y `willy-info` dicen RAM, CPU y disco.
- Con 6 GB de RAM o menos, `zram-tools` comprime memoria en vez de usar disco y `earlyoom` evita
  el cuelgue total.
- Si el equipo tiene 3–4 GB, usa la 2.1 (IceWM) en lugar de la 2.5 (Plasma).
- En máquina virtual con 2 CPU y sin GPU, el escritorio se decodifica por software (`llvmpipe`):
  es lento y **es esperado**.

### VLC se ve gris, sin el tema del sistema

Cierto y aceptado: en la imagen solo hay estilos de Qt6 (`breeze6.so`), y VLC es Qt5. Añadir
`kde-style-breeze-qt5` son 629 KB más librerías KF5; se descartó por ser solo estético.

---

## Sesión y contraseñas

### La pantalla de bloqueo pide una contraseña que no me sé

En un disco instalado, es la que escribiste durante la instalación: la contraseña `willy` **no**
se copia al disco.

**En el USB live hay que distinguir qué ISO tienes.** Desde la receta corregida el 2026-11-07, la
contraseña `willy` se escribe **en la propia imagen** (hook `0050-willylinux.hook.chroot`), así que
el desbloqueo funciona sin haber hecho nada. En las ISO quemadas antes de esa corrección — entre
ellas **la 2.8 del 2026-10-20** — la cuenta live se creaba sin hash en `/etc/shadow`: el
desbloqueo de Plasma **no admite una cuenta sin contraseña**, y ni `willy` ni `live` abrían la
sesión («El desbloqueo ha fallado»). Se comprobó el 2026-11-07 en VirtualBox, con la pantalla
bloquesola por inactividad.

Arreglo a mano en una ISO anterior a la corrección, desde una terminal que todavía esté abierta:

```sh
echo willy:willy | sudo chpasswd     # la cuenta live se llama live
```

**Hazlo nada más arrancar el USB**, antes de que la pantalla se bloquee sola. Si ya estás fuera
de la sesión y no hay ninguna terminal abierta, no hay atajo dentro de la propia live: la pantalla
de bloqueo es justamente lo que no deja entrar. Reinicia el USB, abre un terminal en cuanto aparezca
el escritorio y ejecuta ese comando; o, si necesitas la imagen para algo serio, vuelve a grabarla
con la receta actual, que ya trae la contraseña escrita en la imagen.

### El disco instalado arranca y entra al escritorio sin pedir contraseña

No es que la instalación no haya guardado la clave: la guarda. Es **SDDM**, que lee
`/etc/sddm.conf` **y además** `/etc/sddm.conf.d/*.conf`, y el instalador dejaba `Autologin` en uno
de los dos. Comprobarlo:

```sh
grep -rn -A2 '\[Autologin\]' /etc/sddm.conf /etc/sddm.conf.d/ 2>/dev/null
```

Si sale `User=live` o `Session=`, el equipo entra solo. Tapete a mano:

```sh
sudo sed -i 's|^User=.*|User=|' /etc/sddm.conf /etc/sddm.conf.d/willy.conf
```

> **El detalle que hace que esto sea fácil de pasar por alto:** dejar comentada la línea `User=`
> en el archivo que va después **no anula** la del archivo anterior. SDDM mezcla los dos y la
> opción sigue activa. Solo un `User=` vacío la desactiva. Por eso el instalador falló aunque el
> cambio parecía correcto.

### El panel sale pegado a la izquierda en vez de centrado

Sigue pasando en la ISO quemada en GitHub Actions el 2026-11-07, probado en VirtualBox. Lo que
devuelve el guion:

```
$ willy-panel centrar
willy-panel: Plasma no respondio por la API de scripts, pruebo con el fichero.
willy-panel: no encontre ni la API ni /home/live/.config/plasmashellrc; no he tocado nada.
```

Las dos rutas que tiene el arreglo fallan a la vez en la live: `plasmashell` no contesta por la API
de scripts (el árbol de widgets todavía se está montando cuando `willy-primera-vez` pregunta, y los
cinco reintentos no lo alcanzan) y el respaldo por fichero no encuentra
`~/.config/plasmashellrc`, que en una sesión live recién creada **todavía no existe**.

**Lo que sí funciona es el propio Plasma**, sin guiones:

1. Clic derecho en la barra → *Configurar la barra de tareas* (en algunos idiomas,
   *Configurar el gestor de tareas de solo iconos*).
2. **Alineación → Centrado**. Aceptar.

Eso escribe la clave donde Plasma la lee y se mantiene al reiniciar. `willy-panel` sigue sirviendo
para lo contrario (devolver la barra a la izquierda) cuando el fichero de configuración ya existe,
que es el caso normal en un disco instalado después de la primera sesión.

> Defecto abierto de la 2.8: el arreglo automático hay que buscarlo por otra vía (crear el
> `plasmashellrc` desde el esqueleto, o esperar a que el árbol esté listo con una comprobación
> distinta a la de `barras=`). Hasta entonces, dos clics.

### Quiero que el equipo no pida contraseña al arrancar

No se ofrece como opción: el instalador quita el autologin de SDDM a propósito. Si es un equipo
tuyo sin datos, puedes reactivarlo, pero pierdes el bloqueo de pantalla y la bóveda deja de tener
sentido.

### Olvidé la contraseña de una bóveda

No hay recuperación posible: cryfs no guarda copia de la clave. Mantén una copia de seguridad
fuera de la bóveda.

---

## Compilar y probar

### VirtualBox se cierra con `gurumeditation` al arrancar la VM

Hyper-V/WSL2 tiene reservado AMD-V. Apaga la plataforma de hipervisor y reinicia para usar
VirtualBox; vuelve a encenderla para compilar en WSL2. No pueden coexistir.

### `wsl.exe` responde `WSAETIMEDOUT` o un comando sale con exit 127 sin explicación

Con un build pesado en marcha, el puente a WSL da timeouts transitorios. Reintenta. Y **nunca**
pases comandos con `$` o comillas anidadas por `wsl.exe -- bash -c '...'`: el escapado de MSYS los
corrompe, el comando devuelve 0 y parece que funcionó. Escribe un `.sh` y ejecútalo por ruta.

### La copia de la ISO a otro disco falla a mitad (`Cannot allocate memory`)

Es el canal 9p de WSL. Reanuda con `rsync --append --partial` en vez de volver a empezar; el
script de entrega hace exactamente eso, con reintentos, y genera el `.sha256` al terminar.

---

## Cómo reportar un problema

Adjunta la salida de:

```sh
willy-info                 # edición, versión, hardware, modo live o instalado
willy-guardado             # volatil / persistente / instalado
wpctl status               # si es audio
vainfo --display drm       # si es vídeo
cat /tmp/willy-instalar.log   # si es instalación
```

Indica siempre el **SHA-256 de la ISO** que usas: con las recompilaciones del mismo día, es la
única forma de saber qué imagen probaste.
