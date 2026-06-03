# frozen_string_literal: true

# Projetos (agrupam segredos p/ export .env) + tokens de acesso da skill /antired.
class AddProjectsAndAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :projects, [:user_id, :name], unique: true

    # Segredo pode pertencer a um projeto (nullable: entry "solta" continua válida).
    add_reference :vault_entries, :project, null: true, foreign_key: true

    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false                  # rótulo do dispositivo/dev
      t.string :public_id, null: false             # parte pública do token (lookup)
      t.binary :token_salt, null: false            # salt argon2id p/ derivar a token-key
      t.binary :encrypted_dek, null: false         # DEK cifrada com a token-key
      t.binary :encrypted_dek_nonce, null: false
      t.datetime :last_used_at
      t.datetime :expires_at                       # TTL opcional (nil = nunca expira)
      t.timestamps
    end
    add_index :access_tokens, :public_id, unique: true
  end
end
