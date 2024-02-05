;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Hypercycle Demo with one container of rules
; Based on Eigen & Schuster (197_), Padgett (1997)
; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extensions [array]

globals [
  rule-type-colours
  type-freqs
  last-type
]

breed [rules rule]

rules-own [
  rule-type
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  set rule-type-colours array:from-list (list red yellow green blue violet brown orange lime sky pink cyan ) 
  set type-freqs array:from-list n-values rule-complexity [0]
  
  create-rules Number-Of-Rules [
    set rule-type random rule-complexity
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
  
  ;specific-example
  
  let cur-type 0
  repeat rule-complexity [
    array:set type-freqs cur-type (count rules with [rule-type = cur-type])
    set cur-type cur-type + 1
  ]
  
  set last-type -1
  
  my-update-plots
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to specific-example
  ; This worked in the main model. Why not here?
  ; Target, Rich, Fixed, Complete net
  create-rules 9 [
    set rule-type 0
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
  create-rules 7 [
    set rule-type 1
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
  create-rules 9 [
    set rule-type 2
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
  create-rules 14 [
    set rule-type 3
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
  create-rules 11 [
    set rule-type 4
    setxy random-xcor random-ycor
    set color array:item rule-type-colours rule-type
  ]
end  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if ticks >= max-ticks [stop]
  
  ask one-of ifelse-value (last-type = -1) [ifelse-value (input-environment = "Poor") [rules with [rule-type = 0]] [rules]] [rules with [last-type = rule-type]] [ ; Select Ego
;  ask one-of rules [ ; Select Ego
    let ego self
    let e-type rule-type
    let a-type ((rule-type + 1) mod rule-complexity)
;    ask one-of other rules with [rule-type != e-type] [ ; Select Alter
    ask one-of other rules [ ; Select Alter
      ifelse a-type = rule-type [ ; Alter is compatible
        set last-type a-type
        let tertius one-of rules
;        let tertius one-of other rules ; Select rule to die. ; T != A: Would this make a difference?
;        while [tertius = ego] [set tertius one-of other rules] ; T != E: Would this make a difference?
        ask tertius [
          array:set type-freqs rule-type (-1 + array:item type-freqs rule-type)
          set rule-type ifelse-value (learning-type = "Source Reproduction") [e-type] [a-type]
          set color array:item rule-type-colours rule-type
          array:set type-freqs rule-type (1 + array:item type-freqs rule-type)
        ]
      ]
      [
        set last-type -1
      ]
    ]
  ]
  
  ;print last-type
  
  tick
  if (0 = ticks mod output-every) [my-update-plots]
  
  if 0 < length filter [? = 0] array:to-list type-freqs [stop] ; Halt when at least one is 0
;  if 1 = length filter [? != 0] array:to-list type-freqs [stop] ; Halt when all but one are 0
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to my-update-plots
  set-current-plot "Rule Type Frequencies"
  clear-plot
  foreach array:to-list type-freqs [
    plot ?
  ]
  
  set-current-plot "Evolution"
  let cur-type 0
  repeat rule-complexity [
    set-current-plot-pen (word cur-type)
    plotxy ticks (array:item type-freqs cur-type)
    set cur-type cur-type + 1
  ]
    
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
461
10
900
470
16
16
13.0
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

SLIDER
12
82
184
115
Rule-Complexity
Rule-Complexity
2
10
5
1
1
NIL
HORIZONTAL

INPUTBOX
12
117
167
177
Number-Of-Rules
200
1
0
Number

PLOT
189
81
389
231
Rule Type Frequencies
Type
Freqiencies
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

BUTTON
11
325
75
358
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
76
325
139
358
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
189
234
449
435
Evolution
Time (ticks)
# Instances
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"0" 1.0 0 -2674135 true "" ""
"1" 1.0 0 -1184463 true "" ""
"2" 1.0 0 -10899396 true "" ""
"3" 1.0 0 -13345367 true "" ""
"4" 1.0 0 -8630108 true "" ""
"5" 1.0 0 -6459832 true "" ""
"6" 1.0 0 -955883 true "" ""
"7" 1.0 0 -13840069 true "" ""
"8" 1.0 0 -11221820 true "" ""
"9" 1.0 0 -2064490 true "" ""

MONITOR
12
179
145
224
# Instances per Type
number-of-rules / rule-complexity
1
1
11

CHOOSER
11
274
175
319
Learning-Type
Learning-Type
"Source Reproduction" "Target Reproduction"
1

TEXTBOX
14
10
357
32
Hypercycles with a single rule container
18
0.0
1

INPUTBOX
11
362
166
422
Max-ticks
100000
1
0
Number

INPUTBOX
11
424
166
484
Output-Every
1
1
0
Number

CHOOSER
12
226
150
271
Input-Environment
Input-Environment
"Poor" "Rich"
1

TEXTBOX
14
37
314
58
This program (C) Christopher Watts, 2014.
13
0.0
1

@#$#@#$#@
# A NON-SPATIAL MODEL OF A HYPERCYCLE

After the work by Eigen & Schuster. See also Hofbauer & Sigmund (1988; 1998), Padgett (1997; Padgett et al. 2003; Padgett & Powell, 2012).

A hypercycle is a cycle of production processes. Eigen proposed the concept as part of a theoretical explanation for the origins of life.

The basic hypercycle is: 0 => 1 => ... => (n-1) => 0  
where n is the number of product types, set here by parameter "Rule-Complexity".

In this model, stocks of the various production processes are contained in a single location. Stocks are adjusted according to how often their member processes have been activated / enacted. If one of the stocks in the cycle were to hit zero, there would be no more copies of that process, and thus the cycle would be broken.

How high can n be without one of the stocks of production processes hitting zero?

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 7 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

A population of rules is created, with each rule being of a random type. The number of types is set by "Rule-Complexity".

Each time step, one rule (ego) is chosen to be the source.  
A second rule (alter) is sampled to be the target.

To be compatible with the source rule, the target rule must be of the next type to that of the source.  
i.e. Compatible IFF (alter's type = (ego's type + 1) mod rule-complexity)

If the target rule is compatible with the source then a copy of one of them will be made, to represent learning by doing.

To keep the total stock of rules constant, a third rule is sampled. Its own rule type is "forgotten", and it acquires the learned rule type. Depending on the Learning-Type option, the learned rule is either that of the source or of the target rule.

The simulation runs until either "max-ticks" time steps have been reached, or at least one rule-type has lost all its instances.

To choose the source at the start of the time step, the simulation may use the target from the previous time step (if that time step resulted in learning), sample any rule of type "0" ("Poor" input-environment) or sample any rule irrespective of type ("Rich" input-environment).


## HOW TO USE IT

Set "Rule-Complexity", "Input-Environment" and "Learning-Type".  
Click "Setup".  
Click "Go".  
Watch the plots.

Try running with different values of "Rule-Complexity". Is there a phase shift?


## THINGS TO NOTICE

Assuming "Rich" input-environment:  
Systems with "Rule-Complexity" n >= 5 are unstable and halt quickly. Those n <= 3 are stochastically stable. Those n = 4 are close to unstable and sometimes halt prematurely.

Assuming "Poor" input-environment:  
Only n <= 3 with source reproduction shows stability.

## RELATED MODELS

John Padgett's Hypercycles models (1997; et al 2003; Padgett & Powell 2012) provide a spatial context.

Stuart Kauffman's (1995) auto-catalytic sets and Walter Fontana's (1992) work on Artifical Chemistry are similar concepts.

Compare also Predator-Prey models.


## CREDITS AND REFERENCES

Eigen, M. (1971). "Selforganization of matter and evolution of biological macromolecules." Naturwissenschaften, 58(10), 465-&. 

Eigen, M. (1979). "The Hypercycle : A Principle of Natural Self-Organization." Berlin: Springer.

Eigen, M., & Schuster, P. (1977). "Hypercycle - Principle of natural self-organization .A. Emergence of hypercycle." Naturwissenschaften, 64(11), 541-565. doi: 10.1007/bf00450633

Eigen, M., & Schuster, P. (1978a). "Hypercycle - Principle of natural self-organization .B. Abstract hypercycle." Naturwissenschaften, 65(1), 7-41. doi: 10.1007/bf00420631

Eigen, M., & Schuster, P. (1978b). "Hypercycle - Principle of natural self-organization .C. Realistic hypercycle." Naturwissenschaften, 65(7), 341-369. doi: 10.1007/bf00439699

Fontana, W. (1992). "Algorithmic Chemistry (Vol. 10)". Reading: Addison-Wesley Publ Co.

Hofbauer, J., & Sigmund, K. (1988). "The theory of evolution and dynamical systems : mathematical aspects of selection." Cambridge: Cambridge University Press.

Hofbauer, J., & Sigmund, K. (1998). "Evolutionary games and population dynamics." Cambridge: Cambridge University Press.

Kauffman, S. A. (1995). "At home in the universe : the search for laws of self-organization and complexity." New York ; Oxford: Oxford University Press.

Padgett, J. F. (1997). "The emergence of simple ecologies of skill: a hypercycle approach to economic organization." In W. B. Arthur, S. N. Durlauf & D. A. Lane (Eds.), "The economy as an evolving complex system II" (pp. xii, 583p). Reading, Mass: Advanced Book Program/Perseus Books.

Padgett, J. F., Lee, D., & Collier, N. (2003). "Economic production as chemistry." Industrial and Corporate Change, 12(4), 843-877. doi: 10.1093/icc/12.4.843

Padgett, J. F., & Powell, W. W. (2012). "The emergence of organizations and markets." Princeton, N.J. ; Oxford: Princeton University Press.


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
  <experiment name="experiment" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>ticks</metric>
    <metric>ifelse-value (ticks &gt;= max-ticks) [1] [0]</metric>
    <metric>mean array:to-list type-freqs</metric>
    <metric>min array:to-list type-freqs</metric>
    <metric>median array:to-list type-freqs</metric>
    <metric>max array:to-list type-freqs</metric>
    <metric>array:to-list type-freqs</metric>
    <enumeratedValueSet variable="Number-Of-Rules">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="Learning-Type">
      <value value="&quot;Egoistic&quot;"/>
      <value value="&quot;Altruistic&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="20000"/>
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
