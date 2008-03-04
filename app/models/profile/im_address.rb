=begin

=end

class Profile::ImAddress < ActiveRecord::Base
  set_table_name 'im_addresses'
  validates_presence_of :im_type
  validates_presence_of :im_address

  belongs_to :profile, :foreign_key => 'profile_id'

  after_save {|record| record.profile.save if record.profile}
  after_destroy {|record| record.profile.save if record.profile}

  def self.options
    ['Jabber', 'IRC', 'Silc', 'Gizmo', 'AIM',
    'Google Talk', 'MSN', 'Skype', 'Yahoo', 'Other'].to_localized_select
  end
end
