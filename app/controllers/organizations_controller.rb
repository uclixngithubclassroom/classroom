# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class ClassroomsController < Orgs::Controller
  before_action :ensure_team_management_flipper_is_enabled, only: [:show_groupings]

  before_action :authorize_organization_addition,     only: [:create]
  before_action :set_users_github_organizations,      only: %i[index new create]
  before_action :add_current_user_to_organizations,   only: [:index]
  before_action :paginate_users_github_organizations, only: %i[new create]
  before_action :verify_user_belongs_to_organization, only: [:remove_user]

  skip_before_action :ensure_current_classroom,                         only: %i[index new create]
  skip_before_action :ensure_current_classroom_visible_to_current_user, only: %i[index new create]

  def index
    @classrooms = current_user.classrooms.order(:id).page(params[:page])
  end

  def new
    @classroom = Classroom.new
  end

  # rubocop:disable MethodLength
  def create
    return unless validate_multiple_classrooms_on_org

    result = Classroom::Creator.perform(
      github_id: new_organization_params[:github_id],
      users: new_organization_params[:users]
    )

    if result.success?
      @classroom = result.classroom
      redirect_to setup_organization_path(@classroom)
    else
      flash[:error] = result.error
      redirect_to new_organization_path
    end
  end
  # rubocop:enable MethodLength

  def show
    # sort assignments by title
    @assignments = Kaminari
      .paginate_array(current_classroom.all_assignments(with_invitations: true)
      .sort_by(&:title))
      .page(params[:page])
  end

  def edit; end

  def invitation; end

  def show_groupings
    @groupings = current_classroom.groupings
  end

  def update
    if current_classroom.update_attributes(update_organization_params)
      flash[:success] = "Organization \"#{current_classroom.title}\" updated"
      redirect_to current_classroom
    else
      render :edit
    end
  end

  def destroy
    if current_classroom.update_attributes(deleted_at: Time.zone.now)
      DestroyResourceJob.perform_later(current_classroom)

      flash[:success] = "Your organization, @#{current_classroom.github_organization.login} is being reset"
      redirect_to organizations_path
    else
      render :edit
    end
  end

  def remove_user
    if current_classroom.one_owner_remains?
      flash[:error] = "The user can not be removed from the classroom"
    else
      transfer_assignments if @removed_user.owns_all_assignments_for?(current_classroom)
      current_classroom.users.delete(@removed_user)
      flash[:success] = "The user has been removed from the classroom"
    end

    redirect_to settings_invitations_organization_path
  end

  def new_assignment; end

  def invite; end

  def setup; end

  def setup_organization
    if current_classroom.update_attributes(update_organization_params)
      redirect_to invite_organization_path(current_classroom)
    else
      render :setup
    end
  end

  private

  def authorize_organization_addition
    new_github_organization = github_organization_from_params

    return if new_github_organization.admin?(current_user.github_user.login)
    raise NotAuthorized, "You are not permitted to add this organization as a classroom"
  end

  def github_organization_from_params
    @github_organization_from_params ||= GitHubOrganization.new(
      current_user.github_client,
      params[:organization][:github_id].to_i
    )
  end

  def new_organization_params
    params.require(:organization).permit(:github_id).merge(users: [current_user])
  end

  # rubocop:disable Metrics/AbcSize
  def set_users_github_organizations
    @users_github_organizations = current_user.github_user.organization_memberships.map do |membership|
      {
        # TODO: Remove `classroom` field after we turn off the feature flag
        # for multiple classrooms in one org
        classroom:   Classroom.unscoped.find_by(github_id: membership.organization.id),
        github_id:   membership.organization.id,
        login:       membership.organization.login,
        owner_login: membership.user.login,
        role:        membership.role
      }
    end
  end
  # rubocop:enable Metrics/AbcSize

  # Check if the current user has any organizations with admin privilege,
  # if so add the user to the corresponding classroom automatically.
  def add_current_user_to_organizations
    @users_github_organizations.each do |github_org|
      user_classrooms = Classroom.where(github_id: github_org[:github_id])

      # Iterate over each classroom associate with this github organization
      user_classrooms.map do |classroom|
        create_user_organization_access(classroom) unless classroom.users.include?(current_user)
      end
    end
  end

  def create_user_organization_access(classroom)
    github_org = GitHubOrganization.new(current_user.github_client, classroom.github_id)
    return unless github_org.admin?(current_user.github_user.login)
    classroom.users << current_user
  end

  def paginate_users_github_organizations
    @users_github_organizations = Kaminari.paginate_array(@users_github_organizations).page(params[:page]).per(24)
  end

  def update_organization_params
    params
      .require(:organization)
      .permit(:title)
  end

  def verify_user_belongs_to_organization
    @removed_user = User.find(params[:user_id])
    not_found unless current_classroom.users.map(&:id).include?(@removed_user.id)
  end

  def transfer_assignments
    new_owner = current_classroom.users.where.not(id: @removed_user.id).first
    current_classroom.all_assignments.map do |assignment|
      next unless assignment.creator_id == @removed_user.id
      assignment.update_attributes(creator_id: new_owner.id)
    end
  end

  def validate_multiple_classrooms_on_org
    classroom_exists_on_org = Classroom.unscoped.find_by(github_id: new_organization_params[:github_id])
    if classroom_exists_on_org && !multiple_classrooms_per_org_enabled?
      flash[:error] = "Validation failed: GitHub ID has already been taken"
      redirect_to new_organization_path
      return false
    end
    true
  end
end
# rubocop:enable Metrics/ClassLength
