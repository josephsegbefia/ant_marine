# frozen_string_literal: true

module StaffWebsiteEditorialController
  extend ActiveSupport::Concern

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
    assign_website_section_breadcrumb(current: @record.title)
    render "staff/website/editorial/show"
  end

  def new
    @record = @organization.public_send(editorial_association).build
    authorize @record
    assign_website_section_breadcrumb(current: "New #{editorial_section_label.singularize.downcase}")
    render "staff/website/editorial/new"
  end

  def create
    @record = @organization.public_send(editorial_association).build(editorial_params)
    @record.created_by_membership = Current.membership
    @record.updated_by_membership = Current.membership
    authorize @record
    if @record.save
      redirect_to editorial_show_path(@record), notice: "Draft saved."
    else
      assign_website_section_breadcrumb(current: "New #{editorial_section_label.singularize.downcase}")
      render "staff/website/editorial/new", status: :unprocessable_entity
    end
  end

  def edit
    authorize @record
    assign_website_section_breadcrumb(current: @record.title)
    render "staff/website/editorial/edit"
  end

  def update
    authorize @record
    @record.assign_attributes(editorial_params)
    @record.updated_by_membership = Current.membership
    if @record.save
      redirect_to editorial_show_path(@record), notice: "Draft saved."
    else
      assign_website_section_breadcrumb(current: @record.title)
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
end
