# == Schema Information
# Schema version: 24
#
# Table name: groups
#
#  id             :integer(11)   not null, primary key
#  name           :string(255)   
#  summary        :string(255)   
#  url            :string(255)   
#  type           :string(255)   
#  parent_id      :integer(11)   
#  admin_group_id :integer(11)   
#  council        :boolean(1)    
#  created_at     :datetime      
#  updated_at     :datetime      
#  avatar_id      :integer(11)   


#  group.name       => string
#  group.summary    => string
#  group.url        => string
#  group.council    => boolean
#  group.created_on => date
#  group.updated_on => time
#  group.children   => groups
#  group.parent     => group
#  group.admin_group  => nil or group
#  group.nodes      => nodes
#  group.users      => users
#  group.picture    => picture


class Group < ActiveRecord::Base
  define_index do
    indexes :name
    indexes full_name
    indexes [locations.city, locations.state, locations.country_name], :as => :location
    indexes summary
    indexes issues(:name), :as => :issues
    set_property :delta => true
  end
  include Crabgrass::Serializeable
  attr_protected :featured

  has_many :locations, :class_name => 'ProfileLocation'

  attr_accessor :location_data
  def location_data=(attributes)
    if locations.empty?
      locations.build( attributes ) unless attributes.values.all? {|v| v.blank?}
    else
      locations.first.attributes = attributes
    end
  end

  def location_data
    if locations.empty?
      locations.build
    else
      locations.first
    end
  end

  after_save :save_location
  def save_location
    locations.each {|loc| loc.save}
  end

  #track_changes :name
  acts_as_modified
  acts_as_fleximage do
    image_directory 'public/images/uploaded/icons/groups' 
    require_image false
    preprocess_image { |image| image.resize Crabgrass::Config.image_sizes[:large], :crop => true }
  end

  ####################################################################
  ## about this group

  include Crabgrass::ActiveRecord::Collector

  before_validation :clean_names
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :parent_id
  validates_format_of :name, :with => /^[a-z0-9]+([-\+_]*[a-z0-9]+){1,49}$/, :message => 'may only contain letters, numbers, underscores, and hyphens'
  validates_length_of :name, :in => 3..50, :message => 'must be at least 3 and no more than 50 characters'

  has_collections :admin, :member, :public, :unrestricted

  def clean_names
    t_name = read_attribute(:name)
    if t_name
      write_attribute(:name, t_name.downcase)
    end
    
    t_name = read_attribute(:full_name)
    if t_name
      write_attribute(:full_name, t_name.gsub(/[&<>]/,''))
    end
  end

  # the code shouldn't call find_by_name directly, because the group name
  # might contain a space in it, which we store in the database as a plus.
  def self.get_by_name(name)
    return nil unless name
    Group.find_by_name(name.gsub(' ','+'))
  end

  has_many :issue_identifications, :as => :issue_identifying
  has_many :issues, :through => :issue_identifications, :order => 'name'
#  def issue_ids=(issue_ids)
#    issue_identifications.each do |issue_identification|
#      issue_identification.destroy unless issue_ids.include?(issue_identification.issue_id)
#    end
#    issue_ids.each do |issue_id|
#      self.issue_identifications.create(:issue_id => issue_id) unless issue_identifications.any? {|issue_identification| issue_identification.issue_id == issue_id}
#    end
#  end
  def issue_ids=(issue_id_values)
    issue_identifications.each do |issue_identification|
      issue_identification.destroy unless issue_id_values.include?(issue_identification.issue_id)
    end
    issue_id_values.each do |issue_id|
      self.issue_identifications.build(:issue_id => issue_id) unless issue_identifications.any? {|issue_identification| issue_identification.issue_id == issue_id}
    end
  end


  has_finder :by_issue, lambda {|*issues| issues.any? ? {:include => :issue_identifications, :conditions => ["issue_identifications.issue_id in(?)", issues]} : {} }

  #belongs_to :avatar
  has_one :public_profile, :as => 'entity', :dependent => :destroy, :conditions => ["stranger = ?", true], :class_name => 'Profile'
  def profile
    public_profile || create_public_profile(:stranger => 'true')
  end

  def page
    profile.create_wiki
  end
  
  # name stuff
  def to_param; name; end
  def display_name; full_name ? full_name : name;  end
  def short_name; name; end
  def cut_name; name[0..20]; end
  #def full_name; name; end

  # visual identity
  def banner_style
    @style ||= Style.new(:color => "#eef", :background_color => "#1B5790")
  end
   
  def committee?; instance_of? Committee; end
  def network?; instance_of? Network; end
  def normal?; instance_of? Group; end  
  

  ####################################################################
  ## relationships to users

  has_one :admin_group, :class_name => 'Group', :foreign_key => 'admin_group_id'
    
  has_many :memberships, :dependent => :destroy,
    :after_add => :membership_changed, :after_remove => :membership_changed  

  has_many :join_requests, :as => :requestable, :class_name => 'JoinRequest'

  has_many :gives_permissions,  :as => 'grantor', :class_name => 'Permission'
  has_many :given_permissions,  :as => 'grantee', :class_name => 'Permission'

  def admins_ids
    admins.map(&:id)
  end

  has_many :admin_memberships, 
           :conditions => ["role = 'administrator'"], :class_name => 'Membership', :after_add => :set_admin_role do
  end
  has_many :admins, :through => :admin_memberships, :source => :user do
    def << ( *args )
      args.map { |new_member| @owner.admin_memberships.create :user => new_member }
    end
  end

  def set_admin_role(membership)
    membership.update_attribute :role, :administrator
  end

  has_many :users, :through => :memberships do
    #def <<(*dummy)
    #  raise Exception.new("don't call << on group.users");
    #end
  end
  alias :members :users
  alias :people :users

  has_finder :by_person, lambda {|*people|  
    people.any? ? { :include => :memberships, :conditions => [ "memberships.user_id in(?)", people ]  } : {}
    }

  has_finder :shared, lambda {|has_groups|
    { :conditions => ["groups.id IN (?)", has_groups.group_ids] }
    }
  
  def user_ids
    @user_ids ||= memberships.collect{|m|m.user_id}
  end

  def check_duplicate_memberships(membership)
    membership.user.check_duplicate_memberships(membership)
  end

  def membership_changed(membership)
    @user_ids = nil
    membership.user.update_membership_cache membership
  end

  def relationship_to(user)
    relationships_to(user).first
  end
  def relationships_to(user)
    return [:stranger] unless user
    (@relationships ||= {})[user.login] ||= get_relationships_to(user)
  end
  def get_relationships_to(user)
    ret = []
#   ret << :admin    if ...
    ret << :member   if user.member_of?(self)
#   ret << :peer     if ...
    ret << :stranger if ret.empty?
    ret
  end
  
# maps a user <-> group relationship to user <-> language
#  def in_user_terms(relationship)
#    case relationship
#      when :member;   'friend'
#      when :ally;     'peer'
#      else; relationship.to_s
#    end  
#  end
  
  # whenever the structure of this group has changed 
  # (ie a committee or network has been added or removed)
  # this function should be called to update each user's
  # membership cache.
  def update_membership_caches
    users.each do |u|
      u.update_membership_cache
    end
  end
  
  ####################################################################
  ## relationship to pages
  
  has_many :participations, :class_name => 'GroupParticipation', :dependent => :delete_all
  has_many :pages, :through => :participations do
    def pending
      find(:all, :conditions => ['resolved = ?',false], :order => 'happens_at' )
    end
    def find_with_access(*args)
      user = args[1].delete(:user)
      scope = if user
        if user.member_of?(proxy_owner)
          {}
        else
          {:conditions => ["pages.public = ? OR user_participations.user_id = ? OR group_participations.group_id IN (?)", true, user.id, user.all_group_ids], :include => [:user_participations, :group_participations]}
        end
      else
        {:conditions => ["pages.public = ?", true]}
      end
      with_scope(:find => scope) do
        find(*args)
      end
    end
  end

  def add_page(page, attributes)
    page.group_participations.create attributes.merge(:page_id => page.id, :group_id => id)
    page.changed :groups
  end

  def remove_page(page)
    page.groups.delete(self)
    page.changed :groups
  end
  
  has_many :tags, :finder_sql => %q[
    SELECT DISTINCT tags.* FROM tags INNER JOIN taggings ON tags.id = taggings.tag_id
    WHERE taggings.taggable_type = 'Page' AND taggings.taggable_id IN
      (SELECT pages.id FROM pages INNER JOIN group_participations ON pages.id = group_participations.page_id
      WHERE group_participations.group_id = #{id})],
    :counter_sql => %q[
    SELECT COUNT(*) FROM tags INNER JOIN taggings ON tags.id = taggings.tag_id
    WHERE taggings.taggable_type = 'Page' AND taggings.taggable_id IN
      (SELECT pages.id FROM pages INNER JOIN group_participations ON pages.id = group_participations.page_id
      WHERE group_participations.group_id = #{id})]

  has_many :taggings, :through => :pages

  #results from this one are read-only
  has_finder :by_tag, lambda{|*tags| tags.any? ? { :include => [:pages, :participations], :joins => joins_for_by_tag, :conditions => ["taggings.tag_id in (?)", tags] } : {} }
  
  def self.joins_for_by_tag
    case connection.adapter_name
    when "SQLite"
      "INNER JOIN taggings on ( taggings.taggable_id = pages.id or taggings.taggable_id = group_participations.page_id )"
    when "MySQL"
      "RIGHT JOIN taggings on ( taggings.taggable_id = pages.id or taggings.taggable_id = group_participations.page_id )"
    end
  end
  
  # the group is responsible for a given user's membership
  def membership_for(user)
    memberships.find(:first,
        :conditions => ["user_id = ? AND group_id = ?", user.id, id]
    )
  end

  # return all permissions granted by this group to the given user
  def permissions_for(user)
    gives_permissions.find(:all,
        :conditions => [
          "permissions.grantee_type = 'User' AND "+
          "permissions.grantee_id = ? ",
          user.id
        ]
    )
  end

  # return the user's membership role in this group
  def role_for(user)
    unless user.direct_member_of? self
      AuthorizedSystem::Role.new # default role
    else
      membership = membership_for(user)
      AuthorizedSystem::Role.new( membership.nil? ? '' : membership.role )
    end
  end

  has_finder :allowed, {} #do nothing for now
  has_finder :featured, :conditions =>[ 'groups.featured = ?', true ]

  # check if user has permission to perform action. the optional resource
  # will be used if given, otherwise the :group resource is used.
  def allows?(user, action, resource = nil)
    return true if user.superuser?
    return true if role_for(user).allows?(action, resource.nil? ? :group : resource)
    return Permission.granted?(action, resource, self, user) unless resource.is_a? Symbol
    return false
  end

  def months_with_pages_viewable_by_user(user)
    case Page.connection.adapter_name
    when "SQLite"
      dates = sqlite_months_string
    when "MySQL"
      dates = mysql_months_string
    else
      raise "#{Article.connection.adapter_name} is not yet supported here"
    end
    sql = "SELECT #{dates}, count(pages.id) " +
     "FROM pages JOIN group_participations ON pages.id = group_participations.page_id " +
     "WHERE group_participations.group_id = #{id}"
    unless allows?(user, :view, :page)
      sql += " AND pages.public = 1"
    end
    sql += " GROUP BY year, month ORDER BY year, month"
    months = Page.connection.select_all(sql)
    months.each {|m| m['month'].gsub!(/^0/,'')}
    months
  end

  def sqlite_months_string
    "strftime('%m', created_at) AS month, strftime('%Y', created_at) AS year"
  end

  def mysql_months_string
    "MONTH(pages.created_at) AS month, YEAR(pages.created_at) AS year"
  end

  ####################################################################
  ## relationship to other groups

#  has_many :federations
#  has_many :networks, :through => :federations

  # committees are children! they must respect their parent group.  
  acts_as_tree :order => 'name'
  alias :committees :children
    
  # returns an array of all children ids and self id (but not parents).
  # this is used to determine if a group has access to a page.
  def group_and_committee_ids
    @group_ids ||= ([self.id] + Group.committee_ids(self.id))
  end
  
  # returns an array of committee ids given an array of group ids.
  def self.committee_ids(ids)
    ids = [ids] unless ids.instance_of? Array
    return [] unless ids.any?
    ids = ids.join(',')
    Group.connection.select_values("SELECT groups.id FROM groups WHERE parent_id IN (#{ids})").collect{|id|id.to_i}
  end
    
  # returns a list of group ids for the page namespace
  # (of the group_ids passed in).
  # wtf does this mean? for each group id, we get the ids
  # of all its relatives (parents, children, siblings).
  def self.namespace_ids(ids)
    ids = [ids] unless ids.instance_of? Array
    return [] unless ids.any?
    ids = ids.join(',')
    parent_ids = Group.connection.select_values("SELECT groups.parent_id FROM groups WHERE groups.id IN (#{ids})").collect{|id|id.to_i}
    return ([ids] + committee_ids(ids) + parent_ids + committee_ids(parent_ids)).flatten.uniq
  end
  
  ######################################################
  ## temp stuff for profile transition
  ## should be removed eventually
    
  def publicly_visible_group
    profile.may_see?
  end
  def publicly_visible_group=(val)
    profile.update_attribute :may_see, val
  end

  def publicly_visible_committees
    profile.may_see_committees?
  end
  def publicly_visible_committees=(val)
    profile.update_attribute :may_see_committees, val
  end

  def publicly_visible_members
    profile.may_see_members?
  end
  def publicly_visible_members=(val)
    profile.update_attribute :may_see_members, val
  end

  def accept_new_membership_requests
    profile.may_request_membership?
  end
  def accept_new_membership_requests=(val)
    profile.update_attribute :may_request_membership, val
  end


  protected
  
  after_save :update_name
  def update_name
    if name_modified?
      update_group_name_of_pages  # update cached group name in pages
      #Wiki.clear_all_html(self)   # in case there were links using the old name
      # update all committees (this will also trigger the after_save of committees)
      committees.each {|c| c.update_parent(self)}
    end
  end
   
  def update_group_name_of_pages
    Page.connection.execute "UPDATE pages SET `group_name` = '#{self.name}' WHERE pages.group_id = #{self.id}"
  end
    
  after_create :clear_user_caches
  after_destroy :clear_user_caches

  def clear_user_caches
    parent.users.each do |u|
      u.clear_cache
    end if parent
  end
 
  def self.per_page
    48
  end
end
