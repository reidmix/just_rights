module JustRights
  def self.included base
    base.class_eval do
      class << self
        ##
        # Defines set of permissions.  Must stay in the same order unless you migrate your data.
        # In your parent object or database column must be called +rights+.
        #
        # Options:
        # *on*::      use when specifying multiple permissions on the same parent
        #             example:
        #               permissions :read, :write, :on => :files
        #               permissions :read, :write, :execute, :on => :folders
        # *default*:: the default permissions when using +create+
        #             example:
        #               class Foo; permissions :read, :write, :execute, :default => [:read, :write]; end
        #               Foo::Permissions.create.capabilities # => [:read, :write]
        def permissions *args
          options  = args.extract_options!

          resource = (options[:on]||'').to_s.classify
          class_name = "#{resource}Permission"
          method_name = class_name.underscore
          column_name = "#{resource}Rights".underscore

          # define class
          self.const_set class_name, permission = Class.new(Permission)
          permission.instance_variable_set '@types',   (args||[]).map(&:to_sym).freeze
          permission.instance_variable_set '@default', permission.send(:bitmask_for, *(options[:default]||[]))

          self.class_eval do
            # define setter
            define_method "#{method_name}=" do |record|
              unless permission === record
                message = "#{permission.name} expected, got #{record.class}(##{record.class.object_id})"
                raise ActiveRecord::AssociationTypeMismatch, message
              end
              self[column_name] = record.send(:bitmask)
            end

            # default setter
            define_method "default_#{method_name.pluralize}!" do
              self.send "#{method_name}=", permission.create
            end

            # define wrappers
            define_method "set_#{method_name.pluralize}" do |*args|
              self.send "#{method_name}=", permission.for(*args)
            end

            define_method "#{method_name}_attributes=" do |hash|
              hash.each do |k,v|
                self.send(method_name)[k] = v
              end
            end

            # define getter
            define_method method_name do
              permission.send :new, self[column_name], self
            end
          end

          permission
        end
      end

      def default_permissions_for *defaults
        defaults.each do |resource|
          self.send "default_#{resource.to_s.singularize}_permissions!"
        end
      end
    end
  end

  class Permission
    instance_variable_set '@types',   []
    instance_variable_set '@default', 0

    class << self
      attr_reader :types, :default

      def default_capabilities
        create.capabilities
      end

      ##
      # Returns a Permission based on the supplied capabilities.
      # Example:
      #   p = Permission.for :read, :write
      #   p.capabilites                       # => [:read, :write]
      def for *args
        new bitmask_for(*args)
      end

      ##
      # Returns a Permission using the class defaults.
      def create
        new default
      end

      protected
        ##
        # Internally, permissions are saved as a bitmask and bitmask_for
        # will return this bitmask given the capabilities.
        def bitmask_for *args
          args.map do |type|
            bit_for type
          end.compact.uniq.sum
        end

        ##
        # Bitmasks are built on powers of 2, based on the index of the
        # capability, will determine which bit to act on the bitmask.
        def bit_for type
          2 ** types.index(type.to_sym) rescue 0
        end
    end

    ##
    # Private intializer that will return a new instance based on bitmask
    # and "sticky" of the parent if supplied.
    def initialize bitmask, parent = nil
      @bitmask, @parent = bitmask, parent
      @sticky = parent.respond_to?(:sticky) ? parent.send(:sticky) : false
    end
    private_class_method :new

    ##
    # Returns boolean based on whether this permission has the rights to
    # perform the capability.
    def can? type
      sticky || has_capability?(type) && bitmask & bit_for(type) != 0
    end
    alias_method :[], :can?

    ##
    # Determines whether the supplied capabilities is a member of the
    # defined capabilities for this class.
    def has_capability? type
      types.member? type.to_sym
    end

    ##
    # Retruns the (sub)set of capabilities this Permission can perform.
    def capabilities
      types.select { |type| sticky || can?(type) }
    end

    ##
    # Sets the capability to true or false.  Example.
    #   permission[:read] = true
    def []= type, arg
      bool = case arg.to_s
        when /false|0/i then false
        when  /true|1/i then true
      end
      return unless has_capability? type and not bool.nil?
      self.bitmask ^= self[type] == bool ? 0 : bit_for(type)
    end

    ##
    # All capabilities defined for this class.
    def types
      self.class.types
    end

    ##
    # Helper method for ActiveRecord based actions that need to determine
    # the state of a record; always returns true.
    def new_record?() true end


    ##
    # Facilitates access to keys based on key name.  Will not override
    # class behaviour if key has same name as the key.
    def method_missing name
      if has_capability?(name)
        self[name]
      else
        super
      end
    end

    protected
      attr_reader :bitmask, :sticky, :parent

      ##
      # Sets the bitmask directly and if a parent is specified, resets the
      # rights attribute.
      def bitmask= mask
        @bitmask = mask
        parent.send "#{self.class.name.underscore.split('/').last}=", self if parent
        mask
      end

      ##
      # Helper method, calls class method bit_for
      def bit_for type
        self.class.send :bit_for, type
      end
  end
end