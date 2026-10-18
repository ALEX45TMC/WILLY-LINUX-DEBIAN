# Solución de problemas

Síntoma → causa → qué hacer. Todo lo de aquí pasó de verdad en alguno de los equipos o
máquinas virtuales donde se probó Willy Linux.

---

## Arranque

### El equipo no arranca desde el USB

1. Entra al firmware (`F12`, `F8`, `Esc`, `F2` o `Del` al encender) y elige el USB en el menú de
   arranque temporal.
2. **Desactiva Secure Boot** o pon «Other OS». La ISO arranca sin firma en la mayoría de
   firmware, pero algunos lo bloquean.
3. Prueba el otro modo: si grabaste pensando en UEFI, prueba Legacy/CSM, y al revés.
4. Cambia de puerto: algunos portátiles ignoran USB 3.0 en el arranque.
5. Vuelve a grabar en **modo DD** con Rufus, o con `dd`. Copiar la ISO con el explorador no
   deja un disco arrancable.
6. Con el USB ya arrancado, usa el menú **Comprobar la integridad del USB**.

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
con `src/tree-2.1` (o usar la 2.5 **en un equipo UEFI**, que es donde sí llega al final — ver el
siguiente apartado). La 2.0 no tiene instalador.

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

En el USB live es `willy` (el asistente lo recuerda en su cabecera). En un disco instalado, es la
que escribiste durante la instalación: la contraseña `willy` **no** se copia al disco.

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
