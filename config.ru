# frozen_string_literal: true

require_relative 'config/environment'
require_relative 'app/pingmon'

run Pingmon.freeze.app
