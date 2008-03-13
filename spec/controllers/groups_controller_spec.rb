require File.dirname(__FILE__) + '/../spec_helper'

describe GroupsController do
  describe "create" do
    before do
      @user = User.new
      controller.stub!(:current_user).and_return(@user)
    end
    it "should not respond to GET" do
      get :create
      response.should_not be_success
    end

    it "should respond to POST" do
      controller.should_receive(:message)
      g = Group.new
      g.should_receive(:save).and_return(false)
      Group.should_receive(:new).and_return(g)
      post :create
      response.should be_success
    end

    it "should clear parent groups users cache after create" do
      parent = create_valid_group :name => 'daparent'
      @user.stub!(:member_of?).and_return(true)
      post :create, :parent_id => parent.id, :group => {:name => 'dacommittee'}
    end
  end
  describe "archive" do
    before do
      @group = create_valid_group
    end
    describe "when logged in" do
      before do
        @group.pages << create_valid_page
        @user = create_valid_user
      end

      describe "when a member" do
        before do
          @group.memberships.create(:user => @user)
          @user.stub!(:member_of?).and_return(true)
          @group.stub!(:allows?).and_return(true)
          Group.stub!(:get_by_name).and_return(@group)
          controller.stub!(:current_user).and_return(@user)
        end
        def act
          get :archive, :id => @group.name
        end
        it "should not redirect" do
          act
          response.should_not be_redirect
        end
        it "should be successful" do
          act
          response.should be_success
        end
        it "should render archive template" do
          act
          response.should render_template('groups/archive')
        end
        it "should have a valid group" do
          act
          assigns[:group].should be_valid
        end
        it "months should not be nil" do
          act
          assigns[:months].should_not be_nil
        end
      end

      describe "when a public group" do
        before do
          @group.profile.may_see = true
          @group.profile.save
          get :archive, :id => @group.name
        end
        it "should be successful" do
          pending "groups controller rendering doesn't work"
          response.should be_success
        end
        it "should render archive template" do
          pending "groups controller rendering doesn't work"
          response.should render_template('groups/archive')
        end
        it "should have a valid group" do
          assigns[:group].should be_valid
        end
        it "months should not be nil" do
          pending "groups controller rendering doesn't work"
          assigns[:months].should_not be_nil
        end
      end

      describe "when a private group" do
        before do
          @group.profile.may_see = false
          @group.profile.save
          get :archive, :id => @group.name
        end
        it "should render show_nothing" do
          pending "groups controller rendering doesn't work"
          response.should render_template('groups/show_nothing')
        end
      end
    end
    describe "when not logged in" do
      it "should be sucess for a public group" do
        pending "groups controller rendering doesn't work"
        @group.profile.may_see = true
        @group.profile.save
        get :archive, :id => @group.name
        response.should render_template('groups/archive')
      end
      it "should show nothing for a private group" do
        pending "groups controller rendering doesn't work"
        @group.profile.may_see = false
        @group.profile.save
        get :archive, :id => @group.name
        response.should render_template('groups/show_nothing')
      end
    end

    describe "when allowed" do
      before do
        @user = create_valid_user
        @group.memberships.create(:user => @user)
        controller.stub!(:current_user).and_return(@user)
        @group.pages << (p1 = create_valid_page(:created_at => Date.new(2007, 12)))
        @group.pages << (p2 = create_valid_page(:created_at => Date.new(2008, 2)))
        @group.member_collection << p1
        @group.member_collection << p2
      end
      it "should render archive" do
        get :archive, :id => @group.name
        response.should render_template('groups/archive')
      end
      it "should populate months with the months and years pages were created" do
        get :archive, :id => @group.name
        assigns[:months].length.should == 2
      end
      it "should populate months with the months and years pages were created" do
        get :archive, :id => @group.name
        assigns[:months][0]['month'].should == '12'
        assigns[:months][0]['year'].should == '2007'
      end
      it "should populate months with the months and years pages were created" do
        get :archive, :id => @group.name
        assigns[:months][1]['month'].should == '2'
        assigns[:months][1]['year'].should == '2008'
      end
      it "should populate pages with a paginated collection" do
        get :archive, :id => @group.name
        assigns[:pages].should_not be_empty
        assigns[:pages].all? {|p| p.created_at.year == 2008}.should be_true
      end
    end
  end

  describe "tasks" do
    before do
      @group = create_valid_group
      @user = create_valid_user
      controller.stub!(:current_user).and_return(@user)
    end
    it "should be successful" do
      get :tasks, :id => @group.name
      response.should be_success
    end
  end

  describe "tags" do
    before do
      user = login_valid_user 
      @group = create_valid_group
      @group.memberships.create :user => user
      @page = create_valid_page
      @page.tag_with 'tagish'
      @group.pages << @page
      @group.member_collection << @page
    end
    it "should not die" do
      get :tags, :id => @group.name, :path => ['tagish']
      assigns[:pages].should include(@page)
    end
    it "should be a paginated collection" do
      get :tags, :id => @group.name, :path => ['tagish']
      assigns[:pages].should be_a_kind_of(WillPaginate::Collection)
    end
  end
end