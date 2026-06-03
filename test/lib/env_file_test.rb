# frozen_string_literal: true

require "test_helper"
require "env_file"

class EnvFileTest < ActiveSupport::TestCase
  test "parse ignora comentários, linhas vazias e prefixo export" do
    text = <<~ENV
      # comentário
      DATABASE_URL=postgres://db

      export API_KEY=sk_live_123
      EMPTY=
    ENV
    assert_equal(
      [["DATABASE_URL", "postgres://db"], ["API_KEY", "sk_live_123"], ["EMPTY", ""]],
      EnvFile.parse(text)
    )
  end

  test "parse desfaz aspas e escape de newline" do
    assert_equal [["MSG", "oi mundo"]], EnvFile.parse('MSG="oi mundo"')
    assert_equal [["MULTI", "linha1\nlinha2"]], EnvFile.parse('MULTI="linha1\nlinha2"')
  end

  test "dump cita valores com espaço e deixa valores simples sem aspas" do
    assert_equal "A=simples\n", EnvFile.dump([["A", "simples"]])
    assert_equal %(B="com espaco"\n), EnvFile.dump([["B", "com espaco"]])
    # URL com :/@ é considerada simples (sem aspas)
    assert_equal "U=postgres://u:p@h/db\n", EnvFile.dump([["U", "postgres://u:p@h/db"]])
  end

  test "round-trip parse(dump(x)) preserva os pares" do
    pairs = [["DATABASE_URL", "postgres://u:p@h/db"], ["MSG", "oi mundo"], ["MULTI", "a\nb"]]
    assert_equal pairs, EnvFile.parse(EnvFile.dump(pairs))
  end
end
