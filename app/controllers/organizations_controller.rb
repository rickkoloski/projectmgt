class OrganizationsController < ApplicationController
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :members, :invite]
  before_action :authorize_organization!, except: [:index, :new, :create]
  
  def index
    @organizations = if current_user.admin?
                       Organization.all
                     else
                       Organization.where(id: current_user.organization_id)
                     end
  end

  def show
    @projects = @organization.projects
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)
    @organization.owner_id = current_user.id
    
    if @organization.save
      # Make the current user a member of this organization if they don't have one
      if current_user.organization_id.nil?
        current_user.update(organization_id: @organization.id)
      end
      
      redirect_to @organization, notice: "Organization created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit form
  end

  def update
    if @organization.update(organization_params)
      redirect_to @organization, notice: "Organization updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.destroy
    redirect_to organizations_path, notice: "Organization deleted successfully!"
  end
  
  def members
    @members = User.where(organization_id: @organization.id)
  end
  
  def invite
    email = params[:email]
    name = params[:name]
    role = params[:role] || 'member'
    
    if email.blank? || name.blank?
      redirect_to members_organization_path(@organization), alert: "Email and name are required."
      return
    end
    
    # Try to invite the user
    user = current_user.invite_user(email, name, role)
    
    if user.persisted?
      redirect_to members_organization_path(@organization), notice: "Invitation sent to #{email}!"
    else
      redirect_to members_organization_path(@organization), alert: "Failed to invite user: #{user.errors.full_messages.join(', ')}"
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:id])
  end
  
  def authorize_organization!
    unless @organization.owner_id == current_user.id || 
           current_user.organization_id == @organization.id ||
           current_user.admin?
      redirect_to organizations_path, alert: "You are not authorized to access this organization."
    end
  end
  
  def organization_params
    params.require(:organization).permit(:name, :settings)
  end
end
