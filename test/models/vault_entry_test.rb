# frozen_string_literal: true

# VaultEntry model — SPEC.md §5.1, §6.4.
# Contrato: valor cifrado com a DEK; metadata nunca contém o segredo; enum kind.

require "test_helper"

class VaultEntryTest < ActiveSupport::TestCase
  MASTER = "master de teste vault"
  SECRET = "sk-live-deadbeef-0000-1111"

  setup do
    @user = User.register(email_address: "vault@exemplo.com", master_password: MASTER)
    @dek  = @user.unlock(MASTER)
  end

  # ---- associação e validações (SPEC §5.1) -----------------------------------

  test "pertence a um usuário" do
    entry = VaultEntry.new
    refute entry.valid?
    assert entry.errors[:user].present?
  end

  test "name é obrigatório" do
    entry = @user.vault_entries.new(kind: :login)
    refute entry.valid?
    assert entry.errors[:name].present?
  end

  test "kind aceita login, env e secure_note" do
    %i[login env secure_note].each do |k|
      entry = @user.vault_entries.new(name: "x", kind: k)
      entry.encrypt_value(SECRET, @dek)
      assert entry.valid?, "kind #{k} deveria ser válido"
    end
  end

  # ---- cifragem do valor (SPEC §6.4) -----------------------------------------

  test "encrypt_value preenche ciphertext e nonce" do
    entry = @user.vault_entries.new(name: "Acta Supabase", kind: :env)
    entry.encrypt_value(SECRET, @dek)
    assert entry.ciphertext.present?
    assert entry.nonce.present?
  end

  test "round-trip: decrypt_value devolve o valor original" do
    entry = @user.vault_entries.create!(name: "Acta Supabase", kind: :env).tap do |e|
      e.encrypt_value(SECRET, @dek)
      e.save!
    end
    assert_equal SECRET, entry.reload.decrypt_value(@dek)
  end

  test "ciphertext NÃO contém o plaintext" do
    entry = @user.vault_entries.new(name: "x", kind: :login)
    entry.encrypt_value(SECRET, @dek)
    refute_includes entry.ciphertext, SECRET
  end

  test "decrypt_value com DEK errada levanta" do
    entry = @user.vault_entries.new(name: "x", kind: :login)
    entry.encrypt_value(SECRET, @dek)
    outra_dek = EnvelopeEncryption.generate_dek
    assert_raises(RbNaCl::CryptoError) { entry.decrypt_value(outra_dek) }
  end

  # ---- metadata é não-secreta (SPEC §5.1) ------------------------------------

  test "metadata guarda dados não-secretos e nunca o valor" do
    entry = @user.vault_entries.new(
      name: "Login Acta", kind: :login,
      metadata: { "url" => "https://acta.app", "username" => "diogo" }
    )
    entry.encrypt_value(SECRET, @dek)
    entry.save!
    assert_equal "diogo", entry.reload.metadata["username"]
    refute_includes entry.metadata.to_json, SECRET, "metadata não pode vazar o segredo"
  end

  test "re-editar o valor usa novo nonce" do
    entry = @user.vault_entries.new(name: "x", kind: :login)
    entry.encrypt_value(SECRET, @dek)
    nonce_antigo = entry.nonce.dup
    entry.encrypt_value("novo-valor", @dek)
    refute_equal nonce_antigo, entry.nonce
  end
end
