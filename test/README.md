# test/ — suíte de testes do antired_password

Esta pasta é a **especificação executável** da `SPEC.md`. Cada arquivo traduz uma seção da SPEC
em testes Minitest concretos.

## ⚠️ Estado atual: vermelho (esperado)

A aplicação Rails **ainda não foi scaffoldada** e o código de produção (`EnvelopeEncryption`,
`User`, `VaultEntry`, controllers) **ainda não existe**. Portanto, ao rodar agora, os testes
vão **falhar/erro de carregamento** — isso é esperado e proposital. Eles são o contrato a cumprir.

Eles ficam verdes conforme a implementação avança, na ordem da `SPEC.md` §11.

## Como rodar (depois que a app existir)

```bash
# 1. scaffold da app preservando estes arquivos
rails new . --force        # mantém CLAUDE.md, .gitignore, SPEC.md e test/

# 2. adicionar as gems (Gemfile): rbnacl, rack-attack
bundle install

# 3. rodar a suíte
bin/rails test                       # tudo
bin/rails test test/lib              # só o núcleo cripto (o mais importante)
bin/rails test test/models
bin/rails test test/integration
```

Antes da app existir, dá pra rodar **só o teste de cripto puro** de forma isolada (ele não
depende de Rails, só de `rbnacl` + a classe `EnvelopeEncryption`), assim que essa classe for criada:

```bash
ruby -Itest test/lib/envelope_encryption_test.rb
```

## Mapa arquivo → seção da SPEC

| Arquivo | SPEC | O que cobre |
|---------|------|-------------|
| `lib/envelope_encryption_test.rb` | §4.3 | núcleo cripto: KDF determinística, wrap/unwrap, AEAD, adulteração |
| `models/user_test.rb` | §5.1, §6.1–6.2 | register, unlock, validações, ausência de hash de senha |
| `models/vault_entry_test.rb` | §5.1, §6.4 | cifragem de valor, enum kind, metadata sem segredo |
| `integration/registration_test.rb` | §6.1 | fluxo de signup |
| `integration/login_test.rb` | §6.2 | login-por-decrypt + senha errada |
| `integration/vault_entries_flow_test.rb` | §6.4, §7 | CRUD de segredos com DEK em sessão |
| `integration/rate_limiting_test.rb` | §8 | rack-attack no login |
| `integration/security_invariants_test.rb` | §3 | banco em repouso opaco; sem plaintext em log |

## Princípios

- Testar **propriedades de segurança**, não só caminho feliz (KEK errada levanta, ciphertext
  adulterado levanta, banco em repouso é ilegível).
- **Nunca** colocar segredos reais nos fixtures/tests. As senhas aqui são de brinquedo.
- Master password / KEK / DEK em claro nunca aparecem em asserção de log.
