# frozen_string_literal: true

# User model — SPEC.md §5.1, §6.1–6.2.
# Contrato: registro gera envelope; unlock prova senha por decrypt; SEM hash de senha.

require "test_helper"

class UserTest < ActiveSupport::TestCase
  MASTER = "uma master forte de teste"
  WRONG  = "senha errada qualquer"

  # ---- registro (SPEC §6.1) --------------------------------------------------

  test "register cria usuário com envelope preenchido" do
    user = User.register(email_address: "novo@exemplo.com", master_password: MASTER)
    assert user.persisted?
    assert user.master_salt.present?
    assert user.encrypted_dek.present?
    assert user.encrypted_dek_nonce.present?
  end

  test "register NÃO persiste a master password nem a KEK/DEK em claro" do
    user = User.register(email_address: "claro@exemplo.com", master_password: MASTER)
    row = User.connection.select_one("SELECT * FROM users WHERE id = #{user.id}")
    serialized = row.values.map(&:to_s).join(" ")
    refute_includes serialized, MASTER, "master password não pode aparecer no banco"
  end

  test "User não tem coluna de hash de senha" do
    # A prova de senha é decifrar a DEK (SPEC §3 invariante 2); não existe digest separado.
    cols = User.column_names
    refute_includes cols, "password_digest"
    refute_includes cols, "password_hash"
  end

  # ---- unlock / login-por-decrypt (SPEC §6.2) --------------------------------

  test "unlock com a senha certa devolve a DEK" do
    user = User.register(email_address: "ok@exemplo.com", master_password: MASTER)
    dek = user.unlock(MASTER)
    assert_equal 32, dek.bytesize
  end

  test "unlock é estável: mesma senha sempre devolve a MESMA DEK" do
    user = User.register(email_address: "estavel@exemplo.com", master_password: MASTER)
    assert_equal user.unlock(MASTER), user.reload.unlock(MASTER)
  end

  test "unlock com senha errada levanta InvalidPassword e nunca devolve lixo" do
    user = User.register(email_address: "ruim@exemplo.com", master_password: MASTER)
    assert_raises(User::InvalidPassword) { user.unlock(WRONG) }
  end

  # ---- validações (SPEC §5.1) ------------------------------------------------

  test "email é obrigatório" do
    u = User.new
    refute u.valid?
    assert u.errors[:email_address].present?
  end

  test "email é único case-insensitive" do
    User.register(email_address: "dup@exemplo.com", master_password: MASTER)
    assert_raises(ActiveRecord::RecordInvalid) do
      User.register(email_address: "DUP@Exemplo.com", master_password: MASTER)
    end
  end

  test "email com formato inválido é rejeitado" do
    u = User.new(email_address: "não-é-email")
    refute u.valid?
    assert u.errors[:email_address].present?
  end
end
