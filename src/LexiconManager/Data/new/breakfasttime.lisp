;;;;
;;;; w::breakfasttime
;;;;

(define-words :pos W::n
 :words (
  (w::breakfasttime
  (senses;;;;; night is separate because we can have it with or without articles
   ((LF-PARENT ONT::time-interval)
    (SEM (F::time-function (? tf F::day-period f::day-point)))
    (templ time-reln-templ)
     )
   )
)
))

