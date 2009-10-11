require File.dirname(__FILE__) + '/spec_helper'

describe ActiveRecord::Base do
  it "includes JustRight" do
    ActiveRecord::Base.methods.should be_member('permissions')
  end
end