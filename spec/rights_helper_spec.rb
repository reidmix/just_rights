require File.dirname(__FILE__) + '/spec_helper'

class MockView
  attr_reader :link_name, :link_options, :link_html_options
  attr_reader :submit_value, :submit_options, :capture_arg

  def link_to name, options, html_options
    @link_name, @link_options, @link_html_options = name, options, html_options
  end

  def submit_tag value, options
    @submit_value, @submit_options = value, options
  end

  def capture arg
    @capture_arg = arg
    'Name in Block'
  end

  def concat data
    data
  end

  def escape_javascript(js)
    js # just gonna return it, not testing rails
  end
end

describe RightsHelper do
  it 'is a module' do
    RightsHelper.should be_kind_of(Module)
  end

  describe :included do
    it 'adds helper methods' do
      mock = Class.new(MockView)
      mock.send :include, RightsHelper

      mock.instance_methods.should be_member('access_denied')
      mock.instance_methods.should be_member('link_by_rights')
      mock.instance_methods.should be_member('submit_by_rights')
    end
  end

  describe :methods do
    before do
      @view = Class.new(MockView) do
        include RightsHelper
      end.new
    end

    describe :access_denied do
      it "creates alert('Access Denied') with no message" do
        @view.access_denied.should == %Q[alert('Access Denied');return false;]
      end

      it 'escapes message for javascript' do
        @view.should_receive(:escape_javascript)
        @view.access_denied("Nope! It's not gonna let you do it!")
      end

      it 'places the message in the alert' do
        @view.access_denied("Nope!").should == %Q[alert('Nope!');return false;]
      end
    end

    describe :submit_by_rights do
      before do
        @view.stub!(:authorized_by).and_return true
      end

      it 'calls submit_tag' do
        @view.should_receive(:submit_tag)
        @view.submit_by_rights
      end

      it 'has "Save changes" as default value' do
        @view.submit_by_rights
        @view.submit_value.should == 'Save changes'
      end

      it 'overrides default value' do
        @view.submit_by_rights('Submit')
        @view.submit_value.should == 'Submit'
      end

      it 'removes :can? and :deny (symbol keys)' do
        @view.submit_by_rights('Submit', :can? => :allow, :deny => 'You suck!')
        @view.submit_options.should == {}
      end

      it 'removes :can? and :deny (string keys)' do
        @view.submit_by_rights('Submit', 'can?' => :allow, 'deny' => 'You suck!')
        @view.submit_options.should == {}
      end

      it 'passes along all other options' do
        @view.submit_by_rights('Submit', 'can?' => :allow, 'deny' => 'You suck!', :confirm => 'foo', :method => 'delete')
        @view.submit_options.should == {'confirm' => 'foo', 'method' => 'delete'}
      end

      it 'passes permissions to authorized_by' do
        @view.should_receive(:authorized_by).with(:allow).and_return true
        @view.submit_by_rights('Submit', 'can?' => :allow, 'deny' => 'You suck!')
      end

      describe 'when not authorized' do
        before do
          @view.stub!(:authorized_by).and_return false
        end

        it 'calls submit_tag' do
          @view.should_receive(:submit_tag)
          @view.submit_by_rights
        end

        it 'removes :can? and :deny (symbol keys)' do
          @view.submit_by_rights('Submit', :can? => :allow, :deny => 'You suck!')
          @view.submit_options[:can?].should be_nil
          @view.submit_options[:deny].should be_nil
        end

        it 'removes :can? and :deny (string keys)' do
          @view.submit_by_rights('Submit', 'can?' => :allow, 'deny' => 'You suck!')
          @view.submit_options[:can?].should be_nil
          @view.submit_options[:deny].should be_nil
        end

        it 'passes along all other options' do
          @view.submit_by_rights('Submit', 'can?' => :allow, :id => 'foo', :method => 'delete')
          @view.submit_options[:id].should == 'foo'
          @view.submit_options[:method].should == 'delete'
        end

        it 'removes confirm' do
          @view.submit_by_rights('Submit', :confirm => 'Are you sure?')
          @view.submit_options[:confirm].should be_nil
        end

        it 'adds default access denied message' do
          @view.submit_by_rights('Submit')
          @view.submit_options[:onclick].should == %Q[alert('Access Denied');return false;]
        end

        it 'adds custom access denied message' do
          @view.submit_by_rights('Submit', :deny => 'Nope!')
          @view.submit_options[:onclick].should == %Q[alert('Nope!');return false;]
        end

        it 'appends access denied message to any specified onclick' do
          @view.submit_by_rights('Submit', :onclick => %Q[alert('foo')])
          @view.submit_options[:onclick].should == %Q[alert('foo');alert('Access Denied');return false;]
        end

        it 'passes permissions to authorized_by' do
          @view.should_receive(:authorized_by).with(:allow).and_return false
          @view.submit_by_rights('Submit', 'can?' => :allow, 'deny' => 'You suck!')
        end
      end
    end

    describe :link_by_rights do
      before do
        @view.stub!(:authorized_by).and_return true
      end

      it 'calls link_to' do
        @view.should_receive(:link_to).with('Name', {}, {})
        @view.link_by_rights 'Name'
      end

      it 'removes :can? and :deny (symbol keys)' do
        @view.link_by_rights('Click Me', :link, :can? => :allow, :deny => 'You suck!')
        @view.link_html_options.should == {}
      end

      it 'removes :can? and :deny (string keys)' do
        @view.link_by_rights('Click Me', :link, 'can?' => :allow, 'deny' => 'You suck!')
        @view.link_html_options.should == {}
      end

      it 'passes along name and options' do
        @view.link_by_rights('Click Me', :link)
        @view.link_name.should == 'Click Me'
        @view.link_options.should == :link
      end

      it 'passes along all other options and html_options' do
        @view.link_by_rights('Click Me', :link, 'can?' => :allow, 'deny' => 'You suck!', :method => :delete, :confirm => 'Are you sure?')
        @view.link_html_options.should == {'method' => :delete, 'confirm' => 'Are you sure?'}
      end

      it 'passes permissions to authorized_by' do
        @view.should_receive(:authorized_by).with(:allow).and_return true
        @view.link_by_rights('Click Me', :link, 'can?' => :allow, 'deny' => 'You suck!')
      end

      describe 'when block given' do
        it 'calls link_to' do
          @view.should_receive(:link_to).with('Name in Block', :link, {'id' => 'foo'})
          @view.link_by_rights(:link, :id => 'foo') do |allow|
            'Name in Block'
          end
        end

        it 'yeilds result of authorized_by' do
          @view.link_by_rights(:link, :id => 'foo') do |allow|
            'Name in Block'
          end
          @view.capture_arg.should be_true
        end

        it 'concats results' do
          @view.should_receive(:link_to).and_return :link
          @view.should_receive(:concat).with(:link)
          @view.link_by_rights(:link, :id => 'foo') do |allow|
            'Name in Block'
          end
        end
      end

      describe 'when not authorized' do
        before do
          @view.stub!(:authorized_by).and_return false
        end

        it 'calls link_to' do
          @view.should_receive(:link_to).with('Name', {}, hash_including({}))
          @view.link_by_rights 'Name'
        end

        it 'removes :can? and :deny (symbol keys)' do
          @view.link_by_rights('Click Me', :link, :can? => :allow, :deny => 'You suck!')
          @view.link_html_options[:can?].should be_nil
          @view.link_html_options[:deny].should be_nil
        end

        it 'removes :can? and :deny (string keys)' do
          @view.link_by_rights('Click Me', :link, 'can?' => :allow, 'deny' => 'You suck!')
          @view.link_html_options[:can?].should be_nil
          @view.link_html_options[:deny].should be_nil
        end

        it 'passes along name and options' do
          @view.link_by_rights('Click Me', :link)
          @view.link_name.should == 'Click Me'
          @view.link_options.should == :link
        end

        it 'passes along all other html_options' do
          @view.link_by_rights('Click Me', :link, 'can?' => :allow, :id => 'foo', :class => 'delete')
          @view.link_html_options[:id].should == 'foo'
          @view.link_html_options[:class].should == 'delete'
        end

        it 'removes confirm' do
          @view.link_by_rights('Click Me', :link, :confirm => 'Are you sure?')
          @view.link_html_options[:confirm].should be_nil
        end

        it 'removes method' do
          @view.link_by_rights('Click Me', :link, :method => 'delete')
          @view.link_html_options[:method].should be_nil
        end

        it 'sets the href to javascript:void(0)' do
          @view.link_by_rights('Click Me', :link)
          @view.link_html_options[:href].should == 'javascript:void(0)'
        end

        it 'overwrites the href to javascript:void(0)' do
          @view.link_by_rights('Click Me', :link, :href => '/path')
          @view.link_html_options[:href].should == 'javascript:void(0)'
        end

        it 'adds default access denied message' do
          @view.link_by_rights('Click Me', :link)
          @view.link_html_options[:onclick].should == %Q[alert('Access Denied');return false;]
        end

        it 'adds custom access denied message' do
          @view.link_by_rights('Click Me', :link, :deny => 'Nope!')
          @view.link_html_options[:onclick].should == %Q[alert('Nope!');return false;]
        end

        it 'appends access denied message to any specified onclick' do
          @view.link_by_rights('Click Me', :link, :onclick => %Q[alert('foo')])
          @view.link_html_options[:onclick].should == %Q[alert('foo');alert('Access Denied');return false;]
        end

        it 'passes permissions to authorized_by' do
          @view.should_receive(:authorized_by).with(:allow).and_return false
          @view.link_by_rights('Click Me', :link, 'can?' => :allow, 'deny' => 'You suck!')
        end

        describe 'when block given' do
          it 'calls link_to' do
            @view.should_receive(:link_to).with('Name in Block', :link, hash_including({'id' => 'foo'}))
            @view.link_by_rights(:link, :id => 'foo') do |allow|
              'Name in Block'
            end
          end

          it 'yeilds result of authorized_by' do
            @view.link_by_rights(:link, :id => 'foo') do |allow|
              'Name in Block'
            end
            @view.capture_arg.should be_false
          end

          it 'concats results' do
            @view.should_receive(:link_to).and_return :link
            @view.should_receive(:concat).with(:link)
            @view.link_by_rights(:link, :id => 'foo') do |allow|
              'Name in Block'
            end
          end
        end
      end
    end
  end
end