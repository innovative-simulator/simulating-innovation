;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Model of epistemic landscapes and the division of cognitive labour
; Based on Weisberg & Muldoon (2009)
; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  mean-fitness
  max-fitness
  mean-cfitness
  mean-ffitness
  mean-mfitness
  
  num-signif-visited
  num-visited
  num-high
  eprogress
  tprogress
  
  peaks
  num-found-peak
  
]

breed [agents agent]

agents-own [
  atype
  afitness
  prev-afitness
]

patches-own [
  pfitness
  visited
  not-low
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  set peaks (list (patch 25 25) (patch -5 -5))
  set num-found-peak array:from-list n-values (length peaks) [0]
  set num-signif-visited 0
  set num-visited 0
  
  ask patches [
    set pfitness calculated-fitness pxcor pycor
    set not-low (pfitness > min-pfitness)
    set pcolor scale-color red pfitness 0 0.75
    set visited false
  ]
  
  set num-high count patches with [not-low]
  
  ; Controls
  create-agents number-of-controls [
    set atype 1
    set color green
    setup-given-agent
  ]
  
  ; Mavericks
  create-agents number-of-mavericks [
    set atype 2
    set color pink
    setup-given-agent
  ]
  
  ; Followers
  create-agents number-of-followers [ 
    set atype 3
    set color cyan
    setup-given-agent
  ]
  
  if output-every-tick [
    update
  ]
  
end

to setup-given-agent
  setxy random-xcor random-ycor
  while [[not-low] of patch-here] [
    setxy random-xcor random-ycor
  ]
;  set afitness calculated-fitness xcor ycor 
  set afitness [pfitness] of patch-here
  set prev-afitness 0
;  visit-current-patch
  if leave-trail [pen-down]
end

to-report calculated-fitness [x y]
  let fval (
    (0.75 * exp (- ((0.02 * ((x - 25) ^ 2) ) + (0.01 * (x - 25) * (y - 25)) + (0.02 * ((y - 25) ^ 2)) ) ) ) +
    (0.70 * exp (- ((0.01 * ((x - -5) ^ 2) ) + (0.01 * (x - -5) * (y - -5)) + (0.01 * ((y - -5) ^ 2)) ) ) )
    )
  report ifelse-value (fval >= min-pfitness) [fval] [0]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to recolour-by-fitness
  let max-pfitness max [pfitness] of patches
  
  ask patches [
;    set pcolor scale-color red pfitness 0 max-pfitness
    set pcolor scale-color red pfitness max-pfitness 0
  ]
end

to recolour-by-unvisited
  ask patches [
    set pcolor ifelse-value ((not visited) and not-low) [yellow] [black]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if ticks >= max-ticks [stop]
  
  ask agents [ ; Agents act in a random order, whatever their type.
    if atype = 1 [control-step]
    if atype = 2 [maverick-step]
    if atype = 3 [follower-step]
  ]
  
  tick
  
  if output-every-tick [
    update
  ]
    
  if halt-on-peaks-found? [
    if (not member? 0 (array:to-list num-found-peak)) [
      update
      stop
    ]
  ]
  
  if ticks >= max-ticks [
    update
    stop
  ]
  
end

to update
  set mean-fitness mean [afitness] of agents
  if number-of-controls > 0 [set mean-cfitness (mean [afitness] of (agents with [atype = 1]))]
  if number-of-mavericks > 0 [set mean-mfitness (mean [afitness] of (agents with [atype = 2]))]
  if number-of-followers > 0 [set mean-ffitness (mean [afitness] of (agents with [atype = 3]))]
  set max-fitness max [afitness] of agents
  set eprogress num-signif-visited / num-high
  set tprogress num-visited / (count patches)
  my-update-plots
end

to control-step
  visit-current-patch
  
  ifelse prev-afitness < [pfitness] of patch-here [
    ; Improved
    set prev-afitness [pfitness] of patch-here
    fd 1
  ]
  [
    ifelse prev-afitness = [pfitness] of patch-here [
      ; Equalled
      if 0.02 > random-float 1 [
        ; If feeling lucky, move off in a random direction.
        set prev-afitness [pfitness] of patch-here
        set heading random-float 360
        fd 1
      ]
      ; Otherwise sit quiet.
    ]
    [
      ; Got worse
      back 1
      set heading random-float 360
      set prev-afitness [pfitness] of patch-here
    ]
  ]
  set afitness [pfitness] of patch-here
end

to follower-step
  visit-current-patch
  
  let next-patch max-one-of (neighbors with [visited]) [pfitness]
  ifelse next-patch = nobody [
    ; Everything is unvisited. Head towards a new patch
    set prev-afitness [pfitness] of patch-here
    set heading towards one-of neighbors
    fd 1
  ]
  [
    ifelse ([pfitness] of next-patch) >= ([pfitness] of patch-here) [
      ; There's a better neighbour. Head towards it.
      set prev-afitness [pfitness] of patch-here
      set heading towards next-patch
      fd 1
    ]
    [
      ; There's nowhere better than here. Try going somewhere new.
      set next-patch one-of (neighbors with [not visited]) 
      if next-patch != nobody [
        set prev-afitness [pfitness] of patch-here
        set heading towards next-patch
        fd 1
      ]
    ]
  ]
  set afitness [pfitness] of patch-here
end

to maverick-step
  visit-current-patch
  
  let next-patch nobody
  ifelse ([pfitness] of patch-here) >= prev-afitness [
    set next-patch one-of (neighbors with [not visited])
    ifelse next-patch != nobody [
      ifelse [not visited] of patch-ahead 1 [
        set prev-afitness [pfitness] of patch-here
        fd 1
      ]
      [
        set prev-afitness [pfitness] of patch-here
        set heading towards next-patch
        fd 1
      ]
    ]
    [
      set next-patch one-of (neighbors with [pfitness >= ([[pfitness] of patch-here] of myself)])
      if next-patch != nobody [
        set prev-afitness [pfitness] of patch-here
        set heading towards next-patch
        fd 1
      ]
    ]
  ]
  [
    back 1
    set heading random-float 360
    set prev-afitness [pfitness] of patch-here
  ]
  set afitness [pfitness] of patch-here
end

to visit-current-patch
  ask patch-here [
    if not visited [
      set visited true
      set num-visited num-visited + 1
      if not-low [
        set num-signif-visited num-signif-visited + 1
        
        if member? self peaks [
          let cur-pos position self peaks
          array:set num-found-peak cur-pos (1 + array:item num-found-peak cur-pos)
        ]
      ]
      ;    set pcolor scale-color green pfitness 0 0.75
      ;    set pcolor yellow

    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to my-update-plots
  set-current-plot "Evolution"
  set-current-plot-pen "Mean"
  plotxy ticks mean-fitness
  set-current-plot-pen "Max"
  plotxy ticks max-fitness
  set-current-plot-pen "Progress"
  plotxy ticks eprogress
  
  set-current-plot "Type Means"
  set-current-plot-pen "Controls"
  plotxy ticks mean-cfitness
  set-current-plot-pen "Followers"
  plotxy ticks mean-ffitness
  set-current-plot-pen "Mavericks"
  plotxy ticks mean-mfitness
end
@#$#@#$#@
GRAPHICS-WINDOW
220
51
634
486
50
50
4.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

TEXTBOX
8
10
285
33
Division of Cognitive Labour
20
0.0
1

TEXTBOX
279
10
638
44
After Weisberg & Muldoon (2009).\nThis version (C) Christopher Watts, 2014.
13
0.0
1

SLIDER
7
86
207
119
Number-Of-Followers
Number-Of-Followers
0
500
180
5
1
NIL
HORIZONTAL

SLIDER
7
51
206
84
Number-Of-Controls
Number-Of-Controls
0
500
0
5
1
NIL
HORIZONTAL

SLIDER
8
122
207
155
Number-Of-Mavericks
Number-Of-Mavericks
0
500
20
5
1
NIL
HORIZONTAL

MONITOR
7
206
95
251
% Controls
int (100 * Number-Of-Controls / (number-of-followers + number-of-mavericks + Number-Of-Controls))
1
1
11

MONITOR
100
159
183
204
% Mavericks
int (100 * number-of-mavericks / (number-of-followers + number-of-mavericks + Number-Of-Controls))
1
1
11

MONITOR
100
206
181
251
% Followers
int (100 * number-of-followers / (number-of-followers + number-of-mavericks + Number-Of-Controls))
1
1
11

BUTTON
11
320
75
353
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
7
253
82
313
Max-Ticks
500
1
0
Number

PLOT
646
10
960
160
Evolution
Time (ticks)
Significance
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -13345367 true "" ""
"Max" 1.0 0 -16777216 true "" ""
"Progress" 1.0 0 -2674135 true "" ""

BUTTON
81
320
144
353
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

SWITCH
5
359
122
392
Leave-Trail
Leave-Trail
0
1
-1000

SWITCH
4
396
184
429
Halt-On-Peaks-Found?
Halt-On-Peaks-Found?
1
1
-1000

INPUTBOX
86
253
180
313
Min-PFitness
0.0010
1
0
Number

MONITOR
647
287
748
332
# Found Peak 1
array:item num-found-peak 0
17
1
11

MONITOR
752
287
853
332
# Found Peak 2
array:item num-found-peak 1
17
1
11

MONITOR
647
337
748
382
# High Visited
num-visited
17
1
11

MONITOR
752
337
854
382
# Patches High
num-high
17
1
11

MONITOR
785
192
901
237
Epistemic Progress
eprogress
3
1
11

MONITOR
647
191
704
236
Max
max-fitness
3
1
11

MONITOR
708
191
765
236
Mean
mean-fitness
3
1
11

TEXTBOX
648
168
845
189
Epistemic Significance (Fitness):
13
0.0
1

SWITCH
4
433
167
466
Output-Every-Tick
Output-Every-Tick
0
1
-1000

MONITOR
785
240
901
285
Total Progress
tprogress * (count patches)
3
1
11

MONITOR
7
158
96
203
Total # Agents
(number-of-followers + number-of-mavericks + Number-Of-Controls)
17
1
11

BUTTON
343
493
455
526
Colour by Fitness
recolour-by-fitness
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
220
493
341
526
Colour Unvisited
recolour-by-unvisited
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
647
418
714
463
Controls
mean-cfitness
3
1
11

MONITOR
717
418
782
463
Followers
mean-ffitness
3
1
11

MONITOR
785
418
852
463
Mavericks
mean-mfitness
3
1
11

TEXTBOX
648
397
798
415
Mean Fitness:
13
0.0
1

PLOT
647
469
961
619
Type Means
Time (ticks)
Significance
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Controls" 1.0 0 -10899396 true "" ""
"Followers" 1.0 0 -11221820 true "" ""
"Mavericks" 1.0 0 -2064490 true "" ""

@#$#@#$#@
# EPISTEMIC LANDSCAPES AND THE DIVISION OF COGNITIVE LABOUR

After the model described in Weisberg & Muldoon (2009).

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 5 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

Agents search for better knowledge, represented as positions on a two-dimensional "epistemic landscape". In this example, the landscape has two "peaks". 

There are three types of agent:

* Mavericks: These prefer to head towards positions previously unvisited by other agents.
* Followers: These prefer to head for a position better known to be better than their own.
* Controls: These occasionally try a step in a random direction.

If an agent's move fails to take it to a better position, the agent goes back to where it came from.

Initially the value of any position on the epistemic landscape is unknown, because no one has explored or visited it. Positions that have been visited by at least one agent, become known, and their epistemic ("fitness") values are perceivable to all agents in the local area. The local area is here defined as an agent's patch's NetLogo patch "neighbors".

## HOW TO USE IT

Select numbers of Controls, Followers and Mavericks.  
Click Setup.  
Click Go.

There are two options for stopping the simulation run:  
Run until both peaks have been reached.  
Run until ticks = Max-ticks.

Leave-Trail?: Agents can put their pens down to draw lines showing what paths they have taken.


## THINGS TO NOTICE

Followers can use the paths traced by Mavericks to reach the peaks.


## THINGS TO TRY

Find the best search performance for a given number of agents. How is a population of one type of agents (e.g. followers) affected by the addition of a few agents of another type (e.g. mavericks)?

The experiments listed in BehaviorSpace cover most of the figures in Weisberg & Muldoon (2009).


## RELATED MODELS

Models employing heuristic search of a fitness landscape (models in biology, organisational learning, strategic decision making, science models) or energy landscape (physics).


## CREDITS AND REFERENCES

Weisberg, M., & Muldoon, R. (2009). Epistemic Landscapes and the Division of Cognitive Labor. Philosophy of Science, 76(2), 225-252.


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
  <experiment name="experiment-NumMavericks" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Mavericks">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NumControls" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Mavericks">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NumFollowers" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Mavericks">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-RatioMavFoll" repetitions="20" runMetricsEveryStep="false">
    <setup>set number-of-followers 400 - number-of-mavericks
setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Number-Of-Mavericks" first="0" step="40" last="400"/>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-MavsWithFolls" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="100"/>
      <value value="200"/>
      <value value="300"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Number-Of-Mavericks" first="0" step="5" last="50"/>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NumControls-LongRuns" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count agents</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>mean-cfitness</metric>
    <metric>mean-ffitness</metric>
    <metric>mean-mfitness</metric>
    <metric>eprogress</metric>
    <metric>tprogress</metric>
    <metric>array:to-list num-found-peak</metric>
    <enumeratedValueSet variable="Number-Of-Followers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Controls">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Mavericks">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-PFitness">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Peaks-Found?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Ticks">
      <value value="200"/>
      <value value="500"/>
      <value value="2000"/>
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-Tick">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Leave-Trail">
      <value value="false"/>
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
