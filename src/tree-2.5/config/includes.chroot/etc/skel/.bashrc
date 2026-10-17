# ~/.bashrc de Willy Linux: terminal cómoda y con colores
# Se aplica solo en shells interactivos
case $- in *i*) ;; *) return ;; esac

HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups:ignorespace
HISTTIMEFORMAT='%d/%m %H:%M  '
shopt -s histappend checkwinsize cdspell dirspell 2>/dev/null || true
shopt -s globstar 2>/dev/null || true
# Guardar cada comando al ejecutarlo, no al cerrar la sesión
PROMPT_COMMAND='history -a'"${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

EDITOR=nano
PAGER=less
LESS='-R -F -X'
export EDITOR PAGER LESS

# Autocompletado (paquetes, rutas y sudo)
if ! shopt -oq posix 2>/dev/null; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		# shellcheck disable=SC1091
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		# shellcheck disable=SC1091
		. /etc/bash_completion
	fi
fi

# Colores de ls
if command -v dircolors >/dev/null 2>&1; then
	eval "$(dircolors -b)"
fi

# Colores en las páginas de manual
export MAN_KEEP_FORMATTING=1
if command -v less >/dev/null 2>&1; then
	export LESS_TERMCAP_md=$'\e[01;36m' LESS_TERMCAP_me=$'\e[0m'
	export LESS_TERMCAP_so=$'\e[01;33m' LESS_TERMCAP_se=$'\e[0m'
fi

alias ls='ls --color=auto'
alias ll='ls -lh --color=auto'
alias la='ls -lAh --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias ip='ip -color=auto'
alias mv='mv -i'
alias cp='cp -i'
alias apagar='sudo shutdown -h now'
alias reiniciar='sudo reboot'

# Sistema y recursos
alias ram='ps -eo user,pid,pcpu,pmem,comm --sort=-pmem | head -16'
alias cpu='ps -eo user,pid,pcpu,pmem,comm --sort=-pcpu | head -16'
alias red='ip -brief addr; echo; ip route | head -5'
alias pila='systemctl --failed --no-pager'
alias puertos='ss -tulpn'
alias usb='lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL'
alias espacio='du -sh .[!.]* * 2>/dev/null | sort -h | tail -20'
alias arranque='systemd-analyze time'
alias temperatura='sensors 2>/dev/null || echo "sin sensores"'
alias bateria='acpi -b 2>/dev/null || echo "sin bateria"'
alias equipo='willy-info'
alias monitor='willy-monitor'
alias ajustes='willy-ajustes'
alias instalar='willy-instalar'
alias actualizar='willy-actualizar'
alias persistencia='willy-persistencia'
alias guardar='willy-persistencia'
alias miusuario='willy-identidad'

# Prompt: usuario@equipo ruta, con el último comando en rojo si falló
if [ "${TERM:-linux}" != "dumb" ] && [ "${TERM:-linux}" != "linux" ]; then
	PS1='\[\e]0;\u@\h: \w\a\]'
	PS1+='${debian_chroot:+($debian_chroot)}'
	PS1+='\[\e[01;32m\]\u\[\e[0m\]@\[\e[01;34m\]\h\[\e[0m\]:\[\e[01;33m\]\w\[\e[0m\]'
	PS1+='\[\e[01;31m\]$( [ $? -eq 0 ] || echo " ✗" )\[\e[0m\]\$ '
fi

# Ayuda rápida
ayuda() {
	cat <<'AYUDA'
Willy Linux 2.5.5

Atajos de teclado
  Terminal      Ctrl+Alt+T        Archivos     Ctrl+Alt+E
  Firefox       Ctrl+Alt+F        NetSurf      Ctrl+Alt+N
  Writer/Calc   Ctrl+Alt+W / C    Impress      Ctrl+Alt+P
  Ajustes       Ctrl+Alt+A        Bloquear     Ctrl+Alt+L
  Menú          clic derecho en el escritorio   Captura  Impr Pant

Comandos de sistema
  equipo      resumen del equipo        monitor   panel de consumo (RAM/CPU/red/batería)
  ajustes    panel de configuración    ram cpu   qué gasta memoria y qué gasta CPU
  red         direcciones IP            puertos   servicios escuchando
  usb         discos y memorias         espacio   qué ocupa más en la carpeta actual
  miusuario   mi nombre y mi contraseña guardar   que los cambios duren al apagar
  temperatura / bateria / arranque / pila (servicios fallidos)
  htop  mc    monitor interactivo y gestor de archivos en dos paneles
  instalar    pasar Willy Linux al disco del ordenador
  actualizar  buscar e instalar actualizaciones por internet
  persistencia guardar los cambios en el propio USB
  apagar  reiniciar                    apaga o reinicia el equipo
AYUDA
	# La clave del usuario live solo vale en la memoria USB. En un disco instalado
	# la contrasena es la que se eligio al instalar, y decir otra aqui confundiria.
	# willy-medio es quien sabe donde monta live-boot el medio: cambio de ruta en la
	# version que trae la 2.5, y con la ruta antigua esto se leia como "instalado".
	if willy-medio >/dev/null 2>&1; then
		printf '\nContraseña del usuario live: willy\n'
	fi
}

# Bienvenida breve
echo "Willy Linux 2.5.5 - escribe 'ayuda' para ver atajos y comandos."
