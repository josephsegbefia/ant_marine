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

  def ant_rich_text_field(form, method, **options)
    render partial: "shared/ui/rich_text_field",
           locals: {
             form: form,
             method: method,
             label: options.delete(:label),
             hint: options.delete(:hint),
             required: options.delete(:required)
           }
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
             html_options: extract_html_options(options)
           }
  end

  def ant_icon_picker(form, method, **options)
    render partial: "shared/ui/icon_picker",
           locals: {
             form: form,
             method: method,
             label: options.delete(:label) || method.to_s.humanize,
             hint: options.delete(:hint)
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
             html_options: extract_html_options(options)
           }
  end

  # Text / textarea field outside a form builder (params keyed by `name`).
  def ant_text_field_tag(name, label:, value: nil, id: nil, hint: nil, error: nil, required: false,
                         multiline: false, placeholder: nil, wrapper_class: nil)
    field_id = id || sanitize_to_id(name)
    describedby = [ hint.present? ? "#{field_id}-hint" : nil, error.present? ? "#{field_id}-error" : nil ].compact.join(" ").presence
    input_opts = {
      id: field_id,
      class: "ant-control",
      required: required,
      placeholder: placeholder,
      aria: { invalid: (true if error.present?), describedby: describedby }.compact
    }
    control = if multiline
      text_area_tag(name, value, input_opts.merge(rows: 4))
    else
      text_field_tag(name, value, input_opts)
    end

    content_tag(:div, class: [ "ant-field", "ant-field--portal", wrapper_class ].compact.join(" ")) do
      safe_join([
        label_tag(field_id, label, class: "ant-field__label"),
        control,
        (tag.p(hint, class: "ant-field__hint", id: "#{field_id}-hint") if hint.present?),
        (tag.p(error, class: "ant-field__error", id: "#{field_id}-error", role: "alert") if error.present?)
      ].compact)
    end
  end

  # The ANT dropdown for fields outside a form builder. choices: [[label, value], ...].
  # include_blank: text for an empty first option (for example "All statuses").
  # data/aria go on the underlying <select>, so existing Stimulus targets and actions keep working.
  def ant_select_tag(name, choices, label:, selected: nil, id: nil, include_blank: nil, placeholder: "Choose one",
                     hint: nil, error: nil, searchable: false, compact: false, wrapper_class: nil,
                     required: false, disabled: false, data: {}, aria: {})
    field_id = id || sanitize_to_id(name)
    choices = choices.map { |choice| Array(choice).then { |pair| pair.size == 1 ? [ pair[0], pair[0] ] : pair } }
    choices = [ [ include_blank, "" ] ] + choices if include_blank
    selected_value = selected.to_s
    current = choices.find { |(_text, value)| value.to_s == selected_value }
    describedby = [ hint.present? ? "#{field_id}-hint" : nil, error.present? ? "#{field_id}-error" : nil ].compact.join(" ").presence

    native = select_tag(
      name,
      options_for_select(choices, selected_value),
      id: field_id,
      class: "ant-select__native",
      required: required,
      disabled: disabled,
      data: { custom_select_target: "native" }.merge(data),
      aria: { invalid: (true if error.present?), describedby: describedby }.compact.merge(aria)
    )

    render partial: "shared/ui/select_core",
           locals: {
             field_id: field_id,
             label_html: label_tag(field_id, label, class: "ant-field__label", id: "#{field_id}_label"),
             native_html: native,
             wrapper_class: [ "ant-field", compact ? "ant-field--compact" : "ant-field--portal", wrapper_class ].compact.join(" "),
             placeholder: placeholder,
             searchable: searchable,
             hint: hint,
             error: error,
             current_label: current&.first,
             current_empty: current.nil? || current[1].to_s.empty?
           }
  end

  # The ANT date picker. Submits an ISO date (YYYY-MM-DD) under `name`; without JavaScript it is
  # an ordinary date input. range_start_for/range_end_for take the id of the paired field, so
  # a start date can never be after the end date and the reverse.
  def ant_date_field(name, label:, value: nil, id: nil, min: nil, max: nil, placeholder: "Select date",
                     hint: nil, error: nil, compact: false, wrapper_class: nil, required: false,
                     range_start_for: nil, range_end_for: nil)
    date = ant_date_value(value)
    render partial: "shared/ui/date_picker",
           locals: {
             name: name,
             field_id: id || sanitize_to_id(name),
             iso_value: date&.iso8601,
             display_value: (date && date.strftime("%a %-d %b %Y")),
             label: label,
             min: ant_date_value(min)&.iso8601,
             max: ant_date_value(max)&.iso8601,
             placeholder: placeholder,
             hint: hint,
             error: error,
             required: required,
             wrapper_class: [ "ant-field", compact ? "ant-field--compact" : "ant-field--portal", wrapper_class ].compact.join(" "),
             range_start_for: range_start_for,
             range_end_for: range_end_for
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
  PageHeaderAction = Struct.new(:label, :path, :class, :data, keyword_init: true)
  ContentRecordAction = Struct.new(:label, :path, :class, :data, :external, keyword_init: true)

  def ant_page_header(title:, description: nil, eyebrow: nil, title_id: nil,
                      primary_action: nil, secondary_action: nil)
    render partial: "shared/ui/page_header",
           locals: {
             title: title,
             description: description,
             eyebrow: eyebrow,
             title_id: title_id,
             primary_action: normalize_page_header_action(primary_action),
             secondary_action: normalize_page_header_action(secondary_action)
           }
  end

  def ant_section_tabs(tabs:, aria_label: "Sections")
    render partial: "shared/ui/section_tabs", locals: { tabs: tabs, aria_label: aria_label }
  end

  # pagination: a Pagination; path_for: lambda(page) returning the URL for that page.
  def ant_pagination(pagination, label: "items", path_for:)
    render partial: "shared/ui/pagination", locals: { pagination: pagination, label: label, path_for: path_for }
  end

  def ant_dialog(id:, title:, trigger_label:, trigger_class: nil, description: nil, &block)
    render layout: "shared/ui/dialog",
           locals: { id: id, title: title, trigger_label: trigger_label, trigger_class: trigger_class, description: description },
           &block
  end

  def ant_status_badge(label:, badge_class: "ant-badge--muted")
    render partial: "shared/ui/status_badge", locals: { label: label, badge_class: badge_class }
  end

  def ant_content_record(title:, description: nil, guidance: nil, meta: nil, icon: nil,
                         status_label: nil, status_badge_class: nil,
                         primary_action: nil, secondary_action: nil)
    render partial: "shared/ui/content_record",
           locals: {
             title: title,
             description: description,
             guidance: guidance,
             meta: meta,
             icon: icon,
             status_label: status_label,
             status_badge_class: status_badge_class,
             primary_action: normalize_content_record_action(primary_action),
             secondary_action: normalize_content_record_action(secondary_action)
           }
  end

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

    def ant_date_value(value)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def extract_html_options(options)
      nested = options.delete(:html_options) || {}
      options.merge(nested) { |_key, outer, inner| outer.is_a?(Hash) && inner.is_a?(Hash) ? outer.merge(inner) : inner }
    end

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

    def normalize_page_header_action(action)
      return nil if action.blank?
      return action if action.is_a?(PageHeaderAction)

      path = validate_back_path!(action[:path] || action["path"])
      PageHeaderAction.new(
        label: (action[:label] || action["label"]).to_s,
        path: path,
        class: action[:class] || action["class"],
        data: action[:data] || action["data"] || {}
      )
    end

    def normalize_content_record_action(action)
      return nil if action.blank?
      return action if action.is_a?(ContentRecordAction)

      path = validate_back_path!(action[:path] || action["path"])
      ContentRecordAction.new(
        label: (action[:label] || action["label"]).to_s,
        path: path,
        class: action[:class] || action["class"],
        data: action[:data] || action["data"] || {},
        external: action[:external] || action["external"]
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
