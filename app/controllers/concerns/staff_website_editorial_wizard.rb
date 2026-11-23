# frozen_string_literal: true

module StaffWebsiteEditorialWizard
  extend ActiveSupport::Concern

  included do
    helper StaffEditorialWorkspaceHelper
  end

  private

    def editorial_editor_step
      max = editorial_workspace_config(@record)[:step_count]
      step = params[:step].presence || params[:editor_step].presence || 1
      step.to_i.clamp(1, max)
    end

    def editorial_workspace_config(record)
      helpers.editorial_workspace_config(record)
    end

    def edit_editorial_path(record, step:)
      url_for([ :edit, :staff, :website, record, { step: step } ])
    end

    def redirect_editorial_after_save(created:)
      commit = params[:commit].to_s
      max_step = editorial_workspace_config(@record)[:step_count]
      step = editorial_editor_step
      notice = "Draft saved."

      path = case commit
      when "save_continue"
               next_step = [ step + 1, max_step ].min
               edit_editorial_path(@record, step: next_step)
      when "save_draft"
               @record.persisted? ? edit_editorial_path(@record, step: step) : edit_editorial_path(@record, step: step)
      else
               created ? edit_editorial_path(@record, step: max_step) : editorial_show_path(@record)
      end

      redirect_to path, notice: notice
    end
end
