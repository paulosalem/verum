# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

require 'sourcify'
require 'nokogiri'

class Verum::FiniteStateMachine


  def initialize(initial_state_symbol, parent_machine = nil)

    @initial_state_symbol = initial_state_symbol
    @parent_machine = parent_machine

    @states = {}
    @events = {}
    @transitions = {}

    @allow_event = {}

    @output = {}

    @current_state = nil

    # A transition to be forced. When different from nil, tells the machine to take the transition even
    # if it's event's precondition does not hold.
    @forced_transition = nil

    # Whether the machine should check if the state invariants hold.
    @check_state_invariants = true

    @synch = Proc.new { |context| raise "Method synch is not implemented. If this is intended, call no_synch! before using the machine." }

    #
    # Formal verification mechanisms
    #


    # A hash that maps formal variable names to hashes containing its formal type, auxilliary values and a Proc that calculate their values.
    # E.g., {:var_1 => {type: :integer, values: [0, 10], proc: lambda {...} }, :var_2 => {...}}
    @formal_variables = {}

    # UPPAAL specs, if any
    @uppaal_specs = []
  end

  def current_state_symbol
    current = current_state
    if current != nil
      current.symbol
    else
      nil
    end
  end

  # Override this method to change how the state is stored for long-term use
  def current_state
    @current_state
  end

  # Sets the current state. Typically, this should be used only to set the initial state, since later states
  # are calculated by the FSM itself.
  #
  # Override this method to change how the state is stored for long-term use
  def current_state=(state)


    @current_state = state

    # WARNING: Do not call run_on_entry here, because we must be able to resume a previous machine state,
    #          which has already run on_entry.
  end

  # Returns all the states that can be reached with one transition from the current one, independently of
  # whether the appropriate events take place.
  def possible_next_states_symbols
    ts = @transitions[current_state.to_sym] || []
    ts.inject([]) do |memo, t|
      memo << t.end_state.to_sym
    end
  end

  def [](key)
    output[key]
  end

  def output
    if @parent_machine == nil
      @output

      # If there is a parent machine, we use its output
    else
      @parent_machine.output
    end
  end

  def disable_state_invariant_check!
    @check_state_invariants = false
  end

  def enable_state_invariant_check!
    @check_state_invariants = true
  end

  # Calculates the next state of this machine. This method will advance as many states as possible given the current
  # conditions and context, until either no possible transition is found or a repeated state is reached (to
  # avoid infinite loops).
  def next!(context = {})
    synch(context)
    current_symbol = current_state_symbol


    # If the machine is already running, there is a current state
    if (current_state != nil)
      # Current state's invariant must always hold
      current_state.check_invariant(context) if @check_state_invariants

      #
      # The machine may or may not be terminated. If not, it may further be blocked or not in the current state.
      # If it is, it means that there is a submachine running in the current state, and we must wait it terminate.
      # If it is not, we just advance the present machine.
      #

      # If the machine has terminated, nothing else is possible
      if terminated?
        current_state

        # If the machine has not terminated, but the current state is blocked
      elsif (!terminated?) && current_state.blocked?
        current_state.check_invariant(context) if @check_state_invariants
        current_state.next!(context) # Passes the control to the submachine contained in the state, if any.

        # RECURSIVE CALL BELOW
        #
        # If it is now possible to proceed in the present machine (since the current_state's submachine has just run),
        # let's do it.
        if !current_state.blocked?

          # NOTE: to avoid infinite loops, we require the next state (if any) to be not visited.
          next_transition = best_transition(context)
          if (next_transition != nil) && (!next_transition.end_state.visited?)
            self.next!(context)
          end

        end


        # On the other hand, if the current state is non-blocking, try to proceed with some transition
      elsif (!terminated?) && (!current_state.blocked?)
        current_state.check_invariant(context) if @check_state_invariants

        selected_transition = best_transition(context)

        #
        # If a transition is possible, take it.
        #
        if selected_transition != nil
          current_state.run_on_exit(context) # Leave the current state

          selected_transition.event.run(context) # Let the event do its job
          log("Event happened: " + selected_transition.event.symbol.to_s)

          # Set the new current state. Use the current_state= method, so that subclasses can change how the state is stored!
          self.current_state = selected_transition.end_state
          log("Entered state: " + current_state.symbol.to_s)

          current_state.run_on_entry(context)
          current_state.check_invariant(context) if @check_state_invariants
          current_state.next!(context) # Passes the control to the submachine contained in the state, if any.

          # RECURSIVE CALL BELOW
          #
          # If a transition is still possible, recursively advance the machine. This is necessary because
          # certain sequence of transitions have no preconditions internally, which logically means that
          # it can be executed as soon as possible (in practice, this has been shown to be true as well).
          #
          # NOTE: to avoid infinite loops, we require the next state (if any) to be not visited.
          next_transition = best_transition(context)
          if (next_transition != nil) && (!next_transition.end_state.visited?)
            self.next!(context)
          end

          # return the state reached, which is now the current one
          current_state
        else
          # no state can be reached, because there was no available transition
          nil
        end


        # else # There is no else. The above three alternatives are logically exhaustive.
      end


      # There is no current state, so we must set one.
    else
      start(context)
    end

    # If there is a submachine in the current_state, merge its output with the current machine's
    if current_state != nil && current_state.submachine != nil
      output.merge!(current_state.submachine.output)
    end
  end

  # Forces the machine to move to the specified next state, ignoring any precondition in the transitions.
  # The next state must be one that can be reached with one transition from the current one.
  # This method should be used only the user requires manual control over the system (e.g., because
  # some precondition is known to have taken place "off-line" and cannot be detected by the machine).
  def force_next!(next_state_symbol, context = {})
    # Currently possible transitions
    ts = @transitions[current_state.to_sym] || []

    ts.each do |t|
      if t.end_state.to_sym == next_state_symbol
        # This will ensure that the transition is selected later, during the calculation of the next state.
        @forced_transition = t
        break
      end
    end

    next!(context)
  end

  def start(context = {})
    if has_initial_state?
      self.current_state = @states[@initial_state_symbol]
      current_state.run_on_entry(context)
      current_state.check_invariant(context) if @check_state_invariants
      current_state.next!(context) # Passes the control to the submachine contained in the state, if any.
    else
      raise "The specified initial state (" + @initial_state_symbol + ") is not present in the machine."
    end

  end

  alias restart start

  def has_initial_state?
    @states.has_key? @initial_state_symbol
  end


  def terminated?
    if current_state != nil
      current_state.terminal? && (!current_state.blocked?)
    else
      false
    end
  end


  def state(name, &block)
    state = Verum::State.new(name, self)
    @states[name] = state
    state_builder = Verum::StateBuilder.new(state)


    # initializes the state
    block.call(state_builder) if block != nil
  end


  def event(name, &block)
    event = Verum::Event.new(name, self)
    @events[name] = event
    event_builder = Verum::EventBuilder.new(event)

    # initializes the event
    block.call(event_builder) if block != nil
  end


  def transition(begin_state_symbol, event_symbol, end_state_symbol, priority = 0)

    # if the state has not yet originated any transition, an initialization is in order
    if !@transitions.has_key? begin_state_symbol
      @transitions[begin_state_symbol] = []
    end

    @transitions[begin_state_symbol] << Verum::Transition.new(@states[begin_state_symbol], @events[event_symbol], @states[end_state_symbol], priority)

  end

  def allow_event(event_symbol)
    @allow_event[event_symbol] = true
  end

  alias allow allow_event

  def allow_event?(event_symbol)
    @allow_event[event_symbol]
  end

  def disallow_event(event_symbol)
    @allow_event[event_symbol] = false
  end

  alias disallow disallow_event

  def condition_evaluator
    if @condition_evaluator == nil
      @condition_evaluator = Verum::ConditionEvaluator.new self, @formal_variables
    end

    @condition_evaluator
  end

  # Explicitly defines that no synchronization is required for this machine.
  def no_synch!
    @synch = Proc.new { |context|}
  end


  ######################################################################################################################
  # Validation and formal verification facilities
  ######################################################################################################################


  # Register that a certain symbol, var_name, is to be considered a formal variable of the
  # specified type. Used in formal verification. The specified block shows how to calculate
  # the actual value of the variable when in normal execution (i.e., not under verification).
  #
  # Options:
  #   type:  :boolean, :integer, :enumeration
  #   min, max : the minimum and maximum values of an integer variable.
  #   values: an Array with the possible values of an enumeration variable.
  #   init: the initial value for the variable
  #
  def let(var_name, opts = {}, &block)


    #
    # Store the formal translation of the variable, if any.
    #
    formal_attrs = {}

    # Store the procedure that calculates the value of the variable during runtime.
    formal_attrs[:proc] = block

    if (opts.has_key? :type) && !(opts.has_key? :values)
      formal_attrs[:type] = opts[:type]
      formal_attrs[:min] = opts[:min]
      formal_attrs[:max] = opts[:max]
      formal_attrs[:init] = opts[:init]

    elsif (opts.has_key? :values)
      # The variable is of enumeration type
      formal_attrs[:type] = :enumeration
      formal_attrs[:values] = opts[:values]
      formal_attrs[:init] = opts[:init]


    else
      raise "The formal variable must have a type."
    end

    if(opts.has_key? :init)
      formal_attrs[:init] = opts[:init]
    end

    @formal_variables[var_name.to_sym] = formal_attrs
  end


  def constant(const_name, &block)
    @constants[const_name.to_sym] = block.call(nil)
  end

  alias const constant



  # Adds a UPPAAL query to be considered during model checking.
  def uppaal_spec(spec, comment = "")
    @uppaal_specs << [spec, comment]
  end

  #######################################################################
  # Convenience methods to simplify the specification of UPPAAL queries.#
  #######################################################################

  def uppaal_all_reacheable_except(exceptions, comment = "")

    # Consider only the state names that are not specified as exceptions
    names =
        @states.keys.reject do |key|
          exceptions.include? key
        end

    # Require these to be reacheable
    uppaal_reacheable_states(names, comment)
  end

  # E<> state_name
  def uppaal_reacheable_states(state_names, comment = "")
    state_names.each do |name|
      uppaal_spec("E<> Process.#{name}", comment)
    end
  end

  # Checks whether the specified states can be repeated forever.
  #
  # E[] state_name
  def uppaal_may_repeat_forever(state_names, comment = "")
    state_names.each do |name|
      uppaal_spec("E[] Process.#{name}", comment)
    end
  end

  # A[] !state
  def uppaal_unreacheable_states(state_names, comment = "")
    state_names.each do |name|
      uppaal_spec("A[] !Process.#{name}", comment)
    end
  end

  # A<> (progress condition) imply state_name
  def uppaal_inevitable_states(state_names, comment = "")
    comment += " WARNING: This will only work if priorities are turned off!"

    state_names.each do |name|
      uppaal_spec("A<> Process.#{name}", comment)
    end
  end

  # begin_state_name --> (()progress condition) imply end_state_name)
  def uppaal_leads_to(begin_state_name, end_state_name, comment = "")

    comment += " WARNING: This will only work if priorities are turned off!"

    uppaal_spec("Process.#{begin_state_name} --> Process.#{end_state_name}", comment)
  end



  # Produces a string which is a specification for the UPPAAL model-checker representing
  # this FSM.
  #
  # If use_priorities is false, the enconding in UPPAAL will ignore transitions priorities. This is required
  # to verify properties of the kind 'leads to' (i.e., p --> q), owing to UPPAAL limitations.
  def to_uppaal_spec(use_priorities = true)
    Verum::Converters::UppaalConverter.convert(self.class.to_s, @states, @events, @transitions, @initial_state_symbol, @formal_variables, @uppaal_specs, use_priorities)
  end

  # Produces a string which is a specification in the DOT graph format.
  # (see  http://en.wikipedia.org/wiki/DOT_%28graph_description_language%29)
  def to_dot_spec
    Verum::Converters::DOTConverter.convert(self.class.to_s, @states, @events, @transitions, @initial_state_symbol)
  end




  private

  # Logs a change in the machine. In the default implementation, this is written to stderr.
  # This can (and probably should) be overrided by subclasses to provide other logging mechanisms.
  def log(msg = "")
    $stderr.puts "[" + Time.now.to_s + "]" + self.class.to_s + " machine: " + msg
  end


  # Subclasses must always use this method to retrieve the current state, in order to allow
  # important (re-)initializations.
  def pick_state(key)
    state = @states[key]

    if state != nil
      if state.submachine != nil
        if !state.submachine.terminated?
          state.block!
        end
      end

      # Enforce invariants, if any
      state.check_invariant({}) if @check_state_invariants
    end

    state
  end

  # Determines whether a transition is possible from the current state. If such a transition exist, the method returns
  # it. Otherwise, nil is returned.
  def best_transition(context)
    current_symbol = current_state_symbol
    selected_transition = nil

    #
    # If the current state has transitions leaving it, we will check if one of them is currently possible.
    #
    if @transitions[current_symbol] != nil

      if @forced_transition == nil

        # Look for an event (thus a transition). Also check whether non-determinism is present, and abort if it is detected.
        @transitions[current_symbol].each do |t|
          # The event may happen if its precondition is fulfilled and if the user allows (if the user defined something in this respect).
          if t.event.precondition?(@allow_event[t.event.symbol], context)
            if selected_transition == nil
              # Ok, found an event for the first time, that is what we wanted
              selected_transition = t
            else

              # A second possible event was found. This is only allowed if priorities are different.
              if t.priority > selected_transition.priority
                selected_transition = t
              elsif t.priority < selected_transition.priority
                # nothing changes, the currently selected transition already has higher priority
              else # i.e.,  v.priority == selected_transition.priority
                raise "There is more than one possible transition to be triggered with the same priority: #{t.to_s} and #{selected_transition.to_s} Such non-determinism is not allowed."
              end

            end
          end
        end

      elsif @transitions[current_symbol].include? @forced_transition
        # Select the forced transition, independently of whether the event's precondition hold.
        selected_transition = @forced_transition

      end

      # "Unforce" the transition so that the next ones are "natural"
      @forced_transition = nil

    end


    selected_transition
  end

  # This is the first method called when the machine starts trying to move to the next state.
  # Should be used to synchronize all the relevant inputs and outputs which are specific
  # to particular machines. For example, fetch remote information for input, or equate
  # instance variables.
  #
  def synch(context)
    @synch.call
  end


end
