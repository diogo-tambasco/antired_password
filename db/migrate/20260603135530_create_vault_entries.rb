# frozen_string_literal: true

# vault_entries — SPEC §5.1. Cada segredo: valor cifrado com a DEK
# (ciphertext + nonce). metadata é JSON NÃO-secreto (url, username visível).
class CreateVaultEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :vault_entries do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name
      t.integer :kind, null: false, default: 0
      t.json :metadata, default: {}
      t.binary :ciphertext
      t.binary :nonce

      t.timestamps
    end
  end
end
