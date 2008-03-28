=begin

=end

class Profile::PhoneNumber < ActiveRecord::Base
  set_table_name 'phone_numbers'
  validates_presence_of :phone_number_type
  validates_presence_of :phone_number

  belongs_to :profile#, :foreign_key => 'profile_id'

  #after_save {|record| record.profile.save if record.profile}
  #after_destroy {|record| record.profile.save if record.profile}
  
  def self.options
  end
  
end
