#!/usr/bin/env bash
# Abre o site criptografado para edição.
# Uso: MDW_PASS='senha' bash tools/abrir.sh
# Resultado: trabalho/index.html (texto aberto; a pasta trabalho/ nunca vai para o GitHub).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MDW_PASS:?Defina MDW_PASS com a senha da família}"
rm -rf trabalho
npx -y staticrypt@3.5.4 index.html --decrypt -p "$MDW_PASS" -d trabalho >/dev/null
test -s trabalho/index.html
grep -q "var DATA = {" trabalho/index.html
echo "ok: trabalho/index.html aberto para edição"
