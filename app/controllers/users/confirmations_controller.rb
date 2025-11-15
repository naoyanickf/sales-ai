module Users
  class ConfirmationsController < Devise::ConfirmationsController
    protected

    def after_confirmation_path_for(resource_name, resource)
      if resource.present? && resource.active_for_authentication?
        sign_in(resource_name, resource)
        stored_location_for(resource) || authenticated_root_path
      else
        super
      end
    end
  end
end
