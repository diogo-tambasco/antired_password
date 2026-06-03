# frozen_string_literal: true

require "env_file"

# ProjectsController — gerencia projetos e o round-trip do .env (web).
# Precisa da sessão destravada (DEK em RAM) pra cifrar/decifrar.
class ProjectsController < ApplicationController
  before_action :require_unlock

  def index
    @projects = current_user.projects.order(:name)
  end

  def show
    @project = current_user.projects.find(params[:id])
    @entries = @project.vault_entries.order(:name)
    @env_pairs = @project.env_pairs(current_dek)
    @env_text = EnvFile.dump(@env_pairs)
  end

  def new
    @project = current_user.projects.new
  end

  def create
    @project = current_user.projects.new(project_params)
    if @project.save
      redirect_to @project, notice: "Projeto criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /projects/:id/import_env — cola um .env inteiro → N entries env cifradas.
  # Idempotente por nome: reimportar a mesma KEY atualiza o valor (re-cifra).
  def import_env
    @project = current_user.projects.find(params[:id])
    pairs = EnvFile.parse(params[:env_text])
    pairs.each do |key, value|
      entry = current_user.vault_entries.find_or_initialize_by(project: @project, name: key, kind: :env)
      entry.encrypt_value(value, current_dek)
      entry.save!
    end
    redirect_to @project, notice: "#{pairs.size} variáveis importadas e cifradas."
  end

  def destroy
    @project = current_user.projects.find(params[:id])
    @project.destroy
    redirect_to projects_path, notice: "Projeto removido (segredos mantidos no cofre)."
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end
end
