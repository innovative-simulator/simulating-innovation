;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Kauffman's NK Fitness Landscapes
;; Solution space represented by turtles in a network.
;; This prgoram (C) Christopher J Watts, 2015. See Info tab for terms and conditions of use.
;; Based on:
;; Kauffman, S (1993) "The Origins of Order"
;; Kauffman, S (1995) "At Home in the Universe"
;; Kauffman, S (2000) "Investigations"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extensions [array]

globals [
  mean-fitness
  max-fitness
  initial-mean-fitness
  initial-max-fitness
  
  mean-solution
  max-solution
  num-max-agents
  
  input-sets
  fitness-tables
  
  order-statistic
  ordered-list
  
  color-scheme
  num-colors
  
  prev-rng-seed ; Latest seed number for random number generation
  
]

breed [solutions solution]
breed [agents agent]
undirected-link-breed [slinks slink] ; links to similar solutions

solutions-own [
  fitness
  bits
  Combin
  f-rank ; rank based on fitness
  num-superior ; # superior neighbors
]

agents-own [
  fitness
  cur-solution
  prev-solution
  prev-fitness
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  
  ask patches [set pcolor white]
  
  setup-rng
  
  setup-nk
  
  set color-scheme array:from-list (list red orange green sky violet magenta pink yellow lime cyan blue )
  set num-colors length array:to-list color-scheme
    
  create-solutions (2 ^ n-nodes) [
    setxy random-xcor random-ycor
    set color red
    set size 2
    ;set shape "circle"
    set label-color black
    set bits array:from-list n-values n-nodes [0]
  ]
  set ordered-list sort solutions
  let cur-bit 0
  let cur-combin 0
  foreach ordered-list [
    ask ? [
      set cur-bit 0
      repeat n-nodes [
        if ((int (cur-combin / (2 ^ cur-bit))) mod 2) = 1 [
          array:set bits cur-bit 1
        ]
        set cur-bit 1 + cur-bit
      ]
      
      calc-solution-fitness
      set combin cur-combin
    ]
    set cur-combin 1 + cur-combin
  ]
  
  foreach ordered-list [
    ask ? [
      create-slinks-with solutions with [1 = hamming-distance myself] 
    ]
    set cur-combin 1 + cur-combin
  ]
  
  set mean-solution mean [fitness] of solutions
  set max-solution max [fitness] of solutions
  
  set ordered-list sort-by [([fitness] of ?1) > ([fitness] of ?2)] solutions  
  let cur-rank 1
  foreach ordered-list [
    ask ? [ 
      set f-rank cur-rank
      set num-superior (count slink-neighbors with [fitness > ([fitness] of myself)])
      set color array:item color-scheme num-superior
      if num-superior = 0 [set shape "circle"]
      ;set color array:item color-scheme (int (f-rank / 5))
    ]
    set cur-rank 1 + cur-rank
  ]
  
  ;relocate-spring
  relocate-radial
  
  reorientate-solutions
  my-setup-plots
  
end

to-report hamming-distance [alter]
  report sum (map [ifelse-value (?1 = ?2) [0] [1]] (array:to-list bits) ([array:to-list bits] of alter))
end

to setup-rng
  set prev-rng-seed (ifelse-value (rng-seed = 0) [new-seed] [rng-seed])
  random-seed prev-rng-seed
end

to print-rng-seed
  print ""
  print (word "Current RNG Seed: " prev-rng-seed)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Location

to relocate-spring
  repeat 100 [layout-spring solutions slinks 0.2 5 1]
end 

to relocate-radial
  layout-radial solutions slinks (one-of solutions with [f-rank = 1])
end

to relocate-tutte
  layout-tutte (solutions with [f-rank = 1]) slinks 10
end

to relocate-enlarge-x
  ask solutions [
    set xcor ifelse-value ((1.05 * xcor <= max-pxcor) and (1.05 * xcor >= min-pxcor)) [1.05 * xcor] [xcor]
  ]
end

to relocate-enlarge-y
  ask solutions [
    set ycor ifelse-value ((1.05 * ycor <= max-pycor) and (1.05 * ycor >= min-pycor)) [1.05 * ycor] [ycor]
  ]
end

to relocate-shrink-x
  ask solutions [
    set xcor xcor / 1.05
  ]
end

to relocate-shrink-y
  ask solutions [
    set ycor ycor / 1.05
  ]
end

to relocate-up
  ask solutions [
    if (ycor + 0.5 <= max-pycor) [set ycor ycor + 0.5]
  ]
end

to relocate-down
  ask solutions [
    if (ycor - 0.5 >= min-pycor) [set ycor ycor - 0.5]
  ]
end

to relocate-left
  ask solutions [
    if (xcor - 0.5 >= min-pxcor) [set xcor xcor - 0.5]
  ]
end

to relocate-right
  ask solutions [
    if (xcor + 0.5 <= max-pxcor) [set xcor xcor + 0.5]
  ]
end


to reorientate-solutions
  ask solutions [
    face one-of slink-neighbors with-max [fitness]
  ]

end

to relocate-rotate-90
  ask solutions [
    setxy ycor (-1 * xcor)
  ]
    
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NK fitness defined

to setup-NK
  ; Define input nodes for each node
  set input-sets array:from-list n-values n-nodes [array:from-list (fput 0 (sort sublist (shuffle n-values (n-nodes - 1) [?]) 0 k-inputs)) ] ; New version. Guarantees K unique input nodes.
  let cur-node 0
  let cur-input 0
  let input-set 0
  repeat n-nodes [
    set input-set array:item input-sets cur-node
    set cur-input 0
    array:set input-set 0 cur-node ; Each node is an input to itself
    repeat k-inputs [ ; Each node has K inputs which are not itself
      set cur-input cur-input + 1
      if (array:item input-set cur-input) >= cur-node [array:set input-set cur-input ((array:item input-set cur-input) + 1)]
    ]
    set cur-node cur-node + 1
  ]
  
  ; Define fitness table for each node
  set fitness-tables array:from-list n-values n-nodes [array:from-list n-values (2 ^ (k-inputs + 1)) [random-float 1]]
end

to calc-solution-fitness
  let fitness-sum 0
  let cur-node 0
  repeat n-nodes [
    set fitness-sum fitness-sum + 
      array:item (array:item fitness-tables cur-node) (sum n-values (k-inputs + 1) [(array:item bits (array:item (array:item input-sets cur-node) ?)) * (2 ^ ?)])
    
    set cur-node cur-node + 1
  ]
  
  set fitness (fitness-sum / n-nodes)
  ;set fitness ((fitness-sum / n-nodes) / base-max-fitness) ^ 8 ; Lazer & Friedman's definition
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Search agents

to setup-agents
  reset-ticks
  ask agents [die]
  create-agents number-of-agents [
    set shape "person"
    set color black
    set size 1.5
    set cur-solution one-of solutions
    set prev-solution cur-solution
    set fitness [fitness] of cur-solution
    set prev-fitness [fitness] of prev-solution
    move-to cur-solution
  ]
  set mean-fitness mean [fitness] of agents
  set max-fitness max [fitness] of agents
  set initial-mean-fitness mean-fitness
  set initial-max-fitness max-fitness
  set num-max-agents count agents with [fitness = max-solution]
  my-setup-plots
end

to go
  tick
  let temperature 10 ^ log-temperature
  ask agents [
    set cur-solution ([one-of slink-neighbors] of cur-solution)
    move-to cur-solution
    set fitness ([fitness] of cur-solution)
    ifelse fitness < prev-fitness [
      ifelse (random-float 1) < (exp ((fitness - prev-fitness) / temperature)) [
        set prev-solution cur-solution 
        set prev-fitness fitness 
      ]
      [
        set cur-solution prev-solution
        set fitness prev-fitness
        move-to prev-solution
      ]
    ]
    [
      set prev-solution cur-solution 
      set prev-fitness fitness 
    ]
  ]
  set mean-fitness mean [fitness] of agents
  set max-fitness max [fitness] of agents
  set num-max-agents count agents with [fitness = max-solution]
  
  my-update-plots
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Plots

to my-setup-plots
  set-current-plot "Solution Histogram"
  set-plot-pen-interval 0.05
  histogram [fitness] of solutions

  set-current-plot "Superior Neighbours"
  set-plot-x-range 0 n-nodes
  histogram [num-superior] of solutions

  set-current-plot "Agent Histogram"
  set-plot-pen-interval 0.05
  histogram [fitness] of agents

end

to my-update-plots
  set-current-plot "Solution Histogram"
  set-plot-pen-interval 0.05
  histogram [fitness] of solutions

  set-current-plot "Superior Neighbours"
  set-plot-x-range 0 n-nodes
  histogram [num-superior] of solutions

  set-current-plot "Agent Histogram"
  set-plot-pen-interval 0.05
  histogram [fitness] of solutions
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Output fitness definition

to print-nk
  let cur-item 0
  
  print ""
  print "Input Sets: "
  foreach array:to-list input-sets [
    print (word "Bit " cur-item ": " (array:to-list ?))
    set cur-item 1 + cur-item
  ]
  
  print ""
  print "Fitness Tables: "
  
  set cur-item 0
  foreach array:to-list fitness-tables [
    print (word "Bit " cur-item ": " (array:to-list ?))
    set cur-item 1 + cur-item
  ]
end

to print-solutions
  print ""
  print "Solutions: "
  foreach sort solutions [
    ask ? [
      show (word (array:to-list bits) " : " fitness)
    ]
  ]
  print ""
  
end
@#$#@#$#@
GRAPHICS-WINDOW
213
10
652
470
16
16
13.0
1
12
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
8
120
180
153
K-inputs
K-inputs
0
9
1
1
1
NIL
HORIZONTAL

SLIDER
8
84
180
117
N-nodes
N-nodes
1
10
4
1
1
NIL
HORIZONTAL

BUTTON
114
164
178
197
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

MONITOR
666
281
746
326
Agent Mean
mean-fitness
3
1
11

MONITOR
749
281
822
326
Agent Max
max-fitness
3
1
11

PLOT
665
35
865
185
Solution Histogram
Fitness
# Solutions
0.0
1.1
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

TEXTBOX
11
4
182
70
Kauffman's NK Fitness Landscapes
18
0.0
1

TEXTBOX
666
329
816
347
Initial Values:
11
0.0
1

MONITOR
665
347
745
392
Agent Mean
initial-mean-fitness
3
1
11

MONITOR
748
347
821
392
Agent Max
initial-max-fitness
3
1
11

MONITOR
666
419
746
464
Agent Mean
100 * ((mean-fitness / initial-mean-fitness) - 1)
1
1
11

TEXTBOX
670
400
820
418
% Improvement:
11
0.0
1

MONITOR
749
419
822
464
Agent Max
100 * ((max-fitness / initial-max-fitness) - 1)
1
1
11

BUTTON
665
466
812
499
Print Agents' Best
print (word \"Current best: \" (array:to-list ([bits] of one-of solutions with [fitness = max-fitness])))\n
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
8
158
108
203
# Combinations
2 ^ n-nodes
17
1
11

BUTTON
17
555
105
588
Label Solution
ask solutions [ set label array:to-list bits ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
108
555
196
588
Label Fitness
ask solutions [ set label (word (precision fitness 3) \"     \") ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
17
519
105
552
Labels Off
ask solutions [ set label \"\" ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
107
519
196
552
Label Who
ask solutions [ set label who ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
53
243
119
276
Spring
layout-spring solutions slinks 0.2 5 1
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
17
591
105
624
Label Rank
ask solutions [ set label f-rank ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
451
167
484
Face Best Neighbour
reorientate-solutions
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
868
35
1068
185
Superior Neighbours
# Neighbours
# Solutions
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

BUTTON
122
243
187
276
Radial
relocate-radial
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
38
357
121
390
Enlarge X
relocate-enlarge-x
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
38
393
113
426
Shrink X
relocate-shrink-x
NIL
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
282
134
315
Up
relocate-up
NIL
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
316
134
349
Down
relocate-down
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
316
69
349
Left
relocate-left
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
136
316
199
349
Right
relocate-right
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
253
529
425
562
Number-Of-Agents
Number-Of-Agents
0
20
20
1
1
NIL
HORIZONTAL

BUTTON
359
576
465
609
Setup Agents
setup-agents
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
511
576
574
609
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
577
576
640
609
Step
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

BUTTON
360
612
463
645
Clear Agents
ask agents [die]\nmy-setup-plots
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
482
528
654
561
Log-Temperature
Log-Temperature
-4
4
-4
0.5
1
NIL
HORIZONTAL

MONITOR
656
528
741
573
Temperature
10 ^ log-temperature
6
1
11

MONITOR
665
190
755
235
Solution Mean
precision mean-solution 3
17
1
11

MONITOR
760
190
843
235
Solution Max
precision max-solution 3
17
1
11

MONITOR
833
419
1002
464
# Agents at Global Optimum
num-max-agents
17
1
11

PLOT
868
255
1069
413
Agent Histogram
Agent Fitness
# Agents
0.0
1.1
0.0
1.0
true
false
"" ""
PENS
"default" 0.05 1 -16777216 true "" ""

BUTTON
136
282
199
315
Rotate 90
relocate-rotate-90
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
357
205
390
Enlarge Y
relocate-enlarge-y
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
393
197
426
Shrink Y
relocate-shrink-y
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
21
671
176
731
RNG-Seed
0
1
0
Number

BUTTON
179
671
267
704
Print Seed
print-rng-seed
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
108
591
203
626
Label SolFit
ask solutions [ set label (word (precision fitness 3) \" \" (array:to-list bits)) ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
826
530
957
563
Print NK Definition
print-nk
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
828
569
954
602
Print Solutions
print-solutions
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
10
61
208
79
Landscape Definition:
16
0.0
1

TEXTBOX
8
219
158
239
Solutions Net:
16
0.0
1

TEXTBOX
6
242
156
260
Layout:
13
0.0
1

TEXTBOX
5
285
155
303
Position:
13
0.0
1

TEXTBOX
7
360
157
378
Size:
13
0.0
1

TEXTBOX
7
432
157
450
Solution Nodes:
13
0.0
1

TEXTBOX
15
642
255
663
Random Number Generation:
16
0.0
1

TEXTBOX
24
740
285
839
Set to 0 to generate a new seed each time.\nSet to any other number to generate the same sequence of random numbers each time, and thus repeat a simulation run.\nPress button to print last seed number used.
13
0.0
1

TEXTBOX
5
496
155
514
Labels:
13
0.0
1

TEXTBOX
255
485
405
505
Simulate Search:
16
0.0
1

TEXTBOX
253
508
403
526
Setup search agents:
13
0.0
1

TEXTBOX
487
506
637
524
Search:
13
0.0
1

TEXTBOX
668
253
818
273
Search Results:
16
0.0
1

TEXTBOX
668
10
875
30
Solutions' Properties:
16
0.0
1

BUTTON
115
201
207
234
Setup Agents
Setup-Agents
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# Stuart Kauffman's NK Fitness Landscapes: An Illustration

NK fitness landscapes are described in Kauffman (1993, 1995, 2000) among other places. They represent a problem in combinatorial optimisation, i.e. searching for the best combination of binary variable values. Search is conducted using heuristic search algorithms, simple rules of thumb intended to find fairly good solutions in a reasonable number of steps, without necessarily finding the best. The difficulty of search posed by a particular landscape can be controlled using a single parameter. 

This is the most basic form of Kauffman's fitness models (so no patches, species, alternative network topologies, phenotypical functions etc.)

This NetLogo program (C) Christopher J Watts, 2015. See below for terms and conditions of use.

The program was developed to accompany chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## DEPICTING A FITNESS LANDSCAPE

An NK model with N bit variables has 2 ^ N possible solutions or distinct combinations of 1s and 0s. Turtles are created to represent these solutions. Links are made between any turtles who differ in solution from each other in 1 and only 1 bit. The network of solution turtles represents the solution space for the NK fitness problem. 

Solutions with no superior neighbours are shown as red circles. Other solutions are shown as arrows pointing at their best neighbour and are coloured according to the number of superior neighbours they have.

Various buttons are available for changing the display of this network of solutions.

## DEPICTING OPTIMISATION

Agent optimisers can be created. These perform a heuristic search through the solution space. The heuristic uses a "temperature" parameter, familiar from simulated annealing, to control the probability of accepting an inferior solution.

## HOW IT WORKS

There are N nodes. Each node has a binary variable, its current state. Each node takes input from K input nodes, plus itself. Each node has a fitness table, listing the contribution it makes to fitness given the current states of all its input nodes, including itself. Input nodes are assigned at randomly uniformly. Tables of fitness contributions are populated from a uniform distribution in the range [0, 1). Given a combination of all N node states, the N contributions can be averaged to compute a single fitness value.

## HOW TO USE IT

"setup-NK" defines the input tables and fitness tables.  
"calc-agent-fitness" calculates for the current agent a fitness value from a given solution. The fitness value is returned in the agent's attribute "fitness". (Though it could have been returned using "report " instead.) The solution is contained in an array called "solution". (Though this could have been a global, instead of being agent-specific.)

"setup" creates a population of solution turtles - one for each possible combination of 1s and 0s. It creates links between all solutions which differ in one and only one bit.

"Setup-Agents" creates a given number of agent optimisers and assigns each to an initial solution.  
"Go" asks all agent optimisers to perform one step of the heuristic search algorithm. Slow the speed of the simulation down to watch them at work.

A high value of "log-temperature" will mean agents move from solution to solution at random, with no preference for fit solutions. A low value will mean they perform a random-walk hill climbing heuristic, and get stuck on an optimum - i.e. a solution that is better than all of its neighbours. For K > 0 it is likely that the solution space contains more than one optimum, and agents may well get stuck on a solution that is not the global optimum, the best in the network.

## THINGS TO TRY

Use BehaviorSpace to find out what values for mean and max fitness you get given different size problems (N) and difficulty levels (controlled by K).

How often does an agent get stuck on a local optimum, i.e. a solution that is better than its neighbours, but is not the global optimum, the best in the network? What is the best setting for temperature to maximise the agent's fitness at the end of a simulation run?

## EXTENDING THE MODEL

Try watching the effect of using different heuristic search algorithms to explore the solution space. E.g. temperature could start high and decay over time, as in simulated annealing. With multiple agents, agents could learn from others by adopting the current best solution held by the agents.

The fitness landscape definition could be extended to offer Kauffman's SNKC model (Kauffman 2000), with S "species", each having N bit variables with K intra-species and C inter-species links per variable. A solution network becomes hard to read even with a relatively small number of bit variables (= S * N), because the number of solution 2^(S*N) goes up fast. SNKC landscapes probably do not become interesting until S * N is higher than this, so we have not bothered to implement SNKC in this program.

## NETLOGO FEATURES

Note how compact the definition and calculation of NK fitness is in NetLogo.

## RELATED MODELS

Boolean constraint satisfaction problems (K-Sat) can also be defined very economically.

NK fitness models have provided the starting point for various simulation models, some of them modifying the basic definition. See for examples: Kauffman et al (2000), Levinthal (e.g. 1997) on strategic decision making, Frenken (various) on technological evolution, Lazer & Friedman (2007) on collective learning, and Watts & Gilbert (2011) on science models.

## CREDITS AND REFERENCES

Kauffman, Stuart (1993) "The Origins of Order: Self-Organization and Selection in Evolution". New York: OUP

Kauffman, Stuart (1995) "At home in the universe: the search for laws of complexity". London: Penguin.

Kauffman, Stuart (2000) "Investigations". Oxford : Oxford University Press

Kauffman, Stuart, Jose Lobo & William G Macready (2000) "Optimal search on a technology landscape". Journal of Economic Behavior & Organization 43 141-166.

An early description of simulated annealing was:

Kirkpatrick, S., Gelatt, C. D., & Vecchi, M. P. (1983). "Optimization by Simulated Annealing." Science, 220(4598), 671-680. doi: 10.1126/science.220.4598.671

## VERSION HISTORY

26-Jun-2015: Corrected setup-nk so that the K interdependencies are always distinct nodes.

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
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="20" runMetricsEveryStep="false">
    <setup>setup
setup-agents</setup>
    <go>go</go>
    <exitCondition>ticks = 20</exitCondition>
    <metric>timer</metric>
    <metric>mean-solution</metric>
    <metric>max-solution</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>num-max-agents</metric>
    <metric>initial-mean-fitness</metric>
    <metric>initial-max-fitness</metric>
    <enumeratedValueSet variable="N-nodes">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-inputs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Log-Temperature">
      <value value="-2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
