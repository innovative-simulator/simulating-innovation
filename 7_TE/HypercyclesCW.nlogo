;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Padgett's (1997; 2003) hypercycles model of economic production as chemistry
;; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  i-environment
  o-environment
  recent-history
  num-completed
  num-rules-learned
  p-rule-freqs
  num-input-product-types
  num-output-product-types
  num-env-product-types
  plot-rule-complexity ; # plot pens
  
  product-turtle
  product-colours
  
  init-timer
  init-net-density
  
  arule-adjustments
  outchain
  num-cycles
  cycle-lengths
  num-distinct-rules
  num-parasite-rules
  perc-parasite-rules
  num-parasite-links
  num-parasite-firms
  perc-parasite-links
  perc-parasite-firms
  
  fp-stack ; firm-product stack (Used for counting hypercycles)
  cycles-found
  
  last-seed
]

breed [firms firm]
breed [products product]
; N.B. We do not explicitly model the products.
undirected-link-breed [nlinks nlink] ; Network of firms

firms-own [
  p-rules ; Production rules as [input-product output-product #copies]
  p-rule-sum ; # rules (of any type)
  p-rule-list ; Initial production rules, non-unique values. (Inefficient to work with if 1 firm holds many copies of the same rule)
  product-procd ; Product processed. Used for identifying hypercycles
  p-rule-tbp ; P-Rule To Be Processed.
  neigh-tbp ; Neighbour To Be Processed.
  p-rule-in-hc ; distinct p-rules in at least one hypercycle
]

nlinks-own [
  hl-products ; rules linking higher firm to lower firm (higher and lower in terms of who numbers)
  lh-products ; rules linking lower firm to higher firm
]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup [calc-hc]
  clear-all
  reset-ticks
  set init-timer timer
  
  setup-rng
  
  let tmp-color-list (list red yellow green cyan sky blue violet magenta pink brown)
  set product-colours array:from-list (sentence tmp-color-list (map [? + 2] tmp-color-list) (map [? - 2] tmp-color-list))
;  set product-colours array:from-list (sentence tmp-color-list )
  set p-rule-freqs array:from-list n-values rule-complexity [0]
  set plot-rule-complexity min (list 10 rule-complexity)
  
  ask patches [set pcolor white]
  ;set fp-stack array:from-list n-values ((rule-complexity * number-of-firms) + 1) [0]
  
  create-firms number-of-firms [
    set shape "factory"
    set size 6
    set color grey
    set label-color black
    set product-procd array:from-list n-values rule-complexity [0]
    set p-rule-tbp []
    set neigh-tbp []
    set p-rule-in-hc []
    set p-rules []
    set p-rule-list []
    set p-rule-sum 0
  ]
  
  create-products 1 [
    set hidden? true
    set size 10
    set product-turtle self
  ]
  
  setup-knowledge
  
  setup-links
  
  setup-environment
    
  set num-completed 0
  set num-rules-learned 0
  set recent-history []
  set num-distinct-rules sum [length p-rules] of firms
  set num-parasite-rules 0
  set num-parasite-links 0
  set num-parasite-firms 0
  
  if calc-hc [calc-hypercycles false]
  
  my-setup-plots
  
end

to setup-rng
  set last-seed rng-seed
  if last-seed = 0 [
    set last-seed new-seed
  ]
  random-seed last-seed
end

to print-last-seed
  print (word "Most recent RNG Seed: " last-seed)
end

to-report ruletype-all
  ; returns index number for a valid rule, when all hypercycle types are permitted.
  ; If rule is x->y, index is (x * rule-complexity) + y
  let input random rule-complexity
  let output random (rule-complexity - 1) ; No x->x rules. Although they would be interesting, e.g. as transporters.
  report (list input (output + ifelse-value (output >= input) [1] [0]))
end

to-report ruletype-solo
  ; returns index number for a valid rule, when only hypercycle type permitted is 1->2, ..., n->1.
  ; (Of course, we use product-ID = product-label - 1. A little confusing, but easier to compute.)
  ; If rule is x->(x+1), index is (x * rule-complexity) + ((x+1) mod rule-complexity)
  let input-product (random rule-complexity)
  report (list (input-product) ((input-product + 1) mod rule-complexity))
end

to-report ruletype-various
  if chemistry = "Solo Hypercycle" [report ruletype-solo]
  if chemistry = "All" [report ruletype-all]
end

to setup-knowledge
  ; Evenly distribute rules among firms
  let ruletype 0
  let num-rules-per-firm int (number-of-rules / (count firms))
  let num-remaining (number-of-rules mod (count firms))
  if num-rules-per-firm > 0 [
    ask firms [
      repeat num-rules-per-firm [
        set p-rule-list fput ruletype-various p-rule-list
      ]
;      set p-rule-sum num-rules-per-firm
    ]
  ]
  repeat num-remaining [
    ask n-of num-remaining firms [
      set p-rule-list fput ruletype-various p-rule-list
;      set p-rule-sum p-rule-sum + 1
    ]
  ]
  ask firms [
    set p-rule-sum length p-rule-list
    construct-p-rules
    set p-rule-list []
  ]
end

to construct-p-rules
  ; Given p-rule-list in form [input-product output-product]
  ; produce p-rules in form [input-product output-product #copies]
  set p-rules []
  set p-rule-list sort-by [(item 0 ?1) < (item 0 ?2)] p-rule-list
  set p-rule-list sort-by [((item 0 ?1) < (item 0 ?2)) and ((item 1 ?1) < (item 1 ?2))] p-rule-list
  let rulecount 1
  let cur-item first p-rule-list
  foreach (but-first p-rule-list) [
    ifelse cur-item = ? [
      set rulecount rulecount + 1
    ]
    [
      set p-rules fput (sentence cur-item rulecount) p-rules
      set rulecount 1
      set cur-item ?
    ]
  ]
  set p-rules fput (sentence cur-item rulecount) p-rules
  set p-rules reverse p-rules
end  

to setup-environment
  if input-environment = "Rich" [
    set i-environment array:from-list n-values rule-complexity [number-of-starting-products] ; # per product
;    set i-environment array:from-list n-values rule-complexity [int (number-of-starting-products / rule-complexity)] ; # shared out among products
;    ; Ensure all starting products allocated uniformly
;    let tmp-counter 0
;    repeat (number-of-starting-products mod rule-complexity) [
;      array:set i-environment tmp-counter (1 + array:item i-environment tmp-counter)
;      set tmp-counter tmp-counter + 1
;    ]
  ]
  if input-environment = "Poor" [
    set i-environment array:from-list n-values rule-complexity [0]
    array:set i-environment 0 number-of-starting-products
  ]
  set o-environment array:from-list n-values rule-complexity [0]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to printout-knowledge
  print (word "Production rules at time: " ticks)
  let kstring ""
  let ruletype 0
  foreach sort firms [
    ask ? [
      set kstring (word "Firm " who ": ")
      foreach p-rules [
         set kstring (word kstring (item 0 ?) "->" (item 1 ?) " (" (item 2 ?) ") ")
      ]
    ]
    print kstring
  ]
  print ""
  
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Defining networks

to setup-links
  if interaction-topology = "Complete" [ setup-links-complete ]
  if interaction-topology = "4-Neighbour Grid" [ setup-links-4n-grid ]
  if interaction-topology = "8-Neighbour Grid" [ setup-links-8n-grid ]
  if interaction-topology = "Social Circles" [ setup-links-socialcircles ]
  if interaction-topology = "Random (Erdos-Renyi)" [ setup-links-erdos-renyi ]
  if interaction-topology = "Scale-free (Barabasi-Albert)" [ setup-links-barabasi-albert ]
  if rewire-chance > 0 [ rewire-links ]
  ask nlinks [
    set color grey
  ]
  
  set init-net-density 2 * count nlinks / ((count firms) * ((count firms) - 1))
  
end

to setup-links-complete
  reposition-firms-circle
  
  ask firms [
    create-nlinks-with other firms
  ]
end

to setup-links-socialcircles
  ask firms [
    setxy random-xcor random-ycor
  ]
  
  ask firms [
    create-nlinks-with other firms in-radius link-radius 
  ]
end

to setup-links-4n-grid
  reposition-firms-grid
  
  let numfirms (count firms)
  let numcols int sqrt numfirms
  if (numcols ^ 2) < numfirms [set numcols numcols + 1]
  let numrows int (numfirms / numcols)
  if (numcols * numrows) < numfirms [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
  
  ask firms [
    create-nlinks-with other firms in-radius (1.1 * (max (list xspace yspace)))
  ]
end

to setup-links-8n-grid
  reposition-firms-grid
  
  let numfirms (count firms)
  let numcols int sqrt numfirms
  if (numcols ^ 2) < numfirms [set numcols numcols + 1]
  let numrows int (numfirms / numcols)
  if (numcols * numrows) < numfirms [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
;  let xspace (max-pxcor / (numcols ))
;  let yspace (max-pycor / (numrows ))
  
  ask firms [
    create-nlinks-with other firms in-radius (1.1 * (sqrt ((xspace ^ 2) + (yspace ^ 2)))) 
  ]
end

to setup-links-erdos-renyi
  reposition-firms-circle

  let num-firms (count firms)
  let num-links int (0.5 + (link-chance * (num-firms * (num-firms - 1) / 2)))
  while [num-links > 0] [
    ask one-of firms [
      if (count my-nlinks) < (num-firms - 1) [
        ask one-of other firms [
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
  reposition-firms-circle

  let orderedlist sort firms
  let num-firms (count firms)
  let destinations array:from-list n-values num-firms [-1]
  let num-links 0

  set orderedlist but-first orderedlist
  let chosenfirm 0
  ask first orderedlist [ create-nlink-with firm chosenfirm ]
  array:set destinations num-links chosenfirm
  
  while [num-links < (num-firms - 2)] [
    set chosenfirm ((random (2 * (num-links + 1))) - num-links)
    if chosenfirm < 0 [
      set chosenfirm (array:item destinations (abs chosenfirm))
    ]
    set num-links num-links + 1
    set orderedlist but-first orderedlist
    ask first orderedlist [ create-nlink-with firm chosenfirm ]
    array:set destinations num-links chosenfirm
  ]
end

to rewire-links
  let num-firms-1 ((count firms) - 1)
  ask n-of (rewire-chance * (count nlinks)) nlinks [
    if ([count my-nlinks] of end1) < num-firms-1 [
      ask end1 [
;        create-nlink-with one-of other firms
        create-nlink-with one-of other firms with [not nlink-neighbor? myself]
      ]
      die
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Repositioning an already created network
to reposition-firms-rescaled
  let xborder (max-pxcor - min-pxcor ) / 12
  let yborder (max-pycor - min-pycor ) / 12
  let min-x min [xcor] of firms
  let max-x max [xcor] of firms
  let mult-x (max-pxcor - xborder - min-pxcor - xborder) / (max-x - min-x)
  let min-y min [ycor] of firms
  let max-y max [ycor] of firms
  let mult-y (max-pycor - yborder - min-pycor - yborder) / (max-y - min-y)
  ask firms [setxy (((xcor - min-x) * mult-x ) + min-pxcor + xborder) (((ycor - min-y) * mult-y) + min-pxcor + yborder )]
end

to reposition-firms-spring
  ;layout-spring turtle-set link-set spring-constant spring-length repulsion-constant 
  repeat 10 [layout-spring firms nlinks 0.2 (1.5 * max-pxcor / (sqrt count firms)) 1]
  
end

to reposition-firms-circle
  layout-circle (sort firms) (max-pxcor * 0.4)
  
end

to reposition-firms-grid
  let numfirms (count firms)
  let numcols int sqrt numfirms
  if (numcols ^ 2) < numfirms [set numcols numcols + 1]
  let numrows int (numfirms / numcols)
  if (numcols * numrows) < numfirms [set numrows numrows + 1]
  let xspace (max-pxcor / (numcols + 1))
  let yspace (max-pycor / (numrows + 1))
;  let xspace (max-pxcor / (numcols ))
;  let yspace (max-pycor / (numrows ))

  let orderedset sort firms
  let cur-item 0
  foreach orderedset [
    ask ? [
      set xcor (xspace * (1 + (cur-item mod numcols)))
      set ycor (yspace * (1 + int (cur-item / numcols)))
;      set xcor (xspace * (0.5 + (cur-item mod numcols)))
;      set ycor (yspace * (0.5 + int (cur-item / numcols)))
    ]
    set cur-item cur-item + 1
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if ticks = max-ticks [stop]
  
  if ticks mod output-every = 0 [
    set num-completed 0
    set num-rules-learned 0
    set recent-history []
  ]
  
  let rpath array:from-list n-values rule-complexity [0] ; Count of products processed. (Used for debugging)
  let rsteps 0
  let input-product 0
  let output-product 0
  let cur-ruletype 0
  let next-ruletype 0
  let alter nobody
  set fp-stack []
  
  
  set outchain [] ; Option for debugging: A record of the progress.
  
  ; Pick a starting firm with preference for number of rules.
  let ego sampled-rule-holder 
  ask ego [
    ; Select one of the firm's rules.
    set cur-ruletype sampled-ruletype
    ; Search for a product to use with that rule.
    if input-search = "Random Search" [set input-product random-input-product]
    if input-search = "Selective Search" [set input-product selective-input-product (item 0 cur-ruletype)]
    if 0 > input-product [stop] ; Negative product numbers used to signify Selective Search failed.
    
    ; Depletion of input-environment?
    if endogenous-environment [ ; only if endogenous
      array:set i-environment input-product (-1 + array:item i-environment input-product)
    ]    
    
    if input-product != (item 0 cur-ruletype) [stop] ; Did Random Search fail to find suitable input?
    
    ; Optional display of product moving from firm to firm.
    if show-products [ 
      ask product-turtle [
        set color array:item product-colours input-product
        setxy ([xcor] of ego) ([ycor] of ego)
        set hidden? false
      ]
    ]
    array:set rpath input-product (1 + array:item rpath input-product)
    
  ]
  
  ifelse input-product != (item 0 cur-ruletype) [
    if print-calculations [
      set outchain fput (list ego cur-ruletype input-product "Unsuitable input" ) outchain
    ]
    if 0 <= input-product [send-to-environment input-product]
    set input-product -1
  ]
  [
    ; While still have an input-product to process
    while [input-product >= 0] [
      set rsteps rsteps + 1
      set fp-stack fput (list ego input-product) fp-stack ; record steps taken.
      ask ego [
        array:set product-procd input-product (1 + array:item product-procd input-product) ; record that this firm has handled this product.
      ]
      
      ; Transform product
      set output-product (item 1 cur-ruletype)
      array:set rpath output-product (1 + array:item rpath output-product)
      if print-calculations [
        set outchain fput (list ego cur-ruletype ) outchain
      ]
      
      ; Colour firm that has just processed an input. (Might prefer to colour it by output-product?)
      ask ego [set color array:item product-colours input-product] ; Could save time by only doing this when show-products?
      
      if show-products [
        ask product-turtle [set color array:item product-colours output-product]
      ]
      
      ; Now try to pass on output
;      set alter [sampled-rule-holding-neighbour] of ego 
      set alter one-of [nlink-neighbors] of ego 
      
      ifelse (alter = nobody) [
        ; ego didn't have a neighbour
        send-to-environment output-product
        set input-product -1
        if print-calculations [
          set outchain fput ("No neighbour") outchain
        ]
      ]
      [ 
        ; an alter has been found
        if show-products [ 
          ask product-turtle [
            face alter
            fd (distance alter)
          ]
        ]
        set next-ruletype [suitable-ruletype output-product] of alter
        
        ifelse (next-ruletype = []) [
          ; alter didn't have a suitable rule
          send-to-environment output-product
          set input-product -1
          if print-calculations [
            set outchain fput (list alter "No rule") outchain
          ]
        ]
        [
          ; suitable rule found
          
          ;learning
          calc-learning ego alter cur-ruletype next-ruletype
          ; ego or alter might not have any rules now
          ifelse alter = nobody [
            send-to-environment output-product
            set input-product -1
            if print-calculations [
              set outchain fput (list alter "Died") outchain
            ]
          ]
          [
            if 0 != arule-adjustments [
              set next-ruletype (list (item 0 next-ruletype) (item 1 next-ruletype) ((item 2 next-ruletype) + arule-adjustments))
            ]
            ifelse 0 >= (item 2 next-ruletype) [
              ; alter lost its rule
              send-to-environment output-product
              set input-product -1
              if print-calculations [
                set outchain fput (list alter "Lost rule") outchain
              ]
            ]
            [
              ; To prevent endless loops
              ; Been there, done that...
              ifelse (max-visits <= [array:item product-procd output-product] of alter) [
                send-to-environment output-product
                set input-product -1
                set num-completed num-completed + 1
                if print-calculations [
                  set outchain fput (list alter output-product "Looped") outchain
                ]
              ]
              [
                ; Update for the next pass
                let grl-list (sublist next-ruletype 0 2)
                set cur-ruletype [first filter [grl-list = sublist ? 0 2] p-rules] of alter
                set ego alter
                set input-product output-product
              ]
            ]
          ]
        ]
      ]
    ]
    
  ]
  
  if print-calculations [
    print (word ticks ": " (reverse outchain) "; IE:" (array:to-list i-environment) "; OE:" (array:to-list o-environment) "; Visited:" rpath)
  ]
  
  ask product-turtle [set hidden? true]
  
  ; Clean up
  foreach fp-stack [
    set ego item 0 ?
    if ego != nobody [
      ask ego [
        array:set product-procd (item 1 ?) 0
      ]
    ]
  ]
  ;set fp-stack []
  
  set recent-history fput rsteps recent-history

  tick

  if ticks mod output-every = 0 [
    my-update-plots
  ]
    
end

to-report sampled-rule-holder
  ; Samples one firm, with preference for rules
  ;let wsum random (sum [p-rule-sum] of firms) ; Not needed at present - # rules constant
  let wsum random number-of-rules
  let selected-firm nobody
  ask firms [
    if selected-firm = nobody [
      set wsum wsum - p-rule-sum
      if wsum < 0 [set selected-firm self]
    ]
  ]
;  print selected-firm ; for debugging
  report selected-firm
end

to-report sampled-rule-holding-neighbour
  ; Samples one neighbor, with preference for rules
  if 0 = count nlink-neighbors [report nobody]
  let wsum random (sum [p-rule-sum] of nlink-neighbors)
  let selected-firm nobody
  ask nlink-neighbors [
    if selected-firm = nobody [
      set wsum wsum - p-rule-sum
      if wsum < 0 [set selected-firm self]
    ]
  ]
;  print selected-firm ; for debugging
  report selected-firm
end

to send-to-environment [output-product]
  ; Update environments
  array:set o-environment output-product (1 + array:item o-environment output-product)
  if Endogenous-environment [
    array:set i-environment output-product (1 + array:item i-environment output-product)
  ]
end

to-report random-input-product
  let wsum (sum (array:to-list i-environment))
  if wsum = 0 [report -1]
  set wsum random wsum
  let rindex -1
  while [wsum >= 0] [
    set rindex rindex + 1
    set wsum (wsum - (array:item i-environment rindex))
  ]
  report rindex
end

to-report selective-input-product [given-product]
  if (0 < array:item i-environment given-product) [report given-product]
  report -1
end

to-report suitable-ruletype [given-input]
  ; Returns a ruletype [input output count] which has the given input product and is held by current agent
  ; Returns [] if no rule held of compatible type.
;  show (word p-rule-sum ", " p-rules ", " given-input) ; for debugging
  let list-of-compatibles filter [given-input = item 0 ?] p-rules
  if 0 = length list-of-compatibles [report []]
  let wsum sum map [item 2 ?] list-of-compatibles
  let ruletype first list-of-compatibles
  set wsum (random wsum) - item 2 ruletype
  while [wsum >= 0] [
    set list-of-compatibles but-first list-of-compatibles
    set ruletype first list-of-compatibles
    set wsum wsum - item 2 ruletype
  ]
  report ruletype
  
;  ; This version may be faster: less use of memory, but more processing?
;  let wsum random sum map [ifelse-value (given-input = item 0 ?) [item 2 ?] [0]] p-rules
;  let selected-item []
;  foreach p-rules [
;    if selected-item = [] [
;      if (given-input = item 0 ?) [
;        set wsum wsum - item 2 ?
;        if wsum < 0 [set selected-item ?]
;      ]
;    ]
;  ]
;  report selected-item
end

to-report sampled-ruletype
  ; Returns a randomly chosen ruletype [input output count] .
  ; Returns [] if firm holds no rules.
  let wsum random p-rule-sum
  let selected-item []
  foreach p-rules [
;    print (list wsum ?)
    if selected-item = [] [
      set wsum wsum - item 2 ?
      if wsum < 0 [set selected-item ?]
    ]
  ]
;  print selected-item
  report selected-item
end

to calc-learning [ego alter e-ruletype a-ruletype]
  set arule-adjustments 0
  set num-rules-learned num-rules-learned + 1
  
  let losing-firm sampled-rule-holder
  let losing-ruletype [sampled-ruletype] of losing-firm
  
  if learning = "Source Reproduction" [
    firm-learns ego e-ruletype
  ]
  
  if learning = "Target Reproduction" [
    firm-learns alter a-ruletype
    set arule-adjustments arule-adjustments + 1
  ]  
  
  if learning = "Joint Reproduction" [ ; Haven't tested Joint Reproduction, so ignore.
    firm-learns ego e-ruletype
    set num-rules-learned num-rules-learned + 1
    firm-learns alter a-ruletype
    set arule-adjustments arule-adjustments + 1
  ]  
  
  ;print list losing-firm losing-ruletype
  if losing-firm = alter [
    if (sublist losing-ruletype 0 2 ) = (sublist a-ruletype 0 2 ) [
      set arule-adjustments arule-adjustments - 1
    ]
  ]
  firm-forgets losing-firm losing-ruletype
  
  if learning = "Joint Reproduction" [
    set losing-firm sampled-rule-holder
    set losing-ruletype [sampled-ruletype] of losing-firm
    ;print list losing-firm losing-ruletype
    if losing-firm = alter [
      if (sublist losing-ruletype 0 2 ) = (sublist a-ruletype 0 2 ) [
      set arule-adjustments arule-adjustments - 1
      ]
    ]
    firm-forgets losing-firm losing-ruletype
  ]
end

to firm-learns [given-firm given-ruletype]
  let grl-sublist (sublist given-ruletype 0 2)
  ask given-firm [
    if print-calculations [
      set outchain fput (list given-firm " learns " (filter [(sublist ? 0 2) = grl-sublist] p-rules)) outchain
    ]
    set p-rules map [ifelse-value ((sublist ? 0 2) = grl-sublist) [(list (item 0 ?) (item 1 ?) (1 + item 2 ?))] [?] ] p-rules
    set p-rule-sum p-rule-sum + 1
  ;  if not (member? (grl-sublist) map [sublist ? 0 2] p-rules) [fput given-ruletype p-rules]
  ]
end  

to firm-forgets [given-firm given-ruletype]
  ; Removes a rule of given type.
  let grl-sublist (sublist given-ruletype 0 2)
  ask given-firm [
    if print-calculations [
      set outchain fput (list (word given-firm) " forgets " (filter [(sublist ? 0 2) = grl-sublist] p-rules)) outchain
    ]
    set p-rules map [ifelse-value ((sublist ? 0 2) = grl-sublist) [(list (item 0 ?) (item 1 ?) (-1 + item 2 ?))] [?] ] p-rules
    set num-distinct-rules num-distinct-rules - length p-rules
    set p-rules filter [0 < item 2 ?] p-rules
    set num-distinct-rules num-distinct-rules + length p-rules
    set p-rule-sum p-rule-sum - 1
;    print (list ticks given-firm p-rule-sum (sum map [item 2 ?] p-rules))
    ; Kill off firm and its network links if it has no production rules left.
    if p-rule-sum = 0 [
      ask my-nlinks [die]
      die
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to my-setup-plots
  set-current-plot "Links per node"
  set-plot-x-range 0 (1 + max [count my-nlinks] of firms)
  histogram [count my-nlinks] of firms

  set-current-plot "Completion Rate"
  set-plot-pen-interval output-every 
  set-current-plot "Firms"
  set-plot-pen-interval output-every 
  plot (count firms)
  set-current-plot "Learning Rate"
  set-plot-pen-interval output-every 
  set-current-plot "# Cycles"
  set-plot-pen-interval output-every 
  
  set-current-plot "Environment Evolution"
  setup-all-my-plot-pens
  set-current-plot "Rule Type Evolution"
  setup-all-my-plot-pens
  
  plot-environment
  plot-p-rule-freqs
end

to setup-all-my-plot-pens
  let cur-pen 0
  set-plot-pen-color (array:item product-colours cur-pen)
  repeat (plot-rule-complexity - 1) [
    set cur-pen cur-pen + 1
    set-current-plot-pen (word cur-pen)
;    create-temporary-plot-pen (word cur-pen)
    set-plot-pen-color (array:item product-colours cur-pen)
  ]
end

to my-update-plots
  set-current-plot "Links per node"
  clear-plot
  set-plot-x-range 0 (1 + max [count my-nlinks] of firms)
  histogram [count my-nlinks] of firms

  set-current-plot "Completion Rate"
  plot 100 * num-completed / output-every
  
  set-current-plot "Firms"
  plot (count firms)
  
  set-current-plot "Learning Rate"
  plot num-rules-learned / output-every

  set-current-plot "History Histogram"
  set-plot-x-range 0 (1 + max recent-history)
  histogram recent-history
  
  plot-environment
  plot-p-rule-freqs
  
  calc-hypercycles false
  if num-cycles < HCs-limit [ ; Don't draw this until it's accurate.
    set-current-plot "# Cycles"
    plotxy ticks (num-cycles)
  ]
  set-current-plot "Cycle Lengths"
  ifelse 0 < length cycle-lengths [
    set-plot-x-range 0 (1 + max cycle-lengths)
    histogram cycle-lengths
  ]
  [ clear-plot]
  
end

to plot-p-rule-freqs
  let cur-type 0
  set p-rule-freqs array:from-list (map [0] (array:to-list p-rule-freqs))
  ask firms [
    foreach p-rules [
      set cur-type item 1 ?
      ; Based upon output product only. Doesn't matter for Solo chemistry. Does matter for All.
      array:set p-rule-freqs cur-type ((array:item p-rule-freqs cur-type) + (item 2 ?))
    ]
  ]
  set num-output-product-types sum (map [ifelse-value (? > 0) [1] [0]] (array:to-list p-rule-freqs))
  
  set cur-type 0
  set p-rule-freqs array:from-list (map [0] (array:to-list p-rule-freqs))
  ask firms [
    foreach p-rules [
      set cur-type item 0 ?
      ; Based upon input product only. Doesn't matter for Solo chemistry. Does matter for All.
      array:set p-rule-freqs cur-type ((array:item p-rule-freqs cur-type) + (item 2 ?))
    ]
  ]
  set num-input-product-types sum (map [ifelse-value (? > 0) [1] [0]] (array:to-list p-rule-freqs))
  
  set-current-plot "Evolution in # Product Types"
  set-current-plot-pen "Rule Inputs"
  plotxy ticks num-input-product-types
  set-current-plot-pen "Rule Outputs"
  plotxy ticks num-output-product-types
  
  set-current-plot "Rule Type Evolution"
  set cur-type 0
  repeat plot-rule-complexity [
    set-current-plot-pen (word cur-type)
    plotxy ticks (array:item p-rule-freqs cur-type)
    set cur-type cur-type + 1
  ]
end

to plot-environment
  set-current-plot "Input Environment"
  clear-plot
  foreach array:to-list i-environment [plot ?]

  set-current-plot "Output Environment"
  clear-plot
  foreach array:to-list o-environment [plot ?]
  
  set num-env-product-types sum (map [ifelse-value (? > 0) [1] [0]] (array:to-list i-environment))
  set-current-plot "Evolution in # Product Types"
  set-current-plot-pen "Input Environment"
  plotxy ticks num-env-product-types
  
  set-current-plot "Environment Evolution"
  let cur-prod 0
  repeat plot-rule-complexity [
    set-current-plot-pen (word cur-prod)
    plotxy ticks (array:item i-environment cur-prod)
    set cur-prod cur-prod + 1
  ]
end  

to label-rules
  ask firms [
    set label p-rules
  ]
end

to label-who
  ask firms [set label who]
end

to label-off
  ask firms [set label ""]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calc-hypercycles [verbose]
  let search-result 0
  let cur-firm nobody
  let start-firm nobody
  let start-product 0
  let input-product 0
  let next-firm nobody
  let output-product 0
  let valid-outputs []
;  let compat-rules []
  let valid-destinations []
  let cur-cycle []
  let hc-min 0
  let hc-min-pos 0
  set num-cycles 0
  set cycle-lengths []
  set cycles-found []
  if print-hypercycles [print (word "Checking for hypercycles at time " ticks)]
  set fp-stack []
  ask firms [
;    set product-procd array:from-list n-values rule-complexity [0]
;    set product-procd array:from-list map [0] array:to-list product-procd
    set p-rule-tbp []
    set neigh-tbp []
    set p-rule-in-hc []
  ]
  ask nlinks [
    set hl-products []
    set lh-products []
    set color grey
  ]
;  foreach sort firms [
;    if num-cycles < hcs-limit [
;      ask ? [
  ask firms [
        set start-firm self
        set start-product 0
        repeat rule-complexity [
;        repeat ifelse-value (Input-Environment = "Poor") [1] [rule-complexity] [
          if num-cycles < hcs-limit [
            if 0 < array:item i-environment start-product [ ; Means HCs can reappear if a product reappears in i-environment!
              ; Still some available in environment
              set fp-stack fput (list self start-product) fp-stack ; push starting point
              if verbose [print (list "Start: " start-product self )]
              while [0 < length fp-stack] [
                
                set cur-firm item 0 first fp-stack
                set input-product item 1 first fp-stack
                if verbose [print (list "Processing " cur-firm input-product)]
                ifelse 0 = [array:item product-procd input-product] of cur-firm [
                  ; Not been here before
                  ask cur-firm [
                    array:set product-procd input-product 1
                    set valid-outputs map [item 1 ?] (filter [input-product = item 0 ?] p-rules)
                    ifelse 0 = length valid-outputs [
                      ; Input product no good
                      if verbose [print (word self " has no rules for " input-product)]
                      set fp-stack but-first fp-stack
                      array:set product-procd input-product 0
                    ]
                    [
                      ; Compatible rules generated for input product
                      foreach valid-outputs [
                        set output-product ?
                        set valid-destinations []
                        ask nlink-neighbors [
                          if 0 < length filter [output-product = item 0 ?] p-rules [
                            set valid-destinations fput self valid-destinations
                          ]
                        ]
                        ifelse 0 = length valid-destinations [
                          ; Rule no good.
                          if verbose [print (word self " has no destinations for " output-product)]
                        ]
                        [
                          ; Try Output-product with these neighbours
                          if verbose [print (word self " has destinations for " output-product)]
                          set p-rule-tbp fput (list input-product output-product) p-rule-tbp
                          foreach valid-destinations [
                            set neigh-tbp fput (list output-product ?) neigh-tbp
                          ]
                        ]
                      ]
                    ]
                  ]
                ]
                [
                  ; Have visited firm already during this chain.
                  ask cur-firm [
                    set valid-outputs map [item 1 ?] (filter [input-product = item 0 ?] p-rule-tbp) 
                    ifelse 0 = length valid-outputs [
                      ; Can't use this input-product. Back track.
                      if verbose [print (word self " can't use " input-product)]
                      set fp-stack but-first fp-stack
                      array:set product-procd input-product 0
                    ]
                    [
                      ; Can transform input-product into at least something.
                      set output-product first valid-outputs
                      set valid-destinations map [item 1 ?] (filter [output-product = item 0 ?] neigh-tbp)
                      ifelse 0 = length valid-destinations [
                        ; Can't send this output product to anyone. Forget the rule.
                        if verbose [print (word self " learns nobody wants " output-product)]
                        set p-rule-tbp remove (list input-product output-product) p-rule-tbp
                      ]
                      [
                        set next-firm first valid-destinations
                        ifelse [0 = array:item product-procd output-product] of next-firm [
                          ; Push (destination, output-product) to stack.
                          if verbose [print (word self " passes " output-product " to " next-firm)]
                          set fp-stack fput (list next-firm output-product) fp-stack
                        ]
                        [
                          ; Been here before. Is it a cycle?
                          set search-result position (list next-firm output-product) fp-stack
                          ;                      ifelse search-result = ((length fp-stack) - 1) [
                          ifelse search-result != false [
                            ;                      ifelse (next-firm = start-firm) and (output-product = start-product) [
                            ;print (word search-result " " (length fp-stack))
                            ;                        set search-result ((length fp-stack) - 1)
                            ; Cycle found. Output it.
                            set fp-stack fput (list next-firm output-product) fp-stack
                            ifelse original-cycles-only [
                              ; Record current cycle, starting from lowest who-product combination
                              set cur-cycle (map [([who * 100] of item 0 ?) + (item 1 ?)] (reverse (sublist fp-stack 0 (search-result + 2))))
                              set hc-min min cur-cycle
                              set hc-min-pos position hc-min cur-cycle
                              set cur-cycle (sentence (sublist cur-cycle hc-min-pos ((length cur-cycle) - 1)) (sublist cur-cycle 0 hc-min-pos))
                              if not member? cur-cycle cycles-found [
                                set cycles-found fput cur-cycle cycles-found
                                if verbose [print "New cycle found!"]
                                if print-hypercycles [print-cycle search-result + 1]
                                remember-cycle-rules (search-result + 1)
                                set num-cycles num-cycles + 1
                                set cycle-lengths fput (search-result + 1) cycle-lengths
                              ]
                            ]
                            [
                              if verbose [print "Cycle found!"]
                              if print-hypercycles [print-cycle search-result + 1]
                              remember-cycle-rules (search-result + 1)
                              set num-cycles num-cycles + 1
                              set cycle-lengths fput (search-result + 1) cycle-lengths
                            ]
                            set fp-stack but-first fp-stack
                            if num-cycles >= hcs-limit [
                              if verbose [print "# Hypercycles is too large. Quitting search early."]
                              set fp-stack []
                            ]
                          ]
                          [
                            ; No cycle, but it's been processed already, so backtrack.
                            if verbose [print "Been here already, but it's not a cycle. Forget that destination."]
                          ]
                        ]
                        ; Now don't offer output-product to that destination again.
                        set neigh-tbp remove (list output-product next-firm) neigh-tbp
                      ]
                    ]
                  ]
                ]
              ]
            ] ; i-environment?
            set start-product start-product + 1
          ]
        ]
        if num-cycles >= hcs-limit [stop]
;      ]
;    ]
  ]
  set num-parasite-rules sum [(length p-rules) - (length p-rule-in-hc)] of firms
  set num-parasite-firms count firms with [0 = (length p-rule-in-hc)]
  set num-parasite-links count nlinks with [color = grey]
  set perc-parasite-rules 100 * num-parasite-rules / num-distinct-rules
  set perc-parasite-firms 100 * num-parasite-firms / (count firms)
  set perc-parasite-links ifelse-value (0 < (count nlinks)) [100 * num-parasite-links / (count nlinks)] [0]
  if print-hypercycles [
    print (word "Cycles found of lengths: " cycle-lengths)
    print (word "# Cycles = " num-cycles)
  ]
  ; Clean up
  ask firms [
    set product-procd array:from-list n-values rule-complexity [0]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to print-fp-stack
  foreach fp-stack [
    print ?
  ]
end

to print-cycle [given-start]
  print reverse (sublist fp-stack 0 (given-start + 1))
end

to remember-cycle-rules [given-start]
  let ego nobody
  let alter nobody
  let a-product 0
  let e-product 0
  let cur-item 0
  let cur-rule []
  foreach reverse (sublist fp-stack 0 (given-start + 1)) [
    ifelse cur-item = 0 [
      set alter item 0 ?
      set a-product item 1 ?
    ]
    [
      set ego alter
      set e-product a-product
      set alter item 0 ?
      set a-product item 1 ?
      set cur-rule list e-product a-product
      ask ego [
        if not member? cur-rule p-rule-in-hc [
          set p-rule-in-hc fput cur-rule p-rule-in-hc
        ]
      ]
      ask [nlink-with alter] of ego [
        ifelse ([who] of ego) <= ([who] of alter) [
          if not member? a-product lh-products [
            set lh-products fput a-product lh-products
          ]
        ]
        [
          if not member? a-product hl-products [
            set hl-products fput a-product hl-products
          ]
        ]
        set color red
      ]
    ]
    set cur-item cur-item + 1
  ]
end

to setup-example1
  ; From Padgett's lecture slides
  ; Remember: my product ID numbers are 1 less than his.
  ; Target; Rich; Random RuleC = 5
  ; Should give 39 hypercycles 
  ask firms with [not member? who (list 3 10 11 12 13 14 21 22 23 24 31 33)] [
    die
  ]
  ask firm 3 [set p-rules (list (list 1 2 6))]

  ask firm 10 [set p-rules (list (list 4 0 7))]
  ask firm 11 [set p-rules (list (list 0 1 13) (list 3 4 13))]
  ask firm 12 [set p-rules (list (list 0 1 12) (list 2 3 13) (list 4 0 13))]
  ask firm 13 [set p-rules (list (list 0 1 14))]
  ask firm 14 [set p-rules (list (list 1 2 6))]

  ask firm 21 [set p-rules (list (list 0 1 10) (list 1 2 10))]
  ask firm 22 [set p-rules (list (list 4 0 21) (list 1 2 21))]
  ask firm 23 [set p-rules (list (list 3 4 11) (list 1 2 12))]
  ask firm 24 [set p-rules (list (list 1 2 7))]

  ask firm 31 [set p-rules (list (list 0 1 7))]
  ask firm 33 [set p-rules (list (list 4 0 4))]

  ask firms [set p-rule-sum sum map [item 2 ?] p-rules]
  ;print sum [p-rule-sum] of firms ; check sum
  
end

to setup-example2
  ; From Padgett's lecture slides
  ; Target; Endog (Poor); Random; RuleC = 5
  ; Should give 14 hypercycles 
  ask firms with [not member? who (list 3 14 15 22 23 24 30 31 32 33 34 35 42 45)] [
    die
  ]
  ask firm 3 [set p-rules (list (list 1 2 5))]

  ask firm 14 [set p-rules (list (list 0 1 11))]
  ask firm 15 [set p-rules (list (list 0 1 6))]

  ask firm 22 [set p-rules (list (list 2 3 14))]
  ask firm 23 [set p-rules (list (list 1 2 12))]
  ask firm 24 [set p-rules (list (list 2 3 17) (list 4 0 17))]

  ask firm 30 [set p-rules (list (list 4 0 3))]
  ask firm 31 [set p-rules (list (list 3 4 7))]
  ask firm 32 [set p-rules (list (list 2 3 14))]
  ask firm 33 [set p-rules (list (list 2 3 16) (list 3 4 16))]
  ask firm 34 [set p-rules (list (list 2 3 14) (list 0 1 15))]
  ask firm 35 [set p-rules (list (list 3 4 10))]

  ask firm 42 [set p-rules (list (list 4 0 14))]
  ask firm 45 [set p-rules (list (list 1 2 9))]
  
  ask firms [set p-rule-sum sum map [item 2 ?] p-rules]
  ;print sum [p-rule-sum] of firms ; check sum
  
end
  
to setup-example3
  ; From Padgett's chapter in Padgett & Powell (forthcoming)
  ; Target; Fixed-Rich; Selective; RuleC = 5
  ; Should give 7 hypercycles
  ask firms with [not member? who (list 2 10 11 12 13 14 20 21 22 23 24 32 35)] [
    die
  ]
  ask firm 2 [set p-rules (list (list 0 1 6))]

  ask firm 10 [set p-rules (list (list 3 4 18))]
  ask firm 11 [set p-rules (list (list 4 0 13))]
  ask firm 12 [set p-rules (list (list 2 3 13) (list 1 2 14))]
  ask firm 13 [set p-rules (list (list 0 1 3))]
  ask firm 14 [set p-rules (list (list 3 4 10) (list 1 2 10))]

  ask firm 20 [set p-rules (list (list 4 0 11))]
  ask firm 21 [set p-rules (list (list 2 3 23))]
  ask firm 22 [set p-rules (list (list 1 2 13))]
  ask firm 23 [set p-rules (list (list 0 1 6) (list 1 2 6))]
  ask firm 24 [set p-rules (list (list 4 0 12) (list 2 3 13))]

  ask firm 32 [set p-rules (list (list 3 4 13))]
  ask firm 35 [set p-rules (list (list 0 1 8) (list 3 4 8))]
  
  ask firms [set p-rule-sum sum map [item 2 ?] p-rules]
  ;print sum [p-rule-sum] of firms ; check sum
  
end

to setup-example4
  ; From Padgett's chapter in Padgett & Powell (forthcoming)
  ; Target; Endog; Selective; RuleC = 5
  ; Should give 19 hypercycles (Padgett says 17!)
  ask firms with [not member? who (list 2 11 12 13 20 22 23 31 32 33 40 41 42 52)] [
    die
  ]
  ask firm 2 [set p-rules (list (list 3 4 7))]

  ask firm 11 [set p-rules (list (list 2 3 6))]
  ask firm 12 [set p-rules (list (list 1 2 9))]
  ask firm 13 [set p-rules (list (list 0 1 4))]

  ask firm 20 [set p-rules (list (list 3 4 7) (list 1 2 7))]
  ask firm 22 [set p-rules (list (list 4 0 5) (list 0 1 6))]
  ask firm 23 [set p-rules (list (list 4 0 7))]

  ask firm 31 [set p-rules (list (list 0 1 13))]
  ask firm 32 [set p-rules (list (list 2 3 12) (list 3 4 12) (list 1 2 12))]
  ask firm 33 [set p-rules (list (list 4 0 12))]
  
  ask firm 40 [set p-rules (list (list 1 2 10))]
  ask firm 41 [set p-rules (list (list 2 3 14) (list 4 0 15))]
  ask firm 42 [set p-rules (list (list 1 2 13) (list 3 4 14))]

  ask firm 52 [set p-rules (list (list 3 4 7) (list 4 0 8))]

  ask firms [set p-rule-sum sum map [item 2 ?] p-rules]
  ;print sum [p-rule-sum] of firms ; check sum
  
end
@#$#@#$#@
GRAPHICS-WINDOW
211
10
621
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
3
95
96
155
Number-of-Firms
100
1
0
Number

INPUTBOX
100
95
193
155
Number-of-Rules
200
1
0
Number

SLIDER
4
159
176
192
Rule-Complexity
Rule-Complexity
2
10
5
1
1
NIL
HORIZONTAL

CHOOSER
4
243
207
288
Interaction-Topology
Interaction-Topology
"8-Neighbour Grid" "4-Neighbour Grid" "Social Circles" "Random (Erdos-Renyi)" "Scale-free (Barabasi-Albert)" "Complete"
0

CHOOSER
4
291
176
336
Learning
Learning
"Source Reproduction" "Target Reproduction"
1

CHOOSER
4
339
176
384
Input-Environment
Input-Environment
"Rich" "Poor"
0

CHOOSER
4
423
176
468
Input-Search
Input-Search
"Random Search" "Selective Search"
1

TEXTBOX
6
10
209
50
CW's Hypercycles Model
18
0.0
1

INPUTBOX
2
777
157
837
Rewire-Chance
0
1
0
Number

INPUTBOX
2
840
157
900
Link-Radius
20
1
0
Number

INPUTBOX
2
902
157
962
Link-Chance
0.1
1
0
Number

TEXTBOX
5
743
182
775
Interaction Network Parameters:
13
0.0
1

BUTTON
4
471
68
504
Setup
setup true
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
179
766
297
819
# Interaction Links
count nlinks
17
1
13

MONITOR
300
766
360
819
Density
2 * count nlinks / ((count firms) * ((count firms) - 1))
3
1
13

BUTTON
211
460
288
493
2-D Grid
reposition-firms-grid
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
291
460
354
493
Circle
reposition-firms-circle
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
460
423
493
Spring
reposition-firms-spring
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
440
987
560
1020
Print Knowledge
printout-knowledge
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
1464
188
1664
354
Completion Rate
Time (ticks)
% completing
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

BUTTON
70
471
133
504
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
98
607
187
667
Output-Every
1000
1
0
Number

PLOT
1260
188
1460
355
History Histogram
Path Length
Frequency
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

TEXTBOX
211
443
361
461
Reposition nodes:
13
0.0
1

SWITCH
564
987
729
1020
Print-Calculations
Print-Calculations
1
1
-1000

PLOT
632
319
832
469
Firms
Time (ticks)
Count
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

INPUTBOX
4
544
159
604
Number-Of-Starting-Products
200
1
0
Number

TEXTBOX
6
523
182
541
Additional Model Parameters:
13
0.0
1

CHOOSER
4
195
142
240
Chemistry
Chemistry
"Solo Hypercycle" "All"
0

TEXTBOX
436
443
586
461
Firm Labels:
13
0.0
1

BUTTON
434
460
489
493
P-Rules
label-rules
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
551
460
606
493
Off
label-off
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
460
547
493
Who
label-who
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
1464
10
1664
186
Learning Rate
Time (ticks)
# Rules per tick
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

BUTTON
136
471
196
504
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

INPUTBOX
10
1106
165
1166
RNG-Seed
0
1
0
Number

BUTTON
167
1106
255
1139
Print Seed
print-last-seed
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
4
607
94
667
Max-ticks
100000
1
0
Number

TEXTBOX
441
967
591
985
Useful debugging aids:
13
0.0
1

TEXTBOX
11
1088
161
1106
Random Number Seed:
13
0.0
1

SWITCH
293
501
431
534
Show-Products
Show-Products
1
1
-1000

PLOT
632
11
832
161
Input Environment
Product
Count
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
632
165
832
315
Output Environment
Product
Count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

SWITCH
4
387
209
420
Endogenous-Environment
Endogenous-Environment
0
1
-1000

PLOT
632
474
832
624
# Cycles
Time (ticks)
Count
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
1260
11
1460
186
Cycle Lengths
Length
Count
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
461
639
566
692
# Hypercycles
num-cycles
1
1
13

SWITCH
440
1025
592
1058
Print-Hypercycles
Print-Hypercycles
1
1
-1000

BUTTON
439
1062
592
1095
Calculate Hypercycles
calc-hypercycles false
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
461
526
526
579
# Firms
count firms
1
1
13

BUTTON
439
1099
587
1132
Calculate HCs Verbose
calc-hypercycles true
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
733
987
813
1020
Print # rules
print (word \"# distinct rule-firm combinations in population: \" (sum [length p-rules] of firms))
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
9
1035
97
1068
Example 1
set Interaction-Topology \"8-Neighbour Grid\"\nset learning \"Target Reproduction\"\nset endogenous-environment false\nset input-environment \"Rich\"\nset input-search \"Random Search\"\nset rule-complexity 5\nsetup false\nsetup-example1\ncalc-hypercycles false
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
1035
188
1068
Example 2
set Interaction-Topology \"8-Neighbour Grid\"\nset learning \"Target Reproduction\"\nset endogenous-environment true\nset input-environment \"Rich\"\nset input-search \"Random Search\"\nset rule-complexity 5\nsetup false\nsetup-example2\ncalc-hypercycles false\n
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
13
1014
199
1032
Setup Padgett's examples:
13
0.0
1

BUTTON
211
501
288
534
Rescaled
reposition-firms-rescaled
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
212
565
375
598
Original-Cycles-Only
Original-Cycles-Only
0
1
-1000

INPUTBOX
211
603
271
663
HCs-Limit
200
1
0
Number

TEXTBOX
213
546
363
564
Hypercycles Calculation:
13
0.0
1

TEXTBOX
7
71
157
89
Main parameters:
13
0.0
1

TEXTBOX
5
35
211
78
After Padgett et al. (2003).\nThis version (C) Christopher Watts, 2014.
11
0.0
1

TEXTBOX
179
744
354
762
Interaction Network Metrics:
13
0.0
1

MONITOR
461
582
608
635
# distinct rules per firm
num-distinct-rules / (count firms)
2
1
13

MONITOR
568
806
677
859
% Parasite rules
perc-parasite-rules
1
1
13

MONITOR
569
694
677
747
% Parasite firms
perc-parasite-firms
1
1
13

MONITOR
569
750
677
803
% Parasite links
perc-parasite-links
1
1
13

INPUTBOX
4
671
65
731
Max-Visits
1
1
0
Number

TEXTBOX
288
636
463
684
HCs Check: Hypercycle statistics are only valid if \n# Hypercycles < HCs-Limit
13
0.0
1

PLOT
179
824
393
1012
Links per node
Degree (# links)
Count (# nodes)
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

TEXTBOX
462
507
612
525
Key metrics:
13
0.0
1

BUTTON
191
1035
279
1068
Example 3
set Interaction-Topology \"8-Neighbour Grid\"\nset learning \"Target Reproduction\"\nset endogenous-environment false\nset input-environment \"Rich\"\nset input-search \"Selective Search\"\nset rule-complexity 5\nsetup false\nsetup-example3\ncalc-hypercycles false\n
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
530
526
594
579
# Rules
sum [p-rule-sum] of firms
17
1
13

BUTTON
281
1035
369
1068
Example 4
set Interaction-Topology \"8-Neighbour Grid\"\nset learning \"Target Reproduction\"\nset endogenous-environment true\nset input-environment \"Rich\"\nset input-search \"Selective Search\"\nset rule-complexity 5\nsetup false\nsetup-example4\ncalc-hypercycles false\n
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
461
694
566
747
# Parasite firms
num-parasite-firms
17
1
13

MONITOR
461
750
566
803
# Parasite rules
num-parasite-rules
17
1
13

MONITOR
461
806
566
859
# Parasite links
num-parasite-links
17
1
13

PLOT
844
10
1252
232
Environment Evolution
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
"0" 1.0 0 -2674135 true "" ""
"1" 1.0 0 -1184463 true "" ""
"2" 1.0 0 -10899396 true "" ""
"3" 1.0 0 -11221820 true "" ""
"4" 1.0 0 -13791810 true "" ""
"5" 1.0 0 -13345367 true "" ""
"6" 1.0 0 -8630108 true "" ""
"7" 1.0 0 -5825686 true "" ""
"8" 1.0 0 -2064490 true "" ""
"9" 1.0 0 -6459832 true "" ""

MONITOR
568
638
656
691
HCs Check:
ifelse-value (num-cycles < hcs-limit) [\"Ok\"] [\"> Limit\"]
17
1
13

PLOT
844
236
1252
456
Rule Type Evolution
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
"0" 1.0 0 -2674135 true "" ""
"1" 1.0 0 -1184463 true "" ""
"2" 1.0 0 -10899396 true "" ""
"3" 1.0 0 -11221820 true "" ""
"4" 1.0 0 -13791810 true "" ""
"5" 1.0 0 -13345367 true "" ""
"6" 1.0 0 -8630108 true "" ""
"7" 1.0 0 -5825686 true "" ""
"8" 1.0 0 -2064490 true "" ""
"9" 1.0 0 -6459832 true "" ""

MONITOR
1255
459
1414
512
# Input Product Types
num-input-product-types
1
1
13

MONITOR
1255
515
1425
568
# Output Product Types
num-output-product-types
1
1
13

MONITOR
1255
570
1521
623
# Product Types  in Input Environment
num-env-product-types
1
1
13

PLOT
844
459
1252
621
Evolution in # Product Types
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
"Input Environment" 1.0 0 -13345367 true "" ""
"Rule Inputs" 1.0 0 -2674135 true "" ""
"Rule Outputs" 1.0 0 -10899396 true "" ""

MONITOR
363
766
454
819
Initial Density
init-net-density
3
1
13

TEXTBOX
13
1172
273
1264
If seed set to 0, simulation will generate random numbers from a new seed.\nTo repeat most recent simulation run, click \"Print Seed\", then copy-paste the number into RNG-Seed.
13
0.0
1

@#$#@#$#@
# CW'S HYPERCYCLES MODEL

## WHAT IS IT?

A reproduction in NetLogo of Padgett's Hypercycles Model of Economic Production as Chemistry (Padgett 1997; Padgett et al. 2003).

Conditions are explored for the spontaneous emergence of hypercycles or auto-catalytic (self-reproductive) sets of skills among firms.

This NetLogo program (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Chapter 7 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.


## HOW IT WORKS

### At the start:  

There are a given number of firms, arranged in a network of interaction possibilities, representing geographical, social or previous economic relations.

Distributed among the firms there are a given number of production rules, or skills. Production rules are such that the firm possessing a copy of one knows how to transform an input product into an output product, according to that rule.

### Chemistry

There is a fixed number of possible types of product, labelled here: "0", "1", ... This number is named the __"Rule-complexity"__. 

The initial rules are sampled from a chemistry of valid rule types. If x is a product type, __"Solo"__ chemistry permits only rules of the type "x -> x+1", and "x -> 0" only if x+1 is the number of product types. "All" chemistry permits any rule transforming a product of one type into a product of another type. In "Solo" chemistry, "rule-complexity" controls the length of cycles. So if there are n+1 types of product, a valid production cycle is: 0 -> 1 -> 2 -> ... -> n -> 0. This is, in fact, the only valid type of cycle when using "Solo" chemistry. __"All"__ chemistry permits far more types of cycle.

Firms exist in some environment containing products which may become inputs to the use of production rules. Output products may also be deposited in the same environment.

Each time tick, a production process, or chain of product transformations, is simulated. Over time, firms learn to favour some rules over others for use in transforming products.

### Firm selection:  

Production rules, or skills, are randomly distributed at the start among firms. Each time step, a copy of a rule is chosen at random from those held by all the firms. A product is then sought from the environment to be the input to the chosen rule. A firm's chance of being the start of a production chain then depends in part on how many instances of rules it has, and on what input products can be obtained from the environment. 

### Input Search:

There are two methods for seeking products from the environment. __"Selective"__ search means that only an input product compatible with the chosen rule can be sampled. If no copy of such a product exists in the environment, then the production process ends. __"Random"__ search means that a product is sampled from the input environment: if it is not compatible with the selected rule, then it is passed to the output environment. The chances of a particular product type being sampled can vary in endogenous environments (see below). Both methods of input search assume very little intelligence on the part of firms.

### Product transformation:

Input products compatible with a chosen rule are converted by that rule into an output product. This is then passed to one of the firm's neighbouring firms. If the firm receiving an input product does not have a suitable rule, the unprocessed input product passes to the output environment. If the firm does have rules suitable for processing this input, then a randomly chosen copy of one of the compatible rules is chosen, and the corresponding output product generated and passed to a neighbour.

A chain builds up of firms receiving input products, processing them with a suitable rule and then passing the output product onto a neighbour. This chain halts when either (1) a firm lacks a neighbour to pass the product onto, or (2) a firm lacks a suitable rule and must discard the input product into the output environment, or (3) a cycle is detected, i.e. a firm receives an input product it has processed a given number of times ("Max-Visits") already during this chain.

### Learning and forgetting:  

Firms learn by doing. Each time two rules in succession are followed correctly, a copy is made of one of the two rules by the firm who activated it. Which firm reproduces its rule depends on the type of learning: __"source"__ (the first firm reproduces) or __"target"__ (the second firm reproduces).

To keep the total number of rules fixed, each time a rule is reproduced, a copy of a randomly chosen rule must be deleted. This places selection pressure on rules.  
A firm with no rules left dies. To avoid death, therefore, a firm needs to have its rules reproduced by learning, and that means the firm needs to be given the opportunity to use the rules. Firms that are part of a complete hypercycle will tend to use their rules more often than those that are not. Firms whose rules form part of multiple hypercycles should be the safest of all.

However, it may be possible to survive as a "parasite". With target reproduction, a firm can receive input products from those in a hypercycle. With source reproduction, a firm can receive input products from the environment and benefit from being able to pass the products on.

### The environment:  

There are two types of initial input environment: "Poor" and "Rich". Environments can also be "Endogenous".

__"Poor"__ environments initially contain only copies of the base product (here: "0"; in Padgett's versions of the model the base product is labelled "1".)

__"Rich"__ environments initially contain copies of every product.

Histograms are plotted for the counts of products in both the input and output environments, so use these to check what is happening.

If the environment is set to be __"endogenous"__, then products passed to the output environment are also added to the input environment. Whenever a copy of a product is sampled from the input environment to be input to a production chain, the simulation reduces the number of copies in the endogenous input environment. With a __"fixed"__ or non-endogenous input environment, we assume there is a never-ending supply of all products initially present - i.e. the simulation cannot reduce a stock to zero. 

Both learning and environmental endogeneity allow stigmergy. That is, past production chains alter the chances of future production chains. (Such algorithmic processes have been identified in the behaviour of social insects, especially ants.) Stochastically stable paths of firms and their rules may emerge, while others disappear. Likewise, products may be reduced to a minimum in the input environment, while others come to dominate.


## HOW TO USE IT

Choose input parameters on the left-hand side. Click "Setup". Then click "Go". Note what happens to the firms in the World display, and also note the charts, hypercycles (HC) count, and other metrics.

Switch on "Show-Products" to create a turtle that represents the current product, changing color as the product is transformed, and moving between firms. To view the turtle it will probably be necessary to slow NetLogo down, using the speed slider.

There are buttons for giving firms labels, showing the "who" numbers of the firms, or their sets of production rules. Each production rule is listed as a triple: [input-product output-product number-of-occurences].

There are buttons for relocating the firms on the screen.

There are buttons for setting the simulation up with examples used in Padgett's lectures and writings. Compare the hypercycles count with those made by Padgett which should match (and nearly all do!)

There are buttons for various useful debugging aids, especially when searching for hypercycles.


## EXTRA PARAMETERS

__Number-of-Starting-Products__ : Number of instances of a product in input-environment.

__Max-ticks__ : If > 0, simulation will halt when ticks reaches this value. If < 0, simulation will continue until either the "Go" button is pressed again, or the simulation is halted from the menu.

__Output-Every__ : Number of ticks between updates of charts and hypercycle calculations. If set to 1, calculations will be made every time tick. Higher values save computing time and may improve the readability of charts. If only interested in final values of metrics, then set this to Max-ticks. Determines the base number of ticks for estimates of "Learning-Rate" (# times a rule is learned or reproduced) and "Completion Rate" (# times a chain ends in a cycle).

__Max-Visits__ : Production chains end whenever they give a product this number of times to the same firm. This limit prevents never-ending production chain cycles. (E.g. consider the case of two firms linked only to each other, one having only the rule "0->1" and the other having only "1->0".) Default value is 1.

__Original-Cycles-Only__ : In our method for counting hypercycles, it is possible to count a cycle more than once. This happens when the first firm in the cycle can be supplied with its input product by more than one firm. To avoid this, cycles must be stored in a list once found, and new identifications of cycles checked against this list. Using the list requires memory and computing time, especially during the early stages of a simulation run, when the list is long. You may prefer to switch the use of it off, especially if what is most important is the fact that there are at least some hypercycles, not how many there are. Firms that supply input products to a hypercycle but are not themselves supported by a hypercycle are likely to lose their rules if given enough time, so their existence is probably a sign of too-short simulation runs.

__HCs-Limit__ : Hypercycle counting can be highly time-consuming compared to iterations of production chain simulation, especially early on when many firms remain. To save time, hypercycle counting halts whenever it reaches this limit. (Particularly useful when what you want to know is that there are at least some hypercycles - not how many.) When interpreting metrics from a simulation run, you should first check whether the number of hypercycles is equal to this limit, in which case the exact number of hypercycles is not known, nor are dependent metrics, such as the numbers of parasite rules, firms and links.

__RNG-Seed__ : If set to a number other than 0, then this is fed to NetLogo's random number generator as a seed number. If set to 0, NetLogo generates a random seed number. Given the same seed number, NetLogo should repeat a simulation run exactly. This may be useful when trying to a simulation run where a bug has occurred.

### Firm Network Structure

Firms can be arranged in alternative network structures at the start. Several parameters control this.

__Interaction-Topology__ : The network structure or topology of the firms at the start. Firms can only pass products to neighbours in this network. "8-Neighbour Grid" is the default, a 2-dimensional, Moorean network architecture, in which most firms have neighbours above, below, to the left and right and diagonally adjacent to them. (Unlike Padgett 1997 we do not allow firms at the edge to connect to firms at the opposite edge, or wrap-around. This difference does not seem to have an important effect on model behaviour.) Other options include "4-Neighbour Grid" (von Neumann architecture), "Complete", and "Scale-free (Barabasi-Albert)".

__Rewire-Chance__ : Once an initial network has been created, each link has a chance of being rewired randomly. Demonstrated in the small-world networks of Watts, D & S Strogatz (1998). Default value is 0.

__Link-Radius__ : Used with "Social Circles" topology. Firms are given random spatial locations, then linked to any other firm within a given distance of them, defined by the radius. The impact of this parameter on network density will depend on the number of firms and on the dimensions of the world space.

__Link-Chance__ : Used with "Erdos-Renyi random" topology. Two firms are linked at random, with this chance.


## OUTPUTS AND CHARTS

N.B. Hypercycle calculation is only performed once every "Output-Every" number of time ticks.

### Key metrics:  

These include the current number of firms, the mean number of rules per firm, and the number of hypercycles in the current system.

### Hypercycle calculations:

__A hypercycle__ is a chain of firms and production rules that ends where it started. Hypercycles are included in this count if and only if it is possible to commence the chain given the current input environment and methods concerning its use (rich/poor, endogenous/not). Depending on the setting of "Original-Cycles-Only", some hypercycles may be counted more than once, because it has been possible to commence them from more than one source.

Hypercycle calculation also calculates the % of the current firms, links and rules that are not part of any hypercycle. When a system has become stochastically stable while still containing at least one hypercycle, any remaining firms, links or rules not involved in a hypercycle are parasites, benefitting from the products flowing out of hypercycles but not themselves contributing useful inputs to a cycle's members.

Remember: hypercycle calculation terminates prematurely if the count of hypercycles reaches "HCs-Limit". Statistics based on the numbers of hypercycles and parasites are only accurate if "HCs-Limit" has not been reached.

### Charts:

Charts are shown over time for the numbers of firms and hypercycles. Also shown over time are the average rate per tick of rules being reproduced via "learning", and the rate of production chains resulting in a completed cycle. When the learning rate stabilises at 0, this is because there are no more rules left in the population capable of processing any of the products in the input environment. Hence no more production rules can be generated, and no more learning can occur - the production system is dead. Before that point is reached, the History Histogram shows with what rate chains of particular lengths are being generated.

Time series charts are shown for the stocks or numbers of instances of each product type in the input-environment, and the numbers of instances of each rule type in the firm population, labelled by each rule type's input product. Under "Solo" chemistry, if the number of instances of a particular rule type hits zero, then there is no more possibility of hypercycles. Use these time series, then, to assess whether the system is broken (zero hypercycles), stochastically stable (i.e. there is random variation in stock levels, but it is not noticeably growing) or shows unstable variability.

Other histograms are also calculated for:  
Input environment : This will not change unless the environment is endogenous.  
Output environment : This indicates in what proportions products are being produced and discarded.  
Cycle Length : The frequency distribution of lengths of hypercycles.

### Network metrics:

Firms can only interact with those they are linked to. Links die when one of the firms at their ends dies. The current number of links is shown. Also shown is the network density, i.e. the current number of links divided by the current number of possible links. If n is the current number of living firms, the number of possible links = n * (n - 1) / 2.

A histogram shows the frequency distribution of the number of links per firm, also called "degree centrality".


## THINGS TO NOTICE

Depending on the input parameters, there may emerge persistent hypercycles of production rules and firms.


## THINGS TO TRY

There is a "complexity barrier", beyond which few hypercycles can persist. The exact value at which it is encountered, however, varies with the input factors included here, in particular network topology, target or source reproduction, and rich or poor environment. Use the experiments in BehaviorSpace to explore this further.


## EXTENDING THE MODEL

Try alternative input topologies, with varying degree distributions and clustering.  
Try more complicated production rule sets (chemistry), including multiple input and output products per rule. (NB. Calculations of hypercycles will have to be replaced with calculations of the existence of auto-catalytic sets. This is not an easy problem.)

Chapter 4 of Padgett & Powell (2012) describes extensions to the Hypercycles model, including distribution rules (i.e. to which neighbour should a product be passed), communication of symbols for products, and births and deaths of agents.

This NetLogo program was extended for a study of resilience to system shocks. See Watts & Binder (2012).


## RELATED MODELS

A java version based on Padgett (1997) was included in distributions of Repast, including Repast 3.

An R version was used for the experiments in Padgett et al. (2003) and Padgett et al.  (2012). This may be available from Padgett's website:
http://home.uchicago.edu/~jpadgett/data.html

Simulation models with some similarities to the HyperCycles model include Algorithmic Chemistry, Autocatalytic Sets, and models of emergent Innovation Networks, e.g. SKIN. 

Compare also the use of Ant-Colony Optimization or Cross-Entropy Method when solving Network Planning Problems (NPP).


## CREDITS AND REFERENCES

### Padgett's work

Padgett, John (1997) "The emergence of simple ecologies of skill: a hypercycle approach to economic organization" in Arthur, WB, SN Durlauf & DA Lane eds. "The Economy as an Evolving Complex System II", Addison-Wesley: Reading, MA.

Padgett, John, Lee Doowan, & Nick Collier (2003) "Economic production as chemistry", Industrial and Corporate Change, 12(4), 843-877.

Padgett, John F, Peter McMahan, & Xing Zhong (2012) "Economic Production as Chemistry II", chapter 3 in Padgett & Powell (2012). 

Padgett, J. F., & Powell, W. W. (2012) "The emergence of organizations and markets." Princeton, N.J. ; Oxford: Princeton University Press.

### An extension by Watts

Watts, Christopher & Binder, Claudia R. (2012) "Simulating Shocks with the Hypercycles Model of Economic Production", International Environmental Modelling and Software Society (iEMSs) 2012 International Congress on Environmental Modelling and Software Managing Resources of a Limited Planet, Sixth Biennial Meeting, Leipzig, Germany. R. Seppelt, A.A. Voinov, S. Lange, D. Bankamp (Eds.) http://www.iemss.org/society/index.php/iemss-2012-proceedings

### Hypercycle theory in biology

Eigen, M. (1971). "Selforganization of matter and evolution of biological macromolecules." Naturwissenschaften, 58(10), 465-&. 

Eigen, M. (1979). "The Hypercycle : A Principle of Natural Self-Organization." Berlin: Springer.

Eigen, M., & Schuster, P. (1977). "Hypercycle - Principle of natural self-organization .A. Emergence of hypercycle." Naturwissenschaften, 64(11), 541-565. doi: 10.1007/bf00450633

Eigen, M., & Schuster, P. (1978a). "Hypercycle - Principle of natural self-organization .B. Abstract hypercycle." Naturwissenschaften, 65(1), 7-41. doi: 10.1007/bf00420631

Eigen, M., & Schuster, P. (1978b). "Hypercycle - Principle of natural self-organization .C. Realistic hypercycle." Naturwissenschaften, 65(7), 341-369. doi: 10.1007/bf00439699

Hofbauer, J., & Sigmund, K. (1988). "The theory of evolution and dynamical systems : mathematical aspects of selection." Cambridge: Cambridge University Press.

Hofbauer, J., & Sigmund, K. (1998). "Evolutionary games and population dynamics." Cambridge: Cambridge University Press.

### Analogous models

Fontana, W. (1992). "Algorithmic Chemistry (Vol. 10)". Reading: Addison-Wesley Publ Co.

Kauffman, S. A. (1995). "At home in the universe : the search for laws of self-organization and complexity." New York ; Oxford: Oxford University Press.


## VERSION HISTORY

02-Dec-2014: Corrected hypercycles calculation. Concept of "# hypercycles starting with product 0" is now obsolete and is removed from the program.

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

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

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
  <experiment name="experiment-Selective" repetitions="10" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0) and (ticks &gt; 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Endog" repetitions="30" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0) and (ticks &gt; 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
      <value value="&quot;All&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-PoorRich" repetitions="30" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0) and (ticks &gt; 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
      <value value="&quot;All&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="200000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-all-options-All" repetitions="100" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;All&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-all-options" repetitions="100" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
      <value value="&quot;All&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-8N-Rewire" repetitions="10" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
      <value value="0.003162278"/>
      <value value="0.01"/>
      <value value="0.031622777"/>
      <value value="0.1"/>
      <value value="0.316227766"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-ER-Density" repetitions="100" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="1"/>
      <value value="0.8"/>
      <value value="0.4"/>
      <value value="0.2"/>
      <value value="0.1"/>
      <value value="0.05"/>
      <value value="0.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-8N-Rewire-RS" repetitions="10" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
      <value value="0.003162278"/>
      <value value="0.01"/>
      <value value="0.031622777"/>
      <value value="0.1"/>
      <value value="0.316227766"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-ER-Density-RS" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Random (Erdos-Renyi)&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="1"/>
      <value value="0.8"/>
      <value value="0.4"/>
      <value value="0.2"/>
      <value value="0.1"/>
      <value value="0.05"/>
      <value value="0.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-all-options-RS" repetitions="100" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
      <value value="&quot;All&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
      <value value="&quot;Complete&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-SocialCircles" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-SocialCircles-Rewired" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-SocialCircles-Rewired-SS" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Poor&quot;"/>
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rewire-Chance">
      <value value="0"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-SocialCircles-Rewired-SS-RC6" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Selective Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;Social Circles&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Rule-Complexity">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rewire-Chance" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Solo-8N-Rewire-RS" repetitions="50" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <exitCondition>(num-cycles = 0)</exitCondition>
    <metric>timer</metric>
    <metric>(timer - init-timer)</metric>
    <metric>count firms</metric>
    <metric>init-net-density</metric>
    <metric>sum [p-rule-sum] of firms</metric>
    <metric>num-cycles</metric>
    <metric>ifelse-value (num-cycles = 0) [0] [1]</metric>
    <metric>num-completed / output-every</metric>
    <metric>num-completed</metric>
    <metric>ifelse-value (num-completed &gt; 0) [1] [0]</metric>
    <metric>num-input-product-types</metric>
    <metric>num-output-product-types</metric>
    <metric>num-env-product-types</metric>
    <metric>num-rules-learned</metric>
    <metric>num-rules-learned / output-every</metric>
    <metric>num-distinct-rules</metric>
    <metric>num-distinct-rules / (count firms)</metric>
    <metric>num-parasite-rules</metric>
    <metric>num-parasite-firms</metric>
    <metric>num-parasite-links</metric>
    <metric>perc-parasite-rules</metric>
    <metric>perc-parasite-firms</metric>
    <metric>perc-parasite-links</metric>
    <metric>array:to-list i-environment</metric>
    <metric>array:to-list o-environment</metric>
    <enumeratedValueSet variable="Number-of-Firms">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-Rules">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chemistry">
      <value value="&quot;Solo Hypercycle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Search">
      <value value="&quot;Random Search&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Learning">
      <value value="&quot;Source Reproduction&quot;"/>
      <value value="&quot;Target Reproduction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Input-Environment">
      <value value="&quot;Rich&quot;"/>
      <value value="&quot;Poor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Endogenous-Environment">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interaction-Topology">
      <value value="&quot;8-Neighbour Grid&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rule-Complexity" first="2" step="1" last="9"/>
    <enumeratedValueSet variable="Link-Chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Link-Radius">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Rewire-Chance" first="0" step="0.2" last="1"/>
    <enumeratedValueSet variable="Number-Of-Starting-Products">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-Visits">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Original-Cycles-Only">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Calculations">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Show-Products">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Print-Hypercycles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HCs-Limit">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RNG-Seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-Every">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Max-ticks">
      <value value="100000"/>
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
