module Secured
  extend ActiveSupport::Concern

  included do
    before_action :redirect_not_logged_in_user_to_root
  end

  def redirect_not_logged_in_user_to_root
    redirect_to '/' if session[:userinfo].blank?
  end
end
