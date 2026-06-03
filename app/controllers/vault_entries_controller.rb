# frozen_string_literal: true

# VaultEntriesController — CRUD do cofre (SPEC §6.4, §7).
#
# Bloqueado sem sessão E sem DEK em RAM: sem a DEK não há como cifrar/decifrar
# nada, então redireciona pro login. O `value` (segredo) é SEMPRE lido fora do
# permit e cifrado com a DEK da sessão; nunca vira coluna/atributo do model.
class VaultEntriesController < ApplicationController
  before_action :require_unlock

  # A LISTAGEM não decifra nada: mostra só name/metadata (não-secretos).
  def index
    @entries = current_user.vault_entries.order(:name)
  end

  # find escopado: entry de outro usuário ⇒ RecordNotFound ⇒ 404 (IDOR).
  def show
    @entry = current_user.vault_entries.find(params[:id])
    @value = @entry.decrypt_value(current_dek)
  end

  def new
    @entry = current_user.vault_entries.new
  end

  def create
    @entry = current_user.vault_entries.new(entry_params)
    @entry.encrypt_value(params.dig(:vault_entry, :value).to_s, current_dek)
    if @entry.save
      redirect_to vault_entries_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entry = current_user.vault_entries.find(params[:id])
  end

  def update
    @entry = current_user.vault_entries.find(params[:id])
    @entry.assign_attributes(entry_params)
    value = params.dig(:vault_entry, :value)
    @entry.encrypt_value(value.to_s, current_dek) if value.present?
    if @entry.save
      redirect_to vault_entry_path(@entry)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry = current_user.vault_entries.find(params[:id])
    @entry.destroy
    redirect_to vault_entries_path
  end

  private

  # Bloqueio: precisa estar logado E ter a DEK em sessão (senão não decifra nada).
  def require_unlock
    redirect_to login_path unless logged_in? && current_dek
  end

  # `value` NUNCA entra aqui — é o segredo, lido à parte e cifrado com a DEK.
  def entry_params
    params.require(:vault_entry).permit(:name, :kind, metadata: {})
  end
end
