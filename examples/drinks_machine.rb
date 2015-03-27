# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.


require 'verum' # This assumes that the gem is installed!

# The classical example of a simple drinks (coffee and chocolate) machine, for the purpose of
# illustrating the use of Verum.
module Verum::Examples
  class DrinksMachine < Verum::FiniteStateMachine

    attr_reader :selection_timer

    def initialize
      super(:initial)

      @selection_timer = 0

      #
      # Formal variables
      #

      let :desire_coffee, type: :boolean do
        context[:desire] == :coffee # context is assumed to exist in the environment where this Proc will run.
      end

      let :desire_chocolate, type: :boolean do
        context[:desire] == :chocolate # context is assumed to exist in the environment where this Proc will run.
      end

      let :always_true, type: :boolean do
        true
      end

      let :allow_put_coin, type: :boolean do
        machine.allow_event? :put_coin
      end

      let :kicks_in_the_machine, type: :integer, min: 0, max: 20, init: 0 do
        context[:kicks_in_the_machine] = 3
      end

      let :coffee_grains, type: :integer, min: 0, max: 2000, init: 1000 do
        # Let us assume a constant supply of grains
        1000
      end

      let :arbitrary_stuff, type: :enumeration, values: ['a', 'b', 'c'], init: 'a' do
        context[:arbitrary_stuff] = false # TODO
      end

      let :selection_timer, type: :chronometer do
        machine.selection_timer
      end

      let :allow_restart, type: :boolean do
        machine.allow_event? :restart
      end

      #
      # States
      #

      state :initial do |sb|
        sb.formally_force_progress = false # The user can stay here forever
      end

      state :coin_inside do |sb|
        sb.on_entry do
          puts "Coin inserted!"
          @selection_timer = 0 # resets the selection timer
        end

        # We can stay here for some time only
        sb.formal_invariant do
          selection_timer <= 5
        end
      end

      state :preparing_coffee do |sb|
        sb.on_entry do
          puts "Preparing coffee..."
        end
      end

      state :preparing_chocolate do |sb|
        sb.on_entry do
          puts "Preparing chocolate..."
        end
      end

      state :done do |sb|
        sb.on_entry do
          puts "Done. Please take your drink."
        end
      end

      state :return_money do |sb|
        sb.on_entry do
          puts "Please take your money back."
        end
      end


      #
      # Events
      #

      event :put_coin do |eb|
        eb.formal_precondition do
          allow_put_coin
        end

        # Ensure that the selection timer is properly restarted
        eb.formal_update = {selection_timer: 0}
      end

      event :selection_timeout do |eb|
        eb.formal_precondition do
          selection_timer >= 5
        end
      end

      event :hack_the_machine do |eb|
        eb.formal_precondition do
          if coffee_grains > 20
            allow_put_coin && (kicks_in_the_machine == 3 || kicks_in_the_machine == 7) && (arbitrary_stuff == 'a')

          elsif coffee_grains > 30
            false

          else
            always_true

          end
        end
      end

      event :press_coffee_button do |eb|
        eb.formal_precondition do # |context|
          if always_true
            desire_coffee && (coffee_grains > 10) && always_true
          end

        end
      end

      event :press_chocolate_button do |eb|
        eb.formal_precondition do |context|
          desire_chocolate
        end
      end

      event :finish_preparation

      event :restart do |eb|
        eb.formal_precondition do
          allow_restart
        end
      end


      #
      # Transitions
      #

      transition :initial, :put_coin, :coin_inside
      transition :initial, :hack_the_machine, :coin_inside, -1

      transition :coin_inside, :selection_timeout, :return_money
      transition :coin_inside, :press_coffee_button, :preparing_coffee
      transition :coin_inside, :press_chocolate_button, :preparing_chocolate

      transition :preparing_coffee, :finish_preparation, :done
      transition :preparing_chocolate, :finish_preparation, :done

      transition :done, :restart, :initial
      transition :return_money, :restart, :initial

      #
      # UPPAAL assertions
      #

      uppaal_spec("A<> !Process.initial imply Process.done or Process.return_money",
                  "The machine must always reach either the initial state or, failing that, done or return_money.")

      uppaal_reacheable_states [:preparing_coffee]


    end

    def synch(context = {})
      @selection_timer += 1
    end
  end
end