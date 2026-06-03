# frozen_string_literal: true

# users — SPEC §5.1. Zero-knowledge: SEM password_digest/password_hash.
# A prova de senha é decifrar a DEK (encrypted_dek) com a KEK derivada da
# master password + master_salt.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.binary :master_salt, null: false
      t.binary :encrypted_dek, null: false
      t.binary :encrypted_dek_nonce, null: false

      t.timestamps
    end

    add_index :users, :email_address, unique: true
  end
end
