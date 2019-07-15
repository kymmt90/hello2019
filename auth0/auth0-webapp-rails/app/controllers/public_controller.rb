class PublicController < ActionController::API
  def public
    render json: { message: 'Hello' }
  end
end
