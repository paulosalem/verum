# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.



require 'verum' # This assumes that the gem is installed!

# A simplified payment system, for the purpose of illustrating the use of Verum.
module Verum::Examples

  class SimpleBillingMachine < Verum::FiniteStateMachine

    attr_accessor :trial_days_used, :never_payed, :payed_days_used
    attr_reader :trial_days

    def initialize
      # Define the initial state
      super(:s_basic_account)

      @trial_days = 30

      @trial_days_used = 0
      @never_payed = true
      @payed_days_used = 0


      ## Formal variables ##################################################################################################

      let :trial_days, type: :integer, min: 30, max: 30 do
        machine.trial_days
      end

      let :trial_days_used, type: :chronometer do
        # Access machine variables through the machine() special method
        machine.trial_days_used
      end

      let :trial_days_left, type: :chronometer do
        # Arbitrary computations can be used in here.
        @trial_days - machine.trial_days_used
      end

      let :never_payed, type: :boolean, init: true do
        machine.never_payed
      end

      let :payed_days_used, type: :chronometer do
        machine.payed_days_used
      end

      let :allow_event__e_begin_trial, type: :boolean do
        allow_event?(:e_begin_trial)
      end

      let :allow_event__e_begin_purchase, type: :boolean do
        allow_event?(:e_begin_purchase)
      end



      ## States ############################################################################################################

      state :s_basic_account do |s|

        s.on_entry do
          puts "The user now has a basic account."
        end

        s.formally_force_progress = false # the user can stay here forever
      end

      state :s_trial_normal do |s|
        s.on_entry do
          puts "The user now is trying our premium offer."
        end

        # Ensure that the user does not stay here longer than permitted.
        s.formal_invariant do
          trial_days_used <= trial_days
        end
      end

      state :s_purchasing do |s|
        s.on_entry do
          puts "The user is performing a payment!"
        end
      end

      state :s_payment_normal do |s|
        s.on_entry do
          puts "The user is now a premium user."
        end

        s.formal_invariant do
          never_payed == false
        end
      end


      ## Events ############################################################################################################

      event :e_begin_trial do |e|
        e.formal_precondition do
          allow_event__e_begin_trial && (trial_days_used < trial_days)
        end

      end

      event :e_begin_purchase do |e|
        e.formal_precondition do
          allow_event__e_begin_purchase
        end
      end

      event :e_purchase_succeeds do |e|
        e.formal_update = {payed_days_used: 0, never_payed: false}
      end

      event :e_purchase_fails do

      end

      event :e_no_trial_days_left do |e|
        e.formal_precondition do
          trial_days_used >= trial_days
        end

      end

      event :e_no_payed_days_left do |e|
        e.formal_precondition do
          # Assuming that the payed period is 365 days
          payed_days_used > 365
        end
      end

      ## Transitions #######################################################################################################

      transition :s_basic_account, :e_begin_purchase, :s_purchasing
      transition :s_basic_account, :e_begin_trial, :s_trial_normal

      transition :s_trial_normal, :e_no_trial_days_left, :s_basic_account

      transition :s_purchasing, :e_purchase_succeeds, :s_payment_normal
      transition :s_purchasing, :e_purchase_fails, :s_basic_account

      transition :s_payment_normal, :e_no_payed_days_left, :s_basic_account


      #
      # UPPAAL assertions
      #
      uppaal_reacheable_states [:s_trial_normal, :s_purchasing, :s_payment_normal]
      uppaal_leads_to :s_trial_normal, :s_basic_account
      uppaal_may_repeat_forever [:s_basic_account], "The user may remain with a basic account forever."
      uppaal_spec("A[] !(Process.s_trial_normal and Process.trial_days_used > 30)")

    end

    def synch(context)
      puts "We are supposed to be storing stuff in the database now!"
    end

  end
end