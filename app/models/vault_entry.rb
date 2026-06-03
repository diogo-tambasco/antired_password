# frozen_string_literal: true

require "envelope_encryption"

# VaultEntry — SPEC §5.1, §6.4.
#
# Cada segredo é guardado SÓ como ciphertext + nonce, cifrado com a DEK do
# usuário. `metadata` é JSON NÃO-secreto (url, username visível, projeto) e
# nunca deve conter o valor sensível. NÃO há validação de presença de
# ciphertext/nonce: a entry é criada antes de cifrar e cifrada em seguida.
class VaultEntry < ApplicationRecord
  belongs_to :user

  enum :kind, { login: 0, env: 1, secure_note: 2 }

  validates :name, presence: true

  # Cifra o valor com a DEK (gera nonce novo a cada chamada → re-editar produz
  # nonce diferente). Não persiste; o chamador faz save!.
  def encrypt_value(plaintext, dek)
    wrapped = EnvelopeEncryption.encrypt(plaintext, dek)
    self.ciphertext = wrapped[:ciphertext]
    self.nonce = wrapped[:nonce]
  end

  # Decifra o valor com a DEK. DEK/nonce errado ⇒ RbNaCl::CryptoError propaga
  # (não fazemos rescue: senha/chave errada não pode devolver lixo).
  def decrypt_value(dek)
    EnvelopeEncryption.decrypt(ciphertext, nonce, dek)
  end
end
