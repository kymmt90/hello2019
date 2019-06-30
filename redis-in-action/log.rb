require 'logger'
require 'redis'

class Log
  SEVERITY = {
    Logger::DEBUG => 'debug',
    Logger::INFO => 'info',
    Logger::WARN => 'warning',
    Logger::ERROR => 'error',
    Logger::FATAL => 'fatal'
  }

  def log_recent(name, message, severity: Logger::INFO, conn: connection)
    severity = SEVERITY[severity]
    destination = "recent:#{name}:#{severity}"

    connection.pipelined do
      conn.lpush(destination, "#{Time.new.asctime} #{message}")
      conn.ltrim(destination, 0, 99)
    end
  end

  def log_common(name, message, severity: Logger::INFO, timeout: 5)
    severity = SEVERITY[severity]
    destination = "common:#{name}:#{severity}"

    start_key = "#{destination}:start"

    connection.watch(start_key) do
      hour_start = Time.now.to_f
      existing = connection.get(start_key)

      connection.multi do |multi|
        if existing && existing < hour_start
          multi.rename(destination, "#{destination}:last")
          multi.rename(start_key, "#{destination}:pstart")
          multi.set(start_key, hour_start)
        end

        multi.zincrby(destination, 1.0, message)

        log_recent(name, message, severity: severity, conn: multi)
      end
    end
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end

Log.new.log_recent('foo', 'yabai', severity: Logger::FATAL)
Log.new.log_common('foo', 'yabai', severity: Logger::FATAL)
