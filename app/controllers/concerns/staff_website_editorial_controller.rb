# frozen_string_literal: true

module StaffWebsiteEditorialController
  extend ActiveSupport::Concern
  include StaffWebsiteEditorialWizard

  included do
    class_attribute :editorial_record_class, :editorial_param_key, :editorial_section_label
    helper_method :editorial_section_label, :editorial_index_path, :editorial_record_class
  end

  def index
    assign_website_section_breadcrumb(current: editorial_section_label)
    authorize editorial_record_class
    @records = policy_scope(editorial_record_class).ordered
    render "staff/website/editorial/index"
  end

  def show
    authorize @record
    assign_content_editor_breadcrumb(
      section_label: editorial_section_label,
      section_path: editorial_index_path,
      current: @record.title
    )
    render "staff/website/editorial/show"
  end

  def new
    @record = @organization.public_send(editorial_association).build
    authorize @record
    @editor_step = editorial_editor_step
    @editor_config = editorial_workspace_config(@record)
    assign_editorial_editor_breadcrumb(current: "New #{editorial_section_label.singularize.downcase}")
    render "staff/website/editorial/new"
  end

  def create
    @record = @organization.public_send(editorial_association).build(editorial_params)
    @record.created_by_membership = Current.membership
    @record.updated_by_membership = Current.membership
    @editor_step = editorial_editor_step
    @editor_config = editorial_workspace_config(@record)
    authorize @record
    if @record.save
      redirect_editorial_after_save(created: true)
    else
      assign_editorial_editor_breadcrumb(current: "New #{editorial_section_label.singularize.downcase}")
      render "staff/website/editorial/new", status: :unprocessable_entity
    end
  end

  def edit
    authorize @record
    @editor_step = editorial_editor_step
    @editor_config = editorial_workspace_config(@record)
    assign_editorial_editor_breadcrumb(current: @record.title.presence || "Edit content")
    render "staff/website/editorial/edit"
  end

  def update
    authorize @record
    @editor_step = editorial_editor_step
    @editor_config = editorial_workspace_config(@record)
    @record.assign_attributes(editorial_params)
    @record.updated_by_membership = Current.membership
    if @record.save
      redirect_editorial_after_save(created: false)
    else
      assign_editorial_editor_breadcrumb(current: @record.title.presence || "Edit content")
      render "staff/website/editorial/edit", status: :unprocessable_entity
    end
  end

  def submit_for_review
    authorize @record, :submit_for_review?
    PublicContent::Transition.submit_for_review!(record: @record, membership: Current.membership)
    redirect_to editorial_show_path(@record), notice: "#{editorial_section_label.singularize} submitted for review."
  rescue PublicContent::Transition::InvalidTransition => e
    redirect_to editorial_show_path(@record), alert: e.message
  end

  def withdraw
    authorize @record, :withdraw?
    PublicContent::Transition.withdraw!(record: @record, membership: Current.membership)
    redirect_to editorial_show_path(@record), notice: "Moved back to draft."
  rescue PublicContent::Transition::InvalidTransition
    redirect_to editorial_show_path(@record), alert: "This record cannot be withdrawn right now."
  end

  def approve
    authorize @record, :approve?
    PublicContent::Transition.approve!(record: @record, membership: Current.membership)
    redirect_to editorial_show_path(@record), notice: "Content approved."
  rescue PublicContent::Transition::InvalidTransition
    redirect_to editorial_show_path(@record), alert: "This record cannot be approved right now."
  end

  def publish
    authorize @record, :publish?
    PublicContent::Transition.publish!(record: @record, membership: Current.membership)
    redirect_to editorial_show_path(@record), notice: "Published on the public website."
  rescue PublicContent::Transition::InvalidTransition
    redirect_to editorial_show_path(@record), alert: "This record cannot be published right now."
  end

  def unpublish
    authorize @record, :unpublish?
    PublicContent::Transition.unpublish!(record: @record, membership: Current.membership)
    redirect_to editorial_show_path(@record), notice: "Unpublished."
  rescue PublicContent::Transition::InvalidTransition
    redirect_to editorial_show_path(@record), alert: "This record cannot be unpublished right now."
  end

  def archive
    authorize @record, :archive?
    PublicContent::Transition.archive!(record: @record, membership: Current.membership)
    redirect_to editorial_index_path, notice: "Archived."
  rescue PublicContent::Transition::InvalidTransition
    redirect_to editorial_show_path(@record), alert: "This record cannot be archived right now."
  end

  private

    def set_record
      @record = policy_scope(editorial_record_class).find(params[:id])
    end

    def editorial_association
      editorial_record_class.model_name.collection.to_sym
    end

    def assign_editorial_editor_breadcrumb(current:)
      assign_content_editor_breadcrumb(
        section_label: editorial_section_label,
        section_path: editorial_index_path,
        current: current
      )
    end
end
