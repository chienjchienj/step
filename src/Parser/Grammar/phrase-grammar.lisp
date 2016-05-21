;;;;
;;;; phrase-grammar.lisp
;;;;


(in-package :W)

;; VC verb crossing indicates when there's a verb between a modifier and
;; a head, e.g. will be present in relative clauses like
;; the man driving the truck
;; VC + is added as a default feature for allverbs in *pos-defaults* in LexiconManager/Code/lexicon-DB.lisp

;(parser::define-foot-feature 'VC) ; 2010 -- not currently used

;; dys nil is added as a default feature for all words in *pos-defaults* in LexiconManager/Code/lexicon-DB.lisp
;; for disfluency detection
;(parser::define-foot-feature 'dys) ; 2010 -- not currently used

;; WH is a foot feature: it should not appear in the mother constituent of a rule
(parser::define-foot-feature 'WH)
(parser::define-foot-feature 'WH-VAR)

(parser::set-default-rule-probability .99)

(parser::addLexicalCat 'cv);; contraction
(parser::addLexicalCat '^);; quote
(parser::addLexicalCat '^S)
(parser::addLexicalCat 'adv)
(parser::addLexicalCat 'conj)
(parser::addLexicalCat 'ordinal)
(parser::addLexicalCat 'POSS);; possessive pronoun
(parser::addLexicalCat 'quan);; quantifer
(parser::addLexicalCat '@);; colon
(parser::addLexicalCat 'punc)
(parser::addLexicalCat 'prep)
(parser::addLexicalCat 'neg)



;;  Basic structure of NP rules

;;     NP -> SPEC N1
;;     SPEC -> DET ORDINAL CARDINAL UNIT
;;     N1 -> QUAL* N

;;   SPEC Rulest
;;     This uses a set of features to collect info on spec
;;       SEM - DEFINITE/INDEFINITE/QUANTIFIER
;;       LF - the actual determiner/quantifier
;;       ARG - the placeholder for the object described
;;       RESTR - restrictions on object described, including
;;         (SIZE  N) - cardinality
;;         (SEQUENCE N) - position in sequence (e.g., first, ...)
;;       POSS  - non-null only if possessive determiner, and set to NP that is possessor (at least fro VAR and SEM)

;; Quantifiers appear in different constructions, here's how we tell them apart
;;    Standard Bare forms:  e.g., all boys, each truck, much sand, ...  requires NOSIMPLE -, and AGR and MASS agreement
;;    OF forms: e.g., all of the boys, each of the trucks, much of the sand, ... requires PP SUBCAT agreement
;;    NP forms: e.g., all the trucks, both the trucks, ...   requires NPMOD +
;;    cardinality forms: e.g., the several trucks, the many trucks, and many more, several more,  ...  requires CARDINALITY +
;;    bare constructions: e.g., many arrived yesterday, most died, ... requires NoBareSpec -

(parser::augment-grammar
;;(cl:setq *grammar-SPEC*
      '((headfeatures
	 (DET VAR lex headcat transform)
         (SPEC VAR lex headcat transform SORT POSS)
	 (possessor VAR SEM lex headcat transform)
	 (CARDINALITY lex headcat transform nobarespec qof)
	 (N var mass agr sort lex headcat transform)
	 (NP VAR CASE MASS NAME agr SEM PRO CLASS lex headcat transform postadvbl)
	 (QUANP headcat lex)
	 )

	;;  QUANTIFICATIONS/SPECIFIER STRUCTURE FOR NOUN PHRASES
	
        ;;  DEFINITE/INDEFINITE FORMS
	
	;;  e.g., the, a
	((SPEC (SEM ?def) (AGR ?agr) (MASS ?m) (ARG ?arg) (NObareSpec +)  (lex ?lex) (LF ?l) (restr ?r))
	 -spec-det1> .995
	 (head (DET (sem ?def) (ARG ?arg) (AGR ?agr) (WH -) (MASS ?m) (lex ?lex) (LF ?l) (restr ?r))))


	;;  indefinites allow negation, not a man came

	((SPEC (SEM ?def) (AGR ?agr) (MASS ?m) (ARG ?arg) (NObareSpec +)  (lex ?lex) (LF w::indefinite) (restr ?rr))
	 -spec-det-neg>
	 (word (lex not))
	 (head (DET (sem ?def) (ARG ?arg) (AGR ?agr) (WH -) (MASS ?m) (lex ?lex) (LF w::indefinite) (restr ?r)))
	 (add-to-conjunct (val (negation +)) (old ?r) (new ?rr)))
	
	;; e.g., which, what    -- just like spec-det1> except for adding the wh-var feature
	((SPEC (SEM ?def) (AGR ?agr) (MASS ?m) (ARG ?arg) (NObareSpec +)  (lex ?lex) (LF ?l)
	       (RESTR ?newr) (WH ?!wh) (wh-var ?wh-var))
	 -spec-whdet1>
	 (head (DET (sem ?def) (AGR ?agr) (WH ?!wh) (wh-var ?wh-var)
		    (MASS ?m) (lex ?lex) (poss -) (RESTR ?R) (LF ?l)))
	 (add-to-conjunct (old ?r) (val (PROFORM ?lex)) (new ?newr)))
      
	;; e.g., the first
	((SPEC (SEM ?def) (AGR ?agr) (MASS ?m) (ARG ?arg) (LF ?l) (RESTR ?newr)
	  (SUBCAT (% PP (PTYPE of) (SEM ?anysem))))
	 -spec2>
	 (head (DET (sem ?def) (MASS ?m) (agr ?agr)
		(LF ?l) (RESTR ?R)))
	 (ordinal (LF ?q))
         (add-to-conjunct (val (SEQUENCE ?q)) (old ?r) (new ?newr)))

	;; one
	((SPEC (SEM ?def) (var ?v) (AGR ?agr) (MASS count) (ARG ?arg) (lex ?lex) (LF INDEFINITE) 
	  (subcat ?xx)
	  (RESTR (& (:size (% *PRO* (status indefinite) (class ONT::NUMBER)
					 (constraint ?cc) (var *))))))
	 -spec-one>
	 (head (NUMBER (val 1) (var ?v) (sem ?def) (AGR ?agr) (WH -) (lex ?lex) (RESTR ?R) (LF ?l)))
	 (add-to-conjunct (val (value 1)) (old ?r) (new ?cc))
	 )
	
        ;; e.g., two more, one less, some more, ...
	;; check interpretation?? shouldn't there be an impro -- two more than what?
	;;    this allows MORE or LESS to be attached to cardinality specifiers
	((SPEC (AGR ?agr) (ARG ?arg) (LF ?status) (MASS ?mass)
	       (PRED ?s)
	       (RESTR ?restr1)
	       (SUBCAT (% PP (PTYPE of) (SEM ?subsem)))
	       (QCOMP ?qcomp)
	       (nobarescpec ?nb)
	       )
	 -Spec-comp>  .95 ;; prefer to attach to NP
	 (head (SPEC (AGR ?agr) (ARG ?arg) (LF ?status) (MASS ?mass)
		     (PRED ?s)
		     (RESTR ?restr)
		     (SUBCAT (% PP (PTYPE of) (SEM ?subsem)))
		     (QCOMP -) (nobarescpec ?nb)))
	 (QUAN (COMPARATIVE +) (VAR ?av) (LF ?cmp) (QCOMP ?qcomp))
	 (add-to-conjunct (val (quan ?cmp))
			  (old ?restr) (new ?restr1)))

#||	 ;; e.g.,  some more (water), some more of the water
	;;    this allows MORE or LESS to be attached to cardinality specifiers on MASS terms
	((SPEC (AGR ?agr) (ARG ?arg) (LF ?status) (MASS MASS)
	       (PRED ?s)
	       (RESTR ?restr1)
	       (SUBCAT (% PP (PTYPE of) (SEM ?subsem)))
	       (QCOMP ?qcomp)
	       (nobarescpec ?nb)
	       )
	 -Spec-comp-mass>  .92 ;; prefer to attach to NP
	 (head (SPEC (ARG ?arg) (LF ?status) (MASS MASS)
		     (PRED ?s)
		     ;;(RESTR (& (QUAN ?!q)))
		     (restr ?restr)
		     ;;(SUBCAT (% PP (PTYPE of) (SEM ?subsem)))
		     (QCOMP -) (nobarescpec ?nb)))
	 (QUAN (COMPARATIVE +) (VAR ?av) (LF ?cmp) (QCOMP ?qcomp))
	 (add-to-conjunct (val (quan ?cmp))
			  (old ?restr) (new ?restr1)))||#

	;;  DETERMINERS:  articles, possessives, quantifiers

	;; e.g., the
	((DET (SEM ?def) (AGR ?a) (ARG ?arg) (MASS ?m) (LF ?l))
	 -det1> 1.0
	 (head (art (sem ?def) (DIECTIC -) (MASS ?m) (AGR ?a) (LF ?l))))

        ;; e.g., that, this, ...
	((DET (SEM ?def) (AGR ?a) (ARG ?arg) (MASS ?m) (LF ?l) (RESTR (& (PROFORM ?lex))))
	 -det-diectic> 1.0
	 (head (art (sem ?def) (DIECTIC +) (MASS ?m) (lex ?lex) (AGR ?a) (LF ?l))))
	
	;;  Possessive times
	;; e.g., today's/monday's weather report
	((DET (LF DEFINITE) (AGR ?agr) (ARG ?arg) (MASS ?m) (RESTR (& (assoc-with ?v)))
               (NObareSpec +))
	 -possessive1-time> 1.0
	 (head (NP (SEM ?sem) (VAR ?v) (sort pp-word))) (^S))

	;; possessives become determiners - we use an intermediate constit POSSESSOR to allow the modifier "own", as in "his own truck"
	((DET (LF DEFINITE) (AGR ?agr) (wh-var ?wh-var) (ARG ?arg) (mass ?m) (poss ?v) (restr ?r)
               (NObareSpec +))
	 -possessor1>
	 (head (Possessor  (AGR ?agr)  (wh-var ?wh-var) (ARG ?arg) (mass ?m) (poss ?v) (restr ?r))))

	;;  possessive OWN construction. e.g., his own truck, john's very own house
	((Possessor  (AGR ?agr) (ARG ?arg) (mass ?m) 
	  (restr ?newr) (own +))  ;; no-bare-spec is not + to allow "his own"
	 -possessor2>
	 (head (Possessor  (AGR ?agr) (ARG ?arg) (mass ?m) (poss ?poss) (restr ?r) (own -)))
	 (adjp (lex W::own) (lf ?lf) (arg ?arg) (var ?av))
	 (add-to-conjunct (val (:mod ?av));;(% *PRO* (STATUS F) (CLASS ?lf) (VAR ?av) 
				;;	(CONSTRAINT (& (?subj ?poss) (?dobj ?arg))))))
	  (old ?r) (new ?newr)))
	
	;;  Possessive constructs: two versions of each rule, one as possessor, and other as argument to a relational noun
	;; e.g., the man's book
	;; Myrosia added a restriction (sort pred) to prevent wh-desc prhases appearing in this rule
	((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (MASS ?m) (RESTR (& (assoc-poss ?v)))
               (NObareSpec +))
	 -possessive1> 
	 (head (NP (PRO (? xx - INDEF)) (gerund -) (generated -) (time-converted -) (SEM ?sem) (VAR ?v) (sort pred))) (^S))


	
;;    DELETING THE RELN POSS rules - we will do this as an infrerence process in the IM
#||	;; possessor of a relational noun e.g. the man's hand
	;; Myrosia added a restriction (sort pred) to prevent wh-desc prhases appearing in this rule
        ((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (mass ?m) (poss ?v) (restr ?r)
               (NObareSpec +))
	 -possessive1reln>
	 (head (NP (PRO -) (SEM ?sem)  (VAR ?v) (sort pred) (restr ?r) (postadvbl -))) (^S))
||#	
	;;  e.g., the engines' problems
	;; Myrosia added a restriction (sort pred) to prevent wh-desc prhases appearing in this rule
	((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (MASS ?m) (RESTR (& (assoc-poss ?v)))
               (NObareSpec +))
	 -possessive2>
	 (head (NP (PRO -) (SEM ?sem) (VAR ?v) (agr 3p) (gerund -) (name -) (sort pred))) (^))
#||
	;; plural possessor of relational noun - the engines' wheels
	;; Myrosia added a restriction (sort pred) to prevent wh-desc prhases appearing in this rule
        ((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (POSS (% NP (VAR ?v) (SEM ?sem)))
               (NObareSpec +))
	 -possessive2reln>
	 (head (NP (PRO -) (SEM ?sem) (VAR ?v) (sort pred))) (^))
||#	
	;;   e.g., his book
	;; Myrosia 2003/11/04 changed NP to PRO. Genitives are covered by possessive1 and possessive2 rules
	;; so this should only be pronouns
	((possessor (LF DEFINITE) (AGR ?agr) (WH-VAR ?arg) (MASS ?m) (ARG ?arg1)
	      (RESTR (& (assoc-poss ?arg)))(WH R)
			 ;;(% *PRO* (VAR ?v) (SEM ?sem)
			 ;;(STATUS PRO) (class ?lf) (constraint (& (proform ?lex)))))))
	      (NObareSpec +))	 
	 -possessive3-whose-rel-clause>
	 (head (PRO (CASE POSS) (WH R) 
		    (STATUS PRO-DET) (SEM ?sem) (VAR ?v) (LF ?lf) (lex ?lex) (input ?i))))

	((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (MASS ?m)
	  (RESTR (& (assoc-poss
		     (% *PRO* (VAR ?v) (SEM ?sem)
			(STATUS PRO) (class ?lf) (constraint (& (proform ?lex)))))))
	  (NObareSpec +) (WH (? wh Q -)) (wh-var ?v))	 
	 -possessive3>
	 (head (PRO (CASE POSS) (WH (? wh Q -))
		    (STATUS PRO-DET) (SEM ?sem) (VAR ?v) (LF ?lf) (lex ?lex) (input ?i))))
#||
	((possessor (LF DEFINITE) (AGR ?agr) (ARG ?arg) (mass ?m)
	      (POSS (% *PRO* (VAR ?v) (SEM ?sem)(STATUS PRO) (class ?lf) (constraint (& (proform ?lex)))))
              (NObareSpec +))
         possessive3reln>
	 (head (PRO (CASE POSS) (SEM ?sem) (VAR ?v) (LF ?lf) (LEX ?lex) (input ?i))))
||#
	;;  thirty first, twenty fourth, etc
	((ORDINAL (LF (nth ?newval)) (NTYPE ?ntype) (AGR ?agr) (headcat ordinal) (var ?v) (complex +) (mass count))
	 -ordinal>
	 (NUMBER (VAL ?num) (var ?v))
	 (ORDINAL  (LF (NTH ?lastdigit)) (complex -))
	 (compute-val-and-ntype (expr (+ ?num ?lastdigit)) (newval ?newval) (ntype ?ntype)))

	;;  ORDINAL PHRASES  (e.g., 1st, 2nd, ...)
	((ORDINAL (LF (nth ?digit)) (NTYPE ?ntype) (AGR ?agr) (headcat ordinal) (var ?v) (mass count))
	 -ordinal1>
	 (NUMBER (NTYPE ?ntype) (VAL ?digit) (var ?v))
	 (Punc (lex W::punc-ordinal)))
        ;;  phrases that indicate CARDINALITY
	
	;;  e.g., seven trucks (this is now handled by n1-qual-set1)
	;; but this rule is still used in constructions like "3 mile wide river" (now number processed directly in adj-unit-modifier>)
	;; -- 8/27/08 no longer used, commenting out
;	((CARDINALITY
;	  (LF (% DESCRIPTION (VAR ?v) (STATUS QUANTITY-TERM) (CLASS ONT::NUMBER) (constraint ?con))) ;(CONSTRAINT (& (VALUE ?c)))))
;	  (VAR ?v)
;	  (AGR ?a) (STATUS INDEFINITE) (mass (? mass count bare))
;;	  ;; allow this to get 'greater than 5'
;;	  (nobarespec +) ;; disallow bare numbers interpreted as bare specifiers 
;	  )
;	 -cardinality1> 
;	 (head (NUMBER (val ?c) (VAR ?v) (AGR ?a) (restr ?r)))
;	 (add-to-conjunct (val (:value ?c)) (old ?r) (new ?con))
;	 )

        ;;  e.g.,  needed for phrases like (the) many (trucks), few, several
	;; NB "few/many dogs arrived" goes through -QUAN-CARD-SIMPLE-SPEC> but the few/many dogs arrived uses this rule
        
	((ADJP (ARG ?arg) (ARGUMENT (% NP))
	  (AGR ?a) (sort pred) (VAR ?v) (sem ?sem) (atype w::central) (comparative -) (set-modifier +) 
	  (LF (% DESCRIPTION (STATUS indefinite) (var ?v) (CLASS ONT::NUMBER) (constraint (& (:value ?c)))))
	  (post-subcat -)
	  )
         -cardinality2>
         (head (quan (CARDINALITY +) (VAR ?v) (LF ?c) (mass (? mass count bare)) (STATUS ?status) (AGR ?a)))
	 )

	((ADJP (ARG ?arg) (ARGUMENT (% NP))
	  (AGR ?a)
	  (sort pred) (VAR ?v) (sem ?sem) (atype w::central) (comparative -) (set-modifier +) 
	  (LF (% DESCRIPTION (STATUS indefinite) (var ?v) (CLASS ONT::NUMBER) (constraint ?newc)))
	  (post-subcat -)
	  )
	 -card-number>
	 (head (NUMBER (val ?c) (lf ?lf) (VAR ?v) (AGR ?a) (restr ?r) (sem ?sem))) ;;(ntype !negative)))
	 ;;(GT (arg1 ?c) (arg2 -1)) ;; negative numbers can't be cardinalities  -- I removed this as it caused "under 500 trucks" to fail
	 (add-to-conjunct (val (:value ?c)) (old ?r) (new ?newc))
	 )

        ;;  We need special treatment of number units, as they act like numbers sometimes, as in "the hundred trucks",
        ;;   but note we can't say *hundred trucks and can say "a hundred trucks", "many hundred trucks", "hundreds of trucks"
        ;;   none of which is OK for numbers like seven

        ;;  e.g., many thousand, a few hundred
        ((CARDINALITY (LF (% DESCRIPTION (VAR ?v) (STATUS indefinite) (CLASS ?unit) (CONSTRAINT (& (AMOUNT ?c)))))
		      (AGR 3p) (STATUS ?status) (VAR ?v)
	              (mass (? mass count bare))
	              )
         -cardinality-quan-number-units1>
	 (quan (CARDINALITY +) (VAR ?qv) (LF ?c) (STATUS ?status) (AGR ?a))
	 (head (NUMBER-UNIT (lf ?unit) (AGR 3s) (var ?v)))
         )
	
	 ;;  e.g., a thousand, the hundred, ...
	;;  This produces a QUANP rather than CARDINALITY since we need to pass up the determiner
	
        ((QUANP (LF (% DESCRIPTION (VAR ?v) (STATUS indefinite) (CLASS ?unit)
		       (CONSTRAINT (& (QUAN (% *PRO* (VAR *) (CLASS ONT::NUMBER)
					       (STATUS indefinite) (CONSTRAINT (& (AMOUNT 1)))))))))
		(AGR 3p) (STATUS ?l)
		(mass (? mass count bare))
		(VAR ?v)
		)
         -cardinality-quan-number-units2>
	 (det (sem ?def) (AGR 3s) (LF ?l)) 
         (head (NUMBER-UNIT (lf ?unit) (AGR 3s) (var ?v)))
         )
 
        ;; Number units may also form cardinality experssions in their bare form, but this
        ;;   cannot become a quantifier (e.g., we can't say *hundred trucks)
        ;;  e.g., (a) hundred, (the first) dozen, ...
	
        ((CARDINALITY (LF (% DESCRIPTION (VAR ?v) (STATUS indefinite) (CLASS ?unit) (CONSTRAINT (& (VALUE ?c)))))
		      (VAR ?v) (NOQUAN +)
                      (AGR ?a) (STATUS ?status) (mass (? mass count bare))		   
	              )
         -cardinality-number-unit>
          (head (NUMBER-UNIT (lf ?unit) (AGR 3s) (val ?c) (var ?v)))
         )

	;;  we need numbers as cardinality to handle headless constructions such as "the three in the corner"
	((CARDINALITY (LF (% DESCRIPTION (VAR ?v) (STATUS indefinite) (CLASS ?unit) 
			     (CONSTRAINT ?new)))
		      (VAR ?v) (NOQUAN +)
                      (AGR ?a) (STATUS ?status) (mass (? mass count bare))		   
	              )
         -cardinality-number> .97
          (head (NUMBER (lf ?unit) (AGR ?a) (val ?c) (var ?v) (restr ?restr)))
	 (add-to-conjunct  (val (value ?c)) (old ?restr) (new ?new))
         )


	;; special construction: hundreds, dozens, ...  - doesn't allow *hundreds trucks
        
        #||((QUANP (NOSIMPLE +)   ;; not needed anymore, subsumed by -quan-cardinality>
		(ARG ?arg) (AGR 3p) 
               (VAR (% *PRO* (VAR ?v) (STATUS indefinite) (CLASS ?unit) (CONSTRAINT (& (quan PLURAL)))))
               (MASS (? mss count bare)) (STATUS INDEFINITE) (qof ?qof)
	       (nobarespec +)
	       )
         -quan-number-unit-plur>
         (head (NUMBER-UNIT (lf ?unit) (val ?c) (AGR 3p) (var ?v) (qof ?qof)))
         )||#
        
        ;;  e.g., many thousands (of dogs)
        ((QUANP (NOSIMPLE ?ns) (status  indefinite-plural) (qof ?qof) (ARG ?arg)
	  (var ?v) (agr ?a) (mass ?m))
	 -quan-cardinality
	 (head (Cardinality (nosimple ?ns) (var ?v) (agr ?a) (mass ?m))))

	;; many thousands
	((CARDINALITY (NOSIMPLE +)
                      (VAR (% *PRO* (VAR ?v) (STATUS indefinite-plural) (CLASS ?unit)
			     (CONSTRAINT (& (QUAN ?c)))))
		      (AGR ?a) (STATUS ?status)
	              (mass (? mss count bare))
		      )
         -cardinality-quan-number-units-plur>
         (QUAN (CARDINALITY +) (LF ?c) (STATUS ?status) (VAR ?qv) (AGR ?a))
         (head (NUMBER-UNIT (lf ?unit) (var ?v) (qof ?qof)))
         )
    
	))
;;;

;; headfeatures
;; mass -- can be mass, count or bare
;; qual -- + if qualifier is present, e.g. the RED train
;; changeagr -- looks like this isn't used anywhere
;; roles -- thematic role mappings from LF. No longer used?
;; quantity -- used for commodities

(parser::augment-grammar
 '((headfeatures
    ;; (N1 VAR arg AGR MASS CASE SEM Changeagr lex quantity subcat transform)
    (N1 var arg lex headcat transform agr mass case sem quantity argument indef-only subcat-map refl abbrev gerund nomsubjpreps nomobjpreps dobj-map dobj subj-map generated)
    (N var arg lex headcat transform agr mass case sem quantity argument indef-only subcat-map refl abbrev gerund nomsubjpreps nomobjpreps dobj-map dobj subj-map generated)  ; this is a copy of N1 so -N-prefix> would pass on the features
    (UNITMOD var arg lex headcat transform agr mass case sem quantity subcat argument indef-only)
    (QUAL var arg lex headcat transform ARGUMENT COMPLEX)
    ;; MD 18/04/2008 added SEM as a headfeature to handle "in full" where in subcategorizes for adjp
    ;; Other option might be to subcategorize for adj - need to consider in the future
    (ADJP arg lex headcat transform argument sem) ;; post-subcat)     
    )
   
   ;; common nouns without modifiers, e.g. boxcar, juice, trains
   ((N1 (SORT (? sort PRED UNIT-MEASURE)) (CLASS ?lf) (name-or-bare +)
     (POSTADVBL -) (QUAL -) (RESTR ?r) (subcat ?subcat) (simple +))
    -N1_1>
    (head (n (SORT (? sort PRED UNIT-MEASURE)) (LF ?lf) (RESTR ?r) (punc -) 
	     (subj-map -)   ;; we have a separate rule for nominalizations
	     (subcat ?subcat) (SEM ($ ?type (f::scale ?sc)))
	   )
     ))


   ;; special rule for NOUN prefixes that act as adjectives
   ((N (RESTR  ?con)
       (LF ?lf) ;(CLASS ?lf)
       (SORT ?sort) (QUAL +)
	(relc -) ;(relc ?relc)
	(sem ?nsem) (subcat ?subcat) (SET-RESTR ?sr)
	(comparative ?com)
	(complex -) ;(complex ?cmpl)
	(post-subcat -) (gap ?gap)
	    (dobj ?dobj)
	    (subj ?subj)
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map ?dobjmap)  
	    (comp3-map ?comp-map)
     )
    -N-prefix-hyphen> 1.01
    (ADJ (prefix +)
     (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
     (argument (% NP (sem ?argsem))) 
     (COMPLEX -) (comparative ?com) (Set-modifier -)
     (post-subcat -)
     )
    (word (lex w::punc-minus))
    (head (N (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (SET-RESTR ?sr) (gap ?gap)
	      (SORT ?sort) (relc -) ;;(relc ?relc) "-" to avoid the ambiguity "the [[red book] which I saw]" "the [red [book which I saw]]"  
	      (subcat ?subcat) (complex -) (lf ?lf)
	      (post-subcat -)
	      (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    (dobj ?dobj)   ; for nominalizations
	    (subj ?subj)
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map ?dobjmap)  
	    (comp3-map ?comp-map)
	      
	      )
     )
    (unify (value ?nsem) (pattern ?argsem))  ;; we're doing it this way so we pass up all the sem features
    (add-to-conjunct (val (:MOD (% *PRO* (status F) (class ?qual)
				   (var *) (constraint (& (of ?v)))))) (old ?r) (new ?con)))

   ((N (RESTR  ?con)
       (LF ?lf) ;(CLASS ?lf)
       (SORT ?sort) (QUAL +)
	(relc -) ;(relc ?relc)
	(sem ?nsem) (subcat ?subcat) (SET-RESTR ?sr)
	(comparative ?com)
	(complex -) ;(complex ?cmpl)
	(post-subcat -) (gap ?gap)
	    (dobj ?dobj)
	    (subj ?subj)
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map ?dobjmap)  
	    (comp3-map ?comp-map)
     )
    -N-prefix> 1.01
    (ADJ (prefix +)
     (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
     (argument (% NP (sem ?argsem))) 
     (COMPLEX -) (comparative ?com) (Set-modifier -)
     (post-subcat -)
     )
    (head (N (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (SET-RESTR ?sr) (gap ?gap)
	      (SORT ?sort) (relc -) ;;(relc ?relc) "-" to avoid the ambiguity "the [[red book] which I saw]" "the [red [book which I saw]]"  
	      (subcat ?subcat) (complex -) (lf ?lf)
	      (post-subcat -)
	      (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    (dobj ?dobj)   ; for nominalizations
	    (subj ?subj)
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map ?dobjmap)  
	    (comp3-map ?comp-map)
	      
	      )
     )
    (unify (value ?nsem) (pattern ?argsem))  ;; we're doing it this way so we pass up all the sem features
    (add-to-conjunct (val (:MOD (% *PRO* (status F) (class ?qual)
				   (var *) (constraint (& (of ?v)))))) (old ?r) (new ?con)))
   
   
   ;; special construction, a noun with a name
   ((N1 (CLASS ?lf) (sort PRED)
     (POSTADVBL -) (QUAL -) (RESTR ?newr) (subcat ?subcat)) 
    -N1_string>
    (head (n1 (SORT PRED) (CLASS ?lf) (RESTR ?r)
	   (subcat ?subcat) (complex -)
	   )
     )
    (name (lex ?val) (STRING +)) ;; maybe could relax this to be any name, not necessarily a string???  JFA 2/08    
    (add-to-conjunct (val (:name-of (?val))) (old ?r) (new ?newr)))
   
   ;; relational nouns without filled PP-of    
   ;; e.g., the brother, the hand, the side
   ;; Takes a RELN and puts in a dummy arg to make it a pred on
   ;; a value: e.g., distance -> (Distance <of something> ?arg)) 
   ;; uses special structure *PRO* for the implicit arg
   ;; NOTE: it is crucial to have (SUBCAT -) there, or the N1 will never undergo n-n modification!
   
   ((N1 (sort pred) (class ?lf) (var ?v)
     ;; (restr (& (?smap (% *PRO* (var *) (sem ?argsem) (constraint (& (ROLE-VALUE-OF ?v) (fills-ROLE ?lf)))))))  ;; to be done in IM now
      (RESTR (& (scale ?sc)))
     (qual -) (postadvbl -) (subcat -)
     )
    -N1-reln1> ;;.98 ;; prefer attaching complement
    (head (n  (sort reln) (lf ?lf) (allow-deleted-comp +)
	   (sem ?ssem)  (SEM ($ ?type (f::scale ?sc)))
	   (subcat (% ?argcat (sem ?argsem)))
	   (subcat-map ?smap)
	   (subcat-map (? !smap ont::val)) ;; disallow ont::val here
	   ))
    )

    ;; relational nouns with filled PP-of complements  e.g., distance of the route
    ;; but this is not for e.g., distance of 5 miles -- filled pp-of unit measures should go through n1-reln4
    ;; NOTE: it is crucial to have (SUBCAT -) there, or the N1 will never undergo n-n modification!
    ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?smap ?v1) (scale ?sc))) (gap ?gap)
      (subcat -)
      )
     -N1-reln3>
     (head (n (sort reln) (lf ?lf)
	      (subcat ?!subcat)
	      (subcat (% ?scat (var ?v1) (sem ?ssem) (lf ?lf2) (gap ?gap) )) ;;(sort (? srt pred individual set comparative reln))))
	      (SEM ($ ?type (f::scale ?sc)))
	      (subcat-map ?smap)))
     ?!subcat
     )
  
   ;; there are a few relational nouns with two complements  e.g., ratio of the length to the height
   ;; the intersection of acorn with booth
    ;; but this is not for e.g., distance of 5 miles -- filled pp-of unit measures should go through n1-reln4
    ;; NOTE: it is crucial to have (SUBCAT -) there, or the N1 will never undergo n-n modification!
    ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?smap ?v1) (?smap2 ?v2) (scale ?sc)))
      (subcat -)
      )
     -N1-reln-two-subcat>
     (head (n (sort reln) (lf ?lf)
	      (subcat ?!subcat)
	      (subcat (% ?scat (var ?v1) (sem ?ssem) (lf ?lf2) (sort (? srt pred individual set comparative reln))))
	      (SEM ($ ?type (f::scale ?sc)))
	      (subcat2 ?!subcat2)
	      (subcat2 (% ?scat2 (var ?v2) (sem ?ssem2) (lf ?lf3) (sort (? srt2 pred individual set comparative reln))))
	      (subcat-map ?smap)
	      (subcat2-map ?smap2)))
     ?!subcat
     ?!subcat2
     )

   ;;  alternate construction, e.g., the GTP GTD ratio, the acorn booth intersection
   ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?smap ?v1) (?smap2 ?v2) (scale ?sc)))
      (subcat -)
      )
     -N1-reln-two-subcat-alt> 
    (np (var ?v1) (sem ?ssem) (lf ?lf2))
    (np (var ?v2) (sem ?ssem2) (lf ?lf3))
    (head (n (sort reln) (lf ?lf)
	     (subcat ?!subcat)
	     (subcat (% ?scat (var ?v1) (sem ?ssem) (lf ?lf2) (sort (? srt pred individual set comparative reln))))
	     (SEM ($ ?type (f::scale ?sc)))
	     (subcat2 ?!subcat2)
	     (subcat2 (% ?scat2 (var ?v2) (sem ?ssem2) (lf ?lf3) (sort (? srt2 pred individual set comparative reln))))
	     (subcat-map ?smap)
	     (subcat2-map ?smap2)))
    )
    
  ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?smap ?v1) (?smap2 ?v2) (scale ?sc)))
      (subcat -)
      )
     -N1-reln-two-subcat-colon-dash> 1
    (np (var ?v1) (sem ?ssem) (lf ?lf2))
    (word (punc (? x w::punc-minus w::punc-colon w::punc-slash))) 
    (np (var ?v2) (sem ?ssem2) (lf ?lf3))
    (head (n (sort reln) (lf ?lf)
	     (subcat ?!subcat)
	     (subcat (% ?scat (var ?v1) (sem ?ssem) (lf ?lf2) (sort (? srt pred individual set comparative reln))))
	     (SEM ($ ?type (f::scale ?sc)))
	     (subcat2 ?!subcat2)
	     (subcat2 (% ?scat2 (var ?v2) (sem ?ssem2) (lf ?lf3) (sort (? srt2 pred individual set comparative reln))))
	     (subcat-map ?smap)
	     (subcat2-map ?smap2)))
 )
    ;; simple qualifier modifiers
    ;; TEST: orange dog, the orange dogs
    ((N1 (RESTR  ?con) (CLASS ?c) (SORT ?sort) (QUAL +) (relc ?relc) (sem ?nsem) (subcat ?subcat) (SET-RESTR ?sr)
      (comparative ?com) (complex ?cmpl) (post-subcat -) (gap ?gap)
      )
     -N1-qual1>
     (ADJP (atype (? at attributive-only central ))
      (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
      (argument (% NP (sem ?argsem))) 
      (COMPLEX -) (comparative ?com) (Set-modifier -)
      (post-subcat -)
      )
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (SET-RESTR ?sr) (gap ?gap)
	    (SORT ?sort) (relc -) ;;(relc ?relc) "-" to avoid the ambiguity "the [[red book] which I saw]" "the [red [book which I saw]]"  
	    (subcat ?subcat) (complex ?cmpl)
	    (post-subcat -)
	    (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    )
      )
     (unify (value ?nsem) (pattern ?argsem))  ;; we're doing it this way so we pass up all the sem features
     (add-to-conjunct (val (:MODS ?adjv)) (old ?r) (new ?con)))

    ((N1 (RESTR  ?con) (CLASS ?c) (SORT ?sort) (QUAL +) (relc ?relc) (sem ?nsem) (subcat ?subcat) (SET-RESTR ?sr)
      (comparative ?com) (complex ?cmpl) (post-subcat -) (gap ?gap)
      )
     -N1-qual1-hyphen> 1
     (ADJP (atype (? at attributive-only central )) (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
      (argument (% NP ));;(sem ?nsem))) 
      (COMPLEX -) (comparative ?com) (Set-modifier -)
      (post-subcat -)
      )
     (word (lex w::punc-minus))
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (SET-RESTR ?sr) (gap ?gap)
	    (SORT ?sort) (relc -) 
	    (subcat ?subcat) (complex -)
	    (post-subcat -)
	    (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    )
      )
     (add-to-conjunct (val (:MODS ?adjv)) (old ?r) (new ?con)))

    ;; allow modification of measure terms with physical modifiers as long as the scales match. The sems will be different; keep the head sem
    ;; short distance; heavy weight; hot temperature
      ((N1 (RESTR  ?con) (CLASS ?c) (SORT ?sort) (QUAL +) (relc ?relc) (sem ?nsem) (subcat ?subcat)(SET-RESTR ?sr)
      (comparative ?com) (complex ?cmpl) (post-subcat -)
      )
     -N1-measure-term-qual> .97
     (ADJP (atype (? at attributive-only central )) (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
      (argument (% NP (sem ?nsem1))) (COMPLEX -) (comparative ?com) (Set-modifier -)
      (sem ($ F::ABSTR-OBJ (F::scale ?!sc)))
      (post-subcat -)
      )
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (SET-RESTR ?sr)
	       (sem ($ F::ABSTR-OBJ (F::scale ?!sc)))
	    (SORT ?sort) (relc -) ;; "-" to avoid the ambiguity "the [[red book] which I saw]" "the [red [book which I saw]]"  
	    (subcat ?subcat) (complex ?cmpl)
	    (post-subcat -)
	    (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    )
      )
     (add-to-conjunct (val (:MODS ?adjv)) (old ?r) (new ?con)))

 ;; TEST: five trains
    ;; does this replace the cardinality1> rule?
    ((N1 (RESTR  ?newr) (CLASS ?c) (SORT PRED) (QUAL +) (relc ?relc) (sem ?nsem) (subcat ?subcat)
      (comparative ?com) (complex ?cmpl) (post-subcat -)
      )
     -N1-qual-set1>
     (ADJP (atype (? at attributive-only central )) (LF ?qual) (ARG ?v) (VAR ?adjv) (WH -)
      (argument (% NP (sem ?nsem))) (COMPLEX -) (comparative ?com) (Set-modifier +) (agr ?agr)
      (post-subcat -)
      )
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c) (agr ?agr)
	    (SORT PRED) (relc -) ;;(relc ?relc) "-" to avoid the ambiguity "the [[red book] which I saw]" "the [red [book which I saw]]"  
	    (subcat ?subcat) (complex ?cmpl)
	    (post-subcat -)
	    (PRO -) (postadvbl -) ;; to avoid the ambiguity "the [[red truck] at Avon]" "the [red [truck at Avon]]"
	    )
      )
     (add-to-conjunct (val (:size ?adjv)) (old ?r) (new ?newr))
    )

    ;; nouns with modifiers that come after 
    ;; "Let me see the trucks available [to me]"
    ;; Myrosia 2005/06/13 restricted relc and postadvbl to avoid "the trucks in rochester available"
    ((N1 (RESTR ?con) (CLASS ?c) (SORT ?sort) (QUAL -) (COMPLEX +) (set-restr ?sr)
      (relc -) (subcat ?subcat) (gap ?gap)
      )
     -N1-post-adj>
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?s) (CLASS ?c) (SORT ?sort) (set-restr ?sr)
	    (relc -) (postadvbl -) (subcat ?subcat) (post-subcat -)
	    ))
     (ADJP (LF ?qual) (ATYPE POSTPOSITIVE) ;;(COMPLEX +) removed because it blocks adj w/ no subcat
	   (ARG ?v) (gap ?gap)
	   (VAR ?m) 
	   (argument (% NP (sem ?s)))
	   (post-subcat -)
	   )
     (add-to-conjunct (val (:MODS ?m)) (old ?r) (new ?con)))

;;;    ;; Split phrases like "the same reading as in 3"
;;;    ((N1 (RESTR ?con) (CLASS ?c) (SORT ?sort) (QUAL -) (COMPLEX +)
;;;      (relc ?relc) (subcat ?subcat)
;;;      )
;;;     -N1-post-subcat>
;;;     (ADJP (atype (? at attributive-only central)) 
;;;      (LF ?qual) 
;;;      (ARG ?v) (VAR ?adjv)
;;;      (argument (% NP (sem ?nsem))) 
;;;      (COMPLEX -) (comparative ?com)
;;;      (post-subcat ?!post-subcat)
;;;      (psarg ?psvar)
;;;      (post-subcat (% ?xxx (var ?psvar) (gap -)))
;;;      )
;;;     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c)
;;;	    (SORT ?sort) (relc ?relc) (subcat ?subcat) 
;;;	    (post-subcat -)
;;;	    )
;;;      )
;;;     ?!post-subcat
;;;     (UNIFY (arg1 (% ?xxx (var ?psvar))) (arg2 ?!post-subcat))
;;;     (add-to-conjunct (val (:MODS ?adjv)) (old ?r) (new ?con)))



    
 
    ;; A few adjectives can have their subcat after the head noun, e.e., "the same ideas as me", "a faster car than that"
     ((N1 (RESTR ?con) (CLASS ?c) (SORT ?sort) (QUAL -) (COMPLEX +)(set-restr ?sr)
       (relc ?relc) (subcat ?subcat)
       (post-subcat +)
       (no-postmodifiers +) ;; add an extra feature to say "no further postmodifiers". If we say "The bulb in 1 is in the same path as the battery in 1", we don't want "in 1" to attach to "the path"
      )
     -N1-post-subcat>
     (ADJP (atype (? at attributive-only central)) 
      (LF ?qual) 
      (ARG ?v) (VAR ?adjv)
      (argument (% NP (sem ?nsem))) 
      (COMPLEX -) (comparative ?com)
      ;;(post-subcat ?!post-subcat)
      (psarg ?psvar)
      (post-subcat ?!psct)  ;; just to make sure its not empty
      (post-subcat (% PP (var ?psvar) (ptype ?ptype) (gap -) (sem ?pssem)
		      ))
      )
     (head (N1 (RESTR ?r) (VAR ?v) (SEM ?nsem) (CLASS ?c)(set-restr ?sr)
	    (SORT ?sort) (relc ?relc) (subcat ?subcat) 
	    (post-subcat -)
	    )
      )
      (PP (ptype ?ptype) (var ?psvar) (gap -) (sem ?pssem))
      ;; ?!psct
     ;;(UNIFY (arg1 (% ?xxx (var ?psvar))) (arg2 ?!post-subcat))
     (add-to-conjunct (val (:MODS ?adjv)) (old ?r) (new ?con)))
    
    
    ;; 500 mb or greater
    ;; note that this rule doesn't handle -500 mb of ram or greater; -a 500 mb ram or greater
    ;; note also that there is a similar rule in adverbial-grammar.lisp for NP or adv-er
    ((NP (var ?v1) (spec ?spec)
      (LF (% description (status W::indefinite) (var ?v1) (sort W::unit-measure)
			 (class ?class) (sem ?lfsem)
			 (argument ?ag)
			 (constraint  ?new)))
         (sort ?st)  (case ?case) (class ?class) (wh ?w)
	 (sem ?sem)
	 )
     -adj-or-comparative> 
     (head (NP (VAR ?v1) (lex ?nlex)
               (sort ?st)  (case ?case)
	       (SEM ?sem) (spec ?spec) (wh ?w)
	       (LF (% description (status w::indefinite) (sort W::UNIT-measure)
		      (sem ?lfsem) (argument ?ag) (class ?class) (constraint  ?restr)))
	       )
           )
     (word (lex or))
     (adjp (comparative +) (var ?av) (post-subcat -)
      )
     (add-to-conjunct (val (& (MODS ?av))) (old ?restr) (new ?new))
     )
    
    ;; nouns with a subcat
    ;; e.g.  trucks of oranges
    ((N1 (RESTR (& (?!subcatmap ?v1))) (SORT ?sort) (COMPLEX ?complex)
      (CLASS ?LF) (GAP ?gap) (POSTADVBL -) (QUAL -) (ARGUMENT-MAP ?am)
      (subcat -)
      )
     -N1-subcat1>
     (Head (N (VAR ?v) (lf ?LF)
	    (SORT ?sort) (ARGUMENT-MAP ?am)
	    (SUBCAT ?!subcat) 
	    (subcat-map ?!subcatmap)
	    (SUBCAT (% ?xx (var ?v1) (gap ?gap) (sem ?subcatsem) (postadvbl -)))
	    	    
	    ))
     ?!subcat
     (compute-complex (arg0 ?v1) (arg1 ?complex))
     )

    ;; noun has two subcats: point/coordinate 5 4
    ;; for the rule to be general we should use vars in the restr, not lex...but the numbers
    ;; don't produce a var
    ((N1 (RESTR (& (?smap2 ?l1) (?smap ?l2))) (SORT ?sort) (COMPLEX +)
      (CLASS ?LF) (GAP ?gap) (POSTADVBL -) (QUAL -) (ARGUMENT-MAP ?am)
      (subcat -)
      )
     -N1-coordinates>
     (Head (N (VAR ?v) (lf ?LF)
	    (SORT ?sort) (ARGUMENT-MAP ?am)
	    (SUBCAT ?subcat) (subcat-map ?smap)
	    (SUBCAT (% number (var ?v1) (postadvbl -) (lex ?l1)))
	    (SUBCAT2 ?!subcat2) (subcat2-map ?smap2)
	    (SUBCAT2 (% number (var ?v2) (lex ?l2)(postadvbl -)))
	    	    
	    ))
     ?subcat
     ?!subcat2)
    
    ;;===========================================================================
    ;; ADJECTIVE PHRASES

    ;; adjectives that map to predicates, e.g., little
    ;; swier added attributive and predicative
    ;; 04/2008 swift adding orientation and intensity features
    ;; 10/2009 new representation using ontology types as scales, e.g. enormous -> (f v1 (:* ont::hi w::enormous) :scale ont::large)
    ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem) (atype ?atype) (comparative ?cmp)
      (LF (% PROP (CLASS ?lf)
	     (VAR ?v) (CONSTRAINT ?newc)
	     (transform ?transform) (sem ?sem) (premod -)
	     )))
     -adj-scalar-pred> 1
     (head (ADJ (LF ?lf) (SUBCAT -) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
	    (transform ?transform) (constraint ?con) (functn ?fn) (comp-op ?dir)
	    (Atype ?atype) (comparative ?cmp) (lex ?lx) ;(lf (:* ?lftype ?lex))
	    (sem ($ F::ABSTR-OBJ (f::scale ?!scale) (F::intensity ?ints) (F::orientation ?orient)))
	    (post-subcat -) (prefix -)
	    ))
     (append-conjuncts (conj1 ?con) (conj2 (& (orientation ?orient) (intensity ?ints)
					    (?argmap ?arg) (scale ?scale) 
					     ))
		       (new ?newc))
     )

    ;; prefix ADV modification of an ADJ
   ((ADJ (LF ?lf) (SUBCAT ?subcat) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
     (transform ?transform) (constraint ?newc) (functn ?fn) (comp-op ?dir)  (argument ?argument)
     (atype ?atype) (comparative ?cmp) (lex ?lx) ; (lf (:* ?lftype ?lx))
     ;(sem ($ F::SITUATION))
     (arg ?arg)
     (prefix -)
     )
   -adj-prefix-hyphen> 1
    (adv (PREFIX +) (VAR ?advbv) 
     (argument (% ADJP (sem ?sem))) (LF ?qual)
     )
    (word (lex w::punc-minus))
    (head (ADJ (LF ?lf) (SUBCAT ?subcat) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
	       (transform ?transform) (constraint ?con) (functn ?fn) (comp-op ?dir) (arg ?arg)
	       (atype ?atype) (comparative ?cmp) (lex ?lx) (argument ?argument)
	       ))
    (add-to-conjunct  (val (:MOD (% *PRO* (status F) (class ?qual)
				    (var ?advbv) (constraint (& (of ?v))))))
     (old ?con) 
     (new ?newc))
    )
     
    ((ADJ (LF ?lf) (SUBCAT ?subcat) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
     (transform ?transform) (constraint ?newc) (functn ?fn) (comp-op ?dir)  (argument ?argument)
     (atype ?atype) (comparative ?cmp) (lex ?lx) ; (lf (:* ?lftype ?lx))
     ;(sem ($ F::SITUATION))
     (arg ?arg)
     (prefix -)
     )
   -adj-prefix> 1
    (adv (PREFIX +) (VAR ?advbv) 
     (argument (% ADJP (sem ?sem))) (LF ?qual)
     )
    (head (ADJ (LF ?lf) (SUBCAT ?subcat) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
	       (transform ?transform) (constraint ?con) (functn ?fn) (comp-op ?dir) (arg ?arg)
	       (atype ?atype) (comparative ?cmp) (lex ?lx) (argument ?argument)
	       ))
    (add-to-conjunct  (val (:MOD (% *PRO* (status F) (class ?qual)
				    (var ?advbv) (constraint (& (of ?v))))))
     (old ?con) 
     (new ?newc))
    )
  
   ;; non-scalar adjectives (e.g., sleeping)
   ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem) (atype ?atype) (comparative ?cmp)
      (LF (% PROP (CLASS ?lf)
	     (VAR ?v) (CONSTRAINT ?newc)
	     (transform ?transform) (sem ?sem) (premod -)
	     )))
     -adj-nonscalar-pred> 1
     (head (ADJ (LF ?lf) (SUBCAT -) (VAR ?v) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
	    (transform ?transform) (constraint ?con) (functn ?fn) (comp-op ?dir)
	    (atype ?atype) (comparative ?cmp) (lex ?lx) ; (lf (:* ?lftype ?lx))
	    (sem ($ F::ABSTR-OBJ
		    (f::scale -)))
	    ;;(sem ($ F::SITUATION))
	    (post-subcat -) (prefix -)
	    ))
     (append-conjuncts (conj1 ?con) (conj2 (& (?argmap ?arg)))
      (new ?newc))
     )

    ;;  a (ten foot) high fence, a three mile wide path, .. 
    ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem) (atype ?atype) (comparative ?cmp)
      (LF (% PROP (CLASS ont::at-scale-val) (VAR ?v) (CONSTRAINT ?newc)
	     (transform ?transform) (sem ?sem)))
      )
     -adj-unit-modifier> 1.0
     (ADJP (sort unit-measure) (var ?adjv) 
      (LF (% PROP (constraint (& (val ?adjval)))))
      (sem ($ F::ABSTR-OBJ (F::scale F::linear-scale))))
     (head (ADJ (LF ?lf)  (VAR ?v) (SUBCAT -) (sem ($ F::ABSTR-OBJ (F::scale (? scale F::linear-scale))))
		(SORT PRED) ;;(ARGUMENT-MAP ?argmap)
		(transform ?transform) (constraint ?con)
	    (atype ?atype) (comparative ?cmp)
	    (post-subcat -)
	    ))
     (append-conjuncts (conj1 ?restr) (conj2 ?r) (new ?tempcon))
     (append-conjuncts (conj1 (& (OF ?arg) (VAL ?adjval) (scale (? scale F::linear-scale))))
		       (conj2 ?tempcon) (new ?newc)))

;;  a (ten foot)-high fence, a three mile wide path, .. 
    ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem) (atype ?atype) (comparative ?cmp)
      (LF (% PROP (CLASS ont::at-scale-val) (VAR ?v) (CONSTRAINT ?newc)
	     (transform ?transform) (sem ?sem)))
      )
     -adj-unit-modifier-HYPHEN> 1.1
     (ADJP (sort unit-measure) (var ?adjv) 
      (LF (% PROP (constraint (& (val ?adjval)))))
      (sem ($ F::ABSTR-OBJ (F::scale F::linear-scale))))
     (word (lex w::punc-minus))
     (head (ADJ (LF ?lf)  (VAR ?v) (SUBCAT -) (sem ($ F::ABSTR-OBJ (F::scale (? scale F::linear-scale))))
		(SORT PRED) ;;(ARGUMENT-MAP ?argmap)
		(transform ?transform) (constraint ?con)
	    (atype ?atype) (comparative ?cmp)
	    (post-subcat -)
	    ))
     (append-conjuncts (conj1 ?restr) (conj2 ?r) (new ?tempcon))
     (append-conjuncts (conj1 (& (OF ?arg) (VAL ?adjval) (scale (? scale F::linear-scale))))
		       (conj2 ?tempcon) (new ?newc)))

   ;; adjectives with deleted complements  JFA 8/02
    ;; different (truck)    
    ((ADJP (ARG ?arg) (VAR ?v) (atype ?atype) (comparative -)
      (LF (% PROP (CLASS ?lf) (VAR ?v) 
	     (sem ?sem) 
	     (CONSTRAINT ?newc)
	     (transform ?transform)
	     )))
     -adj-pred-object-deleted>
     (head (ADJ (LF ?lf) (VAR ?v) (sem ?sem) (atype ?atype)
		(CONSTRAINT ?con) (comparative -) (prefix -)
		(SUBCAT (% ?!subc (SEM ?subsem) ))
		(sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
		(SORT PRED) (SUBCAT-MAP ?submap)
;		(Functn ?fn)  ;; don't need functn in none comparative rules
		(COMP-OP ?dir)
		(transform ?transform)
	    (ARGUMENT-MAP ?argmap)
	    (allow-deleted-comp +)
	    (post-subcat -)
	    ))
     (append-conjuncts (conj1 ?con)
		       (conj2 (& (scale ?scale) (f::intensity ?ints) (f::orientation ?orient)
;				 (Functn ?fn)
				 (?argmap ?arg) 
				 (?submap (% *PRO* (var *) (sem ?subsem) (constraint (& (related-to ?v)))))))
				 
		       (new ?newc))
     )

     ;; more quickly
     ((ADVBL (ARG ?arg)
	 (VAR ?v) (atype ?atype) (comparative (? cc + w::superl))
      (LF (% PROP (CLASS ?lf) (VAR ?v)
	     (sem ?sem) 
	     (CONSTRAINT ?newc)
	     (transform ?transform)
	     ))
      (gap -) (wh -) (argument ?argument)
      )
     -adv-compar-object-deleted>
      (head (ADV (LF ?lf) (sem ?sem) (atype ?atype)
	     (CONSTRAINT ?con) (comparative (? cc + w::superl))
	     (SUBCAT (% ?!subc (SEM ?subsem) ))
	     (SORT PRED) (var ?v)
	     (SUBCAT-MAP ?submap)
	     (Functn ?fn)
	     (comp-op ?dir)
	     (transform ?transform)
	     (ARGUMENT-MAP ?argmap)
	     (functn-map ?fnmap)
	     (sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
	     (ARGUMENT (% ?x (sem ?argsem) (lex ?arglex)))
	     (post-subcat -)
	     ))
      (append-conjuncts (conj1 ?con)
       (conj2 (& (scale ?fn) (orientation ?orient) (intensity ?ints)
;		 (Functn ?fn)
		 (?argmap ?arg) 
		 (functn-arg ?fnmap)
		 (?submap (% *PRO* (var *) (class ?c) (sem ?argsem)))))      
       (new ?newc))
      )
    

    ;; comparatives with deleted complements  JFA 8/02
     ;; bigger

    ((ADJP (ARG ?arg) (VAR ?v) (atype ?atype) (comparative (? cc + w::superl))
      (LF (% PROP (CLASS ?lf) (VAR ?v)
	     (sem ?sem) 
	     (CONSTRAINT ?newc)
	     (transform ?transform)
	     ))
      )
     -adj-compar-object-deleted>
     (head (ADJ (LF ?lf) (sem ?sem) (atype ?atype)(VAR ?v) (prefix -)
		(CONSTRAINT ?con) (comparative (? cc + w::superl))
		(SUBCAT (% ?!subc (SEM ?subsem) ))
		(SORT PRED) (SUBCAT-MAP ?submap)
		(Functn ?fn)
		(COMP-OP ?dir)
		(transform ?transform)
		(ARGUMENT-MAP ?argmap)
	    (ARGUMENT (% ?x (sem ?argsem) (lex ?arglex)))
	    (sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
	    (post-subcat -);;(W::allow-deleted-comp +)
	    ))
     (unify (value ?argsem) (pattern ($ ?type (f::type ?c))))
     (append-conjuncts (conj1 ?con)
		       (conj2 (& ;(Functn ?fn)
			         (scale ?fn) (orientation ?orient) (intensity ?ints)
				 (?argmap ?arg) 
				 (?submap (% *PRO* (var *) (class ?c) (sem ?argsem)))))
      (new ?newc))
     )

		       
     ;; (a) BIGGER (computer than that) -- requiring a post-N1 subcat
    ((ADJP (ARG ?arg) (VAR ?v) (atype ?atype) (comparative +)
      (LF (% PROP (CLASS ?lf) (VAR ?v)
	     (sem ?sem) 
	     (CONSTRAINT ?newc)
	     (transform ?transform)
	     ))
       (post-subcat ?!subcat) (psarg ?psvar))
     -adj-compar-subcat-post-N1>
     (head (ADJ (LF ?lf) (sem ?sem) (VAR ?v) (atype ?atype)
		(CONSTRAINT ?con) (allow-post-n1-subcat +) (prefix -)
		(subcat ?!subcat)
		(SORT PRED) (SUBCAT-MAP ?submap)
		(Functn ?fn)		
		(COMP-OP ?dir)
		(transform ?transform)
		(sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
		(ARGUMENT-MAP ?argmap)
		(ARGUMENT (% ?x (sem ?argsem) (lex ?arglex)))
	    ))
     (append-conjuncts (conj1 ?con)
		       (conj2 (& ;(Functn ?scale)
				 (scale ?fn)
				 (orientation ?orient) (intensity ?ints)
				 (?argmap ?arg) 
				 (?submap ?psvar)))
				 
		       (new ?newc))
     )

    ;; a house bigger than that
    ((ADJP (ARG ?arg) (VAR ?v) (COMPLEX +) (atype (? atp postpositive predicative-only))
      (LF (% PROP  (CLASS ?lf)
	     (VAR ?v) (CONSTRAINT (& (?argmap ?arg) (?reln ?argv) (scale ?fn) (intensity ?ints) (orientation ?orient)
						      ))
	     (transform ?transform) (sem ?sem)
	     )))
     -adj-pred-compar-subcat>
     (head (ADJ (LF ?lf) (SUBCAT2 -) (post-subcat -)(VAR ?v) (comparative +)
		(SUBCAT ?subcat) (SUBCAT-MAP ?reln) (SUBCAT (% ?xx (var ?argv)))
		(ARGUMENT-MAP ?argmap) 	
		(functn ?fn)
		(SORT PRED) (prefix -)
		(sem ?sem) (sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
		(transform ?transform)
		))
     ?subcat)


      
    ;; adjectives that map to predicates with subcats, e.g.,  close to avon
    ;; The resulting adjective phrase is marked as predicative only, because really it cannot be used otherwise
    ;; ?? the afraid of dogs man ???
     ((ADJP (ARG ?arg) (VAR ?v) (COMPLEX +) (atype (? atp postpositive predicative-only)) (gap ?gap)
      (LF (% PROP  (CLASS ?lf)
	     (VAR ?v) (CONSTRAINT (& (?argmap ?arg) (?reln ?argv) (FUNCTN ?fn) (scale ?scale) (intensity ?ints) (orientation ?orient)
						      ))
	     (transform ?transform) (sem ?sem)
	     )))
     -adj-pred-subcat>
     (head (ADJ (LF ?lf) (SUBCAT2 -) (post-subcat -)(VAR ?v) (comparative -)
		(SUBCAT ?subcat) (SUBCAT-MAP ?reln) (SUBCAT (% ?xx (var ?argv) (gap ?gap)))
		(ARGUMENT-MAP ?argmap) (prefix -)
		(functn ?fn)
		(SORT PRED)
		(sem ?sem) (sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
		(transform ?transform)
		))
     ?subcat)

   ;;  the ADJP please "difficult to please" has an ARG that is the GAP in the clause. 
    ((ADJP (ARG ?arg) (VAR ?v) (COMPLEX +) (atype (? atp postpositive predicative-only)) (gap -)
      (LF (% PROP  (CLASS ?lf)
	     (VAR ?v) (CONSTRAINT (& (?argmap ?arg) (?reln ?predv) (FUNCTN ?fn) (scale ?scale) (intensity ?ints) (orientation ?orient)
						      ))
	     (transform ?transform) (sem ?sem)
	     )))
     -adj-pred-subcat-gap-as-arg>
     (head (ADJ (LF ?lf) (SUBCAT2 -) (post-subcat -)(VAR ?v) (comparative -)
		(SUBCAT ?subcat) (SUBCAT-MAP ?reln) (SUBCAT (% CP ))
		(ARGUMENT-MAP ?argmap) (prefix -)
		(functn ?fn)
		(SORT PRED)
		(sem ?sem) (sem ($ F::ABSTR-OBJ (f::scale ?scale) (F::intensity ?ints) (F::orientation ?orient)))
		(transform ?transform)
		))
     (CP (var ?predv) (gap ?!gap) (gap (% np (var ?arg)))))

   ;;  special rule for COMPAR-OPS, converting an adjective to a comparative adjective
 
   ((ADJ (LF (:* ?pred ?lftype))
     (VAR ?v) (comparative +)
     (ALLOW-POST-N1-SUBCAT ?xx)
     (SUBCAT-MAP ?subcat-map)
     (subcat  ?subcat)
     (comp-ptype ?pt)
     (ground-oblig ?go)
     (ground-subcat ?ground-subcat)
     (ATYPE CENTRAL)
     (functn ?scale)
     (SORT PRED)
     (sem ($ F::ABSTR-OBJ (f::scale ?scale)))
     (transform ?transform) (argument-map ont::figure) (argument ?argument)  (arg ?arg)
     )
     -more-adj-compar> 1.0
    (ADV (compar-op +) (lf (:* ?pred ?xx)) (ground-oblig ?go) (SUBCAT ?ground-subcat))
    (head (ADJ (LF (:* ?lftype ?w)) (var ?v) 
	       (SUBCAT2 -) (post-subcat -)(VAR ?v) (comparative -)
	       (SUBCAT ?subcat) 
	       (subcat-map ?subcat-map)
	       (ATYPE central)
	       (argument ?argument) (arg ?arg)
	       (SORT PRED)
	       (sem ($ F::ABSTR-OBJ (f::scale ?scale)))
	       (transform ?transform)
	       ))
    )
#||

   ((less-more (pred ONT::MORE-VAL) (ptype w::than))
    -less-more1> 1.0
    (head (word (lex more))))
   
   ((less-more (pred ONT::LESS-VAL) (ptype w::than))
    -less-more2> 1.0
    (head (word (lex less))))

   ((less-more (pred ONT::MAX-VAL) (ptype w::of))
    -less-more3> 1.0
    (head (word (lex most))))

   ((less-more (pred ONT::MIN-VAL) (ptype w::of))
    -less-more4> 1.0
    (head (word (lex least))))
||#

    ;; MD 2008/06/05 removed because it seems to cause excessive ambiguity without evident benefit
   ;; adjectives that map to predicates with two subcats, e.g.,  closer to avon than bath
    ((ADJP (ARG ?arg) (VAR ?v) (COMPLEX +) (atype predicative-only)
      (LF (% PROP (CLASS ?lf) (VAR ?v) (CONSTRAINT (& (?argmap ?arg) (?reln ?argv) (?reln2 ?argv2)))
	     (transform ?transform) (sem ?sem)
	     )) 
           )
     -adj-pred-subcat+>
     (head (ADJ (LF ?lf)  (VAR ?v)
	    (transform ?transform) (sem ?sem)
	    (SUBCAT ?subcat) (SUBCAT-MAP ?reln) (SUBCAT (% ?xx (var ?argv)))
	    (SUBCAT2 ?subcat2) (SUBCAT2-MAP ?reln2) (SUBCAT2 (% ?xx2 (var ?argv2)))
	    (post-subcat -)
	    (ARGUMENT-MAP ?argmap)
	    (SORT PRED)))
     ?subcat
     ?subcat2)
       
    
    ;;=============================================================================
    ;; NOUN-NOUN type  modification
    
    ;; e.g.,  Elmira route/train, the July 31st resolution, my 1990 tax return
    ((N1 (RESTR ?new) (CLASS ?c) (SORT PRED) (sem ?sem)
         (QUAL -) (relc -) (subcat ?subcat) (name-mod +)  ;; only allow one name modifier
     ) 
     -name-n1> .98
     (np (name +) (generated -) ;; don't allow numbers or times here
         (VAR ?v1))
     (head (N1 (VAR ?v2) (relc -) (sem ?sem) (sem ($ (? x F::ABSTR-OBJ F::PHYS-OBJ))) ;;  F::SITUATION)))
	    (RESTR ?r) (CLASS ?c) (SORT PRED) (name-mod -)
	    ;;(subj-map -)  ;; nominalized verbs have their own rules
	    (subcat ?subcat)
	    (post-subcat -)
	    (postadvbl -) 
	    (generated -)
	    )
      )
     (add-to-conjunct (val (ASSOC-WITH ?v1)) (old ?r) (new ?new)))


 ;; e.g.,  specialized construction - where head N1 occurs first -- only in medical domain so far, as in MEK Y280S (where the second is a mutation modifiers)
    ((N1 (RESTR ?new) (CLASS ?c) (SORT PRED) (sem ?sem)
         (QUAL -) (relc -) (subcat ?subcat) (name-mod +)  ;; only allow one name modifier
     ) 
     -n1-mutation> .98
     
     (head (N1 (VAR ?v2) (relc -) (sem ?sem) (sem ($ (? x F::ABSTR-OBJ F::PHYS-OBJ))) ;;  F::SITUATION)))
	    (RESTR ?r) (CLASS ?c) (SORT PRED) (name-mod -)
	    (subjmap -)  ;; nominalized verbs have their own rules
	    (subcat ?subcat)
	    (post-subcat -)
	    (postadvbl -) 
	    (generated -)
	    )
      )
     (np (name +) (time-converted -) (sem ($ f::SITUATION (f::type ont::mutation))) 
      (VAR ?v1))
     (add-to-conjunct (val (ASSOC-WITH ?v1)) (old ?r) (new ?new)))
        
    ;; e.g., the mountain route, the truck plan, the security zone, ...
   ;;   such as "The small car lot"    
    ((N1 (RESTR ?new) (SORT ?sort) (sem ?sem) (class (? c ONT::REFERENTIAL-SEM))
      (N-N-MOD +) (QUAL -) (relc -) (subcat ?subcat) (gap ?gap))
      
     -n-sing-n1-> 0.96 ;; prevent this from happening too often
     (n1 (AGR 3s) (abbrev -) (generated -)
        (var ?v1) (restr ?modr)  (gerund -)   ;; we expect gerunds as modifiers to be adjectives, not N1
	;;  removed this to handle things like "computing services"
	;; we reinstated "gerund -" as "computing" should be an adjective (and we need to exclude "... via phosphorylating Raf"
      (sem ?n-sem)
      (CLASS ?modc) (PRO -) (N-N-MOD -) ;;(COMPLEX -)   can't require COMPLEX - any more -- e.g., "p53 expression levels"
      (SUBCAT ?ignore) (GAP -) (kr-type ?kr-type)
      (postadvbl -) (post-subcat -) 
      )
     (head (N1 (VAR ?v2) (QUAL -) (subcat ?subcat) (sort ?sort)
	       (sem ?sem)  (class (? c ONT::REFERENTIAL-SEM))
	       (generated -)
	       ;;(sem ($ (? x F::ABSTR-OBJ F::PHYS-OBJ))) ;;If we put this in, the SEM info doesn't get passed up!!
	       (RESTR ?r) 
	       (SORT PRED) (gap ?gap) 
	    (relc -)  (postadvbl -) (post-subcat -) 
	    (subjmap -)  ;; nominalized verbs have their own rules
	    (abbrev -)
	       ))
     (add-to-conjunct 
      (val (ASSOC-WITH (% *PRO* (status kind) (var ?v1) (class ?modc) (constraint ?modr) (sem ?n-sem) (kr-type ?kr-type)))) 
      (old ?r) (new ?new)))

    ;; n-n mods with hyphen  -- this allows us to override our otherwise strict requirement to attach on the right
    ((N1 (RESTR ?new) (CLASS ?c) (SORT ?sort) 
      (QUAL -) (relc -) (subcat ?subcat) (n-sing-already +)  ;; stop this happening more than once
      )
     -n-sing-hyphen-n1-> 
     (n1 (AGR 3s) 
        (var ?v1) (sem ?sem) (restr ?modr) 
      (CLASS ?modc) (PRO -) (N-N-MOD -) (COMPLEX -) (SUBCAT -) (GAP -)
      (postadvbl -) (post-subcat -) (n-sing-already -)
      )
     (word (lex w::punc-minus))
     (head (N1 (VAR ?v2) (QUAL -) (subcat ?subcat) (n-sing-already -)
	       (RESTR ?r) (CLASS ?c) (SORT ?sort) (N-N-MOD -)
	       (relc -)  (postadvbl -) (post-subcat -) (name-mod -)
	       (subjmap -)  ;; nominalized verbs have their own rules
	       ))
     (add-to-conjunct (val (ASSOC-WITH (% *PRO* (status kind) (var ?v1) (class ?modc) 
					  (constraint ?modr) (sem ?sem)))) (old ?r) (new ?new)))

 ;; N-N mod with relational nouns, with "the book title", the book will fill the :OF role.
    ((N1 (RESTR ?new) (CLASS ?c) (SORT PRED) 
      (N-N-MOD +) (QUAL -) (relc -) (subcat ?subcat)
      )
     -n-sing-reln1-> 
     (n1 (AGR 3s) 
        (var ?v1) (sem ?sem) (restr ?modr) 
      (CLASS ?modc) (PRO -) (N-N-MOD -) (COMPLEX -) (SUBCAT -) (GAP -)
      (postadvbl -) (post-subcat -)
      )
     (head (N1 (VAR ?v2) (QUAL -) (subcat (% ?cat (sem ?sem)))
	       (RESTR ?r) (CLASS ?c) (SORT RELN) (subcat-map ?smap)
	       (relc -)  (postadvbl -) (post-subcat -)
	       ))
     (add-to-conjunct (val (?smap (% *PRO* (status definite) (var ?v1) (class ?modc) (constraint ?modr) (sem ?sem))))
      (old ?r) (new ?new)))

    ;;  plural N-N is much more rare:
    ;;  the mountains route; the books link

    ((N1 (RESTR ?new) (CLASS ?c) (SORT ?sort) (COMPLEX -)
      (N-N-MOD +) (QUAL -) (relc ?relc) (subcat ?subcat)
      (post-subcat -)
         )
     -n-plur-n1-> 0.97 ;; prevent this from happening too often
     (n1 (AGR 3p) (abbrev -)
	 (var ?v1) (sem ?sem) (restr ?modr) 
	 (CLASS ?modc) (PRO -) (N-N-MOD -) (COMPLEX -) (SUBCAT -) (GAP -)
	 (postadvbl -) (post-subcat -)
      )
     (head (N1 (VAR ?v2) (QUAL -) 
	    (RESTR ?r) (CLASS ?c) (SORT ?sort)
	    (relc ?relc) (subcat ?subcat) (postadvbl -)
	    (post-subcat -)  (subjmap -)  ;; nominalized verbs have their own rules
	       ))
      (add-to-conjunct (val (ASSOC-WITH (% *PRO* (status kind) (var ?v1) (class ?modc) (constraint ?modr) (sem ?sem)))) (old ?r) (new ?new)))
    
    ;;=======================
    ;;
    ;;  RELATIVE CLAUSES
    ;;
    
	
    ;; e.g., the train that went to Avon, the train I moved, the train that is in Avon
    
    ((N1 (RESTR ?con)
      (CLASS ?c) (SORT ?sort) (QUAL ?qual) (COMPLEX +) (var ?v)
      (relc +)  (subcat -) (post-subcat -)
      )
     -n1-rel>
     (head (N1 (VAR ?v) (RESTR ?r)
	       (CLASS ?c) (SORT ?sort) (QUAL ?qual)
	    (SEM ?sem) ;;(subcat -) 
	    (post-subcat -) (gap -) ;;(derived-from-name -) 
	    (no-postmodifiers -) ;; exclude "the same path as the battery I saw" and cp attaching to "path"
	    (agr ?agr)
	    ))
;     (cp (ctype relc) (VAR ?relv) (ARG ?v) (ARGSEM ?argsem) (agr ?agr)
     (cp (ctype relc) (VAR ?relv) (ARG ?v) (ARGSEM ?sem) (agr ?agr)
      (LF ?lf))
     (add-to-conjunct (val (MODS ?relv)) (old ?r) (new ?con)))

    ;;  Great construction!:   All he saw (was mountains)

   ((NP (LF (% description (STATUS definite) (VAR *)
		    (CLASS ?c) (CONSTRAINT (& (mod ?relv)))
		    (sem ?sem)  (transform ?transform)
		    ))
     (sem ?sem)
     (SORT PRED) (VAR *) (AGR (? agr 3s 3p)) (CASE (? case SUB OBJ)))
     -all-he-saw>
    (head (word (lex (? x w::all w::what))))
    (cp (ctype relc) (VAR ?relv) (ARG *) (ARGSEM ?argsem) 
     (LF ?lf))
    )
   
   
   ;; somewhat rare construction allows qualifications: the man though who saw the party, lied about it.
   ((N1 (RESTR ?con)
      (CLASS ?c) (SORT ?sort) (QUAL ?qual) (COMPLEX +) (var ?v)
      (relc +)  (subcat -) (post-subcat -)
      )
    -n1-qual-rel>
    (head (N1 (VAR ?v) (RESTR ?r)
	      (CLASS ?c) (SORT ?sort) (QUAL ?qual)
	      (SEM ?sem) ;;(subcat -) 
	      (post-subcat -) (gap -)
	      (no-postmodifiers -) 
	      ))
    (advbl (var ?advv) (sort w::disc) (sem ($ f::abstr-obj (f::type ont::qualification))))
    (cp (ctype relc) (VAR ?relv) (ARG ?v) (ARGSEM ?argsem) 
     (LF ?lf))
    (add-to-conjunct (val (MODS (?relv ?advv))) (old ?r) (new ?con)))


    ;; the man whose dog barked
    ((N1 (RESTR ?con)
      (CLASS ?c) (SORT ?sort)
      (QUAL ?qual) (COMPLEX +) (wh -) ;;(wh-var ?whv)
      (relc +)  (subcat -) (post-subcat -)
      )
     -n1-rel-whose>
     (head (N1 (VAR ?v) (RESTR ?r) (SEM ?sem) (CLASS ?c) (SORT ?sort) (QUAL ?qual)
	    (sem ?argsem)
	    (post-subcat -)
	    (no-postmodifiers -) ;; exclude "the same path as the battery I saw" and cp attaching to "path"
	    ))
     (cp (ctype rel-whose) (VAR ?relv) (wh R) (wh-var ?v) ;(arg ?v) (argsem ?sem)
      (LF ?lf))
    (add-to-conjunct (val (MODS ?relv)) (old ?r) (new ?con)))

    ;; attach an s-to to a noun:
    ;; I have a job to do, an option to suggest
  ((N1 (RESTR ?con) (gap -)
      (CLASS ?c) (SORT ?sort) (QUAL ?qual) (COMPLEX +)
      (subcat -) (post-subcat -)
      )
     -n1-inf> .92
     (head (N1 (VAR ?v) (RESTR ?r) (SEM ?sem) (CLASS ?c) (SORT ?sort) (QUAL ?qual)
	    (subcat -) (post-subcat -)
	    (no-postmodifiers -) ;; exclude "the same path as the battery I saw" and cp attaching to "path"
	    ))
     (cp (ctype s-to) (VAR ?tov) (subj ?subj)   (gap (% np (sem ?sem) (var ?v)))
	 (dobj ?!dobj) (dobj (% np (sem ?sem)))
	  (LF ?lf)) 
     (add-to-conjunct (val (MODS ?tov)) (old ?r) (new ?con)))
  
  ;; e.g., anything else, what else
    ((NP (SORT PRED)
         (VAR ?v) (SEM ?sem) (lex ?hl) (headcat ?hc) (Class ?c) (AGR ?agr) (WH ?wh) (PRO INDEF)(case ?case)
         (LF (% Description (status ?status) (var ?v) (Class ?c) (SORT individual)
                (Lex ?lex)
                (sem ?sem) 
		(constraint (& (MODS ?else-v) (proform ?hl)))
		(transform ?transform)
                ))
      )
     -np-anything-else>
     (head (pro (SEM ?sem) (AGR ?agr) (VAR ?v) (headcat ?hc) (lex ?hl)
	        (PRO INDEF) (status ?status) (case ?case)
	        (VAR ?v) (WH ?wh) (LF ?c)
	        (transform ?transform)
	        ))
      (Advbl (sort else) (var ?else-v) (arg ?v))
     )

    ;; e.g., something nice, anything like it
    ;; the LF built in the same way as in n1-qual1
    ;; postpositive adjps alowed to parse "something like a dog"
    ((NP (SORT PRED)
         (VAR ?v) (SEM ?sem) (lex ?hl) (headcat ?hc) (Class ?c) (AGR ?agr) (WH ?wh) (PRO INDEF)(case ?case)
         (LF (% Description (status ?status) (var ?v) (Class ?c) (SORT individual)
                (Lex ?lex)
                (sem ?sem) 
		(constraint (& (MODS ?adjv) (proform ?hl)))
		(transform ?transform)
                ))
      )
     -np-anything-adj> .96 ; only use when needed
     (head (pro (SEM ?sem) (AGR ?agr) (VAR ?v) (headcat ?hc) (lex ?hl)
	        (PRO INDEF) (status ?status) (case ?case)
	        (VAR ?v) (WH ?wh) (LF ?c)
	        (transform ?transform)
	    ))
     (ADJP (atype (? at attributive-only central postpositive)) (LF ?qual) (ARG ?v) (VAR ?adjv)
      (argument (% NP (sem ?sem))) (comparative ?com)
      (post-subcat -)
      )
     )
     
     
         ;; e.g., something nice, anything like it
    ;; the LF built in the same way as in n1-qual1
    ;; postpositive adjps alowed to parse "something like a dog"
    ((NP (SORT PRED)
         (VAR ?v) (SEM ?sem) (lex ?hl) (headcat ?hc) (Class ?c) (AGR ?agr) (WH ?wh) (PRO INDEF)(case ?case)
         (LF (% Description (status ?status) (var ?v) (Class ?c) (SORT individual)
                (Lex ?lex)
                (sem ?sem) 
		(constraint (& (MODS ?advvar) (proform ?hl)))
		(transform ?transform)
                ))
      )
     -np-pro-pred> .96			; only use when needed
     (head (pro (SEM ?sem) (AGR ?agr) (VAR ?v) (headcat ?hc) (lex ?hl)
		(status ?status) (case ?case)
	        (VAR ?v) (WH ?wh) (LF ?c)
	        (transform ?transform)		
		(lex (? lxx something everything nothing anything someone anyone somebody anybody somewhere anywhere these those))
		))
     (PRED (LF ?l1) (ARG ?v) ;;SORT SETTING) 
      (var ?advvar) (ARGUMENT (% NP (sem ?sem))))
     )
   
   
   ((np (sort PRED)  (gap -) (mass bare) (case (? case SUB OBJ))
     (sem ?s-sem) (var ?npvar) (WH -) (agr ?a)
     (lf (% description (status ?status) (VAR ?npvar) 
	    (constraint ?constraint) (sort ?npsort)
	    (sem ?npsem)  (class ?npclass) (transform ?transform)
	    )))
    -np-pro-cp> .96
    (head (np (var ?npvar) (sem ?npsem) 
	   (PRO (? prp INDEF +))
	   (WH -)
	   (agr ?a) (case ?case)
	   ;; Myrosia 2009/04/10 Cases like "anything you saw" are handled by indef-pro-desc
	   ;; they are sort wh-desc and cannot come up as fragments
	   ;; "those in a box" is a valid fragment
	   ;; We may want to consolidate the handling later
	   ;;(lex (? lxx these those))
	   (lf (% description (class ?npclass) (status ?status) (constraint ?cons) (sort ?npsort)
		  (transform ?transform)
		  ))))
    (cp (ctype relc) (reduced -)
     (ARG ?npvar) (ARGSEM ?npsem)  (VAR ?CP-V)
     (LF ?lf) 
     )
    (add-to-conjunct (val (suchthat ?cp-v)) (old ?cons) (new ?constraint)))
   
    ;;   simple appositives,
    ;;  e.g., city avon, as in "the city avon"
    ;;
    ((N1 (RESTR ?con) (CLASS ?c) (SORT ?sort) (QUAL ?qual) (COMPLEX +)
      (subcat -) (post-subcat -)
      )
     -N1-appos1> .96
     (head (N1 (VAR ?v1) (RESTR ?r) (CLASS ?c) (SORT ?sort) (QUAL ?qual) (relc -) (sem ?sem)
	    (subcat -) (post-subcat -) (complex -) (derived-from-name -) (time-converted -)
	    )      
      )
     (np (name +) (generated -) (sem ?sem) (class ?lf) (VAR ?v2) (time-converted -))
     (add-to-conjunct (val (EQ ?v2)) (old ?r) (new ?con)))
	
   ;; same with comma  the city, avon
    ((N1 (RESTR ?con) (CLASS ?c) (SORT ?sort) (QUAL ?qual) (COMPLEX +) 
      (subcat -))
     -N1-appos2>
     (head (N1 (VAR ?v1) (RESTR ?r) (CLASS ?c) (SORT ?sort) (QUAL ?qual) (relc -)
	    (subcat -) (post-subcat -) (sem ?sem)
	    ))
     (punc (lex w::punc-comma))
     (np (name +) (generated -) (CLASS ?c) (sem ?sem) (VAR ?v2))
     (add-to-conjunct (val (EQ ?v2)) (old ?r) (new ?con)))
		
    ))


;;; MOre complex relational nouns: the difference in states between the terminals

(parser::augment-grammar
  '((headfeatures
     (N1 var arg lex headcat transform agr mass case sem quantity indef-only refl abbrev nomobjpreps)
     )
    ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?smap ?v1) (?amap ?v2)))
      (subcat -) (argument -)
      )
     -N1-reln-arg-subcat1>
     (head (n (sort reln) (lf ?lf)
	    (subcat ?!subcat)
	    (subcat (% ?scat (var ?v1) (sem ?ssem) (lf ?lf2) (sort (? ssrt pred individual set comparative reln unit-measure))))
	    (subcat-map ?smap)
	    (argument ?!argument)
	    (argument (% ?arg (var ?v2) (sem ?asem) (lf ?lf3) (sort (? asrt pred individual set comparative reln))))
	    (argument-map ?amap)))
     ?!subcat
     ?!argument
     )
    ;; difference in states, with "states" being mapped consistently to the same role as in other cases
    ((N1 (sort pred) (var ?v) (class ?lf) (qual -) (COMPLEX +)
      (restr (& (?amap ?v2)))
      (subcat -) (argument -)
      )
     -N1-reln-arg-subcat-deleted>
     (head (n (sort reln) (lf ?lf)
	    (allow-deleted-comp +)
	    (subcat ?!subcat)	    
	    (argument ?!argument)
	    (argument (% ?arg (var ?v2) (sem ?asem) (lf ?lf3) (sort (? srt pred individual set comparative reln))))
	    (argument-map ?amap)))     
     ?!argument
     )
))


;;(cl:setq *grammar-n1-aux*
(parser::augment-grammar
  '((headfeatures
     (NP headcat lex postadvbl)
      (NAME headcat lex)
      (N1 VAR AGR Changeagr case lex headcat transform subcat set-restr refl abbrev nomobjpreps) ;;  excludes MASS as a head feature
      (N lex headcat refl))
  
  #||    I THINK THIS HAS OUTLIVED ITS USEFULNESS!  JFA 6/14
    ;; container loads of commodities, e.g., boxcars of oranges    ==> should probably be redone as a coercion rule JFA 12/02
    ;;   we allow any container to be a unit-measure term
    ((N1 (VAR ?v) (SORT UNIT-MEASURE) (MASS ?m) (CLASS (:* ont::VOLUME-UNIT ?lf)) (sem ?!sem) (QUAL -)
      )
     -n1-container-commodity> 0.95
     (head (N (SEM ($ F::PHYS-OBJ (f::CONTAINER f::+)
		       )) (sem ?!sem) (sort pred) 
	    (PRED ?pred) (MASS ?m) (LF (:* ?lf ?w)) (ARGSEM ?argsem)))
     )||#

 ;;  COERCION RULE FOR NOUNS e.g., (take my) prescription
    
    ((N (VAR ?v) (MORPH ?m) (SORT ?sort) (CLASS ?kr) (LF ?lf-new)
	(RESTR (& (MODS (% *PRO* (Var **) (status F)
			   (class ?op)
			   (constraint (& (is ?v)
					  (of (% *PRO* (var *) (class ?lf-old) (SEM ?oldsem) (constraint (& (related-to **)))))))))))
	(lex ?l) (sem ?newsem) (AGR ?agr)
      (COERCE -) (TRANSFORM ?t) (MASS ?mass) (CASE ?case) 
      (argument ?argument) (subcat ?subcat) 
      )
     -n1-coerce> .97
     (head (N (COERCE ((% coerce (KR-TYPE ?kr) (Operator ?op) (sem ?newsem) (LF ?lf-new)) ?cc))
              (VAR ?v) (sem ?oldsem) (MORPH ?m) (SORT ?sort) (LF ?lf-old) (lex ?l) (agr ?agr)
	    (TRANSFORM ?t) (MASS ?mass) (CASE ?case) 
	    (argument ?argument) (subcat ?subcat)
	    )
      )
     )
    
       ;; coercing a region into an agent, Italy

    ((NP (VAR *) (MORPH ?m) (SORT ?sort)
         (lf (% description (STATUS W::DEFINITE) (VAR *) (CLASS ont::political-region)
                (CONSTRAINT (& (assoc-with ?v)))))
         (SEM ($ F::phys-obj (f::information ?inf)(F::MOBILITY F::MOVABLE) (f::intentional f::+) (F::spatial-abstraction F::spatial-point)))
         (AGR ?agr)
         (COERCE -) (TRANSFORM ?t) (MASS ?mass) (CASE ?case) 
         (argument ?argument) (subcat ?subcat) (coerced +)
         )
     -n1-region-to-actor-coerce> 0.97
     (head (NP (VAR ?v) (LF (CLASS ont::political-region)) (unit-spec -)
               (SEM ($ F::phys-obj (F::spatial-abstraction F::spatial-region) (f::intentional -) (f::object-function f::spatial-object)))
               (MORPH ?m) (SORT ?sort) (agr ?agr) (generated -)
               (TRANSFORM ?t) (MASS ?mass) (CASE ?case) 
               (argument ?argument) (subcat ?subcat)
	       (coerced -)
              )
           )
    )
    
    
  ;;  COERCION RULE FOR Names
    ((Name (name +) (VAR ?v) (CLASS ?kr) (LF ?lf-new)
	   (RESTR (& (MODS (% *PRO* (var **) (status F) (class ?op)
				  (constraint (& (is ?v) (of (% *PRO* (var *) (STATUS DEFINITE)
								(constraint (& (name-of ?l)))  ;; NAME-OF used to be ?fname JFA 5/04
								(class ?lf-old)))))))))
	   (lex ?l) (sem ?newsem) (AGR ?agr) (full-name ?fname)
	   (COERCE -) (TRANSFORM ?t) )
     -name-coerce>
     (head (name (name +) (COERCE ((% coerce (KR-TYPE ?kr) (Operator ?op) (sem ?newsem) (LF ?lf-new)) ?cc)) ;; gets lf any-sem
		 (VAR ?v) (class ?class-old) (full-name ?fname) (LF ?lf-old) (lex ?l) (agr ?agr)
		 (TRANSFORM ?t)))     
     )      
  ))



;;=========================================================================
;;   NP rules build description structures, which consist of
;;         STATUS - definite/indefinite/quantifiers
;;         VAR - as usual
;;         SORT - a complex expression combine the AGR and MASS features,
;;                that is simplified by an attachment as follows:
;;                (1s/2s/3s -) -> Individual
;;                (1p/2p/3p -) -> Set
;;                (1s/2s/3s +) -> Stuff
;;                (1p/2p/3p +) -> Stuff (quantities of stuff)
;;        CONSTRAINT - the restrictions from N1
;;        SET-CONSTRAINT - the restrictions from SPEC
;;        In singular NPs, the two constraints are simply combined
;;        In plural NPs, the SET-CONSTRAINT apply to the set, and 
;;        the CONSTRAINT to individuals in the set

;;(cl:setq *grammar-NP*
(parser::augment-grammar 
      '((headfeatures
         (NP CASE MASS NAME agr SEM PRO CLASS Changeagr GAP ARGUMENT argument-map SUBCAT role lex headcat transform postadvbl refl gerund abbrev
	  subj dobj subcat-map comp3-map))

; new plural treatment proposed by James May 10 2010
;Basically, we'd have two new quantifiers, say, THE-SET and INDEF-SET,
;and these LF expressions can have a new special role (size or card or whatever
;we call it), attached at the top level.
;
;My guess is that we could eliminate all the plural rules in the grammar and
;slightly generalize the sing version so they handle all the cases. Presumably we'd
;introduce a new sense of THE (of the 3p), and maybe some others.like SOME,
;although I think that's already done.

	;; count and mass NPs, singular and plural:
	;; TEST: a dog, the dog, the dogs, some water, the five dogs


        ((NP (LF (% description (STATUS ?spec) (VAR ?v)   ;;(SORT individual)
		    (CLASS ?c) (CONSTRAINT ?con1)
		    (sem ?sem)  (transform ?transform)
		    ))
             (SORT PRED) (VAR ?v) (CASE (? case SUB OBJ))
	    (wh ?w) (wh-var ?whv);; must move WH feature up by hand here as it is explicitly specified in a daughter
	     )
         -np-indv> 1.0    ;; because determiners are such a closed class, they provide strong evidence for an NP - hence the 1.0 to help with large search spaces
         (SPEC (LF ?spec) (ARG ?v) (mass ?m) (POSS -)
	       (wh ?w) (WH-VAR ?whv)
	       (agr ?agr) (RESTR ?spec-restr) (NOSIMPLE -))   ;; NOSIMPLE prevents this rule for a few cases
         (head (N1 (VAR ?v) (SORT PRED) (CLASS ?c) (MASS ?m)
		(KIND -) (agr ?agr) (RESTR ?r)
		(sem ?sem) (transform ?transform)
		))
	 ;;(add-to-conjunct (val (SIZE ?card)) (old ?setr) (new ?setr1))
	 (append-conjuncts (conj1 ?spec-restr) (conj2 ?r) (new ?con1))
	 )

	;; quantifier with post N1 complement , e.g. more trains than that,
	
        ((NP (LF (% description (STATUS ?spec) (VAR *) (SORT set)   ;; use the N var as the new var
		    (CLASS ?c) (CONSTRAINT ?newr)
		    (sem ?sem)  (transform ?transform)
		    ))
             (SORT PRED) (VAR *) (CASE (? case SUB OBJ))
	     (WH ?w)  (WH-VAR ?whv));; must move WH feature up by hand here as it is explicitly specified in a daughter.
         -np-quan-X-comp>
         (SPEC (LF ?spec) (VAR ?specv)
	       ;; (ARG ?v)  
	  (WH-VAR ?whv)
	  (name-spec -) ;;(mass ?m)
	  (POSS -)
	  (WH ?w) (agr 3p) (NOSIMPLE -) (pred ?pred)
	  (QCOMP (% ?!cat (VAR ?psvar)))
	  (QCOMP ?qcomp))
         (head (N1 (VAR ?v) (SORT PRED) (CLASS ?c) (MASS ?m) 
		   (KIND -) (agr 3p) (RESTR ?r) (sem ?sem)
		   (transform ?transform)
		))
	 ?qcomp ;;(PP (ptype W::THAN) (var ?psvar) (gap -))
	 (add-to-conjunct
	  (val (SIZE (% *PRO* (STATUS INDEFINITE)
			 (VAR **)
			 (CLASS ONT::NUMBER)
			 (CONSTRAINT
			  (& (MODS (% *PRO* (STATUS F)
				      (VAR ***)
				      (CLASS ?pred)
				      (CONSTRAINT (& (figure **) (GROUND ?psvar) (DIFF ?card))))))))))
	  (old ?r) (new ?newr))
	 )

	;; MASS NPs
        ;;  e.g., sand, sand in the corner
        ((NP (MASS (? xx MASS bare))
             (LF (% Description (STATUS BARE) (VAR ?v) (SORT STUFF) (sem ?sem)
	            (CLASS ?c) (CONSTRAINT ?r)
		    (sem ?sem) (transform ?transform)
		    ))	      
             (SORT PRED) (VAR ?v) (simple ?x)

	  )
         -mass>
         (head (N1 (MASS (? xx MASS bare)) (AGR 3s) (VAR ?v) (CLASS ?c) (RESTR ?r) (sem ?sem)
		(transform ?transform) (post-subcat -) (simple ?x)
		(derived-from-name -) ;; this feature is + only if we have a base N1 derived from a NAME (so no need to build a competing NP!)
		)))
        
	;; ANOTHER seems distinct in its behavior so we do it in some grammar rules

	((NP (LF (% description (STATUS indefinite) (VAR ?v)   ;;(SORT individual)
		    (CLASS ?c) (CONSTRAINT ?con1)
		    (sem ?sem)  (transform ?transform)
		    ))
	  (SORT PRED) (VAR ?v) (CASE (? case SUB OBJ))
	  (wh -) (wh-var -);; must move WH feature up by hand here as it is explicitly specified in a daughter
	  )
         -np-another> 1.0   
	 (word (lex w::another))
         (head (N1 (VAR ?v) (SORT PRED) (CLASS ?c) (MASS count)
		   (KIND -) (agr ?agr) (RESTR ?r)
		   (sem ?sem) (transform ?transform)
		   ))
	 ;;(add-to-conjunct (val (SIZE ?card)) (old ?setr) (new ?setr1))
	 (add-to-conjunct 
	  (val (MOD (% *PRO* (status F) (class ont::OTHER) (VAR *) (constraint (& (figure ?v))))))
	  (old ?r) (new ?con1)))
	 
	
        ;; QUANTITY PHRASES

        ;;  UNIT NP PHRASES

	  ;; the / those pounds
	  ((NP (LF (% description (STATUS ?speclf) (VAR ?v) 
		      (CLASS (:* ont::quantity ?sc)) (CONSTRAINT ?constr) (argument ?argument)
		      (sem ?sem)  (transform ?transform) (unit-spec +)
		      ))
	       (spec definite) (class ?c) (VAR ?v) (SORT unit-measure) (WH ?w))
	   -unit-np>  .98    ;; should the NP produced only be used as a SPEC? (possible headless?)
	   (SPEC (LF (? speclf indefinite indefinite-plural definite definite-plural)) ;; only articles in this rule -- no quans
	       (VAR ?specv)
	       (ARG ?v)  
	       (WH-VAR ?whv)
	       (name-spec -) (mass ?m)
	       (POSS -)
	    (WH ?w) (agr ?agr) ;;(restr (& (quan -)))   - doesn't match THE or A!!!
	    (NOSIMPLE -)
	       )
	   (head (N1 (VAR ?v) (SORT unit-measure) (INDEF-ONLY -) (CLASS ?c) (MASS ?m)
		     (KIND -) (agr ?agr) (sem ?sem) (sem ($ f::abstr-obj (f::scale ?sc)))
		     (argument ?argument) (RESTR ?restr) (transform ?transform) (post-subcat -)
		     ))
	   (add-to-conjunct (val (& (unit ?c))) (old ?restr) (new ?constr))
	   )
	  
	;; several/many pounds
	  ((NP (LF (% description (STATUS INDEFINITE) (VAR ?v)
		      (CLASS (:* ont::quantity ?sc)) (CONSTRAINT ?constr) (argument ?argument)
		      (sem ?sem)  (transform ?transform) (unit-spec +)
		      ))
	       (SPEC indefinite) (VAR ?v) (SORT unit-measure) (WH ?w))
	   -unit-quan-card-np>
	   (SPEC (LF ?spec) (ARG ?v) (name-spec -) (mass count)
	    (POSS -) (WH ?w) (agr ?agr)
	    (cardinality +) (QUAN -) ;; cardinality quantifiers only -- others use unit-np-quan
	    (RESTR (& (SIZE ?amt))) (NOSIMPLE -))
	   (head (N1 (VAR ?v) (SORT unit-measure) (INDEF-ONLY -) (CLASS ?c) (MASS ?m)
		     (KIND -) (agr ?agr) (sem ?sem) (sem ($ f::abstr-obj (f::scale ?sc)))
		     (argument ?argument) (RESTR ?restr) (transform ?transform) (post-subcat -)
		     ))
	   ;;   (append-conjuncts (conj1 ?restr) (conj2 ?r) (new ?constr1))
	   (add-to-conjunct (val (& (amount ?amt) (unit ?c))) (old ?restr) (new ?constr))
	   )

	;; quantified unit nps: every three gallons
        ((NP (LF (% description (STATUS quantifier) (VAR ?v) (SORT PRED)   ;; use the N var as the new var
                    (CLASS (:* ONT::quantity ?sc)) (CONSTRAINT ?constr) 
                    (Sem ?sem)
                    ))
             (SORT PRED) (VAR ?v) (CASE (? case SUB OBJ))
             (WH ?w)  (WH-VAR ?whv));; must move WH feature up by hand here as it is explicitly specified in a daughter.
         -np-quan-plur-units>
         (SPEC (LF ?spec) (VAR ?specv)
               (ARG *)  
               (WH-VAR ?whv)
               (name-spec -) (mass ?m) 
               (POSS -)
               (WH ?w) (agr ?agr) (RESTR ?r) (NOSIMPLE -) ;(nobarespec +)
               (RESTR (& (QUAN ?!quan)))  ;; spec must be a quantifier
               )   
         (head (N1 (VAR ?v) (SORT unit-measure) (CLASS ?c) (MASS ?m) 
                   (KIND -) (agr ?agr) (RESTR ?restr) (sem ?sem)  (sem ($ f::abstr-obj (f::scale ?sc)))
		   (argument ?argument)
                 (post-subcat -)
                ))
	 (append-conjuncts (conj1 ?restr) (conj2 ?r) (new ?constr1))
         (add-to-conjunct (val (& (unit ?c))) (old ?constr1) (new ?constr))
         )
  


	;; CLASSIFIER NPS - acts as UNIT-MEASURE specifiers 
	;; e.g., a bunch (of grapes), a cup of water

	((NP (LF (% description (STATUS INDEFINITE)
		    (VAR ?v) (SORT unit-measure)
		    (CLASS (:* ONT::quantity ?sc))
		    (CONSTRAINT ?constr) (argument ?argument)
		    (sem ?sem) 
		    ))
	      (SPEC INDEFINITE) (unit-spec +) (VAR ?v) (SORT unit-measure))
         -pre-unit-np-number-indef>
	  (head (N (VAR ?v) (SORT attribute-unit) (Allow-before +) (LF (:* ?x ?unit))
		   (KIND -) (agr ?agr) (sem ?sem) (sem ($ f::abstr-obj (f::scale ?sc)))
		   (argument ?argument) (RESTR ?restr)
		   (post-subcat -)
		   ))
	 (NUMBER (val ?num) (VAR ?nv) (AGR ?agr) (restr ?r))
	 (append-conjuncts (conj1 ?restr) (conj2 ?r) (new ?constr1))
	 (add-to-conjunct (val (& (amount ?num) (unit ?unit))) (old ?constr1) (new ?constr))
	 )
	
	
       
        ;;  NP with SPECS that subcategorize for NP's
        ;;   all/both/half the boys
        
        ((NP (LF (% description (STATUS ?spec) (VAR ?specvar) (CLASS ?c) (CONSTRAINT ?newr)
		    (sem ?sem)  (transform ?transform)
		    ))
             (SORT PRED) (VAR ?specvar) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
         -np-spec-npplural>
         (SPEC (LF ?spec) (ARG ?v) (name-spec -) (mass ?m) (POSS -) (NPMOD +) (var ?specvar)
               (WH ?w) (agr ?agr) (RESTR ?restr) (SUBCAT (% ?n (sem ?subcatsem))))
	 (head (NP  (VAR ?v) (MASS ?m) 
		    (KIND -) (agr ?agr) 
                    (LF (% DESCRIPTION (CLASS ?c) (STATUS DEFINITE-plural) 
			   (CONSTRAINT ?r) (sem ?sem)
		           (transform ?transform)
		           ))))
	 (add-to-conjunct (val (refset ?v)) (old ?restr) (new ?r1))
	 (append-conjuncts (conj1 ?r1) (conj2 ?r) (new ?newr)))

	((NP (LF (% description (STATUS ?spec) (VAR ?specvar) (CLASS ?c) (CONSTRAINT ?newr)
		    (sem ?sem)  (transform ?transform)
		    ))
             (SORT PRED) (VAR ?specvar) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
         -np-spec-npmass>
         (SPEC (LF ?spec) (ARG ?v) (name-spec -) (MASS MASS) (POSS -) (NPMOD +) (var ?specvar)
               (WH ?w) (agr ?agr) (RESTR ?restr) (SUBCAT (% ?n (sem ?subcatsem))))
	 (head (NP  (VAR ?v)
		    (KIND -)  (MASS MASS)
                    (LF (% DESCRIPTION (CLASS ?c) (STATUS DEFINITE) 
			   (CONSTRAINT ?r) (sem ?sem)
		           (transform ?transform)
		           ))))
	 (add-to-conjunct (val (refset ?v)) (old ?restr) (new ?r1))
	 (append-conjuncts (conj1 ?r1) (conj2 ?r) (new ?newr)))

        ;;  BARE PLURALS  ---> KINDS

	;;  bare plural count; the set-restr can be a cardinality
	;; TEST: dogs, five dogs
        ((NP (var ?v) (LF (% Description (STATUS INDEFINITE-PLURAL)
;			     (constraint (& ?setr))
			     (CONSTRAINT ?r) (sem ?sem)
			     (VAR ?v) (CLASS ?c)))
	     (simple +)
	     (sem ?sem) (transform ?transform)
             (SORT PRED))
         -bare-plural-count> 
         ;; Myrosia 10/13/03 added a possibility of (mass bare) -- e.g. for "lunches" undergoing this rule
         (head (N1 (SORT PRED) (mass (? mass count bare)) (mass ?m)
		   (AGR 3p) (VAR ?v) (CLASS ?c) (RESTR ?r)
		   (sem ?sem) (transform ?transform)
		   (post-subcat -)
		   ))
	 )
		
        ;;  bare plural count nouns are sets
;        ((NP (LF (% Description (STATUS INDEFINITE) (VAR *) (SORT SET) (CONSTRAINT ?setr)
;                    (CLASS (SET-OF (% *PRO* (STATUS KIND) (VAR ?v) (CLASS ?c) (CONSTRAINT ?r))))
;                    (sem ?sem) (transform ?transform)))
;             (SORT PRED) (VAR *))
;         -bare-plural-count> 
;         ;; Myrosia 10/13/03 added a possibility of (mass bare) -- e.g. for "lunches" undergoing this rule
;         (head (N1 (SORT PRED) (mass (? mass count bare)) (mass ?m)
;                (AGR 3p) (VAR ?v) (CLASS ?c) (RESTR ?r) (SET-RESTR ?setr)
;                (sem ?sem) (transform ?transform)
;                (post-subcat -)
;                )))

        ;;  bare plural substance unit nouns are indefinite measures
	;;  gallons, bunches, ...

        ((NP (LF (% Description (STATUS indefinite) (VAR ?v)
	            (CLASS (:* ont::quantity ?sc)) (CONSTRAINT ?newr)
                    (sem ?sem)))
             (SORT AGGREGATE-UNIT) (SPEC INDEFINITE) (VAR ?v))
         -bare-measure-count> .98
         (head (N1 (SORT AGGREGATE-UNIT) (mass count) (mass ?m)
		(AGR 3p) (VAR ?v) (CLASS ?c) (RESTR ?r) 
		(sem ?sem)  (sem ($ f::abstr-obj (f::scale ?sc)))
		(post-subcat -)
		))
	 (add-to-conjunct (val (& (amount PLURAL) (unit ?c))) (old ?r) (new ?newr)))
  ;       (add-to-conjunct (val (:QUANTITY PLURAL)) (old ?r) (new ?newr)))

	;;  bare plural attribute unit nouns are indefinite measures
        ;;  length (inches, miles), degrees ...
	;; (ONT::A V451423 (:* ONT::QUANTITY F::LINEAR-S) :UNIT (:* ONT::LENGTH-UNIT W::METER) :QUANTITY  W::PLURAL)
	   ((NP (LF (% Description (STATUS indefinite) (VAR ?v)
	            (CLASS (:* ont::quantity ?sc)) (CONSTRAINT ?newr)
                    (sem ?sem)))
             (SORT UNIT-MEASURE) (SPEC INDEFINITE) (BARE +) (VAR ?v))
	    -bare-measure-attribute> .98
	    (head (N1 (SORT ATTRIBUTE-UNIT) (mass count) (mass ?m) (abbrev -) ;; don't allow bare form with abbreviations
		      (AGR 3p) (VAR ?v) (CLASS ?c) (RESTR ?r) 
		      (sem ?sem)  (sem ($ f::abstr-obj (f::scale ?sc)))
		      (post-subcat -) (abbrev -)
		      ))
	    (add-to-conjunct (val (& (:amount PLURAL) (unit ?c))) (old ?r) (new ?newr)))
	   
        ;;  bare plural mass nouns get SORT STUFF    ;;;  I don't think this is right JFA 12/02  "waters" is a count, isn't it

        ((NP (LF (% Description (STATUS INDEFINITE) (VAR ?v) (SORT STUFF) 
	            (CLASS ?c) (CONSTRAINT ?r) (sem ?sem) (transform ?transform)))
             (SORT PRED) (VAR ?v)
             )
         -bare-plural-mass>
         (head (N1 (SORT PRED) (mass mass) (MASS ?m) 
		(AGR 3p) (VAR ?v) (CLASS ?c) (RESTR ?r) 
		(sem ?sem) (transform ?transform)
		(post-subcat -)
		)))

        ;;  Bare singular - rare forms/telegraphic speech e.g., status report.
	;;  Also used for N1 conjunction "the truck and train"
        ((NP (LF (% Description (STATUS BARE) (VAR ?v) (SORT INDIVIDUAL)
	            (CLASS ?c) (CONSTRAINT ?r) (sem ?sem) (transform ?transform)))
             (SORT PRED) (VAR ?v)
             (BARE-NP +) (name-or-bare ?nob)
	     (simple +)
	     )
         -bare-singular> .98
         (head (N1 (SORT PRED) (MASS  count) (gerund -) (complex -) (name-or-bare ?nob)
		(AGR 3s) (VAR ?v) (CLASS ?c) (RESTR ?r) 
		(sem ?sem) (transform ?transform)
		)))

        ;;  COMMAS
        ;;  e.g., the train ,
        ((NP (LF ?r) (SORT ?sort) (VAR ?v))
         -np-comma>
         (head (NP (LF ?r) (SORT ?sort) (VAR ?v) (COMPLEX -))) (punc (Lex w::punc-comma)))
	;; reference/citations
	((NP (LF (% description (STATUS ?spec) (VAR ?v) 
		    (CLASS ?c) (CONSTRAINT ?newc)
		    (sem ?sem)  (transform ?transform)
		    ))
             (SORT PRED) (VAR ?v) (paren +)
	    (wh ?w) (wh-var ?whv);; must move WH feature up by hand here as it is explicitly specified in a daughter
	     )
         -np-parenthetical> 1
	 (head (NP (paren -)
		   (LF (% description (STATUS ?spec) (VAR ?v)
			  (CLASS ?c) (CONSTRAINT ?constr)
			  (sem ?sem)  (transform ?transform)
			  ))
		   (SORT PRED) (VAR ?v)
		   (wh ?w) (wh-var ?whv);; must move WH feature up by hand here as it is explicitly specified in a dauhter
		   ))
	 (parenthetical (var ?pv) (arg ?v))
	 (add-to-conjunct (val (parenthetical ?pv)) (old ?constr) (new ?newc)))

	((parenthetical (var ?cc) (arg ?arg))
	 -paren1> 1
	 (punc (lex (? x W::START-SQUARE-PAREN W::START-PAREN w::punc-comma)))
	 (head (Utt (LF (% W::SPEECHACT (constraint (& (content ?cc)))))))
	 (punc (lex  (? y W::END-SQUARE-PAREN W::END-PAREN w::punc-comma))))

	((parenthetical (var ?cc) (arg ?arg))
	 -paren2> 1
	 (punc (lex (? x W::START-SQUARE-PAREN W::START-PAREN W::punc-COMMA)))
	 (head (pred (var ?cc) (arg ?arg)))
	 (punc (lex  (? y W::END-SQUARE-PAREN W::END-PAREN w::punc-comma))))
	 
	 
        ;; NP -> WH-PRO
        ;;  e.g., who, what, ...
        
        ((NP (SORT PRED)
             (VAR ?v) 
	     (sem ?sem)
	     (lex ?lex) (WH Q) (WH-VAR ?v)
             (LF (% Description (status WH) (var ?v) (Class ?s) (SORT (?agr -))
	            (Lex ?lex) (sem ?sem) (transform ?transform)
		    (constraint (& (proform ?lex)))
		    )))
         -wh-pro1>
         (head (pro (PP-WORD -) (AGR ?agr) (LEX ?lex) (LF ?s)
		    (sem ?sem) (transform ?transform)
	            (VAR ?v) (WH Q))))    ;; removed R as NP 
        ))

;;  special rule for another as a bare NP  
;;  veentually I hope to replace this when we extend the capability of Lex definitions
(parser::augment-grammar 
 '((headfeatures (noop noop))
   	((NP (LF (% description (STATUS indefinite) (VAR *)   ;;(SORT individual)
		    (CLASS ONT::REFERENTIAL-SEM) 
		    (CONSTRAINT (& (MOD (% *PRO* (status F) (class ont::OTHER) (VAR **) (constraint (& (figure *)))))))
		    (sem ?sem)  (transform ?transform)
		    ))
	  (sem ?sem)
	  (SORT PRED) (VAR *) (CASE (? case SUB OBJ))
	  (wh -) (wh-var -)
	  )
         -np-another-bare>  .97
	 (head (word (lex w::another) 
	 )))))


(parser::augment-grammar 
 '((headfeatures
    (NP SEM ARGUMENT SUBCAT role lex headcat transform postadvbl refl abbrev))
    
	;;  five pounds, thirty feet  -- because of the sort UNIT-MEASURE, these generally end up a specifiers, not main NPS
	((NP (LF (% description (STATUS INDEFINITE)
		    (VAR ?v) (SORT unit-measure) 
		    (CLASS (:* ONT::quantity ?sc))
		    (CONSTRAINT ?constr) (argument ?argument)
		    (sem ?sem) 
		    ))
	  (class (:* ont::quantity ?sc))
	  (SPEC INDEFINITE) (AGR 3s) (unit-spec +) (VAR ?v) (SORT unit-measure))
         -unit-np-number-indef>
	 (NUMBER (val ?num) (VAR ?nv) (AGR ?agr) (restr ?r))
 	 (head (N1 (VAR ?v) (SORT unit-measure) (INDEF-ONLY -) (CLASS ?c) (MASS ?m)
		   (KIND -) (sem ?sem) (sem ($ f::abstr-obj  (f::scale ?sc)))
		   (argument ?argument) (RESTR ?restr)
		   (post-subcat -)
		))
         (add-to-conjunct (val (& (value ?num))) (old ?r) (new ?newr))
	 (add-to-conjunct (val (& (amount (% *PRO* (status indefinite) (class ont::NUMBER) (VAR ?nv) (constraint ?newr)))
				  (unit ?c))) (old ?restr) (new ?constr))
	 )

   ;;  NP with SPECS that subcategorize for "of" PP's that are count and definite
   ;;    all of the boys, a bunch of the people, most of the trucks, some of them,
   ;;  Its has its own set of head features because the AGR feature comes from the SPEC, not the head
   
    ((NP (LF (% description (STATUS ?spec) (VAR *) (CLASS ?c) (CONSTRAINT ?newr)
                (sem ?sem)  (transform ?transform) 
                ))
	 (case ?case)
         (SORT PRED) (AGR ?agr)
	 (MASS count)
	 (VAR *) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
     -np-spec-of-count-def-pp>
     (SPEC (LF ?spec) (ARG ?v) (VAR ?specvar) (name-spec -) (mass count) 
      (POSS -);;myrosia 12/27/01 added mass restriction to spec
      (WH ?w) 
      (RESTR ?restr)
      (SUBCAT (% PP (Ptype ?ptp) (agr |3P|) (SEM ?sem))))
     (head 
      (PP  (VAR ?v) (MASS count) (ptype ?ptp)
       (KIND -) (AGR |3P|) (GAP -)
       (LF (% DESCRIPTION (CLASS ?c)
	      (sem ?sem) (transform ?transform) (constraint ?con)
		  ))))
     (append-conjuncts (conj1 (& (REFSET ?v))) ;;(quan ?card)
      (conj2 ?restr) (new ?newr)))
     

   ;;  NP with SPECS that subcategorize for "of" PP's that are definite singular/mass
   ;; all of the water, most of the truck
   ((NP (LF (% description (STATUS ?spec) (VAR *) (CLASS ?c) (CONSTRAINT ?newr)
	       (sem ?sem)  (transform ?transform) 
                ))
     (case ?case)
     (SORT PRED)
     (MASS mass)
     (VAR *) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
     -np-spec-of-def-sing-pp>
    (SPEC (LF ?spec) (ARG ?v) (VAR ?specvar) (name-spec -) (mass mass) (POSS -);;myrosia 12/27/01 added mass restriction to spec
     (WH ?w)
     (RESTR ?restr)
     (SUBCAT (% PP (Ptype ?ptp) (agr |3S|) (SEM ?sem))))
    (head 
     (PP  (VAR ?v) (MASS ?mass) (ptype ?ptp)
	  (KIND -) (GAP -) (agr |3S|)
	  (LF (% DESCRIPTION (CLASS ?c) (sem ?sem) 
		 (transform ?transform) (status (? xx definite definite-plural)))
		  )))
    
    (append-conjuncts (conj1 (& (REFOBJECT ?v) (size ?card))) (conj2 ?restr) (new ?newr))
    )

   ;;  NP with SPECS that subcategorize for "of" PP's that are plural
   ;; 25% of the trucks, most of the people
   ((NP (LF (% description (STATUS indefinite-plural) (VAR *) (CLASS ?c) (CONSTRAINT ?newr)
	       (sem ?sem)  (transform ?transform) 
                ))
     (case ?case) (agr 3p)
     (SORT PRED)
     (MASS mass)
     (VAR *) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
     -np-spec-of-def-plur-pp>
    (SPEC (LF ?spec) (ARG ?v) (VAR ?specvar) (name-spec -) (POSS -);;myrosia 12/27/01 added mass restriction to spec
     (WH ?w)
     (RESTR ?restr)
     (SUBCAT (% PP (Ptype ?ptp) (agr |3S|) (SEM ?sem))))
    (head 
     (PP  (VAR ?v) (MASS ?mass) (ptype ?ptp)
	  (KIND -) (GAP -) (agr 3p)
	  (LF (% DESCRIPTION (CLASS ?c) (sem ?sem) 
		 (transform ?transform) (status (? xx definite definite-plural)))
		  )))
    
    (append-conjuncts (conj1 (& (REFOBJECT ?v) (size ?card))) (conj2 ?restr) (new ?newr))
    )
   

   ;;  CLASSIFIER Constructions
   ;;   a bunch of people, a set of numbers, a bunch of sand
      ((NP (LF (% description (STATUS ?spec) (VAR ?v) (CLASS ?c) (CONSTRAINT ?newr)
                (sem ?sem)  (transform ?transform) 
                ))
	 (case ?case)
         (SORT PRED) (AGR ?agr)
	 (MASS count)
	 (VAR ?v) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
     -np-classifier-of-pp>
       (NP  (LF (% description (STATUS ?spec) (VAR ?v) (CLASS ?c) (CONSTRAINT ?restr)
                (sem ?sem)  (transform ?transform) 
                ))
	(case ?case)
	(SORT CLASSIFIER) (AGR ?agr)
	(MASS count)
	(VAR ?v) (WH ?w)
	(argument-map ?!argmap)
	(argument (% PP (ptype ?ptp) (agr ?ppagr) (mass ?mass))))
       (head 
	(PP  (VAR ?ppv) (MASS ?mass) (ptype ?ptp)
	     (KIND -) (AGR ?ppagr) (GAP -) 
	     ))
       (append-conjuncts (conj1 (& (?!argmap ?ppv))) (conj2 ?restr) (new ?newr))
       )
      
   ;;  NP with SPECS that subcategorize for "of" PP's that are mass and indefinite
    ;; e.g., three gallons of water
   ((NP (LF (% description (STATUS ?spec) (VAR *) (CLASS ?c) (CONSTRAINT ?newr)
	       (sem ?sem)  (transform ?transform) 
	       ))
     (case ?case)
     (SORT PRED)
     (MASS mass)
     (VAR *) (WH ?w));; must move WH feature up by hand here as it is explicitly specified in a daughter.
    -np-spec-of-mass-idef-pp>
    (SPEC (LF ?spec) (ARG ?v) (VAR ?specvar) (name-spec -) (mass mass) (POSS -);;myrosia 12/27/01 added mass restriction to spec
     (WH ?w)
     (RESTR ?restr)
     (SUBCAT (% PP (Ptype ?ptp) (SEM ?sem))))
    (head 
     (PP  (VAR ?v) (MASS mass) (ptype ?ptp)
	  (KIND -) (GAP -)
	  (LF (% DESCRIPTION (CLASS ?c) (sem ?sem) (constraint ?constr)
		 (transform ?transform) (status (? st bare indefinite-plural))
		 ))))
                 
    (append-conjuncts (conj1 ?constr) (conj2 ?restr) (new ?newr))
    )
   ))

(parser::augment-grammar 
  '((headfeatures
     (NP VAR SEM agr ARGUMENT SUBCAT role lex headcat transform)
     (SPEC POSS POSS-VAR POSS-SEM comparative lex transform headcat) ;; NObareSpec
     (QUANP CARDINALITY VAR AGR comparative headcat)
     (ADJP headcat lex)
     )

    ;;  a four cycle engine, a two-trick pony, a one horse town, ...
    ((ADJP (ARG ?arg) (VAR *) (sem ?sem) (atype central) (comparative -) (argument ?aa)
      (LF (% PROP (CLASS ONT::ASSOC-WITH) (VAR *) 
	     (CONSTRAINT (& (of ?arg) 
			    (val (% *PRO* (status KIND) (var ?nv) 
				    (CLASS ?c) (CONSTRAINT ?con)))))
				    
	     (Sem ?sem)))
      (transform ?transform))
     -adj-number-noun> .97    ;; this is very rare 
     (NUMBER  (val ?sz) (VAR ?nv) (restr -))
     (Gt (arg1 ?sz) (arg2 0))   ;; negative numbers don't work as cardinailty adjectives!
     (head (N (VAR ?v) (LF ?c) (Mass count) (sort PRED)
	      (KIND -) (agr 3s) (one -) ;; don't allow "one" as the N!
	      (RESTR ?restr) (sem ($ (? ss  F::PHYS-OBJ F::SITUATION-ROOT  F::ABSTR-OBJ)))
	      (transform ?transform) (postadvbl -)
	      (post-subcat -)
	      ))
    (add-to-conjunct (val (amount ?sz)) (old ?restr) (new ?con)))

      ;; version of adj-number-noun with units -- creates quantities, not sets
    ;; a 10 foot fence, 2 week vacation
    ((ADJP (ARG ?arg) (VAR *) (sem ?sem) (atype ?atype) (comparative -) (argument ?aa)
      (SORT unit-measure)
      (LF (% PROP (CLASS ONT::ASSOC-WITH) (VAR *) 
	     (CONSTRAINT (& (of ?arg) 
			    (val (% *PRO* (status INDEFINITE) (var ?nv) 
				    (CLASS (:* ont::quantity ?sc))
				    (CONSTRAINT ?constr)))))
	     (Sem ?sem)))					
      (transform ?transform))
     -adj-number-unit-modifier>
     (NUMBER  (val ?sz) (VAR ?nv) (restr -))
     (head (N1 (VAR ?v) (SORT unit-measure) (INDEF-ONLY -) (CLASS ?c) (MASS ?m) 
	       (KIND -) ;;(agr 3s)   we allow either 61 year old or 61 years old
	       (sem ?sem)  (sem ($ f::abstr-obj (f::scale ?sc)))
	       (RESTR ?restr) (transform ?transform)
	       (postadvbl -) (post-subcat -)
	       ))
     (add-to-conjunct (val (& (amount ?sz) (unit ?c))) (old ?restr) (new ?constr))
     )

    ;; and often has a hyphen
    ((ADJP (ARG ?arg) (VAR *) (sem ?sem) (atype ?atype) (comparative -) (argument ?aa)
      (LF (% PROP (CLASS ONT::ASSOC-WITH) (VAR *) 
	     (CONSTRAINT (& (of ?arg) 
			    (val (% *PRO* (status INDEFINITE) (var ?nv) 
				    (CLASS (:* ont::quantity ?sc))
				    (CONSTRAINT ?constr)))))
	     (Sem ?sem)))
      (SORT unit-measure)
      (transform ?transform))
     -adj-number-unit-modifier-hyphen> 1.1
     (NUMBER  (val ?sz) (VAR ?nv) (restr -))
     (Punc (lex W::punc-minus))
     (head (N1 (VAR ?v) (SORT unit-measure) (INDEF-ONLY -) (CLASS ?c) (MASS ?m) 
	       (KIND -) (agr 3s) (sem ?sem)  (sem ($ f::abstr-obj (f::scale ?sc)))
	       (RESTR ?restr) (transform ?transform)
	       (postadvbl -) (post-subcat -)
	       ))
     (add-to-conjunct (val (& (amount ?sz) (unit ?c))) (old ?restr) (new ?constr))
     )

    ;; version of adj-number-noun with unit before number, e.g., (a) $ 10 (watch)
    ((ADJP (ARG ?arg) (VAR *) (sem ?sem) (atype ?atype) (comparative -) (argument ?aa)
      (SORT unit-measure)
      (LF (% PROP (CLASS ONT::ASSOC-WITH) (VAR *) 
	     (CONSTRAINT (& (of ?arg) 
			    (val (% *PRO* (status INDEFINITE) (var ?nv) 
				    (CLASS (:* ont::quantity ?unit))
				    (CONSTRAINT ?constr)))))
	     (Sem ?sem)))					
      (transform ?transform))
     -adj-number-pre-unit-modifier>
      (head (N (VAR ?v) (SORT attribute-unit) (Allow-before +) (LF (:* ?x ?unit))
		   (KIND -) (agr ?agr) (sem ?sem) (sem ($ f::abstr-obj (f::scale ?sc)))
		   (argument ?argument) (RESTR ?restr)
		   (post-subcat -)
		   ))
     (NUMBER  (val ?sz) (var ?nv) (restr -))
     (add-to-conjunct (val (& (amount ?sz) (unit ?c))) (old ?restr) (new ?constr))
     )

      ;; turn unit NPs into specs
    ;;  e.g., a gallon (of water)
       
    ((SPEC (AGR ?agr)
      (VAR *) 
      (ARG ?arg) (lex ?lex) (LF SM) (SUBCAT ?subcat) (Mass MASS)
      (unit-spec +)
      (restr (& (quantity ?unit-v)))) ;; mass nouns get QUANTITY in the restriction
     -spec-indef-unit-mass>
     (head (NP (sort unit-measure) (LF (% DESCRIPTION (status (? status indefinite indefinite-plural))))
	     (ARGUMENT ?subcat) (ARGUMENT (% ?xx (MASS MASS)))
	    (var ?unit-v) (lex ?unit-lex) )))

    ;;  e.g., the gallon (of water)
       
    ((SPEC (AGR ?agr)
      (VAR *) 
      (ARG ?arg) (lex ?lex) (LF DEFINITE) (SUBCAT ?subcat) (Mass MASS)
      (unit-spec +)
      (restr (& (quantity ?unit-v)))) ;; mass nouns get QUANTITY in the restriction
     -spec-def-unit-mass>
     (head (NP (sort unit-measure) (LF (% DESCRIPTION (status (? status definite definite-plural))))
	     (ARGUMENT ?subcat) (ARGUMENT (% ?xx (MASS MASS)))
	    (var ?unit-v) (lex ?unit-lex) )))


    ;;  e.g., the three gallons, all three gallons, also each three gallons (quantifying over sets of quantities)

    ((SPEC (AGR 3s)
      (VAR *) 
      (ARG ?arg) (lex ?lex) (LF ?speclf) (SUBCAT ?subcat) (Mass MASS)
      ;; (NOSIMPLE +)  disabled to allow three gallons water.
      (unit-spec +)
      (restr ?new))
     -spec-quan-unit-mass>
     (spec (LF ?speclf) (agr ?agr) (complex -) (restr ?restr) (agr 3s))  ;; singular AGR as its a mass term we'll be constructing
     (head (NP (sort unit-measure)
	     (ARGUMENT ?subcat) (ARGUMENT (% ?xx (MASS MASS)))
	    (var ?unit-v) (lex ?unit-lex)))
     (add-to-conjunct (val (quantity ?unit-v)) (old ?restr) (new ?new)))

 #||   ;; e.g., a bunch of trucks
    
    ((SPEC (SEM ?def) (AGR ?agr)
      (VAR *) (card ?unit-v)     
      (ARG ?arg) (lex ?lex) (LF ?spec) (SUBCAT ?subcat) (Mass COUNT)
      (NOSIMPLE +) (unit-spec +)
      (restr (& (size ?unit-v)))) ;; count nouns get SIZE in the restriction
     -spec-unit-count>
     (head (NP (sort classifier)
	    (SPEC ?spec) (ARGUMENT ?subcat) (ARGUMENT (% ?xx (MASS COUNT) (AGR ?agr)))
	    (var ?unit-v) (lex ?unit-lex))))||#


     ;;  QUANTIFIERS
    
    ;; e.g., basic quantification with no-cardinality quantifiers: all trucks, no luck, every person ...
    ((SPEC (ARG ?arg) (VAR *) (agr ?agr) (MASS ?m) (LF ?status) (Nobarespec ?nbs)  (comparative ?cmp)
      (RESTR (& (QUAN ?s) (negation ?neg) )) (NoSimple ?ns) (npmod ?npm)
      (SUBCAT ?qof) (QCOMP ?Qcomp) (PRED ?s))
     -quan-simple-spec>
     (head (quan (CARDINALITY -) (SEM ?sem) (VAR ?v) (agr ?agr) (comparative ?cmp) (QOF ?qof) (QCOMP ?Qcomp)
		 (MASS ?m) (STATUS ?status) (Nobarespec ?nbs) (NoSimple ?ns) (npmod ?npm) (negation ?neg)
		 (LF ?s))))

 #|| ;;  this is not right -- "more than 20 trucks" parses as a SPEC in a headless NP!
  ;; quantifier with complement , e.g. more than that, enough to weigh it down, ...
    ((SPEC (ARG ?arg) (VAR *) (MASS ?m) (agr ?agr) (LF W::indefinite-plural) (Nobarespec ?nbs)  (comparative ?cmp)
	   ;;(NoSimple +)
	   (npmod ?npm)
	   (SUBCAT ?qof) (QCOMP ?Qcomp) (PRED ?s)
	   (RESTR ?restr)
#||(& (% *PRO* (STATUS INDEFINITE)
			 (VAR **)
			 (CLASS ONT::NUMBER)
			 (CONSTRAINT
			  (& (MODS (% *PRO* (STATUS F)
				      (VAR ***)
				      (CLASS ?pred)
				      (CONSTRAINT (& (figure **) (GROUND ?psvar) (DIFF ?card))))))))))||#
      )
     -quan-than-X>
     (head (SPEC (LF ?spec) (VAR ?specv) (agr ?agr)
		 (WH-VAR ?whv) (MASS ?m)
		 (name-spec -)
		 (POSS -)
		 (WH ?w) (RESTR ?set-restr) (NOSIMPLE -) (pred ?pred)
		 (QCOMP (% ?!cat (VAR ?psvar)))
		 (QCOMP ?qcomp)))
     ?qcomp
     (add-to-conjunct (val (size (% *PRO* (STATUS INDEFINITE)
				      (VAR **)
				      (CLASS ONT::NUMBER)
				      (CONSTRAINT
				       (& (MODS (% *PRO* (STATUS F)
						   (VAR ***)
						   (CLASS ?pred)
						   (CONSTRAINT (& (figure **) (GROUND ?psvar) (DIFF ?card))))))))))
      (old ?set-restr) (new ?restr))
			     
     )
||#

    ;; cardinality quantifiers goes to SIZE rather than OP
    ;; TEST: some dogs
    ((SPEC (ARG ?arg) (VAR *) (agr ?agr) (MASS  (? m count bare)) (LF ?status) (Nobarespec ?nbs) 
          ;; (SUBCAT (% N1 (SEM ?subsem) (agr ?agr))) ;; The subcat isn't being used for the simple form yet - if we need it, we'll have to 
                                                    ;;  modifier the ordinal/cardinal rules
	   (subcat ?qof) (qcomp ?qcomp) (cardinality +)
           (restr (& (size ?s)))
	   (NoSimple ?ns) (npmod ?npm))
     -quan-card-def-simple-spec>
     (head (quan (CARDINALITY +) (SEM ?sem) (VAR ?v) (agr ?agr) (MASS (? m COUNT BARE)) (STATUS ?status)
		 (Nobarespec ?nbs) (NoSimple ?ns) (npmod ?npm)
		 (qof ?qof) (qcomp ?qcomp)
		 (LF ?s))))
     
    ;;  building quans with "not", e.g., not all trucks
    ;; not too/so much??
    ((quan (SEM ?sem) (VAR ?v) (MASS ?m) (AGR ?agr) (STATUS ?status) (Nobarespec ?nbs) (LF ?s) (negation +)
           (Nosimple ?ns) (NPmod ?nm) )
     -not-quan>
     (word (lex not))
     (head (quan  (negatable +) (SEM ?sem) (VAR ?v) (agr ?agr) (MASS ?m) (AGR ?agr) 
                  (STATUS ?status) (Nobarespec ?nbs) 
                  (Nosimple ?ns) (NPmod ?nm) (LF ?s))))

     ;;  Special rule for every third, every fifth, ...
    
    ((SPEC (ARG ?arg) (VAR ?v) (agr ?agr) (MASS ?m) (LF QUANTIFIER)
           (SUBCAT (% PP (ptype of))) (RESTR (& (QUAN EVERY) (SEQUENCE ?q)))
           )
     -quan-every-nth>
     (head (quan (VAR ?v) (agr 3s) (MASS ?m) (LF EVERY) (STATUS QUANTIFIER)))
     (ordinal (LF ?q)))

    ;; every five ....
     ((SPEC (ARG ?arg) (VAR ?v) (agr ?agr) (MASS ?m) (LF QUANTIFIER)
           (SUBCAT (% PP (ptype of))) (RESTR (& (QUAN EVERY) (AMOUNT ?num)))
           )
     -quan-every-num>
     (head (quan (VAR ?v) (agr 3s) (MASS ?m) (LF EVERY) (STATUS QUANTIFIER)))
     (number (val ?num)))
    
    ;; Infinitive NPS -- to be is divine
    ((np (SORT PRED)
         (gap -) (var ?v)  (agr 3s)
         (sem ?sem) (mass bare)
         (case sub)      
         (lf (% description (status KIND) (VAR ?v) 
	        (class ?class) 
	        (constraint ?con) (sort individual)
	        (sem ?sem) (transform ?transform)
	        )))
     -infinitive-np> 0.96 ;; don't want to consider it unless there are no other interpretations
     (head (cp (ctype s-to) 
	       (var ?v)  
               (gap -)
               (sem ?sem)
               (lf (% prop (class ?class) (constraint ?con) (transform ?transform)))))
     )


    ; TEST: the quickly loaded truck ; the quickly computer generated truck
     ;; Myrosia 11/26/01 we only allow those phrases before the verbs. After the verbs, they should be treated as reduced relative clauses
     ((ADJP (ARG ?arg) (VAR ?v) 
	    (SUBCATMAP ont::affected) (ARGUMENT ?subj)
	    (atype central) 
	    (LF (% PROP (class ?lf) (VAR ?v) (constraint ?newc)))           
      )
     -vp-pastprt-adjp>
     (head
      (vp- (class ?lf) (constraint ?cons) (var ?v)
	   (SUBJ-MAP ont::affected) (SUBJ ?subj) ;; more general to ask for SUBJ to be AFFECTED role, includes
 	                                         ;; the passive as well as unaccusative cases
	   (gap -) ;;  no gap in the VP
	   (vform (? pp passive pastpart))
	   (complex -)
           (advbl-needed -)
           ))
     (append-conjuncts (conj1 ?cons) (conj2 (& (ont::affected ?arg))) (new ?newc))
     )

    ;; TEST: the loaded truck
    ;; bare passive form as an adjective
    ;; Verb must be passive, and require no complement  
    ((VP- (VAR ?v)  (arg ?arg) (class ?lf)
	  (subj-map ?!reln) (subj ?subj) (VFORM (? vf PASSIVE))
	  (LF (% prop (constraint ?cons) (class ?lf) (VAR ?v)))
      )
     -simple-v-passive-for-adj> 0.97
     (head (V (VFORM (? vf PASSIVE)) (COMP3 (% - )) (DOBJ (% -)) (GAP -) (LF ?lf)
              (SUBJ-MAP ?!reln) (SUBJ ?subj)
              (VAR ?v)
              )
      ))

    ;; TEST: the computer-generated dog
    ((ADJP (VAR ?v)  (arg ?dobj) (class ?lf) (atype w::central) (argument (% NP (var ?dobj)))
      (vform passive) (constraint ?constraint)
      (LF (% prop (class ?lf) (var ?v)
	     (constraint 
	      (& (?!reln (% *PRO* (status kind) (var ?v-n) (class ?nc) (constraint ?nr) (sem ?sem)))
		 (?dobj-map ?dobj))))))
     -adj-passive+subj-hyphen> 1
     (n1 (sort ?sort) (CLASS ?nc) (RESTR ?nr) (status ?status) (complex -) (var ?v-n) 
      (sem ?sem) (relc -) (abbrev -)
	 )
     (punc (lex w::punc-minus))
     (head (V (var ?v) (VFORM pastpart) (DOBJ (% NP (var ?dobj)))
      (GAP -) (LF ?lf)  (part (% -)) ;; no particle forms
      (SUBJ-MAP ?!reln) (dobj-map ?dobj-map)
      ))
     )

    ;; TEST: the computer generated dog
    ((ADJP (VAR ?v)  (arg ?dobj) (class ?lf) (atype w::central) (argument (% NP (var ?dobj)))
      (vform passive) (constraint ?constraint)
      (LF (% prop (class ?lf) (var ?v)
	     (constraint 
	      (& (?!reln (% *PRO* (status kind) (var ?v-n) (class ?nc) (constraint ?nr)))
		 (?dobj-map ?dobj))))))
     -adj-passive+subj> 
     (n1 (sort ?sort) (CLASS ?nc) (RESTR ?nr) (status ?status) (complex -) (gerund -)(var ?v-n) 
      (sem ?sem) (relc -) (abbrev -)
	 )
     (head (V (var ?v) (VFORM pastpart) (DOBJ (% NP (var ?dobj)))
      (GAP -) (LF ?lf) (Part (% -))
      (SUBJ-MAP ?!reln) (dobj-map ?dobj-map)
      ))
     )

    
    ;; TEST: the Ras-dependent activation
    ((ADJP (VAR ?v) (arg ?arg) (class ?lf) (atype w::central) (argument ?argument)
      (constraint ?constraint)
      (LF (% prop (class ?lf) (var ?v)
	     (constraint 
	      (& (?sc-map (% *PRO* (status BARE) (var ?v-n) (class ?nc) (constraint ?nr) (sem ?sem)))
		  (?arg-map ?arg))))))
     -adj-subcat-hyphen> 1
     (n1 (sort ?sort) (CLASS ?nc) (RESTR ?nr) (status ?status) (complex -) (var ?v-n) 
      (sem ?sem) (relc -) (abbrev -)
	 )
     (punc (lex w::punc-minus))
     (head (ADJ (var ?v) (SUBCAT (% PP (var ?sc)))
      (GAP -) 
      (LF ?lf)
      (SUBCAT-MAP ?sc-map)
      (ARGUMENT-MAP ?arg-map)
      (ARGUMENT ?argument)
      ))
     )
    
    ;; TEST: the Ras dependent activation
    ((ADJP (VAR ?v) (arg ?arg) (class ?lf) (atype w::central) (argument ?argument)
      (constraint ?constraint)
      (LF (% prop (class ?lf) (var ?v)
	     (constraint 
	      (& (?sc-map (% *PRO* (status BARE) (var ?v-n) (class ?nc) (constraint ?nr) (sem ?sem)))
		  (?arg-map ?arg))))))
     -adj-subcat-nohyphen> 1
     (n1 (sort ?sort) (CLASS ?nc) (RESTR ?nr) (status ?status) (complex -) (var ?v-n) 
      (sem ?sem) (relc -) (abbrev -)
	 )
;     (punc (lex w::punc-minus))
     (head (ADJ (var ?v) (SUBCAT (% PP (var ?sc)))
      (GAP -) 
      (LF ?lf)
      (SUBCAT-MAP ?sc-map)
      (ARGUMENT-MAP ?arg-map)
      (ARGUMENT ?argument)
      ))
     )
    
    ;;#||  This doesn't really work as the COMP3 for "hire" is the THEME, and DOBJ is the RECIPIENT
    ;;   so we get the RECIPIENT role for "A hired employee"
;     ((ADJP (ARG ?arg) (VAR ?v)  (SUBCATMAP ?!reln) (atype attributive-only)
;           (ARGUMENT ?subj) (sem ?sem)
;           (LF (% PROP (class ?lf) (VAR ?v)
;                  (CONSTRAINT (& (?!reln ?arg)))
;                  (transform ?transform)
;                  ))           
;      )
;     -adj-passive-optional> 0.97
;     (head (V (VFORM PASSIVE) (COMP3 (% ?x (optional +))) (DOBJ (% -)) (GAP -) (LF ?lf) 
;              (SUBJ-MAP ?!reln) (SUBJ ?subj)
;              (VAR ?v) (transform ?transform)
;              )
;      ))
;    
    ;;  bare ing form as an adjective (e.g., the running truck)
    ((ADJP (ARG ?arg) (VAR ?v)  (SUBCATMAP ?!reln) (atype attributive-only)
           (ARGUMENT ?subj)
           (LF (% PROP (class ?lf) (VAR ?v) 
;                  (CONSTRAINT (& (?!reln ?arg) (mod ?prefix)))
                  (CONSTRAINT ?newc)
                  (transform ?transform)
		  ))
           )
     -adj-ing> ;;0.98
     (head (V (VFORM (? vf ING)) (COMP3 (% - )) ;;(DOBJ (% -)) 
	      (GAP -) (LF ?lf) 
              (SUBJ-MAP ?!reln) (SUBJ ?subj)
              (VAR ?v) (transform ?transform)
;	      (prefix ?prefix)
	      (restr ?prefix)
              )
           )
     (append-conjuncts (conj1 ?prefix) (conj2 (& (?!reln ?arg)))
		       (new ?newc))

     )


  ;; the phosphorylating Ras (phosphorylating has an optional LOC role)
 ((ADJP (ARG ?arg) (VAR ?v)  (SUBCATMAP ?!reln) (atype attributive-only)
           (ARGUMENT ?subj)
           (LF (% PROP (class ?lf) (VAR ?v) 
;                  (CONSTRAINT (& (?!reln ?arg) (mod ?prefix)))
                  (CONSTRAINT ?newc)
                  (transform ?transform)
		  ))
           )
     -adj-ing-opt-comp3> 0.98
     (head (V (VFORM (? vf ING)) (COMP3 (% ?!xx (w::optional +)))
	      (GAP -) (LF ?lf) 
              (SUBJ-MAP ?!reln) (SUBJ ?subj)
              (VAR ?v) (transform ?transform)
;	      (prefix ?prefix)
	      (restr ?prefix)
              )
           )
     (append-conjuncts (conj1 ?prefix) (conj2 (& (?!reln ?arg)))
		       (new ?newc))

     )
 
 ))

;; PP-WORDS

(parser::augment-grammar 
  '((headfeatures
     (NP VAR SEM LEX wh case lex headcat transform postadvbl)
     (SPEC POSS POSS-VAR POSS-SEM  transform) 
     (ADVBL VAR SEM LEX ATYPE lex headcat transform neg)
     (ADVBL-R VAR SEM LEX ATYPE argument wh lex headcat transform)
     (QUANP CARDINALITY AGR)
     (N1 lex headcat set-restr refl abbrev nomobjpreps nomsubjpreps)
     (ADJP lex headcat argument transform)
     )

;;;     ;; lexicalized quantifier phrases, e.g., all, several, ...
;;;    ;; currentl we simply make the LF into the VAR to allow simple atoms in the :QUAN slot.
;;;    ;;  may need to change later 
;;;    ((QUANP (ARG ?arg) (AGR ?agr) (VAR ?s) (SEM ?sem)
;;;	    (MASS (? m count bare)) (STATUS ?status) 
;;;	  (Nobarespec ?nbs)
;;;	  )
;;;     -lex-quan>
;;;     (head (quan (SEM ?sem) (VAR ?v) (agr ?agr) (MASS ?m) (STATUS ?status) (Nobarespec ?nbs) (NoSimple ?ns) (npmod ?npm)
;;;	    (LF ?s)))
;;;     )

    ;;   HOW much, many, few   - I haven't found a generalization yet  that excludes "How several", so we enumerate - sorry! JFA 02/03
    ;; its in its own rule cluster here because I don't want the LEX to be a head feature
    
    ((SPEC (LF wh-quantity) (Lex (How ?l)) (headcat QUAN) (STATUS WH) (AGR ?a)
          (ARG ?arg) (MASS ?m) (WH Q) (WH-VAR *) (QUANT +) (VAR ?v)
          (RESTR (& (SIZE (% *PRO* (STATUS WH) (VAR *) (CLASS ont::QUANTITY) (CONSTRAINT (& (QUAN ?lf)))))))
          (SUBCAT (% PP ))
          )
     -how-many-etc>
     (word (lex how))
     (head (quan (sem ?def) (LF ?lf) (MASS (? mss COUNT bare)) (AGR ?a) (VAR ?v) (lex (? x MANY FEW)))))

    ((SPEC (LF wh-quantity) (Lex (How ?l)) (headcat QUAN) (STATUS WH) (AGR ?a)
          (ARG ?arg) (MASS ?m) (WH Q) (WH-VAR *) (QUANT +) (VAR ?v)
          (RESTR (& (QUANTITY (% *PRO* (STATUS WH) (VAR *) (CLASS ont::QUANTITY) (CONSTRAINT (& (QUAN ?lf)))))))
          (SUBCAT (% PP ))
          )
     -how-much>
     (word (lex how))
     (head (quan (sem ?def) (LF ?lf) (MASS MASS) (AGR ?a) (VAR ?v) (lex MUCH))))
        
    ;; VPs as gerund-NPS
    ((NP (SORT PRED)
         (gap -) (var ?v) (agr 3s)
         (sem ?sem) (mass mass) (gerund +) (class ?class)
         (case (? case sub obj -)) ;; gerunds aren't case marked, allow any value except posessive
         (lf (% description (status bare) (VAR ?v) 
                (class ?class) 
                (constraint ?con) (sort individual)
                (sem ?sem) (transform ?transform)
                ))
	 )
     -gerund> ;;.97
     (head (vp (vform ing) (var ?v) (gap -) (aux -)
               (sem ?sem) 
	       (class ?class)  (constraint ?con)  (transform ?transform)
	       ))
     )
#||   THis is replace by new nominlaization handling
    ((NP (SORT PRED)
      (gap -) (var ?v) (agr 3s)
      (sem ?sem) (mass mass) (gerund +) (class ?class)
      (case (? case sub obj -)) ;; gerunds aren't case marked, allow any value except posessive
      (lf (% description (status bare) (VAR ?v) 
	     (class ?class) 
	     (constraint ?con) (sort individual)
	     (sem ?sem) (transform ?transform)
	     ))
      )
     -gerund-w-subj>
     (np (sem ?npsem) (var ?subjvar) (agr ?a) (case (? casesubj sub -)) (lex ?lex) ;; lex needed for expletives?
      (pp-word -) (changeagr -))
     (head (vp (vform ing) (var ?v) (gap -) (aux -)
               (sem ?sem) (subjvar ?subjvar)
	       (subj (% np (sem ?npsem) (var ?subjvar) (lex ?lex)))
	       (class ?class)  (constraint ?con)  (transform ?transform)
	       ))
     )||#
    
;;   NEW RULES FOR HANDLING NOMINALIZATIONS

  

    ;; and we have explicit nominalizations (current any N of type EVENT-OF-CHANGE)
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr ?agr)
      (sem ?sem) (mass ?mass)
      (case (? case sub obj -)) ;; noms aren't case marked, allow any value except posessive
      (class ?class)
      (dobj ?dobj)
      (subj ?subj)
      (comp3 ?comp3)
      (subj-map ?subjmap)
      (dobj-map (? !dmap ONT::NOROLE))
      (comp3-map ?comp-map)
      (restr ?newr)
      
      )
     -n1-nom-with-obj> 1
      (head (n  (var ?v) (gap -) (aux -) (agr ?agr) (sort pred)
		(sem ?sem)  (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(LF ?class) (transform ?transform)
            ;; these are dummy vars for trips-lcflex conversion, please don't delete
            ;;(subj ?subj) (dobj ?dobj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
	    (dobj ?dobj)
	    (dobj (% NP (var ?dobjvar)))
	    (subj ?subj)
	    (subj (% NP (var ?subjvar)))
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map (? !dmap ONT::NOROLE))  ; this is so "Ras causes the inhibition of MMP-9 activation." won't be able to use this template to assign NOROLE to MMP-9
	    (comp3-map ?comp-map)
	    (generated -)
	    (restr ?r)
	    ))
      (add-to-conjunct (val (& (?subjmap ?subjvar) ((? !dmap ONT::NOROLE) ?dobjvar))) (old ?r) (new ?newr))
      )
    
 ;; and we have explicit nominalizations (current any N of type EVENT-OF-CHANGE)
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr ?agr)
      (sem ?sem) (mass ?mass)
      (case (? case sub obj -)) ;; noms aren't case marked, allow any value except posessive
      (class ?class)
      (dobj -)
      (subj ?subj)
      (comp3 ?comp3)
      (subj-map ?subjmap)
      (dobj-map ?dmap)
;      (dobj-map -)
      (comp3-map ?comp-map)
      (restr ?newr)
      
      )
     -n1-nom-without-obj> 1
      (head (n  (var ?v) (gap -) (aux -) (agr ?agr) (sort pred)
		(sem ?sem)  (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(LF ?class) (transform ?transform)
            ;; these are dummy vars for trips-lcflex conversion, please don't delete
            ;;(subj ?subj) (dobj ?dobj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
	    (dobj -)
	    (subj ?subj)
	    (subj (% NP (var ?subjvar)))
      	    (comp3 ?comp3)
	    (subj-map ?subjmap)
	    (dobj-map ?dmap)
;	    (dobj-map -)
	    (comp3-map ?comp-map)
	    (generated -)
	    (restr ?r)
	    ))
      (add-to-conjunct (val (& (?subjmap ?subjvar))) (old ?r) (new ?newr))
      )
     

    ;;  of-PP is typically the DOBJ role   
 ;;   e.g., The eradication of the trucks
    ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already ?npay)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
      (subj-map ?subjmap)
      (dobj ?!dobj)
      (dobj-map -) ;; eliminate the dobj-map so we can't assign another
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-of-obj1> 1.0
     (head (n1  (var ?v) (gap -) (aux -)(case ?case) (gerund ?ger)(agr ?agr)
		(nomobjpreps ?nompreps) (pre-arg-already ?npay)
		(dobj ?!dobj) 
;		(dobj (% ?s3 (case (? dcase obj -)) (agr ?agr) (var ?dv) (sem ?dobjsem) (gap -)))
		(dobj (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?dobjsem) (gap -)))
		(dobj-map ?!dmap)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
	      (restr ?restr)
	    (subj ?subj)
	    (subj-map ?subjmap)
	    (comp3 ?comp3)
	    (comp3-map ?comp-map)
	    (generated -)
	    ))
;     (pp (ptype ?nompreps) (sem ?dobjsem) (agr ?agr) (gap -) (var ?dv))
     (pp (ptype ?nompreps) (sem ?dobjsem) (gap -) (var ?dv))
     (add-to-conjunct (val (& (?!dmap ?dv))) (old ?restr) (new ?newrestr))
     )

    ;;  of PP with accusative/intransitive verbs (mapping affected to the subj)
 ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already ?npay)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj -)
      (subj-map -)
      (dobj-map -) ;; eliminate the dobj-map so we can't assign another
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-of-subj1> 1.0
     (head (n1  (var ?v) (gap -) (aux -)(case ?case) (gerund ?ger) (agr ?agr)
		(pre-arg-already ?npay) 
		(dobj-map -)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
	    ;; these are dummy vars for trips-lcflex conversion, please don't delete
	    ;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ont::affected)
		(subj (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?subjsem) (gap -)))
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		(generated -)
		))
     (pp (ptype of) (gap -) (sem ?subjsem) (var ?dv))
     (add-to-conjunct (val (& (ont::affected ?dv))) (old ?restr) (new ?newrestr))
     )
  

  ;;  by-PP is the SUBJ role   
 ;;   e.g., The eradication by the army
    ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already ?npay)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (dobj ?dobj)
      (dobj-map ?dmap)
      (subj ?subj)
      (subj-map -) ;; we eliminate the SUBJ-MAP so we can't assign another
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-by-subj1> 1
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger) (nomsubjpreps ?subjpreps)
	      (dobj ?dobj) (pre-arg-already ?npay)(agr ?agr)
	      (subj (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?subjsem) (gap -)))
	      (dobj-map ?dmap)
	      (sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
	      (class ?class) (transform ?transform)
	    ;; these are dummy vars for trips-lcflex conversion, please don't delete
	    ;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
	      (restr ?restr)
	    (subj ?subj)
	    (subj-map ?!subjmap)
	    (comp3 ?comp3)
	    (comp3-map ?comp-map)
	    (generated -)
	    ))
     (pp (ptype ?subjpreps) (sem ?subjsem) (gap -) (var ?dv))
     (add-to-conjunct (val (& (?!subjmap ?dv))) (old ?restr) (new ?newrestr)))


 ;; N-N modification on a nominalization yields DOBJ (if nomobjpreps contains "of")
    ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
      (subj-map ?subjmap)
      (dobj ?!dobj)
      (dobj-map -) ;; eliminate the dobj-map so we can't assign another
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-n-n>
     (np (AGR 3s) (abbrev -)
      (var ?v1) 
      (PRO -) (N-N-MOD -) (COMPLEX -) (GAP -)
      (postadvbl -) (post-subcat -) (sem ?dobjsem)
      )
     
     (head (n1  (var ?v) (gap -) (aux -)(case ?case) (gerund ?ger)(agr ?agr)
		(dobj ?!dobj) 
		(dobj (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?dobjsem) (gap -)))
		(dobj-map ?!dmap) (pre-arg-already -)
		(nomobjpreps w::of)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?subjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!dmap ?v1))) (old ?restr) (new ?newrestr))
     )

    ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
      (subj-map ?subjmap)
      (dobj ?!dobj)
      (dobj-map -) ;; eliminate the dobj-map so we can't assign another
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-n-n-hyphen> 1
     (np (AGR 3s) (abbrev -)(agr ?agr)
      (var ?v1) 
      (PRO -) (N-N-MOD -) (COMPLEX -) (GAP -)
      (postadvbl -) (post-subcat -) (sem ?dobjsem)
      )
      (Punc (lex W::punc-minus))
     (head (n1  (var ?v) (gap -) (aux -)(case ?case) (gerund ?ger)
		(dobj ?!dobj) 
		(dobj (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?dobjsem) (gap -)))
		(dobj-map ?!dmap) (pre-arg-already -)
		(nomobjpreps w::of)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?subjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!dmap ?v1))) (old ?restr) (new ?newrestr))
     )

;; N-N modification on a nominalization yields SUBJ if DOBJ is not available 
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
;      (subj-map ?subjmap)
      (subj-map -)  ; eliminate subj-map too
      (dobj ?!dobj)
      (dobj-map -) ;; eliminate the dobj-map 
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-n-n-subj> 
     (np (AGR 3s) (abbrev -) 
      (var ?v1) 
      (PRO -) (N-N-MOD -) (COMPLEX -) (GAP -)
      (postadvbl -) (post-subcat -) (sem ?subjsem)
      )
     
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger) (agr ?agr)
		(dobj-map -) 
;		(nomobjpreps w::of)
		(pre-arg-already -)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?!subjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!subjmap ?v1))) (old ?restr) (new ?newrestr))
     )

;; N-N modification on a nominalization yields SUBJ if "of" is in nomsubjpreps
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
;      (subj-map ?subjmap)
      (subj-map -)  ; eliminate subj-map too
      (dobj ?!dobj)
      (dobj-map -) ;; eliminate the dobj-map 
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-n-n-subj1> 
     (np (AGR 3s) (abbrev -) 
      (var ?v1) 
      (PRO -) (N-N-MOD -) (COMPLEX -) (GAP -)
      (postadvbl -) (post-subcat -) (sem ?subjsem)
      )
     
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger) (agr ?agr)
		;;(dobj-map -) can't do this!  cf "ras attack"
		(pre-arg-already -)
		(nomsubjpreps w::of)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?!subjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!subjmap ?v1))) (old ?restr) (new ?newrestr))
     )

;; N-N modification on a nominalization yields DOBJ if SUBJ is not available (e.g., Raf attack by Ras)
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?!subj)
;      (subj-map ?subjmap)
      (subj-map -)  ; eliminate subj-map too
      (dobj ?dobj)
      (dobj-map -) ;; eliminate the dobj-map 
      (comp3 ?comp3)
      (comp3-map ?comp-map)
      )
     -nom-n-n-dobj> 
     (np (AGR 3s) (abbrev -) 
      (var ?v1) 
      (PRO -) (N-N-MOD -) (COMPLEX -) (GAP -)
      (postadvbl -) (post-subcat -) (sem ?subjsem)
      )
     
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger) (agr ?agr)
		(subj-map -) 
;		(nomsubjpreps w::of)
		(pre-arg-already -)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(dobj ?dobj)
		(dobj-map ?!dobjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!dobjmap ?v1))) (old ?restr) (new ?newrestr))
     )
    
    ;; Possessive modification on a nominalization yields SUBJ 
    ;;  this only applies to N's whose dobj-map is - -- because its filled or doesn't exist!
    ((NP (SORT PRED)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
      (case ?case)
      (lf (% description (status definite) (var ?v) (sort INDIVIDUAL)
		    (Class ?class) (constraint ?newrestr)
		    (sem ?sem)))
      ;;(class ?class)
      ;;(restr ?newrestr)
      (subj ?subj)
      ;;(subj-map -)
      ;;(dobj ?!dobj)
      ;;(dobj-map -)
      ;;(comp3 ?comp3)
      ;;(comp3-map ?comp-map)
      )
     -nom-poss-n-subj> 1
     (Possessor (restr (& (assoc-poss ?v1))))
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger)(agr ?agr)
		(complex ?complex)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?!subjmap)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?!subjmap ?v1))) (old ?restr) (new ?newrestr))
     )

    ;; possessive can be DOBJ if DOBJ is not otherwise specified
    ((NP (SORT PRED) (COMPLEX ?complex)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already +)
       (lf (% description (status definite) (var ?v) (sort INDIVIDUAL)
		    (Class ?class) (constraint ?newrestr)
		    (sem ?sem) 
		    ))
      (case ?case)
      (subj ?subj)
      )
     -nom-poss-n-obj> 1
     (Possessor (restr (& (assoc-poss ?v1))))
     (head (n1  (var ?v) (gap -) (aux -)(case ?case)  (gerund ?ger) (complex ?complex) (agr ?agr)
		(dobj-map (? dobjmap ONT::AFFECTED ONT::NEUTRAL ONT::AFFECTED1 ONT::NEUTRAL1 ONT::AGENT1))
		(dobj ?!dobj) 
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?subj-map)
		(comp3 ?comp3)
		(comp3-map ?comp-map)
		))
     (add-to-conjunct (val (& (?dobjmap ?v1))) (old ?restr) (new ?newrestr))
     )

    ;;   nominalization with verbal complements
    ((N1 (SORT PRED) (COMPLEX +)
      (gap -) (var ?v) (agr ?agr) (gerund ?ger)
      (sem ?sem) (mass ?mass) (pre-arg-already ?npay)
      (case ?case)
      (class ?class)
      (restr ?newrestr)
      (subj ?subj)
      (subj-map ?subjmap)
      ;;(dobj-map ?dobjmap) 
      (dobj-map -)
      (dobj ?dobj)
      (comp3 -)
      (comp3-map -)
      )
     -nom-compln>
     (head (n1  (var ?v) (gap -) (aux -)(case ?case) (agr ?agr)
		(dobj ?dobj)
		(pre-arg-already ?npay)  (gerund ?ger)
		;;(dobj-map ?dobjmap)
		(dobj-map -)
		(sem ?sem) (sem ($ F::SITUATION)) ; (f::type ont::event-of-change)))
		(class ?class) (transform ?transform)
		;; these are dummy vars for trips-lcflex conversion, please don't delete
		;;(subj ?subj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
		(restr ?restr)
		(subj ?subj)
		(subj-map ?subjmap)
		(comp3 (% ?s3 (case (? dcase obj -)) (var ?dv) (sem ?subjsem) (gap -)))
		(comp3 ?!comp3) 
		(comp3-map ?!compmap)
		))
     ?!comp3
     (add-to-conjunct (val (& (?!compmap ?dv))) (old ?restr) (new ?newrestr))
     )
    

    ;; This constructs an NP to stand for the implicit object introduced
    ;;  by the pp-word, e.g., for "why" it is a REASON, for "HOW" it is a METHOD, etc
    ((NP (PP-WORD +) (SORT PRED) (VAR ?v) (SEM ?s) (lex ?lex) 
         (WH Q) (WH-VAR ?v) (CASE ?case) (pred ?lf) 
         (LF (% Description (status WH) (var ?v) (Class ?lf) (SORT (?agr -))
                (Lex ?lex) (sem ?sem) (transform ?transform) (constraint (% & (proform ?lex)))
                )))
     -np-pp-word1>
     (head (n (SORT PP-WORD) (SEM ?s) (AGR ?agr) (SORT ?sort)
              (LF ?lf) (sem ?sem)
              (LEX ?lex) (VAR ?v) (WH Q)
              (transform ?transform)
              )))
    
    ;; why not e.g., I don't know why not
    ((NP (PP-WORD +) (SORT PRED) (VAR ?v) (SEM ?s) (lex why) 
         (WH Q) (CASE ?case) (pred ?lf)
         (LF (% Description (status WH) (var ?v) (Class ?lf) (SORT (?agr -))
                (lex why) (sem ?sem) (transform ?transform)
                )))
     -np-pp-word-why-not>
     (head (n (SORT PP-WORD) (lex why) (SEM ?s) (AGR ?agr) (SORT ?sort)
              (LF ?lf) (sem ?sem)
              (VAR ?v) (WH Q)`
              (transform ?transform)
              ))
     (word (lex not))
     )
    
    ;;  e.g., what else
    ((NP (PP-WORD +) (SORT pred) (VAR ?v) (SEM ?s) (lex ?lex) 
         (WH Q) (WH-VAR ?v) (CASE ?case) (pred ?lf)
         (LF (% Description (status WH) (var ?v) (Class ?lf) (SORT (?agr -))
                (Lex ?lex) (sem ?sem) 
		(constraint (& (MODS ?else-v)))
			     ;;(?ELSE-LF (% *PRO* (var *) (class ?lf) (sem ?sem) (constraint (& (proform ?else-lex)))))))
                (transform ?transform) 
                ))
         )
     -np-pp-word-else1>
     (head (n (SEM ?s) (AGR ?agr) (SORT PP-WORD)
              (LF ?lf)
              (sem ?sem) 
	    (LEX ?lex) (VAR ?v) (WH Q) (transform ?transform)))
      (Advbl (sort else) (var ?else-v) (arg ?v))
      ;; (cv (lex ?else-lex) (lex else) (lf ?else-lf))
     )
    
    ;;  Words like there, here, tomorrow (no WH terms) are treated as PRO forms

    ((NP (PP-WORD +) (PRO +) (SORT (? srt pred set)) (VAR ?v) (SEM ?s) (lex ?lex)
         (role ?lf) (agr (? agr 3s 3p -))
         (LF (% Description (status PRO) (var ?v) (Class ?lf) (SORT (?agr -))
                (Lex ?lex) (sem ?sem) (transform ?transform) (constraint (% & (proform ?lex)))
                )))
     -np-pp-word2>
     (head (N (SEM ?s) (AGR ?agr) (SORT PP-WORD)
              (LEX ?lex) (VAR ?v) (WH -)
              (lf ?lf)
              (sem ?sem) (transform ?transform)
              )
           ))
    
    ;; adverbials with pp-words have a default pro subcat, expressed as an argument in the LF
    
    ;; wh-terms   
    ((ADVBL  (ARG ?argvar) (SUBCATSEM ?subcatsem)
      ;; MD 06/11/06
      ;; note that the explicit propagation up is required, even though argument is head feature
      ;; otherwise all the relevant features do not propagate up correctly
      (argument ?argument)
      (sort pp-word)
      (wh-var *)  (WH Q)
      (var ?v) 
      (LF (% PROP (VAR ?v) (CLASS ?reln) 
	     (CONSTRAINT (& (?!submap (% *PRO* (status *wh-term*) (VAR *) (CLASS ?pro-class)
					 (SEM ?subcatsem) (CONSTRAINT (& (proform ?lex)
									 (suchthat ?v)))))
			    (?!argmap ?argvar)))
	     (sem ?sem) (transform ?trans)))
      (gap -) (pp-word +)
      (role ?reln)
      )
     -advbl-wh-word> 
     (head (adv (SORT PP-WORD) (wh Q) (IMPRO-CLASS ?pro-class)
	    (argument ?argument)
	    (ARGUMENT (% ?argcat (var ?argvar)))
	    (SUBCAT (% ?x (SEM ?subcatsem))) 
	    (subcat-map ?!submap)
	    (argument-map ?!argmap)
	    (LF ?reln) (lex ?lex)
	    (sem ?sem) (transform ?trans)
	    ))
     )

#||  Doesn't seem to be a useful rule - there's not even an ADJ on the RHS
    
 ;; how adj is it
    ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem) (atype ?atype) (comparative ?cmp)
      (LF (% PROP (CLASS ?lf) (VAR ?v) (CONSTRAINT ?newc)
	     (transform ?transform) (sem ?sem) 
	     )))
     -degree-pred>
     (head (ADVBL (LF ?lf) (SUBCAT -) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
	   (constraint ?con) (functn ?fn) (comp-op ?dir)
	    ))
     (append-conjuncts (conj1 ?con) (conj2 (& (?argmap ?arg) (functn ?fn)))
		       (new ?newc))
     )
      ||#

    ;; how adj   e.g., how red
    ((ADJP  (ARG ?argvar) (SUBCATSEM ?subcatsem)
      (wh-var *) (WH Q) (SORT PP-WORD)
      (var ?adjv) (atype ?atype)
      (LF (% PROP (VAR ?adjv) (CLASS ?reln) 
	     (CONSTRAINT ?newc)
	     (sem ?sem) (transform ?trans)))
      (gap -) (pp-word +)
      (role ?reln)
      )
     -how-adj>     
     (adv (SORT PP-WORD) (wh Q) (IMPRO-CLASS ?pro-class) (lex how))
     (head (adjp (var ?adjv) (atype ?atype) (arg ?argvar) (LF (% PROP (class ?reln) (constraint ?con)))))
     (append-conjuncts (conj1 ?con) 
      (conj2 (& (degree (% *PRO* (status *wh-term*) (VAR *) (CLASS ont::degree)
		   (SEM ?subcatsem) (CONSTRAINT (& (proform ?lex) (suchthat ?adjv)))))))
      (new ?newc))
     )

     ;; how adv  e.g., how quickly
    ((ADVBL  (ARG ?argvar) (SUBCATSEM ?subcatsem)
      (wh-var *) (WH Q) (SORT PP-WORD)
      (var ?adjv) (atype ?atype)
      (LF (% PROP (VAR ?adjv) (CLASS ?reln) 
	     (CONSTRAINT ?newc)
	     (sem ?sem) (transform ?trans)))
      (gap -) (pp-word +) (argument ?argu)
      (role ?reln)
      )
     -how-advbl>     
     (adv (SORT PP-WORD) (wh Q) (IMPRO-CLASS ?pro-class) (lex how))
     (head (advbl (var ?adjv) (atype ?atype) (arg ?argvar)  (argument ?argu)
		  (LF (% PROP (class ?reln) (constraint ?con)))))
     (append-conjuncts (conj1 ?con) 
      (conj2 (& (degree (% *PRO* (status *wh-term*) (VAR *) (CLASS ont::degree)
		   (SEM ?subcatsem) (CONSTRAINT (& (proform ?lex) (suchthat ?adjv)))))))
      (new ?newc))
     )
    
    ;; pp adverbials, here, there, home 
    ((ADVBL  (ARG ?argvar) (SUBCATSEM ?subcatsem)
	     (argument ?argument)
      (sort pp-word)
             (var ?v) 
             (LF (% PROP (VAR ?v) (CLASS ?reln) 
	            (CONSTRAINT (& (?!submap (% *PRO*
						(VAR *) (CLASS ?pro-class)
						(SEM ?subcatsem) (CONSTRAINT (& (proform ?lex)))))
										;;(suchthat ?v)))))
			           (?!argmap ?argvar)))
	            (sem ?sem) (transform ?trans)))
             (gap -) (pp-word +)
      (role ?reln)
             )
     -advbl-pp-word>     
     (head (adv (SORT PP-WORD) (wh -) (IMPRO-CLASS ?pro-class)
		(argument ?argument)
	        (ARGUMENT (% ?argcat (var ?argvar)))
	        (SUBCAT (% ?x (SEM ?subcatsem))) 
	        (subcat-map ?!submap)
	        (argument-map ?!argmap)
	        (LF ?reln) (lex ?lex)
	        (sem ?sem) (transform ?trans)
	        ))
     )
    
    ;;  ELSE modifier on pp advbls
    ((ADVBL (ARG ?argvar) (SUBCATSEM ?subcatsem)
      (FOCUS ?var) (var ?v) (wh-var *) 	(argument ?argument)
      (LF (% PROP (VAR ?v) (CLASS ?reln) 
	     (CONSTRAINT (& (?!submap (% *PRO* (VAR *) (SEM ?subcatsem) 
					 (CONSTRAINT (& (proform ?lex)
							(mods ?else-v)
							(suchthat ?v)))))
			    (?!argmap ?argvar)))
	     (sem ?sem) (transform ?trans)))
      (gap -) (pp-word +)
      (role ?reln)
      )
     -advbl-pp-word-else>     
     (Head (adv (SORT PP-WORD) (wh -)
	        (ARGUMENT (% ?argcat (var ?argvar)))
	    (SUBCAT (% ?x (SEM ?subcatsem))) 
	    (subcat-map ?!submap)
	    (argument-map ?!argmap)
	    (argument ?argument)
	    (LF ?reln) (lex ?lex)
	    (sem ?sem) (transform ?trans)
	    (else-word +)
	    ))
     ;;     (cv (lex ?else-lex) (lex else) (lf ?else-lf))
     (Advbl (sort else) (var ?else-v) (arg ?v))
     )

    ;;   ELSE modifier of WH adverbials..  where else ...

     ((ADVBL (ARG ?argvar) (SUBCATSEM ?subcatsem)
      (FOCUS ?var) (var ?v) (wh-var *) (WH Q)
      (LF (% PROP (VAR ?v) (CLASS ?reln) 
	     (CONSTRAINT (& (?!submap (% *PRO* (class ?proclass) (status *wh-term*)
					 (VAR *) (SEM ?subcatsem) 
					 (CONSTRAINT (& (proform ?lex)
							(mods ?else-v)
							(suchthat ?v)))))
			    (?!argmap ?argvar)))
	     (sem ?sem) (transform ?trans)))
      (gap -) (pp-word +)
      (role ?reln)
      )
     -advbl-wh-pp-word-else>     
     (Head (adv (SORT PP-WORD) (wh Q) (impro-class ?proclass)
	        (ARGUMENT (% ?argcat (var ?argvar)))
	    (SUBCAT (% ?x (SEM ?subcatsem))) 
	    (subcat-map ?!submap)
	    (argument-map ?!argmap)
	    (LF ?reln) (lex ?lex)
	    (sem ?sem) (transform ?trans)
	    (else-word +)
	    ))
     ;;     (cv (lex ?else-lex) (lex else) (lf ?else-lf))
     (Advbl (sort else) (var ?else-v) (arg ?v)))
     
    ;; Special construction only for relative clause advbls - we need this only to build the right semantic form
    ((ADVBL-R  (ARG ?argvar) (SUBCATSEM ?subcatsem) (ARG2 ?arg2var)
             (FOCUS *) 
             (var ?v) 
             (LF (% PROP (VAR ?v) (CLASS ?reln) 
	            (CONSTRAINT (& (?!submap ?arg2var)
			           (?!argmap ?argvar)))
	            (sem ?sem) (transform ?trans)))
             (gap -) (pp-word +)
             (role ?reln)
             )
     -advbl-r-word>     
     (head (adv (SORT PP-WORD) (wh Q)
	        (ARGUMENT (% ?argcat (var ?argvar)))
	        (SUBCAT (% ?x (SEM ?subcatsem))) 
	        (subcat-map ?!submap)
	        (argument-map ?!argmap)
	        (LF ?reln) (lex ?lex)
	        (sem ?sem) (transform ?trans)
	        ))
     )


    ))


;; NAMES and complex WH-DESC NPs
;; allows changing of SEM and VAR features

;;(cl:setq *grammar-CONJ*
(parser::augment-grammar	 
  '((headfeatures
     (NP NAME PRO Changeagr lex headcat transform refl)
     (NPSEQ CASE MASS NAME PRO lex headcat transform)
     (NSEQ CASE MASS NAME lex headcat transform)
     (N1 sem lf lex headcat transform set-restr refl abbrev)
     (N sem lf mass sort lex headcat transform refl)
     )
    
  ;;  ing forms can serve as nominalizations e.g., The loading  note: it goes here as nomobjpreps can't be a head feature!
    ((N1 (SORT PRED)
      (gap -) (var ?v) (agr 3s) (gerund +)
      (sem ?sem) (mass ?mass)
      (case (? case sub obj -)) ;; gerunds aren't case marked, allow any value except posessive
      (class ?class)
      (dobj ?dobj)
      (subj ?subj)
      (comp3 ?comp3)
      (subj-map ?!subjmap)
      (dobj-map ?dmap)
      (comp3-map ?comp-map)
      (nomobjpreps ?nop)
      (nomsubjpreps ?nsp)
      )
     -gerund2> 0.98
     (head (v (vform ing) (var ?v) (gap -) (aux -) 
	      (sem ?sem) 
	      (LF ?class) (transform ?transform)
            ;; these are dummy vars for trips-lcflex conversion, please don't delete
            ;;(subj ?subj) (dobj ?dobj) (comp3 ?comp3) (iobj ?iobj) (part ?part)
	    (dobj ?dobj)
	    (subj ?subj)
	    (comp3 ?comp3)
	    (subj-map ?!subjmap)
	    (dobj-map ?dmap)
	    (comp3-map ?comp-map)
	    (nomobjpreps ?nop)
	    (nomsubjpreps ?nsp)
	    ))
     )
    ;; swift 11/28/2007 there is no more gname status
    ;; Myrosia 2/12/99: changed the rule so that class in LF comes from class
    ;; Added "postadvbl -" to handle things like "elmwood at genesee"
    ;; NP -> NAME
    ;; Myrosia 5/19/00 Changed the rule to apply only to "true" names
    ;; "generated" names get status "GNAME" in the next rule
    ((NP (SORT PRED)
         (var ?v) (Class ?lf) (sem ?sem) (agr ?agr) (case (? cas sub obj -))
         (LF (% Description (Status Name) (var ?v) (Sort Individual)
                (class ?lf) (lex ?l) (sem ?sem) 
                (transform ?transform)  (generated ?gen)
		(constraint ?restr)
                ))
         (mass count) (name +) (simple +) (time-converted ?tc) (generated ?gen)
	 (postadvbl ?gen) ;; swift -- setting postadvl to gen as part of eliminating gname rule but still allowing e.g. truck 1
         )
     -np-name>
     (head (name (lex ?l) (sem ?sem) (var ?v) (agr ?agr) (lf ?lf) (class ?class)
	    (full-name ?fname) (time-converted ?tc)
	    ;; swift 11/28/2007 removing gname rule & passing up generated feature (instead of restriction (generated -))
	    (generated ?gen)  (transform ?transform) (title -)
	    (restr ?restr)
	    )))

    
    ;; number or number-and-letter sequences
    ((NP (SORT PRED)
      (var ?v) (Class ONT::ANY-SEM) (agr ?agr) (case (? cas sub obj -))
      (LF (% Description (Status definite) (var ?v) (Sort Individual) (lex ?lf)
                (Class ONT::REFERENTIAL-SEM) (constraint (& (NAME-OF ?lf)))
		(lex ?l) (val ?val) (sem ?sem) (transform ?transform)
                ))
      (sem ($ (? ft f::phys-obj f::abstr-obj)))
      (postadvbl +) (generated +)
      (mass bare)
      (constraint ?restr) (bare-sequence ?bare-sequence)
      )
     -np-sequence-num> 
     (head (rnumber (val ?lf) (lex ?l) (val ?val) (bare-number -) (bare-sequence ?bare-sequence)
			    (restr ?restr) (var ?v)))
     )


	;;   Headless adjective phrases
	;;  The green, the largest
	((NP (SORT PRED) (CLASS ?c) (VAR *) (sem ?s) (case (? case SUB OBJ))  (headless +)
	     (lf (% description (status ?spec) (var *) (sort SET) 
		    (Class ont::Any-sem) 
		    (constraint ?con)
		    (sem ?s)
		    ))
	  (postadvbl +)
	  )
	 -NP-adj-missing-head> .96
	 (head (spec  (poss -) (restr ?restr)
                      (lf ?spec) (arg *) (agr |3P|) (var ?v)))
	 (ADJP (LF ?l1) (ARG *) (set-modifier -)
	  (var ?advvar) (ARGUMENT (% NP (sem ?s))))
	 ;;(cardinality (var ?card))
	 (append-conjuncts (conj1 (& (mods ?advvar))) (conj2 ?restr) (new ?con))
	 )
	
    ;; WH-DESC form
    ;; The Wh-DESC forms map structures that allow relative clause-like modification to indefinite pronoun forms
    ;;   and wh-adverbials

    ;;  The pronoun forms:
    ;;    currently indicate by the feature PRO having value INDEF
    
    ;;  WH-term as gap in an S structure
    ;; e.g., (I know) what the man said, (I know) what else the man said, (i know) what city it is in
    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
	 (sem ?s-sem) (var ?npvar) (WH -) (agr ?a)
         (lf (% description (status ?status) (VAR ?npvar) 
                (constraint ?constraint) (sort ?npsort)
                (sem ?npsem)  (class ?npclass) (transform ?transform)
                )))
     -wh-desc1>
     (head (np (var ?npvar) (sem ?npsem) (PRO (? xx INDEF -)) (WH Q)
	       (agr ?a) (case ?case)
            (lf (% description (class ?npclass) (status ?status) (constraint ?cons) (sort ?npsort)
                   (transform ?transform)
                   ))))
     (s (stype decl) (main -) (lf ?lf-s) (var ?s-v) (sem ?s-sem)
      (gap (% np (sem ?npsem) (var ?npvar) (case ?case) (agr ?a))))
     (add-to-conjunct (val (suchthat ?s-v)) (Old ?cons) (new ?constraint)))

    ;; WH-ADJ e.g., "(I know) how fun it is?"

    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
	 (sem ?s-sem) (var ?!whvar) (WH -) (agr ?a)
         (lf (% description (status definite) (class ONT::DEGREE) (VAR ?!whvar) 
                (constraint (& (:suchthat ?s-v))))))
                
     -wh-desc-pred>
     (head (pred (var ?var) (sem ?npsem) (PRO (? xx INDEF -)) (WH Q) (WH-VAR ?!whvar)
		 (lf (% prop (class ?npclass) (status ?status) (constraint ?cons) (sort ?npsort)
                   (transform ?transform)
                   ))))
     (s (stype decl) (main -) (lf ?lf-s) (var ?s-v) (sem ?s-sem)
      (gap (% pred (sem ?npsem) (var ?var))))
    )
     

    ;; other indefinite pronouns may allow any relative clause
    ;; e.g., (tell) anybody you saw, (was there) anyone else that you saw
    
    ((np (gap -) (mass bare) (case (? case SUB OBJ)) (sort ?npsort)
	 (sem ?s-sem) (var ?npvar) (WH -) (agr ?a)
         (lf (% description (status ?status) (VAR ?npvar) 
                (constraint ?constraint)
                (sme ?npsem)  (class ?npclass) (transform ?transform)
                )))
     -indef-pro-desc>
     (head (np (var ?npvar) (sem ?npsem) 
	    (PRO (? prp INDEF +))
	    (WH -)  (sort ?npsort)
	    (agr ?a) (case ?case)
	    ;; Myrosia's hack to make it work - need a feature later
	    ;; This is because SOMETHING is pro +, but anything is PRO indef
	    (lex (? lxx something everything nothing anything someone anyone somebody anybody somewhere anywhere everybody everyone))
            (lf (% description (class ?npclass) (status ?status) (constraint ?cons);; (sort ?npsort)
                   (transform ?transform)
                   ))))
     (cp (ctype relc)
	 (ARG ?npvar) (ARGSEM ?npsem)  (VAR ?CP-V)
	 (LF ?lf) 
	 )
     (add-to-conjunct (val (suchthat ?cp-v)) (old ?cons) (new ?constraint)))

    ;;  Indef Pro's as subjects of a VP
    ;;  e.g., (show me) who/what arrived, I know who else arrived
   
    ((np (sort wh-desc)  (gap -)  (mass bare) (agr ?a)
      (sem ?s-sem) ;;(sem ?npsem)
      (var ?npvar) (case (? case SUB OBJ))  ;; I think SUB is also OK? isn't it? JFA 3/03
      (lf (% description (status ?status) (VAR ?npvar) (class ?npclass) 
             (constraint ?constraint) (sort ?sort) (WH -)
             (sem ?npsem) (transform ?transform)
             )))
     -wh-desc2> .7
     (head (np (var ?npvar) (sem ?npsem) (wh Q) (agr ?a) ;;(PRO INDEF)
            (lf (% definite  (class ?npclass) (status ?status)
                   (constraint ?cons) (sort ?sort) (transform ?transform)
                   ))))
     (vp (var ?vpvar) (lf ?lf-s) (subjvar ?npvar) 
      (gap -) (CLASS (? !class ont::IN-RELATION ont::HAVE-PROPERTY) )     ;;  "what is aspirin" is not a good NP
      (advbl-needed -)
      (subj (% np (sem ?npsem) (var ?npvar)))
      (sem ?s-sem)
      )
     (add-to-conjunct (val (suchthat ?vpvar)) (old ?cons) (new ?constraint))
     )
    
    ;; wh-term as gap
    ;; (tell me) what to do in avon, (I have) nothing to do    
 ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
	 (sem ?s-sem) (var ?npvar) (WH -) (agr ?a)
         (lf (% description (status ?status) (VAR ?npvar) 
                (constraint ?constraint) (sort ?npsort)
                (sem ?npsem)  (class ?npclass) (transform ?transform)
                )))
  -wh-desc3>
  ;; myrosia 2007/22/02 commented out (pro indef) restriction
  ;; because "I don't know which rule to apply / what person to see" are valid sentences
  (head (np (var ?npvar) (sem ?npsem) ;;;(PRO INDEF) 
	 (WH Q)
	 (agr ?a) (case ?case)
	 (lf (% description (class ?npclass) (status ?status) (constraint ?cons) (sort ?npsort)
		(transform ?transform)
		))))
  (cp (ctype s-to) (lf ?lf-s) (var ?s-v) (sem ?s-sem)
   (gap (% np (sem ?npsem) (var ?npvar) (case ?case) (agr ?a))))
  (add-to-conjunct (val (suchthat ?s-v)) (old ?cons) (new ?constraint)))
    
    ;;  WH-term as setting in an S structure 

    ;; e.g., (I know) when/where the train arrived
    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
            (sem ?s-sem) ;; (sem ?advsem)
         (var ?npvar) 
         (lf (% description (status *wh-term*) (VAR ?npvar) 
                (class ?advrole) (constraint (& (suchthat ?s-v))) (sort individual)
                (sem ?advsem)
                )
             ))
     -wh-desc1a-norole> 0.98
     (head (advbl (pp-word +) 
                  (var ?npvar) 
            ;;(argument (% S (sem ($ f::situation (f::type F::EVENTUALITY)))))
	    (argument (% S (sem ?argsem)))
	    (wh-var ?xx) ;; this is here to disable the foot feature proposition
            (role ?advrole) (subcatsem ?advsem)
            (focus ?foc) (arg ?s-v) (wh Q) (lf ?lf1)
            ))
     (s (stype decl) (sem ?argsem) (var ?s-v) (lf ?lf-s) (gap -) ;; no gap here because locations are treated as adjuncts in grammar (except for pred BE!)
      (advbl-needed -)
      )
     )
    
    ;;    e.g., where the dogs are.
    ;; this is the only case where we have a gap
    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
      (sem ?sem) ;; (sem ?advsem)
      (var ?npvar) 
      (lf (% description (status *wh-term*) (VAR ?npvar) 
	     (class ?advrole) (constraint (& (suchthat ?s-v))) (sort individual)
	     (sem ?advsem)
	     )
	  ))
     -wh-desc1a-be> 0.98
     (head (advbl (pp-word +) 
                  (var ?npvar)  (sem ?sem)
		  (argument (% S (sem ?argsem)))
		  (role ?advrole) (subcatsem ?advsem)
		  (focus ?foc) (arg ?s-v) (wh Q) (lf ?lf1)
		  ))
     (s (stype decl) (sem ?argsem) (var ?s-v) 
      (lf (% prop (class (:* ?be-class W::BE))))
      (gap (% ?xx (var ?npvar) (sem ?sem)))
      (advbl-needed -)
      )
     )

    ;;  special rule for BE form -- unlike the others, we need a GAP in the S
     ;; e.g., (I know) when/where the train is
    
    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
            (sem ?s-sem) ;; (sem ?advsem)
         (var ?npvar) 
         (lf (% description (status *wh-term* ) (VAR ?npvar) 
                (class ?advrole) (constraint (& (suchthat ?s-v))) (sort individual)
                (sem ?advsem)
                )
             ))
     -wh-desc-be-verb> .98
     (head (advbl (pp-word +) 
                  (var ?npvar) 
            ;;(argument (% S (sem ($ f::situation (f::type F::EVENTUALITY)))))
	    ;;(argument (% S (sem ?argsem)))
            (role ?advrole) (subcatsem ?advsem)
            (focus ?foc) (arg ?s-v) (wh Q) (lf ?lf1)
            ))
     (s (stype decl) (var ?s-v)
	(lf (% prop (class ONT::IN-RELATION))) (gap (% NP (var ?npvar)))
      (advbl-needed -)
      )
     )

   
    ;;  WH-term as setting in an S structure 
    ;; e.g., (I know) when/where to go
    ((np (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
         (sem ?sem) ;;(sem ?advsem)
         (var ?whvar)
	 (lf ?wh-lf)
	 )
     ;; 11/21/2008 swift raising preference here to improve processing of "let me teach you how to X"
     -wh-desc4-norole> 0.98
     (head (advbl (pp-word +) (var ?advvar)  (sem ?sem)
            (argument (% S (sem ($ f::situation (f::type ont::situation-root)))))
            (role ?advrole) (subcatsem ?advsem)
            (focus ?foc) (arg ?s-v)
	    (wh Q) (wh-var ?whvar)
	     (lf ?wh-lf)
            ))
     (cp (ctype s-to) (sem ?argsem) (var ?s-v) (lf ?lf-s) (gap -)
      (lf (% Prop (transform ?transform) (sem ?argsem) (class ?c) (constraint ?con)))
      )
     (add-to-conjunct (val (suchthat ?advvar))(old ?con) (new ?constraint))
     )
    

    ;; e.g. "It depends on whether he is happy"
    ;; We do this as a PP because "whether he is happy" already has an NP-like description
    ;; which supports "I don't know whether he is happy"
    ((pp (sort wh-desc)  (gap -) (mass bare) (case (? case SUB OBJ))
      (sem ?s-sem) 
      (var ?s-v) 
      (lf ?lf-s)
      (ptype ?ptp)
      (headcat ?hc)
      )
     -wh-desc-if> 0.97 ;; low probability so that s-if is taken first where it is subcategorized for
     (prep (lex ?ptp) (headcat ?hc))
     (head (cp (ctype s-if) (clex whether)
	    (sem ?s-sem) (var ?s-v) (lf ?lf-s) (gap -)	    
	    (advbl-needed -)
	    )
      )
     )

    ;; NP -> pronoun
    
    ;; june 2010 singular and plural collapsed with new plural representation: LF identifier is ont::pro for singular, ont::pro-set for plural, triggered on the status feature
    ((NP (SORT PRED) (case ?case)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
         (LF (% Description (status ?st) (var ?v) (Class ?c)
                (Lex ?lex) (constraint (& (proform ?lex)))
                (sem ?sem)))
	 (mass ?m) (expletive ?exp)
         )
     -np-pro>
     (head (pro (SEM ?sem) (VAR ?v) (case ?case) (AGR ?agr)
                (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
	    (mass ?m) (sing-lf-only -) (expletive ?exp)
	    (status (? st w::PRO w::pro-set))   ;; this excludes this rule applying to pro's like "everything"
	    (poss -) ;; Added by myrosia 2003/11/02 to avoid "our" as NP
                )))

    ;; indefinite pronouns allow negation, e.g., not everyone, not one, ...

 ((NP (SORT PRED) (case ?case)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
         (LF (% Description (status ?st) (var ?v) (Class ?c)
                (Lex ?lex) (constraint (& (proform ?lex) (negation +)))
                (sem ?sem)))
	 (mass ?m) (expletive ?exp)
         )
     -np-pro-neg>
  (word (lex not))
  (head (pro (pro w::indef) (SEM ?sem) (VAR ?v) (case ?case) (AGR ?agr)
                (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
	    (mass ?m) (sing-lf-only -) (expletive ?exp)
	    (status ?st)
	    (poss -) ;; Added by myrosia 2003/11/02 to avoid "our" as NP
	    )))


   ;; possessive pronouns: it is yours, mine, his, hers
    ((NP (SORT PRED) (case ?case)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ont::REFERENTIAL-SEM) (AGR ?agr)
         (LF (% Description (status w::pro) 
		(var ?v) (Class ont::REFERENTIAL-SEM) 
		(SORT (?agr -))
                (Lex ?lex) 
		(constraint (& (assoc-poss (% *PRO* (status w::PRO) (var *)
					      (class ?c) 
					      (constraint (& (proform ?lex)
					  ))))))
                (sem ?sem)))
	 (mass ?m)
         )
     -np-pro-poss-sing>
     (head (pro (SEM ?sem) (VAR ?v) (case w::poss) (AGR (? agr 1s 2s 3s))
                (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
	    (mass ?m) (sing-lf-only -)
	    (status w::PRO)   ;; this excludes this rule applying to pro's like "everything"
	    (poss +) 
                )))

    ;;   my own, your own, ....
     ((NP (SORT PRED) (case ?case)
         (VAR *) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
         (LF (% Description (status indefinite) (var *) (Class ?c) (SORT (?agr -))
                (Lex ?lex) (constraint ?restr)
                (sem ?sem)))
	 (mass ?m)
         )
     -np-pro-own-bare>
     (head (possessor (SEM ?sem) (VAR ?v) (restr ?restr) (class ?class)
                (LEX ?lex) (VAR ?v) (WH -) (lf ?lf)(own +) (arg *)
	    (mass w::count)
	    ))
      )
     

    ;; possessive pronouns: it is yours, ours, theirs
    ((NP (SORT PRED) (case ?case)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
         (LF (% Description (status PRO) (var ?v) (Class ?c) (SORT (?agr -))
                (Lex ?lex) (constraint (& (proform ?lex)))
                (sem ?sem)))
	 (mass ?m)
         )
     -np-pro-poss-plural>
     (head (pro (SEM ?sem) (VAR ?v) (case w::poss) (AGR (? agr 1p 2p 3p))
                (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
	    (mass ?m) (sing-lf-only -)
	    (status w::PRO)   ;; this excludes this rule applying to pro's like "everything"
	    (poss +) 
                )))

   ;;  QUANTIFIER PRO's e.g., EVERYTHING, anything
   ((NP (SORT PRED) (case ?case)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
         (LF (% Description (status (? status quantifier indefinite))  (var ?v) (Class ?c) (SORT (?agr -))
                (Lex ?lex) (constraint (& (quan ?lex)))
                (sem ?sem)))
         (mass ?m)
         )
     -np-quan-sing>
     (head (pro (SEM ?sem) (VAR ?v) (case ?case) (AGR (? agr 1s 2s 3s))
                (LEX ?lex) (VAR ?v) (WH -) (lf ?c) (status (? status quantifier indefinite ))
	    (mass ?m) (sing-lf-only -)
	    (poss -) 
                )))

   ;; now use np-pro
    ;;  plural pronouns, e.g. US
;    ((NP (SORT PRED)
;         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr) (WH -) (case ?case)
;         (LF (% Description (status pro) (var ?v) 
;                (Class (SET-OF (% *PRO* (var *) (status kind) (class ?c))))
;                (SORT set) (constraint (& (proform ?lex)))
;                (sem ?sem)))
;         (mass ?m)
;         )
;     -np-pro-plur>
;     (head (pro (SEM ?sem) (VAR ?v) (AGR (? agr 1p 2p 3p)) (case ?case)
;                (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
;            (mass ?m) (sing-lf-only -)
;            (poss -) ;; Added by myrosia 2003/11/02 to avoid "our" as NP
;            )))
    
    ;; Added by Myrosia to cover the cases where there's a pronoun
    ;; with either singular or plural agreement (e.g. "what" in what
    ;; is this/what are these), but where it does not matter in most
    ;; cases and we need to avoid needless ambiguity
    ((NP (SORT PRED) (case ?case)
      (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr)
      (LF (% Description (status ?status) (var ?v) (Class ?c) (SORT (?agr -))
	     (Lex ?lex)
	     (constraint (& (proform ?lex)))
	     (sem ?sem)))
      (mass ?m)
      )
     -np-pro-noagr>
     (head (pro (SEM ?sem) (AGR ?agr) (VAR ?v) (case ?case)
	    (LEX ?lex) (VAR ?v) (WH -) (lf ?c)
	    (mass ?m) (sing-lf-only +) (status ?status)
	    (poss -) ;; Added by myrosia 2003/11/02 to avoid "our" as NP
	    )))

    
    ;; THIS HERE needs a special rule as the AT-LOC modifer from here
    ;;    would normally only modifer AN N1 constituent
    ;;  e.g.,  this here,  this in the lake, this here in the lake
    
    ((NP (SORT PRED)
         (VAR ?v) (SEM ?sem) (lex ?lex) (Class ?c) (AGR ?agr) (case ?case)
         (LF (% Description (status pro) (var ?v) (Class ?c) (SORT (?agr -))
                (constraint ?lf)
                (Lex ?lex) (sem ?sem)
                (mass bare)
                )))
     -this-here>
     (head (pro (POINTER +) (SEM ?sem) (AGR ?agr) (VAR ?v) (case ?case) ;;(POSS -)
                (LEX ?lex) (VAR ?v) (class ?c)))
     (advbls (argument (% ?argcat (sem ?s))) (arg ?v) (LF ?lf) (WH -)))
    
    ;;  CONJUNCTIONS
    ;;  use sequence constructions (SEQ +),  e.g., X, Y and/or Z.
    ;;  we control the types carefully to restrict the possibilities
    
    ;; allow mixing of class and sem, so '490 and inner loop' can combine
    ;;  X and Y,  A, Y and Z
    ((NP (ATTACH ?a) (var ?v) (agr 3p) (SEM ?sem)  
      (LF (% Description (Status ?status) (var ?v) 
	     (class ?class)
	     (constraint (& (:operator ?op) (:sequence ?members)))
	     (sem ?sem) (CASE ?case1)
	     (mass ?m1) 
	     ))
      (COMPLEX +) (SORT PRED)
      (generated ?generated)
      )
     np-conj1> 
     (NPSEQ (var ?v1) (SEM ?s1) (lf ?lf1) (class ?c1) (CASE ?case) (mass ?m1)
      (generated ?generated1) (separator W::punc-comma)
      (time-converted ?tc1) ;; MD 2008/03/06 Introduced restriction that only items with the same time-converted status can combine - i.e. don't mix number notation for times or non-times. 
      )
     (conj (SEQ +) (LF ?op) (SUBCAT NP) (var ?v)) ;; (status ?status))
     (head (NP (VAR ?v2) (SEM ?s2) (ATTACH ?a) (lf ?lf2) (LF (% ?d (class ?c2) (status ?status))) (CASE ?case2) (mass ?m2) (constraint ?con)
	    (generated ?generated2)
	    (sort (? !sort unit-measure)) ;; no unit-measure here since they form sub-NPs & we want the whole one
	    (time-converted ?tc1) 
	    ))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (simple-cons (in1 ?v2) (in2 ?lf1) (out ?members))
     (logical-and (in1 ?generated1) (in2 ?generated2) (out ?generated))
     )

    ;; sugar, salt, and dill.

    ((NP (ATTACH ?a) (var ?v) (agr 3p) (SEM ?sem)  
      (LF (% Description (Status ?status) (var ?v) 
	     (class ?class)
	     (constraint (& (:operator ?op) (:sequence ?members)))
	     (sem ?sem) (CASE ?case1)
	     (mass ?m1) 
	     ))
      (COMPLEX +) (SORT PRED)
      (generated ?generated)
      )
     np-comma-conj> 
     (NPSEQ (var ?v1) (SEM ?s1) (lf ?lf1) (class ?c1) (CASE ?case) (mass ?m1)
      (generated ?generated1) (separator w::punc-comma)
      (time-converted ?tc1) ;; MD 2008/03/06 Introduced restriction that only items with the same time-converted status can combine - i.e. don't mix number notation for times or non-times. 
      )
     (punc (lex punc-comma))
     (conj (SEQ +) (LF ?op) (SUBCAT NP) (var ?v) (status ?status))
     (head (NP (VAR ?v2) (SEM ?s2) (ATTACH ?a) (lf ?lf2) (LF (% ?d (class ?c2))) (CASE ?case2) (mass ?m2) (constraint ?con)
	    (generated ?generated2) 
	    (sort (? !sort unit-measure)) ;; no unit-measure here since they form sub-NPs & we want the whole one
	    (time-converted ?tc1) 
	    ))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (simple-cons (in1 ?v2) (in2 ?lf1) (out ?members))
     (logical-and (in1 ?generated1) (in2 ?generated2) (out ?generated))
     )
   

    ((NPSEQ  (SEM ?sem) (LF (?v1 ?v2)) (AGR ?agr) (mass ?m) (class ?class) (case ?c)
      (generated ?gen)  (time-converted ?tc1) (separator w::punc-comma)
      )
     -npseq-initial-sequence-comma> 1.01
     (head (NP (SEM ?s1) (VAR ?v1) ;;(agr ?agr)   ;; AGR is not reliably determined for proper names
	       (complex -) (headless -) (expletive -) ;;(bare-np ?bnp)
	    (generated ?gen1)  (time-converted ?tc1)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c1))) (CASE ?c) (constraint ?con) (mass ?m)
	    (sort (? !sort unit-measure)) ;; no unit measure here since they form sub-NPs [500 mb] & we want the top-level [500 mb of ram] 	    
	    ))
     (punc (lex w::punc-comma))
     (NP (SEM ?s2) (VAR ?v2) ;;(agr ?agr)  
      (complex -) (headless -) (expletive -) ;;(bare-np ?bnp)
	    (generated ?gen2)  (time-converted ?tc1)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c2))) (CASE ?c) (constraint ?con2) (mass ?m)
	    (sort (? !sort unit-measure)))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?gen))
     )

     ((NPSEQ  (SEM ?sem) (LF (?v1 ?v2)) (AGR ?agr) (mass ?m) (class ?class) (case ?c)
      (generated ?gen)  (time-converted ?tc1) (separator (? p w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash  w::punc-minus))
      )
     -npseq-initial-sequence> 1.01
     (head (NP (SEM ?s1) (VAR ?v1) ;;(agr ?agr)   ;; AGR is not reliably determined for proper names
	       (complex -) (headless -) (simple +)
	       (expletive -) ;;(bare-np ?bnp)
	    (generated ?gen1)  (time-converted ?tc1)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c1))) (CASE ?c) (constraint ?con) (mass ?m)
	    (sort (? !sort unit-measure)) ;; no unit measure here since they form sub-NPs [500 mb] & we want the top-level [500 mb of ram] 	    
	    ))
     (punc (lex (? p w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash w::punc-minus)))
     (NP (SEM ?s2) (VAR ?v2) ;;(agr ?agr)  
      (complex -) (expletive -) (simple +) 
      (headless -)
	    (generated ?gen2)  (time-converted ?tc1)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c2))) (CASE ?c) (constraint ?con2) (mass ?m)
	    (sort (? !sort unit-measure)))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?gen))
     )

    ;;  simple conjuncts/disjunct of NPS, e.g., the dog and the cat, the horse or the cow
     ((NP (ATTACH ?a) (var ?v) (agr 3p) (SEM ?sem) (gerund ?ger) 
      (LF (% Description (Status ?status) (var ?v) 
	     (class ?class)
	     (constraint (& (operator ?op) (sequence (?v1 ?v2))))
	     (sem ?sem) (CASE ?c)
	     (mass ?m1) 
	     ))
      (COMPLEX +) (SORT PRED)
      (generated ?generated)
       )
     -two-np-conjunct> 
     (head (NP (SEM ?s1) (VAR ?v1) (agr ?agr)  (complex -) (expletive -) ;;(bare-np ?bnp)
	    (generated ?gen1)  (time-converted ?tc1) (gerund ?ger)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c1) (status ?status))) (CASE ?c) (constraint ?con) (mass ?m2) ;; allowing mismatch on mass
	    (sort (? !sort unit-measure)) ;; no unit measure here since they form sub-NPs [500 mb] & we want the top-level [500 mb of ram] 	    
	    ))
     (conj (SEQ +) (LF ?op) (var ?v) ) ;;(status ?status))
     (NP (SEM ?s2) (VAR ?v2) (agr ?agr1)  (complex -) (expletive -) ;;(bare-np ?bnp)
	    (generated ?gen2)  (time-converted ?tc1)  (gerund ?ger)
	    ;; (bare-sequence -)
	    (LF (% ?sort (class ?c2))) (CASE ?c) (constraint ?con2) (mass ?m1) ;; allowing mismatch on mass -- e.g. "fatigue and weakness"
	    (sort (? !sort unit-measure)))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?generated))
     )
    
        ;; sequences in the bio domain especially can become an NP
     ((NP (ATTACH ?a) (var *) (agr 3p) (SEM ?sem)  
      (LF (% Description (Status definite) (var *) 
	     (class ?c1)
	     (constraint (& (:sequence ?lf1)))
	     (sem ?sem) (CASE ?case1)
	     (mass ?m1) 
	     ))
      (COMPLEX +) (SORT PRED)
      (generated ?generated)
      )
     np-sequence> 
      (head (NPSEQ (var ?v) (SEM ?s1) (lf ?lf1) (class ?c1) (CASE ?case) (mass ?m1)
		   (generated ?generated1) (separator (? p w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash w::punc-minus))
		   (time-converted ?rule))))

    #|| ;;  tc1 without any separator -- needed for speech, should add there
    ((NPSEQ  (SEM  ?sem) (LF ?newlf) (AGR 3s) (CASE ?case) (mass ?m) (class ?class)
      (generated ?gen) (time-converted ?tc1)
      )
     np1-3-3> 0.98 ;; myrosia lowered the preference - we should not do it unless there's a good reason to, so that we don't infer stupid things in lattices
     (head (NPSEQ  (SEM ?s1) (LF ?lf) (MASS ?m) (class ?cl) (CASE ?case)
	    (generated ?gen1) (time-converted ?tc1)
	    ))      
     (NP (SEM ?s2) (VAR ?v2) (MASS ?m) (COMPLEX -) (bare-sequence -) (class ?c2) (CASE ?case) (expletive -)
      (generated ?gen2)  (time-converted ?tc1)) ;; MD 2008/03/06 Introduced restriction that only items with the same time-converted status can combine - i.e. don't mix number notation for times or non-times. 
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (simple-cons (in1 ?v2) (in2 ?lf) (out ?newlf))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?gen))
     )||#

    ((NPSEQ  (SEM  ?sem) (LF ?newlf) (AGR 3s) (CASE ?case) (mass ?m) (class ?class)
      (generated ?gen) (time-conevn1-from-rted ?tc1) (separator (? p w::punc-comma w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash w::punc-minus))
      )
     npseq-add-next-comma> 1.02 
     (head (NPSEQ  (SEM ?s1) (LF ?lf) (MASS ?m) (class ?c1) (CASE ?case)
	    (generated ?gen1) (time-converted ?tc1) (separator (? p w::punc-comma w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash w::punc-minus))
	    )) 
     (punc  (lex w::punc-comma))
     (NP (SEM ?s2) (VAR ?v2) (MASS ?m) (COMPLEX -) (name-mod -) (bare-sequence -) (class ?c2) (CASE ?case) (expletive -)
      (generated ?gen2)  (time-converted ?tc1)) ;; MD 2008/03/06 Introduced restriction that only items with the same time-converted status can combine - i.e. don't mix number notation for times or non-times. 
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (simple-cons (in1 ?v2) (in2 ?lf) (out ?newlf))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?gen))
     )


    ((NPSEQ  (SEM  ?sem) (LF ?newlf) (AGR 3s) (CASE ?case) (mass ?m) (class ?class)
      (generated ?gen) (time-conevn1-from-rted ?tc1) (separator (? p w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash  w::punc-minus))
      )
     npseq-add-next> 1.02 
     (head (NPSEQ  (SEM ?s1) (LF ?lf) (MASS ?m) (class ?c1) (CASE ?case)
	    (generated ?gen1) (time-converted ?tc1) (separator (? p w::punc-slash w::punc-colon w::punc-minus w::punc-en-dash  w::punc-minus))
	    )) 
     (punc  (lex (? p w::punc-slash w::punc-colon  w::punc-minus w::punc-en-dash  w::punc-minus)))
     (NP (SEM ?s2) (VAR ?v2) (MASS ?m) (COMPLEX -) (simple +)   ;; simple is a bare-NP or name
      (name-mod -) (bare-sequence -) (class ?c2) (CASE ?case) (expletive -)
      (generated ?gen2)  (time-converted ?tc1)) ;; MD 2008/03/06 Introduced restriction that only items with the same time-converted status can combine - i.e. don't mix number notation for times or non-times. 
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     (simple-cons (in1 ?v2) (in2 ?lf) (out ?newlf))
     (logical-and (in1 ?gen1) (in2 ?gen2) (out ?gen))
     )
    
    
    ;;  Conjunctions with double conjuncts:: either ... or, neither ... nor, both ... and
    ;;  use sequence constructions (SEQ +),  e.g., X, Y and/or Z.
    ;;  we control the types carefully to restrict the possibilities
    
    ;; Note the difference from the main conj rule: we enforce case
    ;; agreement. We really should enforce it in the other case, too
    ;; the rule makes a simplification that the conjunction should have the agreement feature
    ;; the real rules are kind of complicated and therefore difficult to enforce carefully
    ; TEST: both dogs and cats
    ; TEST: neither dogs nor cats
    ; TEST: either dogs or cats
    ((NP (ATTACH ?a) (var ?v) (agr ?cagr) (SEM ?sem)  
         (LF (% Description (Status ?cstat) (var ?v) 
                (class ?class)
                (constraint (& (operator ?cop) (sequence (?v1 ?v2))))
                (sem ?sem) (CASE ?case1)
                (mass ?m1) 
                )) 
         (COMPLEX +) (SORT PRED))
     -np-double-conj1> 
     (conj (SEQ +) (SUBCAT1 NP) (SUBCAT2 ?wlex) (SUBCAT3 NP) 
      (var ?v) 
      (operator ?cop) (status ?cstat) (agr ?cagr))      
     (NP (var ?v1) (SEM ?s1) (lf ?lf1) (class ?c1) (CASE ?case) (mass ?m1) (constraint ?con1))
     (word (lex ?wlex))
     (head (NP (VAR ?v2) (SEM ?s2) (ATTACH ?a) (lf ?lf2) 
	       (LF (% ?d (class ?c2))) (CASE ?case) 
	       (mass ?m2) (constraint ?con2)
	       (sort (? !sort unit-measure)) ;; no unit-measure here since they form sub-NPs & we want the whole one
	       ))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     (class-least-upper-bound (in1 ?c1) (in2 ?c2) (out ?class))
     ;;     (simple-cons (in1 ?lf2) (in2 ?lf1) (out ?members))
     )
 
    ;; TEST: such dogs as collies
    ;; note that the agr can differ in the 2 NPs: such great issues as the federal budget deficit
    ((NP (var ?v1) (agr ?agr1) (SEM ?s1)
	 (LF (% Description (Status ?st1)
		(var ?v1) (class ?c1)
		(constraint ?new)
                )) 
         (COMPLEX +) (SORT PRED))
     -such-X-as-y>
     (word (lex such))
     (head (NP (var ?v1) (SEM ?s1) (CASE ?case) (agr ?agr1) (mass ?m1) (constraint ?con1)
	       (lf (% ?typ (class ?c1) (status (? st1 indefinite indefinite-plural))))
	       ))
     (pp (lex as))
     (NP (VAR ?v2) (SEM ?s2) (agr ?agr2) (lf ?lf2) 
            (LF (% ?d (class ?c2))) (CASE ?case) 
            (mass ?m2) (constraint ?con2)
            (sort (? !sort unit-measure)) ;; no unit-measure here since they form sub-NPs & we want the whole one
            )
    (add-to-conjunct (val (MODS (% *PRO* (status F) (var *) (class (:* ont::exemplifies w::such-as)) (constraint (& (of ?v1) (val ?v2)))))) (old ?con1) (new ?new))
     )

    ;; Myrosia added atype central restriction. This may be a little bit too harsh, but it is farily reasonable
    ;; and should be changed only if there are compelling counterexamples for predicative-only or attributive-only adjectives
    ;; which I could not find
    ;; Now handles conjunctions and disjunctions
    ((ADJP (ARG ?arg) (argument ?a) (sem ?sem) (atype central)
	   (VAR *) ;(COMPLEX +) -- removed to allow complex adj prenominal modification, e.g. "a natural and periodic state of rest"
	   (SORT PRED)
      (LF (% PROP (CLASS ?conj) (VAR *) (sem ?sem) (CONSTRAINT (& (sequence (?v1 ?v2)))) ;;?members)))
	     (transform ?transform) (sem ?sem)
	     )))
          
     -adj-conj1>
     (ADJP (arg ?arg) (argument ?a) (VAR ?v1) (sem ?s1) (lf ?lf1) (atype central) (post-subcat -)
      (set-modifier -)
      )
     (CONJ (LF ?conj))
     (ADJP (arg ?arg)  (argument ?a) (VAR ?v2) (sem ?s2) (lf ?lf2) (atype central) (post-subcat -)
      (set-modifier -)
      )
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     ;;(simple-cons (in1 ?v2) (in2 ?lf1) (out ?members))
     )
#||
    ;; Myrosia added atype central restriction. This may be a little bit too harsh, but it is farily reasonable
    ;; and should be changed only if there are compelling counterexamples for predicative-only or attributive-only adjectives
    ;; which I could not find
    ((ADJP (arg ?arg) (argument ?a) (sem ?sem) (var *) (atype central)
      ;; 2005/03/07 Myrosia commented out "complex +" b/c phrases like " a missing or damaged lightbulb" are perfectly possible
      ;; (complex +) 
      (sort pred)
      (lex ?hlex) (headcat ?hcat) (fake-head 0) ;; aug-trips
      (LF (% PROP (CLASS OR) (VAR *) (sem ?sem) 
	     (constraint (& (sequence (?v1 ?v2)))) ;;?members)))
	     (transform ?transform) (sem ?sem))
       )      
      )
     
     -adj-disj1> 
     (adjp (var ?v1) (arg ?arg) (argument ?a) (SEM ?s1) (lf ?lf1) (atype central) (post-subcat -)
      (set-modifier -)
      (lex ?hlex) (headcat ?hcat) ) ;; aug-trips
     (conj (LF OR))
     (adjp (var ?v2) (arg ?arg) (argument ?a) (SEM ?s2) (lf ?lf2) (atype central) (post-subcat -)
      (set-modifier -))
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     ;;(simple-cons (in1 ?v2) (in2 ?lf1) (out ?members))
     )
    ||#
    ;; either happy or sad
    ((ADJP (arg ?arg) (argument ?a) (sem ?sem) (var *) (atype central)
      (sort pred)
      (lex ?hlex) (headcat ?hcat) (fake-head 0) ;; aug-trips
      (LF (% PROP (CLASS ?clf) (VAR *) (sem ?sem) 
	     (constraint (& (sequence (?v1 ?v2)))) 
	     (transform ?transform) (sem ?sem))
	  ))
     
     -adj-double-conj1> 
     (conj (SEQ +) (SUBCAT1 ADJP) (SUBCAT2 ?wlex) (SUBCAT3 ADJP) 
      (var ?v) (lf ?clf)
      (operator ?cop)
      )                
     (adjp (var ?v1) (arg ?arg) (argument ?a) (SEM ?s1) (lf ?lf1) (atype central) (post-subcat -)
      (set-modifier -)
      (lex ?hlex) (headcat ?hcat) ) ;; aug-trips
     (word (lex ?wlex))
     (adjp (var ?v2) (arg ?arg) (argument ?a) (SEM ?s2) (lf ?lf2) (atype central) (post-subcat -)
      (set-modifier -)
      )
     (sem-least-upper-bound (in1 ?s1) (in2 ?s2) (out ?sem))
     ;;(simple-cons (in1 ?v2) (in2 ?lf1) (out ?members))
     )            
    ))

;;;  ((ADJP (ARG ?arg) (VAR ?v) (sem ?sem)
;;;      (LF (% PROP (CLASS ?lf) (VAR ?v) (CONSTRAINT ?newc)
;;;	     (transform ?transform) (sem ?sem)
;;;	     )))
;;;     -adj-pred>
;;;     (head (ADJ (LF ?lf) (SUBCAT -) (sem ?sem) (SORT PRED) (ARGUMENT-MAP ?argmap)
;;;		(transform ?transform) (constraint ?con)))
;;;     (append-conjuncts (conj1 ?con) (conj2 (& (?argmap ?arg)))
;;;		       (new ?newc))
;;;     )


;; GRAMMAR 4
;; allows changing of LF, agr, LF SEM and QUANT feature
;;
;;(cl:setq *grammar4*
(parser::augment-grammar
 '((headfeatures
    (NP SPEC QUANT VAR PRO Changeagr lex headcat transform wh)
    ;;(PP headcat) ;; non-aug-trips settings
    (PREP headcat) ;; aug-trips
    ;;(PP VAR agr SEM KIND VAR2)
    )

 #||  ;; PP GAP    ;;;  8/13 I deleted this rule, it seems redundant with -pp1-gap> in adverbial-grammar.lisp
   
   ((PP (PTYPE ?pt) (LF ?lf)
     (lex ?pt) (headcat ?hc) ;; aug-trips
     (gap (% np (lf ?lf) (sem ?sem) (mass ?m)			   
	     (agr ?gapagr) 
	     (case (? case obj -))))
     )
    -pp-gap> 0.96
    (head (prep (LEX ?pt) (headcat ?hc))))||#
   
   ;; numbers (only -- number sequences use np-sequenc1e>
   ((NP (SORT PRED)
     (var ?v) (Class ONT::ANY-SEM) 
     (sem ($ (? ft f::abstr-obj))) ;;(sem ($ (? ft f::phys-obj f::abstr-obj))) 
     (case (? cas sub obj -))
     (LF (% Description (Status number) (var ?v) (Sort Individual) (lex ?lf)
	    (CLASS ONT::NUMBER) ;;(Class ONT::REFERENTIAL-SEM) 
	    (constraint ?restr) 
	    (lex ?l) (val ?val) 
	    (sem ($ (? ft f::abstr-obj)));; (sem ($ (? ft f::phys-obj f::abstr-obj))) 
	    (transform ?transform)
	    ))
     (postadvbl +) 
     (generated +) ;; do we need this for numbers? MD 2008/06/03 yes, because we need to have "bulbs 1 and 3", and only generated NP conjunctions go there
     (simple +)
     (mass ?mass)
     (constraint ?restr) 
     (nobarespec +) ;; bare numbers can't be specifiers     
     (agr (? a 3s 3p))
     )
    -np-number> 0.98
    (head (number (val ?lf) (lex ?l) (val ?val) (range -) (agr (? a 3s 3p));(number-only +)
	   (mass ?mass) (sem ?sem1) (restr ?restr) (var ?v)))
    )
   
   ;; a seven 
   ((NP (SORT PRED)
     (var ?v) (Class ONT::ANY-SEM) (sem ($ (? ft f::phys-obj f::abstr-obj))) (case (? cas sub obj -))
     (LF (% Description (Status w::indefinite) (var ?v) (Sort Individual) (lex ?lf)
	    (Class ONT::ORDERING) (constraint (& (:value ?val))) 
	    (lex ?l) 
	    (sem ($ f::abstr-obj))
	    (transform ?transform)
	    ))
     (postadvbl +) 
     (generated +) ;; do we need this for numbers? MD 2008/06/03 yes, because we need to have "bulbs 1 and 3", and only generated NP conjunctions go there
     (mass count)
     (nobarespec +) ;; bare numbers can't be specifiers     
     (agr (? a 3s 3p))
     )
    -np-score> 0.98
    (art (lex w::a))
    (head (number (lex ?l) (val ?val) (agr (? a 3s 3p));(number-only +)
		  (restr ?restr) (var ?v)))
    )

   ;;  seven out of ten
   ((NP (SORT PRED)
     (var ?v) (Class ONT::ANY-SEM) (sem ($ (? ft f::phys-obj f::abstr-obj))) (case (? cas sub obj -))
     (LF (% Description (Status w::indefinite) (var ?v) (Sort Individual) (lex ?lf)
	    (Class ONT::ORDERING) (constraint (& (:value ?val) (:range ?range)))
	    (lex ?l)
	    (sem ($ f::abstr-obj))
	    (transform ?transform)
	    ))
     (postadvbl +) 
     (generated +) ;; do we need this for numbers? MD 2008/06/03 yes, because we need to have "bulbs 1 and 3", and only generated NP conjunctions go there
     (mass count)
     (nobarespec +) ;; bare numbers can't be specifiers     
     (agr (? a 3s 3p))
     )
    -np-score-outof> 0.98
    ;;(art (lex w::a))
    (head (number (val ?val) (agr (? a 3s 3p));(number-only +)
	   (mass ?mass) (sem ?sem1) (restr ?restr) (var ?v)))
    (word (lex w::out))
    (word (lex W::of))
    (number (val ?range) (range -))
    )

   ((NP (SORT PRED)
     (var ?v) (Class ONT::ANY-SEM) (sem ($ (? ft f::phys-obj f::abstr-obj))) (case (? cas sub obj -))
     (LF (% Description (Status w::indefinite) (var ?v) (Sort Individual) (lex ?lf)
	    (Class ONT::ORDERING) (constraint (& (:value ?val) (:range ?range)))
	    (lex ?l)
	    (sem ($ f::abstr-obj))
	    (transform ?transform)
	    ))
     (postadvbl +) 
     (generated +) ;; do we need this for numbers? MD 2008/06/03 yes, because we need to have "bulbs 1 and 3", and only generated NP conjunctions go there
     (mass count)
     (nobarespec +) ;; bare numbers can't be specifiers     
     (agr (? a 3s 3p))
     )
    -np-a-score-outof> 0.98
    (art (lex w::a))
    (head (number (val ?val) (agr (? a 3s 3p));(number-only +)
	   (mass ?mass) (sem ?sem1) (restr ?restr) (var ?v)))
    (word (lex w::out))
    (word (lex W::of))
    (number (val ?range) (range -))
    )
   

	         
   ))

;; GRAMMAR 6 
;;
;; KIND/AMOUNT/QUAN OF ANY-SEM
;;
;;(cl:setq *grammar6*
(parser::augment-grammar
      '((headfeatures
	 (NP SPEC QUANT VAR agr PRO Changeagr lex headcat transform wh)
	 (N1 sem lf lex headcat transform set-restr refl abbrev nomobjpreps kr-type))
    
   ;; certains NAMES (esp in the biology domain) are really treat like mass nouns
	;;   we need this for constructions wwith modifiers, like "phosphorylated HER3"
    ((n1 (SORT PRED)
      (var ?v) (Class ?lf) (sem ?sem) (agr ?agr) (case (? cas sub obj -)) (derived-from-name -)
      (status name) (lex ?l) (restr (& (w::name-of ?l)))
      (mass mass)
      )
     -n1-from-name> 1
     (head (name (lex ?l) (sem ?sem) 
		 (sem ($ (? type f::PHYS-OBJ f::situation) (f::type (? x ont::molecular-part ont::cell-part ont::chemical ont::physical-process))))
		 (var ?v) (agr ?agr) (lf ?lf) (class ?class)
	    (full-name ?fname) (time-converted ?tc)
	    ;; swift 11/28/2007 removing gname rule & passing up generated feature (instead of restriction (generated -))
	    (generated -)  (transform ?transform) (title -)
	    (restr ?restr)
	    )))

	;;  HEADLESS CONSTRUCTIONS

	;; e.g., the first three, the three,
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?subcatsem) (case (? case SUB OBJ)) (N-N-MOD +) (AGR 3p) (Headless +)
	    (lf (% description (status w::definite-plural) (var ?v) (sort SET)
		    (Class ont::ANY-SEM)
		    (constraint ?con)
		    (sem ?subcatsem) 
		    ))
	  (postadvbl +)
	  )
	 -NP-missing-head-plur> .98 
	 (head (spec (poss -)  (restr ?restr) (mass count)
		     (LF ?spec) (arg ?v) (agr 3p) (var ?v) ;;(NObareSpec -)       removed to handle "the three (arrived)"  jfa 5/10
		     ))
	 (CARDINALITY (var ?card) (AGR 3p))
	 (add-to-conjunct (val (size ?card)) (old ?restr) (new ?con))
	 )

	;; e.g.,  many, a few, ...
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?subcatsem) (case (? case SUB OBJ)) (N-N-MOD +) (AGR 3p) 
	    (lf (% description (status w::indefinite-plural) (var ?v) (sort SET)
		    (Class ont::ANY-SEM)
		    (constraint ?restr)
		    (sem ?subcatsem) 
		    ))
	  (postadvbl +) (headless +)
	  )
	 -NP-missing-head-plur2> .96 ;; Myrosia lowered the preference to be lower than wh-setting1-role, with which this competes on "be" questions
	 (head (spec (poss -) (restr ?restr) (mass count)
		     (LF ?spec) (arg ?v) (agr 3p) (var ?v) (nobarespec -)
		     ))
	 )
        
	;;  e.g., some (as in some pain)  -- we treat these as pre-referential
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?subcatsem) (case (? case SUB OBJ))
	     (lf (% description (status ?spec) (var ?v) (sort INDIVIDUAL)
		    (Class ont::Any-sem) (constraint ?restr)
		    (sem ?subcatsem) 
		    ))
	  (headless +)
	  )
	 -NP-missing-head-mass> .96
	 (head (spec (poss -) (restr ?restr) (LF ?spec) (arg ?v) (agr 3s) (var ?v) (mass mass) (NObareSpec -)
		     (subcat (% ?x (SEM (? subcatsem ($ (? ss F::PHYS-OBJ F::SITUATION F::ABSTR-OBJ))))))))
         )
        
	;;  e.g., the two at avon
	;;  only allowed with determiners that involve a SIZE
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?s) (case (? case SUB OBJ))
	     (lf (% description (status ?spec) (var ?v) (sort SET)
		    (Class ont::Any-sem)
		    (constraint ?con)
		    (sem ?s)
		    ))
	  (postadvbl +)
	  )
	 -NP-missing-head-mod-plur> .96
	 (head (spec  (poss -) (restr ?restr) ;;(SUBCAT (% ?x (SEM ?s)))
		(lf ?spec) (arg ?v) (agr 3p) (var ?v)
		;;(postadvbl +)
		)) ;; (NObareSpec -)))
	 (CARDINALITY (var ?card) (AGR 3p))
         (PRED (LF ?l1) (ARG *) ;;SORT SETTING) 
	       (var ?advvar) (ARGUMENT (% NP (sem ?s))))
	 (append-conjuncts (conj1 (& (size ?card) (mods ?advvar))) (conj2 ?restr) (new ?con))
	 )

#||	;;  e.g., some at avon
	;;  only allowed with determiners that involve a CARD
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?s) (case (? case SUB OBJ))
	     (lf (% description (status w::indefinite-plural) (var ?v) (sort SET)
		    (Class ont::Any-sem)
		    (constraint ?con)
		    (sem ?s)
		    ))
	  ;;(postadvbl +)
	  )
	 -NP-missing-head-mod-plur2> .96
	 (head (spec  (poss -) (card ?!card) (restr ?restr) ;;(SUBCAT (% ?x (SEM ?s)))
		(lf ?spec) (arg ?v) (agr |3P|) (var ?v)
		)) ;; (NObareSpec -)))
         (PRED (LF ?l1) (ARG ?v) ;;SORT SETTING) 
	  (var ?advvar) (ARGUMENT (% NP (sem ?s))))
	 (append-conjuncts (conj1 (& (size ?!card) (mods ?advvar))) (conj2 ?restr) (new ?con))
	 )
||#
	;;  The green two, the largest three, ...
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?s) (case (? case SUB OBJ))  (headless +)
	     (lf (% description (status ?spec) (var ?v) (sort SET) 
		    (Class ont::Any-sem) 
		    (constraint ?con)
		    (sem ?s)
		    ))
	  (postadvbl +)
	  )
	 -NP-missing-head-number> .96
	 (head (spec  (poss -) (restr ?restr)
                      (lf ?spec) (arg ?v) (agr |3P|) (var ?v)))
	 (ADJP (LF ?l1) (ARG *) (set-modifier -)
	  (var ?advvar) (ARGUMENT (% NP (sem ?s))))
	 (cardinality (var ?card))
	 (append-conjuncts (conj1 (& (size ?card) (mods ?advvar))) (conj2 ?restr) (new ?con))
	 )

	;; one more, two less, ....

	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?ssem) (case (? case SUB OBJ))  (headless +)
	     (lf (% description (status INDEF-SET) (var ?v) (sort SET) 
		    (Class ont::Any-sem) 
		    (constraint (& (size ?card) (quan ?s)))
		    (sem ?s)
		    ))
	  (postadvbl +)
	  )
	 -NP-missing-head-number-more> .96
	 (head (cardinality (var ?card) (VAR ?v)))
	 (quan (CARDINALITY -) (SEM ?sem) (VAR ?v) (agr ?agr) (comparative ?cmp) (QOF ?qof) (QCOMP ?Qcomp)
		 (MASS count) (Nobarespec ?nbs) (NoSimple ?ns) (npmod ?npm) (negation ?neg)
		 (LF ?s))
	 )

	


	;;  The green two in the corner, the largest three of the houses, ...
	((NP (SORT PRED) (CLASS ?c) (VAR ?v) (sem ?s) (case (? case SUB OBJ))
	     (lf (% description (status ?spec) (var ?v) (sort SET)
		    (Class ont::Any-sem) 
		    (constraint ?con)
		    (sem ?s)
		    ))
	  (postadvbl +)
	  )
	 -NP-missing-head-number-mod> .96
	 (head (spec  (poss -) (restr ?restr)
                      (lf ?spec) (arg ?v) (agr |3P|) (var ?v)))
	 (ADJP (ARG *) 
	  (var ?advvar1) (ARGUMENT (% NP (sem ?s))))
	 (cardinality (var ?card))
	 (PRED (ARG *) 
	  (var ?advvar2) (ARGUMENT (% NP (sem ?s))))
	 (append-conjuncts (conj1 (& (size ?card) (mods (?advvar1 ?advvar2)))) (conj2 ?restr) (new ?con))
	 )
	
	    

	))


;; various misc rules for collocations

;;(cl:setq *grammar8*
(parser::augment-grammar
      '((headfeatures
	 (NAME VAR NAME lx transform headcat)
	 (ADV var transform headcat)
	 (conj var transform headcat)
	 (quan var transform headcat)
	 (adj var transform headcat)
	 (pause var lex transform headcat)
	 (fp headcat)
	 )		

	;; rule that allows us to skip over filled pauses
	((pause (skip +))
	 -fp1>
	 (head (fp)))

	((puncpause (skip +) (lex ?lex)) ;; (? lex w::punc-comma w::punc-colon W::semi-colon W::punc-hashmark)))
	 -skip-punc1>
	 (head (W::punc (skip -) (lex (? lex w::punc-comma w::punc-colon W::semi-colon W::punc-hashmark w::punc-quotemark)))))

	))
