# DEPLOY — antired_password

Deploy via **Kamal 2** (Docker + kamal-proxy + TLS Let's Encrypt) numa VPS de instância única.

> ⚠️ **Segredos NÃO vivem aqui.** As credenciais reais da VPS (host, usuário, senha root) ficam
> **só** no `CLAUDE.md` local (gitignored). `config/deploy.yml` e `.kamal/secrets` também são
> gitignored. Este arquivo documenta o **processo**, sem segredos — pode ser versionado.

---

## Pré-requisitos

1. **Subdomínio apontando pro IP da VPS** (Let's Encrypt exige domínio, não IP). Ex.:
   `pass.seudominio.com → <IP da VPS>` (registro A no DNS, ex. Cloudflare, resolve em minutos).
2. **Container registry** (ghcr.io ou Docker Hub) com login.
3. **`RAILS_MASTER_KEY`** = conteúdo de `config/master.key` (gitignored).
4. Ruby 3.3+/Rails 8 + `kamal` localmente (`bundle exec kamal version`).

---

## Arquivos de deploy (gitignored — preencher localmente)

- **`config/deploy.yml`** — serviço, imagem, servidor (IP da VPS), proxy SSL + host (subdomínio),
  registry, `env.secret` (RAILS_MASTER_KEY), e **volume persistente** pro SQLite:
  `antired_storage:/rails/storage` (sem isso o banco some a cada deploy).
- **`.kamal/secrets`** — lê `RAILS_MASTER_KEY` e `KAMAL_REGISTRY_PASSWORD` do ambiente/credenciais.
  Nunca hardcodar segredo aqui versionável.

---

## Passos

```bash
# 1ª vez (provisiona Docker na VPS, sobe kamal-proxy, faz o primeiro deploy):
bundle exec kamal setup

# deploys seguintes:
bundle exec kamal deploy
```

O `kamal-proxy` cuida do TLS automático (Let's Encrypt) assim que o subdomínio resolver pro IP.

---

## Segurança pós-deploy (checklist do CLAUDE.md / SPEC §3, §10)

- [ ] **TLS de verdade** funcionando (cert válido). O app já tem `force_ssl`+`assume_ssl` em produção.
- [ ] **Backup cifrado do SQLite** pra fora da VPS (cron). O banco já é opaco em repouso, mas o
      backup não pode ser o vazamento — copiar o arquivo (já contém só ciphertext) ou cifrar de novo.
- [ ] **Trocar senha root por chave SSH** e **desabilitar login por senha** na VPS.
- [ ] Porta do app **só atrás do kamal-proxy**; nada de SQLite/SSH exposto além do necessário.
- [ ] Conferir que `config/master.key` **não** foi commitada (`git check-ignore config/master.key`).

---

## Notas de arquitetura relevantes ao deploy

- **DEK só em RAM:** a sessão usa um `MemoryStore` dedicado (não solid_cache), então a DEK em claro
  **nunca** toca o disco. Consequência: rode o Puma **em processo único** (threads, sem `WEB_CONCURRENCY`
  multi-worker) pra a sessão ser consistente — adequado pra um cofre pessoal de instância única.
  Reiniciar o container descarta as sessões (a DEK morre com o processo), e o usuário só refaz login.
- **libsodium23** já está no `Dockerfile` (runtime do rbnacl).
- **Volume `antired_storage`** é obrigatório no `deploy.yml` — é onde vive o `storage/production.sqlite3`.
