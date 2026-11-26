# frozen_string_literal: true

module AntSelectSystemHelper
  # Interact with the visible ANT custom select trigger/options (not the sr-only native <select>).
  # Portal labels use CSS text-transform: uppercase, so Capybara/Selenium reports "DECISION"
  # for a label whose DOM text is "Decision" — match case-insensitively.
  def select_ant_option(label, option_text)
    field = find_ant_select_field(label)
    within(field) do
      find(".ant-select__trigger", visible: true).click
      assert_selector '[role="option"]', text: option_text, visible: true, wait: 3
      find('[role="option"]', text: option_text, exact_text: true, match: :prefer_exact).click
    end
  end

  def find_ant_select_field(label)
    pattern = /\A#{Regexp.escape(label)}\z/i
    label_el = find("label.ant-field__label", text: pattern, match: :prefer_exact, wait: 5)
    controller = label_el.first(:xpath, "./ancestor::*[@data-controller='custom-select'][1]")
    raise Capybara::ElementNotFound, "No custom-select wrapper for label #{label.inspect}" if controller.nil?

    controller
  end
end
