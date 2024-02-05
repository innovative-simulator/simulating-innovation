;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Sandpiles Model
; A demonstration of self-organised criticality
; Based on the theory by Per Bak
; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  cur-location
  edge-patches
  piles
  ava-sizes
  num-changes
  estimated-gradient
]

patches-own [
  pile-height
  edge
]

to setup
  clear-all
  reset-ticks
  
  resize-world 0 (grid-width + 1) 0 (grid-width + 1)
  
  
  ask patches [
    set edge (
      (pxcor = 0) or
      (pxcor = max-pxcor) or
      (pycor = 0) or
      (pycor = max-pycor)
      )
  ]
  
  set edge-patches patches with [edge]
  set piles patches with [not edge]
  
  ask edge-patches [
    set pcolor blue
  ]
  
  ask piles [
    set pile-height 0
    set pcolor scale-color red pile-height 0 critical-height
  ]
  
  set ava-sizes []
  
end

to go
  if entry-method = "Centre patch always" [set cur-location patch (grid-width / 2) (grid-width / 2)]
  if entry-method = "Random patch" [ set cur-location one-of piles]
  
  set num-changes 0
  ask cur-location [
    set pile-height pile-height + 1
    set pcolor scale-color red pile-height 0 critical-height
  ]
  
  while [still-avalanching] []
    
  if num-changes > 0 [
    set ava-sizes fput num-changes ava-sizes
  ]
  
  if ticks mod output-every = 0 [
    if 0 < length ava-sizes [
      clear-plot
      set-plot-x-range 0 log (1 + max ava-sizes) 10
      ;histogram ava-sizes
      draw-loglog-histo sort ava-sizes
      let min-ava-size min ava-sizes
      let sum-logs sum map [ln (? / (min-ava-size - 0.5))] ava-sizes ; Using continuity correction.
      set estimated-gradient 1 + ((length ava-sizes) / sum-logs) ; Max Likelihood Estimate
    ]
  ]
  
  tick
  
end

to-report still-avalanching
  let prev-num-changes num-changes
  let num-in-flux 0
  ask piles [
    if pile-height >= critical-height [
      set num-changes num-changes + 1
      set num-in-flux ifelse-value ((count neighbors4) > pile-height) [pile-height] [(count neighbors4)]
      set pile-height pile-height - num-in-flux
      set pcolor scale-color red pile-height 0 critical-height
      ask neighbors4 [
        if num-in-flux > 0 [
          set num-in-flux num-in-flux - 1
          if not edge [
            set pile-height pile-height + 1
            set pcolor scale-color red pile-height 0 critical-height
          ]
        ]
      ]
    ]
  ]
  report (num-changes > prev-num-changes)
end

to draw-loglog-histo [histolist]
  set-plot-x-range 0 (1 + int max map [log ? 10] histolist)
  let freq 1
  let curval first histolist
  set histolist but-first histolist
  while [0 < length histolist] [
    ifelse curval = first histolist [
      set freq freq + 1
    ]
    [
      if curval > 0 [plotxy (log curval 10) (log freq 10)]
      set freq 1
      set curval first histolist
    ]
    set histolist but-first histolist
  ]
  plotxy (log curval 10) (log freq 10)  
end  
@#$#@#$#@
GRAPHICS-WINDOW
210
10
662
483
-1
-1
13.0
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
33
0
33
0
0
1
ticks
30.0

SLIDER
4
129
176
162
Grid-Width
Grid-Width
1
50
32
1
1
NIL
HORIZONTAL

SLIDER
4
164
176
197
Critical-Height
Critical-Height
1
16
4
1
1
NIL
HORIZONTAL

CHOOSER
4
199
167
244
Entry-Method
Entry-Method
"Centre patch always" "Random patch"
1

TEXTBOX
10
10
160
35
Sandpiles Model
20
0.0
1

TEXTBOX
9
42
205
122
Demonstration of the concept of self-organised criticality (SOC).\nAfter the work by Per Bak (1996).\nThis program (C) Christopher Watts, 2014.
13
0.0
1

BUTTON
4
250
68
283
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

INPUTBOX
6
287
161
347
Output-Every
100
1
0
Number

PLOT
6
352
206
502
Log-Log
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
"default" 1.0 2 -16777216 true "" ""

BUTTON
71
250
134
283
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
6
506
184
559
Est. Powler Law Gradient
estimated-gradient
3
1
13

@#$#@#$#@
# THE SANDPILES MODEL

A demonstration of the concept of self-organised criticality (SOC).

Based on the work by Per Bak, 1996, "How nature works".

A system of piles of sand tends towards self-organised criticality as grains of sand are added over time.

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 7 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.



## HOW IT WORKS

Grains of sand fall onto a table top, forming sand piles where they land. If the place where a grain lands now has a sand pile at critical height, an avalanche is triggered, and grains shift from the pile to neighbouring piles, if these exist, or fall off the edge of the table. If neighbouring piles are now at critical height, the avalanche continues. Avalanches halt when all piles are below critical height. At this point the size of the avalanche, defined at the number of piles that whose height changed, is recorded.


## HOW TO USE IT

Choose the size of the table top. Choose the critical height. Choose whether the grains enter at a single location (the table centre) or at random locations. Click "Setup" and then "Go".


## THINGS TO NOTICE

The log-log plot, showing a frequency distribution for avalanche sizes, with logarithmic scales on both axes, should tend towards a straight line. This is a sign of a scale-free distribution, or power law.


## THINGS TO TRY

Try different values for the critical height.  
Try adding sand at a fixed point.  
Try different sizes of table top.  
Try replacing "Neighbors4" with "Neighbors" in the code. (That is, the table top becomes an 8-neighbour grid, with a Moorean  neighbourhood, instead of a 4-neighbour, von Neumann neighbourhood.)


## EXTENDING THE MODEL

This uses patches to represent the table top. Use turtles instead, and arrange them in a network of links. Different network structures can be constructed. Does SOC appear for every network structure?


## RELATED MODELS

Another model of a system in a critical state is the forest fire model, RepeatedForestFire.nlogo.


## CREDITS AND REFERENCES

Bak, Per (1996) "How nature works: the science of self-organized criticality", New York.

Bak, P., Tang, C., & Wiesenfeld, K. (1987). "Self-organized criticality - an explanation of 1/F noise." Physical Review Letters, 59(4), 381-384. doi: 10.1103/PhysRevLett.59.381


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
