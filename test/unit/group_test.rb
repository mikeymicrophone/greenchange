require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < Test::Unit::TestCase
  fixtures :groups, :users

  def test_memberships
    g = Group.create :name => 'fruits'
    u = users(:blue)
    assert_equal 0, g.users.size, 'there should be no users'
    assert_raises(Exception, '<< should raise exception not allowed') do
      g.users << u
    end
    g.memberships.create :user => u
    g.memberships.create :user_id => users(:red).id, :page_id => 1

    assert u.member_of?(g), 'user should be member of group'
    
    g.memberships.each do |m|
      m.destroy
    end
    g.reload
    assert_equal 0, g.users.size, 'there should be no users'
  end

  def test_missing_name
    g = Group.create
    assert !g.valid?, 'group with no name should not be valid'
  end

  def test_duplicate_name
    g1 = Group.create :name => 'fruits'
    assert g1.valid?, 'group should be valid'

    g2 = Group.create :name => 'fruits'
    assert g2.valid? == false, 'group should not be valid'
  end

  def test_try_to_create_group_with_same_name_as_user
    u = User.find(1)
    assert u.login, 'user should be valid'

    g = Group.create :name => u.login
    assert g.valid? == false, 'group should not be valid'
    assert g.save == false, 'group should fail to save'
  end

  def test_associations
    assert check_associations(Group)
  end

  def test_cant_pester_private_group
    g = Group.create :name => 'riseup'
    g.publicly_visible_group = false
    u = User.create :login => 'user'
    
    assert g.may_be_pestered_by?(u) == false, 'should not be able to be pestered by user'
    assert u.may_pester?(g) == false, 'should not be able to pester private group'
  end

  def test_can_pester_public_group
    g = Group.create :name => 'riseup'
    g.publicly_visible_group = true
    u = User.create :login => 'user'
    
    assert g.may_be_pestered_by?(u) == true, 'should be able to be pestered by user'
    assert u.may_pester?(g) == true, 'should be able to pester private group'
  end

  def test_association_callbacks
    g = Group.create :name => 'callbacks'
    g.expects(:check_duplicate_memberships)
    g.expects(:membership_changed)
    u = users(:blue)
    g.memberships.create(:user => u)
  end
end
