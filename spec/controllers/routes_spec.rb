require File.dirname(__FILE__) + '/../spec_helper'

describe "Routes" do
  controller_name :pages
  before do
    controller.stub!(:login_required).and_return(true)
    get :new
  end
  it "should know from wikis_url" do
    wikis_path.should == '/wikis'
  end
  it "should know from wiki_url" do
    wiki = Tool::TextDoc.create :title => 'titleish'
    wiki_path(wiki).should == "/wikis/#{wiki.to_param}"
  end
  it "should have a memberships route" do
    memberships_path.should == '/memberships'
  end
  describe "with a group" do
    controller_name :pages
    before do
      @g = create_group
    end
    it "should have a group_memberships route" do
      group_memberships_path(@g).should == "/groups/#{@g.to_param}/memberships"
    end
    it "should have a join route" do
      new_group_join_request_path(@g).should == "/groups/#{@g.to_param}/join_requests/new"
    end
    it "but a better join route would be" do
      new_group_membership_path(@g).should == "/groups/#{@g.to_param}/memberships/new"
    end
    it "should have an invite route" do
      new_group_invitation_path(@g).should == "/groups/#{@g.to_param}/invitations/new"
    end
    it "should have a nested route for wikis" do
      group_wikis_path(@g).should == "/groups/#{@g.to_param}/wikis"
    end
    it "should have a nested route for messages" do
      new_group_message_path(@g).should == "/groups/#{@g.to_param}/messages/new"
    end
  end
  it "should know about participate route for events" do
    event = Tool::Event.create :title => 'eventish'
    participate_event_path(event).should == "/events/#{event.to_param}/participate"
  end
end
