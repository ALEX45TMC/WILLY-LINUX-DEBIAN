#!/bin/bash
# Ensayo del instalador 2.1 (willy-instalar) SIN tocar ningun disco real.
# Mismo mundo simulado que el ensayo de la 2.5, adaptado a esta edicion:
#  - la 2.1 localiza el USB con willy-medio (portado el 2026-10-17 al ver que en el
#    DVD virtual de trixie live-boot monta en /run/live/medium y la ruta antigua fallaba);
#  - la 2.1 no pide contrasena (el usuario sigue siendo live/willy), asi que la
#    cola de entrada solo lleva el BORRAR;
#  - en UEFI instala con --removable --no-nvram, sin efibootmgr ni efivarfs.
set -u
TREE="${TREE:-/mnt/c/Users/DORA/Documents/Qoder/2026-10-12/8792315c/github-willylinux/src/tree-2.1/config/hooks/live/0400-instalador.hook.chroot}"
T=/root/willy-inst-test-21
export T JLOG="$T/log" D="$T/d" Q="$T/q" FORMATEADOS="$T/formateados"
export PATH="$T/bin:$PATH"
fallos=0

rm -rf "$T"; mkdir -p "$T/bin" "$T/q" "$T/d"
: > "$JLOG"; : > "$FORMATEADOS"
[ -f "$TREE" ] || { echo "FALLO: no existe $TREE"; exit 1; }
awk '/^cat > "\$BIN\/willy-instalar" <<'"'"'WLYINSTALL'"'"'$/{d=1;next} d&&/^WLYINSTALL$/{exit} d{print}' \
	"$TREE" > "$T/willy-instalar"
[ "$(wc -l < "$T/willy-instalar")" -gt 100 ] || { echo "FALLO: no se extrajo el instalador"; exit 1; }
# willy-medio va burlado igual que en el ensayo de la 2.5: se saca tal cual del hook,
# porque es justo el trozo que decidia si esto es una sesion live o un disco instalado.
awk '/^cat > "\$BIN\/willy-medio" <<'"'"'WLYMEDIO'"'"'$/{d=1;next} d&&/^WLYMEDIO$/{exit} d{print}' \
	"$TREE" > "$T/bin/willy-medio"
[ "$(wc -l < "$T/bin/willy-medio")" -gt 5 ] || { echo "FALLO: no se extrajo willy-medio del hook"; exit 1; }
echo "instalador 2.1 extraido del hook: $(wc -l < "$T/willy-instalar") lineas"

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
# Un "-" en el fstype significa "sin formato": el fake lo suelta vacio, que es lo que
# hace lsblk -r y lo que desplaza las columnas si van en mal orden.
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
# Lo que se escribe por tee (el fstab y el anadido de GRUB_DISABLE_OS_PROBER) se guarda
# aparte para poder comprobar el texto resultante.
case "$orden" in
	tee\ *) cat >> "$T/tee_in" ;;
esac
case "$orden" in
	mkfs.*\ *|mkswap\ *) printf '%s\n' "$(sacar)" >> "$FORMATEADOS" ;;
esac
exit 0
FAKE

printf '#!/bin/bash\nprintf "BIN: %%s %%s\\n" "partprobe" "$*" >> "$JLOG"\nexit 0\n' > "$T/bin/partprobe"
# La 2.1 abre el cfdisk con lxterminal (IceWM), no con konsole.
for n in lxterminal konsole cfdisk; do
	printf '#!/bin/bash\nprintf "BIN: %%s %%s\\n" "%s" "$*" >> "$JLOG"\nexit 0\n' "$n" > "$T/bin/$n"
done
printf '#!/bin/sh\necho '"'"'SUDO="sudo -n"'"'"'\n' > "$T/bin/willy-sudo"
# willy-medio ya esta en $T/bin (extraido del hook arriba) y usa findmnt, que va burlado.
chmod 755 "$T"/bin/*

espera()    { if grep -qF -- "$1" "$JLOG" "$Q/dialogos" 2>/dev/null; then echo "OK    $2"; else echo "FALLO $2"; printf '        buscado: %s\n' "$1"; fallos=$(( fallos + 1 )); fi; }
no_espera() { if grep -qF -- "$1" "$JLOG" "$Q/dialogos" 2>/dev/null; then echo "FALLO $2"; printf '        no deberia estar: %s\n' "$1"; fallos=$(( fallos + 1 )); else echo "OK    $2"; fi; }
espera_en() { if grep -qF -- "$2" "$1" 2>/dev/null; then echo "OK    $3"; else echo "FALLO $3"; printf '        buscado %s en %s\n' "$2" "$1"; fallos=$(( fallos + 1 )); fi; }
# Los tamano negativo solo se puede buscar con expresion regular ("mkpart ... -2GiB"),
# y grep -F no la interpreta: esta variante mira unicamente el registro de ordenes.
no_espera_re() {
	if grep -qE "$1" "$JLOG" 2>/dev/null; then
		echo "FALLO $2"; printf '        no deberia estar: %s\n' "$1"; grep -E "$1" "$JLOG" | sed 's/^/        /'; fallos=$(( fallos + 1 ))
	else echo "OK    $2"; fi
}

mkdir -p /willy-target/etc/default
echo "" > /willy-target/etc/default/grub

NODOS=""
prepara_nodos() {
	for n in "$@"; do
		[ -b "/dev/$n" ] || mknod "/dev/$n" b 250 $(( 100 + RANDOM % 4000 )) 2>/dev/null
		mkdir -p /willy-target/etc/default
		echo "" > /willy-target/etc/default/grub
		NODOS="$NODOS $n"
	done
}

ejecutar() { # $1=efi|bios  $2=RAM en MB  $3=sin-grub|sin-bios para fingir la ISO sin grub2-common o sin grub-pc  $4=ruta live a fingir (nada = sin sesion live)
	local modo=$1 ram=$2 rc fw=/tmp/fakefw21-$1-${3:-} medio=${4:-/run/live/medium}
	local uefi=0 sin="" bios=""
	case "$1" in efi) uefi=1 ;; esac
	case "${3:-}" in sin-grub) sin=1 ;; sin-bios) bios=1 ;; esac
	rm -rf "$fw"; mkdir -p "$fw/efi"
	[ "$uefi" = 1 ] || rm -rf "$fw/efi"
	: > "$JLOG"; : > "$Q/dialogos"; : > "$FORMATEADOS"; : > "$T/tee_in"
	unshare -m bash -c "
		[ \"x$medio\" = xnada ] || mkdir -p $medio
		mount --bind $fw /sys/firmware
		# Las guardas miran /usr/sbin y /usr/bin: se monta un tmpfs vacio y se dejan
		# ahi los dos ejecutables, salvo cuando se quiere fingir que faltan.
		mount -t tmpfs willy-sbin /usr/sbin
		[ -n '$sin' ] || { touch /usr/sbin/grub-install /usr/sbin/grub-bios-setup; chmod 755 /usr/sbin/grub-install /usr/sbin/grub-bios-setup; }
		[ -z '$bios' ] || rm -f /usr/sbin/grub-bios-setup
		awk -v r=$ram '/MemTotal/{print \"MemTotal:       \" r \"000 kB\"; next} {print}' /proc/meminfo > /tmp/mi21-$1${3:-}
		mount --bind /tmp/mi21-$1${3:-} /proc/meminfo
		exec dash -x '$T/willy-instalar' 2> '$T/stderr'
	"
	rc=$?
	echo "     (salio $rc; $(wc -l < "$JLOG") ordenes privilegiadas)"
	if [ -n "${DEPURAR:-}" ]; then
		echo "     ---- traza ----"; tail -25 "$T/stderr" | sed 's/^/     /'
		echo "     ---- dialogos ----"; cut -c1-110 "$Q/dialogos" | head -10 | sed 's/^/     /'
	fi
	return $rc
}

echo
echo "=== A: UEFI, NVMe con Windows, 16 GB de RAM (y zram0 de paso) ==="
# zram0 y fd0 salen como TYPE=disk en lsblk: si se cuelan en la lista, el usuario puede
# elegir la RAM comprimida como destino y borrar la sesion en marcha.
printf 'sdb disk\nnvme0n1 disk\nzram0 disk\nfd0 disk\nloop0 loop\n' > "$T/d/disks"
echo sdb > "$T/d/padre"
echo /dev/sdb2 > "$T/d/medium"
cat > "$T/d/tabla" <<'EOF'
RM sdb 1
SIZE sdb 32000000000
MODEL sdb USB
RM nvme0n1 0
SIZE nvme0n1 250000000000
MODEL nvme0n1 SSD
RM zram0 0
SIZE zram0 8000000000
MODEL zram0
EOF
printf '/dev/nvme0n1p1 512M vfat c12a7328-f81f-11d2-ba4b-00a0c93ec93b\n/dev/nvme0n1p2 200G ntfs 0fc63daf-8483-4772-8e79-3d69d8477de4\n' > "$T/d/parts"
printf '/dev/nvme0n1p2 ntfs\n' > "$T/d/tipos"
printf '/dev/nvme0n1p1 efi\n/dev/nvme0n1p2 raiz\n' > "$T/d/uuids"
echo "  99999M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/nvme0n1|250 GB|SSD|/dev/nvme0n1\nBorrar el disco entero y particionar solo (recomendado)|auto\n' > "$T/q/lista"
printf 'BORRAR\n' > "$T/q/entrada"
prepara_nodos nvme0n1 nvme0n1p1 nvme0n1p2
ejecutar efi 16384
no_espera 'zram0'                                'la RAM comprimida no sale como destino'
no_espera 'fd0'                                  'los disquetes no salen como destino'
no_espera 'loop0'                                'los loop no salen como destino'
no_espera 'sdb'                                  'el USB de arranque no sale como destino'
espera 'mklabel gpt'                              'crea tabla GPT en UEFI'
espera 'mkpart WillyEFI fat32 1MiB 513MiB'        'particion EFI de 512 MB'
espera 'set 1 esp on'                             'marca la particion como esp'
espera 'mkpart Willy ext4 513MiB 100%'            'la raiz ocupa todo lo demas'
no_espera 'WillySwap'                             'sin swap porque hay 16 GB de RAM'
espera 'mkfs.ext4 -q -F -L willyroot /dev/nvme0n1p2' 'formatea la raiz (nvme lleva sufijo p2)'
espera 'mkfs.vfat -F32 -n WILLYEFI /dev/nvme0n1p1'   'formatea la EFI'
espera_en "$T/tee_in" 'UUID=raiz / ext4'          'fstab con la raiz por UUID'
espera_en "$T/tee_in" 'UUID=efi /boot/efi vfat'   'fstab con la EFI por UUID'
espera 'rm -f /willy-target/etc/sudoers.d/willy-live' 'quita el sudo sin clave del disco'
espera 'chroot /willy-target apt-get purge -y live-boot' 'despide live-boot del disco nuevo'
espera 'grub-install --target=x86_64-efi --efi-directory=/boot/efi' 'GRUB UEFI'
espera '--removable --no-nvram'                   'GRUB UEFI sin tocar el NVRAM de la firmware'
no_espera 'efibootmgr'                             'la 2.1 no escribe el NVRAM con efibootmgr'
no_espera 'grub-install --target=i386-pc'         'no instala GRUB de BIOS en un equipo UEFI'
espera 'grub-mkconfig -o /boot/grub/grub.cfg'     'genera el menú de GRUB'
espera 'Willy Linux quedo instalado en <b>/dev/nvme0n1p2</b>' 'el aviso final dice el destino'
no_espera 'parted -s /dev/sdb'                    'no particiona el USB de donde se arranca'

echo
echo "=== B: BIOS, disco SATA de 500 GB con 2 GB de RAM (crea swap) ==="
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
: > "$T/d/tipos"
printf '/dev/sda1 raiz\n/dev/sda2 swap\n' > "$T/d/uuids"
echo "  440000M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/sda|500 GB|HDD|/dev/sda\nBorrar el disco entero y particionar solo (recomendado)|auto\n' > "$T/q/lista"
printf 'BORRAR\n' > "$T/q/entrada"
prepara_nodos sda sda1 sda2
ejecutar bios 2048
espera 'mklabel msdos'                            'crea tabla msdos en BIOS'
espera 'mkpart primary ext4 1MiB 497142464000B'   'deja 2 GB al final para la swap (parted no traga -2GiB)'
espera 'set 1 boot on'                            'marca la particion de arranque'
espera 'mkpart primary linux-swap 497142464512B 100%' 'crea la swap un sector tras el final de la raiz'
no_espera 'PARTE-RECHAZADA'                       'parted acepta todas las ordenes de la rama BIOS'
espera 'mkswap -L willyswap /dev/sda2'            'formatea la swap (sata no lleva sufijo p)'
espera 'mkfs.ext4 -q -F -L willyroot /dev/sda1'   'formatea la raiz sda1'
espera_en "$T/tee_in" 'UUID=swap none swap'       'fstab con la swap'
no_espera '/boot/efi vfat'                        'sin linea EFI en el fstab de BIOS'
espera 'grub-install --target=i386-pc --boot-directory=/boot /dev/sda' 'GRUB al MBR en BIOS'
no_espera 'x86_64-efi'                            'no intenta GRUB de UEFI'

echo
echo "=== H: el mismo equipo B, pero con el medio en la ruta antigua ==="
# live-boot movio el montaje a /run/live/medium y el instalador se negaba a empezar.
# H prueba que la ruta vieja sigue sirviendo (USB grabados con live-boot anterior).
printf '/dev/sda|500 GB|HDD|/dev/sda\nBorrar el disco entero y particionar solo (recomendado)|auto\n' > "$T/q/lista"
printf 'BORRAR\n' > "$T/q/entrada"
ejecutar bios 2048 "" /lib/live/mount/medium
espera 'mklabel msdos'                            'con la ruta antigua del medio tambien instala'
no_espera 'PARTE-RECHAZADA'                       'y parted acepta las ordenes de esa ruta'

echo
echo "=== I: fuera de una sesion live (debe negarse sin tocar el disco) ==="
ejecutar bios 2048 "" nada
no_espera 'mklabel'                               'no particiona nada si no hay medio live'
espera 'Esto solo funciona desde el USB'          'y lo dice en un aviso'

echo
echo "=== D: UEFI de 2 GB en NVMe: swap con sufijo p y hueco entre raiz y swap ==="
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
printf '/dev/nvme0n1p1 efi\n/dev/nvme0n1p2 raiz\n/dev/nvme0n1p3 swap\n' > "$T/d/uuids"
echo "  99999M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/nvme0n1|250 GB|SSD|/dev/nvme0n1\nBorrar el disco entero y particionar solo (recomendado)|auto\n' > "$T/q/lista"
printf 'BORRAR\n' > "$T/q/entrada"
prepara_nodos nvme0n1 nvme0n1p1 nvme0n1p2 nvme0n1p3
ejecutar efi 2048
no_espera_re 'mkpart .* -[0-9]'                   'ningun tamano negativo llega a parted'
espera 'mkpart Willy ext4 513MiB 246960619008B'   'la raiz para 512 bytes antes del swap'
espera 'mkpart WillySwap linux-swap 246960619520B 100%' 'la swap empieza en GiB redondo'
espera 'mkswap -L willyswap /dev/nvme0n1p3'       'formatea la swap del nvme (lleva sufijo p3)'
espera_en "$T/tee_in" 'UUID=swap none swap'       'fstab con la swap de un equipo de 2 GB'

echo
echo "=== E: ISO sin grub2-common (debe cancelar antes de tocar nada) ==="
ejecutar efi 16384 sin-grub
espera 'le falta <b>grub-install</b>'             'avisa de que falta grub-install'
no_espera 'mklabel'                               'no toca la tabla de particiones'
no_espera 'mkfs'                                  'no formatea'
no_espera 'rsync'                                 'no copia el sistema'

echo
echo "=== F: equipo BIOS sin grub-pc (mismo fallo, otra causa) ==="
ejecutar bios 16384 sin-bios
espera 'le falta <b>grub-bios-setup</b>'          'avisa de que falta grub-bios-setup'
no_espera 'mklabel'                               'no toca la tabla de particiones'
no_espera 'rsync'                                 'no copia el sistema'

echo
echo "=== C: se cancela en el aviso de borrado ==="
printf '/dev/sda|500 GB|HDD|/dev/sda\n' > "$T/q/lista"
printf 'NOBORRO\n' > "$T/q/entrada"
ejecutar bios 2048
no_espera 'parted -s /dev/sda mklabel'            'no particiona nada si no se escribe BORRAR'
no_espera 'mkfs'                                  'no formatea si se cancela'
no_espera 'rsync'                                 'no copia si se cancela'

echo
echo "=== G: rama manual (cfdisk) en UEFI: la EFI y la swap se detectan por GUID ==="
# En el ensayo real de VirtualBox esta rama abortaba con "No hay particion EFI (esp)":
# el lsblk de trixie deja PARTFLAGS vacio en GPT, asi que el flag nunca casaba. Aqui se
# finge ese lsblk mudo y se comprueba que el GUID c12a7328 si vale.
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
printf '/dev/sda1 vfat\n/dev/sda2 ext4\n/dev/sda3 swap\n' > "$T/d/tipos"
printf '/dev/sda1 efi\n/dev/sda2 raiz\n/dev/sda3 swap\n' > "$T/d/uuids"
echo "  26000M" > "$T/d/dfavail"; echo 6000 > "$T/d/du"
printf '/dev/sda|30 GB|HDD|/dev/sda\nParticionar antes con cfdisk y usar eso|manual\n/dev/sda2|27,5G|sin-formato\n' > "$T/q/lista"
printf 'BORRAR\n' > "$T/q/entrada"
prepara_nodos sda sda1 sda2 sda3
ejecutar efi 16384
espera_en "$JLOG" 'lxterminal'                    'abre cfdisk en la consola de IceWM'
no_espera 'mklabel'                               'en la rama manual no se rehace la tabla'
no_espera 'mkpart'                                'en la rama manual no se particiona'
espera 'mkfs.ext4 -q -F -L willyroot /dev/sda2'   'formatea la raiz elegida a mano'
espera 'mkfs.vfat -F32 -n WILLYEFI /dev/sda1'     'formatea la EFI encontrada por su GUID'
espera 'mkswap -L willyswap /dev/sda3'            'prepara la swap buscandola por su GUID'
espera 'mount /dev/sda1 /willy-target/boot/efi'   'monta la EFI detectada'
espera_en "$T/tee_in" 'UUID=efi /boot/efi vfat'   'fstab con la EFI por GUID'
espera_en "$T/tee_in" 'UUID=swap none swap'       'fstab con la swap del esquema manual'
espera 'grub-install --target=x86_64-efi'         'GRUB UEFI en la rama manual'

echo
for n in $NODOS; do rm -f "/dev/$n"; done
rm -rf /tmp/fakefw21-* /tmp/mi21-* /willy-target /tmp/willy-instalar.log
if [ "$fallos" -eq 0 ]; then echo "TODO CORRECTO"; else echo "HAY $fallos FALLOS"; exit 1; fi
