# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

class Verum::StateBuilder

  def initialize(state)
    @state = state
  end

  def invariant(&block)
   @state.invariant block
  end

  def formal_invariant(&block)
    @state.formal_invariant block
  end

  def formally_force_progress=(value)
    @state.formally_force_progress = value
  end

  def terminal=(value)
    @state.terminal = value
  end

  def on_entry(&block)
    @state.on_entry block
  end

  def on_exit(&block)
    @state.on_exit block
  end

  def output
    @state.output
  end

  def submachine
    @state.submachine
  end

  def submachine=(machine)
    @state.submachine = machine
  end

  def initial
    @state.initial = true
  end

  def terminal
    @state.terminal = true
  end

end
