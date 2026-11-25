# frozen_string_literal: true

class CreateServiceInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :service_inquiries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :client_organization, foreign_key: { to_table: :organizations }
      t.references :service, foreign_key: true
      t.string :reference_number, null: false
      t.string :channel, null: false, default: "public_form"
      t.string :current_status, null: false, default: "submitted"
      t.string :service_title_snapshot
      t.string :company_name, null: false
      t.string :contact_name, null: false
      t.string :contact_email, null: false
      t.string :contact_phone
      t.string :project_name
      t.string :vessel_name
      t.string :location, null: false
      t.text :description, null: false
      t.date :preferred_date
      t.string :submission_token, null: false
      t.jsonb :submission_metadata, null: false, default: {}
      t.datetime :submitted_at, null: false
      t.timestamps
    end

    add_index :service_inquiries, :reference_number, unique: true
    add_index :service_inquiries, :submission_token, unique: true
    add_index :service_inquiries, %i[current_status created_at]
    add_check_constraint :service_inquiries,
                         "channel IN ('public_form', 'contact_form', 'client_portal', 'staff')",
                         name: "service_inquiries_channel_check"
    add_check_constraint :service_inquiries,
                         "current_status IN ('submitted', 'under_review', 'needs_clarification', 'qualified', " \
                         "'unqualified', 'merged', 'closed')",
                         name: "service_inquiries_status_check"
    add_check_constraint :service_inquiries,
                         "char_length(description) <= 4000 AND char_length(company_name) <= 160 AND " \
                         "char_length(contact_name) <= 120 AND char_length(contact_email) <= 254 AND " \
                         "char_length(location) <= 200",
                         name: "service_inquiries_length_check"

    add_reference :quotes, :service_inquiry, foreign_key: true
    add_index :quotes, :service_inquiry_id, unique: true,
              where: "service_inquiry_id IS NOT NULL AND status NOT IN ('withdrawn', 'superseded')",
              name: "index_quotes_one_open_quote_per_inquiry"
  end
end
