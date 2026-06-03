# frozen_string_literal: true

require "envelope_encryption"

# AccessToken — destrava o cofre pra skill /antired SEM master password.
#
# A DEK é re-encriptada com uma "token-key" derivada (argon2id) da parte secreta
# do token — o MESMO envelope da master password, só que a "senha" é um token de
# alta entropia. O servidor guarda só a DEK cifrada; o token em claro vive no
# disco do dev. Revogar = apagar a linha. Prova de token válido = decifrar a DEK
# (MAC), igual ao login-por-decrypt — token errado nunca devolve lixo.
#
# Formato do token: "antp_<public_id>_<secret>"
#   public_id → lookup no banco (não-secreto, indexado)
#   secret    → deriva a token-key; NUNCA é persistido
#
# NOTA DE ESCOPO (Phase 1): um token destrava a DEK, então dá acesso de leitura a
# TODO o cofre pessoal — não só a um projeto. Escopo por projeto exige chave por
# projeto (vaults compartilhados, Phase 2).
class AccessToken < ApplicationRecord
  class Invalid < StandardError; end

  PREFIX = "antp"

  belongs_to :user

  normalizes :name, with: ->(n) { n.to_s.strip }
  validates :name, :public_id, :token_salt, :encrypted_dek, :encrypted_dek_nonce, presence: true

  # Emite um token novo a partir da DEK em claro (precisa estar destrancado).
  # Retorna [registro, token_string]. O token_string só existe aqui — mostrado
  # UMA vez pro dev e nunca mais recuperável.
  def self.issue!(user:, dek:, name:, expires_at: nil)
    public_id = SecureRandom.alphanumeric(16)
    secret    = SecureRandom.urlsafe_base64(32)
    salt      = EnvelopeEncryption.generate_salt
    token_key = EnvelopeEncryption.derive_kek(secret, salt)
    wrapped   = EnvelopeEncryption.wrap_dek(dek, token_key)

    record = create!(
      user: user, name: name, public_id: public_id, token_salt: salt,
      encrypted_dek: wrapped[:ciphertext], encrypted_dek_nonce: wrapped[:nonce],
      expires_at: expires_at
    )
    [record, "#{PREFIX}_#{public_id}_#{secret}"]
  end

  # Resolve um token_string → [user, dek]. Invalid se prefixo/lookup/MAC falham.
  def self.unlock(token_string)
    prefix, public_id, secret = token_string.to_s.split("_", 3)
    raise Invalid unless prefix == PREFIX && public_id.present? && secret.present?

    token = find_by(public_id: public_id)
    raise Invalid unless token
    raise Invalid if token.expired?

    dek = token.unwrap_dek(secret)
    token.update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    [token.user, dek]
  end

  # Decifra a DEK com a token-key derivada do secret. Secret errado ⇒ Invalid.
  def unwrap_dek(secret)
    token_key = EnvelopeEncryption.derive_kek(secret, token_salt)
    EnvelopeEncryption.unwrap_dek(encrypted_dek, encrypted_dek_nonce, token_key)
  rescue RbNaCl::CryptoError
    raise Invalid
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
