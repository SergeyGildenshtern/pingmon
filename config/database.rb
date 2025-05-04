# frozen_string_literal: true

module Database
  extend self

  def initialize!
    setup_config
    create_ips_table
    create_ip_metrics_table

    ClickHouse.connection
  end

  private

  def setup_config
    ClickHouse.config do |config|
      config.adapter = :net_http
      config.ssl_verify = false
      config.open_timeout = 3
      config.timeout = 60
      config.scheme = 'http'
      config.host = ENV['CLICKHOUSE_HOST']
      config.port = ENV['CLICKHOUSE_PORT']

      config.database = ENV['CLICKHOUSE_DB']
      config.username = ENV['CLICKHOUSE_USER']
      config.password = ENV['CLICKHOUSE_PASSWORD']

      config.symbolize_keys = true
    end
  end

  def create_ips_table
    ClickHouse.connection.execute <<-SQL
      CREATE TABLE IF NOT EXISTS ips (
        id          UUID    NOT NULL,
        ip          String  NOT NULL,
        is_enabled  Bool    NOT NULL
      ) ENGINE = MergeTree()
      ORDER BY id
    SQL
  end

  def create_ip_metrics_table
    ClickHouse.connection.execute <<-SQL
      CREATE TABLE IF NOT EXISTS ip_metrics (
        ip_id      UUID      NOT NULL,
        rtt        Float32   NULL,
        timestamp  DateTime  NOT NULL
      ) ENGINE = MergeTree()
      ORDER BY (ip_id, timestamp)
    SQL
  end
end
