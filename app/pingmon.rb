# frozen_string_literal: true

require 'random/formatter'

class Pingmon < Roda
  plugin :json
  plugin :halt
  plugin :all_verbs
  plugin :json_parser
  plugin :error_handler

  UUID_REGEXP = /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/

  error do |_e|
    response.status = 500
    failure_payload('Internal server error')
  end

  route do |r|
    r.is 'ips' do
      r.post do
        ip = r.params['ip']
        enabled = r.params['enabled']

        begin
          IPAddr.new(ip)
          ip = ip.split('/').first
        rescue IPAddr::Error
          invalid_param_response(r, 'ip')
        end
        invalid_param_response(r, 'enabled') unless [true, false].include?(enabled)

        if DB.select_value("SELECT 1 FROM ips WHERE ip = '#{ip}' LIMIT 1")
          r.halt(422, failure_payload('IP address already exists'))
        end

        id = Random.uuid_v7
        DB.insert('ips', { id:, ip:, is_enabled: enabled })

        success_payload(id:, ip:, enabled:)
      end

      r.get do
        ips = DB.select_all('SELECT id, ip, is_enabled AS enabled FROM ips ORDER BY id DESC').data
        success_payload(ips)
      end
    end

    r.on 'ips', UUID_REGEXP do |id|
      unless DB.select_value("SELECT 1 FROM ips WHERE id = '#{id}'")
        r.halt(404, failure_payload('IP address not found'))
      end

      r.post 'enable' do
        DB.execute("ALTER TABLE ips UPDATE is_enabled = true WHERE id = '#{id}'")
        success_payload
      end

      r.post 'disable' do
        DB.execute("ALTER TABLE ips UPDATE is_enabled = false WHERE id = '#{id}'")
        success_payload
      end

      r.get 'stats' do
        time_from = parse_datetime_param(r, 'time_from')
        time_to   = parse_datetime_param(r, 'time_to')
        r.halt(422, failure_payload('Requested time range is invalid')) if time_to < time_from

        stats = DB.select_one <<-SQL
          SELECT
              count(*) AS count,
              round(avg(rtt), 3) AS avg_rtt,
              round(min(rtt), 3) AS min_rtt,
              round(max(rtt), 3) AS max_rtt,
              round(median(rtt), 3) AS median_rtt,
              round(stddevPop(rtt), 3) AS stddev_rtt,
              round(countIf(isNull(rtt)) / count(*) * 100, 2) AS packet_loss
          FROM ip_metrics
          WHERE ip_id = '#{id}'
          AND timestamp BETWEEN '#{time_from.strftime(DATE_FORMAT)}' AND '#{time_to.strftime(DATE_FORMAT)}'
        SQL
        r.halt(422, failure_payload('No statistics available')) if stats[:count].zero?

        success_payload(stats.except(:count))
      end

      r.delete true do
        DB.execute("ALTER TABLE ip_metrics DELETE WHERE ip_id = '#{id}'")
        DB.execute("ALTER TABLE ips DELETE WHERE id = '#{id}'")
        success_payload
      end
    end
  end

  private

  def success_payload(data = nil)
    { success: true, data: }.compact
  end

  def failure_payload(message)
    { success: false, message: }
  end

  def invalid_param_response(r, name)
    r.halt(422, failure_payload("Missing or invalid parameter: #{name}"))
  end

  def parse_datetime_param(r, name)
    value = r.params[name].to_s
    DateTime.parse(value)
  rescue Date::Error
    invalid_param_response(r, name)
  end
end
