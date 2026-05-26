# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"
require Rails.root.join("db/migrate/20250929070310_add_view_all_principals_permission_to_existing_roles")

RSpec.describe AddViewAllPrincipalsPermissionToExistingRoles, type: :model do
  let(:project) { create(:project) }

  def migrate_up
    ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) }
  end

  def migrate_down
    ActiveRecord::Migration.suppress_messages { described_class.migrate(:down) }
  end

  describe "up" do
    context "when a global role has manage_user permission" do
      let(:global_role) { create(:global_role, name: "Staff Manager") }

      before { global_role.add_permission!(:manage_user) }

      it "adds view_all_principals to it" do
        expect(global_role.has_permission?(:view_all_principals)).to be false

        migrate_up

        expect(global_role.reload.has_permission?(:view_all_principals)).to be true
      end

      it "does not duplicate the permission when run twice" do
        migrate_up
        migrate_up

        count = RolePermission.where(role_id: global_role.id, permission: "view_all_principals").count
        expect(count).to eq(1)
      end
    end

    context "when a global role already has both manage_user and view_all_principals" do
      let(:global_role) { create(:global_role, name: "Staff Manager") }

      before do
        global_role.add_permission!(:manage_user)
        global_role.add_permission!(:view_all_principals)
      end

      it "does not add a duplicate permission" do
        initial_count = RolePermission.where(role_id: global_role.id, permission: "view_all_principals").count

        migrate_up

        expect(RolePermission.where(role_id: global_role.id, permission: "view_all_principals").count)
          .to eq(initial_count)
      end
    end

    context "when a user has manage_members via a project role" do
      let(:project_role) { create(:project_role, name: "Project Manager") }
      let(:user) { create(:user) }

      before do
        project_role.add_permission!(:manage_members)
        create(:member, project:, principal: user, roles: [project_role])
      end

      it "creates the migration global role with view_all_principals" do
        expect(GlobalRole.find_by(name: "View all users (migration)")).to be_nil

        migrate_up

        migration_role = GlobalRole.find_by(name: "View all users (migration)")
        expect(migration_role).to be_present
        expect(migration_role.has_permission?(:view_all_principals)).to be true
      end

      it "assigns the migration global role to the user" do
        migrate_up

        migration_role = GlobalRole.find_by(name: "View all users (migration)")
        global_membership = user.members.find_by(project: nil)
        expect(global_membership).to be_present
        expect(global_membership.roles).to include(migration_role)
      end

      it "is idempotent" do
        migrate_up
        migrate_up

        expect(user.members.where(project: nil).count).to eq(1)
        expect(MemberRole.joins(:member)
                         .where(members: { user_id: user.id, project_id: nil })
                         .where(role: GlobalRole.find_by(name: "View all users (migration)"))
                         .where(inherited_from: nil)
                         .count).to eq(1)
      end
    end

    context "when a user has manage_members in multiple projects" do
      let(:project_role) { create(:project_role, name: "Project Manager") }
      let(:user) { create(:user) }
      let(:project2) { create(:project) }

      before do
        project_role.add_permission!(:manage_members)
        create(:member, project:, principal: user, roles: [project_role])
        create(:member, project: project2, principal: user, roles: [project_role])
      end

      it "assigns the global role only once" do
        migrate_up

        expect(user.members.where(project: nil).count).to eq(1)
      end
    end

    context "when the user is a PlaceholderUser" do
      let(:project_role) { create(:project_role, name: "Project Manager") }
      let(:placeholder) { create(:placeholder_user) }

      before do
        project_role.add_permission!(:manage_members)
        create(:member, project:, principal: placeholder, roles: [project_role])
      end

      it "does not assign the global role to the placeholder user" do
        migrate_up

        expect(Member.where(user_id: placeholder.id, project_id: nil)).to be_empty
      end
    end

    context "when a user already has a global membership for another role" do
      let(:project_role) { create(:project_role, name: "Project Manager") }
      let(:other_global_role) { create(:global_role, name: "Other Global Role") }
      let(:user) { create(:user) }

      before do
        project_role.add_permission!(:manage_members)
        create(:member, project:, principal: user, roles: [project_role])
        create(:member, project: nil, principal: user, roles: [other_global_role])
      end

      it "reuses the existing global membership instead of creating a new one" do
        migrate_up

        expect(user.members.where(project: nil).count).to eq(1)
        migration_role = GlobalRole.find_by(name: "View all users (migration)")
        expect(user.members.find_by(project: nil).roles).to include(migration_role, other_global_role)
      end
    end
  end

  describe "down" do
    context "when the migration role exists with assignments" do
      let(:migration_role) { create(:global_role, name: "View all users (migration)") }
      let(:user) { create(:user) }

      before do
        migration_role.add_permission!(:view_all_principals)
        create(:member, project: nil, principal: user, roles: [migration_role])
      end

      it "removes the migration role and its global memberships" do
        expect(GlobalRole.find_by(name: "View all users (migration)")).to be_present

        migrate_down

        expect(GlobalRole.find_by(name: "View all users (migration)")).to be_nil
        expect(user.members.reload.where(project: nil)).to be_empty
      end

      it "preserves other global memberships the user has" do
        other_global_role = create(:global_role, name: "Other Role")
        user.members.find_by(project: nil).roles << other_global_role

        migrate_down

        expect(user.members.reload.where(project: nil)).not_to be_empty
        expect(user.members.find_by(project: nil).roles).to include(other_global_role)
      end
    end

    context "when a global role has view_all_principals" do
      let(:global_role) { create(:global_role, name: "Staff Manager") }

      before do
        global_role.add_permission!(:manage_user)
        global_role.add_permission!(:view_all_principals)
      end

      it "removes view_all_principals but leaves manage_user" do
        migrate_down

        global_role.reload
        expect(global_role.has_permission?(:view_all_principals)).to be false
        expect(global_role.has_permission?(:manage_user)).to be true
      end
    end

    context "when the migration role does not exist" do
      it "does not raise an error" do
        expect { migrate_down }.not_to raise_error
      end
    end
  end
end
