# frozen_string_literal: true

module Orgs
  class Controller < ApplicationController
    before_action :ensure_current_classroom
    before_action :ensure_current_classroom_visible_to_current_user

    protected

    def add_current_user_to_current_classroom_or_404
      github_organization = GitHubOrganization.new(current_user.github_client, current_classroom.github_id)
      return not_found unless github_organization.admin?(current_user.github_user.login)
      current_classroom.users << current_user
      true
    end

    def ensure_current_classroom
      not_found if current_classroom.nil?
    end

    def ensure_current_classroom_visible_to_current_user
      return true if current_classroom.users.pluck(:id).include?(current_user.id)
      add_current_user_to_current_organization_or_404
    end

    def current_classroom
      return @current_classroom if defined?(@current_classroom)
      organization_id = params[:organization_id] || params[:id]
      @current_classroom = Classroom.find_by!(slug: organization_id)
    end
    helper_method :current_classroom

    def failbot_context
      super unless current_classroom.nil?
      super.merge(organization: current_classroom.id)
    end
  end
end
