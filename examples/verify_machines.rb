#!/usr/bin/ruby
#
# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

#
#
# This script demonstrates how one can automate the generation of formal specifications from programs written using
# the Verum library. Here, we shall generate all available specifications and visualizations for the example provided.
# Each one will be saved to a different file in the same folder as this script.

require 'verum' # This assumes that the gem is installed!

require '../examples/drinks_machine'
require '../examples/simple_billing_machine'

sbm = Verum::Examples::SimpleBillingMachine.new
cm = Verum::Examples::DrinksMachine.new

File.open('drinks_machine.uppaal.xml', 'w') do |file|
  puts "Writting drinks machine's UPPAAL spec to file..."
  file.write(cm.to_uppaal_spec(false))
end
#puts cm.to_uppaal_spec


File.open('simple_billing_machine.uppaal.xml', 'w') do |file|
  puts "Writting simple billing machine's UPPAAL spec to file..."
  file.write(sbm.to_uppaal_spec)
end
#puts sbm.to_uppaal_spec


File.open('drinks_machine.dot', 'w') do |file|
  puts "Writting drinks machine's DOT visualization to file..."
  file.write(cm.to_dot_spec)
end
#puts cm.to_dot_spec

File.open('simple_billing_machine.dot', 'w') do |file|
  puts "Writting simple billing machine's DOT visualization to file..."
  file.write(sbm.to_dot_spec)
end

puts "Done!"


