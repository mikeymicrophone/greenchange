require File.dirname(__FILE__) + '/../spec_helper'

describe "AuthorizedSystem" do
  
  before do
    @user = create_valid_user
    @group = create_valid_group
    @auth = AuthorizedSystem.access_policy
  end

  it "should issue anonymous access by default" do
    policy = AuthorizedSystem.access_policy
    policy.name.should == 'anonymous'
  end

  it "should issue anonymous acess when unknown access requested" do
    policy = AuthorizedSystem.access_policy :unknown_policy

    policy.name.should_not == 'unknown_policy'

    policy.class.should == AuthorizedSystem::AnonymousAccess
    policy.name.should == 'anonymous'
  end

  it "should return the correct policy" do
    policy = AuthorizedSystem.access_policy :anonymous
    policy.name.should == 'anonymous'

    policy = AuthorizedSystem.access_policy :public
    policy.name.should == 'public'

    policy = AuthorizedSystem.access_policy :member
    policy.name.should == 'member'

    policy = AuthorizedSystem.access_policy :administrator
    policy.name.should == 'administrator'
  end

  it "should allow all actions for administrators" do
    policy = AuthorizedSystem.access_policy :administrator

    policy.allows?(:any, :any).should be_true
    policy.allows?(:whatever, :another).should be_true
  end

  it "should recognize page resources by class name" do
    policy = AuthorizedSystem.access_policy :public

    wiki = Page.make :wiki, {:user => @user, :group => @group, :name => 'TestWikiResource'}
    policy.allows?(:view, wiki).should be_true
  end

  it "should recognize assets as page resources" do
    page = create_valid_page :data => create_valid_asset, :type => 'Tool::Asset'
    @auth.normalize_resource( page ).should == :page
  end
  it "should recognize wikis as page resources" do
    wiki = Page.make :wiki, {:user => @user, :group => @group, :name => 'TestWikiResource'}
    @auth.normalize_resource( wiki ).should == :wiki
  end
end