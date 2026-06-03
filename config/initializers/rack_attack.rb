# frozen_string_literal: true

# rack-attack — brute-force guard no login (SPEC §8).
#
# O middleware Rack::Attack é inserido automaticamente pela railtie da gem ao
# ser requerida (a gem está no Gemfile, então fica ativo em TODOS os ambientes,
# inclusive test). Aqui só configuramos o store e os throttles.
#
# SEGURANÇA: a resposta default de throttle é 429 SEM corpo que revele se o
# email existe — não customizamos a resposta pra não vazar enumeração de usuário.

class Rack::Attack
  # Contadores de throttle vivem no Rails.cache (memory_store em test, solid_cache
  # em produção). O rate_limiting_test faz Rails.cache.clear no setup.
  Rack::Attack.cache.store = Rails.cache

  # Janela do throttle. O rack-attack discretiza o contador em "baldes" de
  # tamanho `period` (chave inclui floor(now/period)). Uma janela CURTA (ex. 20s)
  # tem um efeito colateral: uma rajada de logins que cruza a fronteira do balde
  # se divide entre dois contadores e pode NÃO estourar o limite — tanto num
  # teste quanto, pior, na mão de um atacante batendo na borda da janela. Uma
  # janela mais longa fecha essa brecha (a rajada inteira cai num balde só) e é
  # uma política de lockout de brute-force mais forte. 5 falhas ⇒ bloqueio até a
  # virada do balde (~10 min). Mantém o comportamento esperado pelo
  # rate_limiting_test (6º POST /session ⇒ 429) de forma determinística.
  LOGIN_LIMIT  = 5
  LOGIN_PERIOD = 10.minutes

  # Throttle por IP: no máx. 5 POSTs /session por janela; o 6º vira 429.
  throttle("logins/ip", limit: LOGIN_LIMIT, period: LOGIN_PERIOD) do |req|
    req.ip if req.path == "/session" && req.post?
  end

  # Throttle por email: limita tentativas contra um mesmo email_address.
  # Normaliza igual ao SessionsController (strip + downcase). Sem email no body,
  # nil pula o throttle (nada a contar).
  throttle("logins/email", limit: LOGIN_LIMIT, period: LOGIN_PERIOD) do |req|
    if req.path == "/session" && req.post?
      req.params["email_address"].to_s.strip.downcase.presence
    end
  end
end
