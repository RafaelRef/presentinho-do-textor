#!/bin/bash
# Libera todo mundo para ver DE NOVO o mesmo nome. NAO refaz o sorteio.
# Confere, no fim, que nenhum receiver mudou.
set -uo pipefail
URL=${URL:-https://presentinho-do-textor.onrender.com}
ANTES=$(mktemp); DEPOIS=$(mktemp)
trap 'rm -f "$ANTES" "$DEPOIS"' EXIT

read -r -s -p "ADMIN_SECRET (nao aparece na tela): " S; echo
[ -z "$S" ] && { echo "Vazio. Abortado."; exit 1; }

echo
echo "[1/4] Acordando o servico (ate 2 min se estiver dormindo)..."
curl -s -o /dev/null --max-time 180 "$URL/" || { echo "      Nao respondeu."; exit 1; }
echo "      no ar."

echo "[2/4] Guardando o sorteio atual, para provar que nao muda..."
curl -s --max-time 60 "$URL/api/admin/results" -H "x-admin-secret: $S" > "$ANTES"
grep -q unauthorized "$ANTES" && { echo "      ADMIN_SECRET errado."; exit 1; }
echo "      guardado."

echo "[3/4] Reabrindo..."
R=$(curl -s --max-time 60 -X POST "$URL/api/admin/reabrir" -H "x-admin-secret: $S")
case "$R" in
  *'"ok":true'*)  echo "      $R" ;;
  *unauthorized*) echo "      ADMIN_SECRET errado."; exit 1 ;;
  *sem_sorteio*)  echo "      Nao ha sorteio gravado para reabrir."; exit 1 ;;
  *)              echo "      Resposta inesperada: $R"; exit 1 ;;
esac

echo "[4/4] Conferindo..."
curl -s --max-time 60 "$URL/api/admin/results" -H "x-admin-secret: $S" > "$DEPOIS"
ANTES="$ANTES" DEPOIS="$DEPOIS" python3 -c "$(cat <<'PY'
import json, os, sys
a = {p["name"]: p["receiver"] for p in json.load(open(os.environ["ANTES"]))}
d = json.load(open(os.environ["DEPOIS"]))
b = {p["name"]: p["receiver"] for p in d}
ok = True
def check(cond, msg, det=""):
    global ok
    print(("      OK   " if cond else "      FALHA") + "  " + msg + ("" if cond else "  -> " + det))
    ok = ok and cond
mudou = [n for n in a if a[n] != b.get(n)]
check(not mudou, "NINGUEM teve o nome sorteado alterado", ", ".join(mudou))
ainda = [p["name"] for p in d if p["revealed"]]
check(not ainda, "todo mundo pode ver de novo", ", ".join(ainda))
sys.exit(0 if ok else 2)
PY
)" || { echo; echo "Algo saiu errado. Me chame."; exit 2; }

echo
curl -s "$URL/api/progress" | sed 's/^/      /'
echo
echo "PRONTO. Mesmo sorteio, todo mundo liberado para ver mais uma vez."
echo "Link: $URL"
