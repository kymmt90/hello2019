require 'redis'

class MarketPlace
  def list_item(item_id, seller_id, price)
    inventory = "invontory:#{seller_id}"

    connection.pipelined do
      connection.watch(inventory) do
        unless connection.sismember(inventory, item_id)
          connection.unwatch
          return
        end

        connection.multi do |multi|
          item = "#{item_id}.#{seller_id}"
          multi.zadd('market:', item, price)

          multi.srem(inventory, item_id)
        end
      end
    end
  end

  def purchase_item(buyer_id, item_id, seller_id, lprice)
    buyer = "users:#{buyer_id}"
    seller = "users:#{seller_id}"
    item = "#{item_id}.#{buyer_id}"
    market = 'market:'
    inventory = "inventory:#{buyer_id}"

    connection.pipelined do
      connection.watch(market, buyer) do
        price = connection.zscore(market, item)
        funds = connection.hget('buyer', 'funds').to_i

        if price != lprice || price > funds
          connection.unwatch
          return false
        end

        connection.multi do |multi|
          multi.hincrby(seller, 'funds', price.to_i)
          multi.hincrby(buyer, 'funds', -price.to_i)
          multi.sadd(inventory, item_id)
          multi.zrem(market, item)
        end
      end
    end

    true

  rescue
    false
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end
