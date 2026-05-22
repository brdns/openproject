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
#
module OpPrimer
  class ExpandableTextComponent < Primer::Component
    TRUNCATION_MODES = %i[horizontal vertical].freeze

    attr_reader :truncation, :lines, :inline

    def initialize(truncation: :horizontal, lines: 3, inline: true, expander_arguments: {}, **system_arguments)
      super()

      raise ArgumentError, "truncation must be one of #{TRUNCATION_MODES}" unless TRUNCATION_MODES.include?(truncation)

      @truncation = truncation
      @lines = lines
      @inline = inline
      @expander_arguments = expander_arguments

      @system_arguments = deny_tag_argument(**system_arguments)
      @system_arguments[:tag] = :div
      @system_arguments[:display] = :flex
      @system_arguments[:align_items] = truncation == :vertical ? :flex_start : :baseline
      @system_arguments[:data] = merge_data(
        @system_arguments,
        data: {
          controller: "truncation",
          truncation_mode_value: truncation,
          truncation_inline_value: inline
        }
      )
      @system_arguments[:classes] = class_names(
        @system_arguments[:classes],
        "gap-1 min-width-0"
      )
    end

    def expander_system_arguments
      base = {
        hidden: true,
        mt: 1,
        aria: { label: t(:"js.label_expand_text") },
        data: { truncation_target: "expander" }
      }
      base.deep_merge(@expander_arguments)
    end
  end
end
