# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'spec'
require 'spec/rails'
require 'pp'
#require 'ruby-debug'

Spec::Runner.configure do |config|
  # If you're not using ActiveRecord you should remove these
  # lines, delete config/database.yml and disable :active_record
  # in your config/boot.rb
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  config.include FixtureReplacement
  config.include AuthenticatedSpecHelper

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
    TzTime.zone = TimeZone[DEFAULT_TZ]
    #User.current = nil
  end

  def create_valid_asset
    Asset.create! :filename => 'test.jpg', :size => '100', :content_type => 'image/jpg'
  end

  def login_user(user)
    controller.stub!(:current_user).and_return(user)
  end
end

def asset_fixture_path(filename)
  File.join(RAILS_ROOT, 'test', 'fixtures', 'files', filename)
end

# user permissions matcher
class BeAllowed
  def initialize(act, on_resource)
    @act = act
    @on_resource = on_resource
  end

  def matches?(user)
    @user = user
    @user.may?(@act, @on_resource).eql? true
  end

  def failure_message
    name = @user.is_a?(AuthenticatedUser) ? @user.login : 'anonymous user'
    "expected #{name} to be allowed to #{@act} #{@on_resource}"
  end

  def negative_failure_message
    name = @user.is_a?(AuthenticatedUser) ? @user.login : 'anonymous user'
    "expected #{name} not to be allowed to #{@act} #{@on_resource}"
  end
end

# resource permissions matcher
class Allows
  def initialize(user, act)
    @act = act
    @user = user
  end

  def matches?(resource)
    @resource = resource
    @resource.allows?(@user, @act).eql? true
  end

  def failure_message
    "expected #{@resource.inspect} to allow #{@user.login} to #{@act} #{@resource}"
  end

  def negative_failure_message
    "expected #{@resource.inspect} not to allow #{@user.login} to #{@act} #{@resource}"
  end
end

def be_allowed_to(act, on_resource)
  BeAllowed.new(act, on_resource)
end

def allows(user, act)
  Allows.new(user, act)
end

def sphinx_pid
  config = ThinkingSphinx::Configuration.new
  
  if File.exists?(config.pid_file)
    `cat #{config.pid_file}`[/\d+/]
  else
    nil
  end
end

def sphinx_running?
  sphinx_pid && `ps -p #{sphinx_pid} | wc -l`.to_i > 1
end

def reindex(indexes='--all', sleep_time=1)
  config = ThinkingSphinx::Configuration.new
  FileUtils.mkdir_p config.searchd_file_path
  %x[indexer --config #{config.config_file} --rotate --quiet #{indexes}]
  sleep(sleep_time)
end
