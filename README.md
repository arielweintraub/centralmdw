# Central MDW

Site da família, protegido por senha (StatiCrypt), publicado pelo GitHub Pages.

- `index.html`: o site criptografado. Sem a senha, o conteúdo não pode ser lido.
- `.staticrypt.json`: o "sal" da criptografia. Não é segredo e precisa ficar aqui, para que a senha continue a mesma.
- `tools/abrir.sh`: abre o site para edição em `trabalho/`.
- `tools/publicar.sh`: confere os dados, criptografa de novo e verifica que o resultado abre com a senha.

A pasta `trabalho/` tem texto aberto e está no `.gitignore`. Ela nunca deve ir para o GitHub.
A senha não fica neste repositório.
