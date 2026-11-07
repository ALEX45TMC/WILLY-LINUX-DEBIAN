import os, re, subprocess, tempfile

d = r'E:\Willy Linux\2.8\tree\config\hooks\live'
tmp = tempfile.mkdtemp()
fallos = 0
n = 0

def check(nombre, texto):
    global fallos, n
    p = os.path.join(tmp, nombre)
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        f.write(texto if texto.endswith('\n') else texto + '\n')
    r = subprocess.run(['sh', '-n', p], capture_output=True, text=True, shell=False)
    n += 1
    if r.returncode != 0:
        fallos += 1
        print('FALLO', nombre)
        print(r.stderr.strip())

for fn in sorted(os.listdir(d)):
    if not fn.endswith('.chroot'):
        continue
    src = open(os.path.join(d, fn), encoding='utf-8', errors='replace').read()
    check(fn, src)
    for m in re.finditer(r"<<'([A-Za-z0-9_-]+)'\n(.*?)\n\1\n", src, re.S):
        marca, cuerpo = m.group(1), m.group(2)
        if not cuerpo.lstrip().startswith('#!'):
            continue
        check(f'{fn}.{marca}', cuerpo)

print(f'comprobados {n} guiones, fallos {fallos}')
