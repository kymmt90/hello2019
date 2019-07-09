require 'csv'
require 'json'
require 'redis'

class IpToLocation
  def ip_to_score(ip_address)
    score = 0

    ip_address
      .split('.')
      .map(&:to_i)
      .reduce(0) { |result, v| result + result * 256 + v }
  end

  def import_ips_to_redis(filename)
    CSV.foreach(filename, headers: true).with_index do |row, i|
      start_ip = row['network'].split('/').first

      if start_ip.downcase.include?('i')
        next
      end

      if start_ip.include?('.')
        start_ip = ip_to_score(start_ip)
      end

      start_ip = Integer(start_ip)
      city_id = "#{row['geoname_id']}_#{i}"

      connection.zadd('ip2cityid:', start_ip, city_id)

    rescue TypeError
    end
  end

  def import_cities_to_redis(filename)
    CSV.foreach(filename, headers: true) do |row|
      connection.hset(
        'cityid2city:',
        row['geoname_id'],
        [row['subdivision_1_iso_code'], row['continent_code'], row['country_iso_code']].to_json
      )
    rescue TypeError
    end
  end

  def find_city_by_ip(ip_address)
    city_id = connection.zrevrangebyscore('ip2cityid:', ip_address, 0, limit: [0, 1])

    return unless city_id

    city_id = city_id.split('_').first

    JSON.parse(connection.hget('cityid2city:', city_id))
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end

# IpToLocation.new.import_ips_to_redis(ARGV[0])
# IpToLocation.new.import_cities_to_redis(ARGV[0])
