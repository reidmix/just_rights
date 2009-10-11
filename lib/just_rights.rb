module JustRights
  def self.included base
    base.class_eval do
      class << self
        def permissions *args
          options  = args.extract_options!

          resource = (options[:on]||'').to_s.classify
          class_name = "#{resource}Permission"
          method_name = class_name.underscore
          column_name = "#{resource}Rights".underscore

          # define class
          self.const_set class_name, permission = Class.new(Permission)
          permission.instance_variable_set '@types', (args||[]).map(&:to_sym).freeze

          self.class_eval do
            # define setter
            define_method "#{method_name}=" do |record|
              unless permission === record
                message = "#{permission.name} expected, got #{record.class}(##{record.class.object_id})"
                raise ActiveRecord::AssociationTypeMismatch, message
              end
              self[column_name] = record.send(:bitmask)
            end

            # define wrapper
            define_method "set_#{method_name.pluralize}" do |*args|
              self.send "#{method_name}=", permission.for(*args)
            end

            # define getter
            define_method method_name do
              if respond_to? :sticky
                permission.send :new, self[column_name], sticky
              else
                permission.send :new, self[column_name]
              end
            end
          end

          permission
        end
      end
    end
  end

  class Permission
    instance_variable_set '@types', []

    class << self
      attr_reader :types

      def for *args
        new bitmask_for(*args)
      end

      protected
        def bitmask_for *args
          args.map do |type|
            bit_for type
          end.compact.uniq.sum
        end

        def bit_for type
          2 ** types.index(type.to_sym) rescue 0
        end
    end

    def initialize bitmask, sticky = false
      @bitmask, @sticky = bitmask, sticky
    end
    private_class_method :new

    def can? type
      sticky || has_capability?(type) && bitmask & bit_for(type) != 0
    end

    def has_capability? type
      types.member? type.to_sym
    end

    def capabilities
      types.select { |type| sticky || can?(type) }
    end

    protected
      attr_reader :bitmask, :sticky

      def types
        self.class.types
      end

      def bit_for type
        self.class.send :bit_for, type
      end
  end
end