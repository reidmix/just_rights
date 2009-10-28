require File.dirname(__FILE__) + '/spec_helper'

Permission = Class.new(JustRights::Permission) do
  @types   = [:create, :review, :update, :delete]
  @default = 5

  class << self
    # make it easier to test
    public :bitmask_for, :bit_for
  end
end


describe JustRights::Permission do
  describe :types, 'not set' do
    it 'returns empty array' do
      JustRights::Permission.types.should == []
    end
  end

  describe :default, 'not set' do
    it 'returns 0' do
      JustRights::Permission.default.should == 0
    end
  end

  it 'returns types' do
    Permission.types.should == [:create, :review, :update, :delete]
  end

  it 'returns default' do
    Permission.default.should == 5
  end

  describe :default_capabilities do
    it 'should return empty when not set' do
      JustRights::Permission.default_capabilities.should be_empty
    end

    it 'should return capabilities for default bitmask' do
      Permission.default_capabilities.should == [:create, :update]
    end
  end

  describe :bit_for do
    it 'is 0 with no match' do
      Permission.bit_for(:foo).should  == 0
      Permission.bit_for('foo').should == 0
    end

    it 'returns exponents for each type' do
      Permission.types.map { |t| Permission.bit_for t      }.should == [1, 2, 4, 8]
      Permission.types.map { |t| Permission.bit_for t.to_s }.should == [1, 2, 4, 8]
    end
  end

  describe :bitmask_for do
    it 'is 0 with no match' do
      Permission.bitmask_for.should        == 0
      Permission.bitmask_for(:foo).should  == 0
      Permission.bitmask_for('foo').should == 0
    end

    it 'determines every combination' do
      Permission.bitmask_for(:create).should                            == 1
      Permission.bitmask_for(:review).should                            == 2
      Permission.bitmask_for(:create, :review).should                   == 3
      Permission.bitmask_for(:update).should                            == 4
      Permission.bitmask_for(:create, :update).should                   == 5
      Permission.bitmask_for(:review, :update).should                   == 6
      Permission.bitmask_for(:create, :review, :update).should          == 7
      Permission.bitmask_for(:delete).should                            == 8
      Permission.bitmask_for(:create, :delete).should                   == 9
      Permission.bitmask_for(:review, :delete).should                   == 10
      Permission.bitmask_for(:create, :review, :delete).should          == 11
      Permission.bitmask_for(:update, :delete).should                   == 12
      Permission.bitmask_for(:create, :update, :delete).should          == 13
      Permission.bitmask_for(:review, :update, :delete).should          == 14
      Permission.bitmask_for(:create, :review, :update, :delete).should == 15
    end

    it 'does not add pairs of the same type' do
      Permission.bitmask_for(:create, :create).should == 1
      Permission.bitmask_for(:review, :review).should == 2
      Permission.bitmask_for(:update, :update).should == 4
      Permission.bitmask_for(:delete, :delete).should == 8
    end

    it 'ignore non-matches' do
      Permission.bitmask_for(:create, :foo).should == 1
      Permission.bitmask_for(:review, :foo).should == 2
      Permission.bitmask_for(:update, :foo).should == 4
      Permission.bitmask_for(:delete, :foo).should == 8
    end
  end

  describe :for do
    it 'returns instance' do
      Permission.for.should be_kind_of(Permission)
    end

    it 'creates permission with correct bitmask' do
      Permission.should_receive(:bitmask_for).and_return(11)
      Permission.for.send(:bitmask).should == 11
    end

    it 'creates permission based on all parmeters' do
      Permission.for(:create, :review, :update, :delete, :foo).send(:bitmask).should == 15
    end

    it 'is not sticky' do
      Permission.for.send(:sticky).should be_false
    end
  end

  describe :create do
    it 'returns instance' do
      Permission.create.should be_kind_of(Permission)
    end

    it 'creates permission with correct bitmask' do
      Permission.create.send(:bitmask).should == 5
    end

    it 'creates permission that has default_capabilities' do
      Permission.create.capabilities.should == Permission.default_capabilities
      Permission.create.capabilities.should == [:create, :update]
    end

    it 'is not sticky' do
      Permission.create.send(:sticky).should be_false
    end
  end

  describe :initialize do
    it 'privatizes new' do
      Permission.private_methods.member? 'new'
    end

    it 'sets bitmask' do
      Permission.send(:new, 1).send(:bitmask).should == 1
    end

    it 'sets parent' do
      Permission.send(:new, 1, @mock = mock('parent')).send(:parent).should == @mock
    end

    it 'sets sticky to false by default' do
      Permission.send(:new, 1).send(:sticky).should be_false
    end

    it 'can set sticky to true' do
      Permission.send(:new, 1, mock('parent', :sticky => true)).send(:sticky).should be_true
    end

    it 'can set sticky to false' do
      Permission.send(:new, 1, mock('parent', :sticky => false)).send(:sticky).should be_false
    end
  end

  describe 'instance' do
    before do
      @permission = Permission.for(:create, :review)
    end

    describe :types do
      it 'calls the types class method' do
        Permission.should_receive(:types).and_return [:type]
        @permission.types.should == [:type]
      end
    end

    describe :new_record? do
      it 'is always true' do
        @permission.new_record?.should be_true
      end
    end

    describe :method_missing do
      it 'returns capability value' do
        @permission.should_receive(:[]).with(:create).and_return true
        @permission.create.should be_true

        @permission.should_receive(:[]).with(:review).and_return false
        @permission.review.should be_false
      end

      it 'raises error if no capability' do
        lambda { @permission.foo }.should raise_error(NoMethodError, /undefined method `foo' for /)
      end

    end

    describe :bit_for do
      it 'calls the types class method' do
        Permission.should_receive(:bit_for).with(:type).and_return 1
        @permission.send(:bit_for, :type).should == 1
      end
    end

    it 'returns bitmask' do
      @permission.send(:bitmask).should == 3
    end

    it 'returns stikey' do
      @permission.send(:sticky).should be_false
    end

    describe :has_capability? do
      it 'has specified types' do
        Permission.types.each do |type|
          @permission.has_capability?(type).should be_true
        end
      end

      it 'returns false if not a specified type' do
        @permission.has_capability?(:foo).should be_false
      end

      it 'returns false if nil' do
        @permission.has_capability?(nil).should be_false
      end
    end

    describe :can?, :[] do
      it 'returns true when has permissions' do
        @permission.can?(:create).should be_true
        @permission.can?(:review).should be_true

        @permission[:create].should be_true
        @permission[:review].should be_true
      end

      it 'returns false when does not have permissions' do
        @permission.can?(:update).should be_false
        @permission.can?(:delete).should be_false

        @permission[:update].should be_false
        @permission[:delete].should be_false
      end

      it 'returns false when not a type' do
        @permission.can?(:foo).should be_false
        @permission[:foo].should be_false
      end

      describe 'when sticky' do
        before do
          @permission.stub!(:sticky).and_return true
        end

        it 'returns true when has permissions' do
          @permission.can?(:create).should be_true
          @permission.can?(:review).should be_true
        end

        it 'returns true when does not have permissions' do
          @permission.can?(:update).should be_true
          @permission.can?(:delete).should be_true
        end

        it 'returns true even when not a type' do
          @permission.can?(:foo).should be_true
        end
      end
    end

    describe :capabilities do
      it 'returns the types which have permissions' do
        @permission.capabilities.should == [:create, :review]
      end

      it 'returns no types if none are specified' do
        Permission.for.capabilities.should == []
      end

      it 'returns only types that are valid and specified' do
        Permission.for(:create, :foo).capabilities.should == [:create]
      end

      it 'returns all types if all are specified' do
        Permission.for(*Permission.types).capabilities.should == [:create, :review, :update, :delete]
      end

      describe 'when sticky' do
        it 'returns all types when only some are specified'  do
          @permission.stub!(:sticky).and_return true
          @permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'returns all types when none are specified' do
          permission = Permission.for
          permission.stub!(:sticky).and_return true
          permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it "returns all types except invalid one's specified" do
          permission = Permission.for(:create, :foo)
          permission.stub!(:sticky).and_return true
          permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'returns all types when all are specified' do
          permission = Permission.for(*Permission.types)
          permission.stub!(:sticky).and_return true
          permission.capabilities.should == [:create, :review, :update, :delete]
        end
      end
    end

    describe :[]= do
      describe 'with all capabilities' do
        before do
          @permission = Permission.for(*Permission.types)
        end

        it 'resets parent permission with self' do
          @permission.instance_variable_set('@parent', parent = mock('Parent'))
          parent.should_receive(:permission=).with(@permission)
          @permission[:create] = false
        end

        it 'turns off capability' do
          @permission[:create] = false
          @permission[:create].should be_false
          @permission.capabilities.should == [:review, :update, :delete]

          @permission[:review] = 'false'
          @permission[:review].should be_false
          @permission.capabilities.should == [:update, :delete]

          @permission[:update] = 0
          @permission[:update].should be_false
          @permission.capabilities.should == [:delete]

          @permission[:delete] = '0'
          @permission[:delete].should be_false
          @permission.capabilities.should == []
        end

        it 'turns off capability as string' do
          @permission['create'] = false
          @permission['create'].should be_false
          @permission.capabilities.should == [:review, :update, :delete]

          @permission['review'] = 'false'
          @permission['review'].should be_false
          @permission.capabilities.should == [:update, :delete]

          @permission['update'] = 0
          @permission['update'].should be_false
          @permission.capabilities.should == [:delete]

          @permission['delete'] = '0'
          @permission['delete'].should be_false
          @permission.capabilities.should == []
        end

        it 'leaves on capability' do
          @permission[:create] = true
          @permission['create'] = true
          @permission[:create].should be_true

          @permission[:review] = 'true'
          @permission['review'] = 'true'
          @permission[:review].should be_true

          @permission[:update] = 1
          @permission['update'] = 1
          @permission[:update].should be_true

          @permission[:delete] = '1'
          @permission['delete'] = '1'
          @permission[:delete].should be_true
          @permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'ignores non-types' do
          @permission[:foo] = true
          @permission[:foo] = 'true'
          @permission[:foo] = 1
          @permission[:foo] = '1'
          @permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'ignores non-boolean like values' do
          @permission[:create] = 'nope'
          @permission[:create].should be_true

          @permission[:review] = '2'
          @permission[:review].should be_true

          @permission[:update] = 2
          @permission[:update].should be_true

          @permission[:delete] = nil
          @permission[:update].should be_true
        end
      end

      describe 'without capabilities' do
        before do
          @permission = Permission.for
        end

        it 'turns on capability' do
          @permission[:create] = true
          @permission[:create].should be_true
          @permission.capabilities.should == [:create]

          @permission[:review] = 'true'
          @permission[:review].should be_true
          @permission.capabilities.should == [:create, :review]

          @permission[:update] = 1
          @permission[:update].should be_true
          @permission.capabilities.should == [:create, :review, :update]

          @permission[:delete] = '1'
          @permission[:delete].should be_true
          @permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'turns on capability (as string)' do
          @permission['create'] = true
          @permission['create'].should be_true
          @permission.capabilities.should == [:create]

          @permission['review'] = 'true'
          @permission['review'].should be_true
          @permission.capabilities.should == [:create, :review]

          @permission['update'] = 1
          @permission['update'].should be_true
          @permission.capabilities.should == [:create, :review, :update]

          @permission['delete'] = '1'
          @permission['delete'].should be_true
          @permission.capabilities.should == [:create, :review, :update, :delete]
        end

        it 'leaves off capability' do
          @permission[:create] = false
          @permission['create'] = false
          @permission[:create].should be_false

          @permission[:review] = 'false'
          @permission['review'] = 'false'
          @permission[:review].should be_false

          @permission[:update] = 0
          @permission['update'] = 0
          @permission[:update].should be_false

          @permission[:delete] = '0'
          @permission['delete'] = '0'
          @permission[:delete].should be_false

          @permission.capabilities.should == []
        end

        it 'ignores non-types' do
          @permission[:foo] = false
          @permission[:foo] = 'false'
          @permission[:foo] = 0
          @permission[:foo] = '0'
          @permission.capabilities.should == []
        end

        it 'ignores non-boolean like values' do
          @permission[:create] = 'nope'
          @permission[:create].should be_false

          @permission[:review] = '2'
          @permission[:review].should be_false

          @permission[:update] = 2
          @permission[:update].should be_false

          @permission[:delete] = nil
          @permission[:update].should be_false
        end
      end
    end
  end
end