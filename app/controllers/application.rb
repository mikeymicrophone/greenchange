class ApplicationController < ActionController::Base
  Tag # need this to reload has_many_polymorphs in development mode

  include AuthenticatedSystem	
  include PageUrlHelper
  include UrlHelper
  include ContextHelper
  include TimeHelper

  include PathFinder::Options
      
  # don't allow passwords in the log file.
  filter_parameter_logging "password"
  
  before_filter :pre_clean
  around_filter :rescue_authentication_errors
  before_filter :breadcrumbs, :context
  around_filter :set_timezone
  session :session_secure => true if Crabgrass::Config.https_only

  protected
  
  # let controllers set a custom stylesheet in their class definition
  def self.stylesheet(cssfile=nil)
    write_inheritable_attribute "stylesheet", cssfile if cssfile
    read_inheritable_attribute "stylesheet"
  end
  
  def get_unobtrusive_javascript
    @js_behaviours.to_s
  end
  
  def handle_rss(locals)
    if params[:path].any? and 
        (params[:path].include? 'rss' or params[:path].include? '.rss')
      response.headers['Content-Type'] = 'application/rss+xml'   
      render :partial => '/pages/rss', :locals => locals
    end
  end


  # a one stop shopping function for flash messages
  def message(opts)    
    if opts[:success]
      flash[:notice] = opts[:success]
    elsif opts[:error]
      if opts[:later]
        flash[:error] = opts[:error]
      else
        flash.now[:error] = opts[:error]
      end
    elsif opts[:object]
      object = opts[:object]
      unless object.errors.empty?
        flash.now[:error] = _("Changes could not be saved.")
        flash.now[:text] ||= ""
        flash.now[:text] += "<p>#{_('There are problems with the following fields')}:</p>"
        flash.now[:text] += "<ul>" + object.errors.full_messages.collect { |msg| "<li>#{msg}</li>"} + "</ul>"
        flash.now[:errors] = object.errors
      end
    end
  end
  
  # some helpers we include in controllers. this allows us to 
  # grab the controller that will work in a view context and a
  # controller context.
  def controller
    self
  end 
  
  private
  
  def pre_clean
    User.current = nil
  end

  def set_timezone
    TzTime.zone = logged_in? && current_user.time_zone ? TimeZone[current_user.time_zone] : TimeZone[DEFAULT_TZ]
    yield
    TzTime.reset!
  end

  def rescue_authentication_errors
    yield
  rescue PermissionDenied
    access_denied
  end
end
