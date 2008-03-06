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

  #track_changes :name
  acts_as_modified

  ####################################################################
  ## about this group

  include CrabgrassDispatcher::Validations
  include Crabgrass::ActiveRecord::Collector

  validates_handle :name
  before_validation :clean_names

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
  has_many :issues, :through => :issue_identifications
  def issue_ids=(issue_ids)
    issue_identifications.each do |issue_identification|
      issue_identification.destroy unless issue_ids.include?(issue_identification.issue_id)
    end
    issue_ids.each do |issue_id|
      self.issue_identifications.create(:issue_id => issue_id) unless issue_identifications.any? {|issue_identification| issue_identification.issue_id == issue_id}
    end
  end

  belongs_to :avatar
  has_many :profiles, :as => 'entity', :dependent => :destroy, :extend => Profile::Methods
  
  has_many :tags, :finder_sql => %q[
    SELECT DISTINCT tags.* FROM tags INNER JOIN taggings ON tags.id = taggings.tag_id
    WHERE taggings.taggable_type = 'Page' AND taggings.taggable_id IN
      (SELECT pages.id FROM pages INNER JOIN group_participations ON pages.id = group_participations.page_id
      WHERE group_participations.group_id = #{id})]
  
  # name stuff
  def to_param; name; end
  def display_name; full_name.any? ? full_name : name; end
  def short_name; name; end
  def cut_name; name[0..20]; end

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
    :before_add => :check_duplicate_memberships,
    :after_add => :membership_changed, :after_remove => :membership_changed  
  has_many :users, :through => :memberships do
    def <<(*dummy)
      raise Exception.new("don't call << on group.users");
    end
  end
  
  def user_ids
    @user_ids ||= memberships.collect{|m|m.user_id}
  end

  def check_duplicate_memberships(membership)
    membership.user.check_duplicate_memberships(membership)
  end

  def membership_changed(membership)
    @user_ids = nil
    membership.user.update_membership_cache
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
  
  def may_be_pestered_by?(user)
    return true if user.member_of?(self)
    return true if publicly_visible_group
    return parent.may_be_pestered_by?(user) if parent && parent.publicly_visible_committees
    return false
  end
  
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
  
  def may?(perm, page)
    begin
       may!(perm,page)
    rescue PermissionDenied
       false
    end
  end
  
  # perm one of :view, :edit, :admin
  # this is still a basic stub. see User.may!
  def may!(perm, page)
    gparts = page.participation_for_groups(group_and_committee_ids)
    return true if gparts.any?
    raise PermissionDenied
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
  
#  has_and_belongs_to_many :locations,
#    :class_name => 'Category'
#  has_and_belongs_to_many :categories
  
  ######################################################
  ## temp stuff for profile transition
  ## should be removed eventually
    
  def publicly_visible_group
    profiles.public.may_see?
  end
  def publicly_visible_group=(val)
    profiles.public.update_attribute :may_see, val
  end

  def publicly_visible_committees
    profiles.public.may_see_committees?
  end
  def publicly_visible_committees=(val)
    profiles.public.update_attribute :may_see_committees, val
  end

  def publicly_visible_members
    profiles.public.may_see_members?
  end
  def publicly_visible_members=(val)
    profiles.public.update_attribute :may_see_members, val
  end

  def accept_new_membership_requests
    profiles.public.may_request_membership?
  end
  def accept_new_membership_requests=(val)
    profiles.public.update_attribute :may_request_membership, val
  end


  protected
  
  after_save :update_name
  def update_name
    if name_modified?
      update_group_name_of_pages  # update cached group name in pages
      Wiki.clear_all_html(self)   # in case there were links using the old name
      # update all committees (this will also trigger the after_save of committees)
      committees.each {|c| c.parent_name_change }
    end
  end
   
  def update_group_name_of_pages
    Page.connection.execute "UPDATE pages SET `group_name` = '#{self.name}' WHERE pages.group_id = #{self.id}"
  end
    
end
