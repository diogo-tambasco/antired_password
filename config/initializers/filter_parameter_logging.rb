# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :master_password, :value, :password,
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# Mantém `config.filter_parameters` como a lista ORIGINAL de símbolos.
# Por padrão (Rails 7.1+) `precompile_filter_parameters = true` faz o Rails, ao
# montar o filtro na primeira requisição, sobrescrever a lista in-place por um
# único Regexp compilado (`config.filter_parameters.replace([/.../])`). Isso não
# muda o comportamento de filtragem dos logs, mas torna a config opaca para
# inspeção (vira [Regexp] em vez de [:master_password, :value, ...]). Mantendo a
# lista de símbolos, a config permanece auditável e os params continuam filtrados
# normalmente nos logs. Custo desprezível numa instância única.
Rails.application.config.precompile_filter_parameters = false
