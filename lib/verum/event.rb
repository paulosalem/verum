# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

require 'sourcify'

class Verum::Event


  def initialize(symbol, machine)
    @symbol = symbol
    @machine = machine

    @precondition = Proc.new { true } # By default, the event can take place
    @job = Proc.new {}


    #
    # Formal verification mechanisms
    #

    @formal_precondition = nil

    # Stores the s-expression for the precondition. Used later to perform program analysis and generate appropriate
    # formal preconditions for verification.
    @precondition_sexp = nil;
  end

  def symbol
    @symbol
  end

  def precondition?(allow_status, context)
    # If a formal precondition is available, use it. Otherwise, just use the ordinary one.
    precond = if @formal_precondition != nil
                @machine.condition_evaluator.evaluate(@formal_precondition, context)
              else
                @precondition.call(context)
              end

    if allow_status == nil
      precond
    else
      precond && allow_status
    end
  end

  def run(context)
    @job.call
  end

  def precondition(proc)
    @precondition = proc
  end

  def formal_precondition(proc)
    @formal_precondition = proc
  end

  # The specified parameter must be a map from variable names to their desired values
  def formal_update=(values)
    @formal_update = values
  end

  def formal_update
    @formal_update
  end

  def job(proc)
    @job = proc
  end

  def output
    @machine.output
  end

  def to_s
    @symbol.to_s
  end

  def precondition_sexp
    # TODO handle possible Sourcify::NoMatchingProcError exception (and others?)
    @precondition_sexp =
        if @formal_precondition != nil
          @formal_precondition.to_sexp.deep_clone
        else
          nil
        end

    @precondition_sexp
  end


end
