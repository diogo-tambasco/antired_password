# frozen_string_literal: true

# RegistrationsController — signup (SPEC §6.1, §7).
#
# Params PLANOS: top-level email_address / master_password (não nested).
# A resposta NUNCA ecoa a master password.
class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    user = User.register(
      email_address: params[:email_address],
      master_password: params[:master_password]
    )
    dek = user.unlock(params[:master_password])
    start_session(user, dek)
    redirect_to vault_entries_path
  rescue ActiveRecord::RecordInvalid => e
    @user = User.new(email_address: params[:email_address])
    flash.now[:alert] = "Não foi possível criar a conta: #{e.record.errors.full_messages.to_sentence}"
    render :new, status: :unprocessable_entity
  end
end
