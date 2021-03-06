require File.dirname(__FILE__) + '/../spec_helper'

describe Bookmark do
  describe "on create" do
    it "should make a valid bookmark" do
      b = Bookmark.create :url => "http://nytimes.com", :page_id => 1, :user_id => 1, :description => 'a description'
      b.should be_valid
      b.url.should == 'http://nytimes.com'
      b.page_id.should == 1
      b.user_id.should == 1
      b.description.should == 'a description'
    end
  
    it "should not create duplicate bookmarks" do
      b = Bookmark.create :page => (@page = create_page), :user => (@user = create_user)
      c = Bookmark.create :page => @page, :user => @user
      c.should_not be_valid
    end
  end

  describe "when tagging" do
    it "remembers tags" do
      b = Bookmark.create
      b.tag_with ['tag', 'gat']
      b.tag_list.should include('tag')
      b.tag_list.should include('gat')
    end
  end

  include PageUrlHelper
  it "should show the url if url" do
    b = Bookmark.create :page => (p = create_page)
    b.url.should == page_url(p)
  end
end
