# frozen_string_literal: true

# Invariantes de segurança — SPEC.md §3.
# Estes testes existem pra que regressões de segurança QUEBREM o build.

require "test_helper"

class SecurityInvariantsTest < ActionDispatch::IntegrationTest
  MASTER = "master invariantes"
  SECRET = "valor-altamente-confidencial-42"

  setup do
    @user = User.register(email_address: "inv@exemplo.com", master_password: MASTER)
  end

  # ---- banco em repouso é opaco (SPEC §3) ------------------------------------

  test "o arquivo/linhas do banco não contêm a master password nem o segredo em claro" do
    dek = @user.unlock(MASTER)
    entry = @user.vault_entries.create!(name: "n", kind: :env).tap do |e|
      e.encrypt_value(SECRET, dek); e.save!
    end

    # varre todo o conteúdo bruto das tabelas — nada de plaintext deve aparecer
    users_dump  = User.connection.select_all("SELECT * FROM users").rows.flatten.map(&:to_s).join(" ")
    vault_dump  = VaultEntry.connection.select_all("SELECT * FROM vault_entries").rows.flatten.map(&:to_s).join(" ")
    dump = "#{users_dump} #{vault_dump}"

    refute_includes dump, MASTER, "master password não pode estar no banco"
    refute_includes dump, SECRET, "segredo não pode estar em claro no banco"
    assert entry.ciphertext.present?
  end

  # ---- nada de segredo nos logs (SPEC §3 invariante 1) -----------------------

  test "nenhum segredo aparece nos logs durante signup/login/criação" do
    log = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    begin
      u = User.register(email_address: "log@exemplo.com", master_password: MASTER)
      post session_path, params: { email_address: u.email_address, master_password: MASTER }
      post vault_entries_path, params: { vault_entry: { name: "n", kind: "env", value: SECRET } }
    ensure
      Rails.logger = original
    end
    refute_includes log.string, MASTER, "master password vazou no log"
    refute_includes log.string, SECRET, "segredo vazou no log"
  end

  # ---- params sensíveis filtrados (SPEC §3) ----------------------------------

  test "master_password e value estão na lista de filtered_parameters" do
    filtros = Rails.application.config.filter_parameters.map(&:to_s)
    assert_includes filtros, "master_password"
    assert_includes filtros, "value"
  end

  # ---- DEK não persiste em claro em lugar nenhum -----------------------------

  test "encrypted_dek é diferente da DEK em claro" do
    dek = @user.unlock(MASTER)
    refute_equal dek, @user.encrypted_dek, "a DEK salva tem que estar CIFRADA"
  end
end
