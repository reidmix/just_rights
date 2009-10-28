require File.dirname(__FILE__) + '/spec_helper'

class MockController
  def controller_name() 'mock' end
  class << self
    attr_reader :filter

    def helper(*args) end
    def helper_method(*args) end
    def before_filter(options, &block)
      @filter = block
    end
  end
end

describe PermissionSystem do
  describe PermissionSystem::ForbiddenAccess do
    it 'is a standard error' do
      PermissionSystem::ForbiddenAccess.superclass.should == StandardError
    end
  end

  describe :included do
    before do
      @mock = Class.new(MockController)
    end

    it 'adds helper_methods' do
      @mock.should_receive(:helper_method).with(:rights_for, :rights, :authorized_by)
      @mock.send :include, PermissionSystem
    end

    it 'adds rights helper' do
      @mock.should_receive(:helper).with(:rights)
      @mock.send :include, PermissionSystem
    end

    it 'extends with PermissionSystem::ClassMethods' do
      @mock.send :include, PermissionSystem
      (class << @mock; self; end).ancestors.should be_member(PermissionSystem::ClassMethods)
    end
  end

  describe :controller do
    before do
      @mock = Class.new(MockController)
      @mock.send :include, PermissionSystem
      @controller = @mock.new
    end

    describe :authorized_by do
      before do
        @controller.stub!(:rights_for).and_return @permission = mock("Permission", :can? => true)
      end

      it 'returns false if nil or false' do
        @controller.send(:authorized_by, nil).should be_false
        @controller.send(:authorized_by, false).should be_false
      end

      it 'uses :default permission if not a collection' do
        @controller.should_receive(:rights_for).with(:default).and_return @permission
        @controller.send(:authorized_by, :right)
      end

      it 'is true if a permission can perform right' do
        @controller.send(:authorized_by, :right).should be_true
      end

      it 'is true if any permission can perform right' do
        @permission.stub!(:can?).with(:read).and_return false
        @permission.stub!(:can?).with(:write).and_return true
        @controller.send(:authorized_by, :file => :read, :file => :write).should be_true
      end

      it 'is false if a permission cannot perform right' do
        @permission.should_receive(:can?).and_return false
        @controller.send(:authorized_by, :right).should be_false
      end

      it 'is true if no permission can perform right' do
        @permission.stub!(:can?).with(:read).and_return false
        @permission.stub!(:can?).with(:write).and_return false
        @controller.send(:authorized_by, :file => :read, :file => :write).should be_false
      end
    end

    describe :current_rights do
      it 'returns current_rights if defined' do
        @controller.instance_variable_set('@current_rights', :mock_rights)
        @controller.send(:current_rights).should == :mock_rights
      end

      it 'sets @current_rights to a new HashWithIndifferentAccess when not defined' do
        @controller.instance_variable_get('@current_rights').should be_nil
        rights = @controller.send(:current_rights)

        rights.should be_kind_of(HashWithIndifferentAccess)
        rights.keys.should be_empty
        @controller.instance_variable_get('@current_rights').should == rights
      end
    end

    describe :grant_rights_for do
      it 'merges hash to current_rights' do
        rights = @controller.send(:current_rights)
        rights.should_receive(:merge!).with(:foo => :mock_permission)
        @controller.send :grant_rights_for, :foo => :mock_permission
      end

      it 'will place rights to be retrieved by current_rights' do
        @controller.send :grant_rights_for, :foo => :mock_permission
        @controller.send(:current_rights).should == {'foo' => :mock_permission}
      end
    end

    describe :rights_for do
      before do
        @controller.send(:grant_rights_for, :foo => :mock_permission)
      end

      it 'retrieves a named right' do
        @controller.send(:rights_for, :foo).should == :mock_permission
        @controller.send(:rights_for, 'foo').should == :mock_permission
      end

      it 'returns a default permission with no capabilities on miss' do
        permission = @controller.send(:rights_for, :bar)
        permission.should be_kind_of(JustRights::Permission)
        permission.capabilities.should be_empty
      end
    end

    describe :rights do
      it 'returns rights_for default' do
        @controller.should_receive(:rights_for).with :default
        @controller.send :rights
      end

      it 'returns a default permission if not set' do
        permission = @controller.send :rights
        permission.should be_kind_of(JustRights::Permission)
        permission.capabilities.should be_empty
      end

      it 'returns right set as default' do
        @controller.send(:grant_rights_for, :default => :mock_permission)
        @controller.send(:rights).should == :mock_permission
      end
    end

    describe :rights= do
      it 'returns rights set' do
        @controller.send(:rights=, :mock_permission).should == :mock_permission
      end

      it 'returns right set by rights=' do
        @controller.send(:rights=, :mock_permission)
        @controller.send(:rights).should == :mock_permission
      end
    end

    describe PermissionSystem::ClassMethods do
      it 'defines verify_access options' do
        @mock.methods.should be_member('verify_access')
      end

      describe :verify_access do
        it 'removes "can?" and "deny" (key symbols) before defining before_filter' do
          @mock.should_receive(:before_filter).with('only' => :foo)
          @mock.send :verify_access, :can? => {:resource => :right}, :deny => 'Nope', :only => :foo
        end

        it 'removes "can?" and "deny" (key strings) before defining before_filter' do
          @mock.should_receive(:before_filter).with('only' => :foo)
          @mock.send :verify_access, 'can?' => {:resource => :right}, 'deny' => 'Nope', 'only' => :foo
        end

        describe :before_filter do
          before do
            @mock.send :verify_access, :can? => {:resource => :right}, :deny => 'Nope', :only => :foo
          end

          it 'raises error if not authorized by rights' do
            @controller.should_receive(:authorized_by).with({'resource' => :right}).and_return false
            lambda { @mock.filter.call(@controller) }.should raise_error(PermissionSystem::ForbiddenAccess, 'Nope')
          end

          it 'raises no error if authorized by rights' do
            @controller.should_receive(:authorized_by).with({'resource' => :right}).and_return true
            lambda { @mock.filter.call(@controller) }.should_not raise_error(PermissionSystem::ForbiddenAccess)
          end
        end
      end
    end
  end
end
