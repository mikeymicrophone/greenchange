require File.dirname(__FILE__) + '/../spec_helper'

describe "Authenticated User" do

  it "should require login" do
    iu = User.new( { :login => nil } ) 
    iu.should_not be_valid
  end

  it "should require a password" do
    iu = User.new( { :password => nil } ) 
    iu.should_not be_valid
  end

  it "should require password confirmation" do
    iu = User.new( { :password_confirmation => nil } ) 
    iu.should_not be_valid
  end

  it "should reset password" do
    user = create_valid_user
    user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    User.authenticate('jones','new password').should_not be_nil
  end

  it "should not rehash the password" do
    user = create_valid_user
    user.update_attributes(:login => 'jonez')
    User.authenticate('jonez','joke').should_not be_nil
  end

  it "should authenticate a known user" do
    user = create_valid_user
    User.authenticate('jones','joke').should_not be_nil
  end

  it "should set remember token" do
    user = create_valid_user
    user.remember_me

    user.remember_token.should_not be_nil
    user.remember_token_expires_at.should_not be_nil
  end

  it "should unset remember token" do
    user = create_valid_user
    user.forget_me

    user.remember_token.should be_nil
    user.remember_token_expires_at.should be_nil
  end
end
