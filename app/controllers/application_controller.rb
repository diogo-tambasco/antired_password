class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?

  private

  # Usuário da sessão (não-secreto). A presença de :user_id sozinha NÃO basta
  # pra estar "logado" — sem a DEW em sessão o cofre fica bloqueado.
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # DEK em claro recuperada da sessão server-side (vive só em RAM). Base64 porque
  # a DEK é binária e a sessão serializa em texto.
  def current_dek
    session[:dek] ? Base64.strict_decode64(session[:dek]) : nil
  end

  # Logado = tem usuário E tem DEK em sessão. Sem DEK não dá pra decifrar nada.
  def logged_in?
    current_user.present? && session[:dek].present?
  end

  # Abre a sessão guardando o id do usuário e a DEK (Base64) em RAM. A master
  # password / KEK NUNCA são guardadas — só a DEK, e só durante a sessão ativa.
  def start_session(user, dek)
    session[:user_id] = user.id
    session[:dek] = Base64.strict_encode64(dek)
  end
end
