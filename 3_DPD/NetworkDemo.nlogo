;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Chris's Network Demo
; This version (C) Christopher J Watts, 2014
; See Info tab for terms and conditions of use.
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
  
  output-filename
]


breed [nodes node]
undirected-link-breed [nlinks nlink]

nodes-own [
  infection
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
  
  setup-infections
  
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
;; infections: up to 2 competing technologies/ideas/diseases diffuse from distinct origins
to setup-infections
  reset-ticks
  
  setup-rng-sim
  init-states-allr
  if (initial-states-method = "1 Green, 1 Blue") [ init-states-1b1g ]
  if (initial-states-method = "1 Green") [ init-states-1g ]
  if (initial-states-method = "1 Blue") [ init-states-1b ]
  if (initial-states-method = "Random Green & Blue") [ init-states-randomgb ]
  if (initial-states-method = "1 Green, plus friends") [ init-states-1plusfriends-g ]
  if (initial-states-method = "1 Green, 1 Blue, plus friends") [ init-states-2plusfriends-gb ]
  if (initial-states-method = "10% Green") [ init-states-10pc-g ]
  
  setup-infection-plots
  calc-localvariety
  update-plot
  
end

to make-node-green
  set infection 1
  set color green
end

to make-node-blue
  set infection 2
  set color blue
end

to init-states-1b1g
  ; 1 initial green; 1 blue
  ask one-of nodes [
    make-node-green
    set green-origin self
    ask one-of other nodes [
      make-node-blue
      set blue-origin self
    ]
  ]
  set num-red ((count nodes) - 2)
  set num-green 1
  set num-blue 1
end  

to init-states-1g
  ; 1 initial green
  ask one-of nodes [
    make-node-green
    set green-origin self
  ]
  set num-red ((count nodes) - 1)
  set num-green 1
  set num-blue 0
end  

to init-states-1b
  ; 1 initial blue
  ask one-of nodes [
    make-node-blue
    set blue-origin self
  ]
  set num-red ((count nodes) - 1)
  set num-green 0
  set num-blue 1
end  

to init-states-1plusfriends-g
  ; 1 initial green
  ask one-of nodes [
    make-node-green
    set green-origin self
    ask nlink-neighbors [
      make-node-green
    ]
  ]
  set num-red ((count nodes with [infection = 0]) )
  set num-green ((count nodes with [infection = 1]) )
  set num-blue ((count nodes with [infection = 2]) )
end  

to init-states-2plusfriends-gb
  ; 1 initial green, 1 initial blue, plus their neighbours
  ask one-of nodes [
    set color green
    set infection 1
    set green-origin self
    ask one-of other nodes [
      make-node-blue 
      set blue-origin self
      ask nlink-neighbors [ ; Blue's neighbours
        if self != green-origin [
          ifelse infection = 1 [
            ifelse random 2 < 1 [ make-node-green ]
            [ make-node-blue ]
          ]
          [ make-node-blue ]
        ]
      ]
    ]
    ask nlink-neighbors [ ; Green's neighbours
      if self != blue-origin [
        ifelse infection = 2 [
          ifelse random 2 < 1 [ make-node-green ]
          [ make-node-blue ]
        ]
        [ make-node-green ]
      ]
    ]
  ]
  set num-red ((count nodes with [infection = 0]) )
  set num-green ((count nodes with [infection = 1]) )
  set num-blue ((count nodes with [infection = 2]) )
end  

to init-states-10pc-g
  ; 10% nodes green
  ask n-of (int ((count nodes) / 10)) nodes [
    make-node-green
  ]
  set num-red ((count nodes with [infection = 0]) )
  set num-green ((count nodes with [infection = 1]) )
  set num-blue ((count nodes with [infection = 2]) )
end  

to init-states-allr
  ; No initial green or blue
  ask nodes [
    set color red
    set infection 0
  ]
  set num-red ((count nodes) )
  set num-green 0
  set num-blue 0
end  

to init-states-randomgb
  ; No initial green or blue
  ask nodes [
    ifelse random 2 = 0 [ make-node-green ]
    [ make-node-blue ]
  ]
  set num-red ((count nodes with [infection = 0]) )
  set num-green ((count nodes with [infection = 1]) )
  set num-blue ((count nodes with [infection = 2]) )
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  if end-sim [stop]
  
  if infection-method = "Infection" [ infect ]
  if infection-method = "Complex contagion" [ infect-complex-contagion ]
  if infection-method = "Infection + Targeting" [
    ifelse (random-float 1) < infection-chance [
      infect ]
    [ ifelse (random-float 1) < 0.5 [ target-random ] [target-for-links]
    ]
  ]
  if infection-method = "Infection + Targeting + Friends" [
    ifelse (random-float 1) < infection-chance [
      infect ]
    [ ifelse (random-float 1) < 0.5 [ target-random-and-friends ] [target-for-links-and-friends]
    ]
  ]
  if infection-method = "Target random nodes" [ target-random ]
  if infection-method = "Target for links" [ target-for-links ]
  if infection-method = "Target random nodes + for links" [ 
    ifelse (ticks mod 2 = 0) [ target-random ]
    [ target-for-links ]
  ]
  if infection-method = "Target random nodes, + friends" [ target-random-and-friends ]
  if infection-method = "Target for links, + friends" [ target-for-links-and-friends ]
  if infection-method = "Target random nodes + for links, + friends" [ 
    ifelse (ticks mod 2 = 0) [ target-random-and-friends ]
    [ target-for-links-and-friends ]
  ]
  if infection-method = "Ising Model" [ go-ising ]
  
  tick
  if ticks mod output-every = 0 [update-plot]
  
  if end-sim [
    update-plot
    stop]
  
end

to-report end-sim
  let halt-answer (ticks >= max-ticks)
  if when-to-halt = "Largest component full" [
    set halt-answer (halt-answer or (max-component <= (num-blue + num-green)))
  ]
  report halt-answer
end

to infect
  ask one-of nodes [
    if ((infection = 0) and (degree > 0)) [
      let newstate 0
      let newcolor red
      if (count nlink-neighbors) > 0 [
        ask one-of nlink-neighbors [
          if infection > 0 [
            ifelse infection = 1 [
              set num-green num-green + 1
            ]
            [
              set num-blue num-blue + 1
            ]
            set num-red num-red - 1
            set newstate infection
            set newcolor color
          ]
        ]
        set infection newstate
        set color newcolor
        calc-node-localvariety
        ask nlink-neighbors [ calc-node-localvariety ]
      ]
    ]
    
  ]
end

to infect-complex-contagion
  ask one-of nodes [
    if ((infection = 0) and (degree > 0)) [
      let newstate 0
      let newcolor red
      let num-blue-neighbours (count nlink-neighbors with [color = blue])
      let num-green-neighbours (count nlink-neighbors with [color = green])
      ifelse (num-blue-neighbours >= infection-threshold) 
      and (num-green-neighbours >= infection-threshold)  [
        ifelse random (num-blue-neighbours + num-green-neighbours) < num-green-neighbours [
          set newstate 1
          set newcolor green
          set num-green num-green + 1
        ]
        [
          set newstate 2
          set newcolor blue
          set num-blue num-blue + 1
        ]
      ]
      [
        if (num-blue-neighbours >= infection-threshold) [
          set newstate 2
          set newcolor blue
          set num-blue num-blue + 1
        ]
        if (num-green-neighbours >= infection-threshold) [
          set newstate 1
          set newcolor green
          set num-green num-green + 1
        ]
      ]
      if infection != newstate [
        set infection newstate
        set color newcolor
        set num-red num-red - 1
        calc-node-localvariety
        ask nlink-neighbors [ calc-node-localvariety ]
      ]
    ]
  ]
end

to target-random
  ask one-of nodes [
    if (infection = 0) [
      set num-blue num-blue + 1
      set num-red num-red - 1
      set infection 2
      set color blue
      calc-node-localvariety
      ask nlink-neighbors [ calc-node-localvariety ]
    ]
  ]
end

to target-random-and-friends
  ask one-of nodes [
    if (infection = 0) [
      set num-blue num-blue + 1
      set num-red num-red - 1
      set infection 2
      set color blue
      calc-node-localvariety
      ask nlink-neighbors [ calc-node-localvariety ]
    ]
    ask nlink-neighbors [
      if (infection = 0) [
        set num-blue num-blue + 1
        set num-red num-red - 1
        set infection 2
        set color blue
        calc-node-localvariety
        ask nlink-neighbors [ calc-node-localvariety ]
      ]
    ]
  ]
end

to target-for-links
  ask one-of nodes [
    if (count nlink-neighbors) > 0 [
      ask one-of nlink-neighbors [
        if (infection = 0) [
          set num-green num-green + 1
          set num-red num-red - 1
          set infection 1
          set color green
          calc-node-localvariety
          ask nlink-neighbors [ calc-node-localvariety ]
        ]
      ]
    ]
  ]
end

to target-for-links-and-friends
  ask one-of nodes [
    if (count nlink-neighbors) > 0 [
      ask one-of nlink-neighbors [
        if (infection = 0) [
          set num-green num-green + 1
          set num-red num-red - 1
          set infection 1
          set color green
          calc-node-localvariety
          ask nlink-neighbors [ calc-node-localvariety ]
        ]
        ask nlink-neighbors [
          if (infection = 0) [
            set num-green num-green + 1
            set num-red num-red - 1
            set infection 1
            set color green
            calc-node-localvariety
            ask nlink-neighbors [ calc-node-localvariety ]
          ]
        ]
      ]
    ]
  ]
end

to go-ising
  ; Ising Model - currently no weights on links
  ask one-of nodes [
    let newstate 0
    let weightedsum sum [(infection  * 2) - 3] of nlink-neighbors 
    let expon (-2) * weightedsum / ising-temperature
    ifelse (abs expon) > 500 [ ; Exponent might be too large
      ifelse expon > 0 [
        set newstate 1
      ]
      [
        set newstate 2
      ]
    ]
    [
      ifelse random-float 1 < (1 / (1 + (Exp expon))) [
        set newstate 2
      ]
      [
        set newstate 1
      ]
    ]
    if infection != newstate [
      ifelse newstate = 1 [
        set color green
        set num-blue num-blue - 1
        set num-green num-green + 1
      ]
      [
        set color blue
        set num-blue num-blue + 1
        set num-green num-green - 1
      ]
      set infection newstate
    ]
  ]
end

     
to calc-localvariety
  ask nodes [ calc-node-localvariety ]
end

to calc-node-localvariety
  ifelse (count my-nlinks) > 0 [
    let root-infection infection
    set localvariety  ((count nlink-neighbors with [infection != root-infection]) / (count nlink-neighbors))
  ]
  [
    set localvariety  0
  ]
  
end
  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-plot
  set-current-plot "Infected"
  set-current-plot-pen "green-infected"
  plotxy ticks num-green
  set-current-plot-pen "blue-infected"
  plotxy ticks num-blue
  set-current-plot-pen "red-uninfected"
  plotxy ticks num-red
  
  set-current-plot "Local Variety"
  set-plot-x-range 0 1.1
  set-plot-pen-interval 0.1
  histogram [localvariety] of nodes
  set mean-localvariety mean [localvariety] of nodes
  set min-localvariety min [localvariety] of nodes
  set max-localvariety max [localvariety] of nodes
  
end
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
  

to setup-infection-plots
  set-current-plot "Infected"
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
      ask (one-of nodes with [(component = cur-module) and (1 < count nlink-neighbors with [component = cur-module])]) [
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
; Ulrik Brandes's betweenness algorithm (Brandes, 2001)
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
  let tempnode nobody
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
  file-print "ID,State"
  
  ; Node attributes
  foreach sort nodes [
    ask ? [
      file-write who
      file-write infection
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
  print (word "Who, State, Component, Degree, Closeness, Betweenness, Constraint, Cliquishness, Degree of Separation, Reach, Local Variety")
  
  foreach sort nodes [
    ask ? [
      print (word who ", " infection ", " component ", " degree ", " closeness ", " betweenness ", " constraint ", " cliquishness ", " dos ", " reach ", " localvariety)
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
@#$#@#$#@
GRAPHICS-WINDOW
215
10
625
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
5
84
99
144
Number-of-Nodes
100
1
0
Number

INPUTBOX
5
152
99
212
Link-Radius
40
1
0
Number

BUTTON
120
278
184
311
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
8
10
206
39
Chris's Network Demo
20
0.0
1

PLOT
857
331
1057
481
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
1135
330
1195
375
Average
mean-degree
2
1
11

MONITOR
1203
329
1263
374
Stdev
stdev-degree
3
1
11

MONITOR
1064
382
1126
427
Min
min-degree
17
1
11

MONITOR
1135
381
1195
426
Median
median-degree
17
1
11

MONITOR
1203
380
1263
425
Max
max-degree
17
1
11

TEXTBOX
1065
335
1133
383
Degree Centrality Statistics
13
0.0
1

BUTTON
382
476
454
509
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
859
888
1059
1038
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
1148
903
1210
948
Average
mean-cliquishness
3
1
11

MONITOR
1080
953
1142
998
Min
min-cliquishness
3
1
11

MONITOR
1217
954
1277
999
Max
max-cliquishness
3
1
11

TEXTBOX
1067
900
1153
964
Cliquishness\n(Triangles / 2-Stars)
13
0.0
1

BUTTON
33
381
98
414
Infect
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
633
43
993
214
Infected
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
"Blue-Infected" 1.0 0 -13345367 true "" ""
"Green-Infected" 1.0 0 -10899396 true "" ""
"Red-Uninfected" 1.0 0 -2674135 true "" ""

MONITOR
633
219
690
264
# Blue
num-blue
17
1
11

MONITOR
695
219
754
264
# Green
num-green
17
1
11

MONITOR
757
219
814
264
# Red
num-red
17
1
11

MONITOR
1148
954
1211
999
Median
median-cliquishness
3
1
11

MONITOR
1217
903
1274
948
Stdev
stdev-cliquishness
3
1
11

MONITOR
632
335
719
380
# Components
num-components
17
1
11

INPUTBOX
997
43
1080
103
Output-Every
10
1
0
Number

MONITOR
724
335
827
380
Largest component
max-component
17
1
11

MONITOR
632
383
719
428
Density
net-density
3
1
11

SWITCH
301
574
509
607
Calculate-Slow-Metrics
Calculate-Slow-Metrics
0
1
-1000

MONITOR
636
549
739
594
Clustering Coeff.
clust-coeff
3
1
11

MONITOR
636
647
739
692
Assortativity
assortativity
3
1
11

PLOT
856
486
1056
636
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
859
1061
1059
1211
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
724
383
827
428
Network Diameter
net-diameter
17
1
11

MONITOR
1130
486
1190
531
Average
mean-dos
3
1
11

MONITOR
1194
486
1251
531
Stdev
stdev-dos
3
1
11

MONITOR
1130
536
1190
581
Min
min-dos
3
1
11

MONITOR
1194
536
1251
581
Max
max-dos
3
1
11

TEXTBOX
1059
486
1130
534
Mean Degree of Separation
13
0.0
1

MONITOR
1148
1065
1208
1110
Average
mean-betweenness
3
1
11

MONITOR
1148
1114
1208
1159
Min
min-betweenness
3
1
11

MONITOR
1212
1114
1269
1159
Max
max-betweenness
3
1
11

TEXTBOX
1061
1061
1141
1109
Betweenness Centrality
13
0.0
1

BUTTON
250
476
315
509
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
318
476
379
509
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
5
216
208
261
Network-Type
Network-Type
"Complete" "4-Neighbour Grid" "8-Neighbour Grid" "Linear" "2-Neighbour Ring" "4-Neighbour Ring" "10-Neighbour Ring" "Star" "Random (Erdos-Renyi)" "Social Circles" "Scale-free (Barabasi-Albert)" "Scale-free (BOB)" "Modular (Caveman)" "Identity Search"
12

TEXTBOX
255
450
405
470
Reposition Nodes
16
0.0
1

INPUTBOX
103
152
196
212
Link-Chance
0.3
1
0
Number

INPUTBOX
5
265
98
325
Rewire-Chance
0
1
0
Number

MONITOR
121
90
185
135
# Links
num-nlinks
17
1
11

BUTTON
997
110
1061
143
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
997
147
1062
180
Infect
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
1111
42
1396
192
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
1111
196
1351
244
Local Variety: What proportion of your neighbours have different values to you?
13
0.0
1

MONITOR
1112
235
1176
280
Min
min-localvariety
3
1
11

MONITOR
1180
235
1240
280
Average
mean-localvariety
3
1
11

MONITOR
1244
235
1301
280
Max
max-localvariety
3
1
11

TEXTBOX
1062
430
1267
486
Degree Centrality: a node's degree of connectivity = the number of links to other nodes.
13
0.0
1

TEXTBOX
1061
586
1265
642
Degrees of Separation: A node's DOS is the mean length of shortest paths to other nodes.
13
0.0
1

TEXTBOX
1067
1002
1294
1050
Cliquishness: Proportion of 2-stars with node at centre that are also triangles.
13
0.0
1

TEXTBOX
1062
1160
1282
1224
Betweenness: Mean proportion of shortest paths between pairs of other nodes that go via this node.
13
0.0
1

MONITOR
636
598
739
643
Network Constraint
net-constraint
3
1
11

CHOOSER
3
473
209
518
Infection-Method
Infection-Method
"Infection" "Complex contagion" "Infection + Targeting" "Infection + Targeting + Friends" "Ising Model" "Target random nodes" "Target for links" "Target random nodes + for links" "Target random nodes, + friends" "Target for links, + friends" "Target random nodes + for links, + friends"
0

BUTTON
998
184
1094
217
Clear infection
setup-infections
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
100
381
199
414
Clear infection
setup-infections
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
354
207
374
Simulate epidemics
16
0.0
1

INPUTBOX
3
523
102
583
Infection-Chance
0
1
0
Number

INPUTBOX
3
585
102
645
Ising-Temperature
4
1
0
Number

INPUTBOX
3
696
102
756
Max-Ticks
100000
1
0
Number

CHOOSER
3
648
177
693
When-To-Halt
When-To-Halt
"Max ticks reached" "Largest component full"
1

TEXTBOX
633
306
822
326
Network Metrics:
16
0.0
1

TEXTBOX
634
521
809
546
Slow Network Metrics:
16
0.0
1

TEXTBOX
860
670
1010
690
Slow Node Metrics:
16
0.0
1

TEXTBOX
856
306
1006
326
Node Metrics:
16
0.0
1

PLOT
858
705
1058
855
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
637
802
701
835
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
1130
703
1190
748
Average
mean-constraint
3
1
11

MONITOR
1130
753
1190
798
Min
min-constraint
3
1
11

MONITOR
1194
754
1251
799
Max
max-constraint
3
1
11

TEXTBOX
1061
705
1128
743
Structural Constraint
13
0.0
1

TEXTBOX
1062
806
1278
886
Constraint: Burt's measure of the mean proportion of a node's network resources invested in particular neighbours or near-neighbours.
13
0.0
1

INPUTBOX
104
523
210
583
Infection-Threshold
2
1
0
Number

CHOOSER
3
425
208
470
Initial-States-Method
Initial-States-Method
"1 Green, 1 Blue" "1 Green" "Random Green & Blue" "1 Green, plus friends" "1 Green, 1 Blue, plus friends" "10% Green" "All Red"
0

PLOT
1267
329
1467
479
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
894
339
954
New-Node-Chance
0.1
1
0
Number

INPUTBOX
342
831
444
891
Link-Batch-Size
10
1
0
Number

INPUTBOX
237
831
339
891
Num-Initial-Pairs
1
1
0
Number

INPUTBOX
342
893
444
953
Link-Memory
2
1
0
Number

TEXTBOX
239
806
440
838
For scale-free (BOB) network:
13
0.0
1

INPUTBOX
7
1179
109
1239
Network-Seed
0
1
0
Number

TEXTBOX
12
1149
294
1170
Random number stream seeds:
16
0.0
1

BUTTON
223
1190
320
1223
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

MONITOR
1351
486
1411
531
Average
mean-closeness
3
1
11

MONITOR
1351
534
1411
579
Min
min-closeness
3
1
11

MONITOR
1414
534
1471
579
Max
max-closeness
3
1
11

TEXTBOX
1266
486
1333
521
Closeness Centrality
13
0.0
1

MONITOR
631
460
719
505
Degree
Degree-centralization
3
1
11

MONITOR
724
460
827
505
Closeness
closeness-centralization
3
1
11

TEXTBOX
634
438
784
456
Network Centralization:
13
0.0
1

INPUTBOX
8
825
163
885
Num-Modules
5
1
0
Number

TEXTBOX
6
806
211
838
For Modular (Caveman) networks:
13
0.0
1

INPUTBOX
8
889
163
949
Num-Inter-Modular-Links
1
1
0
Number

INPUTBOX
114
1179
217
1239
Sim-Seed
0
1
0
Number

BUTTON
1483
44
1699
77
Output Network To VNA File
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
1483
87
1968
140
Most Recent Output Filename
output-filename
17
1
13

BUTTON
241
532
392
565
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
398
532
570
565
Print Network Metrics
Output-network-metrics
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
9
966
224
998
For Identity Search network:
13
0.0
1

INPUTBOX
6
989
161
1049
Group-Size-g
25
1
0
Number

INPUTBOX
164
988
319
1048
Branching-Ratio-b
2
1
0
Number

INPUTBOX
7
1052
162
1112
Number-Of-Levels-L
3
1
0
Number

INPUTBOX
165
1052
320
1112
Number-Of-Hierarchies-H
1
1
0
Number

INPUTBOX
323
1052
478
1112
Homophily-alpha
8
1
0
Number

MONITOR
325
991
458
1044
Resulting # Nodes
group-size-g * (branching-ratio-b ^ (number-of-levels-l - 1))
17
1
13

TEXTBOX
639
12
789
32
Simulation results:
16
0.0
1

TEXTBOX
5
780
266
808
Further network parameters:
16
0.0
1

TEXTBOX
1484
10
1634
30
Network Files:
16
0.0
1

TEXTBOX
8
55
203
86
Basic network definition:
16
0.0
1

BUTTON
457
476
563
509
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

@#$#@#$#@
# CHRIS'S NETWORK DEMO

Creates a network from one of several popular types of structure. 
Calculates various metrics for nodes and the network itself. 
Simulates the diffusion processes (of diseases, ideas, innovations etc.) within the network.

This program (C) Christopher J Watts, 2014. See below for terms and conditions of use. 

This program was developed for Chapter 3 of the book:

Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer- based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

## HOW IT WORKS

Clicking "Setup" creates a network.

Clicking "Go" runs one of various simulations of diffusion, including epidemics, targeted persuasion, and the Ising model.

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

## HOW TO USE IT (2): SIMULATING DIFFUSION

If "Go" is clicked, the diffusion simulation runs. "infection-method" determines what the simulation consists of.

The states of the nodes (and their colours) are set to one of:
 
  * 1 green agent (infection = 1), 1 blue agent (infection = 2), all others red (0);  
  * 1 green agent (infection = 1), all others red (0);  
  * agents allocated either green or blue, chosen with uniform chance.

Each time tick an agent is chosen for one of:  

  * if red, attempt to copy one of its neighbours if the neighbour is one of blue or green;  
  * if red, converting to blue or green (depending on the targeting method used to select it);  
  * converting along with its "friends" (neighbours) to blue or green (depending on the targeting method used to select it), if red;  
  * updating its infection state according to the Ising model rule and the "temperature" parameter.

When agents are targeted, they may be chosen at random without preference (in which case, conversion results in their becoming blue) , or with preference for their number of links (in which case, conversion results in green).

The simulation runs until the number of time ticks has reached the "max-ticks" value. Additionally the "when-to-halt" criterion may be used to halt before then if numbers of blue and green equal the size of the largest network component ("Largest component full"). In networks with multiple components, it is conceivable that this second condition might not be met during an epidemic (if the epidemic began in a component other than the largest). Hence the need remains for the first condition as a fail-safe.

There are buttons to:

  * output the network to a VNA-format file, suitable for reading into Ucinet or other network analysis tool;
  * print the node metrics;
  * print the network metrics.


## THINGS TO NOTICE

Different network structures have different properties. This includes effects on the diffusion of innovations, such as the ability of the innovation to reach all nodes, the time required to reach all nodes, and the proportions reached by competing innovations.

## THINGS TO TRY

BehaviorSpace contains various experiments to try, several of them related to papers in which particular network models were introduced. See for examples: Watts & Strogatz (1998); Barabasi & Albert (1999); Kauffman (1995); Watts et al. (2002); Bentley et al. (2011). Chapter 3 of the book details more.

## EXTENDING THE MODEL

Try diffusion with different network architectures. Compare final outcomes with the properties of the epidemic origin nodes (identified in code by the global variables "blue-origin" and "green-origin").

## RELATED MODELS

Network models:
See the references for the key sources on network structure. Then seek papers citing these classics. There have been plenty of other network models developed, some of them with relations to the ones covered here.

Social network analysis:
There is a large literature on the best node and network metrics for social network analysis, including what we should calculate, how best to compute it, and what to infer from it in real-world terms, e.g. what does it tells us about social capital? Wasserman & Faust (1994) remains a good place to start. Although electronic communication devices have provided us with big sources of empirical network data, the question of what structure a realistic social network should take remains an open one (Hamill & Gilbert 2009).

Diffusion models:
There have been many models of diffusion of innovations as an epidemic (i.e. as spreading from person to person), including diffusion within a particular social network.

## CREDITS AND REFERENCES

This program (C) Christopher J Watts, 2014. See below for terms and conditions of use. 
See Help menu for details "About NetLogo" itself.

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
  <experiment name="experiment-diffusion" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>num-red</metric>
    <metric>mean-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>mean-localvariety</metric>
    <metric>min-localvariety</metric>
    <metric>max-localvariety</metric>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ButtonsAndThreads" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <exitCondition>true</exitCondition>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>mean-dos</metric>
    <metric>mean-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0"/>
      <value value="0.0025"/>
      <value value="0.0050"/>
      <value value="0.0075"/>
      <value value="0.01"/>
      <value value="0.0125"/>
      <value value="0.015"/>
      <value value="0.0175"/>
      <value value="0.02"/>
      <value value="0.0225"/>
      <value value="0.025"/>
      <value value="0.0275"/>
      <value value="0.03"/>
      <value value="0.0325"/>
      <value value="0.035"/>
      <value value="0.0375"/>
      <value value="0.04"/>
      <value value="0.0425"/>
      <value value="0.045"/>
      <value value="0.0475"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-DensityAndDOS" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <exitCondition>true</exitCondition>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>mean-dos</metric>
    <metric>mean-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
      <value value="0.65"/>
      <value value="0.7"/>
      <value value="0.75"/>
      <value value="0.8"/>
      <value value="0.85"/>
      <value value="0.9"/>
      <value value="0.95"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-StrogatzAndWatts" repetitions="200" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>stdev-dos</metric>
    <metric>clust-coeff</metric>
    <metric>mean-cliquishness</metric>
    <metric>assortativity</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>mean-degree</metric>
    <metric>median-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>stdev-degree</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="1.78E-4"/>
      <value value="3.16E-4"/>
      <value value="5.62E-4"/>
      <value value="0.0010"/>
      <value value="0.001778"/>
      <value value="0.003162"/>
      <value value="0.005623"/>
      <value value="0.01"/>
      <value value="0.017783"/>
      <value value="0.031623"/>
      <value value="0.056234"/>
      <value value="0.1"/>
      <value value="0.177828"/>
      <value value="0.316228"/>
      <value value="0.562341"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-StructuralHoles" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>[precision localvariety 3] of nodes</metric>
    <metric>[precision constraint 3] of nodes</metric>
    <metric>blue-origin</metric>
    <metric>green-origin</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>num-nlinks</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-diffusion-plus-targeting" repetitions="200" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-components</metric>
    <metric>max-component</metric>
    <metric>num-blue</metric>
    <metric>num-green</metric>
    <metric>num-red</metric>
    <metric>mean-degree</metric>
    <metric>min-degree</metric>
    <metric>max-degree</metric>
    <metric>mean-dos</metric>
    <metric>min-dos</metric>
    <metric>max-dos</metric>
    <metric>net-density</metric>
    <metric>net-diameter</metric>
    <metric>mean-localvariety</metric>
    <metric>min-localvariety</metric>
    <metric>max-localvariety</metric>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;Scale-free (Barabasi-Albert)&quot;"/>
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.01"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="0.99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection + Targeting&quot;"/>
      <value value="&quot;Infection + Targeting + Friends&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Diffusion-2Origins" repetitions="100" runMetricsEveryStep="false">
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
    <metric>[count my-nlinks] of blue-origin</metric>
    <metric>[dos] of blue-origin</metric>
    <metric>[cliquishness] of blue-origin</metric>
    <metric>[constraint] of blue-origin</metric>
    <metric>[betweenness] of blue-origin</metric>
    <metric>[count my-nlinks] of green-origin</metric>
    <metric>[dos] of green-origin</metric>
    <metric>[cliquishness] of green-origin</metric>
    <metric>[constraint] of green-origin</metric>
    <metric>[betweenness] of green-origin</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;4-Neighbour Ring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NetArchitectures" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>true</exitCondition>
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
    <metric>min-cliquishness</metric>
    <metric>max-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>min-betweenness</metric>
    <metric>max-betweenness</metric>
    <metric>mean-constraint</metric>
    <metric>min-constraint</metric>
    <metric>max-constraint</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;Scale-free (Barabasi-Albert)&quot;"/>
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
      <value value="&quot;2-Neighbour Ring&quot;"/>
      <value value="&quot;4-Neighbour Ring&quot;"/>
      <value value="&quot;10-Neighbour Ring&quot;"/>
      <value value="&quot;4-Neighbour Grid&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Linear&quot;"/>
      <value value="&quot;Star&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NetArchitectures-Reps" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>true</exitCondition>
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
    <metric>min-cliquishness</metric>
    <metric>max-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>min-betweenness</metric>
    <metric>max-betweenness</metric>
    <metric>mean-constraint</metric>
    <metric>min-constraint</metric>
    <metric>max-constraint</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;Scale-free (Barabasi-Albert)&quot;"/>
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NetArchitectures-SW" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>true</exitCondition>
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
    <metric>min-cliquishness</metric>
    <metric>max-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>min-betweenness</metric>
    <metric>max-betweenness</metric>
    <metric>mean-constraint</metric>
    <metric>min-constraint</metric>
    <metric>max-constraint</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0.01"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Social Circles&quot;"/>
      <value value="&quot;4-Neighbour Ring&quot;"/>
      <value value="&quot;10-Neighbour Ring&quot;"/>
      <value value="&quot;4-Neighbour Grid&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-NetArchitectures-Fixed" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>true</exitCondition>
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
    <metric>min-cliquishness</metric>
    <metric>max-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>min-betweenness</metric>
    <metric>max-betweenness</metric>
    <metric>mean-constraint</metric>
    <metric>min-constraint</metric>
    <metric>max-constraint</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;2-Neighbour Ring&quot;"/>
      <value value="&quot;4-Neighbour Ring&quot;"/>
      <value value="&quot;10-Neighbour Ring&quot;"/>
      <value value="&quot;4-Neighbour Grid&quot;"/>
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Linear&quot;"/>
      <value value="&quot;Star&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-BOBTest" repetitions="1000" runMetricsEveryStep="false">
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
    <metric>[count my-nlinks] of blue-origin</metric>
    <metric>[dos] of blue-origin</metric>
    <metric>[cliquishness] of blue-origin</metric>
    <metric>[constraint] of blue-origin</metric>
    <metric>[betweenness] of blue-origin</metric>
    <metric>[count my-nlinks] of green-origin</metric>
    <metric>[dos] of green-origin</metric>
    <metric>[cliquishness] of green-origin</metric>
    <metric>[constraint] of green-origin</metric>
    <metric>[betweenness] of green-origin</metric>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Scale-free (BOB)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-batch-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-method">
      <value value="&quot;Infection&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-threshold">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-initial-pairs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-states-method">
      <value value="&quot;1 Green, 1 Blue&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ising-temperature">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="new-node-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-memory">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-DensityAndDOS-MoreMetrics" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <exitCondition>true</exitCondition>
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
    <metric>min-cliquishness</metric>
    <metric>max-cliquishness</metric>
    <metric>mean-betweenness</metric>
    <metric>min-betweenness</metric>
    <metric>max-betweenness</metric>
    <metric>mean-constraint</metric>
    <metric>min-constraint</metric>
    <metric>max-constraint</metric>
    <metric>mean-closeness</metric>
    <metric>min-closeness</metric>
    <metric>max-closeness</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-chance">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
      <value value="0.65"/>
      <value value="0.7"/>
      <value value="0.75"/>
      <value value="0.8"/>
      <value value="0.85"/>
      <value value="0.9"/>
      <value value="0.95"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-radius">
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-slow-metrics">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-to-halt">
      <value value="&quot;Largest component full&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-seed">
      <value value="0"/>
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
