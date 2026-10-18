#!/bin/bash
# Ensayo del instalador willy-instalar SIN tocar ningun disco real.
# Se saca el script tal cual lo genera el hook y se le pone delante un mundo
# simulado: lsblk/parted/mkfs/mount/rsync/grub-install falsos que solo apuntan lo
# que se les manda, yad que contesta desde una cola, y /proc/meminfo y
# /sys/firmware fingidos con montajes dentro de un espacio de nombres aparte.
set -u
TREE="/mnt/c/Users/DORA/Documents/Qoder/2026-10-12/8792315c/tree-2.5/config/hooks/live/0400-instalador.hook.chroot"
T=/root/willy-inst-test
export T JLOG="$T/log" D="$T/d" Q="$T/q" FORMATEADOS="$T/formateados"
export PATH="$T/bin:$PATH"
fallos=0

rm -rf "$T"; mkdir -p "$T/bin" "$T/q" "$T/d"
: > "$JLOG"; : > "$FORMATEADOS"
awk '/^cat > "\$BIN\/willy-instalar" <<'"'"'WLYINSTALL'"'"'$/{d=1;next} d&&/^WLYINSTALL$/{exit} d{print}' \
	"$TREE" > "$T/willy-instalar"
[ "$(wc -l < "$T/willy-instalar")" -gt 100 ] || { echo "FALLO: no se extrajo el instalador"; exit 1; }
echo "instalador extraido del hook: $(wc -l < "$T/willy-instalar") lineas"

# ============================ burlas =========================================
cat > "$T/bin/yad" <<'FAKE'
#!/bin/bash
printf 'YAD: %s\n' "$*" >> "$Q/dialogos"
for a in "$@"; do case "$a" in --text=*) printf 'TEXTO: %s\n' "${a#--text=}" >> "$Q/dialogos" ;; esac; done
cola() {
	local f=$1 linea
	linea=$(head -1 "$f" 2>/dev/null)
	tail -n +2 "$f" > "$f.x" 2>/dev/null && mv "$f.x" "$f"
	printf '%s\n' "$linea"
}
case "$*" in
	*--question*) exit 1 ;;
	*--error*)  printf 'DIALOGO-DE-ERROR: %s\n' "$*" >> "$Q/dialogos" ;;
	*--info*)   : ;;
	*--list*)   cola "$Q/lista" ;;
	*--entry*)  cola "$Q/entrada" ;;
esac
exit 0
FAKE

cat > "$T/bin/lsblk" <<'FAKE'
#!/bin/bash
dev=""; for a in "$@"; do case "$a" in -*) ;; *) dev="$a" ;; esac; done
base=${dev##*/}
dato() { grep -m1 "^$1 $2 " "$D/tabla" 2>/dev/null | cut -d' ' -f3-; }
# Cada fila de "$D/parts" son 4 columnas: nombre, tamano, fstype y GUID de tipo.
# Un "-" en la columna del fstype significa "sin formato": el fake lo suelta vacio, que
# es justo lo que hace lsblk -r y lo que desplaza las columnas si van en mal orden.
# El GUID hace de PARTFLAGS: el lsblk real de trixie lo deja vacio en GPT.
case "$*" in
	*"-dno NAME,TYPE"*)                cat "$D/disks" ;;
	*"-dno PKNAME"*)                   cat "$D/padre" ;;
	*"-dno RM"*)                       dato RM "$base" ;;
	*"-bdno SIZE"*)                    dato SIZE "$base" ;;
	*"-dno MODEL"*)                    dato MODEL "$base" ;;
	*"-dno NAME"*)                     printf '%s\n' "$base" ;;
	*"-rnpo NAME,TYPE,SIZE,FSTYPE"*)   awk '{fs=$3; if(fs=="-") fs=""; print $1" part "$2" "fs}' "$D/parts" ;;
	*"-rnpo NAME,TYPE,PARTTYPE"*)      awk '{print $1" part "$4}' "$D/parts" ;;
	*"-rnpo NAME,TYPE,FSTYPE"*)        awk '{fs=$3; if(fs=="-") fs=""; print $1" part "fs}' "$D/parts" ;;
	*"-rnpo NAME,SIZE,FSTYPE"*)        awk '{fs=$3; if(fs=="-") fs=""; print $1" "$2" "fs}' "$D/parts" ;;
	*"-rnpo NAME,FSTYPE"*)             awk '{fs=$3; if(fs=="-") fs=""; print $1" "fs}' "$D/parts" ;;
	*"-rnpo NAME,PARTFLAGS"*)          cat "$D/flags" ;;
	*"-rnpo NAME"*)                    awk '{print $1}' "$D/parts" ;;
esac
exit 0
FAKE

printf '#!/bin/bash\ncat "$D/medium"\n' > "$T/bin/findmnt"

cat > "$T/bin/sudo" <<'FAKE'
#!/bin/bash
# Anota la orden privilegiada. Las que devuelven datos (blkid/df/du/test) responden
# desde los archivos del escenario; el resto se da por hecha.
printf 'SUDO: %s\n' "$*" >> "$JLOG"
while [ $# -gt 0 ]; do
	case "$1" in
	-n|-S|-k) shift ;;
	-p) shift 2 ;;
	-*) shift ;;
	*) break ;;
	esac
done
orden="$*"
sacar() { printf '%s' "$orden" | awk '{print $NF}'; }
case "$orden" in
	"blkid "*"-s PTTYPE "*)
		grep -m1 "^$(sacar) " "$D/pttypes" 2>/dev/null | cut -d' ' -f2
		exit 0 ;;
	# parted de verdad no admite nombre de particion en una tabla msdos: ahi lo que va
	# despues de mkpart es el tipo. La burla repite esa regla para que un "mkpart Willy"
	# en BIOS vuelva a suspender el ensayo, en vez de pasar como paso en octubre.
	parted\ *mkpart\ *)
		dev=$(printf '%s' "$orden" | awk '$2 ~ /^-/ {print $3; exit}')
		nom=$(printf '%s' "$orden" | awk '{for(i=1;i<=NF;i++) if($i=="mkpart"){print $(i+1); exit}}')
		tbl=$(grep -o "parted -s $dev mklabel [a-z]*" "$JLOG" | tail -1 | awk '{print $NF}')
		if [ "$tbl" = msdos ] || [ "$tbl" = dos ]; then
			case "$nom" in primary|extended|logical) exit 0 ;; esac
			printf 'parted: invalid token: %s\nError: Expecting a partition type.\n' "$nom" >&2
			printf 'PARTE-RECHAZADA: %s\n' "$orden" >> "$JLOG"
			exit 1
		fi
		exit 0 ;;
	"blkid "*"-s UUID "*)
		dev=$(sacar)
		if grep -qxF -- "$dev" "$FORMATEADOS" 2>/dev/null; then
			grep -m1 "^$dev " "$D/uuids" 2>/dev/null | cut -d' ' -f2
			exit 0
		fi
		exit 1 ;;
	"blkid "*"-s TYPE "*)
		grep -m1 "^$(sacar) " "$D/tipos" 2>/dev/null | cut -d' ' -f2
		exit 0 ;;
	"df -BM --output=avail "*) printf 'Avail\n%s\n' "$(cat "$D/dfavail")"; exit 0 ;;
	"du -sxm "*)               printf '%s\t/\n' "$(cat "$D/du")"; exit 0 ;;
	"test -s "*)               exit 0 ;;
	od\ *|cat\ *)             sh -c "$orden"; exit $? ;;
esac
case "$orden" in
	*chpasswd) cat > "$T/chpasswd_in" ;;
	tee\ *) cat >> "$T/tee_in" ;;
	"tee "*|tee) cat >> "$T/tee_in" ;;
esac
case "$orden" in
	mkfs.*\ *|mkswap\ *) printf '%s\n' "$(sacar)" >> "$FORMATEADOS" ;;
esac
exit 0
FAKE

printf '#!/bin/bash\nprintf "BIN: %%s %%s\\n" "%s" "$*" >> "$JLOG"\nexit 0\n' partprobe > "$T/bin/partprobe"
for n in konsole cfdisk; do printf '#!/bin/bash\nprintf "BIN: %%s %%s\\n" "%s" "$*" >> "$JLOG"\nexit 0\n' "$n" > "$T/bin/$n"; done
printf '#!/bin/sh\necho '"'"'SUDO="sudo -n"'"'"'\n' > "$T/bin/willy-sudo"
# willy-medio NO es una burla: se saca tal cual del hook 0700, que es quien lo
# instala en la imagen. Sin el, el instalador cree que no esta en un USB live y
# aborta antes de tocar nada (paso de la comprobacion del medio, linea 21).
H0700="$(dirname "$TREE")/0700-identidad.hook.chroot"
awk '/^cat > "\$BIN\/willy-medio" <<'"'"'EOF'"'"'$/{d=1;next} d&&/^EOF$/{exit} d{print}' \
	"$H0700" > "$T/bin/willy-medio"
[ "$(wc -l < "$T/bin/willy-medio")" -gt 5 ] || { echo "FALLO: no se extrajo willy-medio de $H0700"; exit 1; }
chmod 755 "$T"/bin/*

espera()     { if grep -qF -- "$1" "$JLOG" "$Q/dialogos" 2>/dev/null; then echo "OK    $2"; else echo "FALLO $2"; printf '        buscado: %s\n' "$1"; fallos=$(( fallos + 1 )); fi; }
no_espera()  { if grep -qF -- "$1" "$JLOG" "$Q/dialogos" 2>/dev/null; then echo "FALLO $2"; printf '        no deberia estar: %s\n' "$1"; fallos=$(( fallos + 1 )); else echo "OK    $2"; fi; }
espera_en()  { if grep -qF -- "$2" "$1" 2>/dev/null; then echo "OK    $3"; else echo "FALLO $3"; printf '        buscado %s en %s\n' "$2" "$1"; fallos=$(( fallos + 1 )); fi; }

mkdir -p /willy-target/etc/sddm.conf.d /willy-target/etc/default
printf '[Autologin]
User=live
' > /willy-target/etc/sddm.conf.d/willy.conf
echo "" > /willy-target/etc/default/grub

NODOS=""
prepara_nodos() {
	for n in "$@"; do
		[ -b "/dev/$n" ] || mknod "/dev/$n" b 250 $(( 100 + RANDOM % 4000 )) 2>/dev/null
		mkdir -p /willy-target/etc/sddm.conf.d /willy-target/etc/default
printf '[Autologin]
User=live
' > /willy-target/etc/sddm.conf.d/willy.conf
echo "" > /willy-target/etc/default/grub

NODOS="$NODOS $n"
	done
}

ejecutar() { # $1=efi|efi-sb|bios  $2=RAM en MB  $3=sin-grub|sin-bios para fingir la ISO sin grub2-common o sin grub-pc
	local modo=$1 ram=$2 rc fw=/tmp/fakefw-$1-${3:-}
	local uefi=0 sb=0 sin="" bios=""
	case "$1" in efi) uefi=1 ;; efi-sb) uefi=1; sb=1 ;; esac
	case "${3:-}" in sin-grub) sin=1 ;; sin-bios) bios=1 ;; esac
	rm -rf "$fw"; mkdir -p "$fw/efi"
	[ "$uefi" = 1 ] || rm -rf "$fw/efi"
	if [ "$sb" = 1 ]; then
		# La firmware expone efivars DENTRO de efi, no al lado.
		mkdir -p "$fw/efi/efivars"
		printf '\007\000\000\000\001' > "$fw/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
	fi
	rm -f "$T/chpasswd_in" "$T/tee_in"; : > "$T/tee_in"
	: > "$JLOG"; : > "$Q/dialogos"; : > "$FORMATEADOS"
	unshare -m bash -c "
		mkdir -p /lib/live/mount/medium
		mount --bind $fw /sys/firmware
		# El comprobacion previo de grub mira /usr/sbin: se monta un tmpfs vacio y se
		# dejan ahi los dos ejecutables, salvo cuando se quiere fingir que faltan.
		mount -t tmpfs willy-sbin /usr/sbin
		[ -n '$sin' ] || { touch /usr/sbin/grub-install /usr/sbin/grub-bios-setup; chmod 755 /usr/sbin/grub-install /usr/sbin/grub-bios-setup; }
		[ -z '$bios' ] || rm -f /usr/sbin/grub-bios-setup
		awk -v r=$ram '/MemTotal/{print \"MemTotal:       \" r \"000 kB\"; next} {print}' /proc/meminfo > /tmp/mi-$1${3:-}
		mount --bind /tmp/mi-$1${3:-} /proc/meminfo
		exec dash -x '$T/willy-instalar' 2> '$T/stderr'
	"
	rc=$?
	echo "     (salio $rc; $(wc -l < "$JLOG") ordenes privilegiadas)"
	if [ -n "${DEPURAR:-}" ]; then
		echo "     ---- traza ----"; tail -25 "$T/stderr" | sed 's/^/     /'
		echo "     ---- dialogos ----"; cut -c1-100 "$Q/dialogos" | head -8 | sed 's/^/     /'
		echo "     ---- PATH dentro: $(unshare -m sh -c 'echo $PATH' ) ----"
	fi
	return $rc
}

echo
echo "=== A: UEFI, disco NVMe con Windows, 8 GB de RAM ==="
printf 'sdb disk\nnvme0n1 disk\nloop0 loop\n' > "$T/d/disks"
echo sdb > "$T/d/padre"
echo /dev/sdb2 > "$T/d/medium"
cat > "$T/d/tabla" <<'EOF'
RM sdb 1
SIZE sdb 32000000000
MODEL sdb USB
RM nvme0n1 0
SIZE nvme0n1 250000000000
MODEL nvme0n1 SSD
EOF
printf '/dev/nvme0n1p1 512M vfat c12a7328-f81f-11d2-ba4b-00a0c93ec93b\n/dev/nvme0n1p2 200G ntfs 0fc63daf-8483-4772-8e79-3d69d8477de4\n' > "$T/d/parts"
printf '/dev/nvme0n1p1 esp\n' > "$T/d/flags"
printf '/dev/nvme0n1p2 ntfs\n' > "$T/d/tipos"
printf '/dev/nvme0n1p1 efi\n/dev/nvme0n1p2 raiz\n' > "$T/d/uuids"
printf '  99999M\n6000\n' > "$T/d/capacity"; cp /dev/null "$T/d/dfavail"
echo "  99999M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/nvme0n1|250 GB|SSD|/dev/nvme0n1\nBorrar el disco entero|auto\n' > "$T/q/lista"
printf 'BORRAR\nClave123\nClave123\n' > "$T/q/entrada"
prepara_nodos nvme0n1 nvme0n1p1 nvme0n1p2 nvme0n1p3
ejecutar efi 16384
espera 'mklabel gpt'                          'crea tabla GPT en UEFI'
espera 'mkpart WillyEFI fat32 1MiB 513MiB'     'particion EFI de 512 MB'
espera 'set 1 esp on'                          'marca la particion como esp'
espera 'mkpart Willy ext4 513MiB 100%'         'la raiz ocupa todo lo demas'
no_espera 'WillySwap'                          'sin swap porque hay 16 GB de RAM'
espera 'mkfs.ext4 -q -F -L willyroot /dev/nvme0n1p2' 'formatea la raiz (nvme lleva sufijo p2)'
espera 'mkfs.vfat -F32 -n WILLYEFI /dev/nvme0n1p1'   'formatea la EFI'
espera_en "$T/tee_in" 'UUID=raiz / ext4'        'fstab con la raiz por UUID'
espera_en "$T/tee_in" 'UUID=efi /boot/efi vfat' 'fstab con la EFI por UUID'
espera 'chroot /willy-target chpasswd'          'pone la contrasena en el disco'
espera 's|^User=.*|;User=| /willy-target/etc/sddm.conf.d/willy.conf' 'quita el acceso directo de SDDM'
espera 'truncate -s 0 /willy-target/etc/machine-id' 'renueva la identidad de systemd'
espera 'rm -f /willy-target/etc/sudoers.d/willy-live' 'quita el sudo sin clave del disco'
espera 'grub-install --target=x86_64-efi --efi-directory=/boot/efi' 'GRUB UEFI registrandose en el NVRAM'
no_espera 'grub-install --target=i386-pc'       'no instala GRUB de BIOS en un equipo UEFI'
espera 'particiones de Windows'                 'avisa de que se borra Windows'
no_espera 'Secure Boot activado'               'no molesta con Secure Boot si la firmware no lo tiene'
no_espera 'parted -s /dev/sdb'                  'no particiona el USB de donde se arranca'
no_espera 'sdb'                                 'el USB no sale en la lista de destinos'
no_espera 'loop0'                               'los loop no salen en la lista'
espera_en "$T/chpasswd_in" 'Clave123'          'la contrasena elegida llega a chpasswd por tuberia'

echo
echo "=== B: BIOS, disco SATA con 2 GB de RAM (crea swap) ==="
printf 'sda disk\nsdb disk\n' > "$T/d/disks"
cat > "$T/d/tabla" <<'EOF'
RM sdb 1
SIZE sdb 32000000000
MODEL sdb USB
RM sda 0
SIZE sda 500000000000
MODEL sda HDD
EOF
printf '/dev/sda1 465G ext4 0fc63daf-8483-4772-8e79-3d69d8477de4\n' > "$T/d/parts"
: > "$T/d/flags"; : > "$T/d/tipos"
printf '/dev/sda1 raiz\n/dev/sda2 swap\n' > "$T/d/uuids"
echo "  440000M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/sda|500 GB|HDD|/dev/sda\nBorrar el disco entero|auto\n' > "$T/q/lista"
printf 'BORRAR\notraClave9\notraClave9\n' > "$T/q/entrada"
prepara_nodos sda sda1 sda2
ejecutar bios 2048
espera 'mklabel msdos'                          'crea tabla msdos en BIOS'
espera 'mkpart primary ext4 1MiB 497142464000B'  'deja 2 GB al final para la swap (parted no traga -2GiB)'
espera 'set 1 boot on'                          'marca la particion de arranque'
espera 'mkpart primary linux-swap 497142464512B 100%' 'crea la swap un sector tras el final de la raiz'
no_espera 'PARTE-RECHAZADA'                     'parted acepta todas las ordenes de la rama BIOS'
espera 'mkswap -L willyswap /dev/sda2'          'formatea la swap (sata no lleva sufijo p)'
espera 'mkfs.ext4 -q -F -L willyroot /dev/sda1' 'formatea la raiz sda1'
espera_en "$T/tee_in" 'UUID=swap none swap'     'fstab con la swap'
no_espera '/boot/efi vfat'                       'sin linea EFI en el fstab de BIOS'
espera 'grub-install --target=i386-pc --boot-directory=/boot /dev/sda' 'GRUB al MBR en BIOS'
no_espera 'x86_64-efi'                           'no intenta GRUB de UEFI'
no_espera 'particiones de Windows'               'no avisa de Windows si no hay ntfs'
espera_en "$T/chpasswd_in" 'otraClave9'         'la contrasena elegida llega a chpasswd por tuberia'

echo
echo "=== D: portatil UEFI de 6 GB con Secure Boot activado ==="
# Se rehace el mundo del escenario A (mismo disco NVMe) porque B dej6 el mundo SATA.
printf 'nvme0n1 disk\nsdb disk\n' > "$T/d/disks"
echo sdb > "$T/d/padre"
echo /dev/sdb2 > "$T/d/medium"
cat > "$T/d/tabla" <<'EOF'
RM sdb 1
SIZE sdb 32000000000
MODEL sdb USB
RM nvme0n1 0
SIZE nvme0n1 250000000000
MODEL nvme0n1 SSD
EOF
printf '/dev/nvme0n1p1 512M vfat c12a7328-f81f-11d2-ba4b-00a0c93ec93b\n' > "$T/d/parts"
printf '/dev/nvme0n1p1 esp\n' > "$T/d/flags"
: > "$T/d/tipos"
printf '/dev/nvme0n1p1 efi\n/dev/nvme0n1p2 raiz\n/dev/nvme0n1p3 swap\n' > "$T/d/uuids"
echo "  99999M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/nvme0n1|250 GB|SSD|/dev/nvme0n1\nBorrar el disco entero|auto\n' > "$T/q/lista"
printf 'BORRAR\nClave123\nClave123\n' > "$T/q/entrada"
prepara_nodos nvme0n1 nvme0n1p1 nvme0n1p2 nvme0n1p3
ejecutar efi-sb 6144
espera 'Secure Boot activado'                   'avisa de que habra que desactivar Secure Boot'
espera 'mkpart WillySwap linux-swap 246960619520B 100%' 'con 6 GB de RAM si crea la swap'
espera 'mkswap -L willyswap /dev/nvme0n1p3'     'formatea la swap del nvme (lleva sufijo p3)'
espera_en "$T/tee_in" 'UUID=swap none swap'     'fstab con la swap de 6 GB'
espera 'mount -t efivarfs efivarfs /willy-target/sys/firmware/efi/efivars' 'monta efivars para el NVRAM'
espera 'usermod -aG sudo'                       'asegura el grupo sudo en el disco'
espera 'dpkg --configure -a'                    'repara paquetes a medio configurar'
no_espera 'x86_64-efi --efi-directory=/boot/efi --removable' 'no cae en la ruta alternativa si el NVRAM responde'

echo
echo "=== E: ISO vieja sin grub2-common ni grub-pc (debe cancelar antes de tocar nada) ==="
ejecutar efi 16384 sin-grub
espera 'le falta <b>grub-install</b>'           'avisa de que falta grub-install'
no_espera 'mklabel'                             'no toca la tabla de particiones'
no_espera 'mkfs'                                'no formatea'
no_espera 'rsync'                               'no copia el sistema'
no_espera 'chpasswd'                            'no mete contrasenas'

echo
echo "=== F: equipo BIOS sin grub-bios-setup (mismo fallo, otra causa) ==="
ejecutar bios 16384 sin-bios
espera 'le falta <b>grub-bios-setup</b>'        'avisa de que falta grub-bios-setup'
no_espera 'mklabel'                             'no toca la tabla de particiones'
no_espera 'rsync'                               'no copia el sistema'

echo
echo "=== C: se cancela en el aviso de borrado ==="
printf '/dev/sda|500 GB|HDD|/dev/sda\n' > "$T/q/lista"
printf 'NOBORRO\n' > "$T/q/entrada"
ejecutar bios 2048
no_espera 'parted -s /dev/sda mklabel' 'no particiona nada si no se escribe BORRAR'
no_espera 'mkfs'                       'no formatea si se cancela'
no_espera 'rsync'                      'no copia si se cancela'
no_espera 'chpasswd'                   'no toca contrasenas si se cancela'

echo
echo "=== G: rama manual (cfdisk) en UEFI con 7 GB: la EFI se detecta por GUID ==="
# En el ensayo real de VirtualBox esta rama abortaba con "No hay particion EFI (esp)":
# el lsblk de trixie deja PARTFLAGS vacio en GPT, asi que el flag nunca casaba. Aqui se
# finge ese lsblk mudo (flags vacio) y se comprueba que el GUID c12a7328 si vale.
printf 'sda disk\nsdb disk\n' > "$T/d/disks"
cat > "$T/d/tabla" <<'EOF'
RM sdb 1
SIZE sdb 32000000000
MODEL sdb USB
RM sda 0
SIZE sda 32000000000
MODEL sda HDD
EOF
# Raiz y swap recien creadas con cfdisk: sin formatear, asi que FSTYPE vacio y la swap
# solo se puede encontrar por su GUID. Es el estado exacto del disco en el ensayo real.
printf '/dev/sda1 512M vfat c12a7328-f81f-11d2-ba4b-00a0c93ec93b\n/dev/sda2 27,5G - 0fc63daf-8483-4772-8e79-3d69d8477de4\n/dev/sda3 2G - 0657fd6d-a4ab-43c4-84e5-0933c84b4f4f\n' > "$T/d/parts"
: > "$T/d/flags"
printf '/dev/sda1 vfat\n/dev/sda2 ext4\n/dev/sda3 swap\n' > "$T/d/tipos"
printf '/dev/sda1 efi\n/dev/sda2 raiz\n/dev/sda3 swap\n' > "$T/d/uuids"
echo "  26000M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/sda|30 GB|HDD|/dev/sda\nParticionar antes con cfdisk y usar eso|manual\n/dev/sda2|27,5G|x\n' > "$T/q/lista"
printf 'BORRAR\nClave123\nClave123\n' > "$T/q/entrada"
prepara_nodos sda sda1 sda2 sda3
ejecutar efi 7168
espera_en "$JLOG" 'konsole'                      'abre cfdisk en una consola'
no_espera 'mklabel'                              'en la rama manual no se rehace la tabla'
no_espera 'mkpart'                               'en la rama manual no se particiona'
espera 'mkfs.ext4 -q -F -L willyroot /dev/sda2'  'formatea la raiz elegida a mano'
espera 'mkfs.vfat -F32 -n WILLYEFI /dev/sda1'    'formatea la EFI encontrada por su GUID'
espera 'mkswap -L willyswap /dev/sda3'           'prepara la swap'
espera 'mount /dev/sda1 /willy-target/boot/efi'  'monta la EFI detectada'
espera_en "$T/tee_in" 'UUID=efi /boot/efi vfat'  'fstab con la EFI por GUID'
espera_en "$T/tee_in" 'UUID=swap none swap'      'fstab con la swap del esquema manual'
espera 'grub-install --target=x86_64-efi'        'GRUB UEFI en la rama manual'

echo
for n in $NODOS; do rm -f "/dev/$n"; done
rm -rf /tmp/fakefw-* /tmp/mi-* /willy-target /tmp/willy-instalar.log
if [ "$fallos" -eq 0 ]; then echo "TODO CORRECTO"; else echo "HAY $fallos FALLOS"; exit 1; fi
