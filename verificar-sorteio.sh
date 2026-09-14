#!/bin/bash
# Confere o sorteio gravado sem imprimir quem tirou quem.
URL=${URL:-https://presentinho-do-textor.onrender.com}
read -r -s -p "ADMIN_SECRET (nao aparece na tela): " S; echo; echo
curl -s "$URL/api/admin/results" -H "x-admin-secret: $S" | python3 -c '
import json, sys
GUS = "Gus Amato"
GRUPO = {"Rafael Fernandez","Arthur Correa","Kkao","Mau","Lucca Guidoni",
         "Lucca Claro","Carmona","Victor Klock","Mett Corrrea","Igor André"}
try:
    d = json.load(sys.stdin)
except Exception:
    print("Resposta invalida — segredo errado?"); sys.exit(1)
if isinstance(d, dict):
    print("Erro da API:", d); sys.exit(1)

m = {p["name"]: p["receiver"] for p in d}
ok = True
def check(cond, msg, detalhe=""):
    global ok
    print(("  OK   " if cond else "  FALHA") + "  " + msg + ("" if cond else "  -> " + detalhe))
    if not cond: ok = False

print(f"{len(d)} participantes | {sum(1 for p in d if p['revealed'])} ja revelaram\n")
check(all(m.values()), "todo mundo tem um receiver", "sorteio nao foi rodado?")
check(len(set(m.values())) == len(d), "cada pessoa e presenteada exatamente uma vez")
auto = [n for n, r in m.items() if n == r]
check(not auto, "ninguem tirou a si mesmo", ", ".join(auto))
doador = next((n for n, r in m.items() if r == GUS), None)
check(doador in GRUPO, "quem tirou o Gus esta no grupo dos 10", str(doador))
check(m.get(GUS) in GRUPO, "quem o Gus tirou esta no grupo dos 10", str(m.get(GUS)))
print("\n" + ("TUDO CERTO" if ok else "TEM PROBLEMA — nao compartilhe ainda"))
print("(nomes so aparecem acima em caso de falha)")
'
