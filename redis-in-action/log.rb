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

  def log_recent(name, message, severity: Logger::INFO)
    severity = SEVERITY[severity]
    destination = "recent:#{name}:#{severity}"

    connection.pipelined do
      connection.lpush(destination, "#{Time.new.asctime} #{message}")
      connection.ltrim(destination, 0, 99)
    end
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end

Log.new.log_recent('foo', 'yabai', severity: Logger::FATAL)
