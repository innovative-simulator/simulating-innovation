;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Opinion Dynamics Model after Hegselmann & Krause (2006)
; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  x-step-size
  num-truth-seekers
  num-non-seekers
  truth-deviation
  num-stable
  num-groups
  max-group-size
  
  ; Batch Run stats:
  br-cur-run
  br-ticks
  br-num-truth-seekers
  br-truth-deviation
  br-num-stable
  br-num-groups
  br-max-group-size

  br-num-truth-seekers2
  br-ticks2
  br-truth-deviation2
  br-num-stable2
  br-num-groups2
  br-max-group-size2
]

breed [facts fact] ; Can't call it "truth"
breed [agents agent]

facts-own [
]

agents-own [
  alpha ; Awareness of truth
  next-position
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ;clear-all
  clear-turtles
  clear-patches
  clear-drawing
  clear-all-plots
  clear-output
  
  reset-ticks
  
  set x-step-size (max-pxcor - min-pxcor) / (run-length + 1)
  
  set num-truth-seekers percent-truth-seekers * number-of-agents / 100
  set num-non-seekers number-of-agents - num-truth-seekers
  
  ask patches [set pcolor white]
  
  create-facts 1 [
    set color gray
    setxy 0 initial-truth-ycor
    set heading 90
    pd
    setxy max-pxcor initial-truth-ycor
  ]
  
  create-agents num-truth-seekers [
    set color blue - 1
    setxy 0 random-ycor
    set heading 90
    pd
    set alpha Truth-Preference
  ]
  
  create-agents num-non-seekers [
    set color red + 1
    setxy 0 random-ycor
    set heading 90
    pd
    set alpha 0
  ]
  
  calc-truth-deviation
  calc-num-groups
  update-evol-plots
  set num-stable 0
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  if ticks >= run-length [stop]
  tick
  
  let truth-pos mean [ycor] of facts
  let cur-pos 0
  let social-influence 0
  let cur-sum 0
  let cur-count 0
  ask agents [
    ;set cur-pos ycor
    set social-influence mean [ycor] of agents in-radius confidence-bound
    set next-position ((alpha * truth-pos / 100) + ((100 - alpha) * social-influence / 100))
  ]
  
  set num-stable 0
  ask agents [
    if (abs (ycor - next-position)) <= (very-small-interval / 10) [
      set num-stable 1 + num-stable
    ]
    setxy (xcor + x-step-size) next-position
  ]
  
  calc-truth-deviation
  calc-num-groups
  update-evol-plots
  
  if run-until-stable? [
    if num-stable = number-of-agents [stop]
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-truth-deviation
  let cur-truth mean [ycor] of facts
  set truth-deviation sqrt mean [(ycor - cur-truth) ^ 2] of agents
end

to calc-num-groups
  set max-group-size 0
  set num-groups 0
  let cur-pos -1
  let group-size 0
  foreach sort-by [([ycor] of ?1) <= ([ycor] of ?2)] agents [
    ifelse cur-pos + very-small-interval < [ycor] of ? [
      set cur-pos [ycor] of ?
      set num-groups 1 + num-groups
      if group-size > max-group-size [set max-group-size group-size]
      set group-size 1
    ]
    [
      set group-size 1 + group-size
    ]
  ]
  if group-size > max-group-size [set max-group-size group-size]
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-evol-plots
  set-current-plot "Opinion Groups"
  set-current-plot-pen "# Groups"
  plotxy ticks num-groups
  set-current-plot-pen "Largest Size"
  plotxy ticks max-group-size
  
  set-current-plot "Truth Deviation"
  plotxy ticks truth-deviation
  
  set-current-plot "Stable Agents"
  plotxy ticks num-stable
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to batch-run
  clear-all
  reset-ticks
  set br-cur-run 0
  repeat number-of-repetitions [
    set br-cur-run 1 + br-cur-run
    setup
    go-repeatedly
    collect-batch-run-stats
  ]
end

to go-repeatedly
  let unstable-agents true
  while [(ticks < run-length) and unstable-agents] [
    go
    if run-until-stable? [
      set unstable-agents (num-stable != number-of-agents)
      ;if num-stable = number-of-agents [stop]
    ]
  ]
end

to collect-batch-run-stats
  set br-ticks br-ticks + ticks
  set br-num-truth-seekers br-num-truth-seekers + num-truth-seekers
  set br-truth-deviation br-truth-deviation + truth-deviation 
  set br-num-stable br-num-stable + num-stable
  set br-num-groups br-num-groups + num-groups
  set br-max-group-size br-max-group-size + max-group-size

  set br-ticks2 br-ticks2 + (ticks ^ 2)
  set br-num-truth-seekers2 br-num-truth-seekers2 + (num-truth-seekers ^ 2)
  set br-truth-deviation2 br-truth-deviation2 + (truth-deviation  ^ 2)
  set br-num-stable2 br-num-stable2 + (num-stable ^ 2)
  set br-num-groups2 br-num-groups2 + (num-groups ^ 2)
  set br-max-group-size2 br-max-group-size2 + (max-group-size ^ 2)

end

to output-batch-run-stats
  print "Batch run statistics:"
  print (word "Current run: " br-cur-run)
  if br-cur-run > 0 [
    print ""
    print "Batch Means:"
    print (word "ticks : " (br-ticks / br-cur-run))
    print (word "num-truth-seekers : " (br-num-truth-seekers / br-cur-run))
    print (word "truth-deviation : " (br-truth-deviation / br-cur-run))
    print (word "num-stable : " (br-num-stable / br-cur-run))
    print (word "num-groups : " (br-num-groups / br-cur-run))
    print (word "max-group-size : " (br-max-group-size / br-cur-run))
    print ""
    print "Batch Standard errors:"
    print (word "ticks : " (st-err-calc br-ticks br-ticks2 br-cur-run))
    print (word "num-truth-seekers : " (st-err-calc br-num-truth-seekers br-num-truth-seekers2 br-cur-run))
    print (word "truth-deviation : " (st-err-calc br-truth-deviation br-truth-deviation2 br-cur-run))
    print (word "num-stable : " (st-err-calc br-num-stable br-num-stable2 br-cur-run))
    print (word "num-groups : " (st-err-calc br-num-groups br-num-groups2 br-cur-run))
    print (word "max-group-size : " (st-err-calc br-max-group-size br-max-group-size2 br-cur-run))
  ]
  print ""
  
end

to-report st-err-calc [data-sum data2-sum num-data]
  ; Given sample sum, sum of squares and sample size
  ; Report sample standard error
  report sqrt (((data2-sum - ((data-sum ^ 2) / num-data)) / (num-data - 1)) / num-data)
end
@#$#@#$#@
GRAPHICS-WINDOW
266
10
680
445
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
100
0
100
0
0
1
ticks
30.0

SLIDER
2
77
208
110
Number-Of-Agents
Number-Of-Agents
0
500
100
10
1
NIL
HORIZONTAL

SLIDER
2
156
208
189
Percent-Truth-Seekers
Percent-Truth-Seekers
0
100
10
1
1
NIL
HORIZONTAL

SLIDER
2
113
208
146
Confidence-Bound
Confidence-Bound
0
40
10
1
1
NIL
HORIZONTAL

SLIDER
2
191
208
224
Truth-Preference
Truth-Preference
0
100
10
1
1
NIL
HORIZONTAL

TEXTBOX
5
10
266
76
Hegselmann & Krause's Opinion Dynamics Model (2002; 2006)
18
0.0
1

INPUTBOX
2
272
72
332
Run-Length
200
1
0
Number

BUTTON
8
392
72
425
Setup
Setup
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
141
392
204
425
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
75
392
138
425
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

MONITOR
209
463
309
508
Truth-Deviation
truth-deviation
1
1
11

SLIDER
3
227
208
260
Initial-Truth-Ycor
Initial-Truth-Ycor
0
100
50
5
1
NIL
HORIZONTAL

MONITOR
313
463
411
508
# Truth Seekers
percent-truth-seekers * number-of-agents / 100
1
1
11

SWITCH
76
272
208
305
Run-Until-Stable?
Run-Until-Stable?
0
1
-1000

INPUTBOX
76
309
207
369
Very-Small-Interval
0.0010
1
0
Number

MONITOR
414
464
517
509
# Agents Stable
num-stable
1
1
11

MONITOR
519
464
584
509
# Groups
num-groups
1
1
11

MONITOR
586
464
678
509
Largest Group
max-group-size
1
1
11

PLOT
686
10
1038
216
Opinion Groups
Time (ticks)
Count
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"# Groups" 1.0 0 -16777216 true "" ""
"Largest Size" 1.0 0 -10899396 true "" ""

PLOT
686
218
957
389
Truth Deviation
Time (ticks)
NIL
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
686
392
957
564
Stable Agents
Time (ticks)
Count
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

INPUTBOX
13
560
168
620
Number-Of-Repetitions
20
1
0
Number

TEXTBOX
14
536
261
576
Run a batch of repeated runs:
16
0.0
1

BUTTON
173
561
261
594
Run Batch
batch-run
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
274
539
390
584
Current Batch Run
br-cur-run
1
1
11

BUTTON
174
601
263
634
Print Stats
output-batch-run-stats
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
7
57
263
75
This version (C) Christopher Watts, 2014.
13
0.0
1

@#$#@#$#@
# HEGSELMANN & KRAUSE'S OPINION DYNAMICS MODEL

## WHAT IS IT?

A replication of the opinion dynamics model of Hegselmann & Krause (2006; also 2002).

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 5 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

Rainer Hegselmann describes his work as "computer-aided philosophy" (i.e. computer-aided social epistemology).


## HOW IT WORKS

Agents begin with heterogeneous opinions. Each time step each agent adopts a new opinion, based on an average of the opinions of all agents the agent has confidence in. Confidence is defined as a distance from the agent, known as the "confidence-bound" (called "epsilon" in the paper).

A given percentage of the agents may also seek truth. Truth is defined as a particular position. How much truth-seekers are influenced by the current position of the truth, rather than by the other agents' opinions, is defined by "Truth-Preference" (called "alpha" in the paper).

The simulation continues for a maximum number of time steps, but optionally can be ended early if all agents appear "stable", that is, if no agent is now moving more than 1/10 of a "very-small-interval".

"Truth-Deviation", calculated as the square-root mean squared deviation of agents' opinions from the truth, offers a measure of how close the agents' opinions are to the truth.

A number of opinion groups of agents are identified. Two agents are members of the same group if their opinions are within a "very-small-interval" of each other. The current number of groups and the size of the currently largest group are calculated.


## HOW TO USE IT

Click "Setup", then "Go".

For running experiments, you may like to use the "Run Batch" button. This runs a batch of simulations and calculates for several output metrics the batch mean and standard error. These statistics can either be recorded by BehaviorSpace, or they can be printed to the output window by clicking on the "Print Stats" button.


## THINGS TO NOTICE

Agents converge on a small number of distinct opinions than were present initially.

"num-groups" is set to the number of distinct opinions still present in the population. Two opinions are distinct if the distance between them > "Very-Small-Interval". "max-group-size" is set to the size of the largest group of agents indistinct from each other in opinion.


## THINGS TO TRY

With 0 percent truth-seekers, explore the impact of "confidence-bound" on "num-groups".

For a given number of truth-seekers and a given position for truth, explore the impact of "Truth-Preference" (alpha). What generates the best (lowest) truth-deviation? How does the number of truth-seekers affect this?

How quickly does the model reach a stable state? (Set "Run-Until-Stable" to "on", and "Run-Length" to something quite large, e.g. 4000 ticks.)


## EXTENDING THE MODEL

Bias, networking and different types of agents have all been added to the basic (2002) model. See Rainer Hegselmann, University of Bayreuth, Germany, for details.


## RELATED MODELS

There are several models of opinion dynamics or social influence, including:

* Weisbuch et al. (2001)  
* Axelrod's model of cultural influence (1997a,b)  
* Gilbert's model of academic science structure (1997)
* Models of diffusion or social influence in "social physics"


## CREDITS AND REFERENCES

### Core:

Hegselmann, Rainer and Krause, Ulrich (2006). 'Truth and Cognitive Division of Labour: First Steps Towards a Computer Aided Social Epistemology'. Journal of Artificial Societies and Social Simulation 9(3)10 <http://jasss.soc.surrey.ac.uk/9/3/10.html>. 

Hegselmann, R and Krause, U (2002) Opinion Dynamics and Bounded Confidence � Models, Analysis, and Simulations. Journal of Artificial Societies and Social Simulation (JASSS) vol.5, no. 3 http://jasss.soc.surrey.ac.uk/5/3/2.html. 

### Alternative models:

Axelrod, R. M. (1997a). "The complexity of cooperation : agent-based models of competition and collaboration." Princeton, N.J. ; Chichester: Princeton University Press.

Axelrod, R. M. (1997b). "The dissemination of culture - A model with local convergence and global polarization." Journal of Conflict Resolution, 41(2), 203-226. doi: 10.1177/0022002797041002001

Gilbert, N. (1997). A Simulation of the Structure of Academic Science. Sociological Research Online, 2(2). 

Lehrer, K and Wagner, C G (1981) Rational Consensus in Science and Society. Dordrecht: D. Reidel Publ. Co. 

Weisbuch G, Deffuant G, Amblard F and Nadal J P (2001) Interacting agents and continuous opinion dynamics. http://arXiv.org/pdf/cond-mat/0111494. 


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
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>batch-run</setup>
    <exitCondition>true</exitCondition>
    <metric>timer</metric>
    <metric>br-cur-run</metric>
    <metric>br-ticks / br-cur-run</metric>
    <metric>br-num-truth-seekers / br-cur-run</metric>
    <metric>br-num-stable / br-cur-run</metric>
    <metric>br-num-groups / br-cur-run</metric>
    <metric>br-max-group-size / br-cur-run</metric>
    <metric>br-truth-deviation / br-cur-run</metric>
    <metric>st-err-calc br-ticks br-ticks2 br-cur-run</metric>
    <metric>st-err-calc br-num-truth-seekers br-num-truth-seekers2 br-cur-run</metric>
    <metric>st-err-calc br-num-stable br-num-stable2 br-cur-run</metric>
    <metric>st-err-calc br-num-groups br-num-groups2 br-cur-run</metric>
    <metric>st-err-calc br-max-group-size br-max-group-size2 br-cur-run</metric>
    <metric>st-err-calc br-truth-deviation br-truth-deviation2 br-cur-run</metric>
    <enumeratedValueSet variable="Number-Of-Agents">
      <value value="100"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Confidence-Bound" first="1" step="2" last="40"/>
    <enumeratedValueSet variable="Initial-Truth-Ycor">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percent-Truth-Seekers">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Truth-Preference" first="0" step="5" last="100"/>
    <enumeratedValueSet variable="Run-Until-Stable?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Run-Length">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Very-Small-Interval">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Repetitions">
      <value value="20"/>
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

@#$#@#$#@
0
@#$#@#$#@
