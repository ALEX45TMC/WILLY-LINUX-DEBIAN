#!/bin/sh
xdg-user-dirs-update
lxpolkit &
volumeicon &
connman-gtk --tray &

# Panel de consumo en la esquina del escritorio (se oculta con Ctrl+Alt+M).
( sleep 1; setsid conky >/dev/null 2>&1 ) &

# Icono de bateria en la bandeja, solo si el equipo tiene bateria.
( acpi -b 2>/dev/null | grep -q . && setsid cbatticon >/dev/null 2>&1 ) &

# Bloqueo de pantalla (i3lock + xss-lock)
# Debian no pone contraseña al usuario live y sin ella i3lock no dejaría desbloquear
# nunca: se le asigna "willy" solo la primera vez. Si se cambia con willy-ajustes
# o con passwd, esa nueva contraseña se respeta en los siguientes arranques.
if ! sudo -n passwd -S live 2>/dev/null | grep -q ' live P '; then
	printf '%s\n' 'live:willy' | sudo -n chpasswd 2>/dev/null || true
fi
if sudo -n passwd -S live 2>/dev/null | grep -q ' live P '; then
	# A los 10 min sin uso: apaga el monitor y bloquea la sesión
	xset s 600 600 2>/dev/null || true
	xset s blank 2>/dev/null || true
	xset dpms 600 900 1200 2>/dev/null || true
	xss-lock -- willy-lock &
fi

pcmanfm --desktop &
exec icewm-session
