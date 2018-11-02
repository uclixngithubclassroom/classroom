# frozen_string_literal: true

# Should this be named ClassroomAuthorization instead?
module OrganizationAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :set_organization, :authorize_organization_access
  end

  def authorize_organization_access
    return if @classroom.users.include?(current_user)
    github_organization.admin?(current_user.github_user.login) ? @classroom.users << current_user : not_found
  end

  private

  def github_organization
    @github_organization ||= GitHubOrganization.new(current_user.github_client, @classroom.github_id)
  end

  # Should this be named set_classroom instead?
  def set_organization
    return @classroom if defined?(@classroom)

    organization_id = params[:organization_id] || params[:id]
    @classroom = Classroom.find_by!(slug: organization_id)
  end
end
