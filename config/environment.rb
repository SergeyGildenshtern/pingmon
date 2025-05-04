# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'ipaddr'
require_relative 'database'

Bundler.require(:default)
DB = Database.initialize!

DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
