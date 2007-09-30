require File.dirname(__FILE__) + '/../test_helper'
require 'pages_controller'

# Re-raise errors caught by the controller.
class PagesController; def rescue_action(e) raise e end; end

class PagesControllerTest < Test::Unit::TestCase
  fixtures :pages, :users

  def setup
    @controller = PagesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_create
    login_as :quentin
    get :create
    assert :success
    assert_template 'create'
  end
  
  def test_login_required
    [:tag, :notify, :access, :move, :destroy].each do |action|
      assert_requires_login do |c|
        c.get action, :id => pages(:hello).id
      end
    end
  end
end
