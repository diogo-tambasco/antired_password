# frozen_string_literal: true

# test_helper.rb — bootstrap padrão Rails 8 (Minitest).
#
# NOTA: enquanto a app não for scaffoldada (`rails new`), o require abaixo de
# "config/environment" vai falhar — isso é esperado (ver test/README.md).
# Os testes de `test/lib/envelope_encryption_test.rb` foram escritos para também
# rodar de forma isolada: eles só exigem `rbnacl` + a classe `EnvelopeEncryption`,
# sem precisar do ambiente Rails completo.

ENV["RAILS_ENV"] ||= "test"

begin
  require_relative "../config/environment"
  require "rails/test_help"

  module ActiveSupport
    class TestCase
      # Roda os testes em paralelo (default Rails 8).
      parallelize(workers: :number_of_processors)

      # Carrega todos os fixtures de test/fixtures/*.yml.
      fixtures :all
    end
  end
rescue LoadError => e
  # App Rails ainda não existe. Caímos num modo mínimo só com Minitest, o
  # suficiente pro teste de cripto isolado carregar. Os demais arquivos, que
  # dependem do Rails, vão falhar ao referenciar constantes inexistentes — e é
  # exatamente o "vermelho esperado" descrito no README.
  warn "[test_helper] ambiente Rails ausente (#{e.class}: #{e.message}); modo mínimo Minitest."
  require "minitest/autorun"
end
