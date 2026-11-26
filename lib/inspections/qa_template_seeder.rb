# frozen_string_literal: true

module Inspections
  # Synthetic QA checklist for simulated fieldwork — not a regulatory template.
  module QaTemplateSeeder
    TEMPLATE_KEY = "simulated_qa_general_vessel"
    TEMPLATE_TITLE = "SIMULATED QA — General vessel observation"
    DISCLAIMER =
      "SIMULATED ONLY — This checklist is for development and training. " \
      "It is not a regulatory or classification society inspection template."

    module_function

    def seed!(operating_organization:, created_by_membership:)
      template = InspectionTemplate.find_or_initialize_by(
        operating_organization: operating_organization,
        key: TEMPLATE_KEY
      )
      template.assign_attributes(
        title: TEMPLATE_TITLE,
        description: DISCLAIMER,
        status: "published"
      )
      template.save!

      version = template.inspection_template_versions.find_or_initialize_by(version_number: 1)
      return template if version.persisted?

      version.assign_attributes(
        schema_json: schema_payload,
        published_at: Time.current,
        created_by_membership: created_by_membership
      )
      version.save!

      template.update!(current_version_id: version.id)
      template
    end

    def schema_payload
      {
        "disclaimer" => DISCLAIMER,
        "sections" => [
          {
            "key" => "hull_deck",
            "title" => "Hull and deck (simulated)",
            "items" => [
              {
                "key" => "hull_visible_damage",
                "prompt" => "Visible hull damage observed?",
                "response_type" => "yes_no_na",
                "required" => true
              },
              {
                "key" => "deck_condition",
                "prompt" => "Overall deck condition",
                "response_type" => "satisfactory_unsatisfactory",
                "required" => true
              },
              {
                "key" => "deck_notes",
                "prompt" => "Additional deck notes",
                "response_type" => "long_text",
                "required" => false
              }
            ]
          },
          {
            "key" => "safety_equipment",
            "title" => "Safety equipment (simulated)",
            "items" => [
              {
                "key" => "fire_extinguisher_count",
                "prompt" => "Fire extinguishers counted on board",
                "response_type" => "numeric",
                "required" => false
              },
              {
                "key" => "safety_gear_present",
                "prompt" => "Required safety gear categories present",
                "response_type" => "multi_select",
                "required" => false,
                "options" => [
                  { "value" => "life_jackets", "label" => "Life jackets" },
                  { "value" => "first_aid", "label" => "First aid kit" },
                  { "value" => "epirb", "label" => "EPIRB (simulated check)" }
                ]
              },
              {
                "key" => "safety_walk_date",
                "prompt" => "Date of simulated safety walk",
                "response_type" => "date",
                "required" => false
              }
            ]
          }
        ]
      }
    end
  end
end
