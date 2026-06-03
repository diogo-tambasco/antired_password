# frozen_string_literal: true

require "env_file"

# API JSON do cofre — autenticada por AccessToken (Bearer). Stateless, sem sessão.
# Decifra os segredos em runtime usando a DEK destravada pelo token e NUNCA loga
# valores. TLS obrigatório em produção (kamal-proxy / config.force_ssl).
module Api
  module V1
    class ProjectsController < ActionController::API
      before_action :authenticate_token

      # GET /api/v1/projects(.json|.txt) — nomes dos projetos acessíveis.
      def index
        names = @user.projects.order(:name).pluck(:name)
        if request.format.json?
          render json: { projects: names }
        else
          render plain: names.join("\n") + (names.any? ? "\n" : "")
        end
      end

      # GET /api/v1/projects/:name/env(.json) — corpo .env do projeto.
      # Default: texto puro KEY=VALUE pronto pra escrever no disco.
      def env
        project = @user.projects.where("lower(name) = ?", params[:name].to_s.strip.downcase).first
        return render(json: { error: "project not found" }, status: :not_found) unless project

        pairs = project.env_pairs(@dek)
        if request.format.json?
          render json: { project: project.name, env: pairs.to_h }
        else
          render plain: EnvFile.dump(pairs)
        end
      end

      private

      def authenticate_token
        header = request.headers["Authorization"].to_s
        raw = header.start_with?("Bearer ") ? header.delete_prefix("Bearer ").strip : header.strip
        @user, @dek = AccessToken.unlock(raw)
      rescue AccessToken::Invalid
        render json: { error: "invalid or revoked token" }, status: :unauthorized
      end
    end
  end
end
