class PasswordsController < ApplicationController
  skip_before_filter :login_required, :only => [:new, :create]
  verify :method => :post, :only => [:create, :update], :redirect_to => :edit

  # Enter email address to recover password
  def new
  end

  # Forgot password action
  def create
    if @user = User.find_for_forget(params[:email])
      @user.forgot_password
      @user.save!
      flash[:notice] = "A password reset link has been sent to your email."
      redirect_to login_path #:controller => 'account', :action => 'login'
    else
      flash[:notice]="Could not find a user with that email address."
      render :action => 'new'
    end
  end

  class ResetInvalid < Exception; end

  #Action triggered by clicking on the emailed /reset_password/:id link
  #reset code and id must match a user in the database
  #then the password can be reset
  def edit
    if params[:id].nil?
      render :action => 'new'
      return
    end
    @user = User.find_by_password_reset_code(params[:id]) if params[:id]
    raise ResetInvalid if @user.nil?
  rescue ResetInvalid
    reset_invalid_failure
  end


  #Reset password action /reset_password/:id
  #Confirms an id and a nonblank password
  def update
    if params[:id].nil?
      render :action => 'new'
      return
    end
    @user = User.find_by_password_reset_code(params[:id]) if params[:id]
    raise ResetInvalid if @user.nil?
    return if @user && !params[:password]
    
    if (params[:password] == params[:password_confirmation])
      @user.password_confirmation = params[:password_confirmation]
      @user.password = params[:password]
      @user.reset_password
      if @user.save(false)
        flash[:notice] = "Password reset"
        @user.send(:activate!) unless @user.active?
      else
        flash[:notice] = "Password reset failed"
      end
    else
      flash[:notice] = "Password mismatch"
      render :action => 'edit', :id => params[:id]
      return
    end
    redirect_to login_path
  
  rescue ResetInvalid
    reset_invalid_failure
  end
  
  protected

  def reset_invalid_failure
    logger.error "Invalid Reset Code entered."
    flash[:notice] = "Sorry - That is an invalid password reset code. Please check your code and try again. (Perhaps your email client inserted a carriage return?)"
    redirect_to login_path #:controller => 'account', :action => 'login'
  end

end
