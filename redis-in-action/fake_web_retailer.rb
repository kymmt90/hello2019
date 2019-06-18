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
      connection.zincrby('viewed:', -1, item)
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

  def schedule_row_cache(row_id, delay)
    connection.zadd('delay:', delay, row_id)
    connection.zadd('schedule:', Time.now.to_f, row_id)
  end

  def cache_rows
    next_to_cache = connection.zrange('schedule:', 0, 0, with_scores: true)

    now = Time.now.to_f

    if !next_to_cache || next_to_cache[0][1] > now
      sleep 0.05
    end

    row_id = next_to_cache[0][0]

    delay = connection.zscore('delay:', row_id)
    if delay <= 0
      connection.zrem('delay:', row_id)
      connection.zrem('schedule:', row_id)
      connection.del("inv:#{row_id}")
    end

    row = { product: 'product 1' }
    connection.zadd('schedule:', now + delay, row_id)
    connection.set("inv:#{row_id}", row.to_json)
  end

  def rescale_viewed
    connection.zremrangebyrank('viewed:', 20000, -1)
    connection.zinterstore('viewed:', ['viewed:'], weights: [0.5])
  end

  def can_cache(request)
    item_id = request.item_id

    rank = connection.zrank('viewed:', item_id)

    !rank.nil? && rank < 10000
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
