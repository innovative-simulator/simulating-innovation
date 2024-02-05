;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Using a genetic algorithm to evolve strategies for the Prisoner's Dilemma game.
; Strategies in population evaluated by playing them against each other.
; Inspired by the work of Axelrod (1997, Ch.1).
; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extensions [array matrix]

globals [
  mean-fitness
  max-fitness
  min-fitness
  fitness-values
  
  new-strategies
  player-table
  weights-table
  weights-sum
  e-history
  a-history
  payoff-table
  
  strat-length
  old-strategies
  tmp-strategies
  
  num-in
  num-out
  num-same
  extinctions
  numbers-same
  
  scores
  
  cur-batch-run ; For batch runs
  
  last-seed ; Most recently used random number seed
  
]

breed [players player]

players-own [
  player-id
  fitness
  strategy
  strat-string
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ;clear-all
  clear-all-plots 
  clear-turtles
  clear-patches
  clear-drawing
  clear-links 
  clear-output
  reset-ticks
  
  setup-rng
  
  set e-history array:from-list n-values (memory + game-rounds) [0]
  set a-history array:from-list n-values (memory + game-rounds) [0]
  set payoff-table array:from-list n-values 4 [0]
  array:set payoff-table 3 cooperate-cooperate
  array:set payoff-table 2 cooperate-defect
  array:set payoff-table 1 defect-cooperate
  array:set payoff-table 0 defect-defect
  
  set strat-length (2 * memory + (2 ^ (2 * memory)))
;  set new-strategies array:from-list n-values population-size [array:from-list n-values strat-length [0]]
  set player-table array:from-list n-values population-size [nobody]
  set weights-table array:from-list n-values population-size [0]
  
  create-players population-size [
    set player-id who ; Only turtles, so can use who number straight off.
    set fitness 0
    set strategy array:from-list n-values strat-length [random 2]
    setxy random-xcor random-ycor
  ]
  ask players [calculate-strat-string]
  set old-strategies sort ([strat-string] of players)
  set old-strategies remove-duplicates old-strategies
  
  set scores matrix:from-row-list n-values population-size [n-values population-size [0]]
  
  calculate-all-fitness
  set extinctions []
  set numbers-same []
  set fitness-values []
  
  update-fitness-plots
end

to setup-rng
  set last-seed ifelse-value (rng-seed = 0) [new-seed] [rng-seed]
  random-seed last-seed 
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  tick
  
  calculate-new-strategies
  update-population
  calculate-all-fitness
  my-update-plots
end

to calculate-all-fitness
  ;calculate-all-play-all
  ask players [
    ; play game, calc score
    set fitness calculated-fitness
  ]
  
  set mean-fitness mean [fitness] of players
  set max-fitness max [fitness] of players
  set min-fitness min [fitness] of players
  
end

to-report calculated-fitness
  ; Play 1 game against each of several other, randomly chosen players.
  ; Report mean score.
  report (mean [score-game myself self] of n-of number-of-games other players) / game-rounds
;  report (mean matrix:get-row scores player-id) / game-rounds ; alt version
  
end

to calculate-all-play-all
  let ego-id 0
  ask players [
    set ego-id player-id
    ask other players [
      ;score-game myself self ; alt version
    ]
  ]
end

to-report score-game [ego alter]
;to score-game [ego alter] ; alt version
  ; calculates ego's (and alter's scores in alt version) from playing against each other
  let cur-round 0
  let cur-bit 0
  let cur-e-score 0
  ;let cur-a-score 0 ; alt version
  let e-move 0
  let a-move 0
  let e-outcome 0
  let a-outcome 0
  let e-offset 0
  let a-offset 0
  let steps-back 0
  ;let ego-id [player-id] of ego ; alt version
  ;let alter-id [player-id] of alter ; alt version
  
  repeat memory [
    array:set e-history cur-round ([(array:item strategy cur-bit) + (2 * (array:item strategy (1 + cur-bit)))] of ego)
    array:set a-history cur-round ([(array:item strategy cur-bit) + (2 * (array:item strategy (1 + cur-bit)))] of alter)
    set cur-round cur-round + 1
    set cur-bit cur-bit + 2
  ]
  
  ;matrix:set scores ego-id alter-id 0 ; alt version
  ;matrix:set scores alter-id ego-id 0 ; alt version
  
  repeat game-rounds [
    set e-offset 0
    set a-offset 0
    set steps-back 0
    repeat memory [
      set steps-back steps-back + 1
      set e-offset (4 * e-offset) + (array:item e-history (cur-round - steps-back))
      set a-offset (4 * a-offset) + (array:item a-history (cur-round - steps-back))
    ]
    
    set e-move [array:item strategy ((2 * memory) + e-offset)] of ego
    set a-move [array:item strategy ((2 * memory) + a-offset)] of alter
    set e-outcome (a-move + (2 * e-move))
    set a-outcome (e-move + (2 * a-move))
    set cur-e-score cur-e-score + array:item payoff-table e-outcome
    ;set cur-a-score cur-a-score + array:item payoff-table a-outcome ; alt version
    array:set e-history cur-round e-outcome
    array:set a-history cur-round a-outcome
    
    set cur-round cur-round + 1
  ]
  ;matrix:set scores ego-id alter-id ((matrix:get scores ego-id alter-id) + cur-e-score) ; alt version
  ;matrix:set scores alter-id ego-id ((matrix:get scores alter-id ego-id) + cur-a-score) ; alt version
  report cur-e-score
  
end

to calculate-new-strategies
  let p-item 0
  set weights-sum 0
  ask players [
    array:set player-table p-item self
    array:set weights-table p-item fitness
    set weights-sum weights-sum + fitness
    set p-item p-item + 1
  ]
  
  let ego nobody
  let alter nobody
  let crossed false
  let cur-strat array:from-list n-values strat-length [0]
  
  set new-strategies []
  
  set p-item 0
  let s-item 0
  repeat population-size [
    set ego selected-player
    set alter selected-player
    set s-item 0
    repeat strat-length [
      if (chance-crossover > random-float 1) [set crossed not crossed] ; cross-over?
      array:set cur-strat s-item ifelse-value crossed [[array:item strategy s-item] of alter] [[array:item strategy s-item] of ego]
      if chance-mutation > random-float 1 [ ; mutation?
        array:set cur-strat s-item (1 - array:item cur-strat s-item)
      ]
      set s-item s-item + 1
    ]
    ;array:set new-strategies p-item array:from-list array:to-list cur-strat
    set new-strategies fput (array:from-list array:to-list cur-strat) new-strategies
    set p-item p-item + 1
  ]
end

to update-population
  let p-item 0
  ask players [
;    set strategy array:from-list array:to-list (array:item new-strategies p-item)
    set strategy array:from-list array:to-list (first new-strategies)
    set new-strategies but-first new-strategies
    set p-item p-item + 1
  ]
end

to-report selected-player
  ; sampling of players stratified by fitness
  let cur-sum random-float weights-sum
  let p-item 0
  while [cur-sum > 0] [
    set cur-sum cur-sum - array:item weights-table p-item
    set p-item p-item + 1
  ]
  report array:item player-table (p-item - 1)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calculate-strat-string
  let cur-pos 0
  let cur-str ""
  foreach (array:to-list strategy) [
    if ((cur-pos - (2 * memory)) mod (2 ^ (memory + 1)) = 0) [
      set cur-str (word cur-str "_")
    ]
    set cur-pos cur-pos + 1
    set cur-str (word cur-str (ifelse-value (? = 1) ["C"] ["D"]))
  ]
  set strat-string cur-str
end

to calculate-freq
  ask players [calculate-strat-string]
  set new-strategies sort ([strat-string] of players)
  set new-strategies remove-duplicates new-strategies
  set tmp-strategies map [?] new-strategies
  set num-in 0
  set num-out 0
  set num-same 0
  ; go through two lists of strategies, comparing them
  while [0 < length tmp-strategies] [
    ; if item-old > item-new, item-new is a new addition
    ifelse 0 < length old-strategies [
      ifelse (first old-strategies) > (first tmp-strategies) [
        set num-in num-in + 1
        set tmp-strategies but-first tmp-strategies
      ]
      [
        ; if item-old < item-new, item-old has disappeared
        ifelse (first old-strategies) < (first tmp-strategies) [
          set num-out num-out + 1
          set old-strategies but-first old-strategies
        ]
        [
          set num-same num-same + 1
          set old-strategies but-first old-strategies
          set tmp-strategies but-first tmp-strategies
        ]
      ]
    ]
    [
      set num-in num-in + 1
      set tmp-strategies but-first tmp-strategies
    ]
  ]
  set num-out num-out + length old-strategies
  set old-strategies map [?] new-strategies
  if ticks > output-every [
    set extinctions fput num-out extinctions
    set numbers-same fput num-same numbers-same
    set fitness-values fput mean-fitness fitness-values
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to my-update-plots
  update-fitness-plots
  
  if 0 = ticks mod output-every [
    calculate-freq
    set-current-plot "Strategies"
    set-current-plot-pen "In"
    plotxy ticks num-in
    set-current-plot-pen "Out"
    plotxy ticks num-out
    set-current-plot-pen "Same"
    plotxy ticks num-same
    
    if 0 < length extinctions [
      set-current-plot "Extinctions"
      set-plot-x-range 0 (1 + max extinctions)
      ;set-plot-pen-interval 1
      histogram extinctions
    ]
  ]
  
end

to update-fitness-plots
  set-current-plot "Fitness"
  set-current-plot-pen "Mean"
  plotxy ticks mean-fitness
  set-current-plot-pen "Max"
  plotxy ticks max-fitness
  set-current-plot-pen "Min"
  plotxy ticks min-fitness
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to output-run-to-file
  setup
  let out-filename "GAPD_Output.csv"
  if file-exists? out-filename [file-delete out-filename]
  file-open out-filename
  file-print (word "Ticks, Fitness, Strat-String")
  let cur-gen 0
  repeat number-of-generations [
    go
    if 0 = ticks mod output-every [
      ask players [
        file-print (word ticks ", " fitness ", " strat-string)
      ]
    ]
  ]
  
  file-close
end

to output-batchrun-to-file
  let out-filename "GAPD_BatchOut.csv"
  if file-exists? out-filename [file-delete out-filename]
  file-open out-filename
  file-print (word "Run, Fitness, Strat-String")
  set cur-batch-run 0
  repeat number-of-batch-runs [
    set cur-batch-run cur-batch-run + 1
    setup
    repeat number-of-generations [ go ]
    ask players [
      file-print (word cur-batch-run ", " fitness ", " strat-string)
    ]
  ]
  
  file-close
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
415
575
660
774
16
16
5.1
1
10
1
1
1
0
1
1
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

INPUTBOX
11
109
166
169
Population-Size
80
1
0
Number

INPUTBOX
167
456
322
516
Game-Rounds
15
1
0
Number

SLIDER
10
175
182
208
Memory
Memory
1
3
1
1
1
NIL
HORIZONTAL

INPUTBOX
8
456
163
516
Number-of-Games
19
1
0
Number

INPUTBOX
7
549
162
609
Cooperate-Cooperate
3
1
0
Number

INPUTBOX
165
549
320
609
Cooperate-Defect
0
1
0
Number

INPUTBOX
7
612
162
672
Defect-Cooperate
5
1
0
Number

INPUTBOX
165
612
320
672
Defect-Defect
1
1
0
Number

TEXTBOX
9
523
159
543
Payoff Table:
16
0.0
1

BUTTON
194
107
258
140
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

BUTTON
260
107
323
140
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

PLOT
419
10
729
180
Fitness
Generation (ticks)
Fitness
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -16777216 true "" ""
"Max" 1.0 0 -10899396 true "" ""
"Min" 1.0 0 -2674135 true "" ""

MONITOR
732
10
789
63
Mean
mean-fitness
1
1
13

MONITOR
732
64
789
117
Max
max-fitness
1
1
13

BUTTON
326
107
405
140
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

INPUTBOX
644
421
799
481
Output-Every
80
1
0
Number

PLOT
418
194
767
389
Strategies
Generation (ticks)
# Distinct Strategies
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"In" 1.0 0 -10899396 true "" ""
"Out" 1.0 0 -2674135 true "" ""
"Same" 1.0 0 -16777216 true "" ""

BUTTON
863
294
999
327
Print old-strategies
foreach old-strategies [\nprint ?\n]
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
733
118
790
171
Min
min-fitness
1
1
13

TEXTBOX
15
10
388
45
Evolving Prisoner's Dilemma Strategies
20
0.0
1

TEXTBOX
17
39
289
75
After the work of Axelrod (1997, chapter 1). This program (C) Christopher Watts, 2014.
13
0.0
1

MONITOR
9
329
164
382
Expected # Mutations
population-size * strat-length * chance-mutation
5
1
13

MONITOR
170
329
334
382
Expected # Crossovers
population-size * strat-length * chance-crossover
5
1
13

MONITOR
190
175
324
228
Length of Strategy
(2 * memory) + (2 ^ (2 * memory))
1
1
13

INPUTBOX
9
264
164
324
Chance-Mutation
0.01
1
0
Number

INPUTBOX
170
264
325
324
Chance-Crossover
0.1
1
0
Number

PLOT
418
391
618
541
Extinctions
Size
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
771
225
828
278
# In
num-in
17
1
13

MONITOR
771
281
828
334
# Out
num-out
17
1
13

MONITOR
771
337
837
390
# Same
num-same
17
1
13

BUTTON
863
127
1014
160
Output one run to file
output-run-to-file
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
862
65
1017
125
Number-of-Generations
4000
1
0
Number

INPUTBOX
863
172
982
232
Number-of-Batch-Runs
100
1
0
Number

MONITOR
1007
215
1092
268
Batch Run:
cur-batch-run
17
1
13

BUTTON
863
235
1003
268
Output batch to file
output-batchrun-to-file
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
7
745
162
805
RNG-Seed
0
1
0
Number

BUTTON
8
808
96
841
Print Seed
print \"\"\nprint \"Most recent random number seed:\"\nprint last-seed
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
12
85
162
105
Population design:
16
0.0
1

TEXTBOX
10
431
160
451
Game Design:
16
0.0
1

TEXTBOX
11
238
248
263
Genetic Algorithm Parameters:
16
0.0
1

TEXTBOX
12
717
233
744
Random Number Generation:
16
0.0
1

TEXTBOX
865
15
1082
55
Output data file for analysis in other tools:
16
0.0
1

MONITOR
325
47
415
100
Generation:
ticks
17
1
13

@#$#@#$#@
# APPLYING A GENETIC ALGORITHM TO PRISONER'S DILEMMA STRATEGIES

Robert Axelrod (1997, chapter 1) used genetic algorithms to try to evolve strategies for the Prisoner's Dilemma game. In particular, he sought strategies superior to those submitted to the tournament he co-organised, including the tournament winner, Tit-For-Tat. This model goes beyond his work, however. Whereas Axelrod (1997) evaluates its population of strategies in matches against a fixed set of representative strategies, this program evaluates the current population's strategies in matches against each other. This leads to greater dynamics, since a strategy that performs well in one generation is likely to generate more copies of itself in later generations, but thereby creates opportunities for new strategies to emerge who perform well against the most prevalent strategies, thereby leading to a change in prevalence.

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 7 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

An initial population of strategies is created as random bit strings. "1" denotes "Cooperate". "0" denotes "Defect". Games are played between two players, and consist of a number of consecutive rounds. Moves are chosen on the basis of the strategy, given a number of recent moves in the game ("History"), or, if the game has yet to generate that many previous moves, using some assumptions encoded in the strategy.

The first bits, occurring in pairs, denote the strategy's assumptions concerning previous combinations of moves. Each pair consists of [(Your move),(Your opponent's move)].

The later bits indicate for each combination of historic moves which action the player should take. To retrieve an action, given a combination, look at the nth bit, where:

    n =
      Sum_for_all_rounds_in_history
      (
        (4^((History-Length) - (How long ago round occurred) - 1))
         * ((2 * Your move) + Your opponent's move)
      )

A simple genetic algorithm is used. A new generation of strategies is created by stratified sampling of the current generation's strategies ("roulette-wheel" selection), with a given chance of cross-over occurring between pairs of strategies, and a given chance of mutation also.


## HOW TO USE IT

Choose a population size, and mutation and cross-over chances. Set the number of games and the payoffs. Click "Setup" and "Go". Watch the population mean fitness rise and fall.

Periodically, a census in the form of a frequency distribution can be calculated for distinct strategies. Changes since the previous census can be identified, including number of strategies coming into the population, the number exiting and the number remaining.

A given number of generations can be run and their strategies and fitness values periodically output to file. Click the button "Output run to file" to do this. "Output-Every" determines in time ticks (generations) how often output occurs.


## THINGS TO NOTICE

Under some parameter combinations you may see evidence of punctuated equilibria: long periods in which the strategies are averaging one level of fitness, punctuated by brief periods of change.


## THINGS TO TRY

Find the relations between processes that generate novelty (chance-crossover and chance-mutation) and outputs (mean fitness, diversity).

Explore sensitivity to game rules (payoffs, # rounds, # games etc.)

Try analysing the population dynamics in a single run. Which are the most popular strategies? Which strategies tend to occur with them? Which strategies tend not to occur with them? Which strategies tend to undermine them?


## EXTENDING THE MODEL

Try alternative processes for generating novelty (e.g. alternative versions of crossover).

Try alternative heuristic search methods to genetic algorithms (e.g. cross-entropy method, harmony search).

At present, there are no visual aspects to the model, except for the charts. What could we use the turtles' appearance to represent? Fitness? Number of copies of strategy? Similarity of strategy? Who has just beaten whom, and what the score was?


## RELATED MODELS

Axelrod (1997) evaluates its population of strategies in matches against a fixed set of representative strategies.

Lindgren examined several versions of PD games with evolving strategies, including in spatial contexts. See e.g. Lindgren (1992).


## CREDITS AND REFERENCES

Axelrod, R. M. (1997). "The complexity of cooperation : agent-based models of competition and collaboration." Princeton, N.J. ; Chichester: Princeton University Press.

Lindgren, K. (1992). "Evolutionary phenomena in simple dynamics (Vol. 10)". Reading: Addison-Wesley Publ Co.


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

@#$#@#$#@
0
@#$#@#$#@
