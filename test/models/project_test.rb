# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  MASTER = "master forte do projeto"

  setup do
    @user = User.register(email_address: "proj@exemplo.com", master_password: MASTER)
    @dek = @user.unlock(MASTER)
  end

  test "nome é obrigatório e único por usuário (case-insensitive)" do
    @user.projects.create!(name: "Acta")
    dup = @user.projects.build(name: "acta")
    refute dup.valid?
    assert dup.errors.of_kind?(:name, :taken) # of_kind? ignora opções (value:) do validador
  end

  test "usuários diferentes podem ter projeto de mesmo nome" do
    @user.projects.create!(name: "Acta")
    outro = User.register(email_address: "outro@exemplo.com", master_password: "x")
    assert outro.projects.create(name: "Acta").persisted?
  end

  test "env_pairs devolve só entries env, decifradas e ordenadas por nome" do
    project = @user.projects.create!(name: "acta")
    add_env(project, "DATABASE_URL", "postgres://db")
    add_env(project, "API_KEY", "sk_live_123")
    # entry não-env no mesmo projeto NÃO entra no .env
    login = @user.vault_entries.create!(name: "conta admin", kind: :login, project: project)
    login.encrypt_value("senha", @dek); login.save!

    assert_equal(
      [["API_KEY", "sk_live_123"], ["DATABASE_URL", "postgres://db"]],
      project.env_pairs(@dek)
    )
  end

  test "remover projeto mantém os segredos (nullify, não destroy)" do
    project = @user.projects.create!(name: "acta")
    add_env(project, "K", "v")
    assert_no_difference -> { VaultEntry.count } do
      project.destroy
    end
    assert_nil VaultEntry.last.project_id
  end

  private

  def add_env(project, key, value)
    e = @user.vault_entries.create!(name: key, kind: :env, project: project)
    e.encrypt_value(value, @dek)
    e.save!
    e
  end
end
