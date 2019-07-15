class PrivateController < ActionController::API
  include SecuredApi

  def private
    render json: { message: 'Hello from private' }
  end

  def private_scoped
    render json: { message: 'Hello from private scoped' }
  end
end
