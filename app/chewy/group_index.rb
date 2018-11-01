# frozen_string_literal: true

class GroupIndex < Chewy::Index
  define_type Group.includes(:classroom) do
    field :id
    field :title
    field :github_team_id
    field :created_at
    field :updated_at

    field :organization_login, value: ->(group) { group&.classroom&.github_organization&.login }
  end
end
