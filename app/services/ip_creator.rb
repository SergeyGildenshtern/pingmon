# frozen_string_literal: true

require 'ipaddr'
require 'random/formatter'

class IpCreator
  include Dry::Monads[:result, :do]

  def initialize(ip, enabled)
    @ip      = ip
    @enabled = enabled
  end

  def call
    yield check_ip_param
    yield check_enabled_param
    yield check_ip_existence

    id = create_ip
    Success({ id:, ip: @ip, enabled: @enabled })
  end

  private

  def check_ip_param
    IPAddr.new(@ip)
    @ip = @ip.split('/').first

    Success()
  rescue IPAddr::Error
    Failure[:invalid_param, 'ip']
  end

  def check_enabled_param
    return Failure[:invalid_param, 'enabled'] unless [true, false].include?(@enabled)

    Success()
  end

  def check_ip_existence
    ip_exists = DB.select_value("SELECT 1 FROM ips WHERE ip = '#{@ip}' LIMIT 1")
    return Failure[:exists] if ip_exists

    Success()
  end

  def create_ip
    id = Random.uuid_v7
    DB.insert('ips', { id:, ip: @ip, is_enabled: @enabled })

    id
  end
end
