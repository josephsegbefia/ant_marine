# frozen_string_literal: true

class CreateF401bPublicContentTables < ActiveRecord::Migration[8.1]
  EDITORIAL_STATUSES = %w[draft in_review approved published archived].freeze

  def change
    create_table :articles do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.string :category
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.string :published_category
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
    add_index :articles, %i[organization_id slug], unique: true
    add_index :articles, %i[status published_at]
    add_check_constraint :articles,
      "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])",
      name: "articles_status_check"

    create_table :case_studies do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.string :service_category
      t.string :industry
      t.text :client_challenge
      t.text :approach
      t.text :work_performed
      t.text :outcome
      t.text :release_basis
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.string :published_service_category
      t.string :published_industry
      t.text :published_client_challenge
      t.text :published_approach
      t.text :published_work_performed
      t.text :published_outcome
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
    add_index :case_studies, %i[organization_id slug], unique: true
    add_index :case_studies, %i[status published_at]
    add_check_constraint :case_studies,
      "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])",
      name: "case_studies_status_check"

    create_table :training_offerings do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.text :audience
      t.jsonb :learning_objectives, null: false, default: []
      t.jsonb :topics, null: false, default: []
      t.string :delivery_format
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.text :published_audience
      t.jsonb :published_learning_objectives, null: false, default: []
      t.jsonb :published_topics, null: false, default: []
      t.string :published_delivery_format
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
    add_index :training_offerings, %i[organization_id slug], unique: true
    add_index :training_offerings, %i[status published_at]
    add_check_constraint :training_offerings,
      "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])",
      name: "training_offerings_status_check"

    create_table :public_resources do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :summary
      t.text :body
      t.string :resource_category
      t.string :related_content_label
      t.boolean :file_release_enabled, null: false, default: false
      t.jsonb :seo, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :published_title
      t.text :published_summary
      t.text :published_body
      t.string :published_resource_category
      t.string :published_related_content_label
      t.boolean :published_file_release_enabled, null: false, default: false
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
    add_index :public_resources, %i[organization_id slug], unique: true
    add_index :public_resources, %i[status published_at]
    add_check_constraint :public_resources,
      "status::text = ANY (ARRAY['draft'::text, 'in_review'::text, 'approved'::text, 'published'::text, 'archived'::text])",
      name: "public_resources_status_check"
  end
end
