# frozen_string_literal: true

class Timer
  IP_FETCH_INTERVAL_SECONDS = ENV['IP_FETCH_INTERVAL_SECONDS'].to_i

  def initialize(ips_queue)
    @ips_queue = ips_queue
  end

  def call
    loop do
      @ips_queue.enqueue(*ips_for_ping)
      sleep(IP_FETCH_INTERVAL_SECONDS)
    end
  end

  private

  def ips_for_ping
    DB.select_all('SELECT id, ip FROM ips WHERE is_enabled = true').data
  rescue ClickHouse::Error
    []
  end
end
