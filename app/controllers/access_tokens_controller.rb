# frozen_string_literal: true

# AccessTokensController — emite/revoga tokens da skill /antired (web).
# Emitir exige sessão destravada (precisa da DEK em claro pra re-encriptá-la).
class AccessTokensController < ApplicationController
  before_action :require_unlock

  def index
    @tokens = current_user.access_tokens.order(created_at: :desc)
    @new_token = flash[:new_token] # mostrado UMA vez, logo após criar
  end

  def create
    name = params[:name].to_s.strip
    name = "token-#{Time.current.strftime('%Y%m%d-%H%M')}" if name.empty?
    days = params[:expires_in_days].to_s.strip
    expires_at = days.match?(/\A\d+\z/) && days.to_i.positive? ? days.to_i.days.from_now : nil
    _record, token = AccessToken.issue!(user: current_user, dek: current_dek, name: name, expires_at: expires_at)
    redirect_to access_tokens_path,
                flash: { new_token: token, notice: "Token criado. Copie agora — não dá pra ver de novo." }
  end

  def destroy
    current_user.access_tokens.find(params[:id]).destroy
    redirect_to access_tokens_path, notice: "Token revogado."
  end
end
