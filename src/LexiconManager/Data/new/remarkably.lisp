;;;;
;;;; W::remarkably
;;;;

(define-words :pos W::adv :templ PRED-VP-TEMPL 
 :words (
	 (W::remarkably
	  (SENSES
	   ((LF-PARENT ONT::acceptability-val)
	    (TEMPL ADJ-OPERATOR-TEMPL)	    
	    (example "his ankles are remarkably swollen" "he is remarkably healthy")
	    (SEM (f::gradability +) (f::orientation f::pos) (f::intensity f::hi)) ;; not pos in symptom context!
	    (meta-data :origin cardiac :entry-date 20080613 :change-date nil :comments nil :wn nil)
	    )
	   ((LF-PARENT ONT::acceptability-val)
	    (TEMPL PRED-VP-TEMPL)	    
	    (example "he performed remarkably on the exam")
	    (SEM (f::gradability +) (f::orientation f::pos) (f::intensity f::hi))
	    (meta-data :origin cardiac :entry-date 20080613 :change-date nil :comments nil :wn nil)
	    )
	   )
	  )
))

