# Skill `/antired`

Cliente do cofre **antired_password**: puxa os segredos de um projeto direto pro `.env`.

## Instalar

```bash
# 1. a skill (pro Claude Code achar o /antired)
cp -r skill/antired ~/.claude/skills/antired

# 2. o CLI no PATH (recomendado)
sudo install -m 0755 skill/antired/antired /usr/local/bin/antired
# ou, sem sudo:  ln -s "$PWD/skill/antired/antired" ~/.local/bin/antired

# 3. configurar (uma vez) — pegue um token em <url>/access_tokens
antired login https://seu-cofre.exemplo.com antp_xxxx_yyyy
```

## Usar

```bash
antired ls                 # lista projetos
antired env acta           # escreve ./.env do projeto "acta" (0600, backup em .env.bak)
antired env acta -         # imprime no stdout, não grava
antired open               # abre o cofre no navegador
/antired acta              # no Claude Code, a skill faz o mesmo
```

Config fica em `~/.config/antired/config` (permissão 600). Sem o `antired` no PATH,
o Claude usa o script desta pasta diretamente.

## Segurança
- O cofre é **zero-knowledge em repouso**: o servidor não lê nada sem a sua master password.
- O **token** desta versão dá acesso de leitura ao seu cofre pessoal inteiro (escopo
  por projeto vem numa versão futura). Trate o token como uma senha; revogue em
  `<url>/access_tokens` se vazar.
- Só funciona sobre `https://` (exceto `localhost` em desenvolvimento).
