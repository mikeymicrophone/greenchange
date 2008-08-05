# == Schema Information
# Schema version: 24
#
# Table name: users
#
#  id                        :integer(11)   not null, primary key
#  login                     :string(255)   
#  email                     :string(255)   
#  crypted_password          :string(40)    
#  salt                      :string(40)    
#  created_at                :datetime      
#  updated_at                :datetime      
#  remember_token            :string(255)   
#  remember_token_expires_at :datetime      
#  display_name              :string(255)   
#  time_zone                 :string(255)   
#  language                  :string(5)     
#  avatar_id                 :integer(11)   
#

##
# this is the user model generated by acts_as_authenticated plugin
# crabgrass specific model is called "User", which is a subclass
# of "AuthenticatedUser".
##

require 'digest/sha1'
module AuthenticatedUser 
  #set_table_name 'users'

  def self.included(base)
    base.extend   ClassMethods
    base.instance_eval do
      # a class attr which is set to the currently logged in user
      cattr_accessor :current
      
      # Virtual attribute for the unencrypted password
      attr_accessor :password

      validates_presence_of     :login
      validates_presence_of     :password,                   :if => :password_required?
      validates_presence_of     :password_confirmation,      :if => :password_required?
      validates_length_of       :password, :within => 4..40, :if => :password_required?
      validates_confirmation_of :password,                   :if => :password_required?
      validates_format_of       :login, :with => /^[a-z0-9]+([-_]*[a-z0-9]+){1,39}$/
      validates_length_of       :login, :within => 3..40
      validates_uniqueness_of   :login, :case_sensitive => false

      before_save :encrypt_password
      before_create :make_activation_code
      attr_protected :activation_code, :activated_at, :enabled, :superuser
    end
  end

  class ActivationCodeNotFound < StandardError; end
  class AlreadyActivated < StandardError
    attr_reader :user, :message
    def initialize(user, message=nil)
      @message, @user = message, user
    end
  end

  module ClassMethods
    
    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    def authenticate(login, password)
      u = find :first, :conditions => ['login = ? and enabled = ? and activated_at IS NOT NULL', login, true] # need to get the salt
      u && u.authenticated?(password) ? u : nil
    end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    end

    def find_for_forget(email)
      find :first, :conditions => ['email = ?', email]
    end

    def find_and_activate!(activation_code)
      raise ArgumentError if activation_code.nil?
      user = find_by_activation_code(activation_code)
      raise ActivationCodeNotFound unless user
      raise AlreadyActivated.new(user) if user.active?
      user.send(:activate!)
      user
    end


  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def active?
    # the existence of an activated_at timestamp means they are active
    !activated_at.nil?
  end

  # Returns true if the user has just been activated.
  def pending?
    @activated
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    self.remember_token_expires_at = 2.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  #methods used for password reminders
  def forgot_password
    @forgotten_password = true
    self.make_password_reset_code
  end

  def reset_password
    update_attribute :password_reset_code, nil
    @reset_password = true
  end

  #user observer uses these methods
  def recently_forgot_password?
    @forgotten_password
  end

  def recently_reset_password?
    @reset_password
  end

  protected
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end
    
    def password_required?
      crypted_password.blank? || !password.blank?
    end

    def make_password_reset_code
      self.password_reset_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end

    def make_activation_code
      self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end
    
  private
    # Activates the user in the database.
    def activate!
      # these attributes are protected so they have to be updated individually
      self.update_attributes :activation_code => nil, :searchable => true
      # save should only run once with the @activated flag, as this cues the observer to send email via #pending?
      @activated = true
      self.update_attribute :activated_at, Time.now.utc
    end
  
end

