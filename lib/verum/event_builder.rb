# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

class Verum::EventBuilder

  def initialize(event)
    @event = event
  end

  def precondition(&block)
    @event.precondition block
  end

  def formal_precondition(&block)
    @event.formal_precondition block
  end

  def formal_update=(values = {}) 
    @event.formal_update = values
  end

  def job(&block)
    @event.job block
  end

  def context
    @event.context
  end

  def output
    @event.output
  end

end
