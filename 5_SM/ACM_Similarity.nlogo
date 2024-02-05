;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Axelrod Cultural Model
;; After Axelrod (1997a; 1997b)
;; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  number-of-colours
  group-colours
  number-of-regions
  max-region-size
  last-seed-colours
  number-of-zones
  max-zone-size
  system-stable?
  
  ordered-list ; Used for recolouring nodes in same order each time.
  
  num-grid-links
  net-density
  num-components
  max-component
  
  last-seed-population
  last-seed-iteration
  last-seed-network

  IR-feature-order
]

breed [nodes node]
undirected-link-breed [grid-links grid-link]

nodes-own [
  features
  component
  region
  zone
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;
;; Setup ;;
;;;;;;;;;;;

to setup
 
  clear-all
  reset-ticks
  
  setup-world
  
  set last-seed-population (RNG-seed Population-RNG-Seed)
  setup-population
  set last-seed-network (RNG-seed network-RNG-Seed)
  setup-links
  
  calculate-regions
  calculate-zones
  set system-stable? (0 = regions-not-equal-to-zones)
  
  if (output-display?) [

    set last-seed-colours (RNG-seed Colours-RNG-Seed)
    setup-group-colours
    recolour-agents
    rescale-links
    update-labels
  ]
  
  do-plots
  
  set last-seed-iteration (RNG-seed Iteration-RNG-Seed)
end

to setup-world
  let box-width sqrt number-of-agents
  if (box-width ^ 2) < number-of-agents [ set box-width 1 + box-width ]
  resize-world 0 (2 * box-width) 0 (2 * box-width)
  set-patch-size int ((25 * 13) / (2 * box-width))
  ask patches [set pcolor white]
  
end

to setup-population
  
  create-nodes number-of-agents [
    ; Set initial cultural traits
    set features array:from-list n-values number-of-features [random number-of-traits]
    
    set shape "square"
    set label-color black
  ]
  
  set ordered-list sort nodes
        
end

to setup-group-colours
  ;; Setup the colours for regions, in a random order
  set number-of-colours 100
  if (number-of-agents >= number-of-colours) [set number-of-colours (number-of-agents * 8 / 7)]
  
  let list0 n-values 13 [5 + (? * 10)]
  let list1 shuffle filter [? mod 5 != 0] n-values number-of-colours [? + 1]
  
  set group-colours array:from-list sentence list0 list1
end

to-report RNG-seed [given-seed]
  let seed-value 0
  ifelse (given-seed = 0) [set seed-value new-seed] [set seed-value given-seed]
  random-seed seed-value
  report seed-value
  
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;
;; Go ;;
;;;;;;;;

to go
  if stopping-condition = "Max-ticks" [
    if ticks >= max-ticks [stop]
  ]
  if stopping-condition = "System stable" [
    if system-stable? [stop]
  ]
  
  nodes-interact
  if cultural-drift != 0 [mutation]
  
  tick
  
  if ((ticks mod Output-Every-n-Iterations) = 0) [
    calculate-regions
    calculate-zones
    set system-stable? (regions-not-equal-to-zones = 0)
    if (output-display?) [
      recolour-agents
      rescale-links
      update-labels
    ]
    
    do-plots
  ]
  
end

to nodes-interact
  ; Select participants
  let ego (one-of nodes)
  ask ego [
    let alter (one-of grid-link-neighbors)
    
;    show [who] of ego
;    show [who] of alter
    
    ; Compare features
    calculate-feature-order
    if (threshold-met? ego alter) [
      let number-of-mismatches (number-of-features - Similarity-threshold - (number-of-remaining-features-matched ego alter))
      if (number-of-mismatches > 0) [
        let cur-item Similarity-threshold
        let cur-feature (array:item IR-feature-order cur-item)
        while [([array:item features cur-feature] of ego) = ([array:item features cur-feature] of alter)] [
          set cur-item (cur-item + 1)
          set cur-feature (array:item IR-feature-order cur-item)
        ]

        ; Ego Imitates Alter
        array:set features cur-feature ([array:item features cur-feature] of alter)
      ]
    ]
  ]
end

to-report threshold-met? [ego alter]
  let num-matched 0
  let cur-item 0
  let cur-feature 0
  while [cur-item < number-of-features] [
    set cur-feature array:item IR-feature-order cur-item
    if (([array:item features cur-feature] of ego) = ([array:item features cur-feature] of alter)) [
      set num-matched (num-matched + 1)
      ]
    set cur-item (cur-item + 1)
    ]
  report (num-matched >= Similarity-threshold)
end

to-report number-of-remaining-features-matched [ego alter]
  let num-matched 0
  let cur-item Similarity-threshold
  let cur-feature 0
  while [cur-item < number-of-features] [
    set cur-feature array:item IR-feature-order cur-item
    if (([array:item features cur-feature] of ego) = ([array:item features cur-feature] of alter)) [
      set num-matched (num-matched + 1)
      ]
    set cur-item (cur-item + 1)
    ]
  report num-matched
end

to calculate-feature-order
  ; Populates array with random permutation
  set IR-feature-order array:from-list n-values number-of-features [?]
  let cur-item 0
  let swap-item 0
  let swap-value 0
  while [cur-item < number-of-features] [
    set swap-item ((random (number-of-features - cur-item)) + cur-item)
    set swap-value (array:item IR-feature-order cur-item)
    array:set IR-feature-order cur-item (array:item IR-feature-order swap-item)
    array:set IR-feature-order swap-item swap-value
    
    set cur-item (cur-item + 1)
    ]
  
end

to calculate-regions
  ; Put nodes into regions
  ; Regions defined by matching in every feature
  ; Calculate a network component for each node, and the size of the largest component
  let nodestack []
  let tempnode nobody
  let num-members 0
  let num-groups 0
  let max-group 0
  
  set num-groups 0
  set max-group 0
  foreach ordered-list [ 
    ask ? [
      set region 0
    ]
  ]
  foreach ordered-list [ 
    ask ? [
      if (region = 0) [
        set nodestack []
        set num-groups num-groups + 1
        if (num-members > max-group) [set max-group num-members]
        set num-members 1
        
        set region num-groups
        ask grid-link-neighbors with [region = 0] [
          if number-of-features = number-of-features-matched myself self [
            set nodestack fput self nodestack
          ]
        ]
        
        while [not empty? nodestack] [
          set tempnode first nodestack
          set nodestack but-first nodestack
          ask tempnode [
            if (region = 0) [
              set region num-groups
              set num-members num-members + 1
              ask grid-link-neighbors with [region = 0] [
                if number-of-features = number-of-features-matched myself self [
                  set nodestack fput self nodestack
                ]
              ]
            ]
          ]
        ]
        
      ]
    ]
  ]
  if (num-members > max-group) [set max-group num-members]
  
  set number-of-regions num-groups
  set max-region-size max-group
end

to calculate-zones
  ; Put nodes into zones
  ; Zones defined by matching in sufficient number of features
  ; Calculate a network component for each node, and the size of the largest component
  let nodestack []
  let tempnode nobody
  let num-members 0
  let num-groups 0
  let max-group 0
  
  set num-groups 0
  set max-group 0
  foreach ordered-list [ 
    ask ? [
      set zone 0
    ]
  ]
  foreach ordered-list [ 
    ask ? [
      if (zone = 0) [
        set nodestack []
        set num-groups num-groups + 1
        if (num-members > max-group) [set max-group num-members]
        set num-members 1
        
        set zone num-groups
        ask grid-link-neighbors with [zone = 0] [
          if similarity-threshold <= number-of-features-matched myself self [
            set nodestack fput self nodestack
          ]
        ]
        
        while [not empty? nodestack] [
          set tempnode first nodestack
          set nodestack but-first nodestack
          ask tempnode [
            if (zone = 0) [
              set zone num-groups
              set num-members num-members + 1
              ask grid-link-neighbors with [zone = 0] [
                if similarity-threshold <= number-of-features-matched myself self [
                  set nodestack fput self nodestack
                ]
              ]
            ]
          ]
        ]
        
      ]
    ]
  ]
  if (num-members > max-group) [set max-group num-members]
  
  set number-of-zones num-groups
  set max-zone-size max-group
end

to-report number-of-features-matched [ego alter]
  let num-matched 0
  let cur-feature 0
  while [cur-feature < number-of-features] [
    if (([array:item features cur-feature] of ego) = ([array:item features cur-feature] of alter)) [
      set num-matched (num-matched + 1)
      ]
    set cur-feature (cur-feature + 1)
    ]
  report num-matched
end

to-report regions-not-equal-to-zones
  report sum map [[ifelse-value (region = zone) [0] [1]] of ?] ordered-list
end

to mutation
  if cultural-drift > random-float 1 [
    ask one-of nodes [
      array:set features (random number-of-features) (random number-of-traits)
    ]
  ]
   
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; output ;;
;;;;;;;;;;;;

to recolour-agents
  if colour-agents-by = "Region" [colour-by-region]
  if colour-agents-by = "Zone" [colour-by-zone]
  if colour-agents-by = "Network Component" [colour-by-component]
  
end

to colour-by-region
  foreach ordered-list [
    ask ? [
      set color (array:item group-colours region)
    ]
  ]
end

to colour-by-zone
  foreach ordered-list [
    ask ? [
      set color (array:item group-colours zone)
    ]
  ]
end

to colour-by-component
  foreach ordered-list [
    ask ? [
      set color (array:item group-colours component)
    ]
  ]
end

to rescale-links
  ifelse rescale-links? [
    ask grid-links [
      ;set color scale-color black (number-of-features-matched end1 end2) number-of-features 0
      set thickness 1.0 * (number-of-features-matched end1 end2) / number-of-features
    ]
  ]
  [
    ask grid-links [set thickness 0]
  ]
end

to update-labels
  ifelse Culture-Labels? [
    ask nodes [
      set label array:to-list features
    ]
  ]
  [
    ask nodes [
      set label ""
    ]
  ]
end
    

to do-plots
  set-current-plot "Cultural Diversity"
  set-current-plot-pen "# Regions"
  plotxy ticks number-of-regions
  
  set-current-plot-pen "Largest Region"
  plotxy ticks max-region-size

  set-current-plot "Cultural Intelligibility"
  set-current-plot-pen "# Zones"
  plotxy ticks number-of-zones
  
  set-current-plot-pen "Largest Zone"
  plotxy ticks max-zone-size

end

to print-rng-seeds
  print ""
  print "Last random number seeds used:"
  print (word "Colours: " last-seed-colours)
  print (word "Network structure: " last-seed-network)
  print (word "Population initialisation: " last-seed-population)
  print (word "Simulation iterations: " last-seed-iteration)
  print ""
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Defining networks

to setup-links
  if network-type = "Complete" [ setup-links-complete ]
  if network-type = "4-Neighbour Grid" [ setup-links-4n-grid ]
  if network-type = "8-Neighbour Grid" [ setup-links-8n-grid ]
  if network-type = "Linear" [ setup-links-linear ]
  if network-type = "2-Neighbour Ring" [ setup-links-2n-ring ]
  if network-type = "4-Neighbour Ring" [ setup-links-4n-ring ]
  if network-type = "10-Neighbour Ring" [ setup-links-10n-ring ]
  if network-type = "Social Circles" [ setup-links-socialcircles ]
  if network-type = "Random (Erdos-Renyi)" [ setup-links-erdos-renyi ]
  if network-type = "Scale-free (Barabasi-Albert)" [ setup-links-barabasi-albert ]
  if rewire-chance > 0 [ rewire-links ]
  set num-grid-links (count grid-links)
  
  ask grid-links [
    set color grey
  ]
  
  set net-density 2 * num-grid-links / (number-of-agents * (number-of-agents - 1))
  calculate-components
  
end

to setup-links-complete
  reposition-nodes-circle
  
  ask nodes [
    create-grid-links-with other nodes
  ]
end

to setup-links-2n-ring
  ; 2 neighbours (1 neighbour each side)
  let num-nodes (count nodes)
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach orderedlist [
    ask ? [
      create-grid-link-with node ((who + 1) mod num-nodes) 
    ]
  ]
end

to setup-links-4n-ring
  ; 4 neighbours (2 neighbours each side)
  let num-nodes (count nodes)
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach orderedlist [
    ask ? [
      create-grid-link-with node ((who + 1) mod num-nodes) 
      create-grid-link-with node ((who + 2) mod num-nodes) 
    ]
  ]
end

to setup-links-10n-ring
  ; 10 neighbours (5 neighbours each side)
  ; As used with 1000 nodes by Strogatz, S & Watts, D (1998)
  let num-nodes (count nodes)
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach orderedlist [
    ask ? [
      create-grid-link-with node ((who + 1) mod num-nodes) 
      create-grid-link-with node ((who + 2) mod num-nodes) 
      create-grid-link-with node ((who + 3) mod num-nodes) 
      create-grid-link-with node ((who + 4) mod num-nodes) 
      create-grid-link-with node ((who + 5) mod num-nodes) 
    ]
  ]
end

to setup-links-linear
  ; 2 neighbours each side
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach but-last orderedlist [
    ask ? [
      create-grid-link-with node (who + 1) 
    ]
  ]
end

to setup-links-socialcircles
  ask nodes [
    setxy random-xcor random-ycor
  ]
  
  ask nodes [
    create-grid-links-with other nodes in-radius link-radius 
  ]
end

to setup-links-4n-grid
  reposition-nodes-grid
  
  let numnodes (count nodes)
  let numcols int sqrt numnodes
  if (numcols ^ 2) < numnodes [set numcols numcols + 1]
  let numrows int (numnodes / numcols)
  if (numcols * numrows) < numnodes [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
  
  ask nodes [
    create-grid-links-with other nodes in-radius (1.1 * (max (list xspace yspace)))
  ]
end

to setup-links-8n-grid
  reposition-nodes-grid
  
  let numnodes (count nodes)
  let numcols int sqrt numnodes
  if (numcols ^ 2) < numnodes [set numcols numcols + 1]
  let numrows int (numnodes / numcols)
  if (numcols * numrows) < numnodes [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
  
  ask nodes [
    create-grid-links-with other nodes in-radius (1.1 * (sqrt ((xspace ^ 2) + (yspace ^ 2)))) 
  ]
end

to setup-links-erdos-renyi
  reposition-nodes-circle

  let num-nodes (count nodes)
  let num-links int (0.5 + (link-chance * (num-nodes * (num-nodes - 1) / 2)))
  while [num-links > 0] [
    ask one-of nodes [
      if (count my-grid-links) < (num-nodes - 1) [
        ask one-of other nodes [
          if not (grid-link-neighbor? myself) [
            create-grid-link-with myself [
              set num-links num-links - 1
            ]
          ]
        ]
      ]
    ]
  ]
end

to setup-links-barabasi-albert
  reposition-nodes-circle

  let orderedlist sort nodes
  let num-nodes (count nodes)
  let destinations array:from-list n-values num-nodes [-1]
  let num-links 0

  set orderedlist but-first orderedlist
  let chosennode 0
  ask first orderedlist [ create-grid-link-with node chosennode ]
  array:set destinations num-links chosennode
  
  while [num-links < (num-nodes - 2)] [
    set chosennode ((random (2 * (num-links + 1))) - num-links)
    if chosennode < 0 [
      set chosennode (array:item destinations (abs chosennode))
    ]
    set num-links num-links + 1
    set orderedlist but-first orderedlist
    ask first orderedlist [ create-grid-link-with node chosennode ]
    array:set destinations num-links chosennode
  ]
end

to rewire-links
  let num-nodes-1 ((count nodes) - 1)
  ask n-of (rewire-chance * (count grid-links)) grid-links [
    if ([count my-grid-links] of end1) < num-nodes-1 [
      ask end1 [
;        create-grid-link-with one-of other nodes
        create-grid-link-with one-of other nodes with [not grid-link-neighbor? myself]
      ]
      die
    ]
  ]
end

to calculate-components
  ; Calculate a network component for each node, and the size of the largest component
  let nodestack []
  let tempnode nobody
  let num-members 0
  let num-groups 0
  let max-group 0
  
  set num-groups 0
  set max-group 0
  foreach ordered-list [ 
    ask ? [
      set component 0
    ]
  ]
  foreach ordered-list [ 
    ask ? [
      if (component = 0) [
        set nodestack []
        set num-groups num-groups + 1
        if (num-members > max-group) [set max-group num-members]
        set num-members 1
        
        set component num-groups
        ask grid-link-neighbors with [component = 0] [
          set nodestack fput self nodestack
        ]
        
        while [not empty? nodestack] [
          set tempnode first nodestack
          set nodestack but-first nodestack
          ask tempnode [
            if (component = 0) [
              set component num-groups
              set num-members num-members + 1
              ask grid-link-neighbors with [component = 0] [
                set nodestack fput self nodestack
              ]
            ]
          ]
        ]
      ]
    ]
  ]
  if (num-members > max-group) [set max-group num-members]
  
  set num-components num-groups
  set max-component max-group
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Repositioning an already created network
to reposition-nodes-spring
  ;layout-spring turtle-set link-set spring-constant spring-length repulsion-constant 
  repeat 10 [layout-spring nodes grid-links 1.5 (0.5 * max-pxcor / (sqrt count nodes)) 0.1]
  
end

to reposition-nodes-circle
  layout-circle (sort nodes) (max-pxcor * 0.4)
  
end

to reposition-nodes-grid
  let numnodes (count nodes)
  let numcols int sqrt numnodes
  if (numcols ^ 2) < numnodes [set numcols numcols + 1]
  let numrows int (numnodes / numcols)
  if (numcols * numrows) < numnodes [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))

  let orderedset sort nodes
  foreach orderedset [
    ask ? [
      set xcor (xspace * (1 + (who mod numcols)))
      set ycor (yspace * (1 + int (who / numcols)))
    ]
  ]
  
end

to move-mode  
  ;set moving? true
  ifelse mouse-down? [
    ifelse subject = nobody [
      if [any? turtles-here] of (patch mouse-xcor mouse-ycor) [
        watch one-of [turtles-here] of (patch mouse-xcor mouse-ycor)
      ]
    ]
    [
      ask subject [
        move-to patch mouse-xcor mouse-ycor
      ]
    ]
  ]
  [
    reset-perspective
    ;set moving? false
  ]
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
261
10
607
377
-1
-1
16.0
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
20
0
20
0
0
1
ticks
30.0

INPUTBOX
16
134
171
194
Number-of-Agents
100
1
0
Number

INPUTBOX
16
206
171
266
Number-of-Features
2
1
0
Number

INPUTBOX
16
277
171
337
Number-of-Traits
4
1
0
Number

BUTTON
261
401
325
434
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
334
401
397
434
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
407
401
470
434
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

INPUTBOX
11
816
166
876
Colours-RNG-Seed
-163562921
1
0
Number

INPUTBOX
170
885
325
945
Iteration-RNG-Seed
0
1
0
Number

INPUTBOX
11
884
166
944
Population-RNG-Seed
0
1
0
Number

PLOT
696
41
1118
299
Cultural Diversity
Time
Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"# Regions" 1.0 0 -11033397 true "" ""
"Largest Region" 1.0 0 -14730904 true "" ""

MONITOR
696
306
788
359
# Regions
number-of-regions
17
1
13

INPUTBOX
261
439
393
499
Output-Every-n-Iterations
200
1
0
Number

MONITOR
799
306
960
359
Size of Largest Region
max-region-size
17
1
13

SWITCH
261
503
405
536
Output-Display?
Output-Display?
0
1
-1000

TEXTBOX
10
12
232
37
Axelrod's Cultural Model
20
0.0
1

TEXTBOX
13
789
286
810
Random Number Generator Seeds:
16
0.0
1

SWITCH
8
539
166
572
Culture-Labels?
Culture-Labels?
0
1
-1000

SLIDER
7
342
179
375
Similarity-Threshold
Similarity-Threshold
0
8
1
1
1
NIL
HORIZONTAL

MONITOR
47
377
155
430
> # Features?
ifelse-value (similarity-threshold > number-of-features) [\n\"Too high!\"\n]\n[\"No. It's OK.\"]
17
1
13

BUTTON
11
953
105
986
Print Seeds
print-rng-seeds
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
16
438
171
498
Cultural-Drift
0
1
0
Number

MONITOR
696
364
788
417
# Zones
number-of-zones
17
1
13

MONITOR
799
364
960
417
Size of Largest Zone
max-zone-size
17
1
13

TEXTBOX
8
45
269
103
After Axelrod (1997a; 1997b), Castellano et al. (2000), Klemm et al. (2005).\nThis version (C) Christopher Watts, 2014.
13
0.0
1

PLOT
694
430
1116
689
Cultural Intelligibility
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
"# Zones" 1.0 0 -13840069 true "" ""
"Largest Zone" 1.0 0 -14333415 true "" ""

TEXTBOX
963
306
1191
363
Agents in same region are linked by a chain of agents with all features matching.
13
0.0
1

TEXTBOX
963
365
1198
417
Agents in the same zone are linked by a chain of agents with sufficient numbers of features matching.
13
0.0
1

TEXTBOX
126
951
372
1053
Click button to print seed numbers used in last simulation run. Set seed parameter to corresponding last seed value to repeat sequence of random numbers. Set seed parameter to 0 to make simulation use new seed number.
13
0.0
1

CHOOSER
8
604
242
649
Network-Type
Network-Type
"Complete" "4-Neighbour Grid" "8-Neighbour Grid" "Linear" "2-Neighbour Ring" "4-Neighbour Ring" "10-Neighbour Ring" "Random (Erdos-Renyi)" "Social Circles" "Scale-free (Barabasi-Albert)"
1

INPUTBOX
7
719
101
779
Rewire-Chance
0
1
0
Number

INPUTBOX
7
654
101
714
Link-Radius
5
1
0
Number

INPUTBOX
105
654
243
714
Link-Chance
0.1
1
0
Number

INPUTBOX
171
816
326
876
Network-RNG-Seed
0
1
0
Number

MONITOR
261
691
321
744
Density
net-density
3
1
13

MONITOR
325
692
435
745
# Components
num-components
17
1
13

MONITOR
440
692
630
745
Size of Largest Component
max-component
17
1
13

TEXTBOX
11
579
161
599
Network Structure:
16
0.0
1

TEXTBOX
263
666
413
686
Network Metrics:
16
0.0
1

BUTTON
262
619
331
652
Circle
reposition-nodes-circle
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
401
619
475
652
Spring
reposition-nodes-spring
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
334
619
397
652
Grid
reposition-nodes-grid
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
479
619
585
652
Move Mode
move-mode
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
266
595
416
615
Reposition Nodes:
16
0.0
1

BUTTON
426
502
530
535
Update Labels
set Culture-Labels? not Culture-Labels?\nupdate-labels
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
399
439
491
499
Max-ticks
500000
1
0
Number

TEXTBOX
7
100
157
120
Cultural Parameters:
16
0.0
1

TEXTBOX
698
10
887
30
Cultural Output Metrics:
16
0.0
1

CHOOSER
261
539
443
584
Colour-Agents-By
Colour-Agents-By
"Region" "Zone" "Network Component"
0

BUTTON
446
538
512
571
Recolour
recolour-agents
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
8
504
160
537
Rescale-Links?
Rescale-Links?
0
1
-1000

BUTTON
535
502
649
535
Update Links
set rescale-links? not rescale-links?\nrescale-links
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
547
383
661
436
System Stable?
system-stable?
17
1
13

CHOOSER
494
440
661
485
Stopping-Condition
Stopping-Condition
"System stable" "Max-ticks"
0

@#$#@#$#@
# AXELROD'S CULTURAL MODEL

A NetLogo version of Axelrod's (1997a, 1997b) model of cultural influence. Extras include "Cultural drift" (Klemm et al. 2005) and a "Similarity Threshold".

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 5 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

Agents prefer to interact with those sufficiently similar to themselves. Interactions result in social influence or imitation, thus making agents more similar. The model demonstrates what happens to an initially diverse population under these self-reinforcing processes of homophily and imitation.

Axelrod was partly motivated by the idea expressed by Rogers:

> “the exchange of ideas occurs most frequently between individuals who are alike… Such similarity may be in certain attributes, such as beliefs, education, socioeconomic status, and the like” (Rogers, 2003, p. 305) 

## HOW IT WORKS

Agents have variable values ("traits") in several cultural dimensions ("features"), representing different beliefs or practices. Initially agents are heterogeneous in their traits. Agents are also located in a social network that determines who can try to interact with whom.

Each time step, one randomly chosen agent attempts to interact with one randomly chosen neighbour. A given numbers of features are chosen at random. The interaction is successful if the two agents have matching traits for each of those features. If the interaction is a success, one participant then copies from the other a trait in one of the features not yet compared, chosen at random.

Agents form cultural __regions__. Two agents are in the same region if there is an unbroken chain of agents between them, each of whom matches traits in all features. Agents in the same region have nothing new to say to each other.

Agents form cultural __zones__. Two agents are in the same region if there is an unbroken chain of agents between them, each of whom matches traits in a sufficient number of features (with sufficiency determined by the parameter "Similarity-Threshold", default value = 1). Agents in different zones have no common understanding to serve as a basis for communication.

The numbers of regions and zones and the sizes (in agents) of the largest region and zone are calculated periodically. Agents may also be recoloured according to region.


## HOW TO USE IT

Click Setup.
Click Go.
Let it run until there no longer appear to be any changes.
How many "cultural regions" have the agents formed?

Now try again with different values for the parameters.

The main parameters are:

* __Number-Of-Agents__: Ideally this will be a square number (i.e. one of {1, 4, 9, 16, ...} = {1*1, 2*2, 3*3, 4*4, ...}), so that the agents can be organised in a square grid.
* __Number-Of-Features__: A number from 1 upwards.
* __Number-Of-Traits__: A number from 2 upwards.
* __Similarity-Threshold__: This is the number of features the interaction participants must match in, in order for the interaction to be a success. i.e. How similar must you be to the other person, before you are willing and able to imitate them. Clearly it makes no sense for this parameter to be greater than the number of features.
* __Cultural Drift__ or Noise: Each iteration with this probability, one randomly chosen agent has one randomly chosen feature mutate to a new, randomly chosen trait value.
* __Max-ticks__: If ticks has reached the value of Max-ticks, the simulation stops.

Extra parameters control updating the visual appearance of the model, and the seed numbers for the random number generator.

### NETWORK STRUCTURE

Agents belong to a network defined during setup. Networks determine who is physically capable (as opposed to culturally capable) of attempting interaction with whom. Several parameters exist for controlling the structure of the network.

* __Network-Type__: Common network structures are provided, including complete (everyone links to everyone else), 2-dimensional grids, rings, Erdos-Renyi Random network, Hamil & Gilbert's Social Circles (everyone links to everyone else located within a given radius of them), and Barabasi & Albert's scale-free network.
* __Link-Radius__: Used for the "Social Circles" network.
* __Link-Chance__: Used for the Erdos-Renyi random network.
* __Rewire-Chance__: Chance for each link that that link is rewired to a randomly chosen end node. Watts & Strogatz showed that when applied to a regular network (grids, rings), random rewiring can give the network "small-world" properties of low degree-of-separation while maintaining high clustering.

Buttons exist for repositioning the nodes in the network. Network metrics calculated include the density (the proportion of possible links between nodes that are actually present), the number of components (nodes linked by an unbroken chain are in the same component) and the size of the largest component. If a network has more than one component, agents in one component will not be able to influence agents in the other components, whatever their culture. When experimenting on different network structures, it may be desirable to ignore results from networks that had more than one component.

See the model NetworkDemo.nlogo in Chapter 3 of Watts & Gilbert (2014) for more one network structure.

## THINGS TO NOTICE

Eventually each pair of neighbouring agents is such that they match each other either in all features (and so imitation can produce no more changes) or in no features (and so they have no common ground for interaction leading to imitation). The system is then in a stable state. (Though adding a process of "cultural drift" can disturb this or even prevent it from happening.)


## THINGS TO TRY

Discover how the number of regions and the size of the largest region are affected by each parameter. In particular:

* Vary the number of traits and the number of features. Castellano et al. (2000) showed that the size of the largest region decreased in an S-shaped curve as the ratio of traits to features increased.
* For number of features F = 8, try varying the Similarity-Threshold (from 1 to 7 - you can probably guess what happens at 0 or 8). As the threshold increases, the size of the largest region attained decreases in an S-shaped curve.
* Vary the Cultural-Drift. Klemm et al. (2003; 2005) showed that mutating traits can cause the cultural boundaries between regions to dissolve, but also causes agents to leave a region. Thus depending on its rate, Cultural-Drift can promote or destroy cultural homogenisation and group formation.
* Once you have explored with a two-dimensional, four-neighbour grid, try alternative network structures for the agents. E.g. 8 neighbours, rings, complete, randomly rewired regular networks etc.

With zero cultural drift, a system can reach a static state where every pair of neighbouring agents has either every feature matching, and hence nothing to imitate, or insufficient features matching, and hence no chance of interaction proceeding to imitation. In this case, if regions and zones have been assigned to agents in the same order, region numbers should match zone numbers. The global variable System-Stable? is set to true whenever the number of agents with region not identical to zone = 0. This condition can be tested for, so as to stop the system at this point. 

Non-zero cultural drift will prevent the model from maintaining a static state. In this case, a simulation run must be halted after a pre-specified number of ticks. For example, given n=100 agents with F=2 features, 200 000 ticks should be enough for the system to stabilise on most runs, but not all. Higher values for n and F may require more ticks.

## EXTENDING THE MODEL

More network structures for the agents could be added. (See NetworkDemo.nlogo for ideas.)

How realistic are the processes in this model? How would you try to apply the model's qualititative behaviour to real-world social systems?

This version of the Axelrod Cultural Model can recolour agents by region or zone. Another way to demonstrate changing cultural similarity would be to recolour (or resize) links.


## RELATED MODELS

Several people have replicated Axelrod's cultural model (including in NetLogo). This is probably a good exercise for students learning to program agent-based simulation models. 

Castellano et al. (2000) and Klemm et al. (e.g. 2005) contain interesting explorations of its behaviour. Watts (2009) extended it in the light of Collins's sociology of interaction rituals.

Opinion dynamics models (e.g. Hegselmann & Krause, 2002) show analogous behaviour, but use a single continuous variable to represent one opinion or belief, rather than using multiple discrete variables.

## CREDITS AND REFERENCES

Axelrod, R. M. (1997a). "The complexity of cooperation : agent-based models of competition and collaboration." Princeton, N.J. ; Chichester: Princeton University Press.

Axelrod, R. M. (1997b). "The dissemination of culture - A model with local convergence and global polarization." Journal of Conflict Resolution, 41(2), 203-226. doi: 10.1177/0022002797041002001

Castellano, C., Marsili, M., & Vespignani, A. (2000). "Nonequilibrium phase transition in a model for social influence." Physical Review Letters, 85(16), 3536-3539. doi: 10.1103/PhysRevLett.85.3536

Klemm, Konstantin, Víctor M Eguíluz, Raúl Toral & Maxi San Miguel (2005) "Globalization, polarization and cultural drift" Journal of Economic Dynamics & Control 29 321 – 334

Klemm, K., Eguiluz, V. M., Toral, R., & Miguel, M. S. (2003). "Global culture: A noise-induced transition in finite systems." Physical Review E, 67(4). doi: 10.1103/PhysRevE.67.045101

Klemm, K., Eguiluz, V. M., Toral, R., & San Miguel, M. (2003). "Role of dimensionality in Axelrod's model for the dissemination of culture." Physica a-Statistical Mechanics and Its Applications, 327(1-2), 1-5. doi: 10.1016/s0378-4371(03)00428-x

Rogers, E. M. (2003). "Diffusion of innovations" (5th ed ed.). New York: Free Press.

Watts, C. J. (2009). "An agent-based model of energy in social networks." (PhD), University of Warwick. Retrieved from http://wrap.warwick.ac.uk/2799/  


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
  <experiment name="experiment-F8_Vary_q_ST" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="64"/>
      <value value="128"/>
      <value value="256"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Similarity-Threshold" first="0" step="1" last="8"/>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;System stable&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Vary_Drift" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="64"/>
      <value value="128"/>
      <value value="256"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Similarity-Threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.0010"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;Max-ticks&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Vary_q_F" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="64"/>
      <value value="128"/>
      <value value="256"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Similarity-Threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;System stable&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Vary_q_F_n" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="4"/>
      <value value="9"/>
      <value value="16"/>
      <value value="25"/>
      <value value="36"/>
      <value value="49"/>
      <value value="64"/>
      <value value="81"/>
      <value value="100"/>
      <value value="121"/>
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="64"/>
      <value value="128"/>
      <value value="256"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Similarity-Threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;System stable&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-F10_Vary_q_n" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="4"/>
      <value value="9"/>
      <value value="16"/>
      <value value="25"/>
      <value value="36"/>
      <value value="49"/>
      <value value="64"/>
      <value value="81"/>
      <value value="100"/>
      <value value="121"/>
      <value value="144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Similarity-Threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;System stable&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-F10_q10_Vary_n" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>num-components &gt; 1</exitCondition>
    <metric>timer</metric>
    <metric>system-stable?</metric>
    <metric>number-of-regions</metric>
    <metric>max-region-size</metric>
    <metric>number-of-zones</metric>
    <metric>max-zone-size</metric>
    <metric>net-density</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>last-seed-colours</metric>
    <metric>last-seed-population</metric>
    <metric>last-seed-iteration</metric>
    <enumeratedValueSet variable="Number-of-Agents">
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
      <value value="11"/>
      <value value="12"/>
      <value value="13"/>
      <value value="14"/>
      <value value="15"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Features">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Traits">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Similarity-Threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cultural-Drift">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-Type">
      <value value="&quot;4-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Display?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every-n-Iterations">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Culture-Labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rescale-Links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colour-Agents-By">
      <value value="&quot;Region&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Colours-RNG-Seed">
      <value value="-163562921"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Population-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Network-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Iteration-RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="500000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stopping-Condition">
      <value value="&quot;System stable&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
