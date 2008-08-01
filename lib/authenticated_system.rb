module AuthenticatedSystem

  # Accesses the current user from the session.
  def current_user
    @current_user ||= (session[:user] && load_user(session[:user])) || user_from_cookie || UnauthenticatedUser.new
  end

  def load_user(id)
    user = User.find_by_id(id)
    User.update_all(["last_seen_at = ?", Time.now], ["id = ?", user.id])
    user
  end
  
  # Returns true or false if the user is logged in.
  # Preloads @current_user with the user model if they're logged in.
  def logged_in?
    current_user.is_a?(AuthenticatedUser)
  end
    
  protected 

    # Store the given user in the session.
    def current_user=(new_user)
      return if new_user.is_a?(UnauthenticatedUser)
      session[:user] = (new_user.nil? || new_user.is_a?(Symbol)) ? nil : new_user.id
      @current_user = new_user
    end
    
    # Check if the user is authorized.
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the user
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorize?
    #    current_user.login != "bob"
    #  end
    def authorized?
      true
    end

    # Filter method to enforce a login requirement.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_filter :login_required
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_filter :login_required, :only => [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_filter :login_required
    #
    def login_required
      username, passwd = get_auth_data
      self.current_user ||= User.authenticate(username, passwd) || UnauthenticatedUser.new if username && passwd
      User.current = current_user
      logged_in? && authorized? ? true : access_denied
    end

    def not_logged_in_required
      redirect_to me_path if logged_in?
    end
    
    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the user is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied(exception=nil)
      raise "permission problem" if RAILS_ENV == 'development'
      respond_to do |accepts|
        accepts.html do
          if logged_in?
            flash[:error]='You do not have sufficient permission to perform that action.' 
            log_exception( exception ) if exception
            redirect_to me_path
          else
            flash[:error]= 'Please login to perform that action.'
            redirect_to login_path, :redirect => request.request_uri
          end
        end
        accepts.xml do
          headers["Status"]           = "Unauthorized"
          headers["WWW-Authenticate"] = %(Basic realm="Web Password")
          render :text => "Could't authenticate you", :status => '401 Unauthorized'
        end
      end
      false
    end  
    
    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    def store_location
      session[:return_to] = (request.request_uri unless request.xhr?)
    end
    
    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.
    def redirect_back_or_default(default)
      session[:return_to] ? redirect_to_url(session[:return_to]) : redirect_to(default)
      session[:return_to] = nil
    end
    
    # Inclusion hook to make #current_user and #logged_in?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_user, :logged_in?
    end

    # When called :user_from_cookie will check for an :auth_token
    # cookie and log the user back in if apropriate
    def user_from_cookie
      return unless cookies["auth_token"] 
      user = User.find_by_remember_token(cookies["auth_token"])
      if user && user.remember_token?
        # update the remember_me cookie
        user.remember_me
        cookies["auth_token"] = { :value => user.remember_token , :expires => user.remember_token_expires_at }
        user
      end
    end

  private
    @@http_auth_headers = %w(X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION Authorization)
    # gets BASIC auth info
    def get_auth_data
      auth_key  = @@http_auth_headers.detect { |h| request.env.has_key?(h) }
      auth_data = request.env[auth_key].to_s.split unless auth_key.blank?
      return auth_data && auth_data[0] == 'Basic' ? Base64.decode64(auth_data[1]).split(':')[0..1] : [nil, nil] 
    end
end
