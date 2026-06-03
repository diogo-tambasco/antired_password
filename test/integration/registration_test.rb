# frozen_string_literal: true

# Fluxo de signup — SPEC.md §6.1, §7.

require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  MASTER = "master de signup teste"

  test "GET /signup renderiza o formulário" do
    get signup_path
    assert_response :success
  end

  test "POST /signup cria o usuário e abre sessão" do
    assert_difference -> { User.count }, 1 do
      post signup_path, params: { email_address: "signup@exemplo.com", master_password: MASTER }
    end
    assert_redirected_to vault_entries_path
  end

  test "signup com email duplicado não cria e re-renderiza com erro" do
    User.register(email_address: "dup@exemplo.com", master_password: MASTER)
    assert_no_difference -> { User.count } do
      post signup_path, params: { email_address: "dup@exemplo.com", master_password: MASTER }
    end
    assert_response :unprocessable_entity
  end

  test "resposta do signup nunca ecoa a master password" do
    post signup_path, params: { email_address: "echo@exemplo.com", master_password: MASTER }
    refute_includes response.body, MASTER
  end
end
