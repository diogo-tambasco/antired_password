# frozen_string_literal: true

# API JSON da skill /antired — auth por token (Bearer), export do .env por projeto.

require "test_helper"

class ApiEnvTest < ActionDispatch::IntegrationTest
  MASTER = "master da api"

  setup do
    @user = User.register(email_address: "api@exemplo.com", master_password: MASTER)
    @dek = @user.unlock(MASTER)
    @project = @user.projects.create!(name: "acta")
    add_env("DATABASE_URL", "postgres://db")
    add_env("API_KEY", "sk_live_123")
    _record, @token = AccessToken.issue!(user: @user, dek: @dek, name: "ci")
  end

  test "GET env com token devolve o .env do projeto em texto" do
    get "/api/v1/projects/acta/env", headers: bearer(@token)
    assert_response :success
    assert_includes response.body, "DATABASE_URL=postgres://db"
    assert_includes response.body, "API_KEY=sk_live_123"
  end

  test "match do nome do projeto é case-insensitive" do
    get "/api/v1/projects/ACTA/env", headers: bearer(@token)
    assert_response :success
    assert_includes response.body, "API_KEY=sk_live_123"
  end

  test "formato .json devolve o env como objeto" do
    get "/api/v1/projects/acta/env.json", headers: bearer(@token)
    assert_response :success
    assert_equal "sk_live_123", JSON.parse(response.body).dig("env", "API_KEY")
  end

  test "sem token → 401" do
    get "/api/v1/projects/acta/env"
    assert_response :unauthorized
  end

  test "token inválido → 401 e não vaza segredo" do
    get "/api/v1/projects/acta/env", headers: bearer("antp_xxx_yyy")
    assert_response :unauthorized
    refute_includes response.body, "sk_live_123"
  end

  test "projeto inexistente → 404" do
    get "/api/v1/projects/naoexiste/env", headers: bearer(@token)
    assert_response :not_found
  end

  test "token revogado deixa de acessar" do
    @user.access_tokens.first.destroy
    get "/api/v1/projects/acta/env", headers: bearer(@token)
    assert_response :unauthorized
  end

  test "index lista os projetos do dono" do
    get "/api/v1/projects", headers: bearer(@token).merge("Accept" => "text/plain")
    assert_response :success
    assert_includes response.body, "acta"
  end

  private

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def add_env(key, value)
    e = @user.vault_entries.create!(name: key, kind: :env, project: @project)
    e.encrypt_value(value, @dek)
    e.save!
  end
end
