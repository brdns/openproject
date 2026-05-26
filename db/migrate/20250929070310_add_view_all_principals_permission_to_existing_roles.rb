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

class AddViewAllPrincipalsPermissionToExistingRoles < ActiveRecord::Migration[8.0]
  def up
    # Add global role "View all users (migration)"
    execute <<~SQL.squish
      INSERT INTO roles (name, type, builtin, created_at, updated_at)
      SELECT 'View all users (migration)', 'GlobalRole', 0, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM roles WHERE type = 'GlobalRole' AND name = 'View all users (migration)'
      )
    SQL

    # Add the view_all_principals permission to that role
    execute <<~SQL.squish
      INSERT INTO role_permissions (permission, role_id, created_at, updated_at)
      SELECT 'view_all_principals', r.id, NOW(), NOW()
      FROM roles r
      WHERE r.type = 'GlobalRole' AND r.name = 'View all users (migration)'
        AND NOT EXISTS (
          SELECT 1 FROM role_permissions rp
          WHERE rp.role_id = r.id AND rp.permission = 'view_all_principals'
        )
    SQL

    # Grant view_all_principals to all roles that already have manage_user
    # (ensures Edit users retains its dependency on View users)
    execute <<~SQL.squish
      INSERT INTO role_permissions (permission, role_id, created_at, updated_at)
      SELECT 'view_all_principals', rp.role_id, NOW(), NOW()
      FROM role_permissions rp
      WHERE rp.permission = 'manage_user'
        AND NOT EXISTS (
          SELECT 1 FROM role_permissions rp2
          WHERE rp2.role_id = rp.role_id AND rp2.permission = 'view_all_principals'
        )
    SQL

    # Create a global membership for each user who has manage_members in any project
    # and does not already have one (project_id IS NULL, no entity)
    execute <<~SQL.squish
      INSERT INTO members (user_id, project_id, created_at, updated_at)
      SELECT DISTINCT u.id, NULL, NOW(), NOW()
      FROM users u
      JOIN members m      ON m.user_id    = u.id AND m.project_id IS NOT NULL
      JOIN member_roles mr ON mr.member_id = m.id
      JOIN roles r         ON r.id         = mr.role_id AND r.type = 'ProjectRole'
      JOIN role_permissions rp ON rp.role_id = r.id AND rp.permission = 'manage_members'
      WHERE u.type != 'PlaceholderUser'
        AND NOT EXISTS (
          SELECT 1 FROM members gm
          WHERE gm.user_id      = u.id
            AND gm.project_id   IS NULL
            AND gm.entity_type  IS NULL
            AND gm.entity_id    IS NULL
        )
    SQL

    # Assign the migration global role to those global memberships
    execute <<~SQL.squish
      INSERT INTO member_roles (member_id, role_id)
      SELECT m.id, r.id
      FROM members m
      CROSS JOIN roles r
      WHERE m.project_id  IS NULL
        AND m.entity_type IS NULL
        AND r.type = 'GlobalRole' AND r.name = 'View all users (migration)'
        AND m.user_id IN (
          SELECT DISTINCT u.id
          FROM users u
          JOIN members pm      ON pm.user_id    = u.id AND pm.project_id IS NOT NULL
          JOIN member_roles mr ON mr.member_id  = pm.id
          JOIN roles pr        ON pr.id         = mr.role_id AND pr.type = 'ProjectRole'
          JOIN role_permissions rp ON rp.role_id = pr.id AND rp.permission = 'manage_members'
          WHERE u.type != 'PlaceholderUser'
        )
        AND NOT EXISTS (
          SELECT 1 FROM member_roles mr
          WHERE mr.member_id     = m.id
            AND mr.role_id       = r.id
            AND mr.inherited_from IS NULL
        )
    SQL
  end

  def down
    # Remove view_all_principals from all GlobalRoles
    execute <<~SQL.squish
      DELETE FROM role_permissions
      WHERE permission = 'view_all_principals'
        AND role_id IN (SELECT id FROM roles WHERE type = 'GlobalRole')
    SQL

    # Remove the migration role's direct member_role assignments
    execute <<~SQL.squish
      DELETE FROM member_roles
      WHERE role_id IN (
        SELECT id FROM roles WHERE type = 'GlobalRole' AND name = 'View all users (migration)'
      )
      AND inherited_from IS NULL
    SQL

    # Clean up global memberships that now have no remaining roles
    execute <<~SQL.squish
      DELETE FROM members
      WHERE project_id  IS NULL
        AND entity_type IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM member_roles mr WHERE mr.member_id = members.id
        )
    SQL

    # Delete the migration role itself
    execute <<~SQL.squish
      DELETE FROM roles WHERE type = 'GlobalRole' AND name = 'View all users (migration)'
    SQL
  end
end
