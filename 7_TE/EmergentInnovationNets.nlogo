;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Emergent Innovation Networks
; Attempt at replication of model in
; Cowan, Robin, Nicolas Jonard & Jean-Benoit Zimmermann (2007) "Bilateral Collaboration and the Emergence of Innovation Networks",
; Management Science, 53(7) 1051-1067.
; This version (C) Christopher J Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array matrix]

globals [
  expected-returns
  probability-success
  total-credit
  structural-credit
  relational-credit
  created-knowledge
  a-outcome
  a-time
  a-dos ; degree of separation in alliance net via most likely path
  a-freq ; frequency of alliance attempts
  a-prob ; best probability of activating path to each node
  node-queue ; Used for dos calculations  
  node-queue-start
  node-queue-length
  
  ordered-firms
  ordered-firms-array
  decay
  
  num-additions
  sum-additions
  mean-additions
  
  mean-knowledge
  prev-mean-knowledge
  
  num-alinks
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

  mean-cliquishness
  min-cliquishness
  max-cliquishness

  mean-dos
  min-dos
  max-dos

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
]

breed [firms firm]
undirected-link-breed [alinks alink]

firms-own [
  knowledge
  
  num-successes
  num-self-successes
  
  e-partners
  a-partners
  matched
  max-exp-ret
  
  ; Network related
  degree
  constraint
  cliquishness
  dos
  reach
  closeness
  betweenness
  component
  predecessors
]

alinks-own [
;  time
;  outcome
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initialisation
to setup
  clear-all
  reset-ticks
  ask patches [set pcolor white]
  setup-decay
  setup-firms
  set ordered-firms sort firms
  set ordered-firms-array array:from-list ordered-firms
  set expected-returns matrix:make-constant number-of-firms number-of-firms 0 
  set probability-success matrix:make-constant number-of-firms number-of-firms 0 
  set total-credit matrix:make-constant number-of-firms number-of-firms 0 
  set structural-credit matrix:make-constant number-of-firms number-of-firms 0 
  set relational-credit matrix:make-constant number-of-firms number-of-firms 0 
  set created-knowledge matrix:make-constant number-of-firms number-of-firms 0 
  set a-outcome matrix:make-constant number-of-firms number-of-firms 0 
  set a-time matrix:make-constant number-of-firms number-of-firms 0 
  set a-freq matrix:make-constant number-of-firms number-of-firms 0 
  set a-dos matrix:make-constant number-of-firms number-of-firms (number-of-firms + 1)
  set node-queue array:from-list n-values number-of-firms [nobody]
  set a-prob array:from-list n-values number-of-firms [nobody]
  
  set mean-additions 0
  set num-additions 0
  set sum-additions 0
  set mean-knowledge 0
  set prev-mean-knowledge 0 
  
  calc-metrics
  my-update-plots
  
end

to setup-firms
  create-firms number-of-firms [
    set shape "circle"
    set knowledge array:from-list n-values number-of-knowledge-types [1 + random 2] ; What if continuous?
    set expected-returns array:from-list n-values number-of-firms [0]
    set num-successes 0
    set num-self-successes 0
  ]
  reposition-nodes-grid
  
end

to setup-decay
  ; calc decay function once only
  set decay array:from-list n-values Number-of-Time-Steps [0]
  let cur-time 0
  repeat Number-of-Time-Steps [
    array:set decay cur-time (Discount-Factor ^ cur-time)
    set cur-time cur-time + 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Iterations
to go
  if ticks = number-of-time-steps [stop]
  
  tick
  
  ; calc expected returns from alliances
  calc-relational-credit
  calc-structural-credit
  calc-total-credit
  calc-probability-success
  calc-created-knowledge
  calc-expected-returns
  ; create matching
  calc-matching
  ; update outputs
  if (0 = ticks mod output-every) [
    calc-wdos
    recreate-net
    
    calc-metrics
    my-update-plots
    if reposition-nodes [reposition-nodes-spring]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-relational-credit
  let ego-id 0
  let alter-id 0
  let last-outcome 0
  foreach ordered-firms [
    set ego-id [who] of ?
    set alter-id ego-id
    repeat ((count firms) - ego-id - 1) [
      set alter-id alter-id + 1
;    foreach sublist ordered-firms ego-id (length ordered-firms) [
;      set alter-id [who] of ?
      set last-outcome matrix:get a-outcome ego-id alter-id
      matrix:set relational-credit ego-id alter-id (ifelse-value (0 = last-outcome) [0] [(array:item decay (ticks - matrix:get a-time ego-id alter-id)) * last-outcome])
      matrix:set relational-credit alter-id ego-id (matrix:get relational-credit ego-id alter-id)
    ]
  ]
end

to calc-structural-credit
  let ego-id 0
  let alter-id 0
  let tertius 0
  let sc-sum 0
  foreach ordered-firms [
    set ego-id [who] of ?
    set alter-id ego-id
    repeat ((count firms) - ego-id - 1) [
      set alter-id alter-id + 1
    ;foreach sublist ordered-firms ego-id (length ordered-firms) [
      ;set alter-id [who] of ?
      set sc-sum 0
      foreach ordered-firms [
        set tertius [who] of ?
        if ego-id != tertius [
          if alter-id != tertius [
            set sc-sum sc-sum + ((matrix:get relational-credit ego-id tertius) * (matrix:get relational-credit tertius alter-id))
          ]
        ]
      ]
      matrix:set structural-credit ego-id alter-id sc-sum
      matrix:set structural-credit alter-id ego-id sc-sum
    ]
  ]
end

to calc-total-credit
  let ego-id 0
  let alter-id 0
  let o-sum 0
  foreach ordered-firms [
    set ego-id [who] of ?
    set o-sum (sum matrix:get-row a-outcome ego-id) - (matrix:get a-outcome ego-id ego-id)
    foreach ordered-firms [
      set alter-id [who] of ?
      ifelse o-sum = 0 [
        matrix:set total-credit ego-id alter-id 0
      ]
      [
        matrix:set total-credit ego-id alter-id 
         ((alpha * (matrix:get relational-credit ego-id alter-id) ) + ((1 - alpha) * (matrix:get structural-credit ego-id alter-id) / o-sum))
      ]
    ]
  ]
end

to calc-probability-success
  let ego-id 0
  let alter-id 0
  let prob-range (max-probability-success - min-probability-success)
  foreach ordered-firms [
    set ego-id [who] of ?
    foreach ordered-firms [
      set alter-id [who] of ?
      matrix:set probability-success ego-id alter-id 
       (min-probability-success + (prob-range * (matrix:get total-credit ego-id alter-id)))
    ]
  ]
end

to calc-created-knowledge
  let ego-id 0
  let ego nobody
  let alter-id 0
  let sum-total 0
  let k-element 0
  foreach ordered-firms [
    set ego-id [who] of ?
    set ego ?
    foreach sublist ordered-firms ego-id (length ordered-firms) [
      set alter-id [who] of ?

      set sum-total 0
      set k-element 0
      repeat number-of-knowledge-types [
        set sum-total sum-total + ((knowledge-element ego ? k-element) ^ K-Type-Substitution)
        set k-element k-element + 1
      ]
      
      matrix:set created-knowledge ego-id alter-id 
       (k-production-scale * (sum-total ^ (1 / K-Type-Substitution)))
      matrix:set created-knowledge alter-id ego-id (matrix:get created-knowledge ego-id alter-id)
    ]
  ]
end

to-report knowledge-element [ego alter k-element]
  let ego-val [array:item knowledge k-element] of ego
  let alter-val [array:item knowledge k-element] of alter
  
  report ifelse-value (ego-val < alter-val) [
    (((1 - theta) * ego-val) + (theta * alter-val))
  ]
  [
    (((1 - theta) * alter-val) + (theta * ego-val))
  ]
end

to calc-expected-returns
  let ego-id 0
  let alter 0
  foreach ordered-firms [
    set ego-id [who] of ?
    foreach ordered-firms [
      set alter [who] of ?
      matrix:set expected-returns ego-id alter 
       (matrix:get probability-success ego-id alter) * (matrix:get created-knowledge ego-id alter)
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-matching
  let ego nobody
  let alter nobody
  let unmatched-firms map [?] ordered-firms
  
  set num-additions 0
  set sum-additions 0
  
  let evaluator-id 0
  ask firms [
    set matched false
    set e-partners []
    set a-partners []
  ]
  ask firms [
    set evaluator-id who
;    set max-exp-ret max matrix:get-row expected-returns evaluator-id 
    set max-exp-ret -1
    foreach unmatched-firms [
      if max-exp-ret <= [matrix:get expected-returns evaluator-id who] of ? [
        ifelse max-exp-ret < [matrix:get expected-returns evaluator-id who] of ? [
          set max-exp-ret [matrix:get expected-returns evaluator-id who] of ?
          set e-partners (list ?)
        ]
        [
          set e-partners fput ? e-partners
        ]
      ]
    ]
  ]
  ask firms [
    foreach e-partners [
      ask ? [set a-partners fput myself a-partners]
    ]
  ]
  
  let num-matched 0
  while [num-matched < number-of-firms] [
    set ego max-one-of (firms with [not matched]) [max-exp-ret]
    set alter [first e-partners] of ego
    ask ego [set matched true]
    set unmatched-firms remove ego unmatched-firms
    ifelse ego = alter [
      set num-matched num-matched + 1
    ]
    [
      ask alter [set matched true]
      set unmatched-firms remove alter unmatched-firms
      set num-matched num-matched + 2
    ]
    
    attempt-innovation ego alter
    ask ego [
      foreach a-partners [
        ask ? [
          if not matched [
            set e-partners remove myself e-partners
            if 0 = length e-partners [
              set evaluator-id who
              set max-exp-ret -1
              foreach unmatched-firms [
                if [not matched] of ? [
                  if max-exp-ret <= [matrix:get expected-returns evaluator-id who] of ? [
                    ifelse max-exp-ret < [matrix:get expected-returns evaluator-id who] of ? [
                      set max-exp-ret [matrix:get expected-returns evaluator-id who] of ?
                      set e-partners (list ?)
                    ]
                    [
                      set e-partners fput ? e-partners
                    ]
                  ]
                ]
              ]
              foreach e-partners [
                ask ? [
                  set a-partners fput myself a-partners
                ]
              ]
            ]
          ]
        ]
      ]
    ]
    ask alter [
      foreach a-partners [
        ask ? [
          if not matched [
            set e-partners remove myself e-partners
            if 0 = length e-partners [
              set evaluator-id who
              set max-exp-ret -1
              foreach unmatched-firms [
                if [not matched] of ? [
                  if max-exp-ret <= [matrix:get expected-returns evaluator-id who] of ? [
                    ifelse max-exp-ret < [matrix:get expected-returns evaluator-id who] of ? [
                      set max-exp-ret [matrix:get expected-returns evaluator-id who] of ?
                      set e-partners (list ?)
                    ]
                    [
                      set e-partners fput ? e-partners
                    ]
                  ]
                ]
              ]
              foreach e-partners [
                ask ? [
                  set a-partners fput myself a-partners
                ]
              ]
            ]
          ]
        ]
      ]
    ]
            
  ]
  
  if num-additions > 0 [ set mean-additions sum-additions / num-additions ]
  
end

to calc-matching-alt
  let ego nobody
  let alter nobody
  let evaluator-id 0
  let possible-pairings []
  let current-pairing array:from-list (list nobody nobody 0)
  let best-exp-ret 0
  set num-additions 0
  set sum-additions 0

  foreach ordered-firms [
    set ego ?
    set evaluator-id [who] of ?
    ;ask ego [set matched false]
    foreach ordered-firms [
      set possible-pairings fput (array:from-list (list ego ? ([matrix:get expected-returns evaluator-id who] of ?))) possible-pairings
    ]
  ]
  
  let num-matched 0
  while [num-matched < number-of-firms] [
    set best-exp-ret max map [array:item ? 2] possible-pairings
    set current-pairing one-of filter [best-exp-ret = array:item ? 2] possible-pairings
    set ego array:item current-pairing 0
    set alter array:item current-pairing 1
    ask ego [set matched true]
    ifelse ego = alter [
      set num-matched num-matched + 1
    ]
    [
      ask alter [set matched true]
      set num-matched num-matched + 2
    ]
    attempt-innovation ego alter
    
    set possible-pairings filter [not ((member? ego (array:to-list ?)) or (member? alter (array:to-list ?)))] possible-pairings
  ]
  
  if num-additions > 0 [ set mean-additions sum-additions / num-additions ]
  
end

to calc-matching-old
  set num-additions 0
  set sum-additions 0
  
  let evaluator-id 0
  ask firms [
    set matched false
    set evaluator-id who
    set e-partners sort-by [([matrix:get expected-returns evaluator-id who] of ?1) > ([matrix:get expected-returns evaluator-id who] of ?2)] firms
  ]
  
  let ego nobody
  let alter nobody
  let num-matched 0
  while [num-matched < number-of-firms] [
    ask firms with [not matched] [
      while [ifelse-value (0 < length e-partners) [[matched] of first e-partners] [false]] [
        set e-partners but-first e-partners
      ]
    ]
    set ego max-one-of (firms with [not matched]) [matrix:get expected-returns who ([who] of first e-partners)]
    set alter [first e-partners] of ego
    ask ego [set matched true]
    ifelse ego = alter [
      set num-matched num-matched + 1
    ]
    [
      ask alter [set matched true]
      set num-matched num-matched + 2
    ]
    attempt-innovation ego alter
  ]
  
  if num-additions > 0 [ set mean-additions sum-additions / num-additions ]
  
end

to attempt-innovation [ego alter]
  let ego-id [who] of ego
  let alter-id [who] of alter
  let prob-s 0
  matrix:set a-freq ego-id alter-id (1 + matrix:get a-freq ego-id alter-id) ; Should we count only alliances with innov. successes?
  matrix:set a-freq alter-id ego-id (matrix:get a-freq ego-id alter-id)
  
  ifelse ego = alter [
    set prob-s max-probability-success
  ]
  [
    set prob-s (matrix:get probability-success ego-id alter-id)
  ]
  
  ifelse (random-float 1) < prob-s [
    ; Success!
    matrix:set a-outcome ego-id alter-id 1
    matrix:set a-outcome alter-id ego-id 1
    matrix:set a-time ego-id alter-id ticks
    matrix:set a-time alter-id ego-id ticks
    
    let weights []
    let cur-element -1
    repeat number-of-knowledge-types [
      set cur-element cur-element + 1
      set weights fput (knowledge-element ego alter cur-element) weights
    ]
    let weight-sum random-float sum weights
    set cur-element number-of-knowledge-types 
    while [weight-sum >= 0] [
      set cur-element cur-element - 1
      set weight-sum weight-sum - first weights
      set weights but-first weights
    ]
    let k-addition (matrix:get created-knowledge ego-id alter-id)
    
    ask ego [
      ; Is knowledge supposed to be bounded or unbounded? continuous or discrete? Paper was unclear!
;      array:set knowledge cur-element (ifelse-value (k-addition + (array:item knowledge cur-element) <= 2) [k-addition + (array:item knowledge cur-element)] [2])
      array:set knowledge cur-element (k-addition + (array:item knowledge cur-element))
;      array:set knowledge cur-element k-addition
      
      if ego = alter [
        set num-self-successes num-self-successes + 1
      ]
      set num-successes num-successes + 1
    ]
    ask alter [
;      array:set knowledge cur-element (ifelse-value (k-addition + (array:item knowledge cur-element) <= 2) [k-addition + (array:item knowledge cur-element)] [2])
      array:set knowledge cur-element (k-addition + (array:item knowledge cur-element))
;      array:set knowledge cur-element k-addition
      if ego != alter [
        set num-successes num-successes + 1
      ]
    ]
;    print (word ego ", " alter ", 1, " cur-element ", " k-addition)
    set num-additions num-additions + 1
    set sum-additions sum-additions + k-addition
  ]
  [
    ; Failure!
    matrix:set a-outcome ego-id alter-id 0
    matrix:set a-outcome alter-id ego-id 0
    matrix:set a-time ego-id alter-id ticks
    matrix:set a-time alter-id ego-id ticks
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-wdos
  ; Calculate degrees of separation in a weighted network
  set a-dos matrix:make-constant number-of-firms number-of-firms (number-of-firms + 1)
  let cur-node nobody
  let cur-id 0
  let cur-prob 0
  let cur-dos 0
  let cur-rowsum 0
;  let cur-list (list nobody 1 0)
  let alt-prob 0
  ask firms [
;    let start-node self
    let start-id who
    set a-prob array:from-list n-values number-of-firms [-1]
    set node-queue-start 0
    array:set node-queue 0 (list self 1 0)
    set node-queue-length node-queue-length + 1
    while [node-queue-length > 0] [
      set cur-node item 0 (array:item node-queue node-queue-start)
      set cur-prob item 1 (array:item node-queue node-queue-start)
      set cur-dos item 2 (array:item node-queue node-queue-start)
      set cur-id [who] of cur-node
      matrix:set a-dos start-id cur-id cur-dos
      set node-queue-start (node-queue-start + 1) mod number-of-firms
      set node-queue-length node-queue-length - 1
      set cur-rowsum sum matrix:get-row a-freq cur-id
      if cur-rowsum > 0 [
        ask other firms with [0 < matrix:get a-freq cur-id who] [
          set alt-prob (cur-prob * matrix:get a-freq cur-id who) / cur-rowsum
          if alt-prob > (array:item a-prob who) [
            array:set a-prob who alt-prob
            array:set node-queue ((node-queue-start + node-queue-length) mod number-of-firms) (list self (alt-prob) (cur-dos + 1))
            set node-queue-length node-queue-length + 1
          ]
        ]
      ]
    ]
  ]
end

to recreate-net
  ;ask alinks [ die ]
  let ego-id 0
  let alter-id 0
  let ego nobody
  let alter nobody
  foreach ordered-firms [
    set ego ?
    set ego-id [who] of ?
    foreach ordered-firms [
      if ? != ego [
        set alter ?
        set alter-id [who] of ?
;        ifelse 1 = matrix:get a-outcome ego-id alter-id [
;        ifelse 0 < matrix:get a-freq ego-id alter-id [
        ifelse 1 = matrix:get a-dos ego-id alter-id [
          ask ego [
            if not alink-neighbor? alter [
              create-alink-with alter [ set color grey ]
            ]
          ]
        ]
        [
          ask ego [ 
            if alink-neighbor? alter [
              ask alink-with alter [ die ]
            ]
          ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Networks
;; Repositioning an already created network
to reposition-nodes-spring
  ;layout-spring turtle-set link-set spring-constant spring-length repulsion-constant 
  repeat 10 [layout-spring firms alinks 0.2 (1.5 * max-pxcor / (sqrt count firms)) 1]
  
end

to reposition-nodes-circle
  layout-circle (sort firms) (max-pxcor * 0.4)
  
end

to reposition-nodes-grid
  let numnodes (count firms)
  let numcols int sqrt numnodes
  if (numcols ^ 2) < numnodes [set numcols numcols + 1]
  let numrows int (numnodes / numcols)
  if (numcols * numrows) < numnodes [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
  
  let orderedset sort firms
  foreach orderedset [
    ask ? [
      set xcor (xspace * (1 + (who mod numcols)))
      set ycor (yspace * (1 + int (who / numcols)))
    ]
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculate various node and network metrics
to calc-metrics
  calc-degree
  calc-components
  set net-density (2 * (count alinks) / ((count firms) * ((count firms) - 1)))
  ifelse calculate-slow-metrics [
    calc-net-constraint
    calc-cliquishness
    calc-assortativity
    calc-betweenness
  ]
  [
    calc-cliquishness
    calc-dos
  ]
  
end

to calc-degree
  ; Degree centrality = # links
  ask firms [
    set degree (count my-alinks)
  ]
  
  set mean-degree mean [degree] of firms
  set min-degree min [degree] of firms
  set max-degree max [degree] of firms
  set median-degree median [degree] of firms
  
end

to calc-net-constraint
  let csum 0
  let cij 0
  ask firms [
    let degi (count my-alinks)
    let origin self
    set csum 0
    ask alink-neighbors [
      ; direct or (direct and indirect)
      set cij (1 / degi)
      let dest self
      ask [alink-neighbors] of origin [
        if (alink-neighbor? dest) [
          set cij (cij + (1 / (degi * (count my-alinks))))
        ]
      ]
      set csum (csum + (cij ^ 2))
      
    ]
    set constraint csum
  ]
  set net-constraint sum [constraint] of firms
  set mean-constraint mean [constraint] of firms
  set min-constraint min [constraint] of firms
  set max-constraint max [constraint] of firms
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
  
  ask firms [
    set num-triangles 0
    set num-2stars 0

    ; cliquishness = proportion of 2-stars that are triangles
    set temp-neighbors alink-neighbors
    ask temp-neighbors [
      set origin self
      ask temp-neighbors [
        if alink-neighbor? origin [
          if (origin != self) [
            set num-triangles num-triangles + 1
          ]
        ]
      ]
    ]
    set num-2stars (count alink-neighbors) * ((count alink-neighbors) - 1)
    
    ifelse (num-2stars = 0) [
      set cliquishness 0
    ]
    [
      set cliquishness (num-triangles / num-2stars)
    ]
    set tot-num-triangles tot-num-triangles + num-triangles
    set tot-num-2stars tot-num-2stars + num-2stars
  ]
  
  set mean-cliquishness mean [cliquishness] of firms
  set min-cliquishness min [cliquishness] of firms
  set max-cliquishness max [cliquishness] of firms
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
  ask firms [
    set sum1 sum1 + ((count alink-neighbors) * degree)
    set sum3 sum3 + (count alink-neighbors)
    ask alink-neighbors [
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
    ask firms [
      set temp-diff (degree - avg1)
      set sum2 sum2 + ((count alink-neighbors) * (temp-diff ^ 2))
      ask alink-neighbors [
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
; Ulrik Brandes's betweenness algorithm
;
  let CB array:from-list n-values (count firms) [0]
  let S [] ; Stack (LIFO)
  let Q [] ; Queue (FIFO)
  let R array:from-list n-values (count firms) [0] ; # paths
  let d array:from-list n-values (count firms) [0] ; distance
  ;let P array:from-list n-values (count firms) [0] ; Predecessor list
  let dep array:from-list n-values (count firms) [0]
  let v nobody
  let v-who 0
  let w nobody
  let w-who 0
  let maxdos 0
;  let denominator (((count firms) - 1) * ((count firms) - 2) / 2)
  let denominator ((count firms) - 1) * ((count firms) - 2) 
  set net-diameter -1
  
  ask firms [
    set S []
    ask firms [ set predecessors [] ]
    ;set P []
    set R array:from-list n-values (count firms) [0]
    array:set R who 1
    set d array:from-list n-values (count firms) [-1]
    array:set d who 0
    set Q []
    set Q lput self Q
    while [length Q > 0] [
      set v first Q
      set Q but-first Q
      set S fput v S
      set v-who [who] of v
      ask [alink-neighbors] of v [
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
    
    set dep array:from-list n-values (count firms) [0]
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

  ask firms [
    set betweenness (array:item CB who) / denominator
  ]

  set mean-dos mean [dos] of firms
  set min-dos min [dos] of firms
  set max-dos max [dos] of firms
  
  set mean-closeness mean [closeness] of firms
  set min-closeness min [closeness] of firms
  set max-closeness max [closeness] of firms
  
  set mean-betweenness mean [betweenness] of firms
  set min-betweenness min [betweenness] of firms
  set max-betweenness max [betweenness] of firms
  
  set degree-centralization number-of-firms * (max-degree - mean-degree) / ((number-of-firms - 1) * (number-of-firms - 2))
  set closeness-centralization number-of-firms * (max-closeness - mean-closeness) * (2 * number-of-firms - 3) / ((number-of-firms - 1) * (number-of-firms - 2))
  
end  

to calc-dos
; From Ulrik Brandes's betweenness algorithm
;
  let Q [] ; Queue (FIFO)
  let d array:from-list n-values (count firms) [0] ; distance
  let v nobody
  let v-who 0
  let maxdos 0
  set net-diameter -1
  
  ask firms [
    set d array:from-list n-values (count firms) [-1]
    array:set d who 0
    set Q []
    set Q lput self Q
    while [length Q > 0] [
      set v first Q
      set Q but-first Q
      set v-who [who] of v
      ask [alink-neighbors] of v [
        if (array:item d who) < 0 [
          set Q lput self Q
          array:set d who (1 + array:item d v-who)
        ]
      ]
    ]
    
    set reach sum map [ifelse-value (? >= 0) [1] [0]] (array:to-list d)
    set dos (sum (array:to-list d)) / reach
    set closeness ifelse-value (dos <= 0) [0] [(reach - 1) / (dos * reach)]
    set maxdos max (array:to-list d)
    if (maxdos > net-diameter) [ set net-diameter maxdos ]
  ]

  set mean-dos mean [dos] of firms; with [dos >= 0]
  set min-dos min [dos] of firms; with [dos >= 0]
  set max-dos max [dos] of firms; with [dos >= 0]
  
  set mean-closeness mean [closeness] of firms
  set min-closeness min [closeness] of firms
  set max-closeness max [closeness] of firms
  
  set degree-centralization number-of-firms * (max-degree - mean-degree) / ((number-of-firms - 1) * (number-of-firms - 2))
  set closeness-centralization number-of-firms * (max-closeness - mean-closeness) * (2 * number-of-firms - 3) / ((number-of-firms - 1) * (number-of-firms - 2))

end  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-components
  ; Calculate a network component for each node, and the size of the largest component
  let nodestack []
  let tempnode nobody
  let num-members 0
  
  set num-components 0
  set max-component 0
  ask firms [ set component 0]
  ask firms [
    if (component = 0) [
      set nodestack []
      set num-components num-components + 1
      if (num-members > max-component) [set max-component num-members]
      set num-members 1
      
      set component num-components
      ask alink-neighbors with [component = 0] [
        set nodestack fput self nodestack
      ]
      
      while [not empty? nodestack] [
        set tempnode first nodestack
        set nodestack but-first nodestack
        ask tempnode [
          if (component = 0) [
            set component num-components
            set num-members num-members + 1
            ask alink-neighbors with [component = 0] [
              set nodestack fput self nodestack
            ]
          ]
        ]
      ]
      
    ]
  ]
  if (num-members > max-component) [set max-component num-members]
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Plots
to my-update-plots
  set-current-plot "Innovation Production"
  plotxy ticks mean-additions
  
  set-current-plot "Knowledge"
  set prev-mean-knowledge mean-knowledge
  set mean-knowledge mean [mean array:to-list knowledge] of firms
  plotxy ticks mean-knowledge
  set-current-plot "Knowledge Growth"
  plotxy ticks ifelse-value (prev-mean-knowledge = 0) [0] [100 * (((mean-knowledge / prev-mean-knowledge) ^ (1 / output-every)) - 1)]
  
  set-current-plot "Density"
  plotxy ticks net-density

  set-current-plot "Components"
  set-current-plot-pen "# Components"
  plotxy ticks num-components
  set-current-plot-pen "Largest"
  plotxy ticks max-component

  set-current-plot "Clustering Coefficient"
  plotxy ticks clust-coeff
  
  set-current-plot "Degree Centralization"
  plotxy ticks degree-centralization

  set-current-plot "Degree of Connectivity"
  set-current-plot-pen "Mean"
  plotxy ticks mean-degree
  set-current-plot-pen "Min"
  plotxy ticks min-degree
  set-current-plot-pen "Max"
  plotxy ticks max-degree

  set-current-plot "Degree of Separation"
  set-current-plot-pen "Mean"
  plotxy ticks mean-dos
  set-current-plot-pen "Min"
  plotxy ticks min-dos
  set-current-plot-pen "Max"
  plotxy ticks max-dos
  
end

to print-knowledge
  foreach sort firms [
    ask ? [
      show (array:to-list knowledge)
    ]
  ]
end

to toggle-labels
  ask firms [
    ifelse label = "" [
      set label who
    ]
    [
      set label ""
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
230
10
669
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

TEXTBOX
6
6
203
58
Emergent Innovation Networks
21
0.0
1

TEXTBOX
6
64
220
82
After: Cowan Et Al. (2007)
13
0.0
1

INPUTBOX
6
86
161
146
Number-of-Firms
100
1
0
Number

SLIDER
6
148
207
181
Number-of-Knowledge-Types
Number-of-Knowledge-Types
2
10
5
1
1
NIL
HORIZONTAL

SLIDER
5
255
177
288
Theta
Theta
0
1
0.4
.01
1
NIL
HORIZONTAL

SLIDER
5
200
177
233
Alpha
Alpha
0
1
0.1
0.01
1
NIL
HORIZONTAL

INPUTBOX
5
291
160
351
K-Production-Scale
1.0E-7
1
0
Number

INPUTBOX
5
354
160
414
K-Type-Substitution
0.1
1
0
Number

INPUTBOX
5
417
160
477
Discount-Factor
0.98
1
0
Number

SLIDER
5
480
189
513
Min-Probability-Success
Min-Probability-Success
0
1
0.75
.01
1
NIL
HORIZONTAL

SLIDER
5
516
189
549
Max-Probability-Success
Max-Probability-Success
0
1
0.95
.01
1
NIL
HORIZONTAL

INPUTBOX
230
473
385
533
Number-of-Time-Steps
200
1
0
Number

BUTTON
387
473
451
506
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
454
473
517
506
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
230
537
410
570
Calculate-Slow-Metrics
Calculate-Slow-Metrics
1
1
-1000

BUTTON
520
473
599
506
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
604
474
670
507
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

MONITOR
680
10
767
63
Net Density
net-density
4
1
13

MONITOR
769
10
879
63
# Components
num-components
17
1
13

MONITOR
882
10
1023
63
Largest Component
max-component
17
1
13

PLOT
680
64
880
230
Density
Time (ticks)
Density
0.0
1.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
680
233
988
383
Components
Time (ticks)
# Nodes
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"# Components" 1.0 0 -2674135 true "" ""
"Largest" 1.0 0 -13345367 true "" ""

PLOT
683
653
992
803
Degree of Separation
Time (ticks)
DOS
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -2674135 true "" ""
"Min" 1.0 0 -11221820 true "" ""
"Max" 1.0 0 -13345367 true "" ""

PLOT
991
233
1191
383
Clustering Coefficient
Time (ticks)
Clust. Coeff.
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
884
64
1108
229
Degree Connectivity
Time (ticks)
# Links
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Mean" 1.0 0 -2674135 true "" ""
"Min" 1.0 0 -11221820 true "" ""
"Max" 1.0 0 -13345367 true "" ""

SWITCH
411
537
563
570
Reposition-Nodes
Reposition-Nodes
0
1
-1000

MONITOR
1026
10
1181
63
Degree Centralization
degree-centralization
3
1
13

MONITOR
682
574
785
627
# Innovations
num-additions
17
1
13

MONITOR
789
574
910
627
Mean Innovation
mean-additions
3
1
13

PLOT
680
386
880
563
Innovation Production
Time (ticks)
Mean Additions
0.0
1.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

TEXTBOX
6
236
222
254
Knowledge Task Structure:
13
0.0
1

TEXTBOX
9
183
238
201
Relational vs. Structural Embedding:
13
0.0
1

INPUTBOX
8
604
163
664
Output-Every
1
1
0
Number

BUTTON
230
579
350
612
Print Knowledge
print-knowledge
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
684
802
1022
821
(Not very meaningful unless all nodes in one component.)
13
0.0
1

BUTTON
410
579
514
612
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

MONITOR
1185
10
1308
63
Clustering Coeff.
clust-coeff
3
1
13

MONITOR
913
574
1038
627
Mean Knowledge
mean-knowledge
3
1
13

MONITOR
1041
574
1160
627
Mean % Growth
100 * (((mean-knowledge / prev-mean-knowledge) ^ (1 / output-every)) - 1)
1
1
13

PLOT
883
386
1083
563
Knowledge
Time (ticks)
Type Mean
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
1086
386
1286
563
Knowledge Growth
Time (ticks)
% Growth
0.0
1.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
1111
64
1311
229
Degree Centralization
Time (ticks)
Centralization
0.0
1.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

@#$#@#$#@
# A Model of Emergent Innovation Networks

An attempt at replicating the model described in Cowan et al (2007).

Agent firms seek to improve their knowledge through quantitative innovation in several dimensions. To do this they form alliances with other firms, thus forming innovation networks.

This program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 7 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

Knowledge for solving tasks exists in several types or dimensions. Firms have various amounts of knowledge in each type. This knowledge is drawn upon when firms try to create new knowledge (innovation). 

Firms can either attempt innovation on their own or seek a collaborator to innovate with. A firm evaluates a potential partner on the basis of expected gain in knowledge, i.e. the gain in knowledge multiplied by the probability of success. The probability is a function of past direct experience of collaboration with that firm (relational credit) and the indirect experience of their other partners of working with that firm (structural credit). A parameter (__alpha__) controls the balance between relational and structural credit.

Gain in knowledge is calculated using a Cobb-Douglas production function, with the knowledge in the various dimensions as inputs. The extent to which expertise in one dimension can substitute for that in another dimension is controlled by a parameter, __K-type-substitution__.

Interdependencies between the tasks addressed by knowledge mean that two collaborating firms cannot always use the best knowledge among them. Two firms collaborating may be able to benefit from the maximum knowledge value among them, or be restricted to the minimum value among them. A parameter (__theta__) controls the extent to which firms take the max rather than the min.

Once all firms have evaluated all firms for expected gains in knowledge, a matching algorithm pairs alliance partners up. Innovation is then attempted. There is __a minimum and a maximum probability of success__ for innovation.

If innovation is successful, firms have their knowledge updated and record the outcome of the collaboration in their relational credit. Credit must be renewed, since it is discounted over time according to the parameter __Discount-Factor__.

Recent history of successful collaborations is used to create network links, representing an innovation network of alliances among firms. Various metrics are then calculated for this network.


## HOW TO USE IT

Click "Setup" to create the firms and their initial knowledge. 

Click "Go". Watch the emergence of an innovation network.

If you have access to it, ideally read Cowan et al. (2007). Watts & Gilbert (2014, ch.7) also covers the model, but in less detail.


## THINGS TO NOTICE

Depending on the parameters, the amount of knowledge increases and a network emerges among the firms. The properties of the network, reflected in the network metrics, evolve over time.


## THINGS TO TRY

Cowan et al. (2007) explored the effects on network structure had by varying the parameters, especially theta and alpha. As reported in Watts & Gilbert (2014, ch. 7), we failed to reproduce their results with this program. Why this is is a moot point now, since Cowan et al. report having lost the code to their original. We invite our readers' suggestions.

Try modifying the program to see if you can reproduce the experiment results reported in Cowan et al. (2007). E.g. how else could firms be matched together?


## EXTENDING THE MODEL

Try alternative representations of knowledge and innovation (e.g. NK fitness?) while keeping the ideas of collaboration partner selection and emergent innovation networks.


## RELATED MODELS

For an alternative simulation of innovation networks, see the SKIN model.


## CREDITS AND REFERENCES

Cowan, Robin, Nicolas Jonard & Jean-Benoit Zimmermann (2007) "Bilateral Collaboration and the Emergence of Innovation Networks", Management Science, 53(7) 1051-1067.


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
  <experiment name="experiment-VaryAlphaTheta" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-additions</metric>
    <metric>mean-additions</metric>
    <metric>max-component</metric>
    <metric>num-components</metric>
    <metric>net-density</metric>
    <metric>clust-coeff</metric>
    <metric>ifelse-value (net-density = 0) [0] [clust-coeff / net-density]</metric>
    <metric>net-diameter</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <metric>mean-degree</metric>
    <metric>max-degree</metric>
    <metric>min-degree</metric>
    <metric>median-degree</metric>
    <metric>mean-dos</metric>
    <metric>max-dos</metric>
    <metric>min-dos</metric>
    <metric>mean-closeness</metric>
    <metric>max-closeness</metric>
    <metric>min-closeness</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Knowledge-Types">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Alpha" first="0" step="0.1" last="1"/>
    <steppedValueSet variable="Theta" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="K-Type-Substitution">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Discount-Factor">
      <value value="0.98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Production-Scale">
      <value value="1.0E-8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Probability-Success">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-Probability-Success">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Time-Steps">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reposition-Nodes">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate-Slow-Metrics">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-VaryAlphaTheta-Subst" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>num-additions</metric>
    <metric>mean-additions</metric>
    <metric>max-component</metric>
    <metric>num-components</metric>
    <metric>net-density</metric>
    <metric>clust-coeff</metric>
    <metric>ifelse-value (net-density = 0) [0] [clust-coeff / net-density]</metric>
    <metric>net-diameter</metric>
    <metric>degree-centralization</metric>
    <metric>closeness-centralization</metric>
    <metric>mean-degree</metric>
    <metric>max-degree</metric>
    <metric>min-degree</metric>
    <metric>median-degree</metric>
    <metric>mean-dos</metric>
    <metric>max-dos</metric>
    <metric>min-dos</metric>
    <metric>mean-closeness</metric>
    <metric>max-closeness</metric>
    <metric>min-closeness</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Knowledge-Types">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Alpha" first="0" step="0.1" last="1"/>
    <steppedValueSet variable="Theta" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="K-Type-Substitution">
      <value value="0.99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Discount-Factor">
      <value value="0.98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="K-Production-Scale">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Probability-Success">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Min-Probability-Success">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Time-Steps">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reposition-Nodes">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate-Slow-Metrics">
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
