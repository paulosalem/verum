# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.


# Provides a special evaluation environment.
module Verum

  class ConditionEvaluator

    def initialize(owner_machine, formal_variables)

      # TODO filter out reserved variable names (e.g., :evaluate, :machine)

      # The default context is empty
      @context = {}

      @owner_machine = owner_machine

      # Setup instance methods!
      formal_variables.each do |var_name, var_spec|
        define_singleton_method var_name, var_spec[:proc] # Here we are only interested in the :proc part of the specification.
      end
    end

    def evaluate(proc, context = {})
      @context = context

      instance_exec context, &proc
    end

    def context
      @context
    end

    def machine
      @owner_machine
    end

    # Always returns true. That is to say, makes the argument irrelevant.
    def any(arg)
      true
    end

    def allow_event?(symbol)
      @owner_machine.allow_event?(symbol)
    end

    def method_missing (method_name)
      puts "There is no method called '#{method_name}'. Are you sure you defined a formal variable so named?"
    end

  end
end