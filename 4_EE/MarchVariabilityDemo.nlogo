;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Demonstrates the trade-off between average and variance in performance in a winner-takes-all competition.
; As described in March (1991)
; This version (C) Christopher J Watts, 2014.
; See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


globals [
  Current-Agent
  Competitors
]

breed [agents agent]

agents-own [
  current-value
  param-x
  param-y
  wins
]
 

to setup
  clear-all
  reset-ticks
  
  create-agents 1 [
    set param-x current-x
    set param-y current-y
    set current-agent self
  ]
  
  create-agents number-of-competitors [
    set param-x competitor-x
    set param-y competitor-y
  ]
  
  set competitors agents with [self != current-agent]
  setup-plot
  
end

to setup-plot
  set-current-plot "Trade Off"
  set-plot-x-range min-x max-x 
  set-plot-y-range min-y max-y
  plot-pen-up
  plotxy max-x 0
  plot-pen-down
  plotxy min-x 0
  plot-pen-up
  
end

to reset-agents
  ask current-agent [
    set param-x current-x
    set param-y current-y
    set wins 0
  ]
  
  ask competitors [
    set param-x competitor-x
    set param-y competitor-y
    set wins 0
  ]
end

to simulate-competitions
  let winner nobody
  ask agents [set wins 0]
  repeat number-of-iterations [
    ask agents [
;      set current-value random-normal param-y param-x ; x is standard deviation
      set current-value random-normal param-y (sqrt param-x) ; x is variance
    ]
    set winner max-one-of agents [current-value]
    ask winner [set wins wins + 1]
  ]
end

to estimate-y
  reset-agents
  ask current-agent [
    set param-y min-y
    simulate-competitions
    let low-y-value (wins / number-of-iterations)
    set param-y max-y
    simulate-competitions
    let high-y-value (wins / number-of-iterations)
    y-search-step min-y max-y low-y-value high-y-value 0
    set current-y param-y
  ]
end

to y-search-step [low-y high-y low-y-value high-y-value cur-iteration]
  if cur-iteration = estimate-iterations [ stop ]
  
  let mid-y low-y + ((high-y - low-y) / 2)
  set param-y mid-y
  simulate-competitions
  let mid-y-value (wins / number-of-iterations)
  ifelse mid-y-value >= (1 / (1 + number-of-competitors)) [
    y-search-step low-y mid-y low-y-value mid-y-value (cur-iteration + 1)
  ]
  [
    y-search-step mid-y high-y mid-y-value high-y-value (cur-iteration + 1)
  ]
end


to batch
  setup
  let cur-x min-x
  while [cur-x < (max-x + stepsize-x)] [
    set current-x cur-x
    estimate-y
    update-plot
    set cur-x cur-x + stepsize-x
  ]
end

to update-plot
  set-current-plot "Trade Off"
  set-plot-x-range min-x max-x 
  set-plot-y-range min-y max-y 
  plotxy current-x current-y
  plot-pen-down
  
end
@#$#@#$#@
GRAPHICS-WINDOW
12
347
257
546
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
90
166
150
Number-Of-Competitors
10
1
0
Number

INPUTBOX
11
214
166
274
Competitor-x
1
1
0
Number

INPUTBOX
11
152
166
212
Competitor-y
0
1
0
Number

INPUTBOX
11
275
166
335
Number-Of-Iterations
5000
1
0
Number

INPUTBOX
172
152
327
212
Current-x
2.000000000000001
1
0
Number

INPUTBOX
172
90
327
150
Current-y
-0.5234375
1
0
Number

INPUTBOX
516
90
671
150
Min-x
0
1
0
Number

INPUTBOX
516
152
671
212
Max-x
2
1
0
Number

INPUTBOX
353
90
508
150
Min-y
-4
1
0
Number

INPUTBOX
353
152
508
212
Max-y
4
1
0
Number

INPUTBOX
353
215
508
275
Estimate-Iterations
10
1
0
Number

INPUTBOX
516
215
671
275
Stepsize-x
0.05
1
0
Number

MONITOR
515
316
582
361
# x Steps
1 + ((max-x - min-x) / stepsize-x)
3
1
11

MONITOR
174
291
300
336
Est. Probability Wins
([wins] of current-agent ) / number-of-iterations
3
1
11

BUTTON
174
216
238
249
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
174
255
314
288
Estimate Probability
reset-agents\nsimulate-competitions
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
353
288
442
321
Estimate y
Estimate-y
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
681
90
999
405
Trade Off
Variance
Mean
0.0
1.0
-1.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

BUTTON
588
316
651
349
Batch
batch
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
14
10
458
32
Expected and variable performance: a trade-off
18
0.0
1

TEXTBOX
14
35
467
67
After James March (1991). NetLogo version (C) Christopher Watts, 2014.
13
0.0
1

TEXTBOX
358
55
506
87
Estimate y for given Current-x:
13
0.0
1

TEXTBOX
521
55
690
91
Plot trade-off line for range of values of Current-x:
13
0.0
1

TEXTBOX
178
54
328
86
Estimate chances of winning:
13
0.0
1

TEXTBOX
212
346
376
442
Agents perform by sampling from a Normal distribution with mean = ycor and standard-deviation = xcor.\n
13
0.0
1

TEXTBOX
518
277
668
309
Click \"Batch\" to plot multiple points.
13
0.0
1

@#$#@#$#@
# JAMES MARCH'S DEMO OF THE TRADE-OFF 
# BETWEEN AVERAGE AND VARIANCE IN PERFORMANCE

An illustration of how to trade-off mean performance and variance in performance when trying to come first in a competition. As described by James March (1991), figure 6.

This NetLogo program was developed for chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

(C) Christopher Watts, 2014. See below for terms and conditions of use.

An agent (firm, player etc.) has N competitors in some competition for which performance is normally distributed. Competitors are homogeneous. They all draw their performances from N(0, 1), i.e. a normal distribution with mean = 0 and variance = 1. The one special agent also draws its performances from a normal distribution. If the given agent draws from the same distribution as its competitors, its chance of performing best, or coming first, will be 1 / (N + 1).

To have better chance than its competitors, it could, of course, raise its expected (mean) performance. Less obviously, however, raising its variance in performance will also improve its chances of coming first. Indeed, if a change in behaviour affects both mean and variance, it might even raise its expected performance yet lower its chances of coming first!

## HOW IT WORKS

A competition consists of all N + 1 agents drawing one performance value from their Normal distributions. The one winner is one of the agents with the largest performance value. If the competition is reiterated many times, the proportion of times a particular agent wins provides an estimate for that agent's chances of winning, given their current performance distribution.

Different parameter values for that distribution give different chances of winning.

## HOW TO USE IT

Choose the number of competitors. Click "Setup" to create all agents.

The special agent uses the distribution N(current-y, current-x). Click "Simulate" to return an estimate of its chance of winning, calculated by running competitions for Number-Of-Iterations.

For a given value of current-x (variance), click "Estimate y" to approximate the value of y (mean) at which the chances of winning are 1 / (N + 1). The search for a y value begins with max-y and min-y and recurses, halving the range each iteration for a given number, Estimate-Iterations.

Click Batch to estimate y for values of x from Min-x to Max-x. These are plotted on the chart.

## THINGS TO NOTICE

Sampling from a Normal distribution (random-normal) is time consuming in NetLogo. Try the program with Number-Of-Competitors = 2 initially. Then try larger values. (1000 may take several minutes!)

As the number of compeititors increases, the y-x trade-off line has sharper slope. If you see it kinking at the ends, you may need to increase Max-y and decrease Min-y so as to increase the range over which it searches for y estimates.

## THINGS TO TRY

How many iterations do we need for a sufficiently accurate estimate of the chances of winning or the trade-off line?

## EXTENDING THE MODEL

What if you score a "win" for being in the top 10, or top 10%? 

What if performance follows some distribution other than Normal?

## RELATED MODELS

March (1991) presented the trade-off in a paper describing a model of organisational learning. His point was that learning does not always confer competitive advantage. It can raise a firm's expected performance of some task, but by standardising more and raising reliability, it can also lower variance in performance. Its relative performance in the market depends on both expected performance and variability.

Most papers on organisational or collective learning assume that raising expected performance is always desirable.

## CREDITS AND REFERENCES

March, James G. (1991) "Exploration and Exploitation in Organizational Learning". Organization Science, Vol. 2, No. 1, Special Issue: Organizational Learning: Papers in  
Honor of (and by) James G. March, pp. 71-87.

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
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="false">
    <setup>setup
estimate-y</setup>
    <exitCondition>true</exitCondition>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>current-x</metric>
    <metric>current-y</metric>
    <enumeratedValueSet variable="Number-Of-Competitors">
      <value value="2"/>
      <value value="10"/>
      <value value="100"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Iterations">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Competitor-x">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Competitor-y">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Current-x" first="0" step="0.05" last="2"/>
    <enumeratedValueSet variable="Current-y">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-y">
      <value value="-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-y">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Estimate-Iterations">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-x">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-x">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stepsize-x">
      <value value="0.05"/>
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
