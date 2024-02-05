;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Kauffman's NKC Fitness Landscape demonstrated.
;; See Kauffman, Stuart (1995; 2000).
;; This NetLogo version (C) Christopher Watts, 2014. See Info tabe for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  sorted-agents
  
  mean-fitness
  max-fitness
  min-fitness
  median-fitness
  stdev-fitness
  num-unstable
  
  state-colors
  change-colors
]

breed [agents agent]
breed [variables variable]
directed-link-breed [ilinks ilink]
directed-link-breed [vlinks vlink]

agents-own [
  fitness
  alt-fitness
]
variables-own [
  fitness-contributions
  inputs
  state
  next-state
  alt-state
  last-change
  owner
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  
  set state-colors array:from-list (list blue pink)
  set change-colors array:from-list (list red lime)
  
  ask patches [set pcolor white]
  
  let cur-item 0
  create-agents number-of-agents [
    set size 4
    set shape "person"
    set color black
  ]
  set sorted-agents (sort agents)
  let small-radius 0
  ifelse 1 = count agents [
    ask (first sorted-agents) [setxy ((max-pxcor - min-pxcor) / 2) ((max-pycor - min-pycor) / 2)]
    set small-radius world-width * 0.25
  ]
  [
    layout-circle sorted-agents (world-width * 0.35)
    set small-radius 0.25 * min [min [distance myself] of other agents] of agents
  ]
  
  foreach sorted-agents [
    create-variables number-of-variables-per-agent [
      set size 4
      set shape "circle"
      set owner ?
      create-vlink-to ? [
        set color grey
        set hidden? true
      ]
    ]
  ]
  
  ; Checking parameters
  if k-internal-dependencies >= max [count my-in-vlinks] of agents [
    user-message (word "K is too high.")
    stop
  ]
  if c-external-dependencies > max [(count variables) - count my-in-vlinks] of agents [
    user-message (word "C is too high.")
    stop
  ]
  
  ; Define input tables and fitness contributions for each node.
  let sel-var nobody
  let ext-inputs []
  let int-variables []
  let ext-variables []
  let cur-owner nobody
  ask variables [
    set state (random 2)
    set next-state state
    set last-change ticks
    let cur-var self
    
    set cur-owner owner
    set int-variables ([in-vlink-neighbors] of cur-owner) with [self != cur-var]
    set ext-variables (variables with [owner != cur-owner])
    set inputs sort (n-of k-internal-dependencies int-variables)
    set ext-inputs sort (n-of c-external-dependencies ext-variables)
    foreach inputs [
      ask ? [
        create-ilink-to cur-var [
          set color orange
          if curved-links? [ set shape "input" ] ; Slows updating
        ]
      ]
    ]
    foreach ext-inputs [
      ask ? [
        create-ilink-to cur-var [
          set color brown
          if curved-links? [ set shape "input" ]
        ]
      ]
    ]
    set inputs (sentence inputs ext-inputs self)
    
    ifelse simulation-type = "Boolean update"[
      ; For simplicity, we code the boolean updates table as a fitness contributions table.
      set fitness-contributions array:from-list n-values (2 ^ (length inputs)) [random 2]
    ]
    [
      set fitness-contributions array:from-list n-values (2 ^ (length inputs)) [random-float 1]
    ]
  ]
  
  ask agents [
    let small-angle 360 / (count in-vlink-neighbors)
    let cur-var 0
    ask in-vlink-neighbors [
      move-to owner
      set heading (cur-var * small-angle)
      fd small-radius
      rt 90
      set cur-var cur-var + 1
    ]
  ]
  
  ask agents [set fitness fitness-calculation]
  update-stats

  colour-variables

  my-update-plots
end

to reset-agents
  ask variables [
    set state (random 2)
    set next-state state
    set last-change ticks
  ]
    
  ask agents [set fitness fitness-calculation]
  
  colour-variables

  update-stats
  my-update-plots
end

to update-stats
  set mean-fitness mean [fitness] of agents
  set max-fitness max [fitness] of agents
  set min-fitness min [fitness] of agents
  set median-fitness median [fitness] of agents
  set stdev-fitness (ifelse-value (1 = count agents) [0] [standard-deviation [fitness] of agents])
  set num-unstable count variables with [last-change >= ticks - change-threshold]
end  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report fitness-calculation
  let f-sum 0
  ask in-vlink-neighbors [
    let f-row 0
    foreach inputs [
      set f-row f-row * 2
      set f-row f-row + ([state] of ?)
    ]
    set f-sum f-sum + (array:item fitness-contributions f-row)
  ]
  report (f-sum / (count in-vlink-neighbors))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  tick
  
  if simulation-type = "Hill climb: Egoists in parallel" [parallel-hill-climb]
  if simulation-type = "Hill climb: One Egoist" [one-agent-hill-climb]
  if simulation-type = "Optimise: Egoists in parallel" [agents-optimise-in-parallel]
  if simulation-type = "Optimise: One Egoist" [agent-optimises]
  if simulation-type = "Optimise: One Egoist in turn" [agents-optimise-in-turn]
  if simulation-type = "Hill climb: One Altruist" [one-agent-hill-climb-common-goal]
  if simulation-type = "Cascading updates" [cascading-updates]
  
  ask variables [
    if state != next-state [set last-change ticks]
    set state next-state
  ]
  
  ask agents [set fitness fitness-calculation]
  
  colour-variables
  
  update-stats
  my-update-plots
  if print-statistics [
    print (word mean-fitness ", " max-fitness ", " min-fitness)
  ]
  
end

to parallel-hill-climb
  ; All agents perform hill climbing in parallel. 
  ; Agents seek to improve only their own fitness.
  ask agents [
    set alt-fitness fitness
    let flip-variable one-of in-vlink-neighbors
    ask flip-variable [
      set alt-state state
      set state 1 - alt-state
    ]
    set fitness fitness-calculation
    ifelse fitness < alt-fitness [
      ;rollback
      ask flip-variable [
        set next-state alt-state
        set state alt-state
      ]
;      set fitness alt-fitness
    ]
    [
      ask flip-variable [
        set next-state state
        set state alt-state
      ]
    ]
  ]
end  

to one-agent-hill-climb
  ; One agent per tick uses hill climbing to improve only its own fitness.
  ask one-of agents [
    set alt-fitness fitness
    let flip-variable one-of in-vlink-neighbors
    ask flip-variable [
      set alt-state state
      set state 1 - alt-state
    ]
    set fitness fitness-calculation
    ifelse fitness < alt-fitness [
      ;rollback
      ask flip-variable [
        set next-state alt-state
        set state alt-state
      ]
;      set fitness alt-fitness
    ]
    [
      ask flip-variable [
        set next-state state
        set state alt-state
      ]
    ]
  ]
end

to agents-optimise-in-turn
  ; Every tick, each agent in turn ries every possible combination of its own variables' values. 
  ; Agent seeks best in terms its own fitness only. 
  ; Agent updates its state before the next agent takes it turn.
  let latest-return 0
  foreach sort agents [
    ask ? [
      ask in-vlink-neighbors [
        set alt-state state
      ]
      set latest-return agent-best
      ask in-vlink-neighbors [
        set next-state state
      ]
    ]
  ]
end

to agent-optimises
  ; One agent per tick tries every possible combination of its own variables' values. 
  ; Agent seeks best in terms its own fitness only.
  let latest-return 0
  ask one-of agents [
    set alt-fitness fitness
    ask in-vlink-neighbors [
      set alt-state state
    ]
    set latest-return agent-best
    ask in-vlink-neighbors [
      set next-state state
      set state alt-state
    ]
    set fitness alt-fitness
  ]
end

to agents-optimise-in-parallel
  ; All agents in parallel try every possible combination of their own variables' values. 
  ; Agents seek best in terms their own fitness only.
  let latest-return 0
  foreach sort agents [
    ask ? [
      set alt-fitness fitness
      ask in-vlink-neighbors [
        set alt-state state
      ]
      set latest-return agent-best
      ask in-vlink-neighbors [
        set next-state state
        set state alt-state
      ]
      set fitness alt-fitness
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to cascading-updates
  ; Flip one bit. If it's better, keep new state, but test dependents also.
  let cur-batch []
  let next-batch (list (one-of variables))
  let num-updates 0
  while [0 < length next-batch] [
    set cur-batch shuffle remove-duplicates next-batch
    set next-batch []
    foreach cur-batch [
      if [state = next-state] of ? [ ; Have not updated this variable yet.
        ask [owner] of ? [
          set alt-fitness fitness
          let flip-variable ?
          ask flip-variable [
            set alt-state state
            set state 1 - alt-state
          ]
          set fitness fitness-calculation
          ifelse fitness < alt-fitness [
            ;rollback
            ask flip-variable [
              set next-state alt-state
              set state alt-state
            ]
            ;      set fitness alt-fitness
          ]
          [
            ask flip-variable [
              set next-state state
              set state alt-state
              set num-updates num-updates + 1
              if num-updates < (count variables) [ ; May want a safety limit
                ask out-ilink-neighbors with [state = next-state] [ set next-batch fput self next-batch ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]
  print num-updates
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report agent-best
  ; For current agent, cycle through all solutions and return with one of the best.
  let v-order array:from-list sort in-vlink-neighbors
  let carryover 0
  let cur-node 0
  let num-nodes (count in-vlink-neighbors)
  let unfinished true
  let best-fitness -1
  let best-sol n-values num-nodes [0]
  ask in-vlink-neighbors [set state 0]
  set fitness fitness-calculation
  set best-fitness fitness
  set best-sol map [[state] of ?] (array:to-list v-order)
  
  while [unfinished] [
    set cur-node 0
    set carryover 1
    while [(carryover != 0) and (cur-node < num-nodes)] [
      ifelse 0 = [state] of (array:item v-order cur-node) [
        ask (array:item v-order cur-node) [set state 1]
        set carryover 0
      ]
      [
        ask (array:item v-order cur-node) [set state 0]
        set carryover 1
      ]
      set cur-node cur-node + 1
    ]
    set unfinished not ((cur-node = num-nodes) and (carryover = 1))
    set fitness fitness-calculation
    if fitness > best-fitness [
      set best-fitness fitness
      set best-sol map [[state] of ?] (array:to-list v-order)
    ]
  ]
  
  foreach (array:to-list v-order) [
    ask ? [ set state first best-sol ]
    set best-sol but-first best-sol
  ]
  set fitness best-fitness
  report fitness
end

to one-agent-hill-climb-common-goal
  ; One agent per tick uses hill climbing to improve population's mean fitness.
  ask one-of agents [
    set alt-fitness fitness
    let alt-group-fitness sum [fitness] of agents
    let flip-variable one-of in-vlink-neighbors
    ask flip-variable [
      set alt-state state
      set state 1 - alt-state
    ]
    set fitness fitness-calculation
    let group-fitness sum [fitness-calculation] of agents
    ifelse group-fitness < alt-group-fitness [
      ;rollback
      ask flip-variable [
        set next-state alt-state
        set state alt-state
      ]
;      set fitness alt-fitness
    ]
    [
      ask flip-variable [
        set next-state state
        set state alt-state
      ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to colour-variables
  if Variables-Colour = "On and Off" [
    ask variables [set color array:item state-colors state]
  ]
  if Variables-Colour = "Changing" [
    ask variables [set color array:item change-colors (ifelse-value (last-change >= ticks - change-threshold) [1] [0])]
  ]
end  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to my-update-plots
  set-current-plot "Fitness"
  set-current-plot-pen "Mean"
  plotxy ticks mean-fitness
  set-current-plot-pen "Max"
  plotxy ticks max-fitness
  set-current-plot-pen "Min"
  plotxy ticks min-fitness
  
  if ticks > change-threshold [
    set-current-plot "Instability"
    plotxy ticks num-unstable
  ]
  
end  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   
@#$#@#$#@
GRAPHICS-WINDOW
246
10
656
441
-1
-1
4.0
1
10
1
1
1
0
0
0
1
0
99
0
99
0
0
1
ticks
30.0

SLIDER
19
42
238
75
Number-Of-Agents
Number-Of-Agents
1
100
4
1
1
NIL
HORIZONTAL

SLIDER
19
78
238
111
Number-Of-Variables-Per-Agent
Number-Of-Variables-Per-Agent
1
20
5
1
1
NIL
HORIZONTAL

MONITOR
5
188
87
233
# Variables
number-of-variables-per-agent * number-of-agents
17
1
11

BUTTON
5
240
69
273
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
19
114
238
147
K-Internal-Dependencies
K-Internal-Dependencies
0
9
3
1
1
NIL
HORIZONTAL

SLIDER
19
149
237
182
C-External-Dependencies
C-External-Dependencies
0
9
1
1
1
NIL
HORIZONTAL

MONITOR
680
197
759
242
Mean
mean-fitness
5
1
11

MONITOR
761
197
841
242
Max
max-fitness
5
1
11

BUTTON
5
328
68
361
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
71
328
140
361
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
679
11
961
161
Fitness
Time (ticks)
Agent Fitness
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -16777216 true "" ""
"Max" 1.0 0 -13345367 true "" ""
"Min" 1.0 0 -11221820 true "" ""

TEXTBOX
8
12
240
34
Kauffman's SNKC Fitness
20
0.0
1

INPUTBOX
5
418
160
478
Change-Threshold
10
1
0
Number

CHOOSER
5
369
143
414
Variables-Colour
Variables-Colour
"On and Off" "Changing"
0

TEXTBOX
682
178
832
196
Agent Fitness Statistics:
11
0.0
1

CHOOSER
4
277
230
322
Simulation-Type
Simulation-Type
"Hill climb: Egoists in parallel" "Hill climb: One Egoist" "Optimise: Egoists in parallel" "Optimise: One Egoist" "Optimise: One Egoist in turn" "Hill climb: One Altruist" "Cascading updates"
1

BUTTON
142
328
237
361
Reset Agents
reset-agents
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
92
188
223
233
# Inputs Per Variable
k-internal-dependencies + c-external-dependencies + 1
17
1
11

MONITOR
761
244
841
289
Min
min-fitness
5
1
11

MONITOR
680
244
759
289
Median
median-fitness
5
1
11

MONITOR
843
197
923
242
Stdev
stdev-fitness
5
1
11

PLOT
680
295
880
445
Instability
Time (ticks)
# Unstable
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
882
295
1009
340
# Unstable Variables
num-unstable
17
1
11

MONITOR
882
342
1010
387
%
100 * num-unstable / (count variables)
3
1
11

SWITCH
246
446
379
479
Curved-Links?
Curved-Links?
1
1
-1000

TEXTBOX
6
47
21
70
S
14
0.0
1

TEXTBOX
6
84
21
102
N
14
0.0
1

TEXTBOX
7
122
22
140
K
14
0.0
1

TEXTBOX
6
156
21
174
C
14
0.0
1

SWITCH
382
446
517
479
Print-Statistics
Print-Statistics
1
1
-1000

@#$#@#$#@
# KAUFFMAN'S NK FITNESS MODEL

A demonstration of Stuart Kauffman's concept of NKC Fitness. (See Kauffman 1993; 1995; 2000.) More precisely, a demonstration of coadapting agents (e.g. species, firms) with a given number of traits and given numbers of interdependencies between them, leading to a tunable level difficulty in finding combinations of traits that are satisfactory to all agents in the population.

This NetLogo program (C) Christopher J Watts, 2014. See below for terms and conditions of use.

The program was developed to accompany chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

A number (S) of agents will try to find the most fit combination of state values for a number (N) of boolean variables. The fitness value of their set of variables is determined by tables of fitness values, with one table for each variable in the set.

Each variable is a node in a network. Each node has a number of input nodes, each with its own state, on which a node variable's contribution to fitness will depend. Each node's fitness table contains one row for each combination of input states. Input nodes are chosen randomly at the start, with K inputs sampled from the agent's other variables, C inputs sampled from variables owned by other agents, and 1 input from the variable itself. Thus each node's fitness table has (2 ^ (K + C + 1)) rows.

Agents start with their variables in random states. They then seek better combinations of states using heuristic search algorithms. The search algorithms include a random-walk hill climbing algorithm, which agents may perform one agent at a time in random order (i.e. agents sequentially), or in parallel. In random-walk hill climbing, or trial-and-error experimentation, a problem-solving agent chooses one of its variables, alters the state of that variable, and calculates the resulting fitness value for its new combination of variable states. If the fitness is greater than or equal to its previous value, then the agent will adopt the new state for the variable next time tick. Otherwise, the agent will reverse the state change. An agent may be trying to find better fitness for itself ("Egoist") or for all agents ("Altruist"). State changes only become visible to other agents at the end of the time tick.

If C > 0 then agents may change their states in response to other agents' changes. If agents update in parallel, then the information about input states which an agent incorporated when updating may have changed by the very next time tick, and thus what seemed at the time to be an optimal combination of states may be suboptimal after one tick.


## HOW TO USE IT

Select the number of agents, number of variable nodes per agent, and K and C dependencies. Click "Setup". Agents, variable nodes and dependency links will be drawn. Links within an agent's set of variables are shown in orange. Links between agents' sets are shown in brown. Variable nodes may be coloured according to their current state (on/off), or according to whether they have changed within a given number of ticks.

Select the "Simulation-type". The choice is:

* "Hill climb: Egoists in parallel": All agents perform hill climbing in parallel. Agents seek to improve only their own fitness.
* "Hill climb: One Egoist": One agent per tick uses hill climbing to improve only its own fitness.
* "Optimise: Egoists in parallel": All agents in parallel try every possible combination of their own variables' values. Agents seek best in terms their own fitness only.
* "Optimise: One Egoist": One agent per tick tries every possible combination of its own variables' values. Agent seeks best in terms its own fitness only.
* "Optimise: One Egoist in turn": Every tick, each agent in turn ries every possible combination of its own variables' values. Agent seeks best in terms its own fitness only. Agent updates its state before the next agent takes it turn.
* "Hill climb: One Altruist": One agent per tick uses hill climbing to improve population's mean fitness.
* "Cascading updates": Flip one bit. If the result is better, keep new state, but test dependents also.

Click "Go" to start agents' heuristic searches for fitter variables.

Click "Reset" to give agents variables randomly chosen states.


## THINGS TO NOTICE

If C is low (how low depends in part on K), agents should all be able to find optimal combinations of states, i.e. combinations which they do not want to change, whereupon the system stabilises. At higher values of C, agents may be unable to find a stable system state.

Clicking "Reset" will make agents seek again, but from a different starting point and via different attempted changes. When stability re-emerges, agents may have stabilised on different solutions to before, with different fitness values. This reflects the fact that the fitness landscape consists of multiple peaks or local optima.


## THINGS TO TRY

Explore the parameter space. Record the population mean and max fitness after a given number of ticks. Does the system appear to have stabilised?

Is it better to update agents one at a time or in parallel?

Decomposing a task:  
If the N is relatively low, you might like to try the option "agents optimise in turn". In this, each agent in turn is invited to search through all its possible solutions to identify the best (the global optimum), given current inputs from others. This is much quicker than searching through all possible combinations of all variables held by the population. E.g. Suppose there are 4 agents and N=5 variables per agent. There are 2 ^ N = 32 possible combinations for each agent, and 4 * 32 = 128 solutions to evaluate in total. This is much less than 2 ^ (4 * N) = 2 ^ 20 = 1048576. Does such decomposition of the problem produce good solutions for each agent? Try different values of N, K and C. How do these affect the advantage of decomposition? (Also, which is better for fitness or stability: agents optimising in turn or in parallel?)


## EXTENDING THE MODEL

Variable nodes have a fixed number of input nodes, which are sampled at random without preference. What if some structure or preference is followed during allocation of input nodes?

What other heuristic search algorithms could our agents follow? Are any better than random-walk hill climbing?


## RELATED MODELS

Lots of models make use of Kauffman's NK fitness landscapes!

## CREDITS AND REFERENCES

Kauffman, S. (1993) "The Origins of Order: Self-Organization and Selection in Evolution." New York: Oxford University Press.

Kauffman, S. (1995) "At Home in the Universe: The Search for Laws of Complexity." London: Penguin.

Kauffman, S. (2000) "Investigations." Oxford: Oxford University Press.


## OUR TERMS AND CONDITIONS OF USE

This program was developed for the book:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

If you use this program in your work, please cite the book, as well as giving the URL for the website from which you downloaded the program and the date on which you downloaded it. A suitable form of citation for the program is:

Watts, Christopher (2014) “Name-of-file”. Retrieved 31 January 2014 from http://www.simian.ac.uk/resources/models/simulating-innovation.

This program is free software: you can redistribute it and/or modify it under the terms of version 3 of the GNU General Public License as published by the Free Software Foundation. See http://www.gnu.org/licenses/ for more details. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

Those wishing to make commercial use of the program should contact the book’s authors to discuss terms.

This program has been designed to be run using NetLogo version 5, which can be obtained from http://ccl.northwestern.edu/netlogo/
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="200" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 200</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>count variables</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>median-fitness</metric>
    <metric>stdev-fitness</metric>
    <metric>num-unstable</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Variables-Per-Agent">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Internal-Dependencies">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C-External-Dependencies">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Simulation-Type">
      <value value="&quot;Hill climb: Egoists in parallel&quot;"/>
      <value value="&quot;Hill climb: One Egoist&quot;"/>
      <value value="&quot;Optimise: Egoists in parallel&quot;"/>
      <value value="&quot;Optimise: One Egoist&quot;"/>
      <value value="&quot;Optimise: One Egoist in turn&quot;"/>
      <value value="&quot;Hill climb: One Altruist&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Variables-Colour">
      <value value="&quot;Changing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Change-Threshold">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-HC-One" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 6400</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>count variables</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>median-fitness</metric>
    <metric>stdev-fitness</metric>
    <metric>num-unstable</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Variables-Per-Agent">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Internal-Dependencies">
      <value value="1"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C-External-Dependencies">
      <value value="1"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Simulation-Type">
      <value value="&quot;Hill climb: One Egoist&quot;"/>
      <value value="&quot;Hill climb: One Altruist&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Variables-Colour">
      <value value="&quot;Changing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Change-Threshold">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Opt-One" repetitions="2000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 200</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>count variables</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>median-fitness</metric>
    <metric>stdev-fitness</metric>
    <metric>num-unstable</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Variables-Per-Agent">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Internal-Dependencies">
      <value value="1"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C-External-Dependencies">
      <value value="3"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Simulation-Type">
      <value value="&quot;Optimise: One Egoist&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Variables-Colour">
      <value value="&quot;Changing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Change-Threshold">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-HC-Paral" repetitions="200" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 1600</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>count variables</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>median-fitness</metric>
    <metric>stdev-fitness</metric>
    <metric>num-unstable</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Variables-Per-Agent">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Internal-Dependencies">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C-External-Dependencies">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Simulation-Type">
      <value value="&quot;Hill climb: Egoists in parallel&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Variables-Colour">
      <value value="&quot;Changing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Change-Threshold">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-VarC-K0" repetitions="200" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 2000</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>count variables</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>median-fitness</metric>
    <metric>stdev-fitness</metric>
    <metric>num-unstable</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Variables-Per-Agent">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Internal-Dependencies">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="C-External-Dependencies" first="0" step="1" last="9"/>
    <enumeratedValueSet variable="Simulation-Type">
      <value value="&quot;Hill climb: One Egoist&quot;"/>
      <value value="&quot;Hill climb: One Altruist&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Variables-Colour">
      <value value="&quot;Changing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Change-Threshold">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

input
4.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 0 225
Line -7500403 true 150 150 300 225

@#$#@#$#@
0
@#$#@#$#@
