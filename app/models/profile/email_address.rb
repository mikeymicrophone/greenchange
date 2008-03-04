=begin

=end

class Profile::EmailAddress < ActiveRecord::Base
  set_table_name 'email_addresses'
  validates_presence_of :email_type
  validates_presence_of :email_address
  #validates_as_email :email_address
  
  belongs_to :profile, :foreign_key => 'profile_id'

  after_save {|record| record.profile.save if record.profile}
  after_destroy {|record| record.profile.save if record.profile}
  
  def self.options
    %w[Home Work School Personal Group Other].to_localized_select
  end
  
end
