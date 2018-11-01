# frozen_string_literal: true

class RepoAccessIndex < Chewy::Index
  define_type RepoAccess.includes(:classroom, :user) do
    field :id
    field :created_at
    field :updated_at

    field :organization_login, value: ->(repo_access) { repo_access&.classroom&.github_organization&.login }
    field :user_login,         value: ->(repo_access) { repo_access&.user&.github_user&.login                 }
  end
end
