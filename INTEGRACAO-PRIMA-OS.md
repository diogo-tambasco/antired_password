# Integração do antired_password no prima_os

Guia de como levar o cofre (`antired_password`) para dentro do **prima_os** — o "OS"
de operação das empresas. Decisões e plano fechados em 05/06/2026.

> Este arquivo é público (vai pro git). **Nenhuma senha, IP ou segredo aqui.**
> Credenciais de infra ficam no `CLAUDE.md` (gitignored). Os dados do cofre ficam no
> backup SQLite local (gitignored em `backups/`).

---

## Por que integrar (e não rodar lado-a-lado)

`prima_os` e `antired_password` são a **mesma stack**: Ruby 4.0.5, Rails 8, SQLite,
auth nativo do Rails 8, Hotwire. Os dois já convivem na mesma VPS.

O `prima_os` **já tem** `User`, `Project`, membership + RBAC, `audit_log` e até um
`Vault` (service) com permissão `secrets.reveal`. Mas o Vault dele é outro mecanismo:
uma **senha master global** que destrava a leitura de env de containers Docker **ao
vivo** (`docker inspect`) — **não cifra nada em repouso, não tem chave por usuário**.
O próprio CLAUDE.md do prima_os já anota: *"Env nunca persiste → revelado via senha
master global. Futuro: vira cofre/gerenciador de senhas."*

O `antired` é exatamente esse futuro: cofre **cifrado em repouso**, envelope
zero-knowledge **por usuário** (KEK→DEK, rbnacl/libsodium), com export `.env` e tokens
de CLI.

**Decisão:** portar o **núcleo de cripto do antired como módulo dentro do prima_os** —
não clonar/rodar um segundo app. Assim reusa um login, um `User`, um `Project`, um
RBAC, um audit log, um container. Leve, que era o requisito.

> ⚠️ Se você clonar este repo para dentro do `prima_os`, é como **fonte de referência**
> para portar o módulo — não para subir um segundo Rails rodando em paralelo.

---

## Modelo de master password: por usuário (modelo 1Password)

`prima_os` já tem login próprio (senha de conta). O cofre adiciona uma **segunda**
camada, separada:

1. **Login no prima_os** → senha da conta (auth nativo, já existe).
2. **Destravar o cofre** → master password do cofre (deriva KEK→DEK; **nunca** salva).

A master password do cofre é um segredo só para destravar segredos — independente da
senha de login. Igual 1Password (conta + master password).

---

## Os 3 pontos de reconciliação

| # | Conflito | Resolução |
|---|----------|-----------|
| 1 | `User` do prima_os (com senha de login) vs `User` do antired (sem hash; só salt+DEK) | Adicionar colunas `master_salt` + `encrypted_dek` (+ nonce) no `User` do prima_os. Login continua igual; o cofre é camada extra opt-in por usuário. |
| 2 | `Project` existe nos dois | Reusar o `Project` do prima_os (já tem membership/RBAC). `vault_entries` passam a apontar para ele. |
| 3 | `Vault` global do prima_os (reveal de env de container) vs cofre per-user | **Coexistem.** Reveal-de-container continua (senha global, lê Docker ao vivo). O cofre per-user é storage cifrado novo, com permissões próprias (`vault.*`). |

---

## O que portar do antired (o que vale)

- **Lib de cripto** — envelope KEK→DEK com rbnacl (argon2id + SecretBox). É o núcleo.
- **Colunas no `User`** — `master_salt`, `encrypted_dek`, `encrypted_dek_nonce`.
- **Tabela `vault_entries`** — segredos cifrados em repouso (`ciphertext` + `nonce`).
- **`access_tokens`** — tokens de CLI (cada um carrega uma cópia da DEK re-cifrada).
- **Export `.env` por projeto** + a skill (`/antired` → renomear se fizer sentido).

Dependência nova no prima_os: `rbnacl` (precisa de `libsodium` na imagem Docker).

---

## Plano faseado

- **Fase 0 — Snapshot dos dados de produção.** ✅ Feito. Backup consistente baixado
  para `backups/` (gitignored). Cifrado em repouso; só decifra com a master password.
- **Fase 1 — Cripto + schema.** Portar a lib de envelope; migration das colunas no
  `User` + `vault_entries` + `access_tokens` no prima_os.
- **Fase 2 — UI do cofre.** Controllers/views (Hotwire) dentro do layout do prima_os,
  atrás do RBAC existente (permissão nova `vault.*`).
- **Fase 3 — Export `.env` por projeto** + skill de CLI.
- **Fase 4 — Migração de dados + deploy** (ver abaixo).

---

## Migração dos dados (Fase 4)

Os segredos são **zero-knowledge**: não dá (nem precisa) re-cifrar. A mesma master
password de cada usuário continua decifrando os blobs.

**Estratégia:** copiar **verbatim** os campos cifrados para o schema novo —
`users.master_salt` / `users.encrypted_dek` (+ nonce) e
`vault_entries.ciphertext` / `vault_entries.nonce`, mapeando `user_id` / `project_id`
para os IDs equivalentes no prima_os. Como a KEK deriva da master password + salt
(que viajam junto), tudo continua decifrável sem tocar no plaintext.

Volume real é pequeno (poucas contas, ~dezenas de segredos), então uma task de
migração idempotente resolve. O backup em `backups/` é a fonte.

---

## Estado atual (05/06/2026)

- **antired:** no ar em produção (Docker + Caddy) na VPS de operação. Cofre
  multiusuário funcionando, com contas e projetos reais já cadastrados.
- **Backup de produção:** baixado e verificado (integridade ok), guardado local e
  gitignored em `backups/`. Conteúdo cifrado.
- **Próximo passo:** Fase 1 da integração no prima_os, OU manter o antired standalone
  e migrá-lo para a VPS de labs dedicada — decisão de operação ainda aberta.
