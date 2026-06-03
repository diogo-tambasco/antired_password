# frozen_string_literal: true

# Login-por-decrypt — SPEC.md §6.2, §7.

require "test_helper"

class LoginTest < ActionDispatch::IntegrationTest
  MASTER = "master de login teste"
  WRONG  = "essa nao eh a senha"

  setup do
    @user = User.register(email_address: "login@exemplo.com", master_password: MASTER)
  end

  test "GET /login renderiza o formulário" do
    get login_path
    assert_response :success
  end

  test "login com a senha certa entra e redireciona pro cofre" do
    post session_path, params: { email_address: @user.email_address, master_password: MASTER }
    assert_redirected_to vault_entries_path
  end

  test "login com senha errada falha sem abrir sessão" do
    post session_path, params: { email_address: @user.email_address, master_password: WRONG }
    assert_response :unprocessable_entity
    follow_redirect! rescue nil
    # sem DEK em sessão, o cofre redireciona pro login
    get vault_entries_path
    assert_redirected_to login_path
  end

  test "login com email inexistente dá mensagem genérica" do
    post session_path, params: { email_address: "naoexiste@exemplo.com", master_password: MASTER }
    assert_response :unprocessable_entity
    # não deve revelar se foi email inexistente vs senha errada
    refute_match(/não existe|inexistente|not found/i, response.body)
  end

  test "logout descarta a DEK e bloqueia o cofre" do
    post session_path, params: { email_address: @user.email_address, master_password: MASTER }
    delete session_path
    get vault_entries_path
    assert_redirected_to login_path
  end

  test "resposta de login nunca ecoa a master password" do
    post session_path, params: { email_address: @user.email_address, master_password: MASTER }
    refute_includes response.body, MASTER
  end
end
