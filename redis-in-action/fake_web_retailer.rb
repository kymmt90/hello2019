require 'redis'
require 'securerandom'

class FakeWebRetailer
  def initialize(token:, user:)
    connection.hset('login:', token, user)
  end

  def check_token(token)
    connection.hget('login:', token)
  end

  def update_token(token, user, item = nil)
    timestamp = Time.now.to_f

    connection.hset('login:', token, user)
    connection.zadd('recent:', timestamp, token)

    if item
      key = "viewed:#{token}"
      connection.zadd(key, timestamp, item)
      connection.zremrangebyrank(key, 0, -26)
    end
  end

  def clean_full_sessions(force: false)
    size = connection.zcard('recent:')

    tokens = if force
              connection.zrange('recent:', 0, -1)
            else
              limit = 10000000
              end_index = [size - limit, 100].min
              connection.zrange('recent:', 0, end_index - 1)
            end

    return if tokens.empty?

    session_keys = tokens.map { |token| ["viewed:#{token}", "cart:#{token}"] }.flatten

    connection.del(*session_keys)
    connection.hdel('login:', *tokens)
    connection.zrem('recent:', tokens)
  end

  def add_to_cart(session, item, count)
    if count <= 0
      connection.hdel("cart:#{session}", item)
    else
      connection.hset("cart:#{session}", item, count)
    end
  end

  def cache_request(request, &callback)
    page_key = "cache:#{request.hash}"

    content = connection.get(page_key)

    return content if content

    content = callback.call(request)

    connection.setex(page_key, 300, content)

    content
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end

pp token = SecureRandom.urlsafe_base64
retailer = FakeWebRetailer.new(token: token, user: 'kymmt90')
pp user = retailer.check_token(token)
pp retailer.update_token(token, user)
pp retailer.add_to_cart(token, 'apple', 5)
pp retailer.clean_full_sessions(force: false)
