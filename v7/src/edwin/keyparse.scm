;;; -*-Scheme-*-
;;;
;;;	$Id: keyparse.scm,v 1.1 1997/03/07 23:31:15 cph Exp $
;;;
;;;	Copyright (c) 1996-97 Massachusetts Institute of Technology
;;;
;;;	This material was developed by the Scheme project at the
;;;	Massachusetts Institute of Technology, Department of
;;;	Electrical Engineering and Computer Science.  Permission to
;;;	copy this software, to redistribute it, and to use it for any
;;;	purpose is granted, subject to the following restrictions and
;;;	understandings.
;;;
;;;	1. Any copy made of this software must include this copyright
;;;	notice in full.
;;;
;;;	2. Users of this software agree to make their best efforts (a)
;;;	to return to the MIT Scheme project any improvements or
;;;	extensions that they make, so that these may be included in
;;;	future releases; and (b) to inform MIT of noteworthy uses of
;;;	this software.
;;;
;;;	3. All materials developed as a consequence of the use of this
;;;	software shall duly acknowledge such use, in accordance with
;;;	the usual standards of acknowledging credit in academic
;;;	research.
;;;
;;;	4. MIT has made no warrantee or representation that the
;;;	operation of this software will be error-free, and MIT is
;;;	under no obligation to provide any services, by way of
;;;	maintenance, update, or otherwise.
;;;
;;;	5. In conjunction with products arising from the use of this
;;;	material, there shall be no use of the name of the
;;;	Massachusetts Institute of Technology nor of any adaptation
;;;	thereof in any advertising, promotional, or sales literature
;;;	without prior written consent from MIT in each case.
;;;
;;; NOTE: Parts of this program (Edwin) were created by translation
;;; from corresponding parts of GNU Emacs.  Users should be aware that
;;; the GNU GENERAL PUBLIC LICENSE may apply to these parts.  A copy
;;; of that license should have been included along with this file.
;;;

;;;; Keyword Syntax Parser

(declare (usual-integrations))

(define-structure (description
		   (keyword-constructor make-keyparser-description)
		   (conc-name description/))
  ;; A list of patterns describing the syntax structures recognized by
  ;; this language.  The patterns are matched left to right.
  (patterns #f read-only #t)

  ;; A list of "leaders" that can appear at the beginning of a
  ;; statement.  These leaders are considered to be part of the
  ;; statement that follows them, and are skipped over to find the
  ;; statement and parse it.  Each entry in the list is a pair of a
  ;; regular expression and a procedure; the regexp matches the
  ;; beginning of the leader, and the procedure skips over the rest of
  ;; the leader.  The procedure gets two arguments: the result of the
  ;; regexp match and the END mark, and returns a mark pointing at the
  ;; end of the leader, or #F if the leader doesn't end by END.
  (statement-leaders #f read-only #t)

  ;; A procedure that finds the end of a simple statement given two
  ;; marks: the beginning of the statement and the end of the parse.
  ;; Returns a mark pointing past the statement end, or #F if the
  ;; statement doesn't terminate prior to the parse end.
  (find-statement-end #f read-only #t)

  ;; Procedures that compute the correct indentation for continued
  ;; objects.  Each procedure accepts a mark pointing to the beginning
  ;; of the continued object and returns the indentation for
  ;; continuation lines of that object.
  (indent-continued-statement #f read-only #t)
  (indent-continued-comment #f read-only #t))

;; A structure pattern is a list of pattern fragments, which define
;; the parts of the structure.  The START and END define how the
;; structure begins and ends.  The CONTINUATIONS define intermediate
;; keywords that introduce new subsections of the structure.

;; For example, in a VHDL "IF" statement, the START is "IF
;; <expression> THEN <statements>", the END is "END IF;", and the
;; continations are "ELSIF <expression> THEN <statements>" and "ELSE
;; <statements>".

(define-integrable (pattern/start pattern) (car pattern))
(define-integrable (pattern/end pattern) (cadr pattern))
(define-integrable (pattern/continuations pattern) (cddr pattern))

;; A pattern fragment is a header followed by an indented body.  (This
;; is sometimes called a "hanging indentation" style.)  The pattern
;; fragment defines how to identify the header, how to parse it once
;; it is identified, how much to indent the header should it span
;; multiple lines, and how to parse and indent the body.

(define-structure (fragment
		   (keyword-constructor make-keyparser-fragment)
		   (conc-name fragment/))
  ;; Keyword that introduces the structure.
  (keyword #f read-only #t)

  ;; Procedure that matches the header.  The procedure accepts as
  ;; argument a mark immediately to the right of the keyword, and
  ;; returns a boolean indicating whether the header is matched.  If
  ;; MATCH-HEADER is #F, the header is assumed to be matched when the
  ;; keyword is recognized.
  (match-header #f read-only #t)

  ;; Parser to scan over the header of the structure.  A procedure
  ;; that accepts three arguments and returns one value.  The three
  ;; arguments are: a parser description, a start mark, and an end
  ;; mark.  The value is a mark pointing to the end of the header.
  (parse-header #f read-only #t)

  ;; Procedure that computes the indentation for continuation lines of
  ;; the header.  The procedure accepts one argument, a mark pointing
  ;; to the beginning of the header, and returns the indentation.
  (indent-header #f read-only #t)

  ;; Parser to scan over the body of the structure.  A procedure that
  ;; accepts four arguments and returns two values.  The four
  ;; arguments are: a parser description, a start mark, an end mark,
  ;; and a parser stack.  The two values are: a mark and a parser
  ;; stack.
  (parse-body #f read-only #t)

  ;; Procedure that computes the indentation for the body of the
  ;; structure.  The procedure accepts one argument, a mark pointing
  ;; to the beginning of the header, and returns the indentation.
  (indent-body #f read-only #t)

  ;; This value, if true for an ending fragment, causes the ender to
  ;; close this many enclosing structures in addition to the innermost
  ;; structure.
  (pop-container 0 read-only #t))

(define-variable keyparser-description
  "Top-level description of buffer's syntax, for use by keyword parser."
  #f)

(define-command keyparser-indent-line
  "Indent current line using the keyword syntax for this buffer."
  "d"
  (lambda (#!optional mark)
    (let* ((mark (if (default-object? mark) (current-point) mark))
	   (point? (mark= (line-start mark 0) (line-start (current-point) 0))))
      (indent-line mark (keyparser-compute-indentation mark))
      (if point?
	  (let ((point (current-point)))
	    (if (within-indentation? point)
		(set-current-point! (indentation-end point))))))))

(define-command keyparser-indent-region
  "Indent current region using the keyword syntax for this buffer."
  "r"
  (lambda (region)
    (let ((start
	   (mark-left-inserting-copy (line-start (region-start region) 0)))
	  (end (mark-left-inserting-copy (line-start (region-end region) 0))))
      (let ((dstart (or (this-definition-start start) (group-start start))))
	(let loop ((state (keyparse-initial dstart start)))
	  ;; The temporary marks in STATE are to the left of START, and
	  ;; thus are unaffected by insertion at START.
	  (if (not (line-blank? start))
	      (indent-line start
			   (keyparser-compute-indentation-1 dstart
							    start
							    state)))
	  (let ((start* (line-start start 1 'LIMIT)))
	    (if (mark<= start* end)
		(let ((state (keyparse-partial start start* state)))
		  (move-mark-to! start start*)
		  (loop state))))))
      (mark-temporary! start)
      (mark-temporary! end))))

(define (indent-line mark indentation)
  (let ((indent-point (indentation-end mark)))
    (if (not (= indentation (mark-column indent-point)))
	(change-indentation indentation indent-point))))

(define (keyparser-compute-indentation mark)
  (let ((dstart (or (this-definition-start mark) (group-start mark)))
	(end (line-start mark 0)))
    (keyparser-compute-indentation-1 dstart
				     end
				     (keyparse-initial dstart end))))

(define (keyparser-compute-indentation-1 dstart lstart state)
  ;; DSTART is the start of a top-level definition.  LSTART is the
  ;; start of a line within that definition.  STATE is the keyparser
  ;; state obtained by parsing from DSTART to LSTART.
  (let ((char-state (keyparser-state/char-state state))
	(description (ref-variable keyparser-description dstart)))
    (if (and char-state (in-char-syntax-structure? char-state))
	(cond ((parse-state-in-comment? char-state)
	       ((description/indent-continued-comment description)
		(parse-state-comment-start char-state)))
	      ((> (parse-state-depth char-state) 0)
	       (+ (mark-column
		   (or (parse-state-containing-sexp char-state)
		       (parse-state-containing-sexp
			(parse-partial-sexp dstart lstart))))
		  1))
	      (else 0))
	(let ((restart-point (keyparser-state/restart-point state))
	      (stack (keyparser-state/stack state)))
	  (if restart-point
	      ((if (eq? 'HEADER (keyparser-state/restart-type state))
		   (fragment/indent-header (stack-entry/fragment (car stack)))
		   (description/indent-continued-statement description))
	       restart-point)
	      (if (null? stack)
		  0
		  (let ((entry (at-current-level? description lstart stack)))
		    (if entry
			(mark-indentation
			 (stack-entry/start
			  (car (if (stack-entry/end? entry)
				   (pop-containers
				    stack
				    (stack-entry/fragment entry))
				   stack))))
			(let ((entry (car stack)))
			  ((fragment/indent-body (stack-entry/fragment entry))
			   (stack-entry/start entry)))))))))))

(define-variable keyword-table
  "String table of keywords, to control keyword-completion.
See \\[complete-keyword]."
  #f)

(define-command complete-keyword
  "Perform completion on keyword preceding point."
  ()
  (lambda ()
    (let ((end 
	   (let ((point (current-point)))
	     (let ((end (group-end point)))
	       (or (re-match-forward "\\sw+" point end #f)
		   (and (mark< (group-start point) point)
			(re-match-forward "\\sw+" (mark-1+ point) end #f))
		   (editor-error "No keyword preceding point"))))))
      (let ((start (backward-word end 1 'LIMIT)))
	(standard-completion (extract-string start end)
	  (lambda (prefix if-unique if-not-unique if-not-found)
	    (string-table-complete (ref-variable keyword-table)
				   prefix
				   if-unique
				   if-not-unique
				   if-not-found))
	  (lambda (completion)
	    (delete-string start end)
	    (insert-string completion start)))))))

(define-structure (keyparser-state (conc-name keyparser-state/))
  ;; CHAR-STATE is the result from the character parser.
  (char-state #f read-only #t)

  ;; STACK is a list of elements that indicate the keyword-structure
  ;; nesting.  The first element of STACK indicates the innermost
  ;; structure, subsequent elements indicate less-inner structures.
  (stack #f read-only #t)

  ;; RESTART-POINT is either #F or a mark.  This is used when the
  ;; parser indicates that we are inside some simple structure, such
  ;; as a list or a statement.  In that case, RESTART-POINT remembers
  ;; where we were before we got into that structure, so we can resume
  ;; the parser from that point once we get out of the structure.
  (restart-point #f read-only #t)

  ;; RESTART-TYPE is a symbol indicating what kind of structure
  ;; RESTART-POINT is at the beginning of.  It can be 'HEADER,
  ;; 'LEADER, or 'STATEMENT.
  (restart-type #f read-only #t))

;; Each stack entry consists of a PATTERN describing the structure
;; that we're nested inside, an INDEX indicating which part of PATTERN
;; we're in, and a START mark pointing to the beginning of the
;; structure.

(define-structure (stack-entry
		   (conc-name stack-entry/)
		   (print-procedure
		    (standard-unparser-method 'STACK-ENTRY
		      (lambda (entry port)
			(write-char #\space port)
			(write (fragment/keyword
				(pattern/start
				 (stack-entry/pattern entry)))
			       port)))))
  (pattern #f read-only #t)
  (index #f read-only #t)
  (start #f read-only #t))

(define-integrable (stack-entry/end? entry)
  (= 1 (stack-entry/index entry)))

(define (stack-entry/fragment entry)
  (list-ref (stack-entry/pattern entry)
	    (stack-entry/index entry)))

(define (keyparse-initial dstart mark)
  (let ((lstart (line-start mark 0))
	(state (make-keyparser-state #f '() #f #f)))
    (if (mark= dstart lstart)
	state
	(keyparse-partial dstart lstart state))))

(define (keyparse-partial start end state)
  ;; STATE is the keyparser state corresponding to START; the value of
  ;; this procedure is the keyparser state corresponding to END.
  (let ((cs
	 (parse-partial-sexp start end #f #f
			     (keyparser-state/char-state state))))
    (if (in-char-syntax-structure? cs)
	(make-keyparser-state cs
			      (keyparser-state/stack state)
			      (or (keyparser-state/restart-point state) start)
			      (keyparser-state/restart-type state))
	(call-with-values
	    (lambda ()
	      (keyparse-forward (ref-variable keyparser-description start)
				(or (keyparser-state/restart-point state)
				    start)
				end
				(keyparser-state/stack state)))
	  (lambda (stack restart-point restart-type)
	    (make-keyparser-state cs stack restart-point restart-type))))))

(define (keyparse-forward description start end stack)
  (call-with-values
      (lambda ()
	(parse-forward-to-statement description start end))
    (lambda (sstart kstart)
      (cond ((not kstart)
	     (values stack sstart 'LEADER))
	    ((mark= kstart end)
	     (if (mark= sstart kstart)
		 (values stack #f #f)
		 (values stack sstart 'STATEMENT)))
	    (else
	     (call-with-values
		 (lambda ()
		   (if (and (not (null? stack))
			    (not (stack-entry/end? (car stack))))
		       (match-current-level (stack-entry/pattern (car stack))
					    kstart)
		       (values #f #f)))
	       (lambda (match index)
		 (if match
		     (continue-after-match
		      description sstart match end
		      (cons (make-stack-entry (stack-entry/pattern (car stack))
					      index
					      (stack-entry/start (car stack)))
			    (cdr stack)))
		     (call-with-values
			 (lambda ()
			   (match-structure-start description kstart))
		       (lambda (match pattern)
			 (if match
			     (continue-after-match
			      description sstart match end
			      (cons (make-stack-entry pattern 0 sstart)
				    stack))
			     (let ((se
				    ((description/find-statement-end
				      description)
				     kstart end)))
			       (if se
				   (continue-after-statement-end description
								 se
								 end
								 stack)
				   (values stack
					   sstart
					   'STATEMENT))))))))))))))

(define (at-current-level? description lstart stack)
  (call-with-values
      (lambda ()
	(parse-forward-to-statement description lstart (line-end lstart 0)))
    (lambda (sstart kstart)
      sstart
      (and kstart
	   (call-with-values
	       (lambda ()
		 (match-current-level (stack-entry/pattern (car stack))
				      kstart))
	     (lambda (match index)
	       match
	       (and match
		    (make-stack-entry (stack-entry/pattern (car stack))
				      index
				      (stack-entry/start (car stack))))))))))

(define (parse-forward-to-statement description start end)
  (let ((sstart (skip-whitespace start end)))
    (let outer ((mark sstart))
      (if (mark= mark end)
	  (values sstart mark)
	  (let loop ((leaders (description/statement-leaders description)))
	    (if (null? leaders)
		(values sstart mark)
		(let ((mark* (re-match-forward (caar leaders) mark)))
		  (if mark*
		      (let ((mark* ((cdar leaders) mark* end)))
			(if mark*
			    (outer (skip-whitespace mark* end))
			    (values sstart #f)))
		      (loop (cdr leaders))))))))))

(define (skip-whitespace start end)
  (backward-prefix-chars (forward-to-sexp-start start end) start))

(define (continue-after-match description start match end stack)
  (let ((fragment (stack-entry/fragment (car stack))))
    (let ((mark
	   (and (mark<= match end)
		((fragment/parse-header fragment) match end))))
      (cond ((not mark)
	     (values stack start 'HEADER))
	    ((stack-entry/end? (car stack))
	     (continue-after-statement-end
	      description mark end
	      (pop-containers (cdr stack) fragment)))
	    (else
	     ((fragment/parse-body fragment) description mark end stack))))))

(define (pop-containers stack fragment)
  (let loop ((stack stack) (n (fragment/pop-container fragment)))
    (if (and (pair? stack) (> n 0))
	(loop (cdr stack) (- n 1))
	stack)))

(define (continue-after-statement-end description start end stack)
  (keyparse-forward
   description
   start
   end
   (let loop ((stack stack))
     (if (and (pair? stack)
	      (not (pattern/end (stack-entry/pattern (car stack)))))
	 (loop (cdr stack))
	 stack))))

(define (match-current-level pattern start)
  (let loop ((fragments (cdr pattern)) (index 1))
    (if (null? fragments)
	(values #f #f)
	(let ((mark
	       (and (car fragments)
		    (match-fragment (car fragments) start))))
	  (if mark
	      (values mark index)
	      (loop (cdr fragments) (+ index 1)))))))

(define (match-structure-start description start)
  (let loop ((patterns (description/patterns description)))
    (if (null? patterns)
	(values #f #f)
	(let* ((pattern (car patterns))
	       (mark (match-fragment (pattern/start pattern) start)))
	  (if mark
	      (values mark pattern)
	      (loop (cdr patterns)))))))

(define (match-fragment fragment mark)
  (let ((end (match-forward (fragment/keyword fragment) mark)))
    (and end
	 (or (line-end? end)
	     (char=? #\space
		     (char->syntax-code (ref-variable syntax-table end)
					(mark-right-char end))))
	 (let ((match-header (fragment/match-header fragment)))
	   (if match-header
	       (match-header end)
	       end)))))