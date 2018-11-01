# frozen_string_literal: true

require_relative "support/vcr"
require "securerandom"

FactoryBot.define do
  factory :assignment do
    classroom

    title                 { "#{Faker::Company.name} Assignment" }
    slug                  { title.parameterize                  }
    creator               { classroom.users.first            }
    assignment_invitation { build_assignment_invitation         }
  end

  factory :assignment_invitation do
    assignment
  end

  factory :invite_status do
    assignment_invitation
    user
  end

  factory :group_invite_status do
    group_assignment_invitation
    group
  end

  factory :assignment_repo do
    assignment
    user

    github_repo_id { rand(1..1_000_000) }
  end

  factory :deadline do
    assignment
    deadline_at { Time.zone.tomorrow }
  end

  factory :group_assignment do
    classroom

    title    { "#{Faker::Company.name} Group Assignment"     }
    slug     { title.parameterize                            }
    grouping { create(:grouping, classroom: classroom) }
    creator  { classroom.users.first                      }
  end

  factory :group_assignment_invitation do
    group_assignment
  end

  factory :grouping do
    classroom

    title { Faker::Company.name }
    slug  { title.parameterize  }
  end

  factory :group do
    grouping

    title          { Faker::Team.name[0..39] }
    github_team_id { rand(1..1_000_000) }
  end

  factory :classroom do
    title      { "#{Faker::Company.name} Class" }
    github_id  { rand(1..1_000_000) }

    transient do
      users_count 1
    end

    after(:build) do |classroom, evaluator|
      create_list(:user, evaluator.users_count, classrooms: [classroom])
    end
  end

  factory :roster do
    identifier_name { "email" }

    after(:build) do |roster|
      roster.roster_entries << RosterEntry.create(identifier: "email")
    end
  end

  factory :roster_entry do
    roster
    identifier { "myemail@example.com" }
  end

  factory :user do
    uid    { rand(1..1_000_000) }
    token  { SecureRandom.hex(20) }

    factory :user_with_classrooms do
      transient do
        classrooms_count 5
      end

      after(:create) do |user, evaluator|
        create_list(:classroom, evaluator.classrooms_count, users: [user])
      end
    end
  end
end
