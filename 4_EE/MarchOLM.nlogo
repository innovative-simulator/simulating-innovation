;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; James March's Organisational Learning Model
; Based on March (1991) and on BASIC version (mostly by March) supplied by Simon Rodan (Thanks!)
; This NetLogo version (C) Christopher J Watts, 2014.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;extensions [matrix]


globals [
  reality
  superior-group
  belief-sums
  
  num-bupdates ; # changes made to beliefs
  num-cupdates ; # changes made to codes
  equilibrium ; Are we at equilibrium yet?
  
  num-alt ; # workers with alternative socialization (e.g. fast)
  mean-cscore
  mean-wscore
  mean-cknowledge
  mean-wknowledge
  mean-s-wknowledge
  mean-as-wknowledge
  
  mean-wsocialization
]

breed [workers worker]
breed [orgs org]
directed-link-breed [wlinks wlink] ; x works for y

workers-own [
  beliefs
  w-score
  w-knowledge
  wsocialization
  cur-org
]

orgs-own [
  code
  code-score
  code-knowledge
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  
  set reality n-values number-of-dimensions [(2 * (random 2)) - 1] ; Initialised to 1 or -1
  set superior-group nobody
  set belief-sums n-values number-of-dimensions [0]
  
  ; Setup organizations
  create-orgs number-of-organizations [
    set hidden? true
    set shape "square"
    set code n-values number-of-dimensions [0]
  ]
  
  ; Setup workers
  set num-alt int (number-of-workers * proportion-alt-socialization / 100) ; i.e. # fast socialised
  create-workers num-alt [
    set hidden? true
    set wsocialization alt-socialization
  ]
  create-workers (number-of-workers - num-alt) [ ; i.e. slow or normal socialised
    set hidden? true
    set wsocialization socialization
  ]
  ask workers [
    set shape "person"
    set beliefs n-values number-of-dimensions [(random 3) - 1] ; Initialised to 1, 0 or -1
    set cur-org one-of orgs
    create-wlink-to cur-org [ set hidden? true ]
  ]
  
  set equilibrium false
  set mean-wsocialization mean [wsocialization] of workers
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Order of events in March's version:
  ;For each time period
  ; Turmoil / Turbulence
  ; Turnover
  ; Calculate Code Knowledge
  ; Calculate Agents Knowledge
  ; (These are the figures then output.)
  ; Calculate membership of Superior Group
  ; socialization
  ; Learning
  ; Output Knowledge figures (as calculated earlier)
  ;Next time period


to go
  if ticks >= max-ticks [stop]
  
  ; Turmoil / Turbulence
  set reality map [ifelse-value (turbulence > random-float 100) [ifelse-value (? = 1) [-1] [1]] [?]] reality
  
  ; Turnover: worker left, to be replaced by one with random beliefs.
  ask workers [
    if turnover > random-float 100 [
      set beliefs n-values number-of-dimensions [(random 3) - 1] ; Reinitialised to 1, 0 or -1
    ]
  ]
  
  calc-org-knowledge
  calc-worker-knowledge
  ; (These are the figures then output.)
  
  ;for each organization (if you have more than one)
  set num-bupdates 0
  set num-cupdates 0
  ask orgs [
    calc-superior-group
    
    ; socialization
    let wsoc 0
    ask in-wlink-neighbors [
      set wsoc wsocialization
      set beliefs (map [socialised-belief ?1 ?2 wsoc] (beliefs) ([code] of cur-org))
    ]
;    calc-worker-knowledge ; I'm surprised March allowed socialization after the superior-group has been determined.
;    calc-superior-group

    ; Learning
    set code (map [learned-code ?1 ?2] code belief-sums)
    
  ;next organization
  ]
  
  ; Output Knowledge figures (as calculated earlier)
  my-update-plots
  
  ;set equilibrium (0 = (num-bupdates + num-cupdates))
  set equilibrium (0 = sum [diffs-from-code] of workers)
  if equilibrium and halt-on-equilibrium? [
    calc-org-knowledge
    calc-worker-knowledge
    update-stats
    stop
  ]
  
  tick
end

to calc-org-knowledge
  ; Calculate Code Knowledge
  ask orgs [
    ; NB: Knowledge is the proportion of dimensions that match reality (as per March's text),
    ; but Score is the sum of scoring 1 for a match, -1 for a mismatch, 0 for Undetermined, i.e. code-item * reality.
    set code-score sum (map [?1 * ?2] (reality) (code))
    set code-knowledge sum (map [ifelse-value (?1 = ?2) [1] [0]] (reality) (code))
  ]
end  

to calc-worker-knowledge
  ; Calculate Agents Knowledge
  ask workers [
    ; NB: Knowledge is the proportion of dimensions that match reality (as per March's text),
    ; but Score is the sum of scoring 1 for a match, -1 for a mismatch, 0 for Undetermined, i.e. belief * reality.
    set w-score sum (map [?1 * ?2] (reality) (beliefs))
    set w-knowledge sum (map [ifelse-value (?1 = ?2) [1] [0]] (reality) (beliefs))
  ]
end

to calc-superior-group
  ; Calculate membership of Superior Group
  set superior-group in-wlink-neighbors with [w-score > ([code-score] of myself)]
;  set superior-group in-wlink-neighbors with [w-knowledge > ([code-knowledge] of myself)]
  set belief-sums n-values number-of-dimensions [0]
  ask superior-group [
    set belief-sums (map [?1 + ?2] belief-sums beliefs)
  ]
end  

to-report socialised-belief [bval cval wsoc]
  if cval = 0 [report bval]
  if bval = cval [report bval]
  if (wsoc > random-float 100) [
    set num-bupdates num-bupdates + 1
    if bval = 0 [report cval]
    report 0
  ]
  report bval
end

to-report learned-code [cval bsum]
  let bsize abs bsum
  ; Calc majority view (of superior-group), if one exists.
  let bsign (ifelse-value (bsum = 0) [0] [bsum / bsize])
  if cval = bsign [report cval] ; Majority view matches code.
  if bsize = 0 [report cval] ; No majority view.
  let cur-member 0
  let new-val cval
  ifelse cval = 0 [
    ; Move from 0 to bsign?
    while [(new-val != bsign) and (cur-member < bsize)] [
      if (learning > random-float 100) [
        set new-val bsign
        set num-cupdates num-cupdates + 1
      ]
      set cur-member cur-member + 1
    ]
    report new-val
  ]
  [
    ; Move from opposite of bsign to 0?
    while [(new-val != 0) and (cur-member < bsize)] [
      if (learning > random-float 100) [
        set new-val 0
        set num-cupdates num-cupdates + 1
      ]
      set cur-member cur-member + 1
    ]
    report new-val
  ]
end

to-report diffs-from-code
  report sum (map [ifelse-value (?1 = ?2) [0] [1]] beliefs ([code] of cur-org))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-stats
  set mean-cscore (mean [code-score] of orgs) / number-of-dimensions
  set mean-wscore (mean [w-score] of workers) / number-of-dimensions

  set mean-cknowledge (mean [code-knowledge] of orgs) / number-of-dimensions
  set mean-wknowledge (mean [w-knowledge] of workers) / number-of-dimensions
  
  ifelse num-alt = 0 [
    set mean-s-wknowledge (mean [w-knowledge] of workers with [wsocialization = socialization]) / number-of-dimensions
    set mean-as-wknowledge 0
  ]
  [
    ifelse num-alt = count workers [
      set mean-s-wknowledge 0
      set mean-as-wknowledge (mean [w-knowledge] of workers with [wsocialization = alt-socialization]) / number-of-dimensions
    ]
    [
      set mean-s-wknowledge (mean [w-knowledge] of workers with [wsocialization = socialization]) / number-of-dimensions
      set mean-as-wknowledge (mean [w-knowledge] of workers with [wsocialization = alt-socialization]) / number-of-dimensions
    ]
  ]
  
end

to my-update-plots
  update-stats
  
  set-current-plot "Knowledge Evolution"
  set-current-plot-pen "Code"
  plotxy ticks mean-cknowledge
  set-current-plot-pen "Workers Mean"
  plotxy ticks mean-wknowledge
  
  set-current-plot "Updates"
  set-current-plot-pen "Codes"
  plotxy ticks num-cupdates / (number-of-dimensions * count orgs)
  set-current-plot-pen "Beliefs"
  plotxy ticks num-bupdates / (number-of-dimensions * count workers)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
6
370
251
569
1
1
56.0
1
10
1
1
1
0
1
1
1
-1
1
-1
1
0
0
1
ticks
30.0

INPUTBOX
6
77
161
137
Number-Of-Dimensions
30
1
0
Number

INPUTBOX
6
200
161
260
Number-Of-Workers
50
1
0
Number

SLIDER
167
77
339
110
Socialization
Socialization
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
167
112
339
145
Learning
Learning
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
167
148
339
181
Turnover
Turnover
0
100
0
1
1
NIL
HORIZONTAL

SLIDER
167
184
339
217
Turbulence
Turbulence
0
100
0
1
1
NIL
HORIZONTAL

SLIDER
167
219
339
252
Alt-Socialization
Alt-Socialization
0
100
90
1
1
NIL
HORIZONTAL

SLIDER
167
254
365
287
Proportion-Alt-Socialization
Proportion-Alt-Socialization
0
100
0
1
1
NIL
HORIZONTAL

INPUTBOX
6
264
161
324
Max-ticks
200
1
0
Number

BUTTON
6
330
70
363
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
73
330
136
363
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

TEXTBOX
10
10
436
35
James March's Organisational Learning Model
20
0.0
1

INPUTBOX
6
139
161
199
Number-Of-Organizations
1
1
0
Number

PLOT
370
76
728
304
Knowledge Evolution
Time (ticks)
Knowledge
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Code" 1.0 0 -16777216 true "" ""
"Workers Mean" 1.0 0 -2674135 true "" ""

TEXTBOX
6
38
275
60
This version (C) Christopher J Watts, 2014.
13
0.0
1

MONITOR
370
333
457
386
Code Mean
mean-cknowledge
3
1
13

MONITOR
459
333
571
386
Workers' Mean
mean-wknowledge
3
1
13

TEXTBOX
370
316
520
334
Knowledge Statistics:
13
0.0
1

TEXTBOX
370
389
520
407
Socialisation Statistics:
13
0.0
1

MONITOR
369
407
504
460
Mean Socialization
mean-wsocialization
1
1
13

SWITCH
167
289
333
322
Halt-On-Equilibrium?
Halt-On-Equilibrium?
0
1
-1000

PLOT
369
463
730
662
Updates
Time (ticks)
# Changes (Standardized)
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Codes" 1.0 0 -16777216 true "" ""
"Beliefs" 1.0 0 -2674135 true "" ""

MONITOR
369
669
492
722
# Code Changes
num-cupdates
1
1
13

MONITOR
497
668
622
721
# Belief Changes
num-bupdates
1
1
13

BUTTON
139
330
218
363
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

MONITOR
626
668
737
721
At equilibrium?
equilibrium
17
1
13

MONITOR
582
408
747
461
# Workers above Code
count superior-group
1
1
13

TEXTBOX
168
60
318
78
P1, P2, P3, P4:
13
0.0
1

TEXTBOX
584
315
734
333
Score Statistics:
13
0.0
1

MONITOR
582
334
669
387
Code Mean
mean-cscore
3
1
13

MONITOR
673
334
785
387
Workers' Mean
mean-wscore
3
1
13

TEXTBOX
582
388
746
406
Workers better than Code:
13
0.0
1

@#$#@#$#@
# JAMES MARCH'S ORGANISATIONAL LEARNING MODEL

A NetLogo version of March's classic Organisation Learning Model, based on the description in March (1991) and BASIC code derived from March's original, supplied to me by Simon Rodan (thanks for that!).

An organisation uses its workers to try to develop a coded form of knowledge of reality. The danger is that the population of workers will converge too quickly on a single view, matching the code, which fails to match reality. Slower learning processes may avoid this premature convergence. But too slow learning may also result in poor knowledge. A balance is needed between exploration of new views and exploitation of those already held.

This program was developed for chapter 4 of:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## HOW IT WORKS

An organisation has workers and exists in an environment ("reality").

Reality consists of a number of dimensions, each of which takes the value 1 or -1.  
Workers have beliefs, one for each dimension, initialised as 1, 0 or -1.  
The organisation has a code, representing its official view of reality, initialised as 0 (No opinion).  
Workers alter their beliefs under the influence of the code, as part of socialisation.  
The code is adapted to the beliefs of workers whose knowledge is currently superior to that of the code.  
There is a chance of Turnover, whereby a worker leaves to be replaced with one who has random beliefs.  
There is a chance of Turbulence, or "Turmoil", whereby a dimension of reality changes value.  
Workers may differ in their socialisation rates. A given proportion of them take an alternative socialisation rate.

Both workers and the organisation codes have "knowledge" values, based on their relation to reality. (But see the comment below.)

## HOW TO USE IT

March did not experiment with the numbers of organisations (1), workers (50), or dimensions (30). (So you might like to stick with the default values here.)

Choose parameter values for:  
Socialization (P1), a probability given as a percentage (i.e. values from 0 to 100)  
Learning (P2)  
Turnover (P3)  
Turbulence (P4)  
Alt-Socialisation : the alternative rate for socialisation  
Proportion-Alt-Socialisation : the proportion of workers who take the alternative value.  
Halt-On-Equilibrium? : Whether or not to halt the simulation when codes match the beliefs of workers.  
Max-ticks : Simulation runs halt when ticks reaches this value.

## THINGS TO NOTICE

There are BehaviorSpace experiments defined to try to reproduce the figures in March (1991). Qualitatively we can agree with most of what he writes. However, the scale is out for much of the parameter ranges. (E.g. See fig.1, high P2; fig.4, low P3.; fig.5, P3=10.)


## THINGS TO TRY

One problem with the March model is the high variance in output metrics. This makes it difficult to compare results or prove that one parameter setting is better than another. March ran 80 simulation replications for each setting. The experiments could easily be run with more, but it is questionable whether this is sensible. Real life is run only once. A conclusion that only shows up after 10000 replications might be "statistically significant", but would not be important. Besides which, note what March says in the last third of the paper about variability in organisational performance.

Confusion surrounds the definition (and use and calculation) of knowledge. March seems to write as if it is the proportion of dimensions for which beliefs or code match reality in value. However, the BASIC code seems to be a sum of (belief * reality) and sum of (code * reality). See also the formula given in Rodan (2005). At present, we use the sum products (which we call "score") to determine the superior-group of workers who can affect the code through learning. However, the proportion (call it "knowledge") is closer in scale to the values in March's figures. (The user is welcome to try other methods... Please let us know if you ever get close to March's results!)

## EXTENDING THE MODEL

Lots of attempts have been made (see references).  
Consider trying alternative definitions of knowledge, definitions of reality, social network structures between workers, multiple organisations competing for workers and knowledge.


## RELATED MODELS

Consider instead Lazer & Friedman (2007) ASQ, which uses a variation on Kauffman's NK fitness landscapes to examine the role network structures play in controlling the risk of premature convergence.

## CREDITS AND REFERENCES

March, James G. (1991) "Exploration and Exploitation in Organizational Learning". Organization Science, Vol. 2, No. 1, Special Issue: Organizational Learning: Papers in  
Honor of (and by) James G. March, pp. 71-87.

Rodan, S., (2005), "Exploration and Exploitation Revisited: Extending March's Model of Mutual Learning". Scandinavian Journal of Management, 21: 407-428.

See also papers in:  
Academy of Management Journal, 49(4), August 2006.


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
  <experiment name="experiment-Fig1" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count workers</metric>
    <metric>mean-wsocialization</metric>
    <metric>mean-cscore</metric>
    <metric>mean-wscore</metric>
    <metric>mean-cknowledge</metric>
    <metric>mean-wknowledge</metric>
    <metric>num-cupdates</metric>
    <metric>num-bupdates</metric>
    <metric>equilibrium</metric>
    <enumeratedValueSet variable="Number-Of-Organizations">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Workers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Dimensions">
      <value value="30"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Socialization" first="10" step="10" last="90"/>
    <enumeratedValueSet variable="Learning">
      <value value="10"/>
      <value value="50"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turnover">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turbulence">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Proportion-Alt-Socialization">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Alt-Socialization">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Equilibrium?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Fig2" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count workers</metric>
    <metric>mean-wsocialization</metric>
    <metric>mean-cscore</metric>
    <metric>mean-wscore</metric>
    <metric>mean-cknowledge</metric>
    <metric>mean-wknowledge</metric>
    <metric>num-cupdates</metric>
    <metric>num-bupdates</metric>
    <metric>equilibrium</metric>
    <enumeratedValueSet variable="Number-Of-Organizations">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Workers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Dimensions">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Socialization">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turnover">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turbulence">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Proportion-Alt-Socialization" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="Alt-Socialization">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Equilibrium?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Fig3" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count workers</metric>
    <metric>mean-wsocialization</metric>
    <metric>mean-cscore</metric>
    <metric>mean-wscore</metric>
    <metric>mean-cknowledge</metric>
    <metric>mean-wknowledge</metric>
    <metric>num-cupdates</metric>
    <metric>num-bupdates</metric>
    <metric>equilibrium</metric>
    <metric>mean-s-wknowledge</metric>
    <metric>mean-as-wknowledge</metric>
    <enumeratedValueSet variable="Number-Of-Organizations">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Workers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Dimensions">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Socialization">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turnover">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turbulence">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Proportion-Alt-Socialization" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="Alt-Socialization">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Equilibrium?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Fig4" repetitions="80" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count workers</metric>
    <metric>mean-wsocialization</metric>
    <metric>mean-cscore</metric>
    <metric>mean-wscore</metric>
    <metric>mean-cknowledge</metric>
    <metric>mean-wknowledge</metric>
    <metric>num-cupdates</metric>
    <metric>num-bupdates</metric>
    <metric>equilibrium</metric>
    <enumeratedValueSet variable="Number-Of-Organizations">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Workers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Dimensions">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Socialization">
      <value value="10"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Turnover" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="Turbulence">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Proportion-Alt-Socialization">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Alt-Socialization">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Equilibrium?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Fig5" repetitions="80" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>count workers</metric>
    <metric>mean-wsocialization</metric>
    <metric>mean-cscore</metric>
    <metric>mean-wscore</metric>
    <metric>mean-cknowledge</metric>
    <metric>mean-wknowledge</metric>
    <metric>num-cupdates</metric>
    <metric>num-bupdates</metric>
    <metric>equilibrium</metric>
    <enumeratedValueSet variable="Number-Of-Organizations">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Workers">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Dimensions">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Socialization">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turnover">
      <value value="0"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Turbulence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Proportion-Alt-Socialization">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Alt-Socialization">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Halt-On-Equilibrium?">
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
