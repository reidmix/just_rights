require File.dirname(__FILE__) + '/spec_helper'

describe ActiveRecord::Base do
  it "includes JustRight" do
    ActiveRecord::Base.methods.should be_member('permissions')
  end
end

describe ActionController::Base do
  it 'returns :forbidden for PermissionSystem::ForbiddenAccess' do
    ActionController::Base.rescue_responses['PermissionSystem::ForbiddenAccess'].should == :forbidden
  end

  it 'can load constant PermissionSystem::ForbiddenAccess' do
    defined?(PermissionSystem::ForbiddenAccess).should be_true
  end
end
