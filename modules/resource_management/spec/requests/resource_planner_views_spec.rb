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

RSpec.describe "ResourcePlannerViews requests",
               :skip_csrf,
               type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %w[resource_management]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_resource_planners] })
  end

  let(:resource_planner) { create(:resource_planner, project:, principal: user) }
  let(:view) do
    ResourceWorkPackageList.create!(name: "Original", parent: resource_planner, project:, principal: user)
  end

  before { login_as user }

  describe "PATCH update" do
    subject(:perform) do
      patch project_resource_planner_view_path(project, resource_planner, view),
            params: { view: { name: "Renamed view" } },
            as: :turbo_stream
    end

    it "persists the new name" do
      perform

      expect(response).to have_http_status(:ok)
      expect(view.reload.name).to eq("Renamed view")
    end

    it "closes the dialog and replaces the tab nav and content in place" do
      perform

      # Dialog is closed via a CSS selector target (not a bare id).
      expect(response.body).to include('action="closeDialog"')
      expect(response.body).to include('target="#edit-resource-planner-view-dialog"')

      # Tab nav and the view content are replaced rather than redirecting.
      expect(response.body).to include('action="replace"')
      expect(response.body).to include('target="resource-planners-sub-views-component"')
      expect(response.body).to include('target="resource-planner-views-content-component"')

      # The replaced tab nav reflects the new name.
      expect(response.body).to include("Renamed view")
    end

    context "when another user cannot see the private planner" do
      let(:other_user) { create(:user, member_with_permissions: { project => %i[view_resource_planners] }) }

      before { login_as other_user }

      it "is not found and leaves the view unchanged" do
        perform

        expect(response).to have_http_status(:not_found)
        expect(view.reload.name).to eq("Original")
      end
    end
  end
end
