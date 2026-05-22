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
    # Horizontal truncation with inline expansion (default)
    def default
      render_with_template
    end

    # Text that fits without truncation (expander stays hidden)
    def short_text
      render(OpPrimer::ExpandableTextComponent.new) { "Short text" }
    end

    # Horizontal truncation inside a table, mimicking the Permissions Report layout
    def in_table
      render_with_template
    end

    # Vertical truncation with inline expansion using line-clamp
    # @param lines range { min: 1, max: 6, step: 1 } Number of visible lines
    def vertical(lines: 3)
      render_with_template(locals: { lines: })
    end

    # Vertical truncation where the expander opens a dialog instead of expanding inline
    def dialog
      render_with_template
    end

    # Interactive playground for all modes
    # @param text text The text content to display
    # @param width range { min: 100, max: 600, step: 10 } Container width in pixels
    # @param truncation select { choices: [horizontal, vertical] } Truncation direction
    # @param lines range { min: 1, max: 6, step: 1 } Lines (vertical mode only)
    # @param inline toggle Expand inline or via external action
    def playground(text: "Automatically managed project folders: Share files and manage permissions",
                   width: 200, truncation: :horizontal, lines: 3, inline: true)
      render_with_template(locals: { text:, width:, truncation: truncation.to_sym, lines:, inline: })
    end
  end
end
