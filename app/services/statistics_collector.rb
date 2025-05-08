# frozen_string_literal: true

class StatisticsCollector
  include Dry::Monads[:result, :do]

  def initialize(id, time_from, time_to)
    @id        = id
    @time_from = time_from
    @time_to   = time_to
  end

  def call
    @time_from = yield parse_time('time_from', @time_from)
    @time_to   = yield parse_time('time_to', @time_to)
    yield check_time_range

    statistics = yield fetch_ip_statistics
    Success(statistics)
  end

  private

  def parse_time(name, value)
    result = DateTime.parse(value.to_s)
    Success(result)
  rescue Date::Error
    Failure[:invalid_param, name]
  end

  def check_time_range
    return Failure[:invalid_range] if @time_to < @time_from

    Success()
  end

  def fetch_ip_statistics
    result = DB.select_one <<-SQL
      SELECT
          count(*) AS count,
          round(avg(rtt), 3) AS avg_rtt,
          round(min(rtt), 3) AS min_rtt,
          round(max(rtt), 3) AS max_rtt,
          round(median(rtt), 3) AS median_rtt,
          round(stddevPop(rtt), 3) AS stddev_rtt,
          round(countIf(isNull(rtt)) / count(*) * 100, 2) AS packet_loss
      FROM ip_metrics
      WHERE ip_id = '#{@id}'
      AND timestamp BETWEEN '#{@time_from.strftime(DATE_FORMAT)}' AND '#{@time_to.strftime(DATE_FORMAT)}'
    SQL
    return Failure[:no_statistics] if result[:count].zero?

    Success(result.except(:count))
  end
end
