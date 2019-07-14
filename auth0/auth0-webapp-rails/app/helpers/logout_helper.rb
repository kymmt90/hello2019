module LogoutHelper
  def logout_url
    request_params = {
      returnTo: root_url,
      client_id: Rails.application.credentials.auth0[:client_id]
    }

    URI::HTTPS.build(
      host: Rails.application.credentials.auth0[:domain],
      path: '/v2/logout',
      query: request_params.to_query
    )
  end
end
