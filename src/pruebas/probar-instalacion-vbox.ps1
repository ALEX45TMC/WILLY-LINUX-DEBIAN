# Ensayo real de instalacion a disco en VirtualBox, sin intervencion humana.
#
# Necesita Hyper-V APAGADO (disable-hyperv.cmd + reinicio hecho): mientras
# HypervisorPresent sea True VirtualBox revienta con Guru Meditation -225.
#
#   fase 0  deja constancia de las ISO y discos que se usan
#   fase 1  arranque live de la 2.0 (BIOS) y de la 2.5 (BIOS)  [-Skip con SIN_FASE1=1]
#   fase 2  instalar la 2.1 en BIOS y en UEFI y arrancar del disco   (suspendida: su
#           instalador de la ISO entregada exigia /lib/live/mount/medium)
#   fase 3  instalar la 2.5 en BIOS (diagnosticada el 2026-10-17: parted rechaza los
#           nombres de particion en tabla msdos) y en UEFI, y arrancar del disco
#
# Las teclas se envian por scancodes crudos (keyboardputscancode): con teclado latam
# keyboardputstring deforma '-' '/' y '='. Ver vtype2.sh.
#
# Todo sale en E:\Willy Linux\prueba-instalacion: log, pantallazos y los VDIs.
# Para repetir: borrar E:\Willy Linux\prueba-instalacion\ensayo.marcador
$ErrorActionPreference = 'Continue'
$Vb     = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$Bash   = 'C:\Users\DORA\.qoder\bin\git\bin\bash.exe'
$Base   = 'E:\Willy Linux\prueba-instalacion'
$Shots  = Join-Path $Base 'shots'
$Log    = Join-Path $Base 'ensayo-vbox.log'
$Marca  = Join-Path $Base 'ensayo.marcador'
$Iso20  = 'E:\Willy Linux\2.0\iso\willylinux-v2.0-minimalista-amd64.iso'
$Iso21  = 'E:\Willy Linux\2.1\iso\willylinux-v2.1-amd64.iso'
$Iso25  = 'E:\Willy Linux\2.5\iso\willylinux-v2.5-kde-amd64.iso'

function Log([string]$m) {
    $t = Get-Date -Format 'HH:mm:ss'
    "$t  $m" | Tee-Object -FilePath $Log -Append | Out-Null
    Write-Output "$t  $m"
}

# --- teclado: solo codigos de barras (PS/2 set 1) ------------------------------
function Pulsar([string]$vm, [string[]]$codes) { & $Vb controlvm $vm keyboardputscancode @codes 2>&1 | Out-Null }
function Intro([string]$vm)  { Pulsar $vm @('1c', '9c') }
function Escape([string]$vm) { Pulsar $vm @('01', '81') }
# Ctrl+Alt+T abre terminal en IceWM (lxterminal) y en Plasma (konsole)
function Terminal([string]$vm) { Pulsar $vm @('1d', '38', '14', '94', 'b8', '9d') }
function Escribir([string]$vm, [string]$texto) {
    # keyboardputstring deforma '-' y '/' con el teclado latam del invitado y a veces no
    # manda nada: vtype2.sh envia scancodes crudos con el mapa latam ya probado.
    $seg = $texto -replace "[^A-Za-z0-9 ./-]", ''
    & $Bash -lc "cd /c/Users/DORA/Documents/Qoder/2026-10-12/8792315c && VM='$vm' ./vtype2.sh '$seg'" 2>&1 | Out-Null
}
function Foto([string]$vm, [string]$nombre) {
    $p = Join-Path $Shots ($nombre + '.png')
    & $Vb controlvm $vm screenshotpng $p 2>&1 | Out-Null
    if (Test-Path $p) { Log ("    foto {0}.png ({1} B)" -f $nombre, (Get-Item $p).Length) }
    else { Log "    foto $nombre.png FALLO (la VM no esta corriendo)" }
}
function Apagar([string]$vm) { & $Vb controlvm $vm poweroff 2>&1 | Out-Null; Start-Sleep -Seconds 8 }
function Arrancar([string]$vm) {
    Apagar $vm
    & $Vb startvm $vm --type headless 2>&1 | ForEach-Object { Log "    $_" }
}
function Vivo([string]$vm) {
    $n = & $Vb showvminfo $vm --machinereadable 2>&1 | Out-String
    return ($n -match 'VMState="running"')
}
# Con Hyper-V apagado, el arranque UEFI de la 2.5 (Plasma 6 + squashfs por DVD virtual y 4 GB
# de RAM) tardo casi 7 minutos: los 215 s de siempre dejaron la pantalla en negro y las teclas
# se enviaban al nada. Un PNG de pantalla negra pesa 3-7 KB y el escritorio pintado pasa de
# 150 KB, asi que se espera por tamano de captura, no por segundos fijos.
function EsperarPantalla([string]$vm, [string]$pref, [int]$limiteSeg, [int]$minKB) {
    $t = Join-Path $Shots ($pref + '-esperando.png')
    for ($s = 15; $s -le $limiteSeg; $s += 15) {
        Start-Sleep -Seconds 15
        if (-not (Vivo $vm)) { Log "    pantalla $s s: la VM se apago"; return $false }
        & $Vb controlvm $vm screenshotpng $t 2>&1 | Out-Null
        if (-not (Test-Path $t)) { Log "    pantalla $s s: la VM no responde"; continue }
        $kb = [math]::Round((Get-Item $t).Length / 1KB)
        Log ("    pantalla {0,3}s: {1} KB" -f $s, $kb)
        if ($kb -ge $minKB) { return $true }
    }
    return $false
}

# --- salvaguardas --------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $Shots | Out-Null
if (Test-Path $Marca) { Log "Marcador ya existe: el ensayo se hizo. Borrarlo para repetir."; exit 0 }
$hyp = $null
for ($i = 1; $i -le 18; $i++) {
    $l = & $Vb list vms 2>&1 | Out-String
    if ($l -match 'willy2\.1-bios') { break }
    Start-Sleep -Seconds 10
}
$hyp = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
Log "HypervisorPresent = $hyp"
if ($hyp) { Log 'Hyper-V sigue activo: VirtualBox no puede usar AMD-V. Falta disable-hyperv.cmd + reinicio.'; exit 1 }
Set-Content -Path $Marca -Value (Get-Date -Format s) -Encoding utf8
foreach ($p in @($Iso20, $Iso21, $Iso25)) { if (-not (Test-Path $p)) { Log "FALTA LA ISO $p"; exit 1 } }
Log '=== ENSAYO DE INSTALACION EN VIRTUALBOX ==='

# --- fase 0: constancia de lo que se ensaya ------------------------------------
foreach ($v in @('willy2.0-bios', 'willy2.1-bios', 'willy2.1-uefi', 'willy2.5-bios', 'willy-inst-bios')) {
    $m = & $Vb showvminfo $v --machinereadable 2>&1 | Out-String
    $iso = ([regex]::Matches($m, '"[A-Z0-9-]+-[0-9]+-[0-9]+"="([^"]*\.iso)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
    $vd  = ([regex]::Matches($m, '"[A-Z0-9-]+-[0-9]+-[0-9]+"="([^"]*\.vdi)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
    $mem = [regex]::Match($m, '(?m)^memory=(\d+)').Groups[1].Value
    $fw  = [regex]::Match($m, '(?m)^firmware="(\w+)"').Groups[1].Value
    Log ("    preflight {0,-16} {1} RAM={2} MB  DVD={3}  DISCO={4}" -f $v, $fw, $mem, $iso, $vd)
}

# --- fase 1: las ISO arrancan sin Hyper-V --------------------------------------
# Saltar con SIN_FASE1=1 cuando ya esta fotografiada (ocupa ~8 min).
if (-not $env:SIN_FASE1) {
foreach ($t in @(
        @{ vm = 'willy2.0-bios'; pref = '1-20-bios';  espera = 75 },
        @{ vm = 'willy2.5-bios'; pref = '2-25-bios';  espera = 210 })) {
    Log "--- $($t.vm): arranque live ---"
    Arrancar $t.vm
    Start-Sleep -Seconds 35
    Foto $t.vm ($t.pref + '-menu')
    Start-Sleep -Seconds $t.espera
    Foto $t.vm ($t.pref + '-escritorio')
    Apagar $t.vm
}
}

# --- instalador reutilizable ---------------------------------------------------
function ProbarInstalacion($vm, $ctl, $port, $iso, $pref, $minutosCopia, $esperaArranque, $vdi, $clave) {
    Log "--- ${vm}: instalacion ($pref) ---"
    Arrancar $vm
    # Esperar a que el escritorio este pintado de verdad: si no, las teclas se pierden en la
    # pantalla en negro y el ensayo sale falso (paso 7-25-efi el 2026-10-17 20:22).
    if (-not (EsperarPantalla $vm ($pref + '-00') 900 150)) {
        Foto $vm ($pref + '-00-sin-pantalla')
        Log "    FALLO: el escritorio no se pinto en 15 min; no se envian teclas a ciegas"
        Apagar $vm
        return
    }
    Start-Sleep -Seconds 20
    Foto $vm ($pref + '-01-vivo')
    Escape $vm                      # cierra el asistente de bienvenida si tiene el foco
    Start-Sleep -Seconds 3

    Terminal $vm
    Start-Sleep -Seconds 8
    Foto $vm ($pref + '-02-terminal')
    Escribir $vm 'willy-instalar'
    Intro $vm
    Start-Sleep -Seconds 18
    Foto $vm ($pref + '-03-pide-disco')
    Intro $vm                       # primera fila de la lista = unico disco interno
    Start-Sleep -Seconds 15
    Foto $vm ($pref + '-04-pide-BORRAR')
    Escribir $vm 'BORRAR'
    Intro $vm
    Start-Sleep -Seconds 15
    Foto $vm ($pref + '-05-esquema')
    Intro $vm                       # "Borrar el disco entero y particionar solo"
    if ($clave) {
        # La 2.5 pide dos veces la contrasena del usuario del disco instalado; con tres
        # respuestas vacias el instalador abandona sin tocar el disco.
        Start-Sleep -Seconds 12
        Foto $vm ($pref + '-05b-pide-clave')
        Escribir $vm $clave
        Intro $vm
        Start-Sleep -Seconds 8
        Foto $vm ($pref + '-05c-repite-clave')
        Escribir $vm $clave
        Intro $vm
    }
    Start-Sleep -Seconds 30
    Foto $vm ($pref + '-06-empieza-copia')

    # La copia termina cuando el VDI del host deja de crecer: rsync escribe bloques nuevos
    # y el fichero .vdi dinamico aumenta de tamano en el mismo momento.
    $prev = -1; $quietos = 0
    for ($i = 1; $i -le $minutosCopia; $i++) {
        Start-Sleep -Seconds 60
        if (-not (Vivo $vm)) { Log "    la VM se apago sola en el minuto $i"; break }
        $real = 0
        if ($vdi -and (Test-Path $vdi)) { $real = (Get-Item $vdi).Length }
        if ($real -eq $prev) { $quietos++ } else { $quietos = 0 }
        $prev = $real
        Log ("    minuto {0}: VDI {1:N0} MB (sin crecer {2} min)" -f $i, ($real / 1MB), $quietos)
        Foto $vm ("{0}-07-copiando-{1:d2}" -f $pref, $i)
        if ($real -lt 1GB) {
            if ($i -ge 12) { Log "    FALLO: a los $i min el disco sigue en $($real / 1MB) MB: la copia nunca empezo"; break }
            continue
        }
        if ($i -gt 8 -and $quietos -ge 3) { Log "    el VDI lleva 3 min sin crecer: copia terminada"; break }
    }
    Foto $vm ($pref + '-08-final')
    Escape $vm                      # NUNCA Enter: la pregunta final trae "Reiniciar:0"
    Start-Sleep -Seconds 6
    Apagar $vm
    if ($prev -lt 1GB) {
        Log "    no se prueba arrancar del disco: nunca paso de {0:N0} MB" -f ($prev / 1MB)
        & $Vb storageattach $vm --storagectl $ctl --port $port --device 0 --type dvddrive --medium $iso 2>&1 | Out-Null
        return
    }

    Log "--- ${vm}: arrancando del disco instalado ---"
    & $Vb storageattach $vm --storagectl $ctl --port $port --device 0 --type dvddrive --medium none 2>&1 | Out-Null
    Arrancar $vm
    Start-Sleep -Seconds 25
    Foto $vm ($pref + '-09-instalado-grub')
    Start-Sleep -Seconds $esperaArranque
    Foto $vm ($pref + '-10-instalado-escritorio')
    Terminal $vm
    Start-Sleep -Seconds 8
    foreach ($c in @('df -h', 'ls /home', 'cat /etc/os-release')) { Escribir $vm $c; Intro $vm; Start-Sleep -Seconds 4 }
    Start-Sleep -Seconds 3
    Foto $vm ($pref + '-11-instalado-verificacion')
    Apagar $vm
    & $Vb storageattach $vm --storagectl $ctl --port $port --device 0 --type dvddrive --medium $iso 2>&1 | Out-Null
    Log "    DVD devuelto a $vm"
}

# --- fase 2 / 3 / 4 ------------------------------------------------------------
# 2.1 cancelada el 2026-10-17 19:17: su instalador exige /lib/live/mount/medium y live-boot
# de trixie monta el medio en /run/live/medium, asi que responde "esto solo funciona desde el
# USB live" y sale sin instalar. Re-habilitar estas dos lineas tras recompilar la 2.1 con el
# helper willy-medio (lo mismo que ya se arreglo en la 2.5).
# ProbarInstalacion 'willy2.1-bios' 'IDE'  0 $Iso21 '3-21-bios'  45 130 'C:\Users\DORA\VirtualBox VMs\willy2.1-bios\disco-prueba.vdi'
# ProbarInstalacion 'willy2.1-uefi' 'SATA' 0 $Iso21 '4-21-uefi'  45 130 'E:\Willy Linux\prueba-instalacion\vm\willy21-uefi-disco.vdi'
# La BIOS queda suspendida el 2026-10-17 20:20: ya esta diagnosticada (parted rechaza el nombre
# de particion en tabla msdos, fotos 5-25-bios-06 y 6-diag-03). Se re-habilita con la ISO recompilada.
# ProbarInstalacion 'willy-inst-bios' 'SATA' 1 $Iso25 '5-25-bios' 80 245 'E:\Willy Linux\2.5\vm\willy-inst-bios.vdi' 'willy'
# Lo que falta por probar es la otra mitad de la afirmacion de los docs: que la 2.5 publicada SI
# instala en UEFI, porque ahi la tabla es GPT y los nombres de particion si valen.
ProbarInstalacion 'willy-inst-efi' 'SATA' 1 $Iso25 '7-25-efi' 80 245 'E:\Willy Linux\2.5\vm\willy-inst-efi.vdi' 'willy'

Log '=== ENSAYO TERMINADO: revisar los pantallazos de la carpeta shots ==='
