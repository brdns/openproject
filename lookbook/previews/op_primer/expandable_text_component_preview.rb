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

module OpPrimer
  # @logical_path OpenProject/Primer
  class ExpandableTextComponentPreview < Lookbook::Preview
    # Renders a single expandable text in a constrained container
    def default
      render_with_template
    end

    # Renders text that fits without truncation (expander stays hidden)
    def short_text
      render(OpPrimer::ExpandableTextComponent.new) { "Short text" }
    end

    # Renders expandable text inside a table, mimicking the Permissions Report layout
    def in_table
      render_with_template
    end

    # Interactive playground
    # @param text text The text content to display
    # @param width range { min: 100, max: 600, step: 10 } Container width in pixels
    def playground(text: "Automatically managed project folders: Share files and manage permissions", width: 200)
      render_with_template(locals: { text:, width: })
    end
  end
end
