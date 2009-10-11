require File.dirname(__FILE__) + '/spec_helper'

Permission = Class.new(JustRights::Permission) do
  @types = [:create, :review, :update, :delete]

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

  it 'returns types' do
    Permission.types.should == [:create, :review, :update, :delete]
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

  describe :initialize do
    it 'privatizes new' do
      Permission.private_methods.member? 'new'
    end

    it 'sets bitmask' do
      Permission.send(:new, 1).send(:bitmask).should == 1
    end

    it 'sets sticky to false by default' do
      Permission.send(:new, 1).send(:sticky).should be_false
    end

    it 'can set sticky to true' do
      Permission.send(:new, 1, true).send(:sticky).should be_true
    end
  end

  describe 'instance' do
    before do
      @permission = Permission.for(:create, :review)
    end

    describe :types do
      it 'calls the types class method' do
        Permission.should_receive(:types).and_return [:type]
        @permission.send(:types).should == [:type]
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
          @permission.has_capability? type
        end
      end

      it 'returns false if not a specified type' do
        @permission.has_capability?(:foo).should be_false
      end
    end

    describe :can? do
      it 'returns true when has permissions' do
        @permission.can?(:create).should be_true
        @permission.can?(:review).should be_true
      end

      it 'returns false when does not have permissions' do
        @permission.can?(:update).should be_false
        @permission.can?(:delete).should be_false
      end

      it 'returns false when not a type' do
        @permission.can?(:foo).should be_false
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
  end
end