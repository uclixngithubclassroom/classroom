# frozen_string_literal: true

require "rails_helper"

RSpec.describe Classroom::Creator, type: :model do
  let(:github_organization_id) { classroom_owner_organization_github_id.to_i }
  let(:user)                   { classroom_teacher                           }

  after(:each) do
    Classroom.find_each(&:destroy)
  end

  describe "::perform", :vcr do
    describe "successful creation" do
      it "creates an Organization with a webhook_id" do
        result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])

        expect(result.success?).to be_truthy
        expect(result.classroom.github_id).to eql(github_organization_id)
        expect(result.classroom.webhook_id).to_not be_nil
        expect(result.classroom.github_global_relay_id).to_not be_nil
      end

      it "sends an event to statd" do
        expect(GitHubClassroom.statsd).to receive(:increment).with("classroom.created")

        Classroom::Creator.perform(github_id: github_organization_id, users: [user])
      end

      context "multiple classrooms on same organization" do
        before do
          result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])
          @org = result.classroom
        end

        it "creates a classroom with the same webhook id as the existing one" do
          result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])
          expect(result.classroom.webhook_id).to eql(@org.webhook_id)
        end

        it "creates a classroom with the default title but incremented id" do
          result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])
          expect(result.classroom.title).to eql("#{@org.title[0...-2]}-2")
        end
      end

      context "already created webhook on GitHub org" do
        before do
          GitHubOrganization
            .any_instance.stub(:create_organization_webhook)
            .and_raise GitHub::Error, "Hook: Hook already exists on this organization"

          @dummy_webhook_id = 12_345
          Classroom::Creator
            .any_instance.stub(:get_organization_webhook_id)
            .and_return @dummy_webhook_id
        end

        it "sets webhook id to what it is already set on org" do
          result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])
          expect(result.classroom.webhook_id).to eql(@dummy_webhook_id)
        end
      end
    end

    describe "unsucessful creation" do
      it "does not allow non admins to be added" do
        non_admin_user = create(:user, uid: 1)
        result = Classroom::Creator.perform(github_id: github_organization_id, users: [non_admin_user])
        expect(result.failed?).to be_truthy
      end

      it "deletes the webhook if the process could not be completed" do
        result = Classroom::Creator.perform(github_id: github_organization_id, users: [])
        expect(result.failed?).to be_truthy
      end

      it "deletes the organization if the repository permissions cannot be set to none" do
        stub_request(:patch, github_url("/organizations/#{github_organization_id}"))
          .to_return(body: "{}", status: 401)

        result = Classroom::Creator.perform(github_id: github_organization_id, users: [user])

        expect(result.failed?).to be_truthy
        expect(Classroom.count).to eql(0)
      end
    end
  end
end
