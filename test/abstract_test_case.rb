# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

require 'verum'

# Used by RubyMine in order to display MiniTest results.
require 'minitest'
#require 'minitest/reporters'
#MiniTest::Reporters.use!

require 'minitest/autorun'


class AbstractTestCase < MiniTest::Unit::TestCase

  def setup

  end

  def print_current_state(machine)
    puts "Current state: " + machine.current_state_symbol.to_s
  end

end
