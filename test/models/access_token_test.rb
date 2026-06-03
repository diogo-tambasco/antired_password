# frozen_string_literal: true

require "test_helper"

# AccessToken — unlock-por-decrypt sem master password (token-por-dev).
# Mesmo contrato do User#unlock: prova = decifrar a DEK; errado nunca devolve lixo.
class AccessTokenTest < ActiveSupport::TestCase
  MASTER = "master do token"

  setup do
    @user = User.register(email_address: "tok@exemplo.com", master_password: MASTER)
    @dek = @user.unlock(MASTER)
  end

  test "issue! devolve token antp_<id>_<secret> e persiste a DEK cifrada" do
    record, token = AccessToken.issue!(user: @user, dek: @dek, name: "macbook")
    assert_match(/\Aantp_[A-Za-z0-9]{16}_[A-Za-z0-9_-]+\z/, token)
    refute_includes record.encrypted_dek.to_s, @dek, "DEK não pode estar em claro no banco"
  end

  test "unlock com o token certo devolve o MESMO user e a MESMA DEK" do
    _record, token = AccessToken.issue!(user: @user, dek: @dek, name: "macbook")
    user, dek = AccessToken.unlock(token)
    assert_equal @user.id, user.id
    assert_equal @dek, dek
  end

  test "unlock atualiza last_used_at" do
    _r, token = AccessToken.issue!(user: @user, dek: @dek, name: "x")
    AccessToken.unlock(token)
    assert_not_nil @user.access_tokens.first.last_used_at
  end

  test "token adulterado, inexistente ou lixo é Invalid" do
    _r, token = AccessToken.issue!(user: @user, dek: @dek, name: "x")
    bad = token[0..-2] + (token[-1] == "a" ? "b" : "a")
    assert_raises(AccessToken::Invalid) { AccessToken.unlock(bad) }
    assert_raises(AccessToken::Invalid) { AccessToken.unlock("antp_naoexiste_xxx") }
    assert_raises(AccessToken::Invalid) { AccessToken.unlock("lixo") }
    assert_raises(AccessToken::Invalid) { AccessToken.unlock("") }
  end

  test "token revogado (destruído) deixa de funcionar" do
    record, token = AccessToken.issue!(user: @user, dek: @dek, name: "x")
    record.destroy
    assert_raises(AccessToken::Invalid) { AccessToken.unlock(token) }
  end

  test "token expirado é Invalid" do
    _r, token = AccessToken.issue!(user: @user, dek: @dek, name: "x", expires_at: 1.hour.ago)
    assert_raises(AccessToken::Invalid) { AccessToken.unlock(token) }
  end
end
