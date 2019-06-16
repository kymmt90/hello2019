require 'redis'

module FakeWebRetailer
  def check_token(token)
    connection.hget('login:', token)
  end

  def update_token(token, user, item = nil)
    timestamp = Time.now.to_f

    connection.hset('login:', token, user)
    connection.zadd('recent:', token, timestamp)

    if item
      key = "viewed:#{token}"
      connection.zadd(key, item, timestamp)
      connection.zremrangebyrank(key, 0, -26)
    end
  end

  def clean_sessions
    size = connection.zcard('recent:')
    if size <= LIMIT
      sleep 1
      continue
    end

    limit = 10000000
    end_index = [size - limit, 100].min
    tokens = connection.zrange('recent:', 0, end_index - 1)
    session_keys = []

    tokens.each do |token|
      session_keys << "viewed:#{token}"
    end
    connection.del(*session_keys)

    connection.hdel('login:', *tokens)
    connection.zrem('recent:', *tokens)
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end
