# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_22_103002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "organization_id"
    t.bigint "actor_membership_id"
    t.string "event_type", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_membership_id"], name: "index_audit_events_on_actor_membership_id"
    t.index ["event_type", "occurred_at"], name: "index_audit_events_on_event_type_and_occurred_at"
    t.index ["organization_id", "occurred_at"], name: "index_audit_events_on_organization_id_and_occurred_at"
    t.index ["organization_id"], name: "index_audit_events_on_organization_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject_type_and_subject_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "email", null: false
    t.string "role_key", null: false
    t.string "token_digest", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_membership_id", null: false
    t.bigint "accepted_by_user_id"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_user_id"], name: "index_invitations_on_accepted_by_user_id"
    t.index ["email", "organization_id"], name: "index_invitations_on_email_and_organization_id"
    t.index ["invited_by_membership_id"], name: "index_invitations_on_invited_by_membership_id"
    t.index ["organization_id", "status"], name: "index_invitations_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token_digest"], name: "index_invitations_unique_pending_token_digest", unique: true, where: "((status)::text = 'pending'::text)"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'accepted'::character varying::text, 'revoked'::character varying::text, 'expired'::character varying::text])", name: "invitations_status_check"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "role_key", null: false
    t.string "status", default: "invited", null: false
    t.integer "permission_epoch", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "invited_at"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status"], name: "index_memberships_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id", "status"], name: "index_memberships_on_user_id_and_status"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['invited'::character varying, 'active'::character varying, 'suspended'::character varying, 'removed'::character varying]::text[])", name: "memberships_status_check"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "kind", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.jsonb "profile"
    t.jsonb "settings"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "status"], name: "index_organizations_on_kind_and_status"
    t.index ["kind"], name: "index_organizations_unique_active_ant_marine", unique: true, where: "(((kind)::text = 'ant_marine'::text) AND (archived_at IS NULL))"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['ant_marine'::character varying, 'client'::character varying]::text[])", name: "organizations_kind_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "organizations_status_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "membership_id"
    t.string "ip_address"
    t.string "user_agent"
    t.integer "security_version_at_issue", default: 0, null: false
    t.datetime "revoked_at"
    t.datetime "expires_at", null: false
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["membership_id"], name: "index_sessions_on_membership_id"
    t.index ["user_id", "revoked_at"], name: "index_sessions_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "status", default: "active", null: false
    t.integer "security_version", default: 0, null: false
    t.datetime "email_verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "full_name"
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "users_status_check"
  end

  add_foreign_key "audit_events", "memberships", column: "actor_membership_id"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "invitations", "memberships", column: "invited_by_membership_id"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "accepted_by_user_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "memberships"
  add_foreign_key "sessions", "users"
end
