#!/bin/bash
# Mostra o sorteio como a corrente que ele e: cada um presenteia o proximo.
# Le o segredo por prompt oculto — nao passa pela linha de comando.
URL=${URL:-https://presentinho-do-textor.onrender.com}
read -r -s -p "ADMIN_SECRET (nao aparece na tela): " S; echo; echo
curl -s --max-time 90 "$URL/api/admin/results" -H "x-admin-secret: $S" | python3 -c "$(cat <<'PY'
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("Resposta invalida do servidor."); sys.exit(1)
if isinstance(d, dict):
    if d.get("error") == "unauthorized":
        print("ADMIN_SECRET errado. Confira em Render > seu servico > Environment.")
    else:
        print("Erro da API:", d)
    sys.exit(1)

m = {p["name"]: p["receiver"] for p in d}
viu = {p["name"] for p in d if p["revealed"]}
if not all(m.values()):
    print("Sorteio ainda nao foi rodado."); sys.exit(1)

# percorre a corrente a partir de um nome qualquer
inicio = sorted(m)[0]
ordem, cur = [inicio], m[inicio]
while cur != inicio and len(ordem) <= len(m):
    ordem.append(cur); cur = m[cur]

w = max(len(n) for n in m)
print("A CORRENTE — cada um presenteia o proximo da lista\n")
for i, n in enumerate(ordem, 1):
    print("  %2d. %s  %s" % (i, n.ljust(w), "(ja viu)" if n in viu else ""))
print("      %s  e fecha de volta em %s" % (" " * (w + 1), inicio))

print("\n%d de %d na corrente | %d ja revelaram" % (len(ordem), len(m), len(viu)))
if len(ordem) != len(m):
    print("ATENCAO: a corrente nao passa por todo mundo — ha ciclos separados.")
    sys.exit(2)
print("A corrente passa por todos os %d e fecha na ultima pessoa. Sem interrupcao." % len(m))
PY
)"
