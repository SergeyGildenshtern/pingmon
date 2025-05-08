# frozen_string_literal: true

require_relative '../app/services/ip_creator'
require_relative '../app/services/statistics_collector'

class Pingmon < Roda
  include Dry::Monads[:result]

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
        result = IpCreator.new(r.params['ip'], r.params['enabled']).call

        case result
        in Success(data)
          success_payload(data)
        in Failure[:invalid_param, name]
          invalid_param(r, name)
        in Failure[:exists]
          unprocessable_entity(r, 'IP address already exists')
        end
      end

      r.get do
        result = DB.select_all <<-SQL
          SELECT id, ip, is_enabled AS enabled
          FROM ips
          ORDER BY UUIDv7ToDateTime(id) DESC
        SQL
        success_payload(result.data)
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
        result = StatisticsCollector.new(id, r.params['time_from'], r.params['time_to']).call

        case result
        in Success(data)
          success_payload(data)
        in Failure[:invalid_param, name]
          invalid_param(r, name)
        in Failure[:invalid_range]
          unprocessable_entity(r, 'Requested time range is invalid')
        in Failure[:no_statistics]
          unprocessable_entity(r, 'No statistics available')
        end
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

  def unprocessable_entity(r, message)
    r.halt(422, failure_payload(message))
  end

  def invalid_param(r, name)
    unprocessable_entity(r, "Missing or invalid parameter: #{name}")
  end
end
