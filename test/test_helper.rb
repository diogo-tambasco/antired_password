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
      # SQLite single-file + múltiplos workers em paralelo causam
      # SQLite3::BusyException ("database is locked") intermitente no setup
      # (User.register grava no banco). Serializar elimina a flakiness de I/O
      # sem afetar o comportamento testado. (Exceção documentada de edição em test/.)
      parallelize(workers: 1)

      # Carrega todos os fixtures de test/fixtures/*.yml.
      fixtures :all

      # Isolamento de estado do rack-attack entre testes (infra, não contrato).
      # Os contadores de throttle do rack-attack vivem no Rails.cache (memory_store
      # em test). Sem zerar entre testes, os múltiplos POST /session que vários
      # testes de integração disparam (mesmo IP 127.0.0.1, janela de 20s) somam e
      # estouram o limite de 5/20s — fazendo logins legítimos de setup virarem 429
      # e quebrarem testes não-relacionados de forma dependente da ordem. Limpar o
      # cache antes de cada teste dá a cada um uma janela limpa (o RateLimitingTest
      # já faz isso no próprio setup, então continua válido).
      setup do
        Rails.cache.clear if defined?(Rails) && Rails.respond_to?(:cache)
      end
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
