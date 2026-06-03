ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# `lib/` precisa estar no $LOAD_PATH ANTES do bootsnap montar o cache de paths,
# senão `require "envelope_encryption"` (nome simples, usado pelos testes) falha:
# o bootsnap só resolve o que estava no load path no momento do setup. Rails 8
# mantém `add_autoload_paths_to_load_path = false`, então adicionamos lib aqui.
lib_path = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
