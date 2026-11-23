# frozen_string_literal: true

class MigratePublicContentBodyToActionText < ActiveRecord::Migration[8.1]
  MODEL_COLUMNS = {
    "Article" => %i[body],
    "CaseStudy" => %i[body client_challenge approach work_performed outcome],
    "TrainingOffering" => %i[body],
    "PublicResource" => %i[body],
    "Service" => %i[body],
    "PublicSitePage" => %i[body]
  }.freeze

  def up
    MODEL_COLUMNS.each do |class_name, columns|
      klass = class_name.constantize
      table = klass.table_name

      columns.each do |column|
        next unless column_exists?(table, column)

        klass.unscoped.find_each do |record|
          text = record.read_attribute(column)
          next if text.blank?

          ActionText::RichText.create!(
            name: column.to_s,
            record: record,
            body: PublicContent::RichText.plain_to_html(text)
          )
        end

        remove_column table, column
      end
    end
  end

  def down
    MODEL_COLUMNS.each do |class_name, columns|
      klass = class_name.constantize
      table = klass.table_name
      columns.each do |column|
        add_column table, column, :text unless column_exists?(table, column)
      end
    end
  end
end
