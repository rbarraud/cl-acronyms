(defpackage :info.isoraqathedh.acronyms
  (:use :cl)
  (:nicknames #:acronyms)
  (:export #:expand
           #:*word-list-file-location*
           #:*master-word-list*
           #:*master-structures-list*
           #:total-entries
           #:total-structures
           #:refresh-list
           #:reset-list))

(in-package :acronyms)

(defparameter *word-list-file-location* (asdf:system-relative-pathname 'acronyms "mobyposi" :type "i")
  "Location of which the list of words with part of speech modifiers are located.")

(defparameter *structures-file-location* (asdf:system-relative-pathname 'acronyms "structures" :type "lisp")
  "Location of which the list of structures is located.")

(defun %reset-list ()
  "Blank list for *master-word-list*"
  (loop with ht = (make-hash-table)
        for part-of-speech
          in '(:nouns              ; Noun                            N
               :plurals            ; Plural                          p
               :noun-phrases       ; Noun Phrase                     h
               :verbs              ; Verb (usu participle)           V
               :transitive-verbs   ; Verb (transitive)               t
               :intransitive-verbs ; Verb (intransitive)             i
               :adjectives         ; Adjective                       A
               :adverbs            ; Adverb                          v
               :conjunctions       ; Conjunction                     C
               :prepositions       ; Preposition                     P
               :interjections      ; Interjection                    !
               :pronouns           ; Pronoun                         r
               :definite-articles  ; Definite Article                D
               :indef-articles     ; Indefinite Article              I
               :nominatives)       ; Nominative                      o
        do (setf (gethash part-of-speech ht) (make-array 1500 :adjustable t :fill-pointer 0))
        finally (return ht)))

(defparameter *master-word-list* (%reset-list)
  "The word list holding all words and their parts of speech.")

(defun total-entries ()
  "Returns the total length the dictionary."
  (loop for i being the hash-values of *master-word-list*
        sum (length i)))

(defun reset-list ()
  "Delete all entries from *master-word-list*. Returns t on success."
  (and (setf *master-word-list* (%reset-list))
       t))

(defun %read-structures ()
  "Reads the structures from structures.lisp."
  (with-open-file (structures-file *structures-file-location* :external-format :utf-8)
    (let ((*read-eval* nil))
      (read structures-file))))

(defparameter *master-structures-list* (%read-structures)
  "The vector that holds all structures.")

(defun refresh-structures ()
  "Resets the structure list to the value seen at the structures.lisp file."
  (setf *master-structures-list* (%read-structures)))

(defun total-structures ()
  "Returns the total number of structures."
  (reduce #'+ *master-structures-list* :key #'length))

(defun decode-POS-letter (letter)
  "Turns the codes used by mobiposi.i into keywords corresponding to keys in the hash table."
  (ccase letter
    (#\N :nouns             )
    (#\p :plurals           )
    (#\h :noun-phrases      )
    (#\V :verbs             )
    (#\t :transitive-verbs  )
    (#\i :intransitive-verbs)
    (#\A :adjectives        )
    (#\v :adverbs           )
    (#\C :conjunctions      )
    (#\P :prepositions      )
    (#\! :interjections     )
    (#\r :pronouns          )
    (#\D :definite-articles )
    (#\I :indef-articles    )
    (#\o :nominatives       )))

(defun refresh-list ()
  "Reloads the list from mobiposi.i, replacing all entries orginally in *master-word-list*. 
Returns the number of items placed into the word bank.
Skips any entries that have spaces."
  (reset-list) ; clear the original list.
  (with-open-file (stream *word-list-file-location* :external-format :utf-8)
    (loop initially (format t "~&Reading wordlist from file ~s: " *word-list-file-location*)
          with read = 0
          for j from 0
          for text              = (read-line stream nil) while text
          for word              = (subseq text 0 (position #\× text))
          for codes             = (subseq text (1+ (position #\× text)))
          for first-letter-then = #\Newline then first-letter-now ; #\Newline is guaranteed to never be part of a word.
          for first-letter-now  = (aref word 0)
          when (char-not-equal first-letter-then first-letter-now)
            do (princ (char-upcase first-letter-now))
          when (not (find #\Space word)) ; Forbid multi-word phrases to enter.
            do (map 'list
                    #'(lambda (p) (vector-push-extend word (gethash (decode-POS-letter p) *master-word-list*)))
                    codes)
               (incf read)
          finally
             (format t "~%Read ~:d entries, out of ~:d total in file." read j)
             (return read))))

(defun random-word (part-of-speech &optional letter)
  "Grabs a random word starting with the given part of speech starting with letter, if given.
If part-of-speech is supplied as a word, then that word is used, discarding letter.
[This is so to facilitate build-acronym].
If a letter is supplied, will make up to 12800 attempts to find a word that begins with that letter,
returning nil if attempts run out (usually because there is no such combination)."
  (let ((pos-hash-table (gethash part-of-speech *master-word-list*)))
    (cond ((stringp part-of-speech) part-of-speech)
          ((or (null letter) (find letter '(:any t))) (aref pos-hash-table (random (length pos-hash-table))))
          (t (loop repeat 12800         ; failsafe
                   for i = (aref pos-hash-table (random (length pos-hash-table)))
                   when (char-equal letter (aref i 0))
                     return (format nil "~@(~a~)" i))))))

(defun build-backronym (part-of-speech-specifier acronym)
  "Creates an acronym using a combination of a part-of-speech specifier and an input abbreviation."
  ;; As a bit of a syntactic sugar, allow POS letters used in mobiposi.i to be used as POS-specifiers.
  (when (stringp part-of-speech-specifier)
    (setf part-of-speech-specifier (map 'list #'decode-POS-letter part-of-speech-specifier)))
  (format nil "~{~a~^ ~}"
          (loop for part-of-speech in part-of-speech-specifier
                with acronym = acronym
                with pointer = 0
                if (stringp part-of-speech)
                  collect part-of-speech
                else
                  collect (random-word part-of-speech (aref acronym pointer))
                  and do (incf pointer)
                while (< pointer (length acronym)))))

(defun get-POS-template (acronym)
  "Returns an appropriate part-of-speech template for a given acronym, ready for use in build-backronym."
  ;; MAYBE: Do common (and irregular) substitutions here, like 2 → to, 4 → for
  (flet ((%get-POS-template (length)
           (let ((templates-vector (aref *master-structures-list* (1- length))))
             (aref templates-vector (random (length templates-vector))))))
    (if (<= (length acronym) (length *master-structures-list*))
        ;; Randomly pick a template to use.
        (%get-POS-template (length acronym))
        ;; If the acronym is too long for any precomposed templates,
        ;; Join up existing templates with prepositions into a final template.
        (loop with length-of-structures-list = (length *master-structures-list*)
              with length-of-acronym         = (length acronym)
              for i                          = (1+ (random length-of-structures-list))
              and target                     = length-of-acronym then (- target i)
              while (< length-of-structures-list target)
              append (%get-POS-template i) into final-list
              collect (random-word :prepositions) into final-list
              finally (return (append final-list
                                      (%get-POS-template target)))))))

(defun expand (acronym &optional (times 1 times-supplied-p))
  "Expands an acronym. If 'times' is provided, repeats expansion that many times and collects results into a list."
  ;; Remove all non-letter characters.
  (setf acronym (delete-if-not #'(lambda (p) (find p "ABCDEFGHIJKLMNOPQRSTUVWXYZ" :test #'char-equal)) acronym))
  (if times-supplied-p
      (loop repeat times collect (build-backronym (get-POS-template acronym) acronym))
      (build-backronym (get-POS-template acronym) acronym)))
  
;;; Autoload the list
(refresh-list)
