require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AntiredPassword
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `envelope_encryption.rb` é uma lib pura carregada via `require` explícito
    # (inclusive nos testes isolados, sem Rails). Mantê-la fora do Zeitwerk evita
    # que o autoloader a descarregue entre testes (NameError no test runner).
    # `lib/envelope_encryption.rb` é carregada via `require` explícito (boot.rb
    # coloca lib/ no $LOAD_PATH antes do bootsnap). Fora do Zeitwerk pra não ser
    # descarregada/redefinida pelo autoloader entre testes.
    config.autoload_lib(ignore: %w[assets tasks envelope_encryption.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Sessão server-side (SPEC §6.3, §7): a DEK em claro vive SÓ em RAM durante a
    # sessão ativa. Store dedicado em memória — NUNCA solid_cache, que gravaria a
    # DEK em claro no SQLite do cache e violaria o invariante zero-knowledge em
    # repouso. Esse store é independente de Rails.cache, então funciona em
    # test/dev/prod sem depender do toggle de caching.
    config.session_store :cache_store,
      cache: ActiveSupport::Cache::MemoryStore.new(size: 32 * 1024 * 1024),
      key: "_antired_password_session"
  end
end
