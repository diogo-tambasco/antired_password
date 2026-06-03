# frozen_string_literal: true

# CRUD de segredos com DEK em sessão — SPEC.md §6.4, §7.

require "test_helper"

class VaultEntriesFlowTest < ActionDispatch::IntegrationTest
  MASTER = "master do cofre teste"
  SECRET = "super-secret-token-xyz"

  setup do
    @user = User.register(email_address: "cofre@exemplo.com", master_password: MASTER)
    post session_path, params: { email_address: @user.email_address, master_password: MASTER }
  end

  test "deslogado não acessa o cofre" do
    delete session_path
    get vault_entries_path
    assert_redirected_to login_path
  end

  test "criar segredo cifra o valor e lista pelo nome" do
    assert_difference -> { VaultEntry.count }, 1 do
      post vault_entries_path, params: {
        vault_entry: { name: "Acta Supabase", kind: "env",
                       metadata: { project: "acta" }, value: SECRET }
      }
    end
    get vault_entries_path
    assert_response :success
    assert_includes response.body, "Acta Supabase"   # nome aparece
    refute_includes response.body, SECRET             # valor NÃO aparece na listagem
  end

  test "ver um segredo decifra com a DEK da sessão" do
    entry = create_entry
    get vault_entry_path(entry)
    assert_response :success
    assert_includes response.body, SECRET
  end

  test "valor cifrado no banco nunca é o plaintext" do
    entry = create_entry
    refute_includes entry.reload.ciphertext.to_s, SECRET
  end

  test "editar re-cifra o valor" do
    entry = create_entry
    patch vault_entry_path(entry), params: { vault_entry: { value: "novo-valor-999" } }
    assert_equal "novo-valor-999", entry.reload.decrypt_value(@user.unlock(MASTER))
  end

  test "apagar remove o segredo" do
    entry = create_entry
    assert_difference -> { VaultEntry.count }, -1 do
      delete vault_entry_path(entry)
    end
  end

  test "um usuário não acessa segredo de outro" do
    outro = User.register(email_address: "outro@exemplo.com", master_password: "outra master")
    alheio = outro.vault_entries.create!(name: "alheio", kind: :login).tap do |e|
      e.encrypt_value("nao-pode-ver", outro.unlock("outra master")); e.save!
    end
    get vault_entry_path(alheio)
    assert_response :not_found
  end

  private

  def create_entry
    post vault_entries_path, params: {
      vault_entry: { name: "Acta Supabase", kind: "env", value: SECRET }
    }
    VaultEntry.order(:created_at).last
  end
end
