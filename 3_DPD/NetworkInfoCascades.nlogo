;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Chris's Network Demo with Information Cascades
; This version (C) Christopher J Watts, 2014
; See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  last-network-seed
  last-sim-seed
  
  num-red
  num-blue
  num-green
  blue-origin
  green-origin
  
  num-nlinks
  num-components
  max-component
  net-constraint
  clust-coeff
  assortativity
  
  net-density
  net-diameter
  mean-degree
  min-degree
  max-degree
  median-degree
  stdev-degree
  mean-cliquishness
  min-cliquishness
  max-cliquishness
  median-cliquishness
  stdev-cliquishness
  mean-dos
  min-dos
  max-dos
  stdev-dos
  mean-constraint
  min-constraint
  max-constraint  
  mean-betweenness
  min-betweenness
  max-betweenness

  mean-closeness
  min-closeness
  max-closeness
  
  degree-centralization
  closeness-centralization
;  betweenness-centralization

  mean-localvariety
  sum-localvariety
  min-localvariety
  max-localvariety
  
  order-switchpoints
  blue-green-order
  num-info-errors
  
  mean-error-rate
  median-error-rate
  min-error-rate
  max-error-rate
  
  mean-learning
  median-learning
  min-learning
  max-learning
  
  output-filename
]


breed [nodes node]
undirected-link-breed [nlinks nlink]

nodes-own [
  state
  degree
  constraint
  cliquishness
  dos
  reach
  closeness
  betweenness
  component
  predecessors
  localvariety
  categories
  memory
  num-errors
  num-decisions
  agent-error-rate
  agent-learning
  
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks

  setup-rng-network
  
  ask patches [
    set pcolor white
  ]
  
  if network-type = "Identity Search" [
    set number-of-nodes group-size-g * (branching-ratio-b ^ (number-of-levels-l - 1))
  ]
  
  create-nodes number-of-nodes [
;    set shape "face happy"
    set shape "person"
    set size 4
  ]
  
  setup-links  
  
  setup-states
  
  calc-metrics
  my-setup-plots
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Random number generation
to print-seeds
  print "Random number seeds:"
  print (word "Network: " last-network-seed)
  print (word "Simulation: " last-sim-seed)
  print " "
end

to setup-rng-network
  ifelse network-seed = 0 
  [ set last-network-seed new-seed ]
  [ set last-network-seed network-seed ]
  random-seed last-network-seed
end

to setup-rng-sim
  ifelse sim-seed = 0 
  [ set last-sim-seed new-seed ]
  [ set last-sim-seed sim-seed ]
  random-seed last-sim-seed
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; states: up to 2 competing technologies/ideas/diseases diffuse from distinct origins

to setup-states
  reset-ticks
  
  setup-rng-sim
  init-states-allr
  
;  ask nodes [ set memory [] ]
  ask nodes [
    set memory 0
    if initial-learning-chance = "Uniformly distributed" [ set agent-learning (random-float 1) ]
    if initial-learning-chance = "Homogeneous population" [ set agent-learning learning-chance ]
    set num-decisions 0
    set num-errors 0
    set agent-error-rate 0
  ]
  
  set order-switchpoints []
  set blue-green-order (num-blue > num-green)
  set num-info-errors 0
  
  setup-state-plots
  calc-localvariety
  update-plot
  
end

to init-states-allr
  ; No initial green or blue
  ask nodes [
    set color red
    set state 0
  ]
  set num-red ((count nodes) )
  set num-green 0
  set num-blue 0
end  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if end-sim [stop]
  agent-decision
  
  tick
  if ticks mod output-every = 0 [
    calc-localvariety
    update-plot
    ]
  
  if end-sim [
    calc-localvariety
    update-plot
    stop]
  
end

to-report end-sim
  let halt-answer (ticks >= max-ticks)
  report halt-answer
end
   
to calc-localvariety
  ask nodes [ calc-node-localvariety ]
end

to calc-node-localvariety
  ifelse (count my-nlinks) > 0 [
    let root-state state
    set localvariety  ((count nlink-neighbors with [state != root-state]) / (count nlink-neighbors))
  ]
  [
    set localvariety  0
  ]
  
end
  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-plot
  set-current-plot "Adoption"
  set-current-plot-pen "Green-Adopters"
  plotxy ticks num-green
  set-current-plot-pen "Blue-Adopters"
  plotxy ticks num-blue
  set-current-plot-pen "Red: No Adoption"
  plotxy ticks num-red
  
  set-current-plot "Local Variety"
  set-plot-x-range 0 1.1
  set-plot-pen-interval 0.1
  histogram [localvariety] of nodes
  set mean-localvariety mean [localvariety] of nodes
  set min-localvariety min [localvariety] of nodes
  set max-localvariety max [localvariety] of nodes
  
  set-current-plot "Error Rate Evolution"
  set mean-error-rate mean [agent-error-rate] of nodes
  set median-error-rate median [agent-error-rate] of nodes
  set min-error-rate min [agent-error-rate] of nodes
  set max-error-rate max [agent-error-rate] of nodes    
  set-current-plot-pen "Mean"
  plotxy ticks mean-error-rate
  set-current-plot-pen "Median"
  plotxy ticks median-error-rate
  
  set mean-learning mean [agent-learning] of nodes
  set median-learning median [agent-learning] of nodes
  set min-learning min [agent-learning] of nodes
  set max-learning max [agent-learning] of nodes

  set-current-plot "Learning Histogram"
  histogram [agent-learning] of nodes
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to my-setup-plots
  set-current-plot "Degree Centrality"
  set-plot-x-range 0 (2 + (max [degree] of nodes))
  histogram [degree] of nodes
  
  setup-loglog-plot
  
  set-current-plot "Degree of Separation"
  set-plot-x-range ((min [dos] of nodes)) (2 + (max [dos] of nodes))
  histogram [dos] of nodes
  
  set-current-plot "Betweenness Centrality"
  set-plot-x-range 0 1.1
  set-plot-pen-interval 0.1
  histogram [betweenness] of nodes
  
  set-current-plot "Cliquishness"
  set-plot-x-range 0 1.1
  set-plot-pen-interval 0.1
  histogram [cliquishness] of nodes
  
  set-current-plot "Structural Constraint"
  set-plot-x-range 0 1.1
  set-plot-pen-interval 0.1
  histogram [constraint] of nodes
  
end

to setup-loglog-plot
  let orderedlist sort ([ifelse-value (degree = 0) [0.5] [degree]] of nodes)
  ; NB: Some networks may have nodes with 0 links! Map them to -1 in log plot
  let curval first orderedlist
  set orderedlist but-first orderedlist
  let freqlist []
  let vallist []
  let curfreq 1
  while [length orderedlist > 0] [
    ifelse curval = first orderedlist [
      set curfreq curfreq + 1
    ]
    [ set vallist fput curval vallist
      set freqlist fput curfreq freqlist
      set curval first orderedlist
      set curfreq 1
    ]
    set orderedlist but-first orderedlist
  ]
  set vallist fput curval vallist
  set freqlist fput curfreq freqlist
  set-current-plot "Log-Log Plot of Degree"
  set-plot-x-range 0 int (2 + (max map [log ? 2] vallist))
  set-plot-y-range 0 int (2 + (max map [log ? 2] freqlist))
  ;let currank 0 ; In case we want rank-frequency plots
  ;set vallist reverse vallist
  ;set freqlist reverse freqlist
  while [length freqlist > 0] [
    ;set currank currank + 1
    set curfreq first freqlist
    set curval first vallist
    set freqlist but-first freqlist
    set vallist but-first vallist
    plotxy (log curval 2) (log curfreq 2)
  ]
end
  

to setup-state-plots
  
  set-current-plot "Error Rate Evolution"
  clear-plot
  
  set-current-plot "Adoption"
  clear-plot
  
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
  if network-type = "Star" [ setup-links-star ]
  if network-type = "Social Circles" [ setup-links-socialcircles ]
  if network-type = "Random (Erdos-Renyi)" [ setup-links-erdos-renyi ]
  if network-type = "Scale-free (Barabasi-Albert)" [ setup-links-barabasi-albert ]
  if network-type = "Scale-free (BOB)" [ setup-links-bob ]
  if network-type = "Modular (Caveman)" [ setup-links-modular ]
  if network-type = "Identity Search" [ setup-links-identity-search ]
  if rewire-chance > 0 [ rewire-links ]
  set num-nlinks (count nlinks)
  
  ask nlinks [
    set color grey
  ]
  
end


to setup-links-complete
  reposition-nodes-circle
  
  ask nodes [
    create-nlinks-with other nodes
  ]
end

to setup-links-2n-ring
  ; 2 neighbours (1 neighbour each side)
  let num-nodes (count nodes)
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach orderedlist [
    ask ? [
      create-nlink-with node ((who + 1) mod num-nodes) 
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
      create-nlink-with node ((who + 1) mod num-nodes) 
      create-nlink-with node ((who + 2) mod num-nodes) 
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
      create-nlink-with node ((who + 1) mod num-nodes) 
      create-nlink-with node ((who + 2) mod num-nodes) 
      create-nlink-with node ((who + 3) mod num-nodes) 
      create-nlink-with node ((who + 4) mod num-nodes) 
      create-nlink-with node ((who + 5) mod num-nodes) 
    ]
  ]
end

to setup-links-linear
  ; 2 neighbours each side
  let orderedlist (sort nodes)
  layout-circle orderedlist (max-pxcor * 0.4)
  
  foreach but-last orderedlist [
    ask ? [
      create-nlink-with node (who + 1) 
    ]
  ]
end

to setup-links-modular
  ; Modules ("caves") linked in a ring
  let numnodes (count nodes)
  let module-size int (numnodes / num-modules)
  let orderedlist []
  let cur-module 0
  ask nodes [set component int (who / module-size)]
  repeat num-modules [
    ifelse (cur-module + 1) = num-modules [
      set orderedlist (sort nodes with [component >= cur-module])
    ]
    [
      set orderedlist (sort nodes with [component = cur-module])
    ]
    layout-circle orderedlist (max-pxcor * 0.1)
    foreach orderedlist [
      ask ? [
        foreach orderedlist [
          if ? != self [
            if link-chance > random-float 1 [
              create-nlink-with ?
            ]
          ]
        ]
        set heading (cur-module * 360 / num-modules)
        fd (max-pxcor * 0.3)
        set heading 0
      ]
    ]
    set cur-module 1 + cur-module
  ]
  
  repeat num-inter-modular-links [
    set cur-module 0
    repeat num-modules [
      ask (one-of nodes with [(component = cur-module) and (0 < count nlink-neighbors with [component = cur-module])]) [
        ask one-of my-nlinks with [([component] of end1) = ([component] of end2)] [die]
        create-nlink-with one-of other nodes with [component = ((cur-module + 1) mod num-modules)]
      ]
      set cur-module 1 + cur-module
    ]
  ]
end

to setup-links-identity-search
  ; Agents choose neighbours based on their similarity in identity.
  ; Identity is made up of the groups agents belong to in several dimensions.
  
  reposition-nodes-circle
  
  ; Assign nodes to categories in several hierarchies
  ask nodes [
    set categories array:from-list n-values number-of-hierarchies-h [who]
  ]
  let cur-pos 0
  foreach sort nodes [
    ask ? [
      array:set categories 0 cur-pos
    ]
    set cur-pos 1 + cur-pos
  ]
  let cur-hier 1
  repeat (number-of-hierarchies-h - 1) [
    set cur-pos 0
    foreach shuffle sort nodes [
      ask ? [
        array:set categories cur-hier cur-pos
      ]
      set cur-pos 1 + cur-pos
    ]
  ]
  
  ; Set up stratified sampling of levels
  let dist-weights array:from-list n-values (number-of-levels-L) [0]
  let cur-weight exp (- homophily-alpha)
  let cur-level 0
  repeat number-of-levels-L [
    array:set dist-weights cur-level (cur-weight ^ cur-level)
    set cur-level 1 + cur-level
  ]
  let weight-sum sum array:to-list dist-weights
  
  ; Assign links
  let ego nobody
  let alter nobody
  let min-dist-nodes []
  let ordered-list sort nodes
  
  let num-desired-links int ((count nodes) * (group-size-g - 1) / 2)
  let num-assigned-links 0
  while [num-assigned-links < num-desired-links] [
    ; Choose ego (starting node)
    set ego one-of nodes
    if group-size-g - 1 > [count my-nlinks] of ego [
      
      ; Choose level
      set cur-weight random-float weight-sum
      set cur-level 0
      while [cur-weight >= 0] [
        set cur-weight cur-weight - array:item dist-weights cur-level
        set cur-level cur-level + 1
      ]
      set cur-level cur-level - 1
      
      set min-dist-nodes []
      foreach ordered-list [
        if not ([nlink-neighbor? ?] of ego) [
;          if (count nodes - 1) > [count my-nlinks] of ? [
            if ? != ego [
              if cur-level = social-distance ego ? [
                set min-dist-nodes fput ? min-dist-nodes
              ]
            ]
          ]
;        ]
      ]
      if 0 < length min-dist-nodes [
        ask ego [create-nlink-with one-of min-dist-nodes]
        set num-assigned-links 1 + num-assigned-links
      ]
    ]
  ]
  
end

to-report social-distance [ego alter]
  let min-dist category-distance ([array:item categories 0] of ego) ([array:item categories 0] of alter)
  let cur-cat 0
  let cur-dist 0
  repeat (number-of-hierarchies-h - 1) [
    set cur-cat 1 + cur-cat
    set cur-dist category-distance ([array:item categories cur-cat] of ego) ([array:item categories cur-cat] of alter)
    if min-dist > cur-dist [
      set min-dist cur-dist
    ]
  ]
  report min-dist 
end

to-report category-distance [e-cat a-cat]
  let cur-dist 0
  let e-level int (e-cat / group-size-g)
  let a-level int (a-cat / group-size-g)
  while [e-level != a-level] [
    set cur-dist 1 + cur-dist
    set e-level int (e-level / branching-ratio-b)
    set a-level int (a-level / branching-ratio-b)
  ]
  
  report cur-dist
end

to setup-links-star
  let outerset (but-first (sort nodes))
  layout-circle outerset (max-pxcor * 0.4)
    
  ask node 0 [
    set xcor (max-pxcor / 2)
    set ycor (max-pycor / 2)
    
    create-nlinks-with other nodes 
  ]
end

to setup-links-socialcircles
  ask nodes [
    setxy random-xcor random-ycor
  ]
  
  ask nodes [
    create-nlinks-with other nodes in-radius link-radius 
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
    create-nlinks-with other nodes in-radius (1.1 * (max (list xspace yspace)))
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
    create-nlinks-with other nodes in-radius (1.1 * (sqrt ((xspace ^ 2) + (yspace ^ 2)))) 
  ]
end

to setup-links-erdos-renyi
  reposition-nodes-circle

  let num-nodes (count nodes)
  let num-links int (0.5 + (link-chance * (num-nodes * (num-nodes - 1) / 2)))
  while [num-links > 0] [
    ask one-of nodes [
      if (count my-nlinks) < (num-nodes - 1) [
        ask one-of other nodes [
          if not (nlink-neighbor? myself) [
            create-nlink-with myself [
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
  ask first orderedlist [ create-nlink-with node chosennode ]
  array:set destinations num-links chosennode
  
  while [num-links < (num-nodes - 2)] [
    set chosennode ((random (2 * (num-links + 1))) - num-links)
    if chosennode < 0 [
      set chosennode (array:item destinations (abs chosennode))
    ]
    set num-links num-links + 1
    set orderedlist but-first orderedlist
    ask first orderedlist [ create-nlink-with node chosennode ]
    array:set destinations num-links chosennode
  ]
end

to setup-links-bob
  ; Attempts to generate networks with right-skew degree distributions
  ; using the method of Bentley, Ormerod & Batty (2009)
  reposition-nodes-circle
  
  let orderedlist sort nodes
  let num-nodes (count nodes)
  let max-num-links (num-nodes * (num-nodes - 1))
  let mem-size (2 * link-batch-size * link-memory)
;  let mem-size max-num-links
  let destinations array:from-list n-values mem-size [-1]
  let num-added 0
  let ego nobody
  let alter nobody
  
  repeat int (num-initial-pairs) [
    set ego first orderedlist
    set orderedlist but-first orderedlist
    set alter first orderedlist
    set orderedlist but-first orderedlist
    ask ego [ create-nlink-with alter ]
    array:set destinations num-added [who] of ego
    array:set destinations (num-added + 1) [who] of alter
    set num-added (num-added + 2)
  ]
  
  let mptr num-added
  let num-to-choose-from num-added
  while [(length orderedlist > 0) and (num-added < max-num-links)] [
    repeat (link-batch-size) [
      ; set ego
      ifelse ((random-float 1 < new-node-chance) and (length orderedlist > 0))[
        set ego first orderedlist
        set orderedlist but-first orderedlist
        set alter (node array:item destinations ((mptr - 1 - (random num-to-choose-from) + mem-size) mod mem-size))
      ]
      [ set ego (node array:item destinations ((mptr - 1 - (random num-to-choose-from) + mem-size) mod mem-size))
        ; set alter
        set alter ego
        while [ego = alter] [
          ifelse ((random-float 1 < new-node-chance) and (length orderedlist > 0)) [
            set alter first orderedlist
            set orderedlist but-first orderedlist
          ]
          [ set alter (node array:item destinations ((mptr - 1 - (random num-to-choose-from) + mem-size) mod mem-size)) ]
        ]
      ]
      ; create link
      ask ego [ create-nlink-with alter ]
      array:set destinations (num-added mod mem-size) [who] of ego
      array:set destinations ((num-added + 1) mod mem-size) [who] of alter
      set num-added (num-added + 2)
    ]
    set mptr ((mptr + (2 * link-batch-size)) mod mem-size)
    set num-to-choose-from ifelse-value (num-added > mem-size) [mem-size] [num-added]
  ]
  
end

to rewire-links
  let num-nodes-1 ((count nodes) - 1)
  ask n-of (rewire-chance * (count nlinks)) nlinks [
    if ([count my-nlinks] of end1) < num-nodes-1 [
      ask end1 [
;        create-nlink-with one-of other nodes
        create-nlink-with one-of other nodes with [not nlink-neighbor? myself]
      ]
      die
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Repositioning an already created network
to reposition-nodes-spring
  ;layout-spring turtle-set link-set spring-constant spring-length repulsion-constant 
  repeat 10 [layout-spring nodes nlinks 0.2 (1.5 * max-pxcor / (sqrt count nodes)) 1]
  
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
;; Calculate various node and network metrics

to calc-metrics
  calc-degree
  calc-components
  set net-density (2 * (count nlinks) / ((count nodes) * ((count nodes) - 1)))
  ifelse calculate-slow-metrics [
    calc-net-constraint
    calc-cliquishness
    calc-assortativity
    calc-betweenness
  ]
  [
    calc-dos
  ]
  
end

to calc-degree
  ; Degree centrality = # links
  ask nodes [
    set degree (count my-nlinks)
  ]
  
  set mean-degree mean [degree] of nodes
  set min-degree min [degree] of nodes
  set max-degree max [degree] of nodes
  set median-degree median [degree] of nodes
  set stdev-degree standard-deviation [degree] of nodes
  
end

to calc-net-constraint
  let csum 0
  let cij 0
  ask nodes [
    let degi (count my-nlinks)
    let origin self
    set csum 0
    ask nlink-neighbors [
      ; direct or (direct and indirect)
      set cij (1 / degi)
      let dest self
      ask [nlink-neighbors] of origin [
        if (nlink-neighbor? dest) [
          set cij (cij + (1 / (degi * (count my-nlinks))))
        ]
      ]
      set csum (csum + (cij ^ 2))
      
;      ; indirect and not direct
;      set cij 0
;      let degq (count nlinks)
;      ask [nlink-neighbors] of self [
;        if (not nlink-neighbor? origin) [
;          if self != origin [
;            set cij (cij + (1 / (degi * degq)))
;          ]
;        ]
;      ]
;      set csum (csum + (cij ^ 2))
    ]
    set constraint csum
  ]
  set net-constraint sum [constraint] of nodes
  set mean-constraint mean [constraint] of nodes
  set min-constraint min [constraint] of nodes
  set max-constraint max [constraint] of nodes
end
  

to calc-cliquishness
  ; Node cliquishness = proportion of 2-stars that are triangles
  ; Clustering coefficient: what proportion of triplets are in fact triangles
  let origin nobody
  let num-triangles 0
  let num-2stars 0
  let tot-num-triangles 0
  let tot-num-2stars 0
  let temp-neighbors nobody
  
  ask nodes [
    set num-triangles 0
    set num-2stars 0
;    ; cycle count
;    set origin self
    
;    ask nlink-neighbors [
;      ask nlink-neighbors [
;        if (origin != self) [
;          set num-2stars (num-2stars + 1)
;          ask nlink-neighbors [
;            if (origin = self) [
;              set num-triangles num-triangles + 1
;            ]
;          ]
;        ]
;      ]

    ; cliquishness = proportion of 2-stars that are triangles
    set temp-neighbors nlink-neighbors
    ask temp-neighbors [
      set origin self
      ask temp-neighbors [
        if nlink-neighbor? origin [
          if (origin != self) [
            set num-triangles num-triangles + 1
          ]
        ]
      ]
    ]
    set num-2stars (count nlink-neighbors) * ((count nlink-neighbors) - 1)
    
    ifelse (num-2stars = 0) [
      set cliquishness 0
    ]
    [
      set cliquishness (num-triangles / num-2stars)
    ]
    set tot-num-triangles tot-num-triangles + num-triangles
    set tot-num-2stars tot-num-2stars + num-2stars
  ]
  
  set mean-cliquishness mean [cliquishness] of nodes
  set min-cliquishness min [cliquishness] of nodes
  set max-cliquishness max [cliquishness] of nodes
  set median-cliquishness median [cliquishness] of nodes
  set stdev-cliquishness standard-deviation [cliquishness] of nodes
  if tot-num-2stars > 0 [
    set clust-coeff tot-num-triangles / tot-num-2stars
  ]
  
end

to calc-assortativity
  let avg1 0
  let avg2 0
  let sum1 0
  let sum2 0
  let sum3 0
  ask nodes [
    set sum1 sum1 + ((count nlink-neighbors) * degree)
    set sum3 sum3 + (count nlink-neighbors)
    ask nlink-neighbors [
      set sum2 sum2 + degree
    ]
  ]
  ifelse (sum3 > 0) [
    set avg1 sum1 / sum3
    set avg2 sum2 / sum3
    set sum1 0
    set sum2 0
    set sum3 0
    let temp-diff 0
    ask nodes [
      set temp-diff (degree - avg1)
      set sum2 sum2 + ((count nlink-neighbors) * (temp-diff ^ 2))
      ask nlink-neighbors [
        set sum1 sum1 + (temp-diff * (degree - avg2))
        set sum3 sum3 + ((degree - avg2) ^ 2)
      ]
    ]
    ifelse sum2 * sum3 > 0 [
      set assortativity sum1 / (sqrt (sum2 * sum3))
    ]
    [
      set assortativity 0
    ]
  ]
  [
    set assortativity 0
  ]
   
end

to calc-betweenness
; Ulrik Brandes's (2001) betweenness algorithm
;
  let CB array:from-list n-values (count nodes) [0]
  let S [] ; Stack (LIFO)
  let Q [] ; Queue (FIFO)
  let R array:from-list n-values (count nodes) [0] ; # paths
  let d array:from-list n-values (count nodes) [0] ; distance
  ;let P array:from-list n-values (count nodes) [0] ; Predecessor list
  let dep array:from-list n-values (count nodes) [0]
  let v nobody
  let v-who 0
  let w nobody
  let w-who 0
  let maxdos 0
;  let denominator (((count nodes) - 1) * ((count nodes) - 2) / 2)
  let denominator ((count nodes) - 1) * ((count nodes) - 2) 
  set net-diameter -1
  
  ask nodes [
    set S []
    ask nodes [ set predecessors [] ]
    ;set P []
    set R array:from-list n-values (count nodes) [0]
    array:set R who 1
    set d array:from-list n-values (count nodes) [-1]
    array:set d who 0
    set Q []
    set Q lput self Q
    while [length Q > 0] [
      set v first Q
      set Q but-first Q
      set S fput v S
      set v-who [who] of v
      ask [nlink-neighbors] of v [
        if (array:item d who) < 0 [
          set Q lput self Q
          array:set d who (1 + array:item d v-who)
        ]
        if (array:item d who) = (1 + array:item d v-who) [
          array:set R who ((array:item R who) + (array:item R v-who))
          set predecessors fput v predecessors
          ;set P fput v P
        ]
      ]
    ]
    
    set dep array:from-list n-values (count nodes) [0]
    while [(length S) > 0] [
      set w first S
      set S but-first S
      set w-who [who] of w
      foreach [predecessors] of w [
        ask ? [
          array:set dep who (array:item dep who) + (((array:item R who) / (array:item R w-who)) * (1 + array:item dep w-who))
        ]
      ]
      if w != self [
        array:set CB w-who ((array:item CB w-who) + (array:item dep w-who))
      ]
    ]
    set reach sum map [ifelse-value (? >= 0) [1] [0]] (array:to-list d)
    set dos (sum (array:to-list d)) / reach
    set closeness ifelse-value (dos <= 0) [-1] [(reach - 1) / (dos * reach)]
    set maxdos max (array:to-list d)
    if (maxdos > net-diameter) [ set net-diameter maxdos ]
  ]

  ask nodes [
    set betweenness (array:item CB who) / denominator
  ]

  set mean-dos mean [dos] of nodes
  set min-dos min [dos] of nodes
  set max-dos max [dos] of nodes
  set stdev-dos standard-deviation [dos] of nodes
  
  set mean-closeness mean [closeness] of nodes
  set min-closeness min [closeness] of nodes
  set max-closeness max [closeness] of nodes
  
  set mean-betweenness mean [betweenness] of nodes
  set min-betweenness min [betweenness] of nodes
  set max-betweenness max [betweenness] of nodes
  
  set degree-centralization number-of-nodes * (max-degree - mean-degree) / ((number-of-nodes - 1) * (number-of-nodes - 2))
  set closeness-centralization number-of-nodes * (max-closeness - mean-closeness) * (2 * number-of-nodes - 3) / ((number-of-nodes - 1) * (number-of-nodes - 2))
  
end  

to calc-dos
; From Ulrik Brandes's (2001) betweenness algorithm
;
  let Q [] ; Queue (FIFO)
  let d array:from-list n-values (count nodes) [0] ; distance
  let v nobody
  let v-who 0
  let maxdos 0
  set net-diameter -1
  
  ask nodes [
    set d array:from-list n-values (count nodes) [-1]
    array:set d who 0
    set Q []
    set Q lput self Q
    while [length Q > 0] [
      set v first Q
      set Q but-first Q
      set v-who [who] of v
      ask [nlink-neighbors] of v [
        if (array:item d who) < 0 [
          set Q lput self Q
          array:set d who (1 + array:item d v-who)
        ]
      ]
    ]
    
    set reach sum map [ifelse-value (? >= 0) [1] [0]] (array:to-list d)
    set dos (sum (array:to-list d)) / reach
    set closeness ifelse-value (dos <= 0) [-1] [(reach - 1) / (dos * reach)]
    set maxdos max (array:to-list d)
    if (maxdos > net-diameter) [ set net-diameter maxdos ]
  ]

  set mean-dos mean [dos] of nodes
  set min-dos min [dos] of nodes
  set max-dos max [dos] of nodes
  set stdev-dos standard-deviation [dos] of nodes
  
  set mean-closeness mean [closeness] of nodes
  set min-closeness min [closeness] of nodes
  set max-closeness max [closeness] of nodes
  
  set degree-centralization number-of-nodes * (max-degree - mean-degree) / ((number-of-nodes - 1) * (number-of-nodes - 2))
  set closeness-centralization number-of-nodes * (max-closeness - mean-closeness) * (2 * number-of-nodes - 3) / ((number-of-nodes - 1) * (number-of-nodes - 2))

end  


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to calc-components
  ; Calculate a network component for each node, and the size of the largest component
  let nodestack []
  let tempnode node 0
  let num-members 0
  
  set num-components 0
  set max-component 0
  ask nodes [ set component 0]
  ask nodes [
    if (component = 0) [
      set nodestack []
      set num-components num-components + 1
      if (num-members > max-component) [set max-component num-members]
      set num-members 1
      
      set component num-components
      ask nlink-neighbors with [component = 0] [
        set nodestack fput self nodestack
      ]
      
      while [not empty? nodestack] [
        set tempnode first nodestack
        set nodestack but-first nodestack
        ask tempnode [
          if (component = 0) [
            set component num-components
            set num-members num-members + 1
            ask nlink-neighbors with [component = 0] [
              set nodestack fput self nodestack
            ]
          ]
        ]
      ]
      
    ]
  ]
  if (num-members > max-component) [set max-component num-members]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to output-network-to-vna-file
  
  let file-name user-new-file
  if file-name = false [stop]
  
  ; Open file for output
  if file-exists? file-name [file-delete file-name]
  set output-filename file-name
  file-open file-name
  file-print "*node data"
  
  ; Node attribute headings
  file-print "ID,State,NumErrors,NumDecisions,ErrorRate,Learning"
  
  ; Node attributes
  foreach sort nodes [
    ask ? [
      file-write who
      file-write state
      file-write Num-Errors
      file-write Num-Decisions
      file-write (int (100 * agent-Error-Rate))
      file-write (int (100 * agent-Learning))
      file-print ""
    ]
  ]
  
  file-print ""
  file-print "*node properties"
  file-print "ID x y color shape size shortlabel"
  foreach sort nodes [
    ask ? [
      file-write who
      file-write xcor
      file-write ycor
      file-write 255
      file-write 1
      file-write 10
      file-write (word who) ; (word "node_" who)
      file-print ""
    ]
  ]
  
  file-print ""
  
  ; Tie data
  file-print "*tie data"
  file-print "from to TieType1"
  foreach sort nlinks [
    ask ? [
      file-write ([who] of end1)
      file-write ([who] of end2)
      file-write 1
      file-print ""
      
      ; Force ties to be reflexive
      file-write ([who] of end2)
      file-write ([who] of end1)
      file-write 1
      file-print ""
      
    ]
  ]
  
  file-print ""
  file-close

end

to output-node-metrics
  calc-metrics
  print ""
  print "Node metrics:"
  print ""
  print (word "Who, State, Memory, Num-Errors, Num-Decisions, Error Rate, Learning, Component, Degree, Closeness, Betweenness, Constraint, Cliquishness, Degree of Separation, Reach, Local Variety")

  foreach sort nodes [
    ask ? [
      print (word who ", " state ", " memory ", " num-errors ", " num-decisions ", " agent-error-rate ", " agent-learning 
        ", " component ", " degree ", " closeness ", " betweenness 
        ", " constraint ", " cliquishness ", " dos ", " reach ", " localvariety)
    ]
  ]
end

to output-network-metrics
  calc-metrics
  print ""
  print "Network metrics:"
  print ""
  print (word "Number of nodes, # Red, # Blue, # Green, Blue Origin, Green Origin")
  print (word (count nodes) ", " num-red ", " num-blue ", " num-green ", " blue-origin ", " green-origin)
  print ""
  print (word "Number of links, # Components, Size of largest component, Network Constraint, Clustering coefficient, Assortativity")
  print (word (count nlinks) ", " num-components ", " max-component ", " net-constraint ", " clust-coeff ", " assortativity)
  print ""
  print (word "Network Density, Network Diameter, Degree Centralization, Closeness Centralization")
  print (word net-density ", " net-diameter ", " degree-centralization ", " closeness-centralization)
  print ""
  print (word "Node Degree Centraility: Mean, Min, Max, Median, StDev")
  print (word mean-degree ", " min-degree ", " max-degree ", " median-degree ", " stdev-degree)
  print ""
  print (word "Node Closeness Centraility: Mean, Min, Max")
  print (word mean-closeness ", " min-closeness ", " max-closeness)
  print ""
  print (word "Node Betweenness Centrality: Mean, Min, Max")
  print (word mean-betweenness ", " min-betweenness ", " max-betweenness)
  print ""
  print (word "Node Structural Constraint: Mean, Min, Max")
  print (word mean-constraint ", " min-constraint ", " max-constraint)
  print ""
  print (word "Node Cliquishness (Clustering Coefficient): Mean, Min, Max, Median, StDev")
  print (word mean-cliquishness ", " min-cliquishness ", " max-cliquishness ", " median-cliquishness ", " stdev-cliquishness)
  print ""
  print (word "Node Mean Degree of Separation: Mean, Min, Max, StDev")
  print (word mean-dos ", " min-dos ", " max-dos ", " stdev-dos)
  print ""
  print (word "Local Variety: Mean, Total, Min, Max")
  print (word mean-localvariety ", " sum-localvariety ", " min-localvariety ", " max-localvariety)
  
  print ""
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to agent-decision
  ; Agents uses its memory of past actions by it and its neighbours to decide state
  ask one-of nodes [
    let diff 0
    ifelse random-float 1 < agent-learning [
;      set diff (sum memory)
      set diff memory
      if diff > 1 [
        agent-acts 1 0
        stop
      ]
      if diff < -1 [
        agent-acts -1 0
        stop
      ]
    ]
    [ ; Not using learning from others
      set diff 0
    ]
    let source-signal (ifelse-value (random-float 1 < ifelse-value ((int (ticks / switch-source-every) mod 2) = 0) [source-chance] [1 - source-chance] ) [1] [-1])
    set diff diff + source-signal
    if diff >= 1 [
      agent-acts 1 source-signal
      stop
    ]
    if diff <= -1 [
      agent-acts -1 source-signal
      stop
    ]
    ; diff = 0
    agent-acts (ifelse-value (random-float 1 < 0.5) [1] [-1]) source-signal ; coin toss
  ]
    
end

to agent-acts [given-decision source-signal]
  let decision given-decision
  if random-float 1 < noise-chance [
    set decision 0 - decision
  ]
  let decstate ((decision + 1) / 2) + 1
  
  set num-decisions num-decisions + 1
  ifelse decstate = 2 [
    if (ifelse-value ((int (ticks / switch-source-every) mod 2) = 0) [source-chance] [1 - source-chance]) < 0.5 [
      set num-info-errors num-info-errors + 1
      set num-errors num-errors + 1
      set agent-error-rate (num-errors / num-decisions)
      if fatal-chance > random-float 1 [make-fatal-error]
    ]
  ]
  [
    if (ifelse-value ((int (ticks / switch-source-every) mod 2) = 0) [source-chance] [1 - source-chance]) > 0.5 [
      set num-info-errors num-info-errors + 1
      set num-errors num-errors + 1
      set agent-error-rate (num-errors / num-decisions)
      if fatal-chance > random-float 1 [make-fatal-error]
    ]
  ]
    
  
  if state != decstate [
    ifelse state = 0 [
      set num-red num-red - 1
      set state decstate
      ifelse state = 1 [
        set num-green num-green + 1
        set color green
      ]
      [
        set num-blue num-blue + 1
        set color blue
      ]
    ]
    [
      set state decstate
      ifelse state = 1 [
        set num-blue num-blue - 1
        set num-green num-green + 1
        set color green
      ]
      [
        set num-blue num-blue + 1
        set num-green num-green - 1
        set color blue
      ]
    ]
  ]
  
;  if (num-blue > num-green) != blue-green-order [
;    set blue-green-order (num-blue > num-green)
;    if ticks >= switch-source-every [
;      set order-switchpoints fput ticks order-switchpoints
;    ]
;  ]
  
;  let diff (sum memory)
  let diff memory
  ifelse source-signal != 0 [
    set memory decision + memory
  ]
  [
;    ifelse (abs diff) > 1 [ ; Predictable
;      if (diff / (abs diff)) != decision [ ; Surprising
;                                           ;      set memory fput decision memory
;        set memory decision + memory
;      ]
;    ]
;    [
;      ;    set memory fput decision memory
;      set memory decision + memory
;    ]
  ]
  
  ask nlink-neighbors [
;    set diff (sum memory)
    set diff memory
    ifelse (abs diff) > 1 [ ; Predictable
      if (diff / (abs diff)) != decision [ ; Surprising
;        set memory fput decision memory
        set memory decision + memory
      ]
    ]
    [
;      set memory fput decision memory
      set memory decision + memory
    ]
  ]
end

to make-fatal-error
  ; Error was fatal. Agent "dies" to be replaced with a clone of another agent.
  set num-decisions 0
  set num-errors 0
  set agent-error-rate 0
  set memory 0
  set color red
  set agent-learning [agent-learning] of one-of other nodes
end

to update-error-plots
  set-current-plot "Agents' Errors"
  clear-plot
  ask nodes [plotxy agent-learning agent-error-rate]
end
@#$#@#$#@
GRAPHICS-WINDOW
218
10
628
441
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
99
0
99
0
0
1
ticks
30.0

INPUTBOX
10
129
104
189
Number-of-Nodes
100
1
0
Number

INPUTBOX
10
197
104
257
Link-Radius
20
1
0
Number

BUTTON
125
323
189
356
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

TEXTBOX
10
16
216
91
Chris's Information Cascades Network Demo
20
0.0
1

PLOT
924
655
1124
805
Degree Centrality
Degree
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
1202
654
1262
699
Average
mean-degree
2
1
11

MONITOR
1270
653
1330
698
Stdev
stdev-degree
3
1
11

MONITOR
1131
706
1193
751
Min
min-degree
17
1
11

MONITOR
1202
705
1262
750
Median
median-degree
17
1
11

MONITOR
1270
704
1330
749
Max
max-degree
17
1
11

TEXTBOX
1131
654
1199
702
Degree Centrality Statistics
13
0.0
1

BUTTON
461
479
533
512
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

PLOT
926
1224
1126
1374
Cliquishness
Node Cliquishness
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
1214
1236
1276
1281
Average
mean-cliquishness
3
1
11

MONITOR
1146
1286
1208
1331
Min
min-cliquishness
3
1
11

MONITOR
1283
1287
1343
1332
Max
max-cliquishness
3
1
11

TEXTBOX
1134
1228
1208
1282
Cliquishness\n(Triangles / 2-Stars)
13
0.0
1

BUTTON
333
553
398
586
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
652
40
1012
211
Adoption
Time (ticks)
# Infected
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Blue-Adopters" 1.0 0 -13345367 true "" ""
"Green-Adopters" 1.0 0 -10899396 true "" ""
"Red: No Adoption" 1.0 0 -2674135 true "" ""

MONITOR
652
216
709
261
# Blue
num-blue
17
1
11

MONITOR
714
216
773
261
# Green
num-green
17
1
11

MONITOR
776
216
833
261
# Red
num-red
17
1
11

MONITOR
1214
1287
1277
1332
Median
median-cliquishness
3
1
11

MONITOR
1283
1236
1340
1281
Stdev
stdev-cliquishness
3
1
11

MONITOR
690
655
777
700
# Components
num-components
17
1
11

INPUTBOX
1016
40
1099
100
Output-Every
100
1
0
Number

MONITOR
782
655
885
700
Largest component
max-component
17
1
11

MONITOR
690
703
777
748
Density
net-density
3
1
11

SWITCH
680
947
888
980
Calculate-Slow-Metrics
Calculate-Slow-Metrics
1
1
-1000

MONITOR
690
1022
793
1067
Clustering Coeff.
clust-coeff
3
1
11

MONITOR
690
1120
793
1165
Assortativity
assortativity
3
1
11

PLOT
923
810
1123
960
Degree of Separation
DOS
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
926
1378
1126
1528
Betweenness Centrality
Betweenness
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
782
703
885
748
Network Diameter
net-diameter
17
1
11

MONITOR
1197
810
1257
855
Average
mean-dos
3
1
11

MONITOR
1261
810
1318
855
Stdev
stdev-dos
3
1
11

MONITOR
1197
860
1257
905
Min
min-dos
3
1
11

MONITOR
1261
860
1318
905
Max
max-dos
3
1
11

TEXTBOX
1126
810
1197
858
Mean Degree of Separation
13
0.0
1

MONITOR
1217
1380
1277
1425
Average
mean-betweenness
3
1
11

MONITOR
1217
1429
1277
1474
Min
min-betweenness
3
1
11

MONITOR
1280
1429
1337
1474
Max
max-betweenness
3
1
11

TEXTBOX
1128
1378
1204
1426
Betweenness Centrality
13
0.0
1

BUTTON
329
479
394
512
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
397
479
458
512
2-D Grid
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

CHOOSER
10
261
213
306
Network-Type
Network-Type
"Complete" "4-Neighbour Grid" "8-Neighbour Grid" "Linear" "2-Neighbour Ring" "4-Neighbour Ring" "10-Neighbour Ring" "Star" "Random (Erdos-Renyi)" "Social Circles" "Scale-free (Barabasi-Albert)" "Scale-free (BOB)" "Modular (Caveman)" "Identity Search"
2

TEXTBOX
332
456
482
476
Reposition Nodes
16
0.0
1

INPUTBOX
108
197
201
257
Link-Chance
0.1
1
0
Number

INPUTBOX
10
310
103
370
Rewire-Chance
0
1
0
Number

MONITOR
126
135
190
180
# Links
num-nlinks
17
1
11

BUTTON
1016
107
1080
140
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
1016
144
1081
177
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
1234
39
1468
189
Local Variety
Proportion Neighbours Matching
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

TEXTBOX
1234
193
1478
228
Local Variety: What proportion of your neighbours have different values to you?
13
0.0
1

MONITOR
1232
231
1296
276
Min
min-localvariety
3
1
11

MONITOR
1300
231
1360
276
Average
mean-localvariety
3
1
11

MONITOR
1364
231
1421
276
Max
max-localvariety
3
1
11

TEXTBOX
1129
754
1334
810
Degree Centrality: a node's degree of connectivity = the number of links to other nodes.
13
0.0
1

TEXTBOX
1128
910
1332
966
Degrees of Separation: A node's DOS is the mean length of shortest paths to other nodes.
13
0.0
1

TEXTBOX
1134
1338
1385
1386
Cliquishness: Proportion of 2-stars with node at centre that are also triangles.
13
0.0
1

TEXTBOX
1129
1477
1368
1541
Betweenness: Mean proportion of shortest paths between pairs of other nodes that go via this node.
13
0.0
1

MONITOR
690
1071
793
1116
Network Constraint
net-constraint
3
1
11

BUTTON
1017
181
1135
214
Reset Agents
setup-states
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
492
553
610
586
Reset Agents
setup-states
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
333
528
483
548
Simulation Controls:
16
0.0
1

INPUTBOX
511
594
610
654
Max-ticks
100000
1
0
Number

CHOOSER
333
593
507
638
When-to-Halt
When-to-Halt
"Max ticks reached"
0

TEXTBOX
691
625
841
645
Network Metrics:
16
0.0
1

TEXTBOX
692
992
876
1013
Slow Network Metrics:
16
0.0
1

TEXTBOX
921
995
1071
1015
Slow Node Metrics:
16
0.0
1

TEXTBOX
924
622
1074
642
Node Metrics:
16
0.0
1

PLOT
922
1032
1122
1182
Structural Constraint
Constraint
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

BUTTON
724
847
788
880
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

MONITOR
1194
1032
1254
1077
Average
mean-constraint
3
1
11

MONITOR
1194
1082
1254
1127
Min
min-constraint
3
1
11

MONITOR
1259
1081
1316
1126
Max
max-constraint
3
1
11

TEXTBOX
1125
1032
1192
1070
Structural Constraint
13
0.0
1

TEXTBOX
1126
1133
1367
1213
Constraint: Burt's measure of the mean proportion of a node's network resources invested in particular neighbours or near-neighbours.
13
0.0
1

PLOT
1334
653
1534
803
Log-Log Plot of Degree
log Degree
log # Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

INPUTBOX
237
813
339
873
New-Node-Chance
0.1
1
0
Number

INPUTBOX
342
750
444
810
Link-Batch-Size
10
1
0
Number

INPUTBOX
237
750
339
810
Num-Initial-Pairs
1
1
0
Number

INPUTBOX
342
812
444
872
Link-Memory
2
1
0
Number

TEXTBOX
241
727
445
745
For Scale-free (BOB) network:
13
0.0
1

INPUTBOX
7
1120
109
1180
Network-Seed
0
1
0
Number

TEXTBOX
12
1088
245
1113
Random number stream seeds:
16
0.0
1

BUTTON
56
1189
160
1222
Print Seeds
print-seeds
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
403
227
427
For Information Cascades:
16
0.0
1

INPUTBOX
9
480
142
540
Source-Chance
0.6
1
0
Number

INPUTBOX
149
480
290
540
Learning-Chance
0.9
1
0
Number

INPUTBOX
9
542
142
602
Noise-Chance
0
1
0
Number

INPUTBOX
149
542
290
602
Switch-Source-Every
20000
1
0
Number

MONITOR
945
233
1101
286
Proportion Info Errors
num-info-errors / ticks
3
1
13

PLOT
1234
357
1465
586
Agents' Errors
Learning Chance
Error Rate
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
1234
316
1409
349
Update Agents' Errors
update-error-plots
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
9
606
142
666
Fatal-Chance
0
1
0
Number

PLOT
947
319
1209
486
Error Rate Evolution
Time (ticks)
Error Rate
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -16777216 true "" ""
"Median" 1.0 0 -2674135 true "" ""

MONITOR
946
512
1003
557
Mean
mean-error-rate
3
1
11

MONITOR
1006
512
1063
557
Min
min-error-rate
3
1
11

MONITOR
1066
512
1123
557
Median
median-error-rate
3
1
11

MONITOR
1126
512
1183
557
Max
max-error-rate
3
1
11

TEXTBOX
945
293
1095
313
Agents' Error Rates:
16
0.0
1

PLOT
660
323
860
473
Learning Histogram
Learning Chance
Frequency
0.0
1.1
0.0
1.0
true
false
"" ""
PENS
"default" 0.05 1 -16777216 true "" ""

MONITOR
660
476
717
521
Mean
mean-learning
3
1
11

MONITOR
719
476
776
521
Min
min-learning
3
1
11

MONITOR
778
476
835
521
Median
median-learning
3
1
11

MONITOR
837
476
894
521
Max
max-learning
3
1
11

CHOOSER
9
433
197
478
Initial-Learning-Chance
Initial-Learning-Chance
"Homogeneous population" "Uniformly distributed"
0

INPUTBOX
114
1120
233
1180
Sim-Seed
0
1
0
Number

TEXTBOX
662
292
871
315
Agents' Learning Chances:
16
0.0
1

TEXTBOX
655
10
805
30
Simulation Results:
16
0.0
1

TEXTBOX
1104
68
1140
86
ticks
13
0.0
1

TEXTBOX
11
100
196
127
Basic Network Definition:
16
0.0
1

BUTTON
401
553
488
586
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

BUTTON
536
479
642
512
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
14
695
243
719
Further Network Parameters:
16
0.0
1

TEXTBOX
11
724
232
744
For Modular (Caveman) networks:
13
0.0
1

INPUTBOX
8
747
163
807
Num-Modules
5
1
0
Number

INPUTBOX
9
811
164
871
Num-Inter-Modular-Links
1
1
0
Number

TEXTBOX
9
907
214
926
For Identity Search networks:
13
0.0
1

INPUTBOX
10
932
165
992
Group-Size-g
25
1
0
Number

INPUTBOX
168
933
323
993
Branching-Ratio-b
2
1
0
Number

INPUTBOX
167
995
322
1055
Number-Of-Hierarchies-H
2
1
0
Number

INPUTBOX
9
995
164
1055
Number-Of-Levels-L
3
1
0
Number

INPUTBOX
327
996
482
1056
Homophily-alpha
1
1
0
Number

MONITOR
328
936
467
989
Resulting # Nodes:
group-size-g * (branching-ratio-b ^ (number-of-levels-l - 1))
17
1
13

BUTTON
632
887
755
920
Print Node Metrics
output-node-metrics
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
760
887
905
920
Print Network Metrics
output-network-metrics
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
669
1195
818
1228
Output to VNA file
output-network-to-vna-file
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
559
1240
913
1293
Most Recent Output Filename
output-filename
17
1
13

TEXTBOX
691
758
841
776
Network Centralization:
13
0.0
1

MONITOR
688
781
748
826
Degree
degree-centralization
3
1
11

MONITOR
778
779
847
824
Closeness
closeness-centralization
3
1
11

@#$#@#$#@
# CHRIS'S INFORMATION CASCADES NETWORK DEMO

An extension to networks of the ideas about information cascades in Bikhchandani et al. (1992; 1998). See also Banerjee (1992).

Creates a network from one of several popular network types. 
Calculates various metrics for nodes and the network itself. 
Simulates decision making within the network. Decision making is based on the Information Cascades models of Bikhchandani et al. In our version here, each agent keeps a record in memory of neighbours' past decisions. An agent adds to its memory only if a neighbour's decision seems surprising to that agent, given the current state of its memory. An agent makes its own decisions either on the basis of its memory (a form of learning from others), or by consulting its own private source of information (a form of perception). Agents' decisions represent judgments about a common environmental reality and as such can be scored as successful or an error. The environment is subject to turbulence, whereby its state changes. Perceptual signals from the environment have a given degree of reliability.

This program (C) Christopher J Watts, 2014. See below for terms and conditions of use. 

This program was developed for Chapter 3 of the book:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## HOW IT WORKS

Clicking "Setup" creates a network.

Clicking "Go" runs a series of agent decisions, one agent decision per tick.

Clicking "Reset Agents" keeps the existing network, but causes agents to lose their memory and current adoption decision. Thus another sequence of decisions can be simulated on the same network as before.

## HOW TO USE IT (1): CREATING A NETWORK

In general, to create a network, enter its size in number-of-nodes, then choose a network-type from the drop-down list. (Some of these network types require extra parameters.) 

The types are:

  * "Complete" - every node connects to every other node  
  * "4-Neighbour Grid" - nodes are arranged on a regular 2-dimensional grid, with each node connecting to 4 neighbours (up, down, left, right) providing that these are available. Nodes at the edge have fewer neighbours.  
  * "8-Neighbour Grid" - nodes are arranged on a regular 2-dimensional grid, with each node connecting to 8 neighbours (up, down, left, right, plus diagonals).  
  * "Linear" - nodes form a single line.  
  * "n-Neighbour Ring" - nodes are arranged in a ring, with each node connected to its n/2 nearest neighbours on each side.  
  * "Star" - one central node (a hub) is connected to each of the other nodes, who are not themselves interconnected.  
  * "Random (Erdos-Renyi)" - links are made between random pairs of nodes. The parameter "link-chance" controls how many links are added (actually, by setting the proportion of node pairs with a link present).  
  * "Social Circles" - nodes are given random x and y coordinates, then links are added from each node to every other node within distance "link-radius" of it.  
  * "Scale-free (Barabasi-Albert)" - starting with a linked pair of nodes, a network is grown by adding one new node at a time. Each new node is linked to an existing node, chosen with preference for the number of links the existing node has. The resulting distribution of links to nodes is known to be scale-free, or follow a power law.  
  * "Scale-free (BOB)" - based on the method of Bentley, Ormerod & Batty (2009). (Hence we call it "BOB".) Starting with a given number of linked pair of nodes, a network is grown by adding batches of new links, each with a given chance of linking a new node also. Links to existing nodes are chosen by copying a recent link, where "recent" is defined by "link-memory". Depending on the BOB model parameters, the resulting distribution of links to nodes may be scale-free (Barabasi-Albert is a special case), but can also contain clustering.
  * "Modular (Caveman)" - based on the design of Duncan Watts et al. Each node is assigned to one of a given number of modules. Nodes are initially connected to every other node in their module. Then in each module, one node has a link rewired to a node in the next module. The effect is few inter-modular links ("weak ties") and many intra-modular links, giving high clustering within the module.
  * "Identity Search" - based on the design by Watts, D., Dodds & Newman (2002). Nodes are given identities, based on their membership of groups arranged into hierarchies. The network is generated by adding links with a given preference for low social distance. The social distance between two nodes is the minimum distance across hierarchies. A distance with a hierarchy is the number of levels above the base at which the two nodes' groups have a common branch point. A network generated in this way has the property of being easily searchable by choosing neighbours closest in social distance to a target node. Killworth & Bernard suggested this was the mechanism at work during Milgram's famous "six-degrees-of-separation" chain letters experiments.

In addition to the processes defined by network type, a given number of randomly chosen links may be rewired to randomly chosen nodes. "rewire-chance" determines what proportion of the links receive this rewiring.

Various network metrics are calculated, including the number of network components. (Nodes connected by direct or indirect paths belong to the same component.) Some network metrics will only make sense if the network consists of one single component. There is an option to omit some of the metrics (constraint, betweenness, clustering and cliquishness), due to their requiring particularly long computation.

## HOW TO USE IT (2): SIMULATING INFORMATION CASCADES

If the "Setup" or "Reset Agents" buttons are clicked, agents are initialised with no decision concerning adoption (state "red") and no memory of past actions.

Click "Go" to start a simulation run. 

Each time step, one randomly chosen agent makes a new binary decision: e.g. whether or not to adopt some innovation.

Each agent has a given chance of using "learning-from-others" in its decision:

If using learning:
Each agent keeps a record in memory of its own and its neighbours' past decisions. The agent now consults this memory. If the balance of memory >1 or <-1, then the agent chooses the action 1 or -1 respectively. Otherwise, the agent will consult its private signal and add the value from that to the value from its memory. If the total of memory + signal is >=1 or <=-1, then the agent chooses the action 1 or -1 respectively. If the total = 0, then the agent chooses one of 1 or -1 with 50:50 chances.

If not using learning:
The agent chooses an action based on its private signal only.

Actions expressed:
Once an agent has chosen its action, with a given chance random noise can cause that action to be misexpressed as its opposite. The (potentially mis-)expressed action is publicly known to all the agent's neighbours.

Updating memories:
An agent adds to its memory only if a neighbour's decision seems surprising to that agent, given the current state of its own memory.

With a given period of ticks, the environment switches from prefering +1 to prefering -1, or vice versa. Thus if agents are not to be out-of-sync with the environment they must change their actions. Every decision made in which the action chosen is not that currently prefered by the environment is classified as an error. The proportion of decisions resulting in errors is updated.

The simulation runs until the number of time ticks has reached the "max-ticks" value. 

## THINGS TO NOTICE

Different network structures have different properties. This includes effects on the ability of a network to learn about a common environment. After each simulation run, look at the monitor "Proportion Info Errors". The lower this is, the better the learning performance.

## THINGS TO TRY

BehaviorSpace contains various experiments to try.

Try different network architectures. Compare final outcomes with the properties of the networks.

Try different problem definitions. In particular, the environment could switch state at different frequencies: e.g. every 200, 2000, 200000 ticks instead of every 20000.

Try different numbers of agents (nodes). What is the relation between performance and network size?

Try different numbers of links (network densities).

## EXTENDING THE MODEL

What if agents were making multiple decisions? With interdependencies between these? Some of the features of models of social influence (e.g. preference for similarity when imitating others) and organisational learning could be added.

## RELATED MODELS

Compare other models on the diffusion of innovations and on collective learning. Compare also signals networks in computer science.

## CREDITS AND REFERENCES

This program (C) Christopher J Watts, 2014. See below for terms and conditions of use. 
See Help menu for details "About NetLogo" itself.

### INFORMATION CASCADES REFERENCES

Banerjee, A. V. (1992). "A Simple Model of Herd Behavior." The Quarterly Journal of Economics, 107(3), 797-817. doi: 10.2307/2118364

Bikhchandani, S., Hirshleifer, D., & Welch, I. (1992). "A Theory of Fads, Fashion, Custom, and Cultural Change as Informational Cascades." Journal of Political Economy, 100(5), 992-1026. 

Bikhchandani, S., Hirshleifer, D., & Welch, I. (1998). "Learning from the behavior of others: Conformity, fads, and informational cascades." Journal of Economic Perspectives, 12(3), 151-170. 


### NETWORK-RELATED REFERENCES

Barabási, A.-L., & Albert, R. (1999). "Emergence of scaling in random networks." Science, 286(5439), 509-512. doi: 10.1126/science.286.5439.509

Bentley, R. A., Ormerod, P., & Batty, M. (2011). "Evolving social influence in large populations." Behavioral Ecology and Sociobiology, 65(3), 537-546. doi: 10.1007/s00265-010-1102-1

Brandes, U., (2001) "A faster algorithm for betweenness centrality." Journal of
Mathematical Sociology 25 (2), 163–177.

Burt, R. S. (2007). "Brokerage and closure : an introduction to social capital." Oxford: Oxford University Press.

Erdős, P., & Rényi, A. (1959). "On random graphs I." Publicationes Mathematicae, 6, 290-297. 

Hamill, L., & Gilbert, N. (2009). "Social Circles: A Simple Structure for Agent-Based Social Network Models." Jasss-the Journal of Artificial Societies and Social Simulation, 12(2). doi: 3

Kauffman, S. A. (1995). "At home in the universe: the search for laws of self-organization and complexity." New York ; Oxford: Oxford University Press.

Killworth, P. D., & Bernard, H. R. (1978). "The Reversal Small-World Experiment." Social Networks, 1, 159-192. 

Wasserman, S., & Faust, K. (1994). "Social network analysis: methods and applications." Cambridge: Cambridge University Press.

Watts, D. J., Dodds, P. S., & Newman, M. E. J. (2002). Identity and search in social networks. Science, 296(5571), 1302-1305. doi: 10.1126/science.1070120

Watts, D. J., & Strogatz, S. H. (1998). "Collective dynamics of 'small-world' networks." Nature, 393(6684), 440-442. doi: 10.1038/30918

## OUR TERMS AND CONDITIONS OF USE

This program was developed for the book:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

If you use this program in your work, please cite the book, as well as giving the URL for the website from which you downloaded the program and the date on which you downloaded it. A suitable form of citation for the program is:

Watts, Christopher (2014) “Name-of-file”. Retrieved 31 January 2014 from http://www.simian.ac.uk/resources/models/simulating-innovation .

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
  <experiment name="experiment-InfoCascades" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>clust-coeff</metric>
    <metric>net-constraint</metric>
    <metric>assortativity</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>mean-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>(num-info-errors / ticks)</metric>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-chance">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fatal-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;Scale-free (Barabasi-Albert)&quot;"/>
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Linear&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-learning-chance">
      <value value="&quot;Homogeneous population&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="learning-chance">
      <value value="1"/>
      <value value="0.95"/>
      <value value="0.9"/>
      <value value="0.85"/>
      <value value="0.8"/>
      <value value="0.75"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Max ticks reached&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-chance">
      <value value="0"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-source-every">
      <value value="20000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-InfoCascades-Density" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>clust-coeff</metric>
    <metric>net-constraint</metric>
    <metric>assortativity</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>mean-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>(num-info-errors / ticks)</metric>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-chance">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fatal-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-learning-chance">
      <value value="&quot;Homogeneous population&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="learning-chance">
      <value value="1"/>
      <value value="0.95"/>
      <value value="0.9"/>
      <value value="0.85"/>
      <value value="0.8"/>
      <value value="0.75"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Max ticks reached&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-chance">
      <value value="0"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-source-every">
      <value value="20000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-InfoCascades-NetSize" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>clust-coeff</metric>
    <metric>net-constraint</metric>
    <metric>assortativity</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>mean-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>(num-info-errors / ticks)</metric>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fatal-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-chance">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-learning-chance">
      <value value="&quot;Homogeneous population&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="learning-chance">
      <value value="1"/>
      <value value="0.95"/>
      <value value="0.9"/>
      <value value="0.85"/>
      <value value="0.8"/>
      <value value="0.75"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Max ticks reached&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-chance">
      <value value="0"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-source-every">
      <value value="20000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-InfoCascades-StrogatzWatts" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>clust-coeff</metric>
    <metric>net-constraint</metric>
    <metric>assortativity</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>mean-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>(num-info-errors / ticks)</metric>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-chance">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fatal-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.0010"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;4-Neighbour Ring&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-learning-chance">
      <value value="&quot;Homogeneous population&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="learning-chance">
      <value value="1"/>
      <value value="0.95"/>
      <value value="0.9"/>
      <value value="0.85"/>
      <value value="0.8"/>
      <value value="0.75"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Max ticks reached&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-source-every">
      <value value="20000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-InfoCascades-2000" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>clust-coeff</metric>
    <metric>net-constraint</metric>
    <metric>assortativity</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>mean-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>(num-info-errors / ticks)</metric>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-chance">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fatal-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;Scale-free (Barabasi-Albert)&quot;"/>
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Linear&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-learning-chance">
      <value value="&quot;Homogeneous population&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="learning-chance">
      <value value="1"/>
      <value value="0.95"/>
      <value value="0.9"/>
      <value value="0.85"/>
      <value value="0.8"/>
      <value value="0.75"/>
      <value value="0.7"/>
      <value value="0.6"/>
      <value value="0.5"/>
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Max ticks reached&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-chance">
      <value value="0"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-source-every">
      <value value="2000"/>
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
