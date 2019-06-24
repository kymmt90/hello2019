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

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end
