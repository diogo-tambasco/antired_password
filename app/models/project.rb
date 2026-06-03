# frozen_string_literal: true

# Project — agrupa segredos pra exportar como .env (skill /antired).
# Não-secreto: só o nome. Os valores continuam cifrados nas vault_entries.
class Project < ApplicationRecord
  belongs_to :user
  has_many :vault_entries, dependent: :nullify

  normalizes :name, with: ->(n) { n.to_s.strip }

  validates :name,
            presence: true,
            uniqueness: { scope: :user_id, case_sensitive: false }

  # Pares [KEY, VALUE] das entries kind:env, decifrados com a DEK em runtime.
  # Só entries env viram variáveis de ambiente; login/secure_note ficam de fora.
  def env_pairs(dek)
    vault_entries.env.order(:name).map { |e| [e.name, e.decrypt_value(dek)] }
  end
end
