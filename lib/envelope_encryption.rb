# frozen_string_literal: true

require "rbnacl"

# Núcleo criptográfico do cofre — SPEC.md §4.3.
#
# Módulo puro (sem estado, sem Rails). Envelope encryption zero-knowledge:
#
#   master password ──argon2id──▶ KEK ──SecretBox──▶ DEK ──SecretBox──▶ segredos
#
# Só usa primitivos do libsodium (rbnacl). Nada de hand-roll de cripto.
# Nenhuma função loga/printa/retorna KEK, DEK ou plaintext fora do retorno explícito.
module EnvelopeEncryption
  module_function

  # Parâmetros argon2id — FIXOS e determinísticos (SPEC §4.2).
  # Mudar isto significa não conseguir re-derivar KEKs existentes.
  OPSLIMIT    = RbNaCl::PasswordHash::Argon2::OPSLIMIT_MODERATE
  MEMLIMIT    = RbNaCl::PasswordHash::Argon2::MEMLIMIT_MODERATE
  DIGEST_SIZE = 32

  # Salt aleatório do argon2id (16 bytes), único por usuário.
  def generate_salt
    RbNaCl::Random.random_bytes(RbNaCl::PasswordHash::Argon2::SALTBYTES)
  end

  # Deriva a KEK (32 bytes) a partir da master password + salt.
  # Determinístico: mesma senha + mesmo salt ⇒ mesma KEK.
  def derive_kek(password, salt)
    RbNaCl::PasswordHash.argon2id(password, salt, OPSLIMIT, MEMLIMIT, DIGEST_SIZE)
  end

  # DEK aleatória (32 bytes) — a chave que realmente cifra os segredos.
  def generate_dek
    RbNaCl::Random.random_bytes(32)
  end

  # Cifra a DEK com a KEK (envelope). Bytes brutos de 32, sem header.
  def wrap_dek(dek, kek)
    box   = RbNaCl::SecretBox.new(kek)
    nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
    { ciphertext: box.encrypt(nonce, dek), nonce: nonce }
  end

  # Decifra a DEK. KEK errada ou ciphertext adulterado ⇒ RbNaCl::CryptoError
  # (a prova de senha correta é decifrar a DEK; nunca devolve lixo).
  def unwrap_dek(ciphertext, nonce, kek)
    RbNaCl::SecretBox.new(kek).decrypt(nonce, ciphertext)
  end

  # Cifra um valor com a DEK, preservando o encoding original do plaintext.
  # Header = nome do encoding + NUL separador + bytes do valor.
  def encrypt(plaintext, dek)
    payload = (plaintext.encoding.name + "\x00").b + plaintext.b
    box     = RbNaCl::SecretBox.new(dek)
    nonce   = RbNaCl::Random.random_bytes(box.nonce_bytes)
    { ciphertext: box.encrypt(nonce, payload), nonce: nonce }
  end

  # Decifra um valor e restaura o encoding original. DEK/nonce errado ou
  # ciphertext adulterado ⇒ RbNaCl::CryptoError (Poly1305).
  def decrypt(ciphertext, nonce, dek)
    payload = RbNaCl::SecretBox.new(dek).decrypt(nonce, ciphertext)
    i       = payload.index("\x00".b)
    name    = payload[0...i]
    bytes   = payload[(i + 1)..]
    bytes.force_encoding(name.to_s)
  end
end
