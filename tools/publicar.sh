#!/usr/bin/env bash
# Confere o bloco DATA, criptografa trabalho/index.html e atualiza index.html.
# Uso: MDW_PASS='senha' bash tools/publicar.sh
# Não faz commit nem push: isso fica para quem chamou.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MDW_PASS:?Defina MDW_PASS com a senha da família}"
test -s trabalho/index.html

# 1. O bloco DATA precisa ser JavaScript válido e ter os campos esperados
node -e '
const fs = require("fs");
const s = fs.readFileSync("trabalho/index.html", "utf8");
const i = s.indexOf("var DATA = {"), j = s.indexOf("\n};", i);
if (i < 0 || j < 0) throw new Error("bloco DATA não encontrado");
const DATA = Function(s.slice(i, j + 3) + "; return DATA;")();
for (const k of ["atualizadoEm","controle","pendencias","vencimentos","fixas","gastos","imoveis","seguros","extratos","historico"])
  if (DATA[k] === undefined) throw new Error("falta o campo " + k);
const iso = /^\d{4}-\d{2}-\d{2}$/;
for (const v of DATA.vencimentos) if (!iso.test(v.data) || !v.titulo) throw new Error("vencimento inválido: " + JSON.stringify(v));
for (const p of DATA.pendencias) if (!iso.test(p.data) || !p.titulo) throw new Error("pendência inválida: " + JSON.stringify(p));
for (const s2 of DATA.seguros) if (s2.fim && !iso.test(s2.fim)) throw new Error("fim de seguro inválido: " + s2.fim);
for (const h of DATA.historico) if (!iso.test(h.data) || !h.texto) throw new Error("histórico inválido: " + JSON.stringify(h));
for (const f of DATA.fixas) if (f.ultimo && !["ok","late"].includes(f.ultimo.nivel)) throw new Error("conta fixa inválida: " + JSON.stringify(f));
if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(DATA.atualizadoEm)) throw new Error("atualizadoEm inválido");
const bad = /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b/.exec(s.slice(i, j));
if (bad) throw new Error("parece haver um CPF no DATA: " + bad[0]);
console.log("DATA ok: " + DATA.vencimentos.length + " vencimentos, " + DATA.pendencias.length + " pendências");
'

# 2. Criptografa com a mesma senha e o mesmo sal de sempre (.staticrypt.json)
rm -rf saida conferencia
npx -y staticrypt@3.5.4 trabalho/index.html -p "$MDW_PASS" -d saida --short \
  --template-title "Central MDW" \
  --template-instructions "Digite a senha da família para entrar." \
  --template-placeholder "Senha" --template-button "Entrar" \
  --template-remember "Lembrar neste aparelho" \
  --template-error "Senha incorreta. Tente de novo." \
  --template-toggle-show "Mostrar senha" --template-toggle-hide "Esconder senha" \
  --template-color-primary "#1E5E4B" --template-color-secondary "#F2F5F3" >/dev/null

# 3. Nada de texto aberto no arquivo publicado
if grep -q -i -E "var DATA|Parreira|fastmail|eSocial|Allianz|Gueld|Pontal" saida/index.html; then
  echo "ERRO: texto aberto apareceu no arquivo criptografado. Nada foi publicado." >&2; exit 1
fi

# 4. Abre de novo com a senha e confere que é idêntico
npx -y staticrypt@3.5.4 saida/index.html --decrypt -p "$MDW_PASS" -d conferencia >/dev/null
cmp -s conferencia/index.html trabalho/index.html || { echo "ERRO: a conferência não bateu. Nada foi publicado." >&2; exit 1; }

cp saida/index.html index.html
rm -rf saida conferencia
echo "ok: index.html atualizado e conferido (falta commit e push)"
