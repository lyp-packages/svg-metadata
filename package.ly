#(define svg-id-counter 0)
#(define Grob_metadata_engraver
   (lambda (context)
     (define (recurse prev-moment prev-time prev-rate grobs tempo-changes)
       "Recursive function to calculate and set data for grobs.
        Calculates the actual timing of grobs, honoring tempo changes."
       (let*
        ((grob (car grobs))
         (moment (grob::when grob))
         ;; if there are no more tempo-changes left, there can be no rate change
         (rate-change (and (pair? tempo-changes)
                           ;; caar: (car (car x))
                           (ly:moment<? (caar tempo-changes) moment)))
         (rate (if rate-change
                   ;; cdar: (cdr (car x))
                   (cdar tempo-changes)
                   prev-rate))
         (time (if (equal? moment prev-moment)
                   prev-time
                   (+ prev-time (* rate (ly:moment-main
                                         (ly:moment-sub moment prev-moment))))))
         (cause (ly:grob-property grob 'cause))
         (duration (and (ly:stream-event? cause)
                        (ly:event-property cause 'duration #f)))
         (attribute-alist
          `((id . ,svg-id-counter)
            (class . ,(ly:format "ly grob ~a" (grob::name grob)))
            (data-moment . ,(exact->inexact (ly:moment-main moment)))
            (data-measure . ,(car (grob::rhythmic-location grob)))
            (data-time . ,time))
          ))
        (set! svg-id-counter
              (1+ svg-id-counter))
        (if duration
            (let* ((duration-fraction (ly:moment-main (ly:duration-length duration)))
                   (time-end (exact->inexact (+ time (* rate duration-fraction))))
                   (duration-alist `((data-time-end . ,time-end)
                                     (data-duration . ,duration-fraction))))
              (set! attribute-alist (append! attribute-alist duration-alist))
              ))
        ;; (display attribute-alist) (newline)
        (ly:grob-set-property! grob 'output-attributes attribute-alist)
        ;; recurse or return time if we are done
        (if (null? (cdr grobs))
            time
            (recurse moment time rate (cdr grobs) (if rate-change
                                                      (cdr tempo-changes)
                                                      tempo-changes)))))
     ;; make an engraver with a closure to store events and grobs
     (let ((tempo-change-evts '())
           (grobs '())
           (metronome-mark-grobs '()))
       (make-engraver
        ;; listeners collect and process events
        (listeners
         ((tempo-change-event engraver event)
          (let ((tempo-unit (ly:event-property event 'tempo-unit))
                (metronome-count (ly:event-property event 'metronome-count)))
            ;; Accumulate pairs of "moment when it happens" and
            ;; "new tempo rate" in `tempo-change-evts' for use in `get-seconds'
            (if (and tempo-unit metronome-count)
                (set! tempo-change-evts
                      (cons
                       (cons
                        (ly:context-current-moment context)
                        ;; calculate the tempo rate
                        (* (/ 60 metronome-count)
                          (string->number (ly:duration->string tempo-unit))))
                       tempo-change-evts))))))
        ;; acknowledgers collect grobs
        (acknowledgers
         ((grob-interface engraver grob source-engraver)
          (set! grobs (cons grob grobs)))
         ((metronome-mark-interface engraver grob source-engraver)
          (set! metronome-mark-grobs (cons grob metronome-mark-grobs))))
        ;; finalize stage: calculate and store data on grobs
        ((finalize translator)
         (let*
          ((moment-zero (ly:make-moment 0))
           ; add default tempo at moment zero, if one does not already exist
           (tempo-changes
            (if (or (null? tempo-change-evts)
                    (not (equal? moment-zero (car (last tempo-change-evts)))))
                (append
                 ;; 1/15 is default tempo, could this be accessed somewhere?
                 tempo-change-evts (list (cons moment-zero 1/15)))
                tempo-change-evts))
           (tempo-changes-sorted
            (sort-list! tempo-changes
              (lambda (a b) (ly:moment<? (car a) (car b)))))
           (grobs-sorted
            (sort-list! (filter grob::name grobs)
              (lambda (a b) (ly:moment<? (grob::when a) (grob::when b)))))
           (note-head-grobs
            (filter (lambda (g) (grob::has-interface g 'note-head-interface))
                    grobs))
           (add-metronome-mark-data
            (lambda (grob)
              (let* ((event (ly:grob-property grob 'cause))
                     (text-prop (ly:event-property event 'text))
                     (text-string (and (not (null? text-prop)) text-prop)))
                (if text-string
                    (let* ((attribute-alist (ly:grob-property grob 'output-attributes))
                           (new-alist (append! attribute-alist `((data-text . ,text-string)))))
                      (ly:grob-set-property! grob 'output-attributes new-alist))
                    ))))
           (add-note-head-data
            (lambda (grob)
              (let* ((event (ly:grob-property grob 'cause))
                     (pitch-prop (ly:event-property event 'pitch))
                     (semitone (and (ly:pitch? pitch-prop) (ly:pitch-semitones pitch-prop))))
                (if semitone
                    (let* ((attribute-alist (ly:grob-property grob 'output-attributes))
                           (new-alist (append! attribute-alist `((data-pitch . ,semitone)))))
                      (ly:grob-set-property! grob 'output-attributes new-alist))
                    )))))
          ;; calculate and set grob metadata
          ;; initial tempo rate (0.25) is (/ 60 (* metronome-count tempo-unit))
          ;; with metronome-count = 60 and tempo-unit = 4
          (recurse moment-zero 0 0.25 grobs-sorted tempo-changes-sorted)
          ;; (display tempo-changes-sorted) (newline) (display total-time)
          ;; add additional data for MetronomeMark grobs and NoteHead grobs
          (for-each add-metronome-mark-data metronome-mark-grobs)
          (for-each add-note-head-data note-head-grobs)
          ;; clear out closure variables
          (set! tempo-change-evts '())
          (set! grobs '())
          (set! metronome-mark-grobs '())
          ))))))

\layout {
  \context {
    \Score
    \consists \Grob_metadata_engraver
  }
}
