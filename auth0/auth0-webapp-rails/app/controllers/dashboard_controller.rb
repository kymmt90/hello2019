class DashboardController < ApplicationController
  include Secured

  def show
    @user = session['userinfo'].deep_symbolize_keys
  end
end
