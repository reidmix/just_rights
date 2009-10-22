require File.dirname(__FILE__) + '/spec_helper'

class MockRightsResource
  def initialize
    @attributes, @sticky = {}, false
  end

  def []= key, value
    @attributes[key] = value
  end

  def [] key
    @attributes[key]
  end
end

describe JustRights do
  before do
    @class = Class.new(MockRightsResource) do
      include JustRights
    end
  end

  describe :included do
    it 'should add permissions class method' do
      @class.respond_to?(:permissions).should be_true
    end
  end

  describe :permissions do
    describe 'on resource' do
      it 'returns generated Permission subclass' do
        @class.permissions.superclass.should == JustRights::Permission
        @class::Permission.superclass.should == JustRights::Permission
      end

      it 'returns generated Permission on class' do
        @class.permissions.should == @class::Permission
      end

      it 'sets types on Permission' do
        @class.permissions(:create, :review, :update, :delete)
        @class::Permission.types == [:create, :review, :update, :delete]
      end

      it 'ensures types are symbols' do
        @class.permissions(*%w[create review update delete])
        @class::Permission.types == [:create, :review, :update, :delete]
      end

      it 'freezes types' do
        @class.permissions(*%w[create review update delete])
        @class::Permission.types.should be_frozen
        lambda { @class::Permission.types << :admin }.should raise_error(TypeError, "can't modify frozen array")
      end

      it 'sets undefined default' do
        @class.permissions(:create, :review, :update, :delete)
        @class::Permission.default.should == 0
      end

      it 'sets specified default' do
        @class.permissions(:create, :review, :update, :delete, :default => [:create, :update])
        @class::Permission.default.should == 5
      end

      describe 'defined methods' do
        before do
          @class.permissions(:create, :review, :update, :delete, :default => %w[create update])
          @mock = @class.new
        end

        it 'defines setter and getters' do
          @mock.respond_to?(:permission).should be_true
          @mock.respond_to?(:permission=).should be_true
          @mock.respond_to?(:set_permissions).should be_true
          @mock.respond_to?(:permission_attributes=).should be_true
        end

        describe :permission do
          before do
            @mock['rights'] = 9
          end

          it 'returns correct Permission class' do
            @mock.permission.class.should == @class::Permission
            @mock.permission.class.superclass.should == JustRights::Permission
          end

          it 'sets the correct bitmask, has correct capabilities' do
            @mock.permission.send(:bitmask).should == 9
            @mock.permission.capabilities.should == [:create, :delete]
          end

          it 'is not sticky' do
            @mock.permission.send(:sticky).should be_false
          end

          it 'sets sticky to false' do
            @mock.stub!(:sticky).and_return false
            @mock.sticky.should be_false
            @mock.permission.send(:sticky).should be_false
          end

          it 'sets sticky to true' do
            @mock.stub!(:sticky).and_return true
            @mock.sticky.should be_true
            @mock.permission.send(:sticky).should be_true
          end

          it 'sets the parent' do
            @mock.permission.send(:parent).should == @mock
          end
        end

        describe :permission= do
          it 'accepts generated Permission class' do
            lambda { @mock.permission = @class::Permission.for(:create) }.should_not raise_error
          end

          it 'rejects class not generated Permission class' do
            lambda { @mock.permission = [:create] }.should raise_error(ActiveRecord::AssociationTypeMismatch, /expected, got Array/)
          end

          it 'sets bitmask on rights column' do
            @mock.permission = @class::Permission.for
            @mock['rights'].should == 0

            @mock.permission = @class::Permission.for(:create)
            @mock['rights'].should == 1

            @mock.permission = @class::Permission.for(:create, :delete)
            @mock['rights'].should == 9
          end
        end

        describe :default_permissions! do
          it 'sets bitmask to default' do
            @mock['rights'] = 0
            @mock.default_permissions!
            @mock['rights'].should == 5
          end
        end

        describe :set_permissions do
          it 'sets permission using generated Permission.for()' do
            @class::Permission.should_receive(:for).with(:create, :delete).and_return(:permission)
            @mock.should_receive(:permission=).with(:permission)

            @mock.set_permissions :create, :delete
          end
        end

        describe :permission_attributes= do
          it 'sets each key value on the permission' do
            @mock.stub!(:permission).and_return(@permission = mock(@class::Permission))
            @permission.should_receive(:[]=).with('a', '1')
            @permission.should_receive(:[]=).with(:b, 2)
            @mock.permission_attributes = [['a', '1'], [:b, 2]]
          end
        end
      end
    end

    describe 'with resources' do
      it 'returns generated different Permission subclasses' do
        @class.permissions(:on => :post).superclass.should == JustRights::Permission
        @class::PostPermission.superclass.should == JustRights::Permission

        @class.permissions(:on => :copy_edit).superclass.should == JustRights::Permission
        @class::CopyEditPermission.superclass.should == JustRights::Permission
      end

      it 'returns different generated Permission on class' do
        @class.permissions(:on => :post).should == @class::PostPermission
        @class.permissions(:on => :copy_edit).should == @class::CopyEditPermission
      end

      it 'sets different types on Permission' do
        @class.permissions(:create, :review, :update, :delete, :on => :post)
        @class::PostPermission.types == [:create, :review, :update, :delete]

        @class.permissions(:adjust, :edit, :suggest, :correct, :on => :copy_edit)
        @class::CopyEditPermission.types == [:adjust, :edit, :suggest, :correct]
      end

      it 'ensures each set of types are symbols' do
        @class.permissions('create', 'review', 'update', 'delete', :on => 'post')
        @class::PostPermission.types == [:create, :review, :update, :delete]

        @class.permissions('adjust', 'edit', 'suggest', 'correct', :on => 'copy_edit')
        @class::CopyEditPermission.types == [:adjust, :edit, :suggest, :correct]
      end

      it 'freezes each set of types' do
        @class.permissions('create', 'review', 'update', 'delete', :on => 'post')
        @class::PostPermission.types.should be_frozen
        lambda { @class::PostPermission.types << :admin }.should raise_error(TypeError, "can't modify frozen array")

        @class.permissions('review', 'update', :on => 'copy_edit')
        @class::CopyEditPermission.types.should be_frozen
        lambda { @class::CopyEditPermission.types << :admin }.should raise_error(TypeError, "can't modify frozen array")
      end

      describe 'defined methods' do
        before do
          @class.permissions('create', 'review', 'update', 'delete', :on => 'post', :default => %w[create review])
          @class.permissions('adjust', 'edit', 'suggest', 'correct', :on => 'copy_edit')
          @mock = @class.new
        end

        it 'defines setter and getters' do
          @mock.respond_to?(:post_permission).should be_true
          @mock.respond_to?(:post_permission=).should be_true
          @mock.respond_to?(:set_post_permissions).should be_true

          @mock.respond_to?(:copy_edit_permission).should be_true
          @mock.respond_to?(:copy_edit_permission=).should be_true
          @mock.respond_to?(:set_copy_edit_permissions).should be_true
        end

        describe :permission do
          before do
            @mock['post_rights'] = 9
            @mock['copy_edit_rights'] = 6
          end

          it 'returns correct Permission classes' do
            @mock.post_permission.class.should == @class::PostPermission
            @mock.post_permission.class.superclass.should == JustRights::Permission

            @mock.copy_edit_permission.class.should == @class::CopyEditPermission
            @mock.copy_edit_permission.class.superclass.should == JustRights::Permission
          end

          it 'sets the correct bitmask on each Permission, has correct capabilities' do
            @mock.post_permission.send(:bitmask).should == 9
            @mock.post_permission.capabilities.should == [:create, :delete]

            @mock.copy_edit_permission.send(:bitmask).should == 6
            @mock.copy_edit_permission.capabilities.should == [:edit, :suggest]
          end

          it 'is not sticky' do
            @mock.post_permission.send(:sticky).should be_false
            @mock.copy_edit_permission.send(:sticky).should be_false
          end

          it 'sets sticky to false' do
            @mock.stub!(:sticky).and_return false
            @mock.sticky.should be_false
            @mock.post_permission.send(:sticky).should be_false
            @mock.copy_edit_permission.send(:sticky).should be_false
          end

          it 'sets sticky to true' do
            @mock.stub!(:sticky).and_return true
            @mock.sticky.should be_true
            @mock.post_permission.send(:sticky).should be_true
            @mock.copy_edit_permission.send(:sticky).should be_true
          end
        end

        describe :permission= do
          it 'accepts corresponding generated Permission class' do
            lambda { @mock.post_permission = @class::PostPermission.for(:create) }.should_not raise_error
            lambda { @mock.copy_edit_permission = @class::CopyEditPermission.for(:edit) }.should_not raise_error
          end

          it 'rejects class not generated Permission class' do
            lambda { @mock.post_permission = [:create] }.should \
              raise_error(ActiveRecord::AssociationTypeMismatch, /expected, got Array/)
            lambda { @mock.copy_edit_permission = [:adjust] }.should \
              raise_error(ActiveRecord::AssociationTypeMismatch, /expected, got Array/)
          end

          it 'rejects class not corresponding generated Permission class' do
            lambda { @mock.post_permission = @class::CopyEditPermission.for(:edit) }.should \
              raise_error(ActiveRecord::AssociationTypeMismatch, /expected, got #<Class/)
            lambda { @mock.copy_edit_permission =  @class::PostPermission.for(:create) }.should \
              raise_error(ActiveRecord::AssociationTypeMismatch, /expected, got #<Class/)
          end

          it 'sets bitmask on post_rights column' do
            @mock.post_permission = @class::PostPermission.for
            @mock['post_rights'].should == 0

            @mock.post_permission = @class::PostPermission.for(:create)
            @mock['post_rights'].should == 1

            @mock.post_permission = @class::PostPermission.for(:create, :delete)
            @mock['post_rights'].should == 9
          end

          it 'sets bitmask on copy_edit_rights column' do
            @mock.copy_edit_permission = @class::CopyEditPermission.for
            @mock['copy_edit_rights'].should == 0

            @mock.copy_edit_permission = @class::CopyEditPermission.for(:edit)
            @mock['copy_edit_rights'].should == 2

            @mock.copy_edit_permission = @class::CopyEditPermission.for(:edit, :suggest)
            @mock['copy_edit_rights'].should == 6
          end
        end

        describe :set_permissions do
          it 'sets permission using generated PostPermission.for()' do
            @class::PostPermission.should_receive(:for).with(:create, :delete).and_return(:post_permission)
            @mock.should_receive(:post_permission=).with(:post_permission)

            @mock.set_post_permissions :create, :delete
          end

          it 'sets permission using generated CopyEditPermission.for()' do
            @class::CopyEditPermission.should_receive(:for).with(:edit, :adjust).and_return(:copy_edit_permission)
            @mock.should_receive(:copy_edit_permission=).with(:copy_edit_permission)

            @mock.set_copy_edit_permissions :edit, :adjust
          end
        end
        describe :default_permissions! do
          it 'sets bitmask to specified default (PostPermission.default)' do
            @mock['post_rights'] = 9
            @mock.default_post_permissions!
            @mock['post_rights'].should == 3
            @mock['post_rights'].should == @class::PostPermission.default
          end

          it 'sets bitmask to undefined default (CopyEditPermission.default)' do
            @mock['copy_edit_rights'] = 3
            @mock.default_copy_edit_permissions!
            @mock['copy_edit_rights'].should == 0
            @mock['copy_edit_rights'].should == @class::CopyEditPermission.default
          end
        end

        describe :default_permissions_for do
          it 'sets default permissions for resources' do
            @mock['post_rights'] = 9
            @mock.default_permissions_for :posts
            @mock['post_rights'].should == 3
          end

          it 'sets default permissions for one resource' do
            @mock['post_rights'] = 9
            @mock.default_permissions_for :post
            @mock['post_rights'].should == 3
          end

          it 'sets default permissions for many resources' do
            @mock['post_rights'] = @mock['copy_edit_rights'] = 4
            @mock.default_permissions_for :posts, :copy_edits

            @mock['post_rights'].should == 3
            @mock['copy_edit_rights'].should == 0
          end

          it 'raises error when no matching resource' do
            lambda { @mock.default_permissions_for :foo }.should raise_error(NoMethodError, /undefined method `default_foo_permissions!'/)
          end
        end
      end
    end

  end
end

