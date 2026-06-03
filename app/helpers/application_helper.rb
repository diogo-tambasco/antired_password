module ApplicationHelper
  # Classe do link de navegação no header; destaca o item ativo.
  def nav_class(active)
    base = "rounded-lg px-3 py-1.5 transition"
    if active
      "#{base} bg-zinc-800 text-white"
    else
      "#{base} text-zinc-400 hover:bg-zinc-800/60 hover:text-zinc-100"
    end
  end
end
