# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

class Verum::Transition

  attr_reader :begin_state
  attr_reader :event
  attr_reader :end_state
  attr_reader :priority

  def initialize(begin_state, event, end_state, priority = 0)
    @begin_state = begin_state
    @event = event
    @end_state = end_state
    @priority = priority
  end


  def to_s
    "<#{@begin_state.to_s}, #{@event.to_s}, #{@end_state.to_s}, p = #{@priority.to_s}>"
  end

end