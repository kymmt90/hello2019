module SecuredApi
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
  end

  SCOPE = {
    '/private' => nil,
    '/private-scoped' => ['read:messages']
  }

  private

  def authenticate
    JsonWebToken.verify(authorization_header_token)

  rescue JWT::VerificationError, JWT::DecodeError
    render json: { errors: ['Not Authenticated'] }, status: :unauthorized
  end

  def authorization_header_token
    if request.headers['Authorization'].present?
      request.headers['Authorization'].split(' ').last
    end
  end

  def scope_included
    if SCOPES[request.env['PATH_INFO']] == nil
      true
    else
      (String(@auth_payload['scope']).split(' ') & (SCOPES[request.env['PATH_INFO']])).any?
    end
  end
end
