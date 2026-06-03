# frozen_string_literal: true

# SessionsController — login-por-decrypt + logout (SPEC §6.2–6.3, §7).
#
# Params PLANOS: top-level email_address / master_password (não nested).
# Resposta GENÉRICA pra email inexistente E senha errada (não revela qual dos
# dois falhou — evita enumeração de usuários). A resposta NUNCA ecoa a master
# password.
class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    dek = user&.unlock(params[:master_password])

    if dek
      start_session(user, dek)
      redirect_to vault_entries_path
    else
      deny_generic
    end
  rescue User::InvalidPassword
    deny_generic
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  private

  # Mesma resposta 422 genérica pra qualquer falha de login.
  def deny_generic
    flash.now[:alert] = "Credenciais inválidas."
    render :new, status: :unprocessable_entity
  end
end
