# frozen_string_literal: true

class CreatePublicContentTables < ActiveRecord::Migration[8.1]
  EDITORIAL_STATUSES = %w[draft in_review approved published archived].freeze

  def change
    create_table :services do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.string :category
      t.text :audience
      t.jsonb :scope_items, null: false, default: []
      t.jsonb :process_steps, null: false, default: []
      t.integer :display_order, null: false, default: 0
      t.string :icon_key
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.text :published_audience
      t.jsonb :published_scope_items, null: false, default: []
      t.jsonb :published_process_steps, null: false, default: []
      t.integer :published_display_order
      t.string :published_icon_key
      t.jsonb :published_seo, null: false, default: {}
      t.references :created_by_membership, foreign_key: { to_table: :memberships }
      t.references :updated_by_membership, foreign_key: { to_table: :memberships }
      t.references :approved_by_membership, foreign_key: { to_table: :memberships }
      t.references :published_by_membership, foreign_key: { to_table: :memberships }
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
    end

    add_index :services, %i[organization_id slug], unique: true
    add_index :services, %i[status display_order]
    add_check_constraint :services,
                         "status IN ('draft', 'in_review', 'approved', 'published', 'archived')",
                         name: "services_status_check"

    create_table :public_site_pages do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :page_key, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.jsonb :page_data, null: false, default: {}
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.jsonb :published_page_data, null: false, default: {}
      t.jsonb :published_seo, null: false, default: {}
      t.references :created_by_membership, foreign_key: { to_table: :memberships }
      t.references :updated_by_membership, foreign_key: { to_table: :memberships }
      t.references :approved_by_membership, foreign_key: { to_table: :memberships }
      t.references :published_by_membership, foreign_key: { to_table: :memberships }
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
    end

    add_index :public_site_pages, %i[organization_id page_key], unique: true
    add_index :public_site_pages, :status
    add_check_constraint :public_site_pages,
                         "status IN ('draft', 'in_review', 'approved', 'published', 'archived')",
                         name: "public_site_pages_status_check"
    add_check_constraint :public_site_pages,
                         "page_key IN ('homepage', 'about', 'industries', 'how_we_work', 'contact')",
                         name: "public_site_pages_page_key_check"
  end
end
