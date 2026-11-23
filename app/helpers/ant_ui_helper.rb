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

  def ant_back_link(label:, path:, disabled: false, **html_options)
    validated_path = validate_back_path!(path)

    render partial: "shared/ui/back_link",
           locals: {
             label: label,
             path: validated_path,
             disabled: disabled,
             html_options: html_options
           }
  end

  EmptyStateAction = Struct.new(:label, :path, :class, :data, keyword_init: true)

  def ant_empty_state(title:, description: nil, guidance: nil, icon: nil,
                      variant: :default, size: :default, tone: :neutral,
                      primary_action: nil, secondary_action: nil, title_id: nil)
    render partial: "shared/ui/empty_state",
           locals: {
             title: title,
             description: description,
             guidance: guidance,
             icon: icon,
             variant: variant,
             size: size,
             tone: tone,
             title_id: title_id,
             primary_action: normalize_empty_state_action(primary_action),
             secondary_action: normalize_empty_state_action(secondary_action)
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

    def normalize_empty_state_action(action)
      return nil if action.blank?

      path = validate_back_path!(action[:path] || action["path"])
      EmptyStateAction.new(
        label: (action[:label] || action["label"]).to_s,
        path: path,
        class: action[:class] || action["class"],
        data: action[:data] || action["data"] || {}
      )
    end

    def validate_back_path!(path)
      string_path = path.to_s
      raise ArgumentError, "Back navigation must use an application path" unless string_path.start_with?("/")
      raise ArgumentError, "Back navigation cannot use external redirects" if string_path.start_with?("//")

      string_path
    end

    def flash_toast_actions(flash_key)
      message = flash[flash_key].to_s
      if flash_key == :notice && message.start_with?("Invitation sent")
        return { action_label: "View invitations", action_href: staff_invitations_path }
      end

      {}
    end
end
