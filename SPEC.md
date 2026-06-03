# SPEC — antired_password

> Especificação técnica do **antired_password**: um gerenciador de senhas / cofre de
> credenciais self-hosted, com criptografia **zero-knowledge em repouso** (envelope KEK→DEK).
> Este documento é o **contrato** que a implementação e a suíte de testes (`test/`) devem cumprir.
>
> Status: **app ainda não scaffoldada**. Esta SPEC + a pasta `test/` definem o comportamento
> esperado. Os testes ficam "vermelhos" até a implementação existir (ver `test/README.md`).

---

## 1. Objetivo

Um cofre onde **o servidor, em repouso, não consegue ler nenhum segredo sem a master password**.

- Substituir o vai-e-vem de `.env` perdido entre devs.
- Não depender de cofre de terceiros (1Password etc).
- Self-hosted numa VPS controlada pelo dono, instância única.

### 1.1 O que é (escopo do MVP)

- Cadastro/login de usuário com master password.
- Guardar segredos cifrados de 3 tipos: `login`, `env`, `secure_note`.
- Listar, criar, ver (decifrar em sessão), editar e apagar segredos.
- Rate limit no login (anti brute-force).
- Deploy via Kamal 2 com TLS.

### 1.2 O que NÃO é (fora do MVP)

- Não é end-to-end encryption. É **zero-knowledge em repouso** (ver Threat Model §3).
- Sem compartilhamento entre usuários (re-wrap de DEK por usuário) — futuro.
- Sem pastas/projetos para agrupar — futuro.
- Sem audit log de acessos — futuro.
- Sem recuperação de master password: **se perder a master, perde o cofre** (by design).
- Sem app mobile nativo; só web (Hotwire).

---

## 2. Stack

| Camada | Escolha |
|--------|---------|
| Runtime | Ruby 3.3+ (dev atual: **4.0.5** via rbenv) |
| Framework | Rails **8.x** (atual: 8.1.3) |
| Banco | SQLite (Solid Queue/Cache/Cable em SQLite, default Rails 8) |
| Auth | gerador nativo Rails 8 (`bin/rails generate authentication`), adaptado p/ login-por-decrypt |
| Cripto | `rbnacl` (libsodium): argon2id (KDF) + SecretBox (AEAD XSalsa20-Poly1305) |
| Rate limit | `rack-attack` |
| Front | Hotwire (Turbo + Stimulus), importmap |
| Testes | **Minitest** (default Rails 8) |
| Deploy | Kamal 2 + Docker + kamal-proxy (TLS via Let's Encrypt) |

`rbnacl` exige libsodium no sistema/imagem (`libsodium23` ou `libsodium-dev` no Dockerfile).

---

## 3. Threat Model (postura de segurança honesta)

### Protege contra

- **Vazamento do banco em repouso.** Um atacante que rouba o arquivo SQLite (ou um backup)
  não consegue ler nenhum `ciphertext` sem a master password. O banco sozinho é inútil.
- **Senha fraca de cofre acelerada por hardware.** argon2id encarece cada tentativa de KDF.
- **Brute-force online no login.** `rack-attack` limita tentativas por IP/conta.

### NÃO protege contra (assumido e aceito)

- **Servidor comprometido durante uma sessão ativa.** Durante a sessão, o servidor manipula
  plaintext em memória (necessário pra exibir segredos no Hotwire). Root na máquina = leitura
  do que estiver descifrado naquele momento.
- **Master password fraca + cópia offline do banco** dada KDF mal configurada. Mitigado por
  parâmetros fortes de argon2id (§4.2).
- **Phishing / keylogger no cliente.** Fora do escopo de um cofre self-hosted single-instance.

### Invariantes inegociáveis

1. Master password, KEK e DEK em claro **nunca** vão pro banco, log, ou cookie não-cifrado.
2. **Não existe hash de senha separado.** A prova de senha correta é conseguir decifrar a DEK.
3. **TLS obrigatório** em produção.
4. Backup do SQLite só sai da VPS **cifrado**.
5. Nenhum endpoint vaza, em erro ou log, o conteúdo de `ciphertext`/`metadata` sensível.

---

## 4. Modelo de criptografia (o coração)

Envelope encryption. A chave deriva da master password e **nunca** é persistida.

```
master password (usuário; nunca salva, nunca logada)
   │  argon2id (salt único por usuário)
   ▼
KEK  (key-encrypting key, 32 bytes, derivada em runtime, nunca salva)
   │  SecretBox encrypt/decrypt
   ▼
DEK  (data-encrypting key, 32 bytes aleatória) ── salva CIFRADA (encrypted_dek + nonce)
   │  SecretBox encrypt
   ▼
secrets (valores) ── salvos só como ciphertext + nonce
```

**Por que envelope:** trocar a master password só re-encripta a DEK (1 operação), não os N
segredos. E o banco sozinho não decifra nada.

### 4.1 Primitivos (rbnacl / libsodium)

- **KDF:** `RbNaCl::PasswordHash.argon2id(password, salt, opslimit, memlimit, digest_size)`
  → produz a KEK (32 bytes).
- **AEAD:** `RbNaCl::SecretBox` (XSalsa20-Poly1305) para wrap/unwrap da DEK e cifragem dos
  valores. Cada cifragem usa um **nonce novo aleatório** (`RbNaCl::Random.random_bytes`).
- **Aleatoriedade:** sempre `RbNaCl::Random.random_bytes` (CSPRNG).
- **Nunca hand-roll cripto.** Só os primitivos do libsodium acima.

### 4.2 Parâmetros argon2id

- `digest_size`: **32 bytes** (tamanho de chave do SecretBox).
- `salt`: `RbNaCl::PasswordHash::Argon2::SALTBYTES` bytes (16), único por usuário, aleatório.
- `opslimit`/`memlimit`: no mínimo os presets `:moderate`; preferir `:sensitive` se a VPS aguentar.
  Os parâmetros usados **devem ser estáveis** (ou versionados) — mudar significa não conseguir
  re-derivar a KEK. Se evoluírem, persistir a versão/params junto ao usuário.

### 4.3 Contrato do módulo `EnvelopeEncryption`

Módulo puro (sem estado, sem Rails), testável isoladamente. API esperada:

```ruby
EnvelopeEncryption.generate_salt            # => String binária (SALTBYTES)
EnvelopeEncryption.derive_kek(password, salt) # => 32 bytes; determinístico p/ mesmos inputs
EnvelopeEncryption.generate_dek             # => 32 bytes aleatórios
EnvelopeEncryption.wrap_dek(dek, kek)       # => { ciphertext:, nonce: }
EnvelopeEncryption.unwrap_dek(ciphertext, nonce, kek) # => dek; raise InvalidKey se KEK errada
EnvelopeEncryption.encrypt(plaintext, dek)  # => { ciphertext:, nonce: }
EnvelopeEncryption.decrypt(ciphertext, nonce, dek)   # => plaintext; raise se adulterado
```

**Propriedades que os testes garantem:**

- `derive_kek` é determinístico: mesma senha + mesmo salt ⇒ mesma KEK.
- Salt diferente ⇒ KEK diferente (mesma senha).
- `wrap_dek` produz nonce diferente a cada chamada (mesma DEK/KEK ⇒ ciphertext diferente).
- `unwrap_dek` com KEK correta devolve a DEK original; com KEK errada **levanta erro** (MAC falha),
  nunca devolve lixo silenciosamente.
- `encrypt`/`decrypt` é round-trip exato, inclusive UTF-8 e binário.
- `decrypt` com ciphertext/nonce adulterado **levanta erro** (autenticação Poly1305).
- Nenhuma função retorna ou loga KEK/DEK/plaintext fora do valor de retorno explícito.

---

## 5. Modelo de dados

```
users
  id
  email_address        (string, unique, case-insensitive)
  master_salt          (binary; salt do argon2id)
  encrypted_dek        (binary; DEK cifrada com a KEK)
  encrypted_dek_nonce  (binary)
  created_at / updated_at

vault_entries
  id
  user_id              (FK -> users)
  name                 (string NÃO-secreto; título, ex. "Acta Supabase service key")
  kind                 (integer enum: login=0 | env=1 | secure_note=2)
  metadata             (JSON NÃO-secreto: url, username visível, projeto)
  ciphertext           (binary; valor cifrado com a DEK)
  nonce                (binary)
  created_at / updated_at
```

### 5.1 Regras dos models

**User**
- `email_address`: presente, único (case-insensitive), formato de email válido.
- `master_salt`, `encrypted_dek`, `encrypted_dek_nonce`: presentes (preenchidos no registro).
- **Não tem** coluna de password/password_digest. Correção de senha = decifrar a DEK.
- `User.register(email_address:, master_password:)`:
  gera salt → deriva KEK → gera DEK → salva `encrypted_dek` = wrap(DEK, KEK). Não salva KEK/DEK.
- `user.unlock(master_password)`: deriva KEK do `master_salt` e tenta `unwrap_dek`.
  Sucesso ⇒ devolve a DEK (em memória). Falha ⇒ levanta `InvalidPassword` (nunca devolve nil/lixo).

**VaultEntry**
- `belongs_to :user`.
- `name`: presente. `kind`: enum válido (login/env/secure_note).
- `metadata`: JSON, opcional, **nunca contém o valor secreto**.
- `ciphertext` + `nonce`: presentes.
- `entry.encrypt_value(plaintext, dek)`: preenche `ciphertext`/`nonce`.
- `entry.decrypt_value(dek)`: devolve o plaintext; com DEK errada, levanta erro.

---

## 6. Fluxos

### 6.1 Signup
1. Recebe `email_address` + `master_password`.
2. Valida email; rejeita duplicado.
3. `master_salt = generate_salt`; `kek = derive_kek(pw, salt)`; `dek = generate_dek`.
4. Salva user com `encrypted_dek = wrap_dek(dek, kek)`.
5. Abre sessão (DEK em sessão cifrada do servidor). **Nunca** persiste KEK/DEK em claro.

### 6.2 Login (verificação por decrypt)
1. Recebe `email_address` + `master_password`.
2. Acha o user; deriva `kek` do `master_salt`.
3. `unwrap_dek(encrypted_dek, nonce, kek)`:
   - MAC valida ⇒ senha correta ⇒ DEK na sessão.
   - MAC falha ⇒ credenciais inválidas (mensagem genérica, sem distinguir email-inexistente de
     senha-errada além do necessário; timing aceitável dado argon2id).

### 6.3 Sessão
- Após login, a DEK vive **só durante a sessão ativa**, em store de sessão cifrado do servidor
  (necessário pra Hotwire exibir segredos). Logout/expiração ⇒ DEK descartada.
- Em repouso (sem sessão), nada é decifrável.

### 6.4 CRUD de segredos
- **Criar:** `name`+`kind`+`metadata` em claro; `value` cifrado com a DEK da sessão.
- **Ver:** decifra `ciphertext` com a DEK da sessão e renderiza (Turbo).
- **Editar:** re-cifra o valor com novo nonce.
- **Apagar:** remove a linha.
- Sem DEK na sessão (deslogado) ⇒ 401/redirect login; nunca tenta decifrar.

### 6.5 Troca de master password (futuro próximo)
- Deriva KEK antiga (valida), deriva KEK nova do novo salt, re-wrap só da DEK. Os N segredos
  não são tocados.

---

## 7. Rotas / superfície HTTP (esperada)

| Método | Caminho | Ação |
|--------|---------|------|
| GET | `/signup` | form de cadastro |
| POST | `/signup` | cria user, abre sessão |
| GET | `/session/new` (`/login`) | form de login |
| POST | `/session` | login-por-decrypt |
| DELETE | `/session` | logout (descarta DEK) |
| GET | `/vault_entries` | lista (nomes/metadata, sem valor) |
| GET | `/vault_entries/:id` | mostra valor decifrado (requer DEK em sessão) |
| GET | `/vault_entries/new` | form |
| POST | `/vault_entries` | cria (cifra valor) |
| GET | `/vault_entries/:id/edit` | form de edição |
| PATCH/PUT | `/vault_entries/:id` | atualiza (re-cifra) |
| DELETE | `/vault_entries/:id` | apaga |

Toda rota de `vault_entries` exige sessão autenticada **com DEK presente**.

---

## 8. Rate limiting (rack-attack)

- Limite de tentativas de `POST /session` por IP e por `email_address` (ex.: 5 / 20s, depois
  backoff). Resposta `429` ao estourar.
- argon2id já encarece cada tentativa; rack-attack corta volume.
- Throttle não deve vazar se o email existe ou não.

---

## 9. Estratégia de testes (Minitest)

A pasta `test/` é a especificação executável desta SPEC. Cobertura mínima:

- `test/lib/envelope_encryption_test.rb` — o núcleo cripto (§4.3). **O mais importante.**
- `test/models/user_test.rb` — registro, unlock, validações, ausência de hash de senha (§5.1).
- `test/models/vault_entry_test.rb` — cifragem/decifragem de valor, enum, metadata sem segredo.
- `test/integration/registration_test.rb` — fluxo de signup (§6.1).
- `test/integration/login_test.rb` — login-por-decrypt, senha errada (§6.2).
- `test/integration/vault_entries_flow_test.rb` — CRUD com DEK em sessão (§6.4).
- `test/integration/rate_limiting_test.rb` — rack-attack (§8).
- `test/integration/security_invariants_test.rb` — banco em repouso não revela nada; sem
  plaintext/segredo em log (§3 invariantes).

Princípios:
- Testar **propriedades de segurança**, não só caminho feliz: KEK errada levanta, ciphertext
  adulterado levanta, banco em repouso é opaco.
- Nunca commitar segredos reais nos fixtures.
- Rodar com `bin/rails test` depois que a app existir.

---

## 10. Deploy (resumo — detalhes e credenciais no CLAUDE.md gitignored)

- Kamal 2: `kamal setup` (1ª vez) → `kamal deploy`.
- Volume persistente pro SQLite (`antired_storage:/rails/storage`) — senão o banco some a cada deploy.
- TLS via kamal-proxy + Let's Encrypt ⇒ **precisa de subdomínio** apontando pro IP da VPS.
- Backup: cron copiando o SQLite **cifrado** pra fora da VPS.
- Pós-primeiro-deploy: trocar senha root por chave SSH, desabilitar password auth.

> ⚠️ As credenciais reais da VPS (host/usuário/senha root) vivem **só** no `CLAUDE.md`, que está
> no `.gitignore` e **não** é versionado. Esta SPEC e o repositório público nunca as contêm.

---

## 11. Pendências de implementação (ordem sugerida)

1. `rails new . --force` (SQLite + Hotwire + importmap) preservando `CLAUDE.md`/`.gitignore`/`SPEC.md`/`test/`.
2. Gems: `rbnacl`, `rack-attack`.
3. `EnvelopeEncryption` (§4.3) → faz `test/lib/...` passar.
4. Migrations + models `User`/`VaultEntry` (§5) → faz `test/models/...` passar.
5. Auth nativo adaptado pra login-por-decrypt + sessão com DEK (§6).
6. Controllers/views Hotwire de `vault_entries` (§7).
7. `rack-attack` no login (§8).
8. Subdomínio + DNS, `config/deploy.yml`, `kamal setup`.
9. Backup cifrado + endurecimento SSH da VPS.
