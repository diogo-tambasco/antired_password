# ROADMAP — antired_password

Pivot: cofre single-user → **cofre multiusuário self-hosted + skill `/antired`** (estilo
Doppler/1Password, open-source, Ruby on Rails, para uso pessoal e times pequenos).

Derivado de um design multi-agente com revisão adversarial de criptografia (2026-06-03).
Ordem deliberada: **valor pro próprio dono primeiro** (skill + `.env`), depois a base
cripto multiusuário, depois compartilhamento e convite.

---

## Visão

Cada dev tem um **vault pessoal**; admins criam **vaults compartilhados por projeto**, sem o
servidor nunca ler nada em repouso. A skill `/antired <projeto>` puxa os segredos direto pro
`.env` local via um **token revogável por dev**, sem digitar a master password. Tudo em cima do
envelope `KEK→DEK` atual; o multiusuário adiciona só keypairs Curve25519 (sealed box) — **zero
hand-roll de cripto**.

---

## Fases

### Fase 0 — Deploy do single-user (infra) — ⏳ PENDENTE
Subir o cofre atual em produção com TLS. Subdomínio DuckDNS → IP da VPS; `proxy.host` no
`deploy.yml`; `kamal setup`; backup cifrado (age + cron). Demo: `https://…` com cert válido,
signup/login/segredo no browser.

### Fase 1 — Projetos + export de `.env` (web) — ✅ FEITO
Model `Project` (pertence ao user, nome único); `vault_entries.project_id`; tela pra agrupar
segredos; importar `.env` colado (cada `KEY=VALUE` vira entry cifrada); montar o `.env` do
projeto na sessão web. **Sem cripto nova.** Demo: criar projeto "acta", importar `.env`, revelar
o `.env` decifrado. (Detalhe: a KEY do par é o `name` da entry `kind:env`.)

### Fase 2 — Skill `/antired` + token-por-dev — ✅ FEITO (com ressalva de escopo)
`AccessToken`: re-wrap da DEK por chave derivada do token (`argon2id(secret, salt)`), prova
por decrypt, `expires_at` (TTL) e revogação. API JSON `/api/v1` (Bearer): `projects#index`,
`projects/:name/env` (texto/json). CLI `skill/antired/` (`SKILL.md` + `antired`): grava `.env`
0600 + backup, recusa `http://` não-local, só reporta contagem. Demo (validada): `antired env
acta` grava o `.env`; token revogado/expirado → 401.

> ⚠️ **Ressalva de segurança (dívida consciente):** nesta entrega o token destrava a DEK, então
> lê o **cofre pessoal inteiro** — não só um projeto. O escopo **criptográfico por vault/projeto**
> (cada vault com sua própria chave, grant por token) depende das chaves por vault e entra na
> Fase 4. Documentado no UI de Tokens e no README da skill.

### Fase 3 — Keypair Curve25519 por usuário — ⏳ PENDENTE
Identidade criptográfica por user (`public_key` em claro + `private_key` wrapped pela KEK).
Pré-requisito de qualquer compartilhamento. `register` gera o par; `unlock` devolve `{dek, sk}`;
backfill lazy no login; `change_master_password` re-wrap só DEK+SK. Nota da revisão: usar
`RbNaCl::Boxes::Sealed.from_private_key` (não `from_keypair`, inexistente no rbnacl 7.x); a SK
nunca toca disco/`solid_cache` — só `MemoryStore`.

### Fase 4 — Vaults compartilhados (membros que já têm conta) — ⏳ PENDENTE
Models `Vault`/`VaultMembership`; VK aleatória por vault; segredos cifrados com a VK;
`sealed_vk = SealedBox(member.public_key)` por membro. **Fingerprint da pubkey exibido ao admin**
(anti-MITM — a revisão pegou que sem isso o servidor pode trocar a pubkey). `RotateVaultKey` =
revogação real (gera VK nova, re-cifra, re-sela, re-emite grants). Aqui o token-grant ganha
escopo cripto por vault (fecha a ressalva da Fase 2).

### Fase 5 — Convite por email — ⏳ PENDENTE
Convidar quem **ainda não tem conta** (o ovo-e-galinha de chave pública). `Invitation` com
claim-secret só no `#fragment` do link (nunca query/path/log); aceite atômico (`UPDATE … WHERE
status=0`, anti-race); TTL curto (72h); binding ao email; ao aceitar, o convidado re-sela a VK
pra própria pubkey e o wrap temporário é apagado. Precisa de remetente de email (ver decisões).

---

## Decisões em aberto (do dono)

- **D1 — Escopo do token:** aceitar a ressalva da Fase 2 (token = cofre pessoal inteiro até a
  Fase 4) ou priorizar o escopo cripto antes do multiusuário? (Recomendado: aceitar; é dívida
  documentada e a Fase 4 fecha.)
- **D2 — Remetente de email** (Fase 5): SMTP próprio na VPS vs serviço (Resend/Postmark). Precisa
  do domínio definido.
- **D3 — Vault pessoal reusa a DEK atual** ou ganha uma VK própria como os compartilhados?
  (Recomendado: reusar a DEK — menos migração.)

## Princípios de segurança (não negociáveis)
Nunca hand-roll cripto (rbnacl/libsodium). Master pw / KEK / DEK / SK / VK nunca em claro no
banco, log ou cookie. TLS obrigatório em produção. Token e `.env` tratados como senha (0600,
revogáveis). Backup do SQLite cifrado.
