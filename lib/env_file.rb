# frozen_string_literal: true

# EnvFile — parse/dump de arquivos .env (round-trip da skill /antired).
# Módulo puro, sem estado, sem Rails. NÃO loga nem cifra nada — só formata texto.
module EnvFile
  module_function

  # Texto .env → [[KEY, VALUE], ...]. Ignora comentários (#) e linhas vazias,
  # tolera `export KEY=...` e valores entre aspas.
  def parse(text)
    text.to_s.each_line.filter_map do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      line = line.sub(/\Aexport\s+/, "")
      key, sep, val = line.partition("=")
      key = key.strip
      next if sep.empty? || key.empty?

      [key, unquote(val.strip)]
    end
  end

  # [[KEY, VALUE], ...] → corpo .env (uma var por linha, com aspas quando preciso).
  def dump(pairs)
    pairs.map { |k, v| "#{k}=#{quote(v)}" }.join("\n") + (pairs.any? ? "\n" : "")
  end

  def quote(value)
    s = value.to_s
    # Sem aspas quando o valor é "simples" (sem espaço/aspas/quebra/caractere chato).
    return s if !s.empty? && s.match?(%r{\A[A-Za-z0-9_.\-/:@+]+\z})

    escaped = s.gsub(/[\\"\n]/) { |c| { "\\" => "\\\\", '"' => '\"', "\n" => '\n' }[c] }
    %("#{escaped}")
  end

  def unquote(v)
    if v.length >= 2 && v.start_with?('"') && v.end_with?('"')
      v[1..-2].gsub('\n', "\n").gsub('\"', '"').gsub("\\\\", "\\")
    elsif v.length >= 2 && v.start_with?("'") && v.end_with?("'")
      v[1..-2]
    else
      v
    end
  end
end
