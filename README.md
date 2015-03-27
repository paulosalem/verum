Verum - Verifiable Ruby Machines
===============================================================================================

Verum (for **Ve**rifiable **Ru**by **M**achines) is an experimental Ruby library that allows the implementation of Finite-State Machines (FSM) which are both executable and formally verifiable. The same program that controls the behavior of the machine's actual execution is used to define the necessary features for formal verification. Verification is achieved by translating the machines into timed-automata specifications for the [UPPAAL model checker](http://www.uppaal.org/). Furthermore, the machines can be visualized using the DOT format, through tools such as [Graphviz](http://www.graphviz.org/).

The library comes with two simple examples: a drinks machine and a billing system. I recommend that you take a look in each of these examples, located at the `examples` folder. Here I summarize briefly the essential parts for creating a machine and how to use them. A complete account will, hopefully, be published as an academic paper soon.

## Instalation

The library is provided as a Ruby gem, which can be installed in various ways.

### Local packaging and installation

On Linux (and, presumably, Mac OS) you can download the source and run the included `install_gem_locally.sh` shell script. On Windows, certainly you can easily translate this script.


### Directly from GitHub

If you manage your gems through a `Gemfile`, you can add the following line to it in order to get the latest Verum version directly from GitHub:
```
  gem 'verum', git: "https://github.com/paulosalem/verum.git"
```


## How to define a machine

Every machine must extend the base class `Verum::FiniteStateMachine`. The main parts of the machine are then declared within its `initialize` method. Let us review below some parts of the example drinks machine.

### Formal variables
In order to allow the reuse of the same program text both for execution and for verification, Verum introduces the concept of *formal variables* through the `let` construct. The arguments for `let` define the name, type and other information about the formal variable, which will be used in verification. The block, in turn, is what is actually executed when the machine runs. Within this block, a number of special methods and variables are available, such as `context`.

```
  class DrinksMachine < Verum::FiniteStateMachine
    def initialize
      super(:initial)

      #
      # Formal variables
      #

      let :desire_coffee, type: :boolean do
        context[:desire] == :coffee # context is assumed to exist in the environment where this Proc will run.
      end

      let :kicks_in_the_machine, type: :integer, min: 0, max: 20, init: 0 do
        context[:kicks_in_the_machine] = 3
      end

      (...)

```

### States
The machine can be in various states, which are defined with the `state` command. If a block is provided, it can be used to setup various properties of the state. Most important of all, the `on_entry` method allows the programming of what is to be done when the state is reached during execution.

```
      #
      # States
      #

      state :initial

      state :coin_inside do |sb|
        sb.on_entry do
          puts "Coin inserted!"
        end
      end

      (...)
```

### Events
Events control the conditions on which transitions take place. Within an event, one may define a `formal_precondition`, in which the various formal variables defined previously can be used. Because this precondition will not only executed, but also parsed and translated into a timed-automaton specification, the vocabulary permited is only a subset of what Ruby allows. The following constructs are supported: 

  * References to the formal variables defined previously, which are actually method calls;
  * Logical constructs: or (`||`), and (`&&`), if expressions (`if ... else ... end`), `true` and `false`;
  * Comparators: `<`, `>`, `<=`, `>=`, `==`, `!=`;
  * Arithmetic operations: `+`, `-`, `/`, `*`.
  

```

      #
      # Events
      #

      event :press_coffee_button do |eb|
        eb.formal_precondition do
          if always_true
            desire_coffee && (coffee_grains > 10) && always_true
          end

        end
      end
      
      (...)

```

### Transitions
Finally, to complete the machine, transitions between states through events must be declared. In Verum transitions must be deterministic, which means that if two transitions are enabled at any moment, an exception will be thrown. To mitigate this issue, it is possible to define a transition's priority, in which case non-determinism is resolved by choosing the transition with higher priority. By default, the priority of every transition is zero.

```
      #
      # Transitions
      #

      transition :initial, :put_coin, :coin_inside
      transition :initial, :hack_the_machine, :coin_inside, -1
      
      (...)
```

### Formal specification properties
The above is sufficient to have a running machine and even to generate a formal spefication from it. However, the power of formal verification comes through the definition of *properties* to be verified. Because we use the UPPAAL model checker, the available properties are those that this tool can handle.

```

      #
      # UPPAAL assertions
      #

      uppaal_reacheable_states [:preparing_coffee]
      
      (...)

```


## How to execute a machine
Once a machine is defined, it can be instantiated and used. To this end, the most important method is the `next!` one, which makes the machine advance if conditions are right.

```
@drinks_machine = Verum::Examples::DrinksMachine.new
@drinks_machine.next!

@drinks_machine.allow_event :put_coin
@drinks_machine.next!

(...)
```

It is also possible to pass context information to the `next!` method, so that the machine can take inputs in cosideration for its next move.

```
@drinks_machine.next!(desire: :chocolate)
```


## How to verify a machine
To formally verify a machine, it must first be converted to a UPPAAL timed-automaton specification. This is achieved by a simple method call on the machine itself. The resulting text can be saved to a file.

```
File.open('coffee_machine.uppaal.xml', 'w') do |file|
  puts "Writting coffee machine's UPPAAL spec to file..."
  file.write(@drinks_machine.to_uppaal_spec(false))
end
```

The resulting XML can then be opened in UPPAAL and verified there. Please note, however, that this may result in approximations of the machine's real behavior. Treat this as one element among many in your verification toolbox, alongside regular testing practices.


## How to visualize a machine
Besides generating UPPAAL specifications, Verum also allows the generation of visualizations of the machine. This is achieved by producing a file in the DOT format, which can be rendered using various tools, such as [Graphviz](http://www.graphviz.org/).

```
File.open('coffee_machine.dot', 'w') do |file|
  puts "Writting coffee machine's DOT visualization to file..."
  file.write(@drinks_machine.to_dot_spec)
end
```

## License
Verum - a library for the execution and verification of Finite-State Machines.

Copyright (c) 2015 Paulo Salem.

This software is licensed under LGPL v3. Please see the attached LICENSE file for a complete description of the license.

For alternative licensing options, please contact the author at *paulosalem@paulosalem.com*.
