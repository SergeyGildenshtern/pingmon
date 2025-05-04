# frozen_string_literal: true

require 'timeout'

class Pinger
  PING_TIMEOUT_SECONDS = ENV['PING_TIMEOUT_SECONDS'].to_i
  PING_RTT_REGEXP = /time=([\d.]+)\sms/

  def initialize(ips_queue, metrics_queue)
    @ips_queue = ips_queue
    @metrics_queue = metrics_queue
  end

  def call
    loop do
      data = @ips_queue.dequeue

      Async do
        rtt = ping(data[:ip])
        metric = { rtt:, ip_id: data[:id], timestamp: DateTime.now.strftime(DATE_FORMAT) }

        @metrics_queue.enqueue(metric)
      end
    end
  end

  private

  def ping(ip)
    command = IPAddr.new(ip).ipv6? ? 'ping6' : 'ping'

    Timeout.timeout(PING_TIMEOUT_SECONDS) do
      result = `#{command} -c 1 -n #{ip}`

      result.match(PING_RTT_REGEXP)&.captures&.first
    end
  rescue Timeout::Error
    nil
  end
end
