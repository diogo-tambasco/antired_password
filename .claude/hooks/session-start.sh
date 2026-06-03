#!/usr/bin/env bash
# session-start hook — prepara o ambiente do antired_password no início da sessão.
# Idempotente e NUNCA hard-fail (um hook que falha trava a sessão → tudo é || true + exit 0).
#
# Objetivo: garantir que sessões REMOTAS (Claude Code na web / headless) tenham
# libsodium + gems prontas pra rodar `bin/rails test`. Localmente o ambiente já
# está pronto (rbenv + libsodium via Homebrew), então aqui vira um no-op rápido.

cd "$(dirname "$0")/../.." 2>/dev/null || exit 0

# Só faz setup pesado no ambiente remoto.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# libsodium23 — exigida em runtime pelo rbnacl (argon2id + SecretBox).
if ! { ldconfig -p 2>/dev/null | grep -qi libsodium; }; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq >/dev/null 2>&1 || true
    sudo apt-get install -y --no-install-recommends libsodium23 >/dev/null 2>&1 || true
  fi
fi

# Garante as gems (bundle check é barato; só instala se faltar algo).
if command -v bundle >/dev/null 2>&1; then
  bundle check >/dev/null 2>&1 || bundle install >/dev/null 2>&1 || true
fi

exit 0
