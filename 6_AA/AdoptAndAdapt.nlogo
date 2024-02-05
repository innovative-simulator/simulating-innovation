;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Adopt & Adapt: Diffusion in a landscape subject to constraints on technology portfolios.
;; This version (C) Christopher Watts, 2015. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array matrix]

globals [
  labels-on
  links-on
  
  disjoined-techs
  techs-count
  number-of-terrains
  total-constraints
  aconstraints
  tconstraints
  sconstraints
  gconstraints
  ktuple
  vspair
  last-seed-fitness
  last-seed-sim
  num-satisfied
  mean-num-techs
  max-num-techs
  min-num-techs
  mean-num-adopters
  max-num-adopters
  min-num-adopters
  mean-fitness
  max-fitness
  min-fitness
  init-num-satisfied
  init-mean-fitness
  init-max-fitness
  init-min-fitness
  chr
  chartcolours
  agentcolours
  constraint-string
  ;move-memory-length ; Used by one agent movement method
]

breed [agents agent]
undirected-link-breed [nlinks nlink] ; Neighbours close enough to imitate each other

agents-own [
  home-patch
  target-patch
  move-memory
  move-memory-pos
  techs
  cur-num-techs
  cur-terrain
  fitness
  agent-type
]

patches-own [
  terrain
]

nlinks-own [
  
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  set chartcolours array:from-list (list 3 15 27 33 45 57 63 75 87 93 105 117 123 135 0 8)
  set agentcolours array:from-list (list red orange lime sky violet pink brown cyan magenta grey )
  
  setup-landscape
  setup-constraints ;Sets up constraints, using seed-fitness for RNG
  
  set last-seed-sim (ifelse-value (seed-sim = 0) [new-seed] [seed-sim])
  random-seed last-seed-sim
  
  setup-population
  set init-num-satisfied (count agents with [fitness = total-constraints])
  set init-mean-fitness (mean [fitness] of agents)
  set init-max-fitness (max [fitness] of agents)
  set init-min-fitness (min [fitness] of agents)
  
  update-stats
  my-setup-plots
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-landscape
  if landscape-type = "World" [setup-landscape-world]
  if landscape-type = "4 Quarters" [setup-landscape-4Q]
  
end

to setup-landscape-4Q
  set number-of-terrains 4
  resize-world 0 32 0 32 
  let grassland (patch-set
    patches with [pxcor < 16 and pycor > 16]
    patches with [pxcor = 16 and pycor > 16 and pycor mod 2 = 0]
    patches with [pxcor < 16 and pycor = 16 and pxcor mod 2 = 0]
    )
  let woodland (patch-set
    patches with [pxcor > 16 and pycor > 16]
    patches with [pxcor = 16 and pycor > 16 and pycor mod 2 = 1]
    )
  let water (patch-set 
    patches with [pxcor > 16 and pycor < 16]
    patches with [pxcor = 16 and pycor < 16 and pycor mod 2 = 0]
    )
  let sand (patch-set 
    patches with [pxcor < 16 and pycor < 16]
    patches with [pxcor < 16 and pycor = 16 and pxcor mod 2 = 1]
    patches with [pxcor = 16 and pycor < 16]
    patches with [pxcor >= 16 and pycor = 16]
    )
  
  ask grassland [
    set pcolor (green + (random 3) - 1)
    set terrain 3
  ]
  
  ask woodland [
    set pcolor (63 + (random 3) - 1)
    set terrain 1
  ]
  
  ask sand [
    set pcolor (yellow + (random 3) - 1)
    set terrain 2
  ]
  ask water [
    set pcolor blue
    set terrain 0
  ]
  
end

to setup-landscape-world
  ; Grass 0; Forest 1; Desert 2; Grassland 3; Tropical jungle 4; Ice / Mountains 5
  set number-of-terrains 6
  resize-world 0 31 0 31 
  let pcolor-scheme array:from-list (list blue (green - 2) yellow (green + 1) (lime - 3) (white - 1))
  let wmatrix matrix:from-column-list [
    [ 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 5 5 5 5 5 5 5 0 5 0 0 0 1 1 1 5 5 5 5 5 5 5 5 5 5 5 5 5 0 0 ]
    [ 0 0 5 5 5 5 5 5 5 0 1 0 0 0 1 1 1 1 1 1 1 5 1 1 1 1 1 1 1 1 0 0 ]
    [ 0 0 1 1 1 1 1 1 1 0 1 0 0 0 0 1 1 1 1 1 1 5 1 1 1 1 1 1 1 1 0 0 ]
    [ 0 0 1 1 1 1 1 1 1 0 0 0 0 0 3 1 1 1 1 1 1 5 1 1 1 1 1 1 1 1 0 0 ]
    [ 0 0 1 1 1 1 1 1 1 0 0 0 0 0 3 3 1 1 1 1 1 5 1 1 1 1 3 3 3 3 0 0 ]
    [ 0 0 1 1 1 1 1 1 1 0 0 0 0 0 3 3 1 1 1 1 1 5 3 3 3 3 3 3 3 3 0 0 ]
    [ 0 0 3 3 3 3 3 3 3 0 0 0 0 0 3 3 5 5 3 3 3 2 2 2 2 3 3 3 3 0 0 0 ]
    [ 0 0 3 3 3 3 3 3 3 0 0 0 0 3 3 3 3 3 3 3 3 2 2 2 2 3 3 3 3 0 3 0 ]
    [ 0 0 0 3 3 3 3 3 0 0 0 0 0 3 3 3 3 3 3 3 3 2 2 2 2 3 3 3 3 0 3 0 ]
    [ 0 0 0 3 3 3 3 3 0 0 0 0 0 3 3 0 0 0 3 3 3 3 3 3 3 3 3 3 3 0 3 0 ]
    [ 0 0 0 3 3 3 3 3 0 0 0 0 0 0 0 0 0 0 3 3 3 3 3 3 3 3 3 3 3 0 0 0 ]
    [ 0 0 0 2 2 3 3 3 0 0 0 0 0 3 3 3 3 3 3 3 3 3 3 3 3 5 5 3 3 0 0 0 ]
    [ 0 0 0 2 2 0 0 0 0 0 0 0 0 2 2 2 2 2 2 2 3 3 3 3 3 5 5 4 4 0 0 0 ]
    [ 0 0 0 2 2 0 0 0 0 0 0 0 0 2 2 2 2 2 2 0 0 0 0 3 3 3 3 4 4 0 0 0 ]
    [ 0 0 0 2 2 0 0 0 0 0 0 0 0 2 2 2 2 2 2 0 0 0 0 3 3 3 3 4 4 0 0 0 ]
    [ 0 0 0 2 2 0 0 0 0 0 0 0 0 2 2 2 2 2 2 0 0 0 0 4 4 4 4 0 0 0 0 0 ]
    [ 0 0 0 2 2 0 0 0 0 0 0 0 0 2 2 2 2 2 2 0 0 0 0 4 4 4 4 0 0 0 0 0 ]
    [ 0 0 0 4 4 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 4 4 4 4 0 0 0 0 0 ]
    [ 0 0 0 4 4 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 4 4 4 4 0 0 0 0 0 ]
    [ 0 0 0 4 5 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 4 4 4 4 0 0 0 0 0 ]
    [ 0 0 0 4 5 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 4 5 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 4 5 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 4 5 4 4 4 0 0 0 0 0 4 4 4 3 3 3 0 0 0 0 0 0 0 0 2 2 2 0 0 ]
    [ 0 0 0 3 5 3 0 0 0 0 0 0 0 0 3 3 3 3 3 0 0 0 0 0 0 0 0 2 2 2 0 0 ]
    [ 0 0 0 3 5 3 0 0 0 0 0 0 0 0 3 3 3 3 3 0 0 0 0 0 0 0 0 3 3 3 0 0 ]
    [ 0 0 0 3 5 3 0 0 0 0 0 0 0 0 3 3 3 3 3 0 0 0 0 0 0 0 0 3 3 3 0 0 ]
    [ 0 0 0 3 5 3 0 0 0 0 0 0 0 0 3 3 3 3 3 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 3 3 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
    [ 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ]
  ]
  ask patches [
    set terrain matrix:get wmatrix pxcor (31 - pycor)
    set pcolor array:item pcolor-scheme terrain
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-population
  ;set move-memory-length 10
  create-agents initial-population [
    setxy random-xcor random-ycor
    if landscape-type = "World" [
      while [[terrain = 0] of patch-here] [setxy random-xcor random-ycor] ; Don't base yourself on water.
    ]
    set home-patch patch-here
    set agent-type random number-of-agent-types
    set color array:item agentcolours (agent-type mod (length array:to-list agentcolours))
    setup-agent-shape
    setup-initial-techs
    ;set label (word array:to-list techs)
    set cur-terrain [terrain] of patch-here
    set fitness agent-fitness self
    set target-patch patch-here
    set move-memory-pos 0
    set move-memory array:from-list n-values move-memory-length [[]]
  ]
  set labels-on false
  toggle-labels
  setup-links
  toggle-links
  
  set techs-count array:from-list (n-values number-of-techs [0])
  ask agents [set techs-count array:from-list (map [?1 + ?2] (array:to-list techs-count) (array:to-list techs))]
end

to setup-initial-techs
  if initial-techs-method = "Random" [set techs array:from-list (n-values number-of-techs [random 2])]
  if initial-techs-method = "All 0" [set techs array:from-list (n-values number-of-techs [0])]
  if initial-techs-method = "All 1" [set techs array:from-list (n-values number-of-techs [1])]
end

to setup-agent-shape
  ifelse ([terrain] of patch-here = 0) [
    set shape "boat"
  ]
  [set shape "person"]
end

to toggle-labels
  set labels-on (not labels-on)
  ask agents [
    ifelse labels-on [
      set label (word array:to-list techs)
    ]
    [ set label ""
    ]
  ]
end

to my-setup-plots
  set-current-plot "Number of Adopters"
  let pen-num 0
  set-plot-pen-color item pen-num base-colors
  set-plot-pen-interval output-every-n-ticks
  repeat (number-of-techs - 1) [
    set pen-num (pen-num + 1)
    create-temporary-plot-pen (word "tech-" pen-num)
    set-plot-pen-color array:item chartcolours pen-num
    set-plot-pen-interval output-every-n-ticks
  ]
  
  set-current-plot "Technologies' Popularity"
  set-plot-x-range 0 number-of-techs 
  
  set-current-plot "Number of Techs Per Agent"
  set-plot-y-range 0 (number-of-techs + 1)
  set-current-plot-pen "Mean"
  set-plot-pen-interval output-every-n-ticks
  set-current-plot-pen "Max"
  set-plot-pen-interval output-every-n-ticks
  set-current-plot-pen "Min"
  set-plot-pen-interval output-every-n-ticks

  set-current-plot "Fitness Evolution"
  set-plot-y-range 0 (total-constraints + 1)
  set-current-plot-pen "Mean"
  set-plot-pen-interval output-every-n-ticks
  set-current-plot-pen "Max"
  set-plot-pen-interval output-every-n-ticks
  set-current-plot-pen "Min"
  set-plot-pen-interval output-every-n-ticks

  set-current-plot "Fitness Distribution"
  set-plot-x-range 0 (total-constraints + 1)
  
  set-current-plot "Number of Fully Satisfied Agents"
  set-plot-y-range 0 (initial-population + 1)
  set-plot-pen-interval output-every-n-ticks
  
  my-update-plots
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-constraints
  ; Defines the constraint sets for each terrain type
  set total-constraints agent-type-constraints + terrain-constraints + social-constraints + generic-constraints
  
  set last-seed-fitness (ifelse-value (seed-fitness = 0) [new-seed] [seed-fitness])
  random-seed last-seed-fitness
  
  set aconstraints n-values number-of-agent-types [
    ; multiple agent types
    n-values agent-type-constraints [
        ; multiple constraints in each set
        (map [((2 * random 2) - 1) * (1 + ?)] (n-of constraint-width-k (n-values number-of-techs [?])))
        ; multiple component variables in each constraint
        ; Each component is an index number to be used with the techs array
        ; To denote a negated variable, an index number is multiplied by -1
    ]
  ]  

  set tconstraints n-values number-of-terrains [
    ; multiple terrain types
    n-values terrain-constraints [
        ; multiple constraints in each set
        (map [((2 * random 2) - 1) * (1 + ?)] (n-of constraint-width-k (n-values number-of-techs [?])))
        ; multiple component variables in each constraint
        ; Each component is an index number to be used with the techs array
        ; To denote a negated variable, an index number is multiplied by -1
    ]
  ]  

  set sconstraints n-values social-constraints [
      ; multiple constraints in 1 set
      (map [((2 * random 2) - 1) * (1 + ?)] (n-of constraint-width-k (n-values number-of-techs [?])))
      ; multiple component variables in each constraint
      ; Each component is an index number to be used with the techs array
      ; To denote a negated variable, an index number is multiplied by -1
  ]
  
  set gconstraints n-values generic-constraints [
    ; multiple constraints in 1 set
    (map [((2 * random 2) - 1) * (1 + ?)] (n-of constraint-width-k (n-values number-of-techs [?])))
    ; multiple component variables in each constraint
    ; Each component is an index number to be used with the techs array
    ; To denote a negated variable, an index number is multiplied by -1
  ]

end

to-report agent-fitness [given-agent]
  report ksat-fitness given-agent
;  report simple-fitness given-agent
end

to-report ksat-fitness [given-agent]
  ; k-sat fitness function:
  ; Uses the binary values in given agent's techs array
  ; and the constraints set for given agent's current terrain
  ; to return the number of constraints satisfied by those values.
  let ksat 0
  let cval 1
  
  ; Agent Type constraints 
  foreach (item ([agent-type] of given-agent) aconstraints) [
    ; i.e. for each constraint in the set that goes with current agent type
    set cval 1
    foreach ? [
      ; i.e. for each variable in the constraint
      ifelse ? > 0 [
        ; if variable ID positive, use value in agent's techs array
        ; * means constraint is being calculated using conjunction operations (AND)
;        set cval cval * (array:item techs (? - 1)) ; A AND B
        set cval cval * (1 - array:item techs (? - 1)) ; A OR B equates to �(�A & �B)
      ]
      [
        ; if variable ID negative, use 1 - value in agent's techs array
;        set cval cval * (1 - (array:item techs ((abs ?) - 1))) ;A AND B
        set cval cval * ((array:item techs ((abs ?) - 1))) ; A OR B equates to �(�A & �B)
      ]
    ]
;    set ksat ksat + cval ; A AND B
    set ksat ksat + 1 - cval ; A OR B equates to �(�A & �B)
  ]

  ; Terrain constraints 
  foreach (item ([cur-terrain] of given-agent) tconstraints) [
    ; i.e. for each constraint in the set that goes with current terrain
    set cval 1
    foreach ? [
      ; i.e. for each variable in the constraint
      ifelse ? > 0 [
        ; if variable ID positive, use value in agent's techs array
        ; * means constraint is being calculated using conjunction operations (AND)
;        set cval cval * (array:item techs (? - 1)) ; A AND B
        set cval cval * (1 - array:item techs (? - 1)) ; A OR B equates to �(�A & �B)
      ]
      [
        ; if variable ID negative, use 1 - value in agent's techs array
;        set cval cval * (1 - (array:item techs ((abs ?) - 1))) ;A AND B
        set cval cval * ((array:item techs ((abs ?) - 1))) ; A OR B equates to �(�A & �B)
      ]
    ]
;    set ksat ksat + cval ; A AND B
    set ksat ksat + 1 - cval ; A OR B equates to �(�A & �B)
  ]
  
  ; Social constraints
  if 0 < length sconstraints [
    set disjoined-techs array:from-list map [?] (array:to-list techs)
    ask agents in-radius imitation-radius [set disjoined-techs array:from-list (map [ifelse-value (?1 = ?2) [?1] [?1 + ?2]] (array:to-list techs) (array:to-list disjoined-techs))]  
    foreach sconstraints [
      ; i.e. for each constraint in the set that goes with current terrain
      set cval 1
      foreach ? [
        ; i.e. for each variable in the constraint
        ifelse ? > 0 [
          ; if variable ID positive, use value in agent's techs array
          ; * means constraint is being calculated using conjunction operations (AND)
          ;        set cval cval * (array:item disjoined-techs (? - 1)) ; A AND B
          set cval cval * (1 - array:item disjoined-techs (? - 1)) ; A OR B equates to �(�A & �B)
        ]
        [
          ; if variable ID negative, use 1 - value in agent's techs array
          ;        set cval cval * (1 - (array:item disjoined-techs ((abs ?) - 1))) ;A AND B
          set cval cval * ((array:item disjoined-techs ((abs ?) - 1))) ; A OR B equates to �(�A & �B)
        ]
      ]
      ;    set ksat ksat + cval ; A AND B
      set ksat ksat + 1 - cval ; A OR B equates to �(�A & �B)
    ]
  ]
  
  ; Generic constraints
  foreach gconstraints [
    ; i.e. for each constraint in the set that goes with current terrain
    set cval 1
    foreach ? [
      ; i.e. for each variable in the constraint
      ifelse ? > 0 [
        ; if variable ID positive, use value in agent's techs array
        ; * means constraint is being calculated using conjunction operations (AND)
;        set cval cval * (array:item techs (? - 1)) ; A AND B
        set cval cval * (1 - array:item techs (? - 1)) ; A OR B equates to �(�A & �B)
      ]
      [
        ; if variable ID negative, use 1 - value in agent's techs array
;        set cval cval * (1 - (array:item techs ((abs ?) - 1))) ;A AND B
        set cval cval * ((array:item techs ((abs ?) - 1))) ; A OR B equates to �(�A & �B)
      ]
    ]
;    set ksat ksat + cval ; A AND B
    set ksat ksat + 1 - cval ; A OR B equates to �(�A & �B)
  ]

  report ksat
end

to output-constraints
  ; Prints to the window the current constraint sets.
  print "Outputting constraint sets:"
  set constraint-string ""

  let cnum 0
  let tnum 0
  foreach aconstraints [
    ; i.e. for each constraint set
    print (word "Agent Type " tnum ":")
    set cnum 0
    foreach ? [
      output-current-constraint ? cnum
      set cnum (cnum + 1)
    ]
    set tnum (tnum + 1)
    print ""
  ]

  set tnum 0
  foreach tconstraints [
    ; i.e. for each constraint set
    print (word "Terrain " tnum ":")
    set cnum 0
    foreach ? [
      output-current-constraint ? cnum
      set cnum (cnum + 1)
    ]
    set tnum (tnum + 1)
    print ""
  ]

  print (word "Social:")
  set cnum 0
  foreach sconstraints [
    output-current-constraint ? cnum
    set cnum (cnum + 1)
  ]
  print ""

  print (word "Generic:")
  set cnum 0
  foreach gconstraints [
    output-current-constraint ? cnum
    set cnum (cnum + 1)
  ]
  print ""


end

to output-current-constraint [clist cnum]
  ; i.e. for each constraint in the set
  let vnum 0
  set constraint-string (word cnum ")")
  foreach clist [
    ; i.e. for each variable in the constraint
;        if vnum > 0 [set constraint (word constraint " &")]
    if vnum > 0 [set constraint-string (word constraint-string " OR")]
    ifelse ? > 0 [
      ; if variable ID positive, use value in agent's techs array
      ; * means constraint is a conjunction operation (AND)
      set constraint-string (word constraint-string "  T" (? - 1))
    ]
    [
      set constraint-string (word constraint-string " �T" ((abs ?) - 1))
    ]
    set vnum (vnum + 1)
  ]
  print constraint-string
end

to output-best-fitness
  ; Creates a temporary agent, then uses it to 
  ; print best fitness and solution for each terrain
  let tnum 0
  print ""
  print "Outputting best fitness values and first optimal solution:"
  create-agents 1 [
    set techs array:from-list (n-values number-of-techs [0])
    repeat number-of-agent-types [
      set agent-type tnum
      print (word "Agent Type: " tnum)
      print best-fitness-agent self
      print array:to-list techs
      print ""
      set tnum (tnum + 1)
    ]
    set agent-type 0
    set tnum 0
    repeat number-of-terrains [
      set cur-terrain tnum
      print (word "Terrain: " tnum)
      print best-fitness-agent self
      print array:to-list techs
      print ""
      set tnum (tnum + 1)
    ]
    die
  ]
end

to-report best-fitness-agent [given-agent]
  ; Returns best fitness value
  ; Given agent then has one of the solutions with that fitness value.
  ; Might not work as number of technologies get bigger.
  let tech-sol 0
  let max-sol (2 ^ number-of-techs)
  let pos 0
  let cur-sol 0
  let cur-fitness 0
  let best-sol -1
  let best-fitness -1
  ask given-agent [
    repeat max-sol [
      set pos 0
      repeat number-of-techs [
        array:set techs pos ((int (cur-sol / (2 ^ pos))) mod 2)
        set pos (pos + 1)
      ]
      set cur-fitness agent-fitness self
      if cur-fitness > best-fitness [
        set best-fitness cur-fitness
        set best-sol cur-sol
      ]
      set cur-sol (cur-sol + 1)
    ]
  ]
  
  set pos 0
  repeat number-of-techs [
    array:set techs pos ((int (best-sol / (2 ^ pos))) mod 2)
    set pos (pos + 1)
  ]
  
  report best-fitness
end

to-report simple-fitness [given-agent]
  ; Simple fitness function: a bit count of techs array
  ; Used during development but now replaced with K-Sat.
  let bit-count 0
  let cur-tech 0
  ask given-agent [
    repeat number-of-techs [
      set bit-count (bit-count + (array:item techs cur-tech))
      set cur-tech (cur-tech + 1)
    ]
  ]
  report bit-count
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to output-seeds
  print "Random number generator seeds: "
  print (word "seed-fitness " last-seed-fitness)
  print (word "seed-sim " last-seed-sim)
  print ""
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ; Agents move around
  ; and may invent, discard / forget, or imitate from nearby agents technologies.
  let temp-terrain 0
  ask agents [
    agent-move
    
    set temp-terrain [terrain] of patch-here
    if cur-terrain != temp-terrain [
      set cur-terrain temp-terrain
      set fitness agent-fitness self
      setup-agent-shape
    ]
    
    if random-float 1 < chance-invention [invention]
    if random-float 1 < chance-discard [discard]
    if random-float 1 < chance-imitation [adopt-and-adapt]
    
  ]
  
  tick
  
  if ticks mod output-every-n-ticks = 0 [
    if links-on [refresh-nlinks]
    update-stats
    my-update-plots
  ]
  
end

to update-stats
  set num-satisfied (count agents with [fitness = total-constraints])
  ask agents [set cur-num-techs (sum array:to-list techs)]
  set mean-num-techs (mean [cur-num-techs] of agents)
  set max-num-techs (max [cur-num-techs] of agents)
  set min-num-techs (min [cur-num-techs] of agents)
  set mean-num-adopters (mean array:to-list techs-count)
  set max-num-adopters (max array:to-list techs-count)
  set min-num-adopters (min array:to-list techs-count)
  set mean-fitness (mean [fitness] of agents)
  set max-fitness (max [fitness] of agents)
  set min-fitness (min [fitness] of agents)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to agent-move
  
  if agent-movement-method = "Static" [ stop ]
  if agent-movement-method = "Around base" [ agent-move-aroundbase stop ]
  if agent-movement-method = "Star base" [ agent-move-starbase stop ]
  if agent-movement-method = "Random walk" [ agent-move-randomwalk stop ]
  if agent-movement-method = "Mostly memory" [ agent-move-mostlymemory stop ]
  if agent-movement-method = "Mostly good memory" [ agent-move-mostlygoodmemory stop ]
  
end

to agent-move-randomwalk
  ; Random walk / Brownian motion
  rt random-float 360
  while [patch-ahead 1 = nobody] [rt random-float 360]
  fd 1
end

to agent-move-starbase
  ; Move to circle edge, then return home and pick another direction.
  ifelse patch-here = home-patch [
    ; At home. Try venturing out in another direction.
    rt random-float 360
    while [patch-ahead 1 = nobody] [rt random-float 360]
    fd 1
  ]
  [
    ; Not at home.
    ifelse (patch-ahead 1 = nobody) [
      ;Edge of world. Time to go home.
      face home-patch
      fd 1
    ]
    [
      ifelse (distance home-patch >= roam-radius) [
        ; Too far from home. Time to go back.
        face home-patch
        fd 1
      ]
      [
        ; Keep going
        fd 1
      ]
    ]
  ]
end

to agent-move-aroundbase
  ; Move to circle edge, then bounce across circle in random direction
  ifelse (patch-ahead 1 = nobody) [
    ;Try another direction
    rt random-float 360
  ]
  [
    ifelse (distance home-patch >= roam-radius) [
      face home-patch
      fd 1
      rt ((random-float 90) - 45)
    ]
    [
      fd 1
    ]
  ]
end

to agent-move-mostlymemory
  ; Mostly sample a target-patch from memory. Occasionally innovate instead.
  ifelse (patch-here = target-patch) [
    ; At target. Try going somewhere else.
    set-new-target
    array:set move-memory move-memory-pos  (list patch-here fitness)
    set move-memory-pos ((1 + move-memory-pos) mod move-memory-length)
    fd 1
  ]
  [
    ; Keep going towards target.
    if nobody = patch-ahead 1 [set-new-target]
    fd 1
  ]
end

to agent-move-mostlygoodmemory
  ; Mostly sample a target-patch from memory. Targets reached are not remembered if inferior to those in memory. Occasionally innovate instead.
  ifelse (patch-here = target-patch) [
    ; At target. Try going somewhere else.
    set-new-target
    set move-memory-pos length filter [ifelse-value (? = []) [false] [fitness <= last ?]] array:to-list move-memory
    if (0 < move-memory-pos) [
      set move-memory-pos position (one-of filter [fitness <= last ?] array:to-list move-memory) move-memory
      array:set move-memory move-memory-pos  (list patch-here fitness)
    ]
    fd 1
  ]
  [
    ; Keep going towards target.
    if nobody = patch-ahead 1 [set-new-target]
    fd 1
  ]
end

to set-new-target
  ifelse move-innovation > random-float 1 [
    innovate-new-target
  ]
  [
    let cur-mem one-of array:to-list move-memory
    ifelse cur-mem = [] [
      innovate-new-target
    ]
    [
      set target-patch first cur-mem
      ifelse (target-patch = patch-here) [
        innovate-new-target
      ]
      [
        face target-patch
      ]
;      if (1 + roam-radius) < (distance target-patch) [show (word patch-here target-patch " H:" heading " D:" (distance target-patch) move-memory)] ; error check
    ]
  ]
end

to innovate-new-target
  ; innovate
  let step-size (1 + random roam-radius)
  rt random-float 360
  while [nobody = patch-ahead step-size] [rt random-float 360]
  set target-patch patch-ahead step-size
end  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to invention
  ; Given agent (re-)invents / discovers an arbitrary technology
  let selected-tech ((random (number-of-techs / size-of-complex-techs)) * size-of-complex-techs)
  if (techs-present selected-tech size-of-complex-techs) < size-of-complex-techs [
    let old-values array:to-list techs
    invent-techs selected-tech size-of-complex-techs
    let alt-fitness agent-fitness self
    ifelse alt-fitness >= fitness [ ; ">=" means that more techs is better than fewer
      if labels-on [set label (word array:to-list techs)]
      let pos selected-tech
      repeat size-of-complex-techs [
        array:set techs-count pos ((array:item techs-count pos) + (array:item techs pos) - (item pos old-values))
        set pos (pos + 1)
      ]
      set fitness alt-fitness
      set cur-num-techs (sum array:to-list techs)
    ]
    [
      set techs array:from-list old-values
    ]
    
  ]
end

to flash-invention
  ; Initiates an invention event
  ; Called by button
  ask one-of agents [invention]
end

to discard
  ; Given agent tries going without an arbitrary technology
  let selected-tech ((random (number-of-techs / size-of-complex-techs)) * size-of-complex-techs)
  if (techs-present selected-tech size-of-complex-techs) > 0 [
    let old-values array:to-list techs
    wipe-techs selected-tech size-of-complex-techs
    let alt-fitness agent-fitness self
    ifelse alt-fitness > fitness [  ; ">" means that more techs is better than fewer
      if labels-on [set label (word array:to-list techs)]
      let pos selected-tech
      repeat size-of-complex-techs [
        array:set techs-count pos ((array:item techs-count pos) + (array:item techs pos) - (item pos old-values))
        set pos (pos + 1)
      ]
      set fitness alt-fitness
      set cur-num-techs (sum array:to-list techs)
    ]
    [
      set techs array:from-list old-values
    ]
    
  ]
end

to-report techs-present [start-bit num-bits]
  ; Returns number of techs present for a given range of techs array
  ; i.e. counts bits set to 1
  let bit-count 0
  let pos start-bit
  repeat num-bits [
    set bit-count (bit-count + array:item techs pos)
  ]
  report bit-count
end
  

to invent-techs [start-bit num-bits]
  let pos start-bit
  repeat num-bits [
    array:set techs pos 1
    set pos (pos + 1)
  ]
end

to wipe-techs [start-bit num-bits]
  let pos start-bit
  repeat num-bits [
    array:set techs pos 0
    set pos (pos + 1)
  ]
end

to adopt-and-adapt
  ; Current agent imitates one of the agents within a given radius of it.
  ; A multi-bit word may be copied - with possibility of adaptation or error
  let imitated one-of agents in-radius imitation-radius
  if imitated != nobody [    
    let selected-tech ((random (number-of-techs / size-of-complex-techs)) * size-of-complex-techs)
    if (compare-bits self imitated selected-tech size-of-complex-techs) < size-of-complex-techs [
      let old-values array:to-list techs
;      array:set techs selected-tech [array:item techs selected-tech] of imitated
      copy-bits imitated selected-tech size-of-complex-techs
      let alt-fitness agent-fitness self
      ifelse alt-fitness >= fitness [  ; ">=" means that change through imitation is better than remaining the same
        if labels-on [set label (word array:to-list techs)]
        let pos selected-tech
        repeat size-of-complex-techs [
          array:set techs-count pos ((array:item techs-count pos) + (array:item techs pos) - (item pos old-values))
          set pos (pos + 1)
        ]
        set fitness alt-fitness
        set cur-num-techs (sum array:to-list techs)
      ]
      [
        set techs array:from-list old-values
      ]
    ]
  ]  
end

to-report compare-bits [ego alter start-bit num-bits]
  let compcount 0
  let pos start-bit
  repeat num-bits [
    set compcount (compcount + 1 - abs ([array:item techs pos] of ego - [array:item techs pos] of alter))
    set pos (pos + 1)
  ]
  report compcount
end

to copy-bits [alter start-bit num-bits]
  let compcount 0
  let pos start-bit
  repeat num-bits [
    if random-float 1 >= chance-adapt [
      array:set techs pos ([array:item techs pos] of alter)
    ]
    set pos (pos + 1)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-links
  ask agents [
    ask other agents [
      create-nlink-with myself [
        set hidden? true
        set color white
      ]
    ]
  ]
  set links-on true
end  

to toggle-links
  ; Switch on/off links showing who can interact with whom.
  set links-on not links-on
  ifelse links-on [
    refresh-nlinks
  ]
  [
    ask nlinks [set hidden? true]
  ]
end

to refresh-nlinks
  ask nlinks [
    ifelse ([imitation-radius >= distance ([end2] of myself)] of end1) [
      set hidden? false
    ]
    [
      set hidden? true
    ]
  ]
  
;  ask agents [
;    ask other agents in-radius imitation-radius [
;      ifelse nlink-neighbor? myself [
;        ask nlink-with myself [set hidden? false]
;      ]
;      [
;        create-nlink-with myself [set hidden? false]
;      ]
;    ]
;  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to my-update-plots
  set-current-plot "Number of Adopters"
  let pen-num 0
  repeat number-of-techs [
    set-current-plot-pen (word "tech-" pen-num)
    plotxy ticks (array:item techs-count pen-num)
    set pen-num (pen-num + 1)
  ]
  
  set-current-plot "Technologies' Popularity"
  clear-plot
  set pen-num 0
  repeat number-of-techs [
    plot (array:item techs-count pen-num)
    set pen-num (pen-num + 1)
  ]  
  
  set-current-plot "Number of Techs Per Agent"
  set-current-plot-pen "Mean"
  plotxy ticks mean-num-techs
  set-current-plot-pen "Max"
  plotxy ticks max-num-techs
  set-current-plot-pen "Min"
  plotxy ticks min-num-techs

  set-current-plot "Fitness Evolution"
  set-current-plot-pen "Mean"
  plotxy ticks mean-fitness
  set-current-plot-pen "Max"
  plotxy ticks max-fitness
  set-current-plot-pen "Min"
  plotxy ticks min-fitness
  
  set-current-plot "Fitness Distribution"
  histogram [fitness] of agents
  
  set-current-plot "Number of Fully Satisfied Agents"
  plotxy ticks num-satisfied
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
254
10
693
470
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
32
0
32
0
0
1
ticks
30.0

BUTTON
254
479
318
512
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
173
185
248
245
Roam-Radius
2
1
0
Number

BUTTON
320
479
383
512
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

INPUTBOX
7
250
111
310
Initial-Population
60
1
0
Number

TEXTBOX
7
5
199
46
Adopt & Adapt
24
0.0
1

INPUTBOX
7
311
111
371
Number-Of-Techs
4
1
0
Number

INPUTBOX
252
564
355
624
Chance-Invention
1.0E-5
1
0
Number

INPUTBOX
252
628
346
688
Chance-Discard
0.1
1
0
Number

INPUTBOX
432
562
526
622
Chance-Imitation
0.5
1
0
Number

BUTTON
589
475
693
508
Labels on/off
toggle-labels
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
357
563
412
596
Invent!
flash-invention
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
698
10
1165
302
Number of Adopters
Time (ticks)
# Adopters
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"tech-0" 1.0 0 -16777216 true "" ""

PLOT
1169
10
1458
199
Technologies' Popularity
Tech
# Adopters
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

INPUTBOX
433
625
521
685
Imitation-Radius
2
1
0
Number

PLOT
698
490
965
655
Fitness Evolution
Time (ticks)
Mean Fitness
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -16777216 true "" ""
"Max" 1.0 0 -13345367 true "" ""
"Min" 1.0 0 -11033397 true "" ""

INPUTBOX
125
614
229
674
Constraint-Width-K
2
1
0
Number

PLOT
968
490
1199
655
Fitness Distribution
Fitness (# Constraints)
# Agents
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

INPUTBOX
574
766
690
826
Output-Every-n-Ticks
400
1
0
Number

INPUTBOX
9
832
164
892
Seed-Fitness
0
1
0
Number

INPUTBOX
9
894
164
954
Seed-Sim
0
1
0
Number

MONITOR
1202
490
1302
543
Mean Fitness
mean-fitness
2
1
13

MONITOR
1202
546
1302
599
Max Fitness
max-fitness
17
1
13

MONITOR
1202
602
1302
655
Min Fitness
min-fitness
17
1
13

BUTTON
10
688
170
721
Print Constraint Sets
output-constraints
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
10
958
154
991
Print last RNG Seeds
output-seeds
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
10
724
203
757
Print best fitness and solution
output-best-fitness
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
121
311
249
371
Size-Of-Complex-Techs
1
1
0
Number

INPUTBOX
432
690
526
750
Chance-Adapt
0
1
0
Number

MONITOR
1305
490
1394
543
Initial Mean
init-mean-fitness
2
1
13

MONITOR
1306
546
1394
599
Initial Max
init-max-fitness
17
1
13

MONITOR
1306
603
1395
656
Initial Min
init-min-fitness
17
1
13

MONITOR
969
659
1103
712
# Agents Satisfied
num-satisfied
17
1
13

MONITOR
969
716
1094
769
Initial # Satisfied
init-num-satisfied
17
1
13

PLOT
698
659
965
828
Number of Fully Satisfied Agents
Time (ticks)
# Agents
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
698
304
1063
487
Number of Techs Per Agent
Time (ticks)
# Technologies
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -16777216 true "" ""
"Max" 1.0 0 -10873583 true "" ""
"Min" 1.0 0 -1604481 true "" ""

MONITOR
1067
305
1175
358
Mean # Techs
mean-num-techs
2
1
13

MONITOR
1067
360
1176
413
Max # Techs
max-num-techs
17
1
13

MONITOR
1067
416
1176
469
Min # Techs
min-num-techs
17
1
13

MONITOR
1179
305
1306
358
Mean # Adopters
mean-num-adopters
2
1
13

MONITOR
1179
361
1306
414
Max # Adopters
max-num-adopters
17
1
13

MONITOR
1179
416
1306
469
Min # Adopters
min-num-adopters
17
1
13

CHOOSER
4
89
142
134
Landscape-Type
Landscape-Type
"World" "4 Quarters"
1

BUTTON
589
511
685
544
Links on/off
toggle-links
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
4
185
170
230
Agent-Movement-Method
Agent-Movement-Method
"Static" "Random walk" "Star base" "Around base" "Mostly memory" "Mostly good memory"
4

BUTTON
386
479
465
512
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

CHOOSER
4
137
142
182
Initial-Techs-Method
Initial-Techs-Method
"All 0" "Random" "All 1"
0

SLIDER
11
507
183
540
Terrain-Constraints
Terrain-Constraints
0
128
16
4
1
NIL
HORIZONTAL

SLIDER
11
543
183
576
Social-Constraints
Social-Constraints
0
128
8
4
1
NIL
HORIZONTAL

SLIDER
11
578
183
611
Generic-Constraints
Generic-Constraints
0
128
8
4
1
NIL
HORIZONTAL

MONITOR
11
614
121
659
Total # Constraints
agent-type-constraints + terrain-constraints + social-constraints + generic-constraints
1
1
11

INPUTBOX
121
249
248
309
Number-Of-Agent-Types
1
1
0
Number

SLIDER
11
472
195
505
Agent-Type-Constraints
Agent-Type-Constraints
0
128
8
4
1
NIL
HORIZONTAL

TEXTBOX
4
39
213
57
(C) Christopher Watts, 2015.
13
0.0
1

TEXTBOX
16
786
166
826
Random Number Generator Seeds:
16
0.0
1

TEXTBOX
183
826
333
986
Set seed to 0 to make simulation use a different seed number each time. To repeat random numbers used in most recent simulation run, click button to print last seeds, then copy-paste seed number into corresponding input box.
13
0.0
1

TEXTBOX
253
536
592
563
Invention, Imitation, Discarding & Adaptation:
16
0.0
1

TEXTBOX
10
450
160
470
Fitness Definition:
16
0.0
1

TEXTBOX
8
64
238
88
World, Agent & Tech Setup:
16
0.0
1

INPUTBOX
7
374
129
434
Move-Memory-Length
10
1
0
Number

INPUTBOX
132
374
249
434
Move-Innovation
0.05
1
0
Number

@#$#@#$#@
# ADOPT AND ADAPT

## WHAT IS IT?

A model of multiple technology diffusion in which there are constraints on which technologies will work well with which others. Constraints may be due to the terrain in the landscape, the agents in one's neighbourhood, one's own attributes or due to some general physical properties of the technology itself.

Agents living in a landscape of grassland, forest, water and sand can adopt technologies/practices from each other. Different terrain places different constraints on an agent, and an agent may need to adapt a technology in order to profit from adopting it. The agent may need a different combination of technologies to other agents in order to profit from imitating a particular technology.

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 6 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

A combination of a constraint satisfaction problem (K-Sat), and diffusion of innovations through imitation of other agents.

### Landscapes and terrain

There are two types of landscape: "World" and "4 Quarters". In "4 Quarters", the world is divided into 4 quarters, each representing a different type of terrain: grassland (terrain 0, top left); forest (1, top right); sand (2, bottom left), and; water (3, bottom right). In "World", an extra terrain, Snow/Ice is added and the terrains are distributed in a pattern (very) crudely resembling the world's continents.

### Agents and technologies

A given number of agents is generated. Each agent has knowledge / possession of a given number of technologies / technological practices (called "techs"). This knowledge is represented as an array of 0/1 binary variables - an agent's current values can be seen in its label, whenever labels are being shown. In the default case, all agents start with knowledge of no technologies (label set to "0"s). Agents may discover technologies through invention, with some given chance, or they learn through imitation of one of the nearby agents within a given radius. There is a given chance, however, that an agent will try discarding a technology. Any changes in technological knowledge, whether due to invention, discarding or imitation, will only be accepted by an agent if they result in that agent's fitness not becoming worse.

### Complex technologies and adapting

"Techs" are basic, simple technologies. Invention, imitation and discarding all apply to "complex technologies", constructed from combinations of fixed length of basic technologies. By default the length of complex technologies is set to 1, thus equating them with basic techs. However, if Size-Of-Complex-Techs > 1, multiple bits will be copied whenever one agent imitates another. 

This allows the possibility that some of the bits representing adoption of a complex tech are modified during copying. In this way, a complex technology is adapted as well as adopted by the imitating agent. Some of the components of the complex tech are being modified. The parameter "Chance-Adapt" controls the chance of a bit being changed during imitation.


### Fitness due to terrain

At the start, for each terrain type a set of constraints is generated. These determine how well a particular technology "fits" with other technologies in that terrain. Each constraint set has a given number of constraints (though some duplication is possible). Each constraint consists of a given number, K, of technology variables, some of which may be negated. An agent's current fitness is calculated as the number of constraints satisfied by that agent's current technologies. The set of constraints used is that for the agent's current patch's terrain.

### Movement

Agents move, and may thereby change current patch and terrain type. There are multiple methods for controlling agents' movement. Under the default option, "Around base", each agent begins at its home base, then roams within a given radius of that home. Thus some agents will spend most, if not all, of their time within the same terrain, while others may cross between two or more different terrain types. When an agent changes terrain, its fitness is recalculated using the changed constraint set. Agents are depicted using the "person" shape, except when on water, for which they take to boats instead.


## HOW TO USE IT

The possibility of diffusion through imitation depends on the population density - i.e. the number of agents, the roaming radius size, the imitation radius size and the chance of imitation.

Invention occurs by chance with a given probability, but may also be caused by clicking a button. It is possible, however, that an invention event results only in a selected agent "discovering" a technology that agent already knows. It is also possible, that the agent discovers a previously unknown technology, but fails to keep it due to it breaking more constraints than the agent's previous technological knowledge. So clicking the invent button might fail to result in any noticeable change!

The difficulty of constraint satisfaction problems varies with the ratio between the number of constraints and the number of (technology) variables. As the ratio increases, the expected number of broken constraints undergoes a phase transition from very low to very high. The exact shape of this transition varies with the width of the constraints - i.e. the number of variables included in each constraint (the "K" in "K-Sat").


## THINGS TO NOTICE

Agents located in different terrains have satisfaction levels defined by different constraint sets - so expect to see technologies diffusing rapidly among agents who share terrain, but diffusion may fail between agents who tend to occupy different terrain. How many technologies are limited to particular terrains? Are there particular combinations of technologies that are limited to particular terrains?

Some agents roam between two or more types of terrain, and therefore have to satisfy more than one set of constraints. Is their technology list less constant? Is their mean satisfaction level lower?

The success of a particular technology depends on what other technologies its would-be adopters are already using. A technology may fail to take off at one time point, but then sweep through the population at a later point if in the meantime other technologies have spread that alter its value. A ubiquitous technology can also suffer a drop in popularity if a new technology emerges that conflicts with it. Look for such interdependencies between technologies in the time series plots.


## THINGS TO TRY

Try different size populations. How does this affect diffusion? Diffusion depends on whether agents roam sufficiently close to each other to be able to imitate, so try varying roam-radius and imitation-radius as well.

Try changing the definition of the K-Sat problem (varying the number of technologies, the number of constraints, and the width of a constraint). How does this affect diffusion? How does it affect fitness (satisfaction) over a particular length of time?

Try changing the type of constraints (agent-type, terrain, social, generic) while keeping the same total number of constraints.

Try changing the rates of the events that affect technology diffusion (invention, discarding and imitation). The agent population are solving constraint satisfaction (k-sat) problems. Can you optimise their problem-solving performance? (Of course, some rates may be far from realistic!)


## CURRENT EXTENSIONS

### Constraints due to other causes

As well as constraint due to current terrain, other constraint sets may be defined to go with the following factors:

* Agent-Type-Constraints: If Number-Of-Agent-Types > 1, there may be different constraint sets for different types of agents, just as different people have different roles and skillsets.
* Social-Constraints: These constraints apply to technologies held by oneself or any other agents in one's radius.
* Generic-Constraints: These apply at all times, whatever one's current terrain, agent-type or social environment.

### Movement methods

Several methods are provided for determining agents' movements:

* "Static": Agents do not move at all from their initial positions.
* "Random walk": Agents perform 1 step in a randomly chosen direction.
* "Star base": Agents choose a direction at random, then venture out from their base (their initial position), 1 step per tick, continuing in that direction until they hit the Roam-Radius. Then they turn around, head back to base and repeat with a new choice of direction.
* "Around base": Agents travel around within a circle (set by Roam-Radius) around their base (their initial position). Whenever they hit the edge of the circle, they turn a random amount within the circle.
* "Mostly memory": Agents head towards target patches. On reaching a target, agents choose a new one. Agents maintain a memory of given length of patches they have visited. With a given chance ("Move-Innovation"), an agent chooses to be its new target a patch within its Roam-Radius. Otherwise it samples a patch from memory.
* "Mostly good memory": Similar to "Mostly memory", except that patches are only added to memory if fitness at them is better than that remembered at the other patches in memory.


## FURTHER EXTENDING THE MODEL

Obviously, more complicated landscapes could be defined. The four-quarters landscape was chosen for its ability to make visual particular clusters of adopters. Real-world landscapes could be modelled instead for a particular set of technologies and practices, given information about the terrain-specific interdependencies between them.


## NETLOGO FEATURES

Note how to encode a K-Sat problem in NetLogo. (The relevant code is in setup-constraints, ksat-fitness and output-constraints. Remember, there are 4 types of constraint, so each subroutine contains 4 variations on the same code.) tconstraints is a list, with one item for each terrain. (For many more items a list might be considered inefficient.) Each item is a list of constraints. Each constraint is a list of index numbers - some of them negative to denote a negated variable. The index numbers are used with the techs array that each agent has to return binary values. Each constraint involves conjunction operations (AND) between its components.


## RELATED MODELS

There are lots of diffusion models, including those of disease epidemics, and those in which the inter-agent interactions occur in a social network of a given structure. Two questions to consider concerning diffusion: (1) How does agents' movement method affect diffusion? (2) Why do we not see the famous s-curve for adoption?

Epidemic models are not the only approach to modelling the diffusion of innovations. Probit models assume agents repeatedly decide whether or not to adopt, given their current environment which may change over time.

Ecological models include interdependent populations of different-species creatures - e.g. wolves and sheep, or foxes, rabbits and grass - and show complex dynamics over time in their population sizes. How similar is a ecological model to a technology-diffusion model?

Papers exist on k-sat problems and the heuristic search algorithms used to solve them, though NetLogo models may be hard to find. Lazer & Friedman (2007, Administrative Science Quarterly) model an organisation of agents who solve an NK fitness landscape problem using similar processes of imitation of neighbours and trial-and-error experimenting. There may be analogues to Lazer & Friedman's finding that model features that slow down the rate of diffusion (e.g. the organisation's network structure) can lead to better problem-solving performance (because of the balance between exploitation of existing solutions and further exploration of new solutions).


## CREDITS AND REFERENCES

For more on K-Sat problems, including their use in models of technological evolution see in chapters 8 and 9 in:  
Kauffman, Stuart (2000) "Investigations". Oxford: Oxford University Press.

An earlier version of this model was discussed in at the DIME Final Conference, University of Maastricht, NL, 2011, and at European Association of Studies in Science and Technology (EASST 010) Conference, University of Trento, Italy, 2010.

For an alternative model of collective problem solving (using NK fitness), see:
Lazer, D., & Friedman, A. (2007). "The network structure of exploration and exploitation." Administrative Science Quarterly, 52(4), 667-694. 


## VERSION HISTORY

26-Jun-2015: Revised setup-constraints so that the K variables in each constraint are distinct. (Of course, the constraints themselves may be repeated, so you are unlikely to get C distinct constraints in a set.)


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

boat
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

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
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment Diffusion Test" repetitions="10" runMetricsEveryStep="false">
    <setup>setup
flash-invention</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 10000</exitCondition>
    <metric>timer</metric>
    <metric>array:item techs-count 0</metric>
    <enumeratedValueSet variable="imitation-radius">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-constraints">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every-n-ticks">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-trial">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-fitness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-sim">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-complex-techs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
      <value value="30"/>
      <value value="35"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-imitation">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-c-width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roam-radius">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-techs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-invention">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-adapt">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment Adapting 40000" repetitions="40" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 40000</exitCondition>
    <metric>timer</metric>
    <metric>mean-num-techs</metric>
    <metric>max-num-techs</metric>
    <metric>min-num-techs</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>init-mean-fitness</metric>
    <metric>init-max-fitness</metric>
    <metric>init-min-fitness</metric>
    <metric>num-satisfied</metric>
    <metric>init-num-satisfied</metric>
    <metric>mean-num-adopters</metric>
    <metric>max-num-adopters</metric>
    <metric>min-num-adopters</metric>
    <enumeratedValueSet variable="chance-trial">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-complex-techs">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-imitation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-techs">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roam-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-c-width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every-n-ticks">
      <value value="40000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-invention">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-adapt">
      <value value="0"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="2.0E-4"/>
      <value value="5.0E-4"/>
      <value value="0.0010"/>
      <value value="0.0020"/>
      <value value="0.0050"/>
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="imitation-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-fitness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-constraints">
      <value value="8"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-sim">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment Adapting" repetitions="40" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 200000</exitCondition>
    <metric>timer</metric>
    <metric>mean-num-techs</metric>
    <metric>max-num-techs</metric>
    <metric>min-num-techs</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>init-mean-fitness</metric>
    <metric>init-max-fitness</metric>
    <metric>init-min-fitness</metric>
    <metric>num-satisfied</metric>
    <metric>init-num-satisfied</metric>
    <metric>mean-num-adopters</metric>
    <metric>max-num-adopters</metric>
    <metric>min-num-adopters</metric>
    <enumeratedValueSet variable="chance-trial">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-complex-techs">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-imitation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-techs">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roam-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-c-width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every-n-ticks">
      <value value="200000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-invention">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-adapt">
      <value value="0"/>
      <value value="1.0E-4"/>
      <value value="0.0010"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="imitation-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-fitness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-constraints">
      <value value="8"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-sim">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment Adapting 3" repetitions="40" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt;= 200000</exitCondition>
    <metric>timer</metric>
    <metric>mean-num-techs</metric>
    <metric>max-num-techs</metric>
    <metric>min-num-techs</metric>
    <metric>mean-fitness</metric>
    <metric>max-fitness</metric>
    <metric>min-fitness</metric>
    <metric>init-mean-fitness</metric>
    <metric>init-max-fitness</metric>
    <metric>init-min-fitness</metric>
    <metric>num-satisfied</metric>
    <metric>init-num-satisfied</metric>
    <metric>mean-num-adopters</metric>
    <metric>max-num-adopters</metric>
    <metric>min-num-adopters</metric>
    <enumeratedValueSet variable="chance-trial">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-complex-techs">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-imitation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-techs">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roam-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-c-width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-every-n-ticks">
      <value value="200000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-invention">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chance-adapt">
      <value value="0.9"/>
      <value value="0.99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="imitation-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-fitness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="terrain-constraints">
      <value value="8"/>
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-sim">
      <value value="0"/>
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
