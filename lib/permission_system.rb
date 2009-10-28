require 'just_rights'

module PermissionSystem
  class ForbiddenAccess < StandardError
  end

  protected
    ##
    # Inclusion of rights_for and rights.
    def self.included base
      base.send :helper_method, :rights_for, :rights, :authorized_by
      base.send :helper, :rights
      base.extend ClassMethods
    end

    module ClassMethods
      protected
        def verify_access options
          options = options.with_indifferent_access
          rights  = options.delete(:can?)
          message = options.delete(:deny)

          before_filter options do |controller|
            raise ForbiddenAccess, message unless controller.send :authorized_by, rights
          end
        end
    end

    ##
    # Any authorized rights will return true.  If no resource is provided it will use
    # :default namespace
    # Example:
    #   authorized_by :allow                # same as authorized_by :default => :right
    #   authorized_by :resource => :allow   # true if rights_For(:resource).can?(:allow)
    def authorized_by rights
      return false unless rights

      unless rights.respond_to?(:keys)
        rights = {:default => rights}
      end

      rights.any? do |right, permission|
        rights_for(right).can?(permission)
      end
    end

    ##
    # The hash of all currently granted rights
    def current_rights
      return @current_rights if defined?(@current_rights)
      @current_rights = HashWithIndifferentAccess.new
    end

    ##
    # Merges a set of named rights to the current_rights
    # Use grant_rights when you have multiple types of permissions.
    def grant_rights_for rights_hash
      current_rights.merge! rights_hash
    end

    ##
    # Retrieves a named right or a Permission with no capabilities
    # Use rights_for when you have multiple types of permissions.
    def rights_for right_name
      current_rights[right_name] || JustRights::Permission.create
    end

    ##
    # Retrieves rights.  Use rights when you have only one Permission
    def rights
      rights_for :default
    end

    ##
    # Sets rights.  Use rights when you have only one Permission
    def rights= default_rights
      grant_rights_for(:default => default_rights) && default_rights
    end
end