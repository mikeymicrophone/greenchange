# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'spec'
require 'spec/rails'
require 'pp'
require 'ruby-debug'

Spec::Runner.configure do |config|
  # If you're not using ActiveRecord you should remove these
  # lines, delete config/database.yml and disable :active_record
  # in your config/boot.rb
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'

  # == Fixtures
  #
  # You can declare fixtures for each example_group like this:
  #   describe "...." do
  #     fixtures :table_a, :table_b
  #
  # Alternatively, if you prefer to declare them only once, you can
  # do so right here. Just uncomment the next line and replace the fixture
  # names with your fixtures.
  #
  # config.global_fixtures = :table_a, :table_b
  config.global_fixtures = :users
  #
  # If you declare global fixtures, be aware that they will be declared
  # for all of your examples, even those that don't use them.
  #
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  config.before do
    User.current = nil
  end

  def create_valid_page(options = {})
    @page = Page.create({:title => 'valid_page'}.merge(options))
  end

  def create_valid_asset
    Asset.create! :filename => 'test.jpg', :size => '100', :content_type => 'image/jpg'
  end

  def create_valid_user( options = {} )
    valid_user = User.new( { :login => "jones", :email => "aviary@birdcage.com", :password => "joke", :password_confirmation => "joke"}.merge( options ))
    valid_user.profiles.build :first_name => "Plus", :last_name => "Ca Change", :friend => true
    valid_user.save!
    valid_user
  end

  def create_valid_group(options={})
    valid_group = Group.create({:name => 'valid_group'}.merge(options))
  end

  def create_valid_group
    valid_group = Group.create :name => 'valid_group'
  end

  def login_valid_user( options = {} )
    current_user = create_valid_user( options )
    User.current = current_user
    controller.stub!(:current_user).and_return(current_user)
  end
end

def asset_fixture_path(filename)
  File.join(RAILS_ROOT, 'test', 'fixtures', 'files', filename)
end
