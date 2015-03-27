# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.


require './abstract_test_case'
require '../examples/drinks_machine'
require '../examples/simple_billing_machine'

# Tests Verum's execution capabilities.
class FiniteStateMachineTest < AbstractTestCase

  def setup
    super
    @drinks_machine = Verum::Examples::DrinksMachine.new
    @billing_machine = Verum::Examples::SimpleBillingMachine.new
  end

  def test_prepare_chocolate

    print_current_state(@drinks_machine)

    @drinks_machine.next!

    print_current_state(@drinks_machine)
    assert(@drinks_machine.current_state_symbol == :initial)

    @drinks_machine.allow_event :put_coin
    @drinks_machine.next!

    print_current_state(@drinks_machine)
    assert(@drinks_machine.current_state_symbol == :coin_inside)

    # The user now has a desire
    @drinks_machine.next!(desire: :chocolate)

    # The machine is supposed to go through the :preparing_chocolate state. Since there is no precondition
    # in the transition leading out of this state, we cannot check here that it is there. Rather, the machine
    # is going directly to :done
    #

    @drinks_machine.next!

    print_current_state(@drinks_machine)
    assert(@drinks_machine.current_state_symbol == :done)

    @drinks_machine.allow_event :restart

    @drinks_machine.next!

    print_current_state(@drinks_machine)
    assert(@drinks_machine.current_state_symbol == :initial)
  end

  def test_simple_billing
    print_current_state(@billing_machine)

    @billing_machine.next!
    assert(@billing_machine.current_state_symbol == :s_basic_account)

    print_current_state(@billing_machine)

    @billing_machine.allow_event :e_begin_trial
    @billing_machine.next!
    assert(@billing_machine.current_state_symbol == :s_trial_normal)

    print_current_state(@billing_machine)

    # Simulate the passage of time
    @billing_machine.trial_days_used = 29
    @billing_machine.next!
    assert(@billing_machine.current_state_symbol == :s_trial_normal)

    print_current_state(@billing_machine)

    @billing_machine.trial_days_used = 30
    @billing_machine.next!
    assert(@billing_machine.current_state_symbol == :s_basic_account)

    print_current_state(@billing_machine)

  end

  # TODO add tests of verification capabilities in another file?
end
