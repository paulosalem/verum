#
#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

Gem::Specification.new do |s|
  s.name        = 'verum'
  s.version     = '0.3.0'
  s.date        = '2015-03-27'
  s.summary     = "Verifiable Ruby Machines"
  s.description = "A programatic FSM library that makes specifications executable and verifiable."
  s.authors     = ["Paulo Salem"]
  s.email       = 'paulosalem@paulosalem.com'
  s.files       = ["lib/verum.rb"]
  s.homepage    = 'https://github.com/paulosalem/verum'
  s.license       = 'LGPL 3'

  s.add_runtime_dependency "sourcify",
                           ["~> 0.5.0"]

  s.add_runtime_dependency "sexp_processor"

  s.add_runtime_dependency "nokogiri"

  s.add_runtime_dependency "minitest"
end