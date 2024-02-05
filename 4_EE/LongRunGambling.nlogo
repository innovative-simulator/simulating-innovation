;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Long-run gambling
; A replication of Thorngate & Tavakoli (2005)
; This version (C) Christopher Watts, 2014. See Info tab for terms & conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extensions [array]

globals [
  payoff
  num-players
  np-evol
]

breed [agents agent]

agents-own [
  wealth
  survived
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  create-agents number-of-gamblers [
    set hidden? true
    set wealth initial-funds
    set survived 0
  ]
  set payoff expected-payoff * 100 / chance-of-winning
  set np-evol array:from-list n-values (max-ticks + 1) [0]
  array:set np-evol 0 number-of-gamblers
  set num-players number-of-gamblers
  
  update-all-plots
end

to update-all-plots
  set-current-plot "Survival"
  plotxy ticks num-players

  set-current-plot "Histogram"
  clear-plot
  set-plot-x-range 0 (1 + max [wealth] of agents)
  set-histogram-num-bars 6
  if num-players > 0 [
    histogram [wealth] of agents with [wealth > 0]
;    histogram [wealth] of agents 
  ]
  
  set-current-plot "Wealth"
  set-current-plot-pen "Max"
  plotxy ticks (max [wealth] of agents)
  set-current-plot-pen "Mean"
  plotxy ticks (mean [wealth] of agents)
  set-current-plot-pen "Median"
  plotxy ticks (median [wealth] of agents)
  set-current-plot-pen "Min"
  plotxy ticks (min [wealth] of agents)
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if ticks >= max-ticks [stop]
  
  set num-players 0
  ask agents with [wealth > 0] [
    set num-players num-players + 1
    set survived survived + 1
    set wealth wealth - ante
    if chance-of-winning > random-float 100 [
      set wealth wealth + payoff
    ]
  ]
  
  array:set np-evol ticks num-players
  tick
  
  update-all-plots
  
  array:set np-evol ticks num-players
  
  if num-players = 0 [stop]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
7
413
252
612
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
7
69
162
129
Number-Of-Gamblers
1000
1
0
Number

SLIDER
7
134
204
167
Chance-of-Winning
Chance-of-Winning
5
100
50
5
1
%
HORIZONTAL

INPUTBOX
7
194
162
254
Expected-Payoff
3
1
0
Number

INPUTBOX
7
257
162
317
Ante
4
1
0
Number

INPUTBOX
181
69
336
129
Initial-Funds
12
1
0
Number

MONITOR
166
194
281
247
Payoff
expected-payoff  * 100 / chance-of-winning
3
1
13

BUTTON
173
322
237
355
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
240
322
303
355
Play
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
421
63
718
213
Survival
Round
# Players
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

TEXTBOX
10
12
205
35
Long-Run Gambling
20
0.0
1

TEXTBOX
215
10
689
58
After Thorngate & Tavakoli (2005) \"In the long run: Biological versus economic rationality\". Simulation & Gaming, 36(1), 9-26, DOI: 10.1177/1046878104270471
13
0.0
1

MONITOR
421
217
496
270
# Players
num-players
17
1
13

MONITOR
500
217
602
270
Max # Played
max [survived] of agents
17
1
13

MONITOR
166
257
281
310
Expected Value
expected-payoff - ante
3
1
13

INPUTBOX
7
320
162
380
Max-ticks
1000
1
0
Number

MONITOR
420
293
482
346
# at 10
array:item np-evol 10
17
1
13

MONITOR
618
293
688
346
# at 100
array:item np-evol 100
17
1
13

MONITOR
692
292
770
345
# at 1000
array:item np-evol 1000
17
1
13

TEXTBOX
419
275
569
293
Numbers Surviving:
13
0.0
1

MONITOR
486
293
548
346
# at 20
array:item np-evol 20
17
1
13

MONITOR
553
293
615
346
# at 40
array:item np-evol 40
17
1
13

MONITOR
606
216
717
269
Mean # Played
mean [survived] of agents
1
1
13

TEXTBOX
289
194
418
256
Expected Payoff = Payoff * Chance-of-Winning
13
0.0
1

TEXTBOX
285
257
435
289
Expected Value = Expected Payoff - Ante
13
0.0
1

TEXTBOX
174
363
373
395
If all players run out of money, game ends.
13
0.0
1

PLOT
420
374
620
524
Histogram
Wealth
# Players
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
307
322
403
355
Play 1 Round
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
624
375
947
577
Wealth
Round
Money
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Max" 1.0 0 -13840069 true "" ""
"Median" 1.0 0 -11033397 true "" ""
"Mean" 1.0 0 -16777216 true "" ""
"Min" 1.0 0 -2674135 true "" ""

@#$#@#$#@
# LONG-RUN GAMBLING

Replication in NetLogo of the model described in Thorngate & Tavakoli (2005).  
This version (C) Christopher J Watts, 2014. See below for our terms and conditions of use.

This simulation examines: 

> "how long hypothetical gamblers could continue gambling without going broke in different games of chance. Gamblers began with a fixed amount of money and paid a fixed ante to play each game. Games had equal expected value but varied in their probability of winning and amount won. When the expected value was zero or positive, gamblers playing low ante, low-risk games (high chances of small wins) had longer runs than did gamblers playing high ante, high-risk games (low chances of big wins). When the expected value was negative, gamblers playing high-risk games had longer runs than gamblers playing low-risk games. The results extend Slobodkin and Rapoport's [1974] concept of biological rationality and explain why people with limited wealth are wise to avoid risks in winning situations and take risks in losing situations, a central principle of prospect theory."  
> Thorngate & Tavakoli (2005) Abstract

This program was developed for chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## HOW TO USE IT

A given number of agents are going to play a gambling game. Each round, each player wins a payoff if lucky, and gets no payoff. To play the round, however, each player has to pay an "ante" first. Players start the game with a limited amount of wealth. If a player runs out of money, they cannot pay the ante anymore and exit the game.

Several parameters are needed to define the game.

* Initial-Funds: How much money a player has at the start of the game.
* Chance-of-Winning: The chance of winning a payoff during one round of the game.
* Expected-Payoff: There is 0 payoff for losing, so expected payoff = payoff for winning * chance-of-winning.
* Ante: How much each player must pay in order to play the game for one round.
* Max-ticks: A limit on the number of rounds a game can last. However, most games will end before this, when all the players have run out of money.

The __expected value__ to a player of playing one round is the expected payoff - the ante. Depending on the parameter values this could be positive, zero or negative.

Each round (tick), charts are updated with the number of players surviving that far (i.e. still with wealth > 0), the distribution of wealth among surviving players, and the max, mean, median and min wealth among players.


## THINGS TO TRY

Keep Ante and Chance-of-Winning fixed. Then test three different values of Expected-Payoff: one giving positive expected value, one 0 expected value and one negative expected value of playing the game.

Try different values for Chance-of-Winning. Although the expected payoff and expected value of playing one round are being held constant, the number of rounds a player can expect to play will vary with chance-of-winning, as does the expected amount to gain or lose from playing the game. 


## THINGS TO NOTICE

This program demonstrates a difference between economists' and biologists' conceptions of rationality. According to economists' game theory, a rational agent should be indifferent between two games equal in expected value per round. Biologists focus attention on survival, however. A player (or species) seeking to maximise survival may express a preference between these two games, if they offer different values for the number of rounds expected to be played before a player runs out of money, and if they offer different chances of surviving a given number of rounds.

This also demonstrates the importance of considering variation in outcomes, not just average outcome. Even if the expected value is positive, by random chance some players may lose enough times to spend all their limited initial funds on antes, and thus hit the terminating state (exiting the game because wealth has hit 0). If they could continue to play, they would expect to win some rounds as well. But the terminating state means this cannot happen.


## CREDITS AND REFERENCES

Thorngate & Tavakoli (2005) "In the long run: Biological versus economic rationality". Simulation & Gaming, 36(1), 9-26, DOI: 10.1177/1046878104270471

Slobodkin, L. B., & Rapoport, A. (1974). "An Optimal Strategy of Evolution." The Quarterly Review of Biology, 49(3), 181-200. doi: 10.2307/2822820


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
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>expected-payoff - ante</metric>
    <metric>payoff</metric>
    <metric>num-players</metric>
    <metric>array:item np-evol 10</metric>
    <metric>array:item np-evol 20</metric>
    <metric>array:item np-evol 40</metric>
    <metric>array:item np-evol 100</metric>
    <metric>array:item np-evol 1000</metric>
    <metric>mean [survived] of agents</metric>
    <metric>max [survived] of agents</metric>
    <metric>median [survived] of agents</metric>
    <metric>min [survived] of agents</metric>
    <metric>standard-deviation [survived] of agents</metric>
    <enumeratedValueSet variable="Number-Of-Gamblers">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ante">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Expected-Payoff">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Chance-of-Winning" first="10" step="10" last="90"/>
    <enumeratedValueSet variable="Initial-Funds">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="1000"/>
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
