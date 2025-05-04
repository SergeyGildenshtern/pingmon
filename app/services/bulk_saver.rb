# frozen_string_literal: true

class BulkSaver
  METRICS_BATCH_SIZE = ENV['METRICS_SAVE_BATCH_SIZE'].to_i

  def initialize(metrics_queue)
    @metrics_queue = metrics_queue
    @buffer = []
  end

  def call
    @metrics_queue.each do |metric|
      @buffer << metric
      next if @buffer.size < METRICS_BATCH_SIZE

      save_metrics
    end
  end

  private

  def save_metrics
    DB.insert('ip_metrics', @buffer)
    @buffer.clear
  rescue ClickHouse::Error
    nil
  end
end
