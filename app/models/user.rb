# frozen_string_literal: true

require "envelope_encryption"

# User — SPEC §5.1, §6.1–6.2.
#
# Zero-knowledge: NÃO existe hash de senha. A prova de que a master password
# está correta é conseguir decifrar a DEK (encrypted_dek) com a KEK derivada
# da master password + master_salt (argon2id). KEK e DEK em claro NUNCA são
# persistidas, logadas ou retornadas acidentalmente.
class User < ApplicationRecord
  # Levantada quando o unlock falha (master password errada → MAC inválido).
  class InvalidPassword < StandardError; end

  has_many :vault_entries, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :master_salt, :encrypted_dek, :encrypted_dek_nonce, presence: true

  # Signup (SPEC §6.1): gera salt → deriva KEK → gera DEK aleatória → salva a
  # DEK CIFRADA (envelope). Nunca persiste KEK nem DEK em claro.
  def self.register(email_address:, master_password:)
    salt = EnvelopeEncryption.generate_salt
    kek  = EnvelopeEncryption.derive_kek(master_password, salt)
    dek  = EnvelopeEncryption.generate_dek
    wrapped = EnvelopeEncryption.wrap_dek(dek, kek)

    create!(
      email_address: email_address,
      master_salt: salt,
      encrypted_dek: wrapped[:ciphertext],
      encrypted_dek_nonce: wrapped[:nonce]
    )
  end

  # Login-por-decrypt (SPEC §6.2): deriva a KEK e tenta decifrar a DEK.
  # MAC válido ⇒ senha correta, devolve a DEK (32 bytes, sempre a mesma para
  # a mesma senha). MAC inválido ⇒ InvalidPassword (nunca devolve lixo).
  def unlock(master_password)
    kek = EnvelopeEncryption.derive_kek(master_password, master_salt)
    EnvelopeEncryption.unwrap_dek(encrypted_dek, encrypted_dek_nonce, kek)
  rescue RbNaCl::CryptoError
    raise InvalidPassword
  end
end
