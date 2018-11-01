# frozen_string_literal: true

class ClassroomIndex < Chewy::Index
  define_type Classroom do
    field :id
    field :github_id
    field :slug
    field :title
    field :created_at
    field :updated_at

    field :login, value: ->(classroom) { classroom&.github_organization&.login }
    field :name,  value: ->(classroom) { classroom&.github_organization&.name  }
  end
end
