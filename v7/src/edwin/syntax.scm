;;; -*-Scheme-*-
;;;
;;; $Id: syntax.scm,v 1.83 1999/01/02 06:11:34 cph Exp $
;;;
;;; Copyright (c) 1986, 1989-1999 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;;; Syntax Tables

(declare (usual-integrations))

(define-structure (syntax-table (constructor %make-syntax-table)
				(conc-name syntax-table/))
  (entries false read-only #t))

(define (modify-syntax-entry! syntax-table char string)
  (if (not (syntax-table? syntax-table))
      (error:wrong-type-argument syntax-table
				 "syntax table"
				 'MODIFY-SYNTAX-ENTRY!))
  (vector-set! (syntax-table/entries syntax-table)
	       (char->ascii char)
	       ((ucode-primitive string->syntax-entry) string)))

(define (modify-syntax-entries! syntax-table cl ch string)
  (if (not (syntax-table? syntax-table))
      (error:wrong-type-argument syntax-table
				 "syntax table"
				 'MODIFY-SYNTAX-ENTRIES!))
  (let ((entries (syntax-table/entries syntax-table))
	(ah (char->ascii ch))
	(entry ((ucode-primitive string->syntax-entry) string)))
    (do ((a (char->ascii cl) (+ a 1)))
	((> a ah) unspecific)
      (vector-set! entries a entry))))

(define standard-syntax-table
  (let ((table
	 (%make-syntax-table
	  (make-vector 256 ((ucode-primitive string->syntax-entry) "")))))
    (modify-syntax-entries! table #\0 #\9 "w")
    (modify-syntax-entries! table #\A #\Z "w")
    (modify-syntax-entries! table #\a #\z "w")
    (modify-syntax-entry! table #\$ "w")
    (modify-syntax-entry! table #\% "w")
    (modify-syntax-entry! table #\( "()")
    (modify-syntax-entry! table #\) ")(")
    (modify-syntax-entry! table #\[ "(]")
    (modify-syntax-entry! table #\] ")[")
    (modify-syntax-entry! table #\{ "(}")
    (modify-syntax-entry! table #\} "){")
    (modify-syntax-entry! table #\" "\"")
    (modify-syntax-entry! table #\\ "\\")
    (for-each (lambda (char)
		(modify-syntax-entry! table char "_"))
	      (string->list "_-+*/&|<>="))
    (for-each (lambda (char)
		(modify-syntax-entry! table char "."))
	      (string->list ".,;:?!#@~^'`"))
    table))

(define (make-syntax-table #!optional table)
  (let ((table
	 (if (or (default-object? table) (not table))
	     standard-syntax-table
	     table)))
    (%make-syntax-table (vector-copy (syntax-table/entries table)))))

(define (char->syntax-code syntax-table char)
  ((ucode-primitive char->syntax-code) (syntax-table/entries syntax-table)
				       char))

(define (syntax-entry->string entry)
  (let ((code (fix:and #xf entry)))
    (if (> code 12)
	"invalid"
	(string-append
	 (vector-ref '#(" " "." "w" "_" "(" ")" "'" "\"" "$" "\\" "/" "<" ">")
		     code)
	 (let ((match (fix:and #xff (fix:lsh entry -4))))
	   (if (zero? match)
	       " "
	       (emacs-key-name (ascii->char match) false)))
	 (let ((cbits (fix:and #xFF (fix:lsh entry -12))))
	   (string-append
	    (if (fix:= 0 (fix:and #x40 cbits)) "" "1")
	    (if (fix:= 0 (fix:and #x10 cbits)) "" "2")
	    (if (fix:= 0 (fix:and #x04 cbits)) "" "3")
	    (if (fix:= 0 (fix:and #x01 cbits)) "" "4")
	    (if (or (fix:= 0 (fix:and #x80 cbits))
		    (and (fix:= code 11)
			 (fix:= #x80 (fix:and #xC0 cbits))))
		""
		"5")
	    (if (fix:= 0 (fix:and #x20 cbits)) "" "6")
	    (if (or (fix:= 0 (fix:and #x08 cbits))
		    (and (fix:= code 12)
			 (fix:= #x08 (fix:and #x0C cbits))))
		""
		"7")
	    (if (fix:= 0 (fix:and #x02 cbits)) "" "8")))
	 (if (fix:= 0 (fix:and #x100000 entry)) "" "p")))))

(define (substring-find-next-char-of-syntax string start end
					    syntax-table syntax)
  (let loop ((index start))
    (and (< index end)
	 (if (char=? syntax
		     (char->syntax-code syntax-table
					(string-ref string index)))
	     index
	     (loop (+ index 1))))))

(define (substring-find-next-char-not-of-syntax string start end
						syntax-table syntax)
  (let loop ((index start))
    (and (< index end)
	 (if (char=? syntax
		     (char->syntax-code syntax-table
					(string-ref string index)))
	     (loop (+ index 1))
	     index))))

(define-command describe-syntax
  "Describe the syntax specifications in the syntax table.
The descriptions are inserted in a buffer,
which is selected so you can see it."
  ()
  (lambda ()
    (with-output-to-help-display
     (lambda ()
       (newline)
       (let ((table (syntax-table/entries (ref-variable syntax-table))))
	 (let ((table-end (vector-length table))
	       (describe-char-range
		(lambda (bottom top)
		  (let ((describe-char
			 (lambda (ascii)
			   (emacs-key-name (ascii->char ascii) false)))
			(top (- top 1)))
		    (if (= bottom top)
			(describe-char bottom)
			(string-append (describe-char bottom)
				       " .. "
				       (describe-char top)))))))
	   (let loop ((start 0))
	     (if (< start table-end)
		 (let* ((entry (vector-ref table start))
			(end
			 (let loop ((index (+ start 1)))
			   (if (and (< index table-end)
				    (eqv? entry (vector-ref table index)))
			       (loop (+ index 1))
			       index))))
		   (let ((range-desc (describe-char-range start end)))
		     (write-string range-desc)
		     (write-char #\tab)
		     (if (< (string-length range-desc) 8)
			 (write-char #\tab)))
		   (describe-syntax-entry entry)
		   (loop end))))))))))

(define (describe-syntax-entry entry)
  (let ((code (fix:and #x0f entry)))
    (if (> code 12)
	(write-string "invalid")
	(begin
	  (write-string (syntax-entry->string entry))
	  (write-string "\twhich means: ")
	  (write-string
	   (vector-ref '#("whitespace" "punctuation" "word" "symbol" "open"
				       "close" "quote" "string" "math"
				       "escape" "charquote" "comment"
				       "endcomment")
		       code))
	  (let ((match (fix:and #xff (fix:lsh entry -4))))
	    (if (not (zero? match))
		(begin
		  (write-string ", matches ")
		  (write-string (emacs-key-name (ascii->char match) false)))))
	  (let ((decode-comment-bit
		 (lambda (code pos se style)
		   (if (not (fix:= 0 (fix:and code entry)))
		       (begin
			 (write-string ",\n\t  is the ")
			 (write-string pos)
			 (write-string " character of comment-")
			 (write-string se)
			 (write-string " sequence ")
			 (write-string style))))))
	    (decode-comment-bit #x40000 "first" "start" "B")
	    (decode-comment-bit #x10000 "second" "start" "B")
	    (decode-comment-bit #x04000 "first" "end" "B")
	    (decode-comment-bit #x01000 "second" "end" "B")
	    (if (not (and (fix:= code 11)
			  (fix:= #x80000 (fix:and #xC0000 entry))))
		(decode-comment-bit #x80000 "first" "start" "A"))
	    (decode-comment-bit #x20000 "second" "start" "A")
	    (if (not (and (fix:= code 12)
			  (fix:= #x08000 (fix:and #x0C000 entry))))
		(decode-comment-bit #x08000 "first" "end" "A"))
	    (decode-comment-bit #x02000 "second" "end" "A"))
	  (if (not (fix:= 0 (fix:and #x100000 entry)))
	      (write-string ",\n\t  is a prefix character")))))
  (newline))

;;;; Word Parsing

(define-variable syntax-table
  "The syntax-table used for word and list parsing."
  (make-syntax-table))

(define-variable syntax-ignore-comments-backwards
  "If true, ignore comments in backwards expression parsing.
This can be #T for comments that end in }, as in Pascal or C.
It should be #F for comments that end in Newline, as in Lisp;
this is because Newline occurs often when it doesn't indicate
a comment ending."
  false
  boolean?)

(define forward-word)
(define backward-word)
(let ()

(define (%forward-word mark n limit?)
  (let ((group (mark-group mark)))
    (let ((end (group-end-index group))
	  (entries (syntax-table/entries (group-syntax-table group))))
      (let loop ((start (mark-index mark)) (n n))
	(let ((m
	       ((ucode-primitive scan-word-forward) entries group start end)))
	  (cond ((not m) (limit-mark-motion limit? (make-mark group start)))
		((= n 1) (make-mark group m))
		(else (loop m (-1+ n)))))))))

(define (%backward-word mark n limit?)
  (let ((group (mark-group mark)))
    (let ((end (group-start-index group))
	  (entries (syntax-table/entries (group-syntax-table group))))
      (let loop ((start (mark-index mark)) (n n))
	(let ((m
	       ((ucode-primitive scan-word-backward) entries group start end)))
	  (cond ((not m) (limit-mark-motion limit? (make-mark group start)))
		((= n 1) (make-mark group m))
		(else (loop m (-1+ n)))))))))

(set! forward-word
(named-lambda (forward-word mark n #!optional limit?)
  (let ((limit? (and (not (default-object? limit?)) limit?)))
    (cond ((positive? n) (%forward-word mark n limit?))
	  ((negative? n) (%backward-word mark (- n) limit?))
	  (else mark)))))

(set! backward-word
(named-lambda (backward-word mark n #!optional limit?)
  (let ((limit? (and (not (default-object? limit?)) limit?)))
    (cond ((positive? n) (%backward-word mark n limit?))
	  ((negative? n) (%forward-word mark (- n) limit?))
	  (else mark)))))

)

(define (forward-to-word mark #!optional limit?)
  (let ((limit? (and (not (default-object? limit?)) limit?))
	(group (mark-group mark)))
    (let ((index
	   ((ucode-primitive scan-forward-to-word)
	    (syntax-table/entries (group-syntax-table group))
	    group
	    (mark-index mark)
	    (group-end-index group))))
      (if (not index)
	  (limit-mark-motion limit? (group-end mark))
	  (make-mark group index)))))

;;;; Lisp Parsing

(define-macro (default-end/forward start end)
  `(COND ((DEFAULT-OBJECT? ,end)
	  (GROUP-END ,start))
	 ((MARK<= ,start ,end)
	  ,end)
	 (ELSE
	  (ERROR "Marks incorrectly related:" ,start ,end))))

(define-macro (default-end/backward start end)
  `(COND ((DEFAULT-OBJECT? ,end)
	  (GROUP-START ,start))
	 ((MARK>= ,start ,end)
	  ,end)
	 (ELSE
	  (ERROR "Marks incorrectly related:" ,start ,end))))

(define (forward-prefix-chars start #!optional end)
  (let ((group (mark-group start))
	(end (default-end/forward start end)))
    (make-mark group
	       ((ucode-primitive scan-forward-prefix-chars 4)
		(syntax-table/entries (group-syntax-table group))
		group
		(mark-index start)
		(mark-index end)))))

(define (backward-prefix-chars start #!optional end)
  (let ((group (mark-group start))
	(end (default-end/backward start end)))
    (make-mark group
	       ((ucode-primitive scan-backward-prefix-chars 4)
		(syntax-table/entries (group-syntax-table group))
		group
		(mark-index start)
		(mark-index end)))))

(define (mark-right-char-quoted? mark)
  (let ((group (mark-group mark)))
    ((ucode-primitive quoted-char?)
     (syntax-table/entries (group-syntax-table group))
     group
     (mark-index mark)
     (group-start-index group))))

(define (mark-left-char-quoted? mark)
  (if (group-start? mark)
      (error "Mark has no left char" mark))
  (mark-right-char-quoted? (mark-1+ mark)))

(define-structure (parse-state (type vector))
  (depth #f read-only #t)
  (in-string? #f read-only #t)		;#F or ASCII delimiter.
  ;; COMMENT-STATE takes the following values:
  ;; #f = not in comment
  ;; 1 = in comment (style A)
  ;; 2 = after first char of two-char comment start (style A)
  ;; 3 = after first char of two-char comment end (style A)
  ;; 5 = in comment (style B)
  ;; 6 = after first char of two-char comment start (style B)
  ;; 7 = after first char of two-char comment end (style B)
  ;; COMMENT-START is valid when COMMENT-STATE is not #f.
  (comment-state #f read-only #t)
  (quoted? #f read-only #t)
  (last-sexp #f)
  (containing-sexp #f)
  (location #f)
  (comment-start #f))

(define (parse-state-in-comment? state)
  (memv (parse-state-comment-state state) '(1 3 5 7)))

(define (in-char-syntax-structure? state)
  (or (parse-state-in-comment? state)
      (parse-state-in-string? state)
      (parse-state-quoted? state)
      (not (= (parse-state-depth state) 0))))

(define (forward-to-sexp-start mark end)
  (parse-state-location (parse-partial-sexp mark end 0 #t)))

(define (parse-partial-sexp start end
			    #!optional target-depth stop-before? old-state)
  (if (not (mark<= start end))
      (error "Marks incorrectly related:" start end))
  (let ((target-depth
	 (if (or (default-object? target-depth) (not target-depth))
	     -1000000
	     target-depth))
	(stop-before? (if (default-object? stop-before?) #f stop-before?))
	(old-state (if (default-object? old-state) #f old-state))
	(group (mark-group start)))
    (let ((state
	   ((ucode-primitive scan-sexps-forward)
	    (syntax-table/entries (group-syntax-table group))
	    group
	    (mark-index start)
	    (mark-index end)
	    target-depth stop-before? old-state)))
      ;; Convert the returned indices to marks.
      (if (parse-state-last-sexp state)
	  (set-parse-state-last-sexp! 
	   state 
	   (make-mark group (parse-state-last-sexp state))))
      (if (parse-state-containing-sexp state)
	  (set-parse-state-containing-sexp! 
	   state
	   (make-mark group (parse-state-containing-sexp state))))
      (set-parse-state-location! state
				 (make-mark group
					    (parse-state-location state)))
      (if (parse-state-comment-start state)
	  (set-parse-state-comment-start!
	   state
	   (make-mark group (parse-state-comment-start state))))
      state)))

(define forward-one-sexp)
(define backward-one-sexp)
(define forward-one-list)
(define backward-one-list)
(define forward-up-one-list)
(define backward-up-one-list)
(define forward-down-one-list)
(define backward-down-one-list)
(let ()

(define (%forward-list start end depth sexp?)
  (let ((group (mark-group start)))
    (let ((index
	   ((ucode-primitive scan-list-forward)
	    (syntax-table/entries (group-syntax-table group))
	    group
	    (mark-index start)
	    (mark-index end)
	    depth
	    sexp?
	    #t)))
      (and index (make-mark group index)))))

(define (%backward-list start end depth sexp?)
  (let ((group (mark-group start)))
    (let ((index
	   ((ucode-primitive scan-list-backward)
	    (syntax-table/entries (group-syntax-table group))
	    group
	    (mark-index start)
	    (mark-index end)
	    depth
	    sexp?
	    (group-local-ref
	     group
	     (ref-variable-object syntax-ignore-comments-backwards)))))
      (and index (make-mark group index)))))

(set! forward-one-sexp
(named-lambda (forward-one-sexp start #!optional end)
  (%forward-list start (default-end/forward start end) 0 #t)))

(set! backward-one-sexp
(named-lambda (backward-one-sexp start #!optional end)
  (let ((end (default-end/backward start end)))
    (let ((mark (%backward-list start end 0 #t)))
      (and mark (backward-prefix-chars mark end))))))

(set! forward-one-list
(named-lambda (forward-one-list start #!optional end)
  (%forward-list start (default-end/forward start end) 0 #f)))

(set! backward-one-list
(named-lambda (backward-one-list start #!optional end)
  (%backward-list start (default-end/backward start end) 0 #f)))

(set! forward-up-one-list
(named-lambda (forward-up-one-list start #!optional end)
  (%forward-list start (default-end/forward start end) 1 #f)))

(set! backward-up-one-list
(named-lambda (backward-up-one-list start #!optional end)
  (%backward-list start (default-end/backward start end) 1 #f)))

(set! forward-down-one-list
(named-lambda (forward-down-one-list start #!optional end)
  (%forward-list start (default-end/forward start end) -1 #f)))

(set! backward-down-one-list
(named-lambda (backward-down-one-list start #!optional end)
  (%backward-list start (default-end/backward start end) -1 #f)))

)

;;;; Definition Start/End

(define-variable definition-start
  "Regexp to match start of a definition."
  "^\\s("
  string?)

(define (definition-start? mark)
  (re-match-forward
   (mark-local-ref mark (ref-variable-object definition-start))
   mark))

(define (forward-one-definition-start mark)
  (and (re-search-forward
	(mark-local-ref mark (ref-variable-object definition-start))
	(if (line-start? mark) (line-end mark 0) mark)
	(group-end mark))
       (re-match-start 0)))

(define (backward-one-definition-start mark)
  (re-search-backward
   (mark-local-ref mark (ref-variable-object definition-start))
   mark
   (group-start mark)))

(define (forward-one-definition-end mark)
  (define (loop start)
    (and start
	 (let ((end (forward-one-list start)))
	   (and end
		(let ((end*
		       (let ((end (horizontal-space-end end)))
			 (if (re-match-forward "[;\n]" end)
			     (line-start end 1 'LIMIT)
			     end))))
		  (if (mark> end* mark)
		      end*
		      (loop (forward-one-definition-start end))))))))
  (and (not (group-end? mark))
       (loop (or (backward-one-definition-start (mark1+ mark))
		 (forward-one-definition-start (group-start mark))))))

(define (backward-one-definition-end mark)
  (let ((start (backward-one-definition-start mark)))
    (and start
	 (let ((end (forward-one-definition-end start)))
	   (and end
		(if (mark< end mark)
		    end
		    (let ((start (backward-one-definition-start start)))
		      (and start (forward-one-definition-end start)))))))))