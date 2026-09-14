#!/bin/bash
# Sorteia, confere as regras e mostra o status. Rode quantas vezes quiser:
# cada execucao refaz o sorteio do zero e zera todas as revelacoes.
set -uo pipefail
URL=${URL:-https://presentinho-do-textor.onrender.com}

read -r -s -p "ADMIN_SECRET (nao aparece na tela): " S; echo
[ -z "$S" ] && { echo "Vazio. Abortado."; exit 1; }

echo
echo "[1/4] Acordando o servico (pode levar ate 1 min se estiver dormindo)..."
curl -s -o /dev/null --max-time 120 "$URL/" || { echo "  Nao respondeu. Tente de novo."; exit 1; }
echo "      no ar."

echo "[2/4] Sorteando..."
R=$(curl -s --max-time 60 -X POST "$URL/api/admin/draw" -H "x-admin-secret: $S")
case "$R" in
  *'"ok":true'*)        echo "      $R" ;;
  *unauthorized*)       echo "      ADMIN_SECRET errado. Confira em Render > Environment."; exit 1 ;;
  *unknown_names*)      echo "      Nome do grupo nao existe no banco: $R"; exit 1 ;;
  *no_valid_draw*)      echo "      Restricoes impossiveis de satisfazer: $R"; exit 1 ;;
  *)                    echo "      Resposta inesperada: $R"; exit 1 ;;
esac

echo "[3/4] Conferindo as regras (sem imprimir quem tirou quem)..."
curl -s --max-time 60 "$URL/api/admin/results" -H "x-admin-secret: $S" | python3 -c '
import json, sys
GUS = "Gus Amato"
GRUPO = {"Rafael Fernandez","Arthur Correa","Kkao","Mau","Lucca Guidoni",
         "Lucca Claro","Carmona","Victor Klock","Mett Corrrea","Igor André"}
d = json.load(sys.stdin)
m = {p["name"]: p["receiver"] for p in d}
ok = True
def check(cond, msg, det=""):
    global ok
    print(("      OK   " if cond else "      FALHA") + "  " + msg + ("" if cond else "  -> " + det))
    ok = ok and cond
check(all(m.values()), "todo mundo tem um receiver")
check(len(set(m.values())) == len(d), "cada pessoa e presenteada exatamente uma vez")
auto = [n for n, r in m.items() if n == r]
check(not auto, "ninguem tirou a si mesmo", ", ".join(auto))
doador = next((n for n, r in m.items() if r == GUS), None)
check(doador in GRUPO, "quem tirou o Gus esta no grupo dos 10", str(doador))
check(m.get(GUS) in GRUPO, "quem o Gus tirou esta no grupo dos 10", str(m.get(GUS)))
sys.exit(0 if ok else 2)
' || { echo; echo "REGRAS VIOLADAS — nao compartilhe. Me chame."; exit 2; }

echo "[4/4] Status:"
curl -s "$URL/api/progress" | sed 's/^/      /'
echo
echo "PRONTO. Sorteio novo no ar, ninguem revelou ainda."
echo "Link: $URL"
