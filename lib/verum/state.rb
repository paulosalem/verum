# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

class Verum::State

  def initialize(symbol, machine)
    @symbol = symbol
    @machine = machine

    @initial = false
    @terminal = false

    # If progress is not guaranteed by the underlying formalism used in formal verification, this signals
    # to the translator that a special mechanism must be added to the translation in order to ensure this.
    # By default, this is true. For states in which the machine can stay forever, this must be set to false.
    @formally_force_progress = true

    @invariant = Proc.new { true }
    @on_entry = Proc.new {}
    @on_exit = Proc.new {}

    @submachine = nil
    @blocked = false # If the submachine is running, this state remains blocked.

    @terminal = false

    @visited = false
  end

  def to_sym
    @symbol
  end

  alias symbol to_sym

  def to_s
    symbol.to_s
  end

  def invariant_sexp
    # TODO handle possible Sourcify::NoMatchingProcError exception (and others?)
    @invariant_sexp =
        if @formal_invariant != nil
          @formal_invariant.to_sexp.deep_clone
        else
          nil
        end

    @invariant_sexp
  end

  #
  # Passes the control to the submachine stored in this state, if any.
  #
  def next!(context)
    if @submachine != nil
      @submachine.next!(context)
    end

    update_blocked
  end

  def check_invariant(context)
    update_blocked

    # If a formal invariant is available, use it. Otherwise, just use the ordinary one.
    invar_holds =
        if @formal_invariant != nil
          @machine.condition_evaluator.evaluate(@formal_invariant, context)
        else
          @invariant.call(context)
        end

    if !invar_holds
      raise "Invariant violation of state: #{self.to_s}"
    end
  end

  def initial=(b)
    @initial = b
  end

  def initial?
    @initial
  end

  def formally_force_progress=(b)
    @formally_force_progress = b
  end

  def formally_force_progress?
    @formally_force_progress
  end

  def terminal=(b)
    @terminal = b
  end

  def terminal?
    @terminal
  end


  def block!
    @blocked = true
  end

  def blocked?
    @blocked
  end


  def visit!
    @visited = true
  end

  def visited?
    @visited
  end

  def run_on_entry(context)
    visit!
    update_blocked
    @on_entry.call(context)
  end

  def run_on_exit(context)
    update_blocked
    @on_exit.call(context)
  end


  def invariant(proc)
    @invariant = proc
  end

  def formal_invariant(proc)
    @formal_invariant = proc
  end

  def terminal=(bool)
    @terminal = bool
  end

  def terminal?
    @terminal
  end

  def on_entry(proc)
    @on_entry = proc
  end

  def on_exit(proc)
    @on_exit = proc
  end

  def output
    @machine.output
  end

  def submachine
    @submachine
  end

  def submachine=(machine)
    @submachine = machine
  end

  private

  # Determines whether the state is blocked or not and sets the appropriate variable.
  def update_blocked
    if @submachine != nil

      # If the submachine has not terminated, this state remains blocking
      if !(@submachine.terminated?)
        @blocked = true
      else
        @blocked = false
      end

    else
      # Since there is no submachine to block the state, ensures that the state is not blocked!
      @blocked = false
    end
  end

end
