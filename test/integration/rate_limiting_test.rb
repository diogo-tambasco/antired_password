# frozen_string_literal: true

# rack-attack no login — SPEC.md §8.

require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  MASTER = "master rate limit"

  setup do
    @user = User.register(email_address: "rate@exemplo.com", master_password: MASTER)
    # garante cache limpo entre testes (rack-attack usa Rails.cache)
    Rails.cache.clear if defined?(Rails)
    Rack::Attack.reset! if defined?(Rack::Attack) && Rack::Attack.respond_to?(:reset!)
  end

  test "estourar tentativas de login responde 429" do
    limite = 6 # deve passar do throttle configurado (ex.: 5/20s) — ajustar se mudar o preset
    limite.times do
      post session_path, params: { email_address: @user.email_address, master_password: "errada" }
    end
    assert_equal 429, response.status, "após o limite, login deve responder Too Many Requests"
  end

  test "throttle não revela se o email existe" do
    10.times do
      post session_path, params: { email_address: "fantasma@exemplo.com", master_password: "x" }
    end
    refute_match(/não existe|inexistente|not found/i, response.body)
  end

  test "requisições dentro do limite não são bloqueadas" do
    post session_path, params: { email_address: @user.email_address, master_password: "errada" }
    refute_equal 429, response.status
  end
end
