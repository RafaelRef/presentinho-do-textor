#!/bin/bash
# Refaz o sorteio e confere todas as regras, inclusive que ninguem repetiu
# quem tinha antes. Cada execucao zera as revelacoes.
set -uo pipefail
URL=${URL:-https://presentinho-do-textor.onrender.com}
ANTES=$(mktemp)
trap 'rm -f "$ANTES"' EXIT

read -r -s -p "ADMIN_SECRET (nao aparece na tela): " S; echo
[ -z "$S" ] && { echo "Vazio. Abortado."; exit 1; }

echo
echo "[1/5] Acordando o servico (ate 1 min se estiver dormindo)..."
curl -s -o /dev/null --max-time 120 "$URL/" || { echo "      Nao respondeu."; exit 1; }
echo "      no ar, rodando o commit $(curl -s --max-time 30 "$URL/api/version" | sed 's/[^0-9a-z]*commit[^0-9a-z]*//;s/[^0-9a-z].*//')"

echo "[2/5] Guardando o sorteio atual, para conferir que ninguem repete..."
curl -s --max-time 60 "$URL/api/admin/results" -H "x-admin-secret: $S" > "$ANTES"
grep -q unauthorized "$ANTES" && { echo "      ADMIN_SECRET errado. Confira em Render > Environment."; exit 1; }
echo "      guardado."

echo "[3/5] Sorteando..."
R=$(curl -s --max-time 60 -X POST "$URL/api/admin/draw" -H "x-admin-secret: $S")
case "$R" in
  *'"ok":true'*)   echo "      $R" ;;
  *unauthorized*)  echo "      ADMIN_SECRET errado."; exit 1 ;;
  *unknown_names*) echo "      Nome do grupo nao existe no banco: $R"; exit 1 ;;
  *no_valid_draw*) echo "      Restricoes impossiveis de satisfazer: $R"; exit 1 ;;
  *)               echo "      Resposta inesperada: $R"; exit 1 ;;
esac

echo "[4/5] Conferindo as regras (sem imprimir quem tirou quem)..."
curl -s --max-time 60 "$URL/api/admin/results" -H "x-admin-secret: $S" | ANTES="$ANTES" python3 -c "$(cat <<'PY'
import json, sys, os
GUS = "Gus Amato"
GRUPO = {"Rafael Fernandez","Arthur Correa","Kkao","Mau","Lucca Guidoni",
         "Lucca Claro","Carmona","Victor Klock","Mett Corrrea","Igor André"}
novo = {p["name"]: p["receiver"] for p in json.load(sys.stdin)}
try:
    antes = {p["name"]: p["receiver"] for p in json.load(open(os.environ["ANTES"]))}
except Exception:
    antes = {}

ok = True
def check(cond, msg, det=""):
    global ok
    print(("      OK   " if cond else "      FALHA") + "  " + msg + ("" if cond else "  -> " + det))
    ok = ok and cond

check(all(novo.values()), "todo mundo tem um receiver")
check(len(set(novo.values())) == len(novo), "cada pessoa e presenteada exatamente uma vez")
auto = [n for n, r in novo.items() if n == r]
check(not auto, "ninguem tirou a si mesmo", ", ".join(auto))
doador = next((n for n, r in novo.items() if r == GUS), None)
check(doador in GRUPO, "quem tirou o Gus esta no grupo dos 10", str(doador))
check(novo.get(GUS) in GRUPO, "quem o Gus tirou esta no grupo dos 10", str(novo.get(GUS)))
check(novo.get("Victor Klock") == "Carmona",
      "Victor Klock tira o Carmona", str(novo.get("Victor Klock")))
check(novo.get("Rafael Fernandez") != "Bia Brossel",
      "Rafael Fernandez NAO tira a Bia Brossel")

mutuos = sorted({tuple(sorted((n, r))) for n, r in novo.items() if novo.get(r) == n})
check(not mutuos, "ninguem tira quem tirou ela (sem pares mutuos)",
      "; ".join(a + " <-> " + b for a, b in mutuos))

# a corrente tem que passar por todo mundo antes de fechar
primeiro = next(iter(novo))
passos, cur = 1, novo[primeiro]
while cur != primeiro and passos <= len(novo):
    cur = novo[cur]; passos += 1
check(passos == len(novo), "o sorteio e uma corrente unica passando por todos",
      "fechou em %d de %d" % (passos, len(novo)))

if antes and any(antes.values()):
    rep = [n for n in novo if antes.get(n) and antes[n] == novo[n]]
    check(not rep, "ninguem repetiu quem tinha antes", ", ".join(rep))
else:
    print("      --     (primeiro sorteio: nada para comparar)")
sys.exit(0 if ok else 2)
PY
)" || { echo; echo "REGRAS VIOLADAS — nao compartilhe. Me chame."; exit 2; }

echo "[5/5] Status:"
curl -s "$URL/api/progress" | sed 's/^/      /'
echo
echo "PRONTO. Sorteio novo no ar, ninguem revelou ainda."
echo "Link: $URL"
