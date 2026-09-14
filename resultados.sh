#!/bin/bash
# Mostra quem tirou quem. Le o segredo por prompt oculto — nao passa pela
# linha de comando, entao nao sofre com expansao de $ e ! nem fica no historico.
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
        print("ADMIN_SECRET errado.")
        print("Confira o valor em Render > seu servico > Environment.")
    else:
        print("Erro da API:", d)
    sys.exit(1)

w = max(len(p["name"]) for p in d)
print("QUEM".ljust(w) + "      VAI PRESENTEAR         JA VIU?")
print("-" * (w + 40))
for p in sorted(d, key=lambda x: x["name"]):
    r = p["receiver"] or "(sem sorteio!)"
    print(p["name"].ljust(w) + "  ->  " + r.ljust(21) + ("sim" if p["revealed"] else "-"))
n = sum(1 for p in d if p["revealed"])
print("\n%d participantes | %d ja revelaram | %d faltam" % (len(d), n, len(d) - n))
PY
)"
