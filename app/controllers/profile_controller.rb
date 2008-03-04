class ProfileController < ApplicationController

  before_filter :login_required
  prepend_before_filter :fetch_profile
  layout :choose_layout
  stylesheet 'profile'
  
  def show
    
  end

  def edit
    if request.post?
      @profile.save_from_params params['profile']
      @entity.issue_ids = params['issues']
    end
  end

  # ajax
  def add_location
    render :update do |page|
      page.insert_html :bottom, 'profile_locations', :partial => 'location', :locals => {:location => Profile::Location.new}
    end
  end

  # ajax
  def add_email_address
    render :update do |page|
      page.insert_html :bottom, 'profile_email_addresses', :partial => 'email_address', :locals => {:email_address => Profile::EmailAddress.new}
    end
  end

  # ajax
  def add_im_address
    render :update do |page|
      page.insert_html :bottom, 'profile_im_addresses', :partial => 'im_address', :locals => {:im_address => Profile::ImAddress.new}
    end
  end

  # ajax
  def add_phone_number
    render :update do |page|
      page.insert_html :bottom, 'profile_phone_numbers', :partial => 'phone_number', :locals => {:phone_number => Profile::PhoneNumber.new}
    end
  end

  # ajax
  def add_note
    render :update do |page|
      page.insert_html :bottom, 'profile_notes', :partial => 'note', :locals => {:note => Profile::Note.new}
    end
  end

  # ajax
  def add_website
    render :update do |page|
      page.insert_html :bottom, 'profile_websites', :partial => 'website', :locals => {:website => Profile::Website.new}
    end
  end

  protected
 
  def fetch_profile
    return true unless params[:id]
    @profile = Profile.find params[:id]
    @entity = @profile.entity
    if @entity.is_a?(User)
      @user = @entity
    elsif @entity.is_a?(Group)
      @group = @entity
    else
      raise Exception.new("could not determine entity type for profile: #{@profile.inspect}")
    end
  end
  
  # always have access to self
  def authorized?
    if @entity.is_a?(User) and current_user == @entity
      return true
    elsif @entity.is_a?(Group)
      return true if action_name == 'show'
      return true if logged_in? and current_user.member_of?(@entity)
      return false
    elsif action_name =~ /add_/
     return true # TODO: this is the right way to do this
    end
  end
  
  def choose_layout
    if @user
      return 'me'
    elsif @group
      return 'group'
    else
      return 'application'
    end
  end
  
  def context
    me_context('large')
    add_context 'inbox'.t, url_for(:controller => 'inbox', :action => 'index')
  end
  
  #try to make it easier to add or edit profile sections from plugins
  def profile_sections
    ['description_section', 'phone_number_section', 'email_address_section', 'location_section', 'im_address_section', 'website_section']
  end
  helper_method :profile_sections

  protected
  def profile_sections_with_issues
    ['issues_section'] + profile_sections_without_issues
  end
  alias_method_chain :profile_sections, :issues

end
