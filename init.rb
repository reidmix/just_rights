ActiveRecord::Base.send :include, JustRights
ActionController::Base.rescue_responses['PermissionSystem::ForbiddenAccess'] = :forbidden
