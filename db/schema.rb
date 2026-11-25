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

ActiveRecord::Schema[8.1].define(version: 2026_11_25_230000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.string "category"
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.string "published_category"
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_articles_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_articles_on_created_by_membership_id"
    t.index ["organization_id", "slug"], name: "index_articles_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_articles_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_articles_on_published_by_membership_id"
    t.index ["status", "published_at"], name: "index_articles_on_status_and_published_at"
    t.index ["updated_by_membership_id"], name: "index_articles_on_updated_by_membership_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])", name: "articles_status_check"
  end

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

  create_table "case_studies", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.string "service_category"
    t.string "industry"
    t.text "release_basis"
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.string "published_service_category"
    t.string "published_industry"
    t.text "published_client_challenge"
    t.text "published_approach"
    t.text "published_work_performed"
    t.text "published_outcome"
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_case_studies_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_case_studies_on_created_by_membership_id"
    t.index ["organization_id", "slug"], name: "index_case_studies_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_case_studies_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_case_studies_on_published_by_membership_id"
    t.index ["status", "published_at"], name: "index_case_studies_on_status_and_published_at"
    t.index ["updated_by_membership_id"], name: "index_case_studies_on_updated_by_membership_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])", name: "case_studies_status_check"
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

  create_table "permission_overrides", force: :cascade do |t|
    t.bigint "membership_id", null: false
    t.bigint "permission_id", null: false
    t.string "effect", null: false
    t.bigint "granted_by_membership_id", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_membership_id"], name: "index_permission_overrides_on_granted_by_membership_id"
    t.index ["membership_id", "permission_id"], name: "index_permission_overrides_on_membership_id_and_permission_id", unique: true
    t.index ["membership_id"], name: "index_permission_overrides_on_membership_id"
    t.index ["permission_id"], name: "index_permission_overrides_on_permission_id"
    t.check_constraint "effect::text = ANY (ARRAY['allow'::character varying::text, 'deny'::character varying::text])", name: "permission_overrides_effect_check"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "key", null: false
    t.string "display_name", null: false
    t.text "description"
    t.string "category", null: false
    t.string "domain", null: false
    t.string "override_rule", default: "yes", null: false
    t.integer "catalogue_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
    t.check_constraint "override_rule::text = ANY (ARRAY['yes'::character varying::text, 'protected'::character varying::text, 'deny_only'::character varying::text])", name: "permissions_override_rule_check"
  end

  create_table "public_resources", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.string "resource_category"
    t.string "related_content_label"
    t.boolean "file_release_enabled", default: false, null: false
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.string "published_resource_category"
    t.string "published_related_content_label"
    t.boolean "published_file_release_enabled", default: false, null: false
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_public_resources_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_public_resources_on_created_by_membership_id"
    t.index ["organization_id", "slug"], name: "index_public_resources_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_public_resources_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_public_resources_on_published_by_membership_id"
    t.index ["status", "published_at"], name: "index_public_resources_on_status_and_published_at"
    t.index ["updated_by_membership_id"], name: "index_public_resources_on_updated_by_membership_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])", name: "public_resources_status_check"
  end

  create_table "public_site_pages", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "page_key", null: false
    t.string "title", null: false
    t.text "summary"
    t.jsonb "page_data", default: {}, null: false
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.jsonb "published_page_data", default: {}, null: false
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_public_site_pages_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_public_site_pages_on_created_by_membership_id"
    t.index ["organization_id", "page_key"], name: "index_public_site_pages_on_organization_id_and_page_key", unique: true
    t.index ["organization_id"], name: "index_public_site_pages_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_public_site_pages_on_published_by_membership_id"
    t.index ["status"], name: "index_public_site_pages_on_status"
    t.index ["updated_by_membership_id"], name: "index_public_site_pages_on_updated_by_membership_id"
    t.check_constraint "page_key::text = ANY (ARRAY['homepage'::character varying, 'about'::character varying, 'industries'::character varying, 'how_we_work'::character varying, 'contact'::character varying]::text[])", name: "public_site_pages_page_key_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "public_site_pages_status_check"
  end

  create_table "quote_deliveries", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "quote_id", null: false
    t.bigint "quote_revision_id", null: false
    t.bigint "requested_by_membership_id", null: false
    t.bigint "dispatched_by_membership_id"
    t.string "channel", default: "email", null: false
    t.string "status", default: "prepared", null: false
    t.string "delivery_adapter", null: false
    t.string "idempotency_key", null: false
    t.string "recipient_email", null: false
    t.string "recipient_name"
    t.string "recipient_company"
    t.integer "attempt_count", default: 0, null: false
    t.datetime "prepared_at", null: false
    t.datetime "queued_at"
    t.datetime "attempted_at"
    t.datetime "accepted_at"
    t.datetime "failed_at"
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.string "provider_message_id"
    t.string "provider_response"
    t.string "failure_reason"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispatched_by_membership_id"], name: "index_quote_deliveries_on_dispatched_by_membership_id"
    t.index ["idempotency_key"], name: "index_quote_deliveries_on_idempotency_key", unique: true
    t.index ["organization_id"], name: "index_quote_deliveries_on_organization_id"
    t.index ["quote_id"], name: "index_quote_deliveries_on_quote_id"
    t.index ["quote_revision_id"], name: "index_quote_deliveries_on_quote_revision_id"
    t.index ["quote_revision_id"], name: "index_quote_deliveries_one_live_per_revision", unique: true, where: "((status)::text = ANY ((ARRAY['prepared'::character varying, 'queued'::character varying, 'sending'::character varying, 'accepted_by_provider'::character varying, 'outcome_unknown'::character varying, 'delivery_confirmed'::character varying])::text[]))"
    t.index ["requested_by_membership_id"], name: "index_quote_deliveries_on_requested_by_membership_id"
    t.check_constraint "channel::text = 'email'::text", name: "quote_deliveries_channel_check"
    t.check_constraint "status::text <> 'accepted_by_provider'::text OR accepted_at IS NOT NULL", name: "quote_deliveries_accepted_has_timestamp"
    t.check_constraint "status::text <> 'delivery_confirmed'::text OR confirmed_at IS NOT NULL AND provider_message_id IS NOT NULL", name: "quote_deliveries_confirmation_needs_evidence"
    t.check_constraint "status::text = ANY (ARRAY['prepared'::character varying, 'queued'::character varying, 'sending'::character varying, 'accepted_by_provider'::character varying, 'failed'::character varying, 'outcome_unknown'::character varying, 'delivery_confirmed'::character varying, 'cancelled'::character varying]::text[])", name: "quote_deliveries_status_check"
  end

  create_table "quote_line_items", force: :cascade do |t|
    t.bigint "quote_revision_id", null: false
    t.integer "position", default: 0, null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "1.0", null: false
    t.string "unit", default: "each", null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.bigint "line_total_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_revision_id", "position"], name: "index_quote_line_items_on_quote_revision_id_and_position"
    t.index ["quote_revision_id"], name: "index_quote_line_items_on_quote_revision_id"
    t.check_constraint "quantity > 0::numeric", name: "quote_line_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND line_total_cents >= 0", name: "quote_line_items_amounts_non_negative"
  end

  create_table "quote_revisions", force: :cascade do |t|
    t.bigint "quote_id", null: false
    t.integer "version_number", null: false
    t.string "revision_status", default: "draft", null: false
    t.string "title"
    t.text "scope_description"
    t.text "deliverables"
    t.text "exclusions"
    t.text "additional_requirements"
    t.string "currency", default: "GHS", null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.date "valid_until"
    t.text "payment_terms"
    t.text "commercial_exclusions"
    t.text "additional_conditions"
    t.text "internal_notes"
    t.jsonb "recipient_snapshot", default: {}, null: false
    t.datetime "frozen_at"
    t.bigint "approved_by_membership_id"
    t.datetime "approved_at"
    t.bigint "issued_by_membership_id"
    t.datetime "issued_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "prepared_by_membership_id"
    t.bigint "submitted_by_membership_id"
    t.bigint "contributor_membership_ids", default: [], null: false, array: true
    t.bigint "predecessor_revision_id"
    t.bigint "superseded_by_revision_id"
    t.text "revision_reason"
    t.datetime "superseded_at"
    t.index ["predecessor_revision_id"], name: "index_quote_revisions_on_predecessor_revision_id"
    t.index ["prepared_by_membership_id"], name: "index_quote_revisions_on_prepared_by_membership_id"
    t.index ["quote_id", "version_number"], name: "index_quote_revisions_on_quote_id_and_version_number", unique: true
    t.index ["quote_id"], name: "index_quote_revisions_on_quote_id"
    t.index ["submitted_by_membership_id"], name: "index_quote_revisions_on_submitted_by_membership_id"
    t.index ["superseded_by_revision_id"], name: "index_quote_revisions_on_superseded_by_revision_id"
    t.check_constraint "(revision_status::text <> ALL (ARRAY['approved'::character varying, 'issued'::character varying]::text[])) OR frozen_at IS NOT NULL", name: "quote_revisions_approved_are_frozen"
    t.check_constraint "approved_by_membership_id IS NULL OR approved_by_membership_id IS DISTINCT FROM prepared_by_membership_id AND approved_by_membership_id IS DISTINCT FROM submitted_by_membership_id AND NOT (approved_by_membership_id = ANY (contributor_membership_ids))", name: "quote_revisions_approver_is_independent"
    t.check_constraint "currency::text = ANY (ARRAY['GHS'::character varying, 'USD'::character varying, 'EUR'::character varying, 'GBP'::character varying]::text[])", name: "quote_revisions_currency_check"
    t.check_constraint "revision_reason IS NULL OR char_length(revision_reason) <= 500", name: "quote_revisions_reason_length"
    t.check_constraint "revision_status::text <> 'superseded'::text OR superseded_at IS NOT NULL", name: "quote_revisions_superseded_have_timestamp"
    t.check_constraint "revision_status::text = ANY (ARRAY['draft'::character varying, 'pending_review'::character varying, 'approved'::character varying, 'issued'::character varying, 'superseded'::character varying]::text[])", name: "quote_revisions_status_check"
    t.check_constraint "subtotal_cents >= 0 AND total_cents >= 0", name: "quote_revisions_totals_non_negative"
    t.check_constraint "version_number = 1 OR predecessor_revision_id IS NOT NULL AND revision_reason IS NOT NULL", name: "quote_revisions_later_versions_have_lineage"
  end

  create_table "quotes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "client_organization_id"
    t.bigint "service_id"
    t.string "reference_number", null: false
    t.string "status", default: "draft", null: false
    t.string "delivery_state", default: "not_prepared", null: false
    t.jsonb "prospective_client", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "current_revision_id"
    t.bigint "service_inquiry_id"
    t.index ["client_organization_id"], name: "index_quotes_on_client_organization_id"
    t.index ["current_revision_id"], name: "index_quotes_on_current_revision_id"
    t.index ["organization_id", "reference_number"], name: "index_quotes_on_organization_id_and_reference_number", unique: true
    t.index ["organization_id"], name: "index_quotes_on_organization_id"
    t.index ["service_id"], name: "index_quotes_on_service_id"
    t.index ["service_inquiry_id"], name: "index_quotes_on_service_inquiry_id"
    t.index ["service_inquiry_id"], name: "index_quotes_one_open_quote_per_inquiry", unique: true, where: "((service_inquiry_id IS NOT NULL) AND ((status)::text <> ALL ((ARRAY['withdrawn'::character varying, 'superseded'::character varying])::text[])))"
    t.index ["status"], name: "index_quotes_on_status"
    t.check_constraint "delivery_state::text = ANY (ARRAY['not_prepared'::character varying, 'prepared'::character varying, 'delivery_pending'::character varying, 'delivery_attempted'::character varying, 'delivered'::character varying, 'delivery_failed'::character varying]::text[])", name: "quotes_delivery_state_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'pending_review'::character varying, 'returned_for_correction'::character varying, 'approved_for_issuance'::character varying, 'issued'::character varying, 'withdrawn'::character varying, 'superseded'::character varying]::text[])", name: "quotes_status_check"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.string "role_key", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_key", "permission_id"], name: "index_role_permissions_on_role_key_and_permission_id", unique: true
    t.index ["role_key"], name: "index_role_permissions_on_role_key"
  end

  create_table "service_inquiries", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "client_organization_id"
    t.bigint "service_id"
    t.string "reference_number", null: false
    t.string "channel", default: "public_form", null: false
    t.string "current_status", default: "submitted", null: false
    t.string "service_title_snapshot"
    t.string "company_name", null: false
    t.string "contact_name", null: false
    t.string "contact_email", null: false
    t.string "contact_phone"
    t.string "project_name"
    t.string "vessel_name"
    t.string "location", null: false
    t.text "description", null: false
    t.date "preferred_date"
    t.string "submission_token", null: false
    t.jsonb "submission_metadata", default: {}, null: false
    t.datetime "submitted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assigned_membership_id"
    t.bigint "duplicate_of_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "review_started_at"
    t.datetime "qualified_at"
    t.text "qualification_note"
    t.string "closure_reason"
    t.text "closure_note"
    t.datetime "closed_at"
    t.index ["assigned_membership_id"], name: "index_service_inquiries_on_assigned_membership_id"
    t.index ["client_organization_id"], name: "index_service_inquiries_on_client_organization_id"
    t.index ["current_status", "created_at"], name: "index_service_inquiries_on_current_status_and_created_at"
    t.index ["duplicate_of_id"], name: "index_service_inquiries_on_duplicate_of_id"
    t.index ["organization_id", "assigned_membership_id", "current_status"], name: "index_service_inquiries_on_org_assignee_status"
    t.index ["organization_id"], name: "index_service_inquiries_on_organization_id"
    t.index ["reference_number"], name: "index_service_inquiries_on_reference_number", unique: true
    t.index ["service_id"], name: "index_service_inquiries_on_service_id"
    t.index ["submission_token"], name: "index_service_inquiries_on_submission_token", unique: true
    t.check_constraint "(current_status::text = ANY (ARRAY['closed'::character varying, 'unqualified'::character varying, 'merged'::character varying]::text[])) = (closure_reason IS NOT NULL AND closed_at IS NOT NULL)", name: "service_inquiries_closed_states_have_reason"
    t.check_constraint "channel::text = ANY (ARRAY['public_form'::character varying, 'contact_form'::character varying, 'client_portal'::character varying, 'staff'::character varying]::text[])", name: "service_inquiries_channel_check"
    t.check_constraint "char_length(COALESCE(qualification_note, ''::text)) <= 2000 AND char_length(COALESCE(closure_note, ''::text)) <= 2000", name: "service_inquiries_triage_note_length"
    t.check_constraint "char_length(description) <= 4000 AND char_length(company_name::text) <= 160 AND char_length(contact_name::text) <= 120 AND char_length(contact_email::text) <= 254 AND char_length(location::text) <= 200", name: "service_inquiries_length_check"
    t.check_constraint "closure_reason IS NULL OR (closure_reason::text = ANY (ARRAY['cancelled'::character varying, 'not_proceeding'::character varying, 'other'::character varying, 'outside_scope'::character varying, 'duplicate'::character varying]::text[]))", name: "service_inquiries_closure_reason_check"
    t.check_constraint "closure_reason::text IS DISTINCT FROM 'other'::text OR closure_note IS NOT NULL", name: "service_inquiries_other_reason_has_note"
    t.check_constraint "current_status::text <> 'closed'::text OR (closure_reason::text = ANY (ARRAY['cancelled'::character varying, 'not_proceeding'::character varying, 'other'::character varying]::text[]))", name: "service_inquiries_closed_reason_matches"
    t.check_constraint "current_status::text <> 'merged'::text OR closure_reason::text = 'duplicate'::text AND duplicate_of_id IS NOT NULL AND duplicate_of_id <> id", name: "service_inquiries_merged_has_canonical"
    t.check_constraint "current_status::text <> 'unqualified'::text OR closure_reason::text = 'outside_scope'::text AND closure_note IS NOT NULL", name: "service_inquiries_unqualified_has_note"
    t.check_constraint "current_status::text = ANY (ARRAY['submitted'::character varying, 'under_review'::character varying, 'needs_clarification'::character varying, 'qualified'::character varying, 'unqualified'::character varying, 'merged'::character varying, 'closed'::character varying]::text[])", name: "service_inquiries_status_check"
  end

  create_table "service_inquiry_assignments", force: :cascade do |t|
    t.bigint "service_inquiry_id", null: false
    t.bigint "previous_membership_id"
    t.bigint "new_membership_id"
    t.bigint "actor_membership_id", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.index ["actor_membership_id"], name: "index_service_inquiry_assignments_on_actor_membership_id"
    t.index ["new_membership_id"], name: "index_service_inquiry_assignments_on_new_membership_id"
    t.index ["previous_membership_id"], name: "index_service_inquiry_assignments_on_previous_membership_id"
    t.index ["service_inquiry_id"], name: "index_service_inquiry_assignments_on_service_inquiry_id"
    t.check_constraint "previous_membership_id IS DISTINCT FROM new_membership_id", name: "service_inquiry_assignments_change_check"
    t.check_constraint "reason IS NULL OR char_length(reason) <= 500", name: "service_inquiry_assignments_reason_length"
  end

  create_table "service_inquiry_clarifications", force: :cascade do |t|
    t.bigint "service_inquiry_id", null: false
    t.bigint "created_by_membership_id", null: false
    t.string "subject", null: false
    t.text "questions", null: false
    t.text "prepared_message"
    t.string "status", default: "prepared", null: false
    t.string "contact_channel"
    t.datetime "contacted_at"
    t.bigint "contacted_by_membership_id"
    t.text "response_text"
    t.string "response_source"
    t.datetime "response_received_at"
    t.bigint "response_recorded_by_membership_id"
    t.datetime "withdrawn_at"
    t.bigint "withdrawn_by_membership_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contacted_by_membership_id"], name: "idx_on_contacted_by_membership_id_60558e5d9f"
    t.index ["created_by_membership_id"], name: "idx_on_created_by_membership_id_5421d8492b"
    t.index ["response_recorded_by_membership_id"], name: "idx_on_response_recorded_by_membership_id_e5ec9fb48e"
    t.index ["service_inquiry_id"], name: "index_service_inquiry_clarifications_on_service_inquiry_id"
    t.index ["withdrawn_by_membership_id"], name: "idx_on_withdrawn_by_membership_id_03eb4e1b68"
    t.check_constraint "char_length(subject::text) <= 160 AND char_length(questions) <= 2000 AND char_length(COALESCE(prepared_message, ''::text)) <= 4000 AND char_length(COALESCE(response_text, ''::text)) <= 4000", name: "service_inquiry_clarifications_length_check"
    t.check_constraint "contact_channel IS NULL OR (contact_channel::text = ANY (ARRAY['phone'::character varying, 'email_outside_system'::character varying, 'in_person'::character varying, 'other'::character varying]::text[]))", name: "service_inquiry_clarifications_channel_check"
    t.check_constraint "response_source IS NULL OR (response_source::text = ANY (ARRAY['phone'::character varying, 'email'::character varying, 'in_person'::character varying, 'other'::character varying]::text[]))", name: "service_inquiry_clarifications_source_check"
    t.check_constraint "status::text <> 'answered'::text OR response_text IS NOT NULL AND response_source IS NOT NULL AND response_received_at IS NOT NULL AND response_recorded_by_membership_id IS NOT NULL", name: "service_inquiry_clarifications_answer_recorded"
    t.check_constraint "status::text <> 'contacted_outside_system'::text OR contact_channel IS NOT NULL AND contacted_at IS NOT NULL AND contacted_by_membership_id IS NOT NULL", name: "service_inquiry_clarifications_contact_recorded"
    t.check_constraint "status::text <> 'withdrawn'::text OR withdrawn_at IS NOT NULL AND withdrawn_by_membership_id IS NOT NULL", name: "service_inquiry_clarifications_withdrawal_recorded"
    t.check_constraint "status::text = ANY (ARRAY['prepared'::character varying, 'contacted_outside_system'::character varying, 'answered'::character varying, 'withdrawn'::character varying]::text[])", name: "service_inquiry_clarifications_status_check"
  end

  create_table "service_inquiry_notes", force: :cascade do |t|
    t.bigint "service_inquiry_id", null: false
    t.bigint "author_membership_id", null: false
    t.bigint "corrects_note_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.index ["author_membership_id"], name: "index_service_inquiry_notes_on_author_membership_id"
    t.index ["corrects_note_id"], name: "index_service_inquiry_notes_on_corrects_note_id", unique: true
    t.index ["service_inquiry_id"], name: "index_service_inquiry_notes_on_service_inquiry_id"
    t.check_constraint "char_length(btrim(body)) > 0 AND char_length(body) <= 4000", name: "service_inquiry_notes_body_check"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.string "category"
    t.text "audience"
    t.jsonb "scope_items", default: [], null: false
    t.jsonb "process_steps", default: [], null: false
    t.integer "display_order", default: 0, null: false
    t.string "icon_key"
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.text "published_audience"
    t.jsonb "published_scope_items", default: [], null: false
    t.jsonb "published_process_steps", default: [], null: false
    t.integer "published_display_order"
    t.string "published_icon_key"
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_services_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_services_on_created_by_membership_id"
    t.index ["organization_id", "slug"], name: "index_services_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_services_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_services_on_published_by_membership_id"
    t.index ["status", "display_order"], name: "index_services_on_status_and_display_order"
    t.index ["updated_by_membership_id"], name: "index_services_on_updated_by_membership_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'in_review'::character varying, 'approved'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "services_status_check"
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
    t.integer "permission_epoch_at_issue", default: 0, null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["membership_id"], name: "index_sessions_on_membership_id"
    t.index ["user_id", "revoked_at"], name: "index_sessions_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "staff_notifications", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "recipient_membership_id", null: false
    t.bigint "audit_event_id", null: false
    t.string "kind", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "title", null: false
    t.string "dedupe_key", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.index ["audit_event_id"], name: "index_staff_notifications_on_audit_event_id"
    t.index ["organization_id"], name: "index_staff_notifications_on_organization_id"
    t.index ["recipient_membership_id", "dedupe_key"], name: "index_staff_notifications_on_recipient_and_dedupe_key", unique: true
    t.index ["recipient_membership_id", "read_at", "created_at"], name: "index_staff_notifications_on_recipient_unread"
    t.check_constraint "char_length(title::text) <= 200", name: "staff_notifications_title_length"
    t.check_constraint "kind::text = ANY (ARRAY['new_enquiry'::character varying, 'enquiry_assigned'::character varying, 'enquiry_reassigned_away'::character varying, 'clarification_answered'::character varying]::text[])", name: "staff_notifications_kind_check"
  end

  create_table "storage_assets", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "uploaded_by_membership_id", null: false
    t.string "scan_status", default: "pending_upload", null: false
    t.string "classification", default: "standard", null: false
    t.string "filename", null: false
    t.string "content_type", null: false
    t.bigint "byte_size", null: false
    t.string "checksum_sha256", null: false
    t.string "storage_key", null: false
    t.integer "encryption_key_version", null: false
    t.bigint "active_storage_blob_id"
    t.string "scan_result"
    t.datetime "scanned_at"
    t.string "rejected_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_storage_blob_id"], name: "index_storage_assets_on_active_storage_blob_id"
    t.index ["organization_id"], name: "index_storage_assets_on_organization_id"
    t.index ["scan_status"], name: "index_storage_assets_on_scan_status"
    t.index ["storage_key"], name: "index_storage_assets_on_storage_key", unique: true
    t.index ["uploaded_by_membership_id"], name: "index_storage_assets_on_uploaded_by_membership_id"
    t.check_constraint "classification::text = ANY (ARRAY['standard'::character varying, 'confidential'::character varying]::text[])", name: "storage_assets_classification_check"
    t.check_constraint "scan_status::text = ANY (ARRAY['pending_upload'::character varying, 'scanning'::character varying, 'available'::character varying, 'rejected'::character varying]::text[])", name: "storage_assets_scan_status_check"
  end

  create_table "training_offerings", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.text "audience"
    t.jsonb "learning_objectives", default: [], null: false
    t.jsonb "topics", default: [], null: false
    t.string "delivery_format"
    t.jsonb "seo", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "published_title"
    t.text "published_summary"
    t.text "published_body"
    t.text "published_audience"
    t.jsonb "published_learning_objectives", default: [], null: false
    t.jsonb "published_topics", default: [], null: false
    t.string "published_delivery_format"
    t.jsonb "published_seo", default: {}, null: false
    t.bigint "created_by_membership_id"
    t.bigint "updated_by_membership_id"
    t.bigint "approved_by_membership_id"
    t.bigint "published_by_membership_id"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_membership_id"], name: "index_training_offerings_on_approved_by_membership_id"
    t.index ["created_by_membership_id"], name: "index_training_offerings_on_created_by_membership_id"
    t.index ["organization_id", "slug"], name: "index_training_offerings_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_training_offerings_on_organization_id"
    t.index ["published_by_membership_id"], name: "index_training_offerings_on_published_by_membership_id"
    t.index ["status", "published_at"], name: "index_training_offerings_on_status_and_published_at"
    t.index ["updated_by_membership_id"], name: "index_training_offerings_on_updated_by_membership_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])", name: "training_offerings_status_check"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "memberships", column: "approved_by_membership_id"
  add_foreign_key "articles", "memberships", column: "created_by_membership_id"
  add_foreign_key "articles", "memberships", column: "published_by_membership_id"
  add_foreign_key "articles", "memberships", column: "updated_by_membership_id"
  add_foreign_key "articles", "organizations"
  add_foreign_key "audit_events", "memberships", column: "actor_membership_id"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "case_studies", "memberships", column: "approved_by_membership_id"
  add_foreign_key "case_studies", "memberships", column: "created_by_membership_id"
  add_foreign_key "case_studies", "memberships", column: "published_by_membership_id"
  add_foreign_key "case_studies", "memberships", column: "updated_by_membership_id"
  add_foreign_key "case_studies", "organizations"
  add_foreign_key "invitations", "memberships", column: "invited_by_membership_id"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "accepted_by_user_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "permission_overrides", "memberships"
  add_foreign_key "permission_overrides", "memberships", column: "granted_by_membership_id"
  add_foreign_key "permission_overrides", "permissions"
  add_foreign_key "public_resources", "memberships", column: "approved_by_membership_id"
  add_foreign_key "public_resources", "memberships", column: "created_by_membership_id"
  add_foreign_key "public_resources", "memberships", column: "published_by_membership_id"
  add_foreign_key "public_resources", "memberships", column: "updated_by_membership_id"
  add_foreign_key "public_resources", "organizations"
  add_foreign_key "public_site_pages", "memberships", column: "approved_by_membership_id"
  add_foreign_key "public_site_pages", "memberships", column: "created_by_membership_id"
  add_foreign_key "public_site_pages", "memberships", column: "published_by_membership_id"
  add_foreign_key "public_site_pages", "memberships", column: "updated_by_membership_id"
  add_foreign_key "public_site_pages", "organizations"
  add_foreign_key "quote_deliveries", "memberships", column: "dispatched_by_membership_id"
  add_foreign_key "quote_deliveries", "memberships", column: "requested_by_membership_id"
  add_foreign_key "quote_deliveries", "organizations"
  add_foreign_key "quote_deliveries", "quote_revisions"
  add_foreign_key "quote_deliveries", "quotes"
  add_foreign_key "quote_line_items", "quote_revisions"
  add_foreign_key "quote_revisions", "memberships", column: "prepared_by_membership_id"
  add_foreign_key "quote_revisions", "memberships", column: "submitted_by_membership_id"
  add_foreign_key "quote_revisions", "quote_revisions", column: "predecessor_revision_id"
  add_foreign_key "quote_revisions", "quote_revisions", column: "superseded_by_revision_id"
  add_foreign_key "quote_revisions", "quotes"
  add_foreign_key "quotes", "organizations"
  add_foreign_key "quotes", "organizations", column: "client_organization_id"
  add_foreign_key "quotes", "quote_revisions", column: "current_revision_id"
  add_foreign_key "quotes", "service_inquiries"
  add_foreign_key "quotes", "services"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "service_inquiries", "memberships", column: "assigned_membership_id"
  add_foreign_key "service_inquiries", "organizations"
  add_foreign_key "service_inquiries", "organizations", column: "client_organization_id"
  add_foreign_key "service_inquiries", "service_inquiries", column: "duplicate_of_id"
  add_foreign_key "service_inquiries", "services"
  add_foreign_key "service_inquiry_assignments", "memberships", column: "actor_membership_id"
  add_foreign_key "service_inquiry_assignments", "memberships", column: "new_membership_id"
  add_foreign_key "service_inquiry_assignments", "memberships", column: "previous_membership_id"
  add_foreign_key "service_inquiry_assignments", "service_inquiries"
  add_foreign_key "service_inquiry_clarifications", "memberships", column: "contacted_by_membership_id"
  add_foreign_key "service_inquiry_clarifications", "memberships", column: "created_by_membership_id"
  add_foreign_key "service_inquiry_clarifications", "memberships", column: "response_recorded_by_membership_id"
  add_foreign_key "service_inquiry_clarifications", "memberships", column: "withdrawn_by_membership_id"
  add_foreign_key "service_inquiry_clarifications", "service_inquiries"
  add_foreign_key "service_inquiry_notes", "memberships", column: "author_membership_id"
  add_foreign_key "service_inquiry_notes", "service_inquiries"
  add_foreign_key "service_inquiry_notes", "service_inquiry_notes", column: "corrects_note_id"
  add_foreign_key "services", "memberships", column: "approved_by_membership_id"
  add_foreign_key "services", "memberships", column: "created_by_membership_id"
  add_foreign_key "services", "memberships", column: "published_by_membership_id"
  add_foreign_key "services", "memberships", column: "updated_by_membership_id"
  add_foreign_key "services", "organizations"
  add_foreign_key "sessions", "memberships"
  add_foreign_key "sessions", "users"
  add_foreign_key "staff_notifications", "audit_events"
  add_foreign_key "staff_notifications", "memberships", column: "recipient_membership_id"
  add_foreign_key "staff_notifications", "organizations"
  add_foreign_key "storage_assets", "active_storage_blobs"
  add_foreign_key "storage_assets", "memberships", column: "uploaded_by_membership_id"
  add_foreign_key "storage_assets", "organizations"
  add_foreign_key "training_offerings", "memberships", column: "approved_by_membership_id"
  add_foreign_key "training_offerings", "memberships", column: "created_by_membership_id"
  add_foreign_key "training_offerings", "memberships", column: "published_by_membership_id"
  add_foreign_key "training_offerings", "memberships", column: "updated_by_membership_id"
  add_foreign_key "training_offerings", "organizations"
end
