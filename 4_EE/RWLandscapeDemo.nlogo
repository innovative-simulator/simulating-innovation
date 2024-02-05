;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Demonstrates the heuristic search method called random-walk hill climbing.
; Also demonstrates the temperature principle in simulated annealing.
; This version (C) Christopher J Watts, 2014.
; See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extensions [array]


globals [
  landscape-coords
  best-y
  best-x
]

turtles-own [
  prev-xcor
  prev-ycor
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  
  ask patches [set pcolor white]
  
  draw-landscape
  
  create-turtles 1 [
    set color red
    let cur-x 12
    setxy cur-x (fitness cur-x)
    setup-walker
  ]

  create-turtles 1 [
    set color blue
    let cur-x 14
    setxy cur-x (fitness cur-x)
    setup-walker
  ]
  update-evol-plot
end

to setup-walker
  set shape "person"
  set size 2
  ;set color 5 + (10 * random 13)
  ;let cur-x int random-xcor
  ;setxy cur-x (fitness cur-x)
  set prev-xcor xcor
  set prev-ycor ycor
end

to draw-landscape
  if landscape = "2 Peaks" [setup-landscape-2peaks]
  if landscape = "Random" [setup-landscape-random]
  set best-y max map [last ?] array:to-list landscape-coords
  set best-x first array:item landscape-coords (position best-y map [last ?] array:to-list landscape-coords) 
  
  create-turtles 1 [
    set pen-size 3.0
    set color green - 2

    pen-up
    setxy (first array:item landscape-coords 0) (last array:item landscape-coords 0)
    pen-down
    foreach but-first array:to-list landscape-coords [
      setxy (first ?) (last ?)
    ]
    die
  ]
end

to setup-landscape-2peaks
  set landscape-coords array:from-list 
   (list [-0.5 5] [5 15] [10 5] [15 5] [25 10] [29.5 5])
end

to setup-landscape-random
  set landscape-coords array:from-list n-values 16 [0]
  let cur-item 0
  let cur-x -0.5
  repeat 16 [
     array:set landscape-coords cur-item (list cur-x (random max-pycor))
     set cur-item 1 + cur-item
     set cur-x 2 + cur-x
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report fitness [given-x]
  let cur-item length filter [(first ?) < given-x] array:to-list landscape-coords
  let x0 first array:item landscape-coords (cur-item - 1)
  let y0 last array:item landscape-coords (cur-item - 1)
  let x1 first array:item landscape-coords cur-item
  let y1 last array:item landscape-coords cur-item
  report y0 + ((y1 - y0) * (given-x - x0) / (x1 - x0))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  tick
  
  ask turtles [
    ifelse ycor < prev-ycor [
      ifelse (random-float 1) < (exp ((ycor - prev-ycor) / (10 ^ log-temperature))) [
        ; Small chance of accepting inferior step.
        trial-new-step
      ]
      [
        ; If unhappy with current position move back.
        setxy prev-xcor prev-ycor
      ]
    ]
    [
      ; If happy, keep current position and try somewhere new.
      trial-new-step
    ]
    ;show (word xcor ", " ycor)
  ]
  update-evol-plot
  
end

to trial-new-step
  set prev-xcor xcor
  set prev-ycor ycor
  let cur-x xcor + ((2 * random 2) - 1)
  while [(cur-x < min-pxcor) or (cur-x >= max-pxcor)] [ ; Keep within the world.
    set cur-x xcor + ((2 * random 2) - 1)
  ]
  setxy cur-x (fitness cur-x)
end

to update-evol-plot
  set-current-plot-pen "Agent 1"
  plotxy ticks ([ycor] of turtle 1)
  set-current-plot-pen "Agent 2"
  plotxy ticks ([ycor] of turtle 2)
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
210
10
610
301
-1
-1
13.0
1
10
1
1
1
0
1
0
1
0
29
0
19
0
0
1
ticks
30.0

BUTTON
12
132
76
165
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
77
167
140
200
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
12
167
75
200
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

TEXTBOX
8
11
203
55
Random-Walk\nHill Climbing Demo
18
0.0
1

CHOOSER
12
85
150
130
Landscape
Landscape
"2 Peaks" "Random"
0

MONITOR
12
206
92
251
Best Fitness
best-y
3
1
11

MONITOR
93
206
193
251
available at x =
best-x
3
1
11

PLOT
614
10
900
196
Evolution
Steps
Fitness
0.0
1.0
0.0
20.0
true
true
"" ""
PENS
"Agent 1" 1.0 0 -2674135 true "" ""
"Agent 2" 1.0 0 -13345367 true "" ""

SLIDER
11
301
183
334
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
12
337
112
390
Temperature
10 ^ log-temperature
6
1
13

TEXTBOX
13
283
163
301
Simulated Annealing:
13
0.0
1

TEXTBOX
9
58
197
77
(C) Christopher Watts, 2014.
13
0.0
1

@#$#@#$#@
# HILL CLIMBING: AN ILLUSTRATION

Random-walk hill climbing is a simple rule of thumb for seeking solutions to problems. Another term for it is trial-and-error experimentation.

This program illustrates the principle of random-walk hill climbing, a heuristic search algorithm. It also includes simulated annealing, a metaheuristic method. The program was developed to produce figures 4.1 and 4.2 in chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## RANDOM-WALK HILL CLIMBING ON A FITNESS LANDSCAPE

Imagine exploring a hilly landscape in thick fog. You would like to find the highest peak in the landscape, but because of the fog, you can see no further than where you are at present. One method for exploring the landscape would be:

    Repeat until tired or bored:
      Take one step in a random direction.
      Did that step take you uphill? If not, then retrace that one step. Otherwise adopt this new position.
    End of repeated step

This will take you up a nearby hill, and in some landscapes (but not all) it will do it in fewer steps than would be involved if you started from one corner of the landscape and visited every position exhaustively. However, the peak you arrive at may not be the largest peak in the landscape. (I.e. it may be a "local optimum" rather than "the global optimum".) Once up this peak, hill-climbing does not offer you the chance of descending to try another peak, and because of the fog you do not know whether there are better peaks anyway.

## SIMULATED ANNEALING

One solution to the problem of local optima would be for a whole team of agents to explore the landscape, each starting from a different position. This would improve the chance that at least one agent finds the best peak, but it leaves it unclear how other agents would get to learn about this success.

Another solution is to accept some, but not all, downhill steps. Simulated annealing is a method for deciding when to do this.

    Repeat until tired or bored:
      Take one step in a random direction.
      Did that step take you uphill?
      If not, then test your luck: 
        If not lucky, retrace that one step. 
        Otherwise adopt this new position.
      Otherwise adopt this new position.
    End of repeated step


## HOW TO USE IT

Choose a landscape to explore: "Random" or "Two Peaks".

Click "Setup". The landscape is drawn and two agents are created to explore it.

Click "Step" to simulate a single step.

Click "Go" to start simulating multiple steps.

A chart shows the agents' heights over time.

If the agents get stuck on a local peak, try using the slider to increase "Log-Temperature". Temperature controls the chance of accepting an inferior position. The higher the temperature (and log-temperature), the greater the chance of acceptance. Also, the greater the inferiority, the smaller the acceptance chance. Playing with the slider, you will soon discover the model's sensitivity to it. A true simulated annealing algorithm will start with high temperature, then gradually reduce it over time.

## EXTENDING THE MODEL

This model is only intended to be a very simple demonstration.

## RELATED MODELS

Heuristic search methods are contained in many systems: e.g. models of biological evolution or genetic algorithms, ant colony optimisation, collective or organisational learning, strategic decision making, scientific publication and technological evolution. See Watts & Gilbert (2014), especially chapters 4 to 7. Kauffman (1995) is another introduction to some of these areas.

## CREDITS AND REFERENCES

This program (C) Christopher J Watts, 2014. See below for terms and conditions of use. 
See Help menu for details "About NetLogo" itself.

As well as our book, an introduction to the concepts of hill climbing and simulated annealing can be found in:

Kauffman, S. A. (1995). "At home in the universe: the search for laws of self-organization and complexity." New York ; Oxford: Oxford University Press.

An early description of simulated annealing was:

Kirkpatrick, S., Gelatt, C. D., & Vecchi, M. P. (1983). "Optimization by Simulated Annealing." Science, 220(4598), 671-680. doi: 10.1126/science.220.4598.671

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
