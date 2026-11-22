# frozen_string_literal: true

module AntUiHelper
  FLASH_TYPE_MAP = {
    notice: "success",
    alert: "error",
    warning: "warning",
    info: "info"
  }.freeze

  def flash_toast_payload
    FLASH_TYPE_MAP.filter_map do |flash_key, toast_type|
      message = flash[flash_key]
      next if message.blank?

      payload = {
        type: toast_type,
        message: message.to_s,
        assertive: toast_type == "error"
      }
      payload.merge!(flash_toast_actions(flash_key))
      payload
    end
  end

  def ant_field(form, method, **options)
    render partial: "shared/ui/field",
           locals: {
             form: form,
             method: method,
             type: options.delete(:type) || :text,
             label: options.delete(:label),
             hint: options.delete(:hint),
             error: options.delete(:error),
             required: options.delete(:required),
             context: options.delete(:context) || :access,
             html_options: options
           }
  end

  def ant_select(form, method, choices:, **options)
    render partial: "shared/ui/select",
           locals: {
             form: form,
             method: method,
             choices: choices,
             label: options.delete(:label),
             hint: options.delete(:hint),
             error: options.delete(:error),
             required: options.delete(:required),
             searchable: options.delete(:searchable) || false,
             placeholder: options.delete(:placeholder) || "Choose one",
             context: options.delete(:context) || :access,
             select_options: options.delete(:select_options) || {},
             html_options: options
           }
  end

  def ant_collection_select(form, method, collection, value_method, text_method, **options)
    choices = collection.map { |item| [ item.public_send(text_method), item.public_send(value_method) ] }
    selected = options.delete(:selected)
    select_options = options.delete(:select_options) || {}
    select_options[:selected] = selected if selected.present?

    ant_select(
      form,
      method,
      choices: choices,
      select_options: select_options,
      **options
    )
  end

  private

    def flash_toast_actions(flash_key)
      message = flash[flash_key].to_s
      if flash_key == :notice && message.start_with?("Invitation sent")
        return { action_label: "View invitations", action_href: staff_invitations_path }
      end

      {}
    end
end
