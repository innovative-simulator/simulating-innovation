;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Citation Agents
;; This version (C) Christopher Watts, 2014. See Info tab for terms and conditions of use.
;; Based on the work described in Watts, C & N Gilbert (2011)
;; "Simulating the impact of cumulative advantage on scientific performance", Scientometrics.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [array]

globals [
  
  num-papers-to-date
  num-pubs-to-date
  num-new-authors
  num-authors-to-date
  
  y-papers ; Array of paper lists for each year
  y-num-papers ; Array of # papers for each year
  y-pubs ; Array of publication lists for each year
  y-num-pubs ; Array of # publications for each year
  y-num-authors ; Array of # new authors for each year
  y-cites-frompapers ; Array of # citations received from papers
  y-cites-frompubs ; Array of # citations received from pubs
  y-max-fitness ; Array of max-fitness value at each year
  y-mean-fitness ; Array of mean-fitness value at each year
  
  authrecency-pdf ; Pre-calculated probability density function, used for recency of papers when selecting authors
  refrecency-pdf ; Pre-calculated probability density function, used for recency of papers when selecting references
  peerrecency-pdf ; Pre-calculated probability density function, used for recency of papers when selecting peer reviewers
  
  weights ; Used variously for stratified sampling
  
  ; Frequency distributions
  applist
  apjlist
  ppalist
  jpalist
  rpplist
  rpjlist
  cpplist
  jcpjlist
  jamlist
  jcmlist
  
  mean-fitness
  max-fitness
  initial-mean-fitness
  initial-max-fitness
  
  input-sets
  fitness-tables
]

breed [papers paper]
breed [authors author]
directed-link-breed [wlinks wlink] ; x Wrote y
directed-link-breed [alinks alink] ; y Authored by x
directed-link-breed [rlinks rlink] ; x Refers to y
directed-link-breed [clinks clink] ; y Cited by x
undirected-link-breed [coalinks coalink] ; x and y are coauthors
undirected-link-breed [shalinks shalink] ; x and y share authors
undirected-link-breed [cocitlinks cocitlink] ; x and y cite the same source.

papers-own [
  pdate
  first-author
  contents
  fitness
  status ; 0 for founding papers; 1 for unpublished papers; 2 for papers published in journal
]

authors-own [
  beliefs
  fitness
]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  ask patches [ set pcolor white ]
  
  ; Pre-calculate probability density functions for speed
  set authrecency-pdf array:from-list n-values (time-steps + 1) [0]
  calc-pdf authrecency-pdf authrecency-p1 authrecency-p2
  set refrecency-pdf array:from-list n-values (time-steps + 1) [0]
  calc-pdf refrecency-pdf refrecency-p1 refrecency-p2
  set peerrecency-pdf array:from-list n-values (time-steps + 1) [0]
  calc-pdf peerrecency-pdf peerrecency-p1 peerrecency-p2
  
  ; Arrays by Year
  set weights array:from-list n-values (time-steps + 1) [0]
  set y-papers array:from-list n-values (time-steps + 1) [[]]
  set y-num-papers array:from-list n-values (time-steps + 1) [0]
  set y-pubs array:from-list n-values (time-steps + 1) [[]]
  set y-num-pubs array:from-list n-values (time-steps + 1) [0]
  set y-cites-frompapers array:from-list n-values (time-steps + 1) [0]
  set y-cites-frompubs array:from-list n-values (time-steps + 1) [0]
  set y-num-authors array:from-list n-values (time-steps + 1) [[]]
  set y-mean-fitness array:from-list n-values (time-steps + 1) [0]
  set y-max-fitness array:from-list n-values (time-steps + 1) [0]
  
  setup-field
  
  my-update-plots
  
end

to my-setup-plots
  set-current-plot "New Papers"
  set-plot-x-range 1 (time-steps + 1)
  set-current-plot "Papers To Date"
  set-plot-x-range 1 (time-steps + 1)
  
  set-current-plot "New Authors"
  set-plot-x-range 1 (time-steps + 1)
  set-current-plot "Authors To Date"
  set-plot-x-range 1 (time-steps + 1)
end  

to go
  if ticks >= time-steps [stop]
  tick ; Founding papers treated as year 0; first volume of journal is year 1
  grow-field
  my-update-plots
  ;print ticks
  
  if ticks >= time-steps [
    calc-final-distributions
    draw-final-plots
    stop
  ]
  
end

to my-update-plots
  set-current-plot "New Papers"
  set-current-plot-pen "Papers"
  plotxy ticks (array:item y-num-papers ticks)
  set-current-plot-pen "Publications"
  plotxy ticks (array:item y-num-pubs ticks)
  
  set-current-plot "Papers To Date"
  set-current-plot-pen "Papers"
  plotxy ticks num-papers-to-date
  set-current-plot-pen "Publications"
  plotxy ticks num-pubs-to-date

  set-current-plot "Authors To Date"
  plotxy ticks num-authors-to-date

  set-current-plot "New Authors"
  plotxy ticks num-new-authors
  
  set-current-plot "Fitness"
  set-current-plot-pen "Max"
  plotxy ticks (max [fitness] of authors)
;  plotxy ticks max-fitness
  set-current-plot-pen "Mean"
  plotxy ticks (mean [fitness] of authors)
;  plotxy ticks mean-fitness
  
  set-current-plot "% of Papers Accepted"
  plotxy ticks ifelse-value ((array:item y-num-papers ticks) = 0) [0] [100 * (array:item y-num-pubs ticks) / (array:item y-num-papers ticks)]
end

to draw-final-plots
  ; Authors
  
  set-current-plot "Authors Per Paper"
  draw-pairs-list applist
  
  set-current-plot "Authors Per Publication"
  draw-pairs-list apjlist
  
  set-current-plot "Papers Per Author"
  draw-pairs-list ppalist
  
  set-current-plot "log-log (Papers Per Author)"
  draw-loglog-pairs-list ppalist
  
  set-current-plot "Publications Per Author"
  draw-pairs-list jpalist
  
  set-current-plot "log-log (Publications Per Author)"
  draw-loglog-pairs-list jpalist
  
  ; References
  
  set-current-plot "References Per Paper"
  draw-pairs-list rpplist
  
  set-current-plot "References Per Publication"
  draw-pairs-list rpjlist

  set-current-plot "Citations Per Paper"
  draw-pairs-list cpplist
  
  set-current-plot "log-log (Citations Per Paper)"
  draw-loglog-pairs-list cpplist
  
  set-current-plot "Citations Per Publication"
  draw-pairs-list jcpjlist
  
  set-current-plot "log-log (Citations Per Publication)"
  draw-loglog-pairs-list jcpjlist
  
  ; Citations Received by papers in each year
  set-current-plot "Citations Received"
  let cur-year 0
  repeat time-steps [
    plotxy cur-year sum [count my-out-clinks] of papers with [pdate = cur-year]
    set cur-year cur-year + 1
  ]
  
  ; Authorship time gaps
  let timegaps []  
  let cur-paper nobody
  ask papers with [pdate = ticks] [
    set cur-paper self
    ask out-alink-neighbors [
      ask out-wlink-neighbors [
        if (self != cur-paper) [
          set timegaps fput (ticks - pdate) timegaps
        ]
      ]
    ]
  ]
  ;set timegaps sort timegaps
  set-current-plot "Years since previous papers"
  set-plot-x-range 0 (1 + max timegaps) 
  histogram timegaps
  
  ; Citing-Cited time gaps
  set timegaps []  
  ask papers with [pdate = ticks] [
    ask out-rlink-neighbors [
      set timegaps fput (ticks - pdate) timegaps
    ]
  ]
  ;set timegaps sort timegaps
  set-current-plot "Citing-Cited Gap"
  if (0 < length timegaps) [set-plot-x-range 0 (1 + max timegaps) ]
  histogram timegaps
  
  ; Career span
  set timegaps []
  ask authors [
    if 0 < count out-wlink-neighbors [
      set timegaps fput ((max [pdate] of out-wlink-neighbors) - (min [pdate] of out-wlink-neighbors)) timegaps
    ]
  ]
  set-current-plot "Career Span"
  set-plot-x-range 0 (1 + max timegaps) 
  histogram timegaps
  
end

to draw-pairs-list [pairs-list]
  foreach pairs-list [
    plotxy (first ?) (first but-first ?)
  ]
end

to draw-loglog-pairs-list [pairs-list]
  let curval 0
  let curfreq 0
  foreach pairs-list [
    set curval (first ?)
    if curval > 0 [
      set curfreq (first but-first ?)
      if curfreq > 0 [
        plotxy (log curval 10) (log curfreq 10)
      ]
    ]
  ]
end

to draw-loglog-histo [histolist]
  let freq 1
  let curval first histolist
  set histolist but-first histolist
  while [0 < length histolist] [
    ifelse curval = first histolist [
      set freq freq + 1
    ]
    [
      if curval > 0 [plotxy (log curval 10) (log freq 10)]
      set freq 1
      set curval first histolist
    ]
    set histolist but-first histolist
  ]
  plotxy (log curval 10) (log freq 10)  
end  

to print-histo [histolist]
  let freq 1
  let curval first histolist
  set histolist but-first histolist
  while [0 < length histolist] [
    ifelse curval = first histolist [
      set freq freq + 1
    ]
    [
      print (word curval ", " freq )
      set freq 1
      set curval first histolist
    ]
    set histolist but-first histolist
  ]
  print (word curval ", " freq )
end

to-report freq-distribution [histolist]
  let freqd []
  let freq 1
  if 0 < length histolist [
    let curval first histolist
    set histolist but-first histolist
    while [0 < length histolist] [
      ifelse curval = first histolist [
        set freq freq + 1
      ]
      [
        set freqd fput (list curval freq) freqd
        set freq 1
        set curval first histolist
      ]
      set histolist but-first histolist
    ]
    set freqd fput (list curval freq) freqd
  ]
  report reverse freqd
end

to print-pairs-list [pairs-list]
  foreach pairs-list [
    print (word (first ?) ", " (first but-first ?) )
  ]
end

to calc-final-distributions
  ; Authors per Paper
  print ""
  let histolist [count out-alink-neighbors] of papers with [status > 0]
  set histolist sort histolist
  set applist freq-distribution histolist
  
  ; Authors per Pub
  print ""
  set histolist [count out-alink-neighbors] of papers with [status = 2]
  set histolist sort histolist
  set apjlist freq-distribution histolist
  
  ; Papers per Author
;  let histolist [count out-wlink-neighbors] of authors
  set histolist [count out-wlink-neighbors with [status > 0]] of authors
  set histolist sort histolist
  set ppalist freq-distribution histolist
  
  ; Pubs per Author
;  let histolist [count out-wlink-neighbors] of authors
  set histolist [count out-wlink-neighbors with [status = 2]] of authors
  set histolist sort histolist
  set jpalist freq-distribution histolist
  
  ; References per Paper
  set histolist [count out-rlink-neighbors] of papers with [status > 0]
  set histolist sort histolist
  set rpplist freq-distribution histolist
  
  ; References per Pub
  set histolist [count out-rlink-neighbors] of papers with [status = 2]
  set histolist sort histolist
  set rpjlist freq-distribution histolist
  
  ; Citations per Paper
  set histolist [count out-clink-neighbors with [status > 0]] of papers with [status > 0]
  set histolist sort histolist
  set cpplist freq-distribution histolist
  
  ; Citations per Pub
  set histolist [count out-clink-neighbors with [status = 2]] of papers with [status = 2]
  set histolist sort histolist
  set jcpjlist freq-distribution histolist
  
  ; Author Memory
  set histolist []
  let epdate 0
  let curyear-pubs (papers with [(status = 2) and (pdate = ticks)])
  ask papers with [status = 2] [
    set epdate pdate
    ask curyear-pubs [
      if (common-author self myself) [
        set histolist fput (ticks - epdate) histolist
      ]
    ]
  ]
  set histolist sort histolist
  set jamlist freq-distribution histolist
  
  ; Citation Memory
  set histolist []
  ask papers with [(status = 2) and (pdate = ticks)] [
    ask out-rlink-neighbors [
      set histolist fput (ticks - pdate) histolist
    ]
  ]
  set histolist sort histolist
  set jcmlist freq-distribution histolist
end

to print-final-distributions
  print "Authors Per Paper"
  print-pairs-list applist
  print ""
  print "Papers Per Author"
  print-pairs-list ppalist
  print ""
  print "Publications Per Author"
  print-pairs-list jpalist
  print ""
  print "References Per Paper"
  print-pairs-list rpplist
  print ""
  print "References Per Publication"
  print-pairs-list rpjlist
  print ""
  print "Citations Per Paper"
  print-pairs-list cpplist
  print ""
  print "Citations Per Publication"
  print-pairs-list jcpjlist
  print ""
  print "Author Memory"
  print-pairs-list jamlist
  print ""
  print "Citation Memory"
  print-pairs-list jcmlist
  print ""
end

to-report common-author [ego alter]
  report (0 < ([count out-alink-neighbors with [out-wlink-neighbor? alter]] of ego))
end
      
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-field
  let new-papers []
  let cur-paper nobody
  set num-new-authors 0
  set mean-fitness 0
  
  repeat foundational-papers [
    create-papers 1 [
      set hidden? hide-papers
      set color blue
      set pdate 0
      set status 0
      set contents array:from-list n-values contents-size [random-xcor]
      setxy (array:item contents 0) (array:item contents 1)
      calc-paper-fitness
      set new-papers fput self new-papers
      set cur-paper self
    ]
    
    create-authors 1 [
      set hidden? hide-authors
      set shape "person"
      setxy ([xcor] of cur-paper) ([ycor] of cur-paper)
      set color yellow
      set beliefs (array:from-list (array:to-list [contents] of cur-paper))
      calc-agent-fitness
      set num-new-authors num-new-authors + 1
      write-paper cur-paper
      ask cur-paper [set first-author myself]
    ]
  ]
  
  array:set y-papers ticks new-papers
  array:set y-num-papers ticks (length new-papers)
  array:set y-pubs ticks new-papers ; Founding papers are automatically published.
  array:set y-num-pubs ticks (length new-papers)
  array:set y-num-authors ticks num-new-authors
  
  set num-papers-to-date 0 ; Excludes founding papers
  set num-pubs-to-date 0
  set num-authors-to-date 0
  set max-fitness max [fitness] of papers
  set mean-fitness mean [fitness] of papers
  
end

to grow-field
  let new-papers []
  let new-pubs []
  let cur-paper nobody
  set num-new-authors 0
  set mean-fitness 0
  
  repeat (first-year-papers * (field-growth ^ (ticks - 1))) [
    create-papers 1 [
      set hidden? hide-papers
      setxy (ticks * max-pxcor / time-steps) random-ycor
      set color green
      set pdate ticks
      set status 1
      set new-papers fput self new-papers
      set cur-paper self
    ]
    
    ; Generate First Author
    ask generated-author cur-paper [
      write-paper cur-paper
      ask cur-paper [set first-author myself]
    ]
    ; Generate Coauthors
    repeat int (weibull-dist authorsperpaper-p1 authorsperpaper-p2) [
      ask generated-author cur-paper [
        if author-accepts ([first-author] of cur-paper) [
          write-paper cur-paper
        ]
      ]
    ]
    
    ; Generate References
    let refpaper nobody
    repeat int (weibull-dist refsperpaper-p1 refsperpaper-p2) [
      set refpaper (generated-reference cur-paper)
      if refpaper != nobody [
        ask refpaper [
          if ref-similarity >= (author-paper-similarity ([first-author] of cur-paper) self) [ 
            cite-paper cur-paper
          ]
        ]
      ]
    ]
    
    ; Generate Contents
    let cur-bit 0
    ask cur-paper [
      let num-sources (count out-alink-neighbors) + (count out-rlink-neighbors)
      set contents array:from-list n-values contents-size [0]
      repeat contents-size [
        ifelse random-float 1 < chance-bit-innovative [
          array:set contents cur-bit (random-xcor)
        ]
        [
          array:set contents cur-bit ((sum [array:item beliefs cur-bit] of out-alink-neighbors ) + (sum [array:item contents cur-bit] of out-rlink-neighbors)) / ((count out-alink-neighbors) + (count out-rlink-neighbors))
;          ifelse (random num-sources) < (count out-alink-neighbors) [
;            array:set contents cur-bit ([array:item beliefs cur-bit] of one-of out-alink-neighbors)
;          ]
;          [
;            array:set contents cur-bit ([array:item contents cur-bit] of one-of out-rlink-neighbors)
;          ]
        ]
        set cur-bit cur-bit + 1
      ]
      setxy (array:item contents 0) (array:item contents 1)
    ]
    
    ; Calculate fitness
    ; Authors have option of copying superior contents
    ask cur-paper [
      calc-paper-fitness
      let cur-fitness fitness
      ask out-alink-neighbors [
        if fitness <= cur-fitness [
          set cur-bit 0
          repeat contents-size [
            array:set beliefs cur-bit ([array:item contents cur-bit] of myself)
            set cur-bit cur-bit + 1
          ]
          setxy (array:item beliefs 0) (array:item beliefs 1)
          calc-agent-fitness
        ]
      ]
      if fitness > max-fitness [set max-fitness fitness]
      set mean-fitness mean-fitness + fitness
    ]
    
    ; Publish?
    ask cur-paper [
      if publishable [
        set status 2
        set color red
        set size 2
        set new-pubs fput self new-pubs
      ]
    ]
    
  ]
  array:set y-papers ticks new-papers
  array:set y-num-papers ticks (length new-papers)
  set num-papers-to-date num-papers-to-date + (length new-papers)
  
  set num-authors-to-date num-authors-to-date + num-new-authors
  array:set y-num-authors ticks num-new-authors
  
  if (length new-papers) > 0 [ set mean-fitness (mean-fitness / (length new-papers))]
  array:set y-mean-fitness ticks mean-fitness
  array:set y-max-fitness ticks max-fitness
  
  array:set y-pubs ticks new-pubs
  array:set y-num-pubs ticks (length new-pubs)
  set num-pubs-to-date num-pubs-to-date + (length new-pubs)
  
  ; Update citations received by year
  foreach new-papers [
    ask ? [
      ifelse status = 2 [
        ask out-rlink-neighbors [
          array:set y-cites-frompapers pdate (1 + array:item y-cites-frompapers pdate)
          array:set y-cites-frompubs pdate (1 + array:item y-cites-frompubs pdate)
        ]
      ]
      [
        ask out-rlink-neighbors [
          array:set y-cites-frompapers pdate (1 + array:item y-cites-frompapers pdate)
        ]
      ]
    ]
  ]
end

to write-paper [given-paper]
  create-wlink-to given-paper [
    set color red
    set hidden? hide-wlinks]
  create-alink-from given-paper [
    set color yellow
    set hidden? hide-alinks]
end

to cite-paper [given-paper]
  create-clink-to given-paper [
    set color pink
    set hidden? hide-clinks]
  create-rlink-from given-paper [
    set color sky
    set hidden? hide-rlinks]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report weibull-dist [alpha beta]
;      FndblRnd_Weibull = pdblBeta * ((-Log(1 - grnsSim.genrand_real2b)) ^ (1 / pdblAlpha))
  report beta * ((0 - ln (1 - random-float 1)) ^ (1 / alpha))
end

to calc-pdf [given-pdf param1 param2]
  ; Recency of papers, when selecting authors
  let prevval 0
  let curval 0
  let x 0
  repeat (time-steps + 1) [
    ; Weibull distributed
    set curval 1 - exp (0 - (((x + 1) / param2) ^ param1))
    array:set given-pdf x (curval - prevval)
    set prevval curval
    set x x + 1
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Authorship

to-report generated-author [given-paper]
  let cur-author nobody
  let selpaper nobody
  ifelse (random-float 1) < chance-new-to-field [
    ; New author
    create-authors 1 [
      set hidden? hide-authors
      set shape "person"
;      setxy ([xcor] of given-paper) ([ycor] of given-paper)
      set color red
      set beliefs array:from-list n-values contents-size [random-xcor]
      setxy (array:item beliefs 0) (array:item beliefs 1)
      set fitness 0
      set cur-author self
      set num-new-authors num-new-authors + 1
    ]
    ;print cur-author
    report cur-author
  ]
  [
    ; Select an existing author
    if selecting-authors-method = "From recent paper" [
      report  ([one-of out-alink-neighbors] of (recent-paper authrecency-pdf))
    ]
    if selecting-authors-method = "From recently cited paper" [
      set selpaper (recent-paper authrecency-pdf)
      if 0 = [count out-rlink-neighbors] of selpaper [ report [one-of out-alink-neighbors] of selpaper ]
      report ([one-of out-alink-neighbors] of ([one-of out-rlink-neighbors] of selpaper))
    ]
    if selecting-authors-method = "Any author" [
      report one-of authors
    ]
    if selecting-authors-method = "From recent publication" [
      report  ([one-of out-alink-neighbors] of (recent-pub authrecency-pdf))
    ]
    if selecting-authors-method = "From recently cited publication" [
      set selpaper (recent-pub authrecency-pdf)
      if 0 = [count out-rlink-neighbors] of selpaper [ report [one-of out-alink-neighbors] of selpaper ]
;      if (random-float 1) < (1 / (1 + [count out-rlink-neighbors] of selpaper)) [ report [one-of out-alink-neighbors] of selpaper ]
      report ([one-of out-alink-neighbors] of ([one-of out-rlink-neighbors] of selpaper))
    ]
  ]
end

to-report recent-paper [weighting-pdf]
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year)) * (array:item y-num-papers year)
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  set weightsum weightsum + array:item weights year
  let chosenitem (int (weightsum / (array:item weighting-pdf (ticks - 1 - year))))
  report item chosenitem (array:item y-papers year)
end

to-report recent-pub [weighting-pdf]
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year)) * (array:item y-num-pubs year)
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  set weightsum weightsum + array:item weights year
  let chosenitem (int (weightsum / (array:item weighting-pdf (ticks - 1 - year))))
  report item chosenitem (array:item y-pubs year)
end

to-report recently-cited-paper [weighting-pdf]
  let selpaper (recent-paper refrecency-pdf)
  if selpaper = nobody [report nobody]
  let numrefs ([count out-rlink-neighbors] of selpaper)
;    ifelse (random-float 1) < (chance-use-paper-not-ref + (1 / (numrefs + 1))) [
  ifelse (random-float 1) < (chance-use-paper-not-ref) [
    report selpaper
  ]
  [
    if (0 = numrefs) [report selpaper]
    report (one-of [out-rlink-neighbors] of selpaper)
  ]
end

to-report recently-cited-pub [weighting-pdf]
  let selpaper (recent-pub refrecency-pdf)
  if selpaper = nobody [report nobody]
  let numrefs ([count out-rlink-neighbors] of selpaper)
;    ifelse (random-float 1) < (chance-use-paper-not-ref + (1 / (numrefs + 1))) [
  ifelse (random-float 1) < (chance-use-paper-not-ref) [
    report selpaper
  ]
  [
    if (0 = numrefs) [report selpaper]
    report (one-of [out-rlink-neighbors] of selpaper)
  ]
end

to-report cited-and-recent-paper [weighting-pdf]
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year)) * ((array:item y-num-papers year) + (array:item y-cites-frompapers year))
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  set weightsum weightsum + array:item weights year
  set weightsum (weightsum / (array:item weighting-pdf (ticks - 1 - year)))
  let citeslist array:item y-papers year
  if 0 = length citeslist [report nobody]
  let chosenitem first citeslist
  set weightsum weightsum - 1 - [count my-out-clinks] of chosenitem
  while [weightsum >= 0] [
    set citeslist but-first citeslist
    set chosenitem first citeslist
    set weightsum weightsum - 1 - [count my-out-clinks] of chosenitem
  ]
  report chosenitem
end

to-report cited-and-recent-pub [weighting-pdf]
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year)) * ((array:item y-num-pubs year) + (array:item y-cites-frompubs year))
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  set weightsum weightsum + array:item weights year
  set weightsum (weightsum / (array:item weighting-pdf (ticks - 1 - year)))
  let citeslist array:item y-pubs year
  if 0 = length citeslist [report nobody]
  let chosenitem first citeslist
  set weightsum weightsum - 1 - [count my-out-clinks] of chosenitem
  while [weightsum >= 0] [
    set citeslist but-first citeslist
    set chosenitem first citeslist
    set weightsum weightsum - 1 - [count my-out-clinks] of chosenitem
  ]
  report chosenitem
end

to-report recent-year-paper [weighting-pdf]
  ; Picks a recent year, then returns a paper from it (if one exists)
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year))
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  report ifelse-value (0 = (array:item y-num-papers year)) [nobody] [one-of array:item y-papers year]
end

to-report recent-year-pub [weighting-pdf]
  ; Picks a recent year, then returns a pub from it (if one exists)
  let weightsum 0
  let weight 0
  let year 0
  repeat ticks [
    set weight (array:item weighting-pdf (ticks - 1 - year))
    array:set weights year weight
    set weightsum weightsum + weight
    set year year + 1
  ]
  
  if weightsum = 0 [report nobody]
  set weightsum random-float weightsum
  
  set year -1
  while [weightsum >= 0] [
    set year year + 1
    set weightsum weightsum - array:item weights year
  ]
  report ifelse-value (0 = (array:item y-num-pubs year)) [nobody] [one-of array:item y-pubs year]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report author-accepts [given-author]
  report (self != given-author) and (auth-similarity >= authors-similarity self given-author)
end

to-report authors-similarity [ego alter]
  report mean (map [abs (?1 - ?2)] (array:to-list [beliefs] of ego) (array:to-list [beliefs] of alter))
end

to-report author-paper-similarity [given-author given-paper]
  report mean (map [abs (?1 - ?2)] (array:to-list [beliefs] of given-author) (array:to-list [contents] of given-paper)) 
end

to-report papers-similarity [ego alter]
  report mean (map [abs (?1 - ?2)] (array:to-list [contents] of ego) (array:to-list [contents] of alter)) 
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Reference

to-report generated-reference [given-paper]
  let selpaper nobody
  let numrefs 0
  if selecting-references-method = "Recent paper" [
    report (recent-paper refrecency-pdf)
  ]
  if selecting-references-method = "Copy reference in recent paper" [
    report recently-cited-paper refrecency-pdf
  ]
  if selecting-references-method = "Any past paper" [
    report one-of papers with [pdate < ticks]
  ]
  if selecting-references-method = "Recent and cited paper" [
    report (cited-and-recent-paper refrecency-pdf)
  ]
  if selecting-references-method = "Recent publication" [
    report (recent-pub refrecency-pdf)
  ]
  if selecting-references-method = "Copy reference in recent publication" [
    report (recently-cited-pub refrecency-pdf)
  ]
  if selecting-references-method = "Any past publication" [
    report one-of papers with [(pdate < ticks) and (status = 2)]
  ]
  if selecting-references-method = "Recent and cited publication" [
    report (cited-and-recent-pub refrecency-pdf)
  ]
  if selecting-references-method = "Paper from recent year" [
    report recent-year-paper refrecency-pdf
  ]
  if selecting-references-method = "Publication from recent year" [
    report recent-year-pub refrecency-pdf
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Peer Review
to-report generated-peer
  let selpaper nobody
  ; Select an existing author
  if selecting-peer-reviewers-method = "From recent paper" [
    report  ([one-of out-alink-neighbors] of (recent-paper peerrecency-pdf))
  ]
  if selecting-peer-reviewers-method = "From recently cited paper" [
    set selpaper (recent-paper peerrecency-pdf)
    if 0 = [count out-rlink-neighbors] of selpaper [ report [one-of out-alink-neighbors] of selpaper ]
    report ([one-of out-alink-neighbors] of ([one-of out-rlink-neighbors] of selpaper))
  ]
  if selecting-peer-reviewers-method = "From recent publication" [
    report  ([one-of out-alink-neighbors] of (recent-pub peerrecency-pdf))
  ]
  if selecting-peer-reviewers-method = "From recently cited publication" [
    set selpaper (recent-pub peerrecency-pdf)
    if 0 = [count out-rlink-neighbors] of selpaper [ report [one-of out-alink-neighbors] of selpaper ]
    report ([one-of out-alink-neighbors] of ([one-of out-rlink-neighbors] of selpaper))
  ]
  if selecting-peer-reviewers-method = "Any author" [
    report one-of authors
  ]
end

to-report publishable
;  print (word "Reviewing paper " who)
  let selpeer nobody
  let acceptible true
  
  ; Distinct from reference papers
  ask out-rlink-neighbors [
    if acceptible [ 
      set acceptible (originality-distance <= papers-similarity self myself)
    ]
  ]
  
  if acceptible [
    let simil 0
    let num-accepts 0
    repeat reviewer-attempts [
      set acceptible true
      set selpeer generated-peer
      if acceptible [
        set acceptible not (out-alink-neighbor? selpeer) ] ; Reviewer not an author of this paper
      if acceptible [
        set simil (author-paper-similarity selpeer self)
;        set acceptible ((contents-size > simil) and (peer-similarity <= simil)) ; Paper original and intelligible to reviewer
        set acceptible ((originality-distance <= simil) and (peer-similarity >= simil)) ; Paper original and intelligible to reviewer
      ]
      if acceptible [
        set acceptible (fitness >= [fitness] of selpeer)] ; Reviewer doesn't know better
      if acceptible [set num-accepts num-accepts + 1]
    ]
    set acceptible (num-accepts >= reviews-required)
  ]
  report acceptible
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Drawing Networks

to relocate-papers-spring
  repeat 10 [layout-spring papers cocitlinks 1 1 1 ]
end

to relocate-authors-spring
  repeat 10 [layout-spring authors coalinks 1 1 1 ]
end

to relocate-all-visible-spring
  let v-agents turtles with [not hidden?]
  let v-links links with [not hidden?]
  repeat 10 [layout-spring v-agents v-links 1 1 1 ]
end

to draw-coauthorship-links
  let ego nobody
  ask authors [
    set ego self
    ask out-wlink-neighbors [
      ask out-alink-neighbors [
        if self != ego [create-coalink-with ego [
            set hidden? hide-coauthlinks
            set color blue]]
      ]
    ]
  ]
end

to draw-cocitation-links
  let ego nobody
  ask papers [
    set ego self
    ask out-rlink-neighbors [
      ask out-clink-neighbors [
        if self != ego [create-cocitlink-with ego [
            set hidden? hide-cocitlinks
            set color cyan]]
      ]
    ]
  ]
end

to draw-sharing-links
  let ego nobody
  ask papers [
    set ego self
    ask out-alink-neighbors [
      ask out-wlink-neighbors [
        if self != ego [create-shalink-with ego [set color orange]]
      ]
    ]
  ]
end

to toggle-foundations
  ask papers with [status = 0] [set hidden? not hidden? ]
end

to toggle-set [given-set]
  ask given-set [set hidden? not hidden? ]
end

to toggle-linkset [given-linkset]
  ask given-linkset [set hidden? not hidden? ]
end

to toggle-isolates-coalinks
  ask authors with [0 = count coalink-neighbors] [set hidden? not hidden? ]
end

to toggle-isolates-cocitlinks
  ask papers with [0 = count cocitlink-neighbors] [set hidden? not hidden? ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Fitness function: 2 gaussians in 2 dimensions, with parameters to match Weisberg & Muldoon (2009)
to calc-agent-fitness
  if fitness-method = "2-D Gaussians" [
    let gsum 0
    let x (array:item beliefs 0) - 50
    let y (array:item beliefs 1) - 50
    set gsum gsum + gaussian-fitness .75 .02 .01 .02 (x - 25) (y - 25)
    set gsum gsum + gaussian-fitness .70 .01 .01 .01 (x - -5) (y - -5)
    set fitness gsum
    stop
  ]
  set fitness 1
end

to calc-paper-fitness
  if fitness-method = "2-D Gaussians" [
    let gsum 0
    let x (array:item contents 0) - 50
    let y (array:item contents 1) - 50
    set gsum gsum + gaussian-fitness .75 .02 .01 .02 (x - 25) (y - 25)
    set gsum gsum + gaussian-fitness .70 .01 .01 .01 (x - -5) (y - -5)
    set fitness gsum
    stop
  ]
  set fitness 1
end

to-report gaussian-fitness [peak x2-coeff xy-coeff y2-coeff x y]
  report peak * exp (- ((x2-coeff * (x ^ 2)) + (xy-coeff * (x * y)) + (y2-coeff * (y ^ 2))))
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
275
10
689
445
-1
-1
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
0
100
0
100
0
0
1
ticks
30.0

INPUTBOX
127
113
240
173
Foundational-Papers
14
1
0
Number

INPUTBOX
11
113
124
173
Time-Steps
30
1
0
Number

TEXTBOX
11
10
264
63
Citation Agents:\nModel Scientific Field
20
0.0
1

TEXTBOX
14
97
164
115
Field Parameters:
13
0.0
1

INPUTBOX
11
176
124
236
First-Year-Papers
16
1
0
Number

INPUTBOX
127
176
241
236
Field-Growth
1.067
1
0
Number

PLOT
902
10
1196
160
New Papers
Year
# Papers
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Papers" 1.0 1 -10899396 true "" ""
"Publications" 1.0 1 -16777216 true "" ""

BUTTON
10
64
74
97
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
77
64
140
97
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
11
243
161
261
Authorship Parameters:
13
0.0
1

CHOOSER
11
264
254
309
Selecting-Authors-Method
Selecting-Authors-Method
"From recent paper" "From recent publication" "From recently cited paper" "From recently cited publication" "Any author"
3

INPUTBOX
11
313
127
373
AuthorsPerPaper-P1
1.4
1
0
Number

INPUTBOX
129
313
253
373
AuthorsPerPaper-P2
1.3
1
0
Number

INPUTBOX
11
376
128
436
Chance-New-To-Field
0.6
1
0
Number

INPUTBOX
11
438
128
498
AuthRecency-P1
1.3
1
0
Number

INPUTBOX
129
438
254
498
AuthRecency-P2
1
1
0
Number

PLOT
1200
10
1508
160
Papers To Date
Year
# Papers
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Papers" 1.0 1 -10899396 true "" ""
"Publications" 1.0 1 -16777216 true "" ""

PLOT
698
163
898
313
New Authors
Year
# Authors
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
902
163
1102
313
Authors To Date
Year
# Authors
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
698
317
898
467
Authors Per Paper
# Authors
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
902
317
1102
467
Papers Per Author
# Papers
Frequency
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
1105
317
1305
467
log-log (Papers Per Author)
log Papers
log Freq.
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
497
531
610
564
Spring Papers
relocate-papers-spring
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
499
687
615
720
Papers On/Off
toggle-set papers
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
497
567
610
600
Spring Authors
relocate-authors-spring
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
618
687
737
720
Authors On/Off
toggle-set authors
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
619
763
750
796
Authored-By On/Off
toggle-linkset alinks
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
618
838
737
871
Wrote On/Off
toggle-linkset wlinks
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
620
879
751
912
Create Coauthorship
draw-coauthorship-links
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
619
726
735
759
Hide-alinks
Hide-alinks
0
1
-1000

SWITCH
619
802
737
835
Hide-wlinks
Hide-wlinks
0
1
-1000

TEXTBOX
496
503
646
521
Visualising Networks:
13
0.0
1

TEXTBOX
6
507
156
525
References Parameters:
13
0.0
1

CHOOSER
7
531
256
576
Selecting-References-Method
Selecting-References-Method
"Recent paper" "Recent publication" "Copy reference in recent paper" "Copy reference in recent publication" "Any past paper" "Any past publication" "Recent and cited paper" "Recent and cited publication" "Paper from recent year" "Publication from recent year"
3

INPUTBOX
7
580
123
640
RefsPerPaper-P1
1
1
0
Number

INPUTBOX
125
580
248
640
RefsPerPaper-P2
4.2
1
0
Number

INPUTBOX
7
644
147
704
Chance-Use-Paper-Not-Ref
0.3
1
0
Number

INPUTBOX
7
706
124
766
RefRecency-P1
1.3
1
0
Number

INPUTBOX
126
706
249
766
RefRecency-P2
2
1
0
Number

TEXTBOX
8
781
158
799
Contents Parameters:
13
0.0
1

INPUTBOX
126
806
245
866
Chance-Bit-Innovative
0.01
1
0
Number

INPUTBOX
7
805
122
865
Contents-Size
2
1
0
Number

INPUTBOX
7
917
132
977
Interdependencies
5
1
0
Number

BUTTON
754
879
882
912
Sharing an Author
draw-sharing-links
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
500
802
617
835
Hide-clinks
Hide-clinks
0
1
-1000

SWITCH
498
727
616
760
Hide-rlinks
Hide-rlinks
0
1
-1000

BUTTON
500
838
617
871
Cites On/Off
toggle-linkset clinks
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
498
763
616
796
Refers-To On/Off
toggle-linkset rlinks
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
471
898
621
References Per Paper
# References
Frequency
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
902
471
1102
621
Citations Per Paper
# Citations
Frequency
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
1105
471
1305
621
log-log (Citations Per Paper)
log Citations
log Freq.
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

INPUTBOX
129
376
253
436
Auth-Similarity
10
1
0
Number

INPUTBOX
149
644
249
704
Ref-Similarity
10
1
0
Number

TEXTBOX
260
504
410
522
Peer Review Parameters:
13
0.0
1

CHOOSER
257
531
489
576
Selecting-Peer-Reviewers-Method
Selecting-Peer-Reviewers-Method
"From recent paper" "From recent publication" "From recently cited paper" "From recently cited publication" "Any author"
3

INPUTBOX
258
580
372
640
Reviewer-Attempts
20
1
0
Number

INPUTBOX
375
580
490
640
Reviews-Required
3
1
0
Number

INPUTBOX
258
644
372
704
Peer-Similarity
10
1
0
Number

INPUTBOX
258
708
372
768
PeerRecency-P1
1
1
0
Number

INPUTBOX
374
708
492
768
PeerRecency-P2
4
1
0
Number

BUTTON
501
879
618
912
Create Cocitation
draw-cocitation-links
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
501
914
618
947
Hide-cocitlinks
Hide-cocitlinks
0
1
-1000

SWITCH
620
914
771
947
Hide-coauthlinks
Hide-coauthlinks
0
1
-1000

BUTTON
501
950
618
983
Cocitation On/Off
toggle-linkset cocitlinks
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
620
950
761
983
Coauthorship On/Off
toggle-linkset coalinks
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
741
687
881
720
Foundations On/Off
toggle-foundations
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
499
651
615
684
Hide-Papers
Hide-Papers
1
1
-1000

SWITCH
618
651
750
684
Hide-Authors
Hide-Authors
0
1
-1000

BUTTON
497
604
610
637
Spring All Visible
relocate-all-visible-spring
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
501
987
619
1020
Isolates On/Off
toggle-isolates-cocitlinks
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
620
987
738
1020
Isolates On/Off
toggle-isolates-coalinks
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
902
625
1150
775
Fitness
Year
Fitness
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Max" 1.0 0 -13345367 true "" ""
"Mean" 1.0 0 -16777216 true "" ""

BUTTON
145
64
266
97
Print Distributions
print-final-distributions
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
1105
163
1305
313
Years since previous papers
# Years Ago
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1308
163
1508
313
Career Span
Years
Frequency
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
1308
471
1508
621
Citing-Cited Gap
# Years
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1308
317
1508
467
Citations Received
Year
# Received
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

CHOOSER
7
868
145
913
Fitness-Method
Fitness-Method
"Return 1" "2-D Gaussians"
0

PLOT
1154
625
1354
775
% of Papers Accepted
Year
%
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

BUTTON
741
726
882
759
Unpublished On/Off
toggle-set papers with [status < 2]
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
1511
317
1711
467
Authors Per Publication
# Authors
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1511
471
1711
621
References Per Publication
# References
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1714
317
1914
467
Publications Per Author
# Papers
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1714
471
1914
621
Citations Per Publication
# Citations
Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1917
317
2117
467
log-log (Publications Per Author)
log Publications
log Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

PLOT
1917
471
2117
621
log-log (Citations Per Publication)
log Citations
log Frequency
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

MONITOR
699
10
789
63
# Papers
num-papers-to-date
17
1
13

MONITOR
699
65
804
118
# Publications
num-pubs-to-date
17
1
13

MONITOR
809
65
899
118
# Authors
num-authors-to-date
17
1
13

MONITOR
791
10
879
63
Best fitness
max-fitness
3
1
13

INPUTBOX
375
644
491
704
Originality-Distance
1
1
0
Number

@#$#@#$#@
# CITATION AGENTS

## WHAT IS IT?

Citation Agents: A Simulation of Scientific Publication and Collective Searching.  

This version (C) Christopher Watts, 2014. See below for terms and conditions of use.

This program was developed for Watts & Gilbert (2011) and for Chapter 5 of the book:

> Watts, Christopher and Gilbert, Nigel (2014) “Simulating Innovation: Computer-based Tools for Rethinking Innovation”. Cheltenham, UK and Northampton, MA, USA: Edward Elgar.

Simulates the production of academic papers in some scientific field. Papers have contents and a quality or "fitness value", and peer review can lead to some of them becoming journal "publications". Model combines ideas from scientometrics, stochastic process models, science models and simulations of organisational learning.


## HOW IT WORKS

Each time tick, a number of papers are generated. Each paper has authors, references to previous papers (if any), contents, a fitness value for its contents, and peer reviewers.   
For generating authors and references, various methods are available, including sampling from a recent paper or publication, and sampling from the referenced papers in a recent paper or publication.

Each author has beliefs, again with a fitness value.

For generating paper contents, we sample bit strings from either a bernoulli process (representing innovation, information entering from outside the field), or the beliefs of the authors and the contents of reference papers.

Peer reviewers decide whether or not the paper can become a publication. For this they consider its originality, similarity to their own beliefs, and fitness value relative to their own.


## HOW TO USE IT

Click "Setup". Click "Go". Charts will update automatically.

BehaviorSpace contains several experiments generating distributions and fitness performance.

Distributions can be output if the "Print Distributions" button is clicked. These can then be copy-pasted into other programs (e.g. Excel).

A drop-down box determines whether papers' all have the same quality or "fitness value" (equal to 1) or a value derived from their contents as a position on a two-dimensional fitness landscape with gaussian functions providing two "hills". If using the latter, peer review will mean that not all "papers" become "publications". Sampling processes used for generating authors, references and peer reviewers can be based on either "papers" or "publications".

Buttons exist for revealing the papers, authors, and the links between them, and also for creating coauthorship links between authors and cocitation links between papers. By default turtles and their links are hidden when created. Drawing thousands of links takes time - NetLogo may slow down badly. When learning what the "on/off" buttons do, we recommend you start with a small field (# papers < 100). The easiest way to achieve this is probably to reduce the number of time steps.


## THINGS TO NOTICE

Depending on the parameters, you should be able to see:  
exponential growth in the field in terms of numbers of papers and authors;  
scale-free distributions of papers per author and citations per paper.


## THINGS TO TRY

Start with the simple fitness function "Return 1". Using this almost no papers will be rejected for publication. The resulting distributions will probably look very realistic.

Try to fit distributions derived from real bibliometric data - e.g. download from ISI Web of Science. See the paper by Watts & Gilbert for an example.

Then try using the gaussian fitness. Once some papers get rejected for their less-fit contents, the number of journal publications falls. Adjusting the parameters to get realistic distributions may prove difficult.

Experiments:
 
* Explore the sensitivity to the various parameters and options.  
* Find the best balance between exploring and exploiting - i.e. searching widely over the possible contents and searching locally around known contents.


## EXTENDING THE MODEL

* More plausible fitness landscape or method of evaluating papers and beliefs.  
* Better representation of the world outside the journal? (i.e. alternatives to foundational papers; authors and references to papers from outside the journal, or outside the field; more innovation during contents generation)  
* Better representation of peer review processes  
* Constraint networks: limits on who can co-author with whom, and who can cite whom. E.g. geography, language, institution, social networks.


## NETLOGO FEATURES

Simulation model was originally developed over a period of several weeks in Excel 2003 with VBA. The NetLogo version was developed in days, is far shorter, much faster (especially at larger scales), and comes with the ability to visualise networks.


## RELATED MODELS

* Simon (1955) describes how a stochastic process can generate statistical patterns seen in publication data.
* Gilbert's model of Academic Science Structure (Gilbert, 1997)  
* The "Topics, Aging & Recursive Learning" (TARL) model (Boerner et al, 2004)  
* Lazer & Friedman (2007) for a model of collective search, using NK fitness.
* Bentley, Ormerod & Batty (2011) for a method of generating scale-free frequency distributions.


## CREDITS AND REFERENCES

Watts, C., & Gilbert, N. (2011). "Does cumulative advantage affect collective learning in science? An agent-based simulation." Scientometrics, 89(1), 437-463. doi: 10.1007/s11192-011-0432-8

Bentley, R. A., Ormerod, P., & Batty, M. (2011). "Evolving social influence in large populations." Behavioral Ecology and Sociobiology, 65(3), 537-546. doi: 10.1007/s00265-010-1102-1

Boerner, K., Maru, J. T., Goldstone, R. L. (2004) "The simultaneous evolution of author and paper networks". Proceedings of the National Academy of Science USA, 101(suppl. 1), S266-S273.

Gilbert, N. (1997) "A Simulation of the Structure of Academic Science". Sociological Research Online, 2(2)3, http://www.socresonline.org.uk/socresonline/2/2/3.html .

Lazer, D., & Friedman, A. (2007) "The Network Structure of Exploration and Exploitation". Administrative Science Quarterly, 52, 667-694.

Kauffman, S. (1993) "The Origins of Order: Self-Organization and Selection in Evolution". New York: Oxford University Press.

Kauffman, S. (1995) "At Home in the Universe: The Search for Laws of Complexity". London: Penguin.

Price, D. D. S. (1976) "A General Theory of Bibliometric and Other Cumulative Advantage Processes". Journal of the American Society for Information Science, 27(Sep.-Oct.), 292-306.

Simon, H. A. (1955) "On a Class of Skew Distribution Functions". Biometrika, 42(3/4), 425-440.


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
  <experiment name="experiment-SelRef" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>ticks</metric>
    <metric>max-fitness</metric>
    <metric>num-papers-to-date</metric>
    <metric>num-pubs-to-date</metric>
    <metric>num-authors-to-date</metric>
    <metric>array:to-list y-mean-fitness</metric>
    <metric>array:to-list y-max-fitness</metric>
    <metric>array:to-list y-num-papers</metric>
    <metric>array:to-list y-num-pubs</metric>
    <metric>array:to-list y-num-authors</metric>
    <enumeratedValueSet variable="PeerRecency-P2">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Authors-Method">
      <value value="&quot;From recently cited publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Peer-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Peer-Reviewers-Method">
      <value value="&quot;From recent publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Authors">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-New-To-Field">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P1">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Contents-Size">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-rlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Field-Growth">
      <value value="1.067"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-wlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-References-Method">
      <value value="&quot;Recent paper&quot;"/>
      <value value="&quot;Recent publication&quot;"/>
      <value value="&quot;Copy reference in recent paper&quot;"/>
      <value value="&quot;Copy reference in recent publication&quot;"/>
      <value value="&quot;Any past paper&quot;"/>
      <value value="&quot;Any past publication&quot;"/>
      <value value="&quot;Recent and cited paper&quot;"/>
      <value value="&quot;Recent and cited publication&quot;"/>
      <value value="&quot;Paper from recent year&quot;"/>
      <value value="&quot;Publication from recent year&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="First-Year-Papers">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviews-Required">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Time-Steps">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-clinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Papers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P2">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-coauthlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ref-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P2">
      <value value="4.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeerRecency-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-alinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Bit-Innovative">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-cocitlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviewer-Attempts">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interdependencies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Use-Paper-Not-Ref">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fitness-Method">
      <value value="&quot;NK Fitness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Auth-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Foundational-Papers">
      <value value="14"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ReviewsReq" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>ticks</metric>
    <metric>max-fitness</metric>
    <metric>num-papers-to-date</metric>
    <metric>num-pubs-to-date</metric>
    <metric>num-authors-to-date</metric>
    <metric>array:to-list y-mean-fitness</metric>
    <metric>array:to-list y-max-fitness</metric>
    <metric>array:to-list y-num-papers</metric>
    <metric>array:to-list y-num-pubs</metric>
    <metric>array:to-list y-num-authors</metric>
    <enumeratedValueSet variable="PeerRecency-P2">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Authors-Method">
      <value value="&quot;From recently cited publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Peer-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Peer-Reviewers-Method">
      <value value="&quot;From recent publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Authors">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-New-To-Field">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P1">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Contents-Size">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-rlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Field-Growth">
      <value value="1.067"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-wlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-References-Method">
      <value value="&quot;Recent publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="First-Year-Papers">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviews-Required">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Time-Steps">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-clinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Papers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P2">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-coauthlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ref-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P2">
      <value value="4.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeerRecency-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-alinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Bit-Innovative">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-cocitlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviewer-Attempts">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interdependencies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Use-Paper-Not-Ref">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fitness-Method">
      <value value="&quot;NK Fitness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Auth-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Foundational-Papers">
      <value value="14"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-Distributions-NK" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>timer</metric>
    <metric>ticks</metric>
    <metric>num-papers-to-date</metric>
    <metric>num-pubs-to-date</metric>
    <metric>num-authors-to-date</metric>
    <metric>max-fitness</metric>
    <metric>array:to-list y-num-papers</metric>
    <metric>array:to-list y-num-pubs</metric>
    <metric>array:to-list y-num-authors</metric>
    <metric>array:to-list y-cites-frompapers</metric>
    <metric>array:to-list y-cites-frompubs</metric>
    <metric>array:to-list y-mean-fitness</metric>
    <metric>array:to-list y-max-fitness</metric>
    <metric>applist</metric>
    <metric>apjlist</metric>
    <metric>ppalist</metric>
    <metric>jpalist</metric>
    <metric>rpplist</metric>
    <metric>rpjlist</metric>
    <metric>cpplist</metric>
    <metric>jcpjlist</metric>
    <metric>jamlist</metric>
    <metric>jcmlist</metric>
    <enumeratedValueSet variable="Peer-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Interdependencies">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Papers">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Peer-Reviewers-Method">
      <value value="&quot;From recent publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P1">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-References-Method">
      <value value="&quot;Copy reference in recent publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-New-To-Field">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-clinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ref-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Bit-Innovative">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Time-Steps">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviews-Required">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefRecency-P2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P2">
      <value value="4.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthRecency-P1">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RefsPerPaper-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeerRecency-P2">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selecting-Authors-Method">
      <value value="&quot;From recently cited publication&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Contents-Size">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reviewer-Attempts">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fitness-Method">
      <value value="&quot;NK Fitness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-Authors">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-coauthlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-wlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-cocitlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PeerRecency-P1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-rlinks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Field-Growth">
      <value value="1.067"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Chance-Use-Paper-Not-Ref">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="AuthorsPerPaper-P2">
      <value value="1.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Auth-Similarity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="First-Year-Papers">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Foundational-Papers">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hide-alinks">
      <value value="true"/>
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
