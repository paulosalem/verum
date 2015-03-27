# -*- encoding : utf-8 -*-

#  Verum - a library for the execution and verification of Finite-State Machines.
#
#  Copyright (c) 2015 Paulo Salem.
#
#  This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.
#  For alternative licensing options, please contact the author at paulosalem@paulosalem.com.

require 'sexp_processor'
require 'cgi'

module Verum::Converters

  # A mixin with common useful methods.
  module UtilityComplements

    # Removes symbols that might cause problems (when rendered in the UPPAAL format) in the specified string.
    def filter(str)
      str.gsub(/\?|!/, '_')
    end

    def assert_non_nil(*values, element_name)
      values.each do |value|
        if value == nil
          raise "#{element_name}: cannot be left blank."
        end
      end
    end
  end


  module UppaalConverter
    extend Verum::Converters::UtilityComplements

    def self.convert(name, states, events, transitions, initial_state, formal_variables, specs,
        use_priorities = true, max_delay = 100000000)

      @name = name
      @states = states
      @events = events
      @transitions_map = transitions
      @initial_state = initial_state
      @formal_variables = formal_variables
      @specs = specs
      @use_priorities = use_priorities
      @max_delay = max_delay

      # A map from variables to maps that take their enumerable values to integers. Necessary in order to convert
      # enumerations to integers throughout the specification.
      @enum_to_int = {}

      # A map from priorities declared in transitions using Ruby programming to natural numbers that will be later
      # used to provide such priorities to UPPAAL
      @priority_to_natural = {}

      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.doc.create_internal_subset(
            'nta',
            "-//Uppaal Team//DTD Flat System 1.1//EN",
            "http://www.it.uu.se/research/group/darts/uppaal/flat-1_2.dtd"
        )

        xml.nta do
          xml.declaration do
            xml.text global_declarations
          end

          xml.template do
            xml.name "Machine"
            xml.declaration do
              xml.text "clock t; \n" # Global time
              xml.text "clock d; \n" # Local delays
              xml.text local_machine_declarations
            end

            locations_definition(xml)

            xml.init ref: @initial_state.to_s

            transitions_definition(xml)
          end

          xml.template do
            xml.name "PriorityEnforcer"
            xml.declaration do
              local_priorityenforcer_declarations(xml)
            end

            priorityenforcer_definitions(xml)
          end

          xml.system do
            xml.text <<-TXT
              // Place template instantiations here.
              Process = Machine();
              PE = PriorityEnforcer();

              // List one or more processes to be composed into a system.
              system Process, PE;
            TXT
          end

          xml.queries do
            queries_definition(xml)
          end

        end

      end

      builder.to_xml

    end


    def self.global_declarations
      spec = ""

      priorities = []

      #
      # Find all the priorities declared in Ruby and make them available for use in UPPAAL
      #

      @transitions_map.each do |k, transitions|
        transitions.each do |transition|
          priorities << transition.priority if transition.priority != nil
        end
      end

      # Ensures there is only one element of each and then order the result
      priorities.uniq!.sort!

      priorities.each_index do |i|
        @priority_to_natural.merge!({priorities[i] => i})
      end

      #
      # Declare channel variables which are used to enforce priorities, as well as their relative priorities.
      # The "default" channel is predefined by UPPAAL.
      #
      @priority_channels = @priority_to_natural.map do |k, v|
        "force_trans_#{v.to_s}"
      end

      if @priority_channels.length > 0
        spec += "chan " + @priority_channels.join(', ') + "; \n" # e.g., chan force_trans_0, force_trans_1, force_trans_2

        # If priorities are disabled, we comment their declaration out. The reason why one may wish to disable priorities
        # is that UPPAAL cannot deal with 'leads to' properties (i.e., p --> q) if transitions have priorities.
        comment_priorities_out =
            if @use_priorities
              ""
            else
              "// " # This comments out the line. Later, a user may simply remove it to add priorities back. That's why
              # we just comment them out here, instead of not including them at all in the spec.

            end

        spec += "#{comment_priorities_out} chan priority " + @priority_channels.join(' < ') + "; \n" # e.g., chan priority force_trans_0 < force_trans_1 < force_trans_2
      end

      spec

    end

    def self.local_machine_declarations
      spec = ""

      # Define the formal variables used in preconditions
      @formal_variables.each do |var, properties|
        # Clean up the variable's name
        var = filter(var.to_s)

        if properties[:type] != nil
          spec += "   " + var_typed_definition(var, properties[:type], values: properties[:values], min: properties[:min], max: properties[:max], init: properties[:init])

        elsif properties[:values] != nil
          spec += "   " + var_enumeration_definition(var.to_s, properties[:values], init: properties[:init])

        elsif properties[:types] != nil
          # Split the variable
          split_vars_by_type(var, properties[:types]).each do |typed_var|
            spec += "   " + var_typed_definition(typed_var[:name], typed_var[:type],
                                                 values: typed_var[:values], min: typed_var[:min], max: typed_var[:max],
                                                 init: properties[:init])
          end
        end


      end

      spec
    end

    def self.var_typed_definition(var_name, type, opts = {})

      # Determine whether there is an initial value
      init_assign =
          if opts[:init] != nil
            "= " + opts[:init].to_s
          else
            ""
          end

      # Render the declaration itself
      if type == :enumeration
        var_enumeration_definition(var_name, opts[:values])

      elsif type == :boolean
        "bool #{var_name.to_s} #{init_assign}; \n"

      elsif type == :integer
        assert_non_nil(opts[:min], opts[:max], "Integer boundaries")

        "int[#{opts[:min].to_s}, #{opts[:max].to_s}] #{var_name.to_s} #{init_assign}; \n"

      elsif type == :chronometer
        "clock #{var_name.to_s}; \n"
      else
        raise "Unsuported type '#{type}'."
      end

    end

    def self.var_enumeration_definition(var_name, var_values, opts = {})

      # Convert enumeration names to integers
      @enum_to_int.merge!({var_name => {}})
      count = 0
      var_values.each do |value|
        @enum_to_int[var_name].merge!({value.to_sym => count})
        count += 1
      end

      init_assign =
          if opts[:init] != nil
            "= " + @enum_to_int[var_name][opts[:init].to_sym].to_s
          else
            ""
          end

      " int[0, #{var_values.length - 1}] #{var_name} #{init_assign}; \n"
    end


    def self.locations_definition(xml)
      @states.keys.each do |key|
        xml.location(id: "#{key.to_s}") do
          xml.name "#{key.to_s}"


          xml.label kind: "invariant" do

            # If this is not a terminal state, we must set a special time-out invariant in order to force
            # the machine to eventually progress (i.e., it can't be stuck in a state). This addition is necessary
            # because the normal TA semantics allows for the machine to stay forever in a state.
            inv_txt =
                if (@states[key].formally_force_progress?)
                  if (@states[key].terminal?)
                    "true" # In a terminal state, it makes no sense to force progress

                  else
                    "(d <= #{@max_delay})"
                  end
                else
                  "true"
                end
                #if (!@states[key].terminal?)
                #  "(d <= #{@max_delay})"
                #else
                #  "true"
                #end

            # Also, the user may have specified his or her own invariants.
            if @states[key].invariant_sexp != nil
              inv_txt += " and (#{extract_formula(@states[key].invariant_sexp, :invariant)})"
            end

            xml.text inv_txt
          end


        end
      end

    end


    def self.init_definition
      "<init ref=\"#{@initial_state.to_s}\"/>"
    end

    def self.transitions_definition(xml)

      @transitions_map.keys.each do |begin_state_sym|
        @transitions_map[begin_state_sym].each do |trans|
          if trans.event != nil
            e_sym = trans.event.symbol

            xml.transition do
              xml.source ref: begin_state_sym.to_s
              xml.target ref: trans.end_state.to_s

              xml.label kind: "select" do
                xml.text extract_select(e_sym)
              end

              xml.label kind: "guard" do
                xml.text extract_precond(e_sym)
              end

              xml.label kind: "assignment" do
                # Besides the programmer-defined updates, we also set the delay clock d to 0, so that in the next
                # state it can be properly reused.
                xml.text (extract_update(e_sym, ['d := 0']))
              end

              xml.label kind: "synchronisation" do
                xml.text "#{@priority_channels.at(@priority_to_natural[trans.priority]).to_s}?"
              end
            end
          else
            puts "WARNING: nil event in transition '#{trans.to_s}'"
          end

        end

      end

    end

    def self.local_priorityenforcer_declarations(xml)
      # Nothing for now here...
    end

    def self.priorityenforcer_definitions(xml)
      xml.location(id: "pe0") do
        xml.name "pe0"
      end

      xml.init ref: "pe0"

      @priority_channels.each do |chan|
        xml.transition do
          xml.source ref: "pe0"
          xml.target ref: "pe0"
          xml.label(kind: "synchronisation") do
            xml.text "#{chan.to_s}!"
          end
        end
      end

    end

    def self.queries_definition(xml)
      @specs.each do |query|
        xml.query do
          xml.formula query[0].to_s
          xml.comment_ query[1]
        end
      end

    end


    def self.extract_update(event_key, extra_updates = [])
      var_to_value = @events[event_key].formal_update

      update =
          if var_to_value != nil
            updates = []
            var_to_value.each do |k, v|

              # Put correct value for enumerations. These must be converted to an integer value, owing to the lack
              # of proper enumerations in UPPAAL.
              new_value =
                  if @formal_variables[k][:type] == :enumeration
                    @enum_to_int[k][v]
                  else
                    v
                  end

              updates = updates << "#{k.to_s} := #{new_value.to_s}"
            end

            (updates + extra_updates).join(", ")

          else
            extra_updates.join(", ")
          end

      update
    end

    def self.extract_select(event_key)

      spec = []

      cp = ConditionProcessor.new(@formal_variables, @enum_to_int, :precondition)
      formula_sexp = @events[event_key].precondition_sexp
      cp.process(formula_sexp)

      cp.formal_variables_used.each do |formal_var|
        # If no initial value is assigned, we assume that the values for this variable will be non-deterministic
        if @formal_variables[formal_var][:init] == nil

          # Clocks are handled directly by the model checker, so we only need to care here about other types.
          if @formal_variables[formal_var][:type] != :chronometer

            type = @formal_variables[formal_var][:type]
            uppaal_type =
                case type
                  when :boolean
                    # Booleans are actually integers to UPPAAL
                    "int[0,1]"

                  # TODO unclear how these could be used when writting the UPPAAL precondition...
                  # when :enumeration
                  #   # Recall that our enumerations are represented as integers in UPPAAL
                  #   "int[0,#{formal_variables[formal_var][:values].length - 1}]"
                  #
                  # when :integer
                  #   "int[#{formal_variables[formal_var][:min]},#{formal_variables[formal_var][:max]}]"

                  else
                    raise "Non-determinism for type #{type.to_s} is not supported yet." +
                              "Please specify an initial value to the formal variable #{formal_var}."
                end

            spec << "nondet_#{filter(formal_var.to_s)}: #{uppaal_type}"
          end
        end
      end

      spec.join(', ')
    end

    def self.extract_precond(event_key)
      extract_formula(@events[event_key].precondition_sexp, :precondition)
    end

    def self.extract_formula(formula_sexp, type)

      original = "(no source available)"

      p = if (formula_sexp != nil) && (!formula_sexp.empty?)
            original = formula_sexp.to_s # Save the original source, because it will be destroyed when processed...

            cp = ConditionProcessor.new(@formal_variables, @enum_to_int, type)
            cp.process(formula_sexp).to_s
          else

            # If not precondition is set, we assume that the event can always happen
            "true"
          end

      p
    end


    class ConditionProcessor < SexpProcessor
      include Verum::Converters::UtilityComplements

      def initialize(formal_variables, enum_to_int, type)
        super()
        self.strict = false
        self.expected = String
        self.default_method = :not_supported

        @formal_variables = formal_variables

        @enum_to_int = enum_to_int

        @type = type # :invariant, :precondition

        @cleaned_formal_variables = {}
        formal_variables.each do |k, v|
          @cleaned_formal_variables[filter(k.to_s).to_sym] = v
        end


        # A set of the formal variables used in the expressions processed.
        @formal_variables_used = []

        # TODO is this variable useful at all??
        # A set of variables that have been declared to be anything, and can thus be ignored
        # when rendering conditions.
        @any = []
      end

      # Finds which formal variables are used in the specified expression.
      def formal_variables_used(exp = nil)
        process(exp) if exp != nil && !exp.empty?
        @formal_variables_used
      end

      def irrelevant_formal_variables(exp = nil)
        process(exp) if exp != nil && !exp.empty?
        @any
      end

      def process_lit(exp)
        exp.shift
        filter(exp.shift.to_s)
      end

      #def process_const(exp)
      #  exp.shift
      #  exp.shift # TODO interpret the symbol
      #end

      def process_str(exp)
        exp.shift
        exp.shift.to_s
      end

      def process_and(exp)
        exp.shift
        a = process(exp.shift)
        b = process(exp.shift)

        "#{a} and #{b}"
      end

      def process_or(exp)
        exp.shift
        a = process(exp.shift)
        b = process(exp.shift)

        "#{a} or #{b}"
      end

      def process_nil(exp)
        ""
      end

      def process_if(exp)
        exp.shift
        cond = process(exp.shift)
        if_true = process(exp.shift)
        if_false = process(exp.shift)

        if if_false == nil
          # If no else clause is defined, in Ruby a nil object is returned, which evaluates to false. So here
          # we explicitly define the result as FALSE when no else clause is in place.
          if_false = "false"
        end


        implication_1 = "(#{cond} imply #{if_true})"
        implication_2 = "((!#{cond}) imply #{if_false})"

        # Both implications MUST be present ALWAYS in order to ensure proper semantics.
        # Note, for instance, that if only implication_1 was present, then in a situation where cond == false
        # the condition would (by classical logic) ALWAYS evaluate to TRUE -- which would clearly not be
        # the intended semantics.
        "(#{implication_1} and #{implication_2})"
      end

      def process_true(exp)
        exp.shift
        "true"
      end

      def process_false(exp)
        exp.shift
        "false"
      end

      def process_call(exp)
        exp.shift
        receiver = process(exp.shift)

        method = exp.shift.to_s

        #
        # Arguments to the method
        #

        # The argument expression
        arg_name =
            if !exp.empty?
              process_argument(exp.shift)
            else
              nil
            end

        arg_name_sym = arg_name.to_s.to_sym

        #
        # Capture the type(s) of the formal variable, if it has been declared.
        #

        # Clean the method for proper printing in UPPAAL format.
        clean_method = filter(method)

        if @cleaned_formal_variables[clean_method.to_sym] != nil
          type = @cleaned_formal_variables[clean_method.to_sym][:type]
          values = @cleaned_formal_variables[clean_method.to_sym][:values] # it it is an enumeration
          types = @cleaned_formal_variables[clean_method.to_sym][:types]
          init = @cleaned_formal_variables[clean_method.to_sym][:init]

          ensure_correct_variable_type!(type, arg_name, values) if arg_name != nil

          # Record for later reference that the variable was used.
          @formal_variables_used << method.to_sym

        else
          type = values = types = nil
        end


        if (type == nil) && (values == nil) && (types == nil)
          # We are dealing now with reserved functions and keywords, not user-defined things.

          #
          # IDEAS other special functions:
          #
          #         - unchanged(v): specifies that the value of v must not change from one state to another

          if method.to_sym == :any
            # Handle special function any()
            # Marks the argument as something to be either have all its possibilities explored or ignored,
            # because anything can happen to it...

            if @cleaned_formal_variables.has_key?(arg_name_sym)

              # a simple formal variable, just add it to @any
              @any << arg_name_sym

              if (@cleaned_formal_variables[arg_name_sym][:init] == nil) && (@type == :precondition)
                # ...If no initial value was set, it means that we should try both of them. The nondet_ auxiliary variable
                # was defined elsewhere and permits this. Note that this special nondet_ variable is only available
                # in transitions, and hence we require that @type == :precondition. In state :invariant there is no such
                # provisions, so we must ignore the variable altogether.
                "#{arg_name.to_s} == nondet_#{arg_name.to_s}"

              else
                # ... thus, the generated condition is trivially true.
                "true"
              end

            else
              raise "any() must be applied to a formal variable, but instead was applied to: #{arg_name.to_s}"
            end

          else
            # We must be dealing with regular method calls.

            # method should be something like: <, >, <=, >=, ==, etc.
            # Must ensure that the comparisons/functions supported by UPPAAL
            op = convert_method_to_op(method)

            arg_filtered = lambda do |var_name|
              if @enum_to_int[var_name] != nil
                @enum_to_int[var_name][arg_name_sym]
              else
                arg_name
              end
            end


            "(#{receiver.to_s} #{op.to_s} #{arg_filtered.(receiver).to_s})"

          end


        elsif type == :boolean

          if (init == nil) && (@type == :precondition)
            # If no initial value was set, it means that we should try both of them. The nondet_ auxiliary variable
            # was defined elsewhere and permits this. Note that this special nondet_ variable is only available
            # in transitions, and hence we require that @type == :precondition. In state :invariant there is no such
            # provisions, so we must ignore the variable altogether.
            "#{clean_method.to_s} == nondet_#{clean_method}"

          else
            clean_method.to_s
          end

        elsif (type == :integer) || (type == :string)
          clean_method.to_s

        elsif type == :chronometer
          clean_method.to_s

        elsif (values != nil) && !values.empty?
          # Enumeration type
          clean_method.to_s

        else
          raise "Invalid call: (#{receiver.to_s} #{op.to_s} #{arg.to_s})"
        end


      end


      def process_argument(exp)
        if (exp.sexp_type == :call)
          exp.shift # :call
          exp.shift # nil
          filter(exp.shift.to_s) #:some_method_name
        else
          process(exp)
        end
      end

      def process_iter(exp)
        exp.shift
        exp.shift
        exp.shift
        process exp.shift
      end

      def not_supported(exp)
        puts "Element not supported: #{exp.to_s}."
      end


      private

      def convert_method_to_op(method)
        case method

          when '<', '>', '<=', '>=', '==', '!=', '+', '-', '*', '/'
            # These remain the same. The methods involving '<' and '>' will be automatically escaped by
            # the XML rendering library we employ.
            method.to_s

          else
            raise "This Ruby method cannot be converted to an equivalent UPPAAL operation: #{method.to_s}"
        end
      end

      # Returns true if the specified value is of the specified type, or raises an exception otherwise.
      # In case type is an :enumeration, the parameter enum_values define its possible values.
      def ensure_correct_variable_type!(type, value, enum_values = [])

        aux_is_number = lambda do
          if value.is_a? Integer
            true
          elsif (value.is_a? String) &&
              !(value =~ /[^\d\.]+/) # value must NOT match any non-digit or dot character.
            true
          else
            raise "The value for type '#{type} should be a number, but instead is #{value}'."
          end
        end

        if type == :enumeration
          if enum_values != nil
            match = enum_values.find do |enum_val|
              enum_val.to_sym == value.to_sym
            end

            if match != nil
              true
            else
              raise "The value for type '#{type} should be within the relevant enumeration, but instead is #{value}'."
            end

          else
            raise "Enumeration type must specify a set of possible values."
          end

        elsif type == :boolean
          (value == true) || (value == false)

        elsif type == :integer
          aux_is_number.()

        elsif type == :chronometer
          value == nil || aux_is_number.()

        else
          raise "Invalid type: #{type.to_s}."
        end
      end
    end


  end


  module DOTConverter

    def self.convert(name, states, events, transitions, initial_state)

      spec = <<-SPEC
digraph #{filter(name)} {
#{edges_definitions(transitions)}
}
      SPEC

      spec
    end

    def self.edges_definitions(transitions_map)
      transitions_map.values.inject "" do |memo1, transitions|
        s = transitions.inject "" do |memo2, transition|
          memo2 +
              "    #{filter(transition.begin_state.to_s)} -> #{filter(transition.end_state.to_s)} [label=\"#{filter(transition.event.to_s)} [#{transition.priority.to_s}]\"]\n"
        end

        memo1 + s
      end
    end

    # Removes symbols that might cause problems (when rendered in the DOT format) in the specified string.
    def self.filter(str)
      str.gsub(/[^\w]/, '_')
    end

  end


end



