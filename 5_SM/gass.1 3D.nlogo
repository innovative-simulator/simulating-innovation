; This is a re-implementation of the model described in 
; Gilbert, Nigel. (1997). A simulation of the structure of academic science. 
; Sociological Research Online, 2(2)3, http://www.socresonline.org.uk/socresonline/2/2/3.html.
;
; The original model was written in Common Lisp  in 1996 and run using Macintosh Common Lisp
; This version is for NetLogo 4.1, 3D version and was writtin on 19 May 2010, mainly in
; in a Boeing 777 over the Atlantic.

; The re-implementation stays fairly close to the original logic, which is why it does not
; follow normal NetLogo style in some places.

; December 2010: added correction to procedure 'original' to use direct-distance rather than
; in-radius.  Bug found by Nicholas Payette <nicolaspayette@gmail.com>, to whom many thanks.


; The NetLogo grid is used as the 'universe' of knowledge, with the z axis representing time
; the papers are reepresented as dots coloured the same as their 'generator' papers. (This
; is a deviation from the original, which was in black and white).

; The original used a universe measuring 2^16 - 1 by 2^16 - 1 units, but the units were
; discrete.  This is mapped in this re-implementation to the NetLogo grid, set to 33 by 33 
; patches, but measured in floating-point (actually double) coordinates.

breed [ papers paper ]
papers-own [
  my-author
  date
  cited-papers
]

breed [ authors author ]
authors-own [
  birth
  death
  n-citations
  my-papers
]

to setup
  clear-all
  set-default-shape papers "dot"
  repeat 1000 [ initial-papers ]
end


to initial-papers
  create-papers 1 [
    hide-turtle
    set date 0
    setxyz random-xcor random-ycor 0
    set cited-papers []
    set my-author ifelse-value (count authors > 0 and random 100 > alpha)
      [ one-of authors ]
      [ create-new-author ]
    ask my-author [ set my-papers fput myself my-papers ]
  ]
end

to-report create-new-author
  let new-author nobody
  hatch-authors 1 [
    hide-turtle
    set birth ticks
    set death ticks + random phi
    set my-papers []
    set new-author self
  ]
  report new-author
end

to go
  if ticks = 1000 [ stop ]
  repeat 1 + floor ( omega * (count papers - 1000) + ((random 100) - 50) / 100) [
  ; keep trying to create a new paper until we write a paper that is original
    let original? false
    while [ not original? ] [
      let generator-paper select-generator-paper
      let new-paper nobody
      let prob 1
      create-papers 1 [
        set color [color] of generator-paper
        set date ticks
        ; the constant 33 means that after 1000 ticks the papers are placed at the 
        ;  end of the z axis
        setxyz [ xcor ] of generator-paper [ ycor ] of generator-paper (ticks / 33)
        set new-paper self
        set cited-papers []
      ]
      let near-papers nearby-papers new-paper
      let cited-paper one-of near-papers
      while [ prob <= 100 and is-paper? cited-paper ] [
        set near-papers near-papers with [ self != cited-paper ]
        ask new-paper [ 
          set cited-papers fput cited-paper cited-papers 
          mix cited-paper prob
        ]
        set prob prob + random beta
        set cited-paper one-of near-papers
      ]
      ask new-paper [ 
        set original? original 
        ifelse original? 
          [ store-paper generator-paper]
          [ die ]
      ]
    ]
  ]
  do-plots
  tick
end

; choose a paper with an author that is still alive
to-report select-generator-paper
  report one-of papers with [ ticks <= [death] of my-author ]
end

; return an agentset of papers that are 'near' to the new-paper in knowledge space
to-report nearby-papers [ new-paper ]
  let near-papers nobody
  ask new-paper [
    set near-papers other papers with [ direct-distance myself <= (epsilon / 1000) ]
  ]
  report near-papers
end

; does the same as 'in-radius', but doesn't wrap around as the built-in primitive does
to-report direct-distance [ other-paper ]
  report sqrt (([xcor] of other-paper - xcor) ^ 2 + ([ycor] of other-paper - ycor) ^ 2)
end

; move myself so that I am a bit closer to 'citation'
to mix [ citation prob ]  ; paper procedure
  setxyz 
  xcor + round (([xcor] of citation - xcor ) * ((100 - prob) / 200 ))
  ycor + round (([ycor] of citation - ycor ) * ((100 - prob) / 200 ))
  zcor
end

; report true if there are no other papers near to me
to-report original ; paper procedure
  report not any? other papers with [ direct-distance myself <= (delta / 1000) ]
end

; give the paper an author and record citations
to store-paper [ generator-paper ] ; paper procedure
  set my-author ifelse-value ((random 100) > alpha)
    [ [my-author] of generator-paper ]
    [ create-new-author ]
  ask my-author [ set my-papers fput myself my-papers ]
  foreach cited-papers [
    ask ? [ increment-citations ]
  ]
end

to increment-citations ; paper procedure
  ask my-author [
    set n-citations n-citations + 1
  ]
end

to do-plots
  set-current-plot "Cumulative papers"
  plot count papers with [ date > 0 ]
  set-current-plot "References per paper"
  histogram [length cited-papers] of papers with [ date > 0 ]
  set-current-plot "Citations per author"
  histogram [n-citations] of authors
  set-current-plot "Papers per author"
  histogram [length my-papers] of authors
end






  
    

  
    
    
    
  
  
@#$#@#$#@
GRAPHICS-WINDOW
0
0
439
460
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
32
1
1
1
ticks

BUTTON
120
20
183
53
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
35
20
101
53
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
30
90
202
123
alpha
alpha
0
100
41
1
1
NIL
HORIZONTAL

SLIDER
30
140
202
173
beta
beta
0
100
20
1
1
NIL
HORIZONTAL

SLIDER
30
195
202
228
delta
delta
0
1000
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
30
295
202
328
phi
phi
0
1000
480
1
1
NIL
HORIZONTAL

SLIDER
30
350
202
383
omega
omega
0
0.01
0.0025
0.0005
1
NIL
HORIZONTAL

SLIDER
30
245
202
278
epsilon
epsilon
0
10000
7000
1
1
NIL
HORIZONTAL

PLOT
225
60
425
210
Cumulative papers
Time
Papers
0.0
10.0
0.0
10.0
true
false
PENS
"default" 1.0 0 -16777216 true

PLOT
225
235
425
385
Citations per author
NIL
NIL
0.0
200.0
0.0
10.0
true
false
PENS
"default" 5.0 1 -16777216 true

PLOT
445
235
645
385
Papers per author
NIL
NIL
0.0
20.0
0.0
10.0
true
false
PENS
"default" 1.0 1 -16777216 true

PLOT
445
60
645
210
References per paper
NIL
NIL
0.0
25.0
0.0
100.0
true
false
PENS
"default" 1.0 1 -16777216 true

TEXTBOX
15
75
220
101
chance of paper having a new author
11
0.0
1

TEXTBOX
15
125
165
143
chance of another citation
11
0.0
1

TEXTBOX
15
180
190
206
closeness of original papers
11
0.0
1

TEXTBOX
15
230
165
248
max distance of cited paper
11
0.0
1

TEXTBOX
15
280
165
298
max lifetime of an author
11
0.0
1

TEXTBOX
15
335
250
361
growth of papers per unit time
11
0.0
1

@#$#@#$#@
WHAT IS IT?
-----------
Contemporary science exhibits a number of regularities in the relationships between quantitative indicators of its growth. The classic source for these relationships is de Solla Price's (1963) lectures on Little Science, Big Science, in which he argues that there is evidence of a qualitative change in science from traditional 'little' science to the big science of large research teams and expensive research equipment. In making this argument, de Solla Price summarizes well what was then known about the structure of 'little' science. In the following thirty years, the dramatic changes which de Solla Price envisaged have generally not occurred (with some exceptions) and his summary is therefore still useful.

The central theme of de Solla Price's book is that science is growing exponentially, with a doubling time of between 10 and 20 years, depending on the indicator. For him, the fundamental characteristic of science is the publication of research papers in academic journals. He notes that papers always include references to other papers in the scientific literature, with a mean of 10 references per paper. The number of journals has followed an exponential growth curve with a doubling every 15 years since the mid-eighteenth century. There is approximately one journal for every 100 scientists (where a scientist is someone who has published a scientific paper) and scientists divide themselves up into 'invisible colleges' of roughly this size.

References tend to be to the most recent literature. Half of the references made in a large sample of papers would be to other papers published not more than 9 to 15 years previously. However, because the number of papers is growing exponentially, every paper has on average an approximately equal chance of being cited, although there are large variations in the number of citations different papers receive.

These observed regularities constitute the criteria with which to judge the simulation. The task is to develop a model which will reproduce these regularities from a small set of plausible assumptions.

HOW IT WORKS
------------
At the heart of the model is the idea that science as an institution can be characterized by 'papers', each proposing a new quantum of knowledge, and 'authors' who write papers. The simulation will model the generation of papers by authors.
The first assumption we make is that the simulation may proceed without reference to any external 'objective reality'. We shall simulate scientific papers each of which will capture some quantum of 'knowledge', but the constraints on this knowledge will be entirely internal to the model. To represent a quantum of knowledge, we shall use a sequence of bits. The bit sequences representing quanta of knowledge will be called 'kenes', a neologism intentionally similar to 'genes'.

Kenes could in principal consist of arbitrary bit sequences of indefinite length. However, we shall want to portray 'science' graphically in a convenient fashion and this means locating kenes in space. Since arbitrary bit sequences can only be mapped into spaces of indefinite dimensionality, we impose a rather strict limit on which sequences are allowable, purely for the purposes of permitting graphical displays. We require that each kene is composed of two sub- sequences of equal length, and we treat each sub-sequence as a representation of a coordinate on a plane. This restriction on kenes is substantial, but does not affect the logic of the simulation while making it much easier to see what is going on. It should be emphasized that the requirement that kenes can be mapped into a plane is not part of the model of the structure of science and could be relaxed in further work.

As a consequence of the fact that kenes can be decomposed into two coordinates, every kene can be assigned a position on the plane. Since each paper contains knowledge represented by one kene, that kene can stand for the paper and in particular, papers can also be located on the plane. In the simulation, each kene is composed of two coordinates, each 16 bits in length, giving a total 'scientific universe' of 2162 = 4,294,967,296 potential kenes, that is, an essentially infinite number compared with the number of papers generated during one run of the simulation. Authors can also be positioned on the plane according to the location of their latest paper.

One of the principal constraints on publication in science is that no two papers may be published which contain the same or similar knowledge. This amounts to the requirement that no two papers have identical kenes. In the model we extend this to require that no two papers have kenes which are 'similar', where similarity is measured by the distance between the kenes (a paper is deemed original if it lies more than delta	coordinate units away from any other paper, where delta and the other Greek symbols below are numerical parameters set at the start of the simulation). Since distance is a well defined notion even in multi-dimensional space, the idea that kenes and thus papers can be close does not depend on the requirement that kenes must be located on a plane.

So far, we have defined the three essential entities in the model: papers, authors and kenes. Next we need to consider the basic processes which give rise to these entities.
We propose that it is papers which give rise to further papers, with authors adopting only an incidental role in the process. A 'generator' paper is selected at random from those papers already published whose authors are still active in science. This spawns a new potential paper as a copy of itself, with the same kene. The new paper then selects a set of other papers to cite by randomly choosing papers located within the region of its generator paper (the 'region' is defined as the area within a circleofradius epsilon. Each of the cited papers modifies the generator kene to some extent. The first such paper has the most influence on the paper's kene, with successive citations having a decreasing effect. A spatial way of thinking about the process is that each cited paper 'pulls' the kene from its original location some way towards the location of the cited kene.
More precisely, the x coordinate of the new paper (p) is affected by the cited paper (c) thus:

x'p = xp + (xc - xp) * (1 - m) / 2

where m is a value between zero and one which increases randomly but monotonically for each successive citation. A similar equation determines the new y coordinate.

The result is a kene which is somewhat changed compared with the generator kene. If the changes are sufficient, the new kene will no longer be close to the generator kene. If the new kene is also not close to the kene of any previously published paper, it can be considered to be original and can be 'published'. If, however, the new kene is similar to a previous paper, the publication is abandoned.

Thus papers generate new papers which combine the influence of the generator paper with the papers it cites. Finally, publishable papers choose an author. A proportion (alpha) of papers choose a new, previously unpublished author and the rest are assigned the author of the generator paper.

An increasing number of papers are generated at each time step since there is a small constant probability, omega, of each published paper acting as a generator for a further paper at the next time step.

The rules concerning authors are much simpler. Authors remain in science from the time they publish their first paper until retirement. They are modelled as retiring when the duration of their time in science exceeds a value drawn from a uniform distribution from 0 to phi time units.

This section has described the rules which determine the generation of papers and authors in the simulation. It may be noticed that the rules are local and at the 'micro' level. That is, they make no reference to the overall state of the simulation and do not refer to aggregate properties. Papers, for example, cite other papers in their region without reference to whether that locality is relatively dense or thinly spread, or to the positions of papers outside the neighbourhood.



HOW TO USE IT
-------------
This section could explain how to use the model, including a description of each of the items in the interface tab.


THINGS TO NOTICE
----------------
You can pan, move and zoom the 3D plot.


EXTENDING THE MODEL
-------------------
See Watts, C. and Gilbert, N. (forthcoming) in Scientometrics.

NETLOGO FEATURES
----------------
The  model requires the 3D version of NetLogo 4.1


CREDITS AND REFERENCES
----------------------
This is a re-implementation of the model described in 
Gilbert, Nigel. (1997). A simulation of the structure of academic science. 
Sociological Research Online, 2(2)3, http://www.socresonline.org.uk/socresonline/2/2/3.html.
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
NetLogo 3D 4.1.1
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
1
@#$#@#$#@
