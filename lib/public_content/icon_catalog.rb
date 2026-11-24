# frozen_string_literal: true

module PublicContent
  module IconCatalog
    Entry = Data.define(:key, :label, :group)

    ENTRIES = [
      Entry.new(key: "ship", label: "Ship", group: "Marine"),
      Entry.new(key: "anchor", label: "Anchor", group: "Marine"),
      Entry.new(key: "compass", label: "Navigation", group: "Marine"),
      Entry.new(key: "life-ring", label: "Safety at sea", group: "Marine"),
      Entry.new(key: "clipboard", label: "Survey & inspection", group: "Technical"),
      Entry.new(key: "shield", label: "Safety & compliance", group: "Technical"),
      Entry.new(key: "chart", label: "Reporting", group: "Technical"),
      Entry.new(key: "file", label: "Documentation", group: "Technical"),
      Entry.new(key: "wrench", label: "Engineering", group: "Technical"),
      Entry.new(key: "layers", label: "Project support", group: "Projects"),
      Entry.new(key: "brief", label: "Project management", group: "Projects"),
      Entry.new(key: "globe", label: "Regional reach", group: "Advisory"),
      Entry.new(key: "users", label: "Team & advisory", group: "Advisory"),
      Entry.new(key: "leaf", label: "Environmental", group: "Advisory"),
      Entry.new(key: "book", label: "Training", group: "Learning"),
      Entry.new(key: "check", label: "Approval", group: "Learning")
    ].freeze

    module_function

    def keys
      ENTRIES.map(&:key)
    end

    def labels
      ENTRIES.to_h { |e| [ e.key, e.label ] }
    end

    def label_for(key)
      labels[key.to_s] || key.to_s.humanize
    end

    def valid?(key)
      key.blank? || keys.include?(key.to_s)
    end

    def resolve(key)
      k = key.to_s
      return "ship" if k.blank?
      return k if keys.include?(k)

      "ship"
    end

    def select_choices
      labels.map { |key, label| [ label, key ] }
    end

    def grouped_entries
      ENTRIES.group_by(&:group)
    end
  end
end
