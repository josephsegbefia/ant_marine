# frozen_string_literal: true

# F4-05: projects, assignments, milestones, tasks, schedule events, status events, client updates.
class F405ProjectManagement < ActiveRecord::Migration[8.1]
  def up
    create_table :projects do |t|
      t.string :reference_number, null: false
      t.string :title, null: false
      t.references :operating_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :client_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :service, foreign_key: true
      t.references :service_inquiry, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true, index: { unique: true }
      t.references :quote_response, null: false, foreign_key: true, index: { unique: true }
      t.references :quote_portal_release, null: false, foreign_key: true
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :coordinator_membership, foreign_key: { to_table: :memberships }
      t.string :internal_status, null: false, default: "planning"
      t.string :client_status, null: false, default: "planning"
      t.string :mode, null: false, default: "simulated"
      t.string :location
      t.string :vessel_name
      t.string :vessel_identifier
      t.text :operational_description
      t.text :internal_notes
      t.date :proposed_start_on
      t.date :target_completion_on
      t.jsonb :commercial_snapshot, null: false, default: {}
      t.datetime :archived_at
      t.timestamps
    end

    add_index :projects, :reference_number, unique: true
    add_index :projects, [ :operating_organization_id, :internal_status ]
    add_index :projects, [ :client_organization_id, :client_status ]
    add_index :projects, :mode

    execute <<~SQL
      ALTER TABLE projects
        ADD CONSTRAINT projects_internal_status_check
        CHECK (internal_status IN (
          'planning','scheduled','in_progress','technical_review','report_ready',
          'completed','closed','on_hold','cancelled'
        ));
      ALTER TABLE projects
        ADD CONSTRAINT projects_client_status_check
        CHECK (client_status IN (
          'planning','scheduled','in_progress','on_hold','completed','cancelled','closed'
        ));
      ALTER TABLE projects
        ADD CONSTRAINT projects_mode_check
        CHECK (mode IN ('simulated'));
      ALTER TABLE projects
        ADD CONSTRAINT projects_title_length CHECK (char_length(title) BETWEEN 1 AND 200);
    SQL

    create_table :assignments do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.string :assignment_kind, null: false
      t.string :access_scope, null: false
      t.boolean :active, null: false, default: true
      t.datetime :acknowledged_at
      t.references :assigned_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :reason
      t.datetime :ended_at
      t.timestamps
    end

    add_index :assignments, [ :project_id, :user_id, :assignment_kind ],
              unique: true, where: "active = TRUE",
              name: "index_assignments_unique_active_kind"
    add_index :assignments, [ :user_id, :active ]
    add_index :assignments, [ :project_id, :active ]

    execute <<~SQL
      ALTER TABLE assignments
        ADD CONSTRAINT assignments_kind_check
        CHECK (assignment_kind IN (
          'coordinator','lead_surveyor','surveyor','technical_reviewer','collaborator'
        ));
      ALTER TABLE assignments
        ADD CONSTRAINT assignments_access_scope_check
        CHECK (access_scope IN ('delivery','review','collaborator'));
    SQL

    create_table :project_milestones do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :kind, null: false, default: "operational"
      t.integer :position, null: false, default: 0
      t.references :responsible_membership, foreign_key: { to_table: :memberships }
      t.date :target_on
      t.string :status, null: false, default: "pending"
      t.datetime :completed_at
      t.references :completed_by_membership, foreign_key: { to_table: :memberships }
      t.boolean :counts_toward_progress, null: false, default: true
      t.timestamps
    end

    add_index :project_milestones, [ :project_id, :position ]

    execute <<~SQL
      ALTER TABLE project_milestones
        ADD CONSTRAINT project_milestones_status_check
        CHECK (status IN ('pending','completed','cancelled'));
      ALTER TABLE project_milestones
        ADD CONSTRAINT project_milestones_kind_check
        CHECK (kind IN (
          'project_initiated','planning','mobilization','site_work',
          'technical_review','report_release','project_completion','operational'
        ));
    SQL

    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.references :assignee_membership, foreign_key: { to_table: :memberships }
      t.string :priority, null: false, default: "normal"
      t.string :status, null: false, default: "todo"
      t.date :due_on
      t.datetime :completed_at
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :notes
      t.timestamps
    end

    add_index :tasks, [ :project_id, :status ]
    add_index :tasks, [ :assignee_membership_id, :status ]
    add_index :tasks, :due_on

    execute <<~SQL
      ALTER TABLE tasks
        ADD CONSTRAINT tasks_status_check
        CHECK (status IN ('todo','in_progress','blocked','completed','cancelled'));
      ALTER TABLE tasks
        ADD CONSTRAINT tasks_priority_check
        CHECK (priority IN ('low','normal','high','urgent'));
      ALTER TABLE tasks
        ADD CONSTRAINT tasks_title_length CHECK (char_length(title) BETWEEN 1 AND 200);
    SQL

    create_table :schedule_events do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :activity_type, null: false, default: "site_work"
      t.string :confirmation_state, null: false, default: "proposed"
      t.string :location
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.references :responsible_membership, foreign_key: { to_table: :memberships }
      t.text :internal_notes
      t.text :cancellation_reason
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :confirmed_by_membership, foreign_key: { to_table: :memberships }
      t.datetime :confirmed_at
      t.boolean :conflict_override, null: false, default: false
      t.text :conflict_override_reason
      t.timestamps
    end

    add_index :schedule_events, [ :project_id, :starts_at ]
    add_index :schedule_events, [ :responsible_membership_id, :starts_at ]
    add_index :schedule_events, :confirmation_state

    execute <<~SQL
      ALTER TABLE schedule_events
        ADD CONSTRAINT schedule_events_confirmation_state_check
        CHECK (confirmation_state IN (
          'proposed','confirmed','rescheduled','cancelled','completed'
        ));
      ALTER TABLE schedule_events
        ADD CONSTRAINT schedule_events_activity_type_check
        CHECK (activity_type IN (
          'site_work','mobilization','meeting','inspection','other'
        ));
      ALTER TABLE schedule_events
        ADD CONSTRAINT schedule_events_time_order_check
        CHECK (starts_at < ends_at);
    SQL

    create_table :project_status_events do |t|
      t.references :project, null: false, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.references :actor_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :reason
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :project_status_events, [ :project_id, :occurred_at ]

    create_table :project_updates do |t|
      t.references :project, null: false, foreign_key: true
      t.references :author_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :body, null: false
      t.string :visibility, null: false, default: "client"
      t.datetime :published_at, null: false
      t.timestamps
    end

    add_index :project_updates, [ :project_id, :published_at ]

    execute <<~SQL
      ALTER TABLE project_updates
        ADD CONSTRAINT project_updates_visibility_check
        CHECK (visibility IN ('client','internal'));
      ALTER TABLE project_updates
        ADD CONSTRAINT project_updates_body_length CHECK (char_length(body) BETWEEN 1 AND 5000);
    SQL

    # Expand staff notification kinds for project events
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (
          'new_enquiry','enquiry_assigned','enquiry_reassigned_away','clarification_answered',
          'quote_accepted','quote_declined','quote_changes_requested',
          'project_created','project_assigned','project_assignment_changed',
          'task_assigned','schedule_confirmed','schedule_cancelled','project_update'
        ));
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE staff_notifications DROP CONSTRAINT IF EXISTS staff_notifications_kind_check;
      ALTER TABLE staff_notifications
        ADD CONSTRAINT staff_notifications_kind_check
        CHECK (kind IN (
          'new_enquiry','enquiry_assigned','enquiry_reassigned_away','clarification_answered',
          'quote_accepted','quote_declined','quote_changes_requested'
        ));
    SQL

    drop_table :project_updates
    drop_table :project_status_events
    drop_table :schedule_events
    drop_table :tasks
    drop_table :project_milestones
    drop_table :assignments
    drop_table :projects
  end
end
