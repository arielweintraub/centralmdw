#!/usr/bin/env bash
# Confere o bloco DATA, criptografa trabalho/index.html e atualiza index.html.
# Uso: MDW_PASS='senha' bash tools/publicar.sh
# Não faz commit nem push: isso fica para quem chamou.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MDW_PASS:?Defina MDW_PASS com a senha da família}"
: "${MDW_PROIB:?Defina MDW_PROIB com a lista de nomes proibidos no site (fica fora do GitHub)}"
test -s trabalho/index.html

# 1. O bloco DATA precisa ser JavaScript válido e ter os campos esperados
node -e '
const fs = require("fs");
const s = fs.readFileSync("trabalho/index.html", "utf8");
const i = s.indexOf("var DATA = {"), j = s.indexOf("\n};", i);
if (i < 0 || j < 0) throw new Error("bloco DATA não encontrado");
const DATA = Function(s.slice(i, j + 3) + "; return DATA;")();
for (const k of ["atualizadoEm","controle","pendencias","vencimentos","fixas","seguros","historico"])
  if (DATA[k] === undefined) throw new Error("falta o campo " + k);
const iso = /^\d{4}-\d{2}-\d{2}$/;
for (const v of DATA.vencimentos) if (!iso.test(v.data) || !v.titulo) throw new Error("vencimento inválido: " + JSON.stringify(v));
for (const p of DATA.pendencias) if (!iso.test(p.data) || !p.titulo || !/^[a-z0-9-]+$/.test(p.id || "")) throw new Error("pendência inválida (data, titulo e id em minúsculas-com-hífen): " + JSON.stringify(p));
const ids = DATA.pendencias.map(p => p.id); if (new Set(ids).size !== ids.length) throw new Error("id de pendência repetido");
if (!Array.isArray(DATA.controle.dispensados)) throw new Error("falta controle.dispensados");
for (const s2 of DATA.seguros) if (s2.fim && !iso.test(s2.fim)) throw new Error("fim de seguro inválido: " + s2.fim);
for (const h of DATA.historico) if (!iso.test(h.data) || !h.texto) throw new Error("histórico inválido: " + JSON.stringify(h));
for (const f of DATA.fixas) if (f.ultimo && !["ok","late"].includes(f.ultimo.nivel)) throw new Error("conta fixa inválida: " + JSON.stringify(f));
if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(DATA.atualizadoEm)) throw new Error("atualizadoEm inválido");
const bad = /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b/.exec(s.slice(i, j));
if (bad) throw new Error("parece haver um CPF no DATA: " + bad[0]);
// Regra do site: nada de valores em reais nem endereços de imóveis
const bloco = s.slice(i, j);
// Padrões genéricos aqui; os nomes específicos (ruas, bairros) vêm da variável MDW_PROIB,
// que fica fora do GitHub (definida pela rotina diária).
const proib = [/R\$/, /\breais\b/i, /\bRua\b/, /\bAv\.|\bAvenida\b|\bAlameda\b|\bTravessa\b/, new RegExp(process.env.MDW_PROIB)];
for (const r of proib) { const m = r.exec(bloco); if (m) throw new Error("o site não pode ter valores nem endereços; achei: \"" + bloco.slice(Math.max(0, m.index - 40), m.index + 40).replace(/\n/g, " ") + "\""); }
for (const v of DATA.vencimentos) if (v.valor) throw new Error("vencimento com campo valor (proibido): " + v.titulo);
console.log("DATA ok: " + DATA.vencimentos.length + " vencimentos, " + DATA.pendencias.length + " pendências");
'

# 2. Criptografa com a mesma senha e o mesmo sal de sempre (.staticrypt.json)
rm -rf saida conferencia
npx -y staticrypt@3.5.4 trabalho/index.html -p "$MDW_PASS" -d saida \
  --template-title "Central MDW" \
  --template-instructions "Digite a senha da família para entrar." \
  --template-placeholder "Senha" --template-button "Entrar" \
  --template-remember "Lembrar neste aparelho" \
  --template-error "Senha incorreta. Tente de novo." \
  --template-toggle-show "Mostrar senha" --template-toggle-hide "Esconder senha" \
  --template-color-primary "#1E5E4B" --template-color-secondary "#F2F5F3" >/dev/null

# 3. Nada de texto aberto no arquivo publicado
#    Os textos de teste saem do próprio bloco DATA, então nenhuma palavra fica escrita aqui.
node -e '
const fs = require("fs");
const s = fs.readFileSync("trabalho/index.html", "utf8"), out = fs.readFileSync("saida/index.html", "utf8");
const i = s.indexOf("var DATA = {"), j = s.indexOf("\n};", i);
const DATA = Function(s.slice(i, j + 3) + "; return DATA;")();
const amostras = ["var DATA", DATA.email]
  .concat(DATA.historico.map(h => h.texto), DATA.pendencias.map(p => p.titulo), DATA.vencimentos.map(v => v.titulo),
          DATA.seguros.map(x => x.seguradora), DATA.seguros.map(x => x.apolice))
  .filter(t => t && t.length >= 5).map(t => t.slice(0, 24));
const vazou = amostras.filter(t => out.includes(t));
if (vazou.length) { console.error("ERRO: texto aberto apareceu no arquivo criptografado (" + vazou.length + " trechos). Nada foi publicado."); process.exit(1); }
console.log("criptografia ok: " + amostras.length + " trechos conferidos");
' 

# 4. Abre de novo com a senha e confere que é idêntico
npx -y staticrypt@3.5.4 saida/index.html --decrypt -p "$MDW_PASS" -d conferencia >/dev/null
cmp -s conferencia/index.html trabalho/index.html || { echo "ERRO: a conferência não bateu. Nada foi publicado." >&2; exit 1; }

cp saida/index.html index.html
rm -rf saida conferencia
echo "ok: index.html atualizado e conferido (falta commit e push)"
