;;;;
;;;; W::inadequate
;;;;

(define-words :pos W::adj :templ CENTRAL-ADJ-TEMPL
 :words (
   (W::inadequate
   (wordfeats (W::morph (:FORMS (-LY))))
   (SENSES
    ((meta-data :origin trips :entry-date 20060824 :change-date 20090731 :comments nil :wn ("adequate%5:00:00:sufficient:00"))
     (EXAMPLE "that's inadequate [for him]")
     (LF-PARENT ONT::inadequate)
     (TEMPL central-adj-optional-xp-TEMPL (XP (% W::PP (W::Ptype W::for))))
     )
    )
   )
))

