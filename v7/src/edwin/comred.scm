;;; -*-Scheme-*-
;;;
;;; $Id: comred.scm,v 1.118 2000/05/08 17:34:43 cph Exp $
;;;
;;; Copyright (c) 1986, 1989-2000 Massachusetts Institute of Technology
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

;;;; Command Reader

(declare (usual-integrations))

(define *command-key*)		;Key read to find current command
(define *command*)		;The current command
(define *last-command*)		;The previous command, excluding arg commands
(define *command-argument*)	;Argument from last command
(define *next-argument*)	;Argument to next command
(define *command-message*)	;Message from last command
(define *next-message*)		;Message to next command
(define *non-undo-count*)	;# of self-inserts since last undo boundary
(define keyboard-keys-read)	;# of keys read from keyboard
(define command-history)
(define command-history-limit 30)
(define command-reader-override-queue)
(define *command-suffixes*)

(define (initialize-command-reader!)
  (set! keyboard-keys-read 0)
  (set! command-history (make-circular-list command-history-limit false))
  (set! command-reader-override-queue (make-queue))
  (set! *command-suffixes* #f)
  unspecific)

(define (top-level-command-reader init)
  (with-keyboard-macro-disabled
   (lambda ()
     (bind-condition-handler (list condition-type:abort-current-command)
	 return-to-command-loop
       (lambda ()
	 (command-reader init))))))

(define (command-reader #!optional initialization)
  (fluid-let ((*last-command* false)
	      (*command* false)
	      (*command-argument*)
	      (*next-argument* false)
	      (*command-message*)
	      (*next-message* false)
	      (*non-undo-count* 0)
	      (*command-key* false))
    (bind-condition-handler (list condition-type:editor-error)
	editor-error-handler
      (lambda ()
	(bind-condition-handler (list condition-type:abort-current-command)
	    (lambda (condition)
	      (if (not (condition/^G? condition))
		  (return-to-command-loop condition)))
	  (lambda ()
	    (if (and (not (default-object? initialization)) initialization)
		(bind-abort-editor-command
		 (lambda ()
		   (reset-command-state!)
		   (initialization))))
	    (do () (false)
	      (bind-abort-editor-command
	       (lambda ()
		 (do () (#f)
		   (reset-command-state!)
		   (if (queue-empty? command-reader-override-queue)
		       (let ((input (get-next-keyboard-char)))
			 (if (input-event? input)
			     (begin
			       (apply-input-event input)
			       (if (not (eq? 'BUTTON (input-event/type input)))
				   (preserve-command-state!)))
			     (begin
			       (set! *command-key* input)
			       (clear-message)
			       (set-command-prompt!
				(if (not (command-argument))
				    (key-name input)
				    (string-append-separated
				     (command-argument-prompt)
				     (key-name input))))
			       (let ((window (current-window)))
				 (%dispatch-on-command
				  window
				  (local-comtab-entry (buffer-comtabs
						       (window-buffer window))
						      input
						      (window-point window))
				  false)))))
		       ((dequeue! command-reader-override-queue)))))))))))))

(define (bind-abort-editor-command thunk)
  (call-with-current-continuation
   (lambda (continuation)
     (with-restart 'ABORT-EDITOR-COMMAND "Return to the editor command loop."
	 (lambda (#!optional input)
	   (within-continuation continuation
	     (lambda ()
	       (if (and (not (default-object? input)) (input-event? input))
		   (begin
		     (reset-command-state!)
		     (apply-input-event input))))))
	 values
       thunk))))

(define (return-to-command-loop condition)
  (let ((restart (find-restart 'ABORT-EDITOR-COMMAND)))
    (if (not restart) (error "Missing ABORT-EDITOR-COMMAND restart."))
    (keyboard-macro-disable)
    (invoke-restart restart
		    (and (condition/abort-current-command? condition)
			 (abort-current-command/input condition)))))

(define (get-next-keyboard-char)
  (if *executing-keyboard-macro?*
      (begin
	(set! keyboard-keys-read (+ keyboard-keys-read 1))
	(keyboard-macro-read-key))
      (with-editor-interrupts-disabled keyboard-read)))

(define (reset-command-state!)
  (unblock-thread-events)
  (set! *last-command* *command*)
  (set! *command* false)
  (set! *command-argument* *next-argument*)
  (set! *next-argument* false)
  (set! *command-message* *next-message*)
  (set! *next-message* false)
  (if (command-argument)
      (set-command-prompt! (command-argument-prompt))
      (reset-command-prompt!))
  (if *defining-keyboard-macro?*
      (keyboard-macro-finalize-keys)))

(define (preserve-command-state!)
  (set! *next-argument* *command-argument*)
  (set! *next-message* *command-message*)
  (set! *command* *last-command*)
  unspecific)

(define (override-next-command! override)
  (enqueue! command-reader-override-queue override))

(define-integrable (current-command-key)
  *command-key*)

(define (last-command-key)
  (if (key? *command-key*)
      *command-key*
      (car (last-pair *command-key*))))

(define (set-current-command! command)
  (set! *command* command)
  unspecific)

(define-integrable (current-command)
  *command*)

(define-integrable (last-command)
  *last-command*)

(define (set-command-argument! argument mode)
  (set! *next-argument* (cons argument mode))
  ;; Preserve message and last command.
  (set! *next-message* *command-message*)
  (set! *command* *last-command*)
  unspecific)

(define-integrable (command-argument)
  (and *command-argument* (car *command-argument*)))

(define (auto-argument-mode?)
  (and *command-argument* (cdr *command-argument*)))

(define (set-command-message! tag . arguments)
  (set! *next-message* (cons tag arguments))
  unspecific)

(define (command-message-receive tag if-received if-not-received)
  (if (and *command-message*
	   (eq? (car *command-message*) tag))
      (apply if-received (cdr *command-message*))
      (if-not-received)))

(define (command-history-list)
  (let loop ((history command-history))
    (if (car history)
	(let loop ((history (cdr history)) (result (list (car history))))
	  (if (eq? history command-history)
	      result
	      (loop (cdr history) (cons (car history) result))))
	(let ((history (cdr history)))
	  (if (eq? history command-history)
	      '()
	      (loop history))))))

(define (add-command-suffix! suffix)
  (if *command-suffixes*
      (enqueue! *command-suffixes* suffix)
      (suffix)))

(define (maybe-add-command-suffix! suffix)
  (if *command-suffixes*
      (without-interrupts
       (lambda ()
	 (if (not (queued?/unsafe *command-suffixes* suffix))
	     (enqueue!/unsafe *command-suffixes* suffix))))
      (suffix)))

;;; The procedures for executing commands come in two flavors.  The
;;; difference is that the EXECUTE-foo procedures reset the command
;;; state first, while the DISPATCH-ON-foo procedures do not.  The
;;; latter should only be used by "prefix" commands such as C-X or
;;; C-4, since they want arguments, messages, etc. to be passed on.

(define-integrable (execute-key comtab key)
  (reset-command-state!)
  (dispatch-on-key comtab key))

(define-integrable (execute-command command)
  (reset-command-state!)
  (%dispatch-on-command (current-window) command false))

(define (execute-button-command screen button x y)
  (clear-message)
  (reset-command-state!)
  (send (screen-root-window screen) ':button-event! button x y))

(define (read-and-dispatch-on-key)
  (dispatch-on-key (current-comtabs)
		   (with-editor-interrupts-disabled keyboard-read)))

(define (dispatch-on-key comtab key)
  (if (input-event? key)
      (apply-input-event key)
      (begin
	(set! *command-key* key)
	(set-command-prompt!
	 (string-append-separated (command-argument-prompt) (xkey->name key)))
	(%dispatch-on-command (current-window)
			      (comtab-entry comtab key)
			      false))))

(define (dispatch-on-command command #!optional record?)
  (%dispatch-on-command (current-window)
			command
			(if (default-object? record?) false record?)))

(define (%dispatch-on-command window command record?)
  (set! *command* command)
  (guarantee-command-loaded command)
  (define (char-image-string ch)
    (window-char->image window ch))
  (let ((point (window-point window))
	(point-x (window-point-x window))
	(procedure (command-procedure command)))
    (let ((normal
	   (lambda ()
	     (set! *non-undo-count* 0)
	     (if (not *command-argument*)
		 (undo-boundary! point))
	     (fluid-let ((*command-suffixes* (make-queue)))
	       (let ((v
		      (apply procedure
			     (interactive-arguments command record?))))
		 (let loop ()
		   (if (not (queue-empty? *command-suffixes*))
		       (begin
			 ((dequeue! *command-suffixes*))
			 (loop))))
		 v)))))
      (cond ((or *executing-keyboard-macro?* *command-argument*)
	     (normal))
	    ((and (char? *command-key*)
		  (or (eq? command (ref-command-object self-insert-command))
		      (command-argument-self-insert? command)))
	     (let ((non-undo-count *non-undo-count*))
	       (if (or (fix:= non-undo-count 0)
		       (fix:>= non-undo-count 20))
		   (begin
		     (set! *non-undo-count* 1)
		     (undo-boundary! point))
		   (set! *non-undo-count* (fix:+ non-undo-count 1))))
	     (let ((key *command-key*))
	       (if (and (not (window-needs-redisplay? window))
			(let ((buffer (window-buffer window)))
			  (and (buffer-auto-save-modified? buffer)
			       (null? (cdr (buffer-windows buffer)))))
			(line-end? point)
			(not (char=? key #\newline))
			(not (char=? key #\tab))
			(let ((image (char-image-string key)))
			  (and (fix:= (string-length image) 1)
			       (char=? (string-ref image 0) key)))
			(fix:< point-x (fix:- (window-x-size window) 1)))
		   (if (self-insert key 1 #t)
		       (begin
			 (set! *non-undo-count* 0)
			 (undo-boundary! point))
		       (window-direct-output-insert-char! window key))
		   (normal))))
	    ((eq? command (ref-command-object forward-char))
	     (if (and (not (window-needs-redisplay? window))
		      (not (group-end? point))
		      (let ((char (mark-right-char point)))
			(and (not (char=? char #\newline))
			     (not (char=? char #\tab))
			     (fix:= (string-length (char-image-string char))
				    1)))
		      (fix:< point-x (fix:- (window-x-size window) 2)))
		 (window-direct-output-forward-char! window)
		 (normal)))
	    ((eq? command (ref-command-object backward-char))
	     (if (and (not (window-needs-redisplay? window))
		      (not (group-start? point))
		      (let ((char (mark-left-char point)))
			(and (not (char=? char #\newline))
			     (not (char=? char #\tab))
			     (fix:= (string-length (char-image-string char))
				    1)))
		      (fix:< 0 point-x)
		      (fix:< point-x (fix:- (window-x-size window) 1)))
		 (window-direct-output-backward-char! window)
		 (normal)))
	    (else
	     (normal))))))

(define (interactive-arguments command record?)
  (let ((specification (command-interactive-specification command))
	(record-command-arguments
	 (lambda (arguments)
	   (let ((history command-history))
	     (set-car! history (cons (command-name command) arguments))
	     (set! command-history (cdr history))))))
    (cond ((string? specification)
	   (with-values
	       (lambda ()
		 (let ((end (string-length specification)))
		   (let loop
		       ((index
			 (if (and (not (zero? end))
				  (char=? #\* (string-ref specification 0)))
			     (begin
			       (if (buffer-read-only? (current-buffer))
				   (barf-if-read-only))
			       1)
			     0)))
		     (if (< index end)
			 (let ((newline
				(substring-find-next-char specification
							  index
							  end
							  #\newline)))
			   (with-values
			       (lambda ()
				 (interactive-argument
				  (string-ref specification index)
				  (substring specification
					     (+ index 1)
					     (or newline end))))
			     (lambda (argument expression from-tty?)
			       (with-values
				   (lambda ()
				     (if newline
					 (loop (+ newline 1))
					 (values '() '() false)))
				 (lambda (arguments expressions any-from-tty?)
				   (values (cons argument arguments)
					   (cons expression expressions)
					   (or from-tty? any-from-tty?)))))))
			 (values '() '() false)))))
	     (lambda (arguments expressions any-from-tty?)
	       (if (or record?
		       (and any-from-tty?
			    (not (prefix-key-list? (current-comtabs)
						   (current-command-key)))))
		   (record-command-arguments expressions))
	       arguments)))
	  ((null? specification)
	   (if record? (record-command-arguments '()))
	   '())
	  (else
	   (let ((old-keys-read keyboard-keys-read))
	     (let ((arguments (specification)))
	       (if (or record? (not (= keyboard-keys-read old-keys-read)))
		   (record-command-arguments (map quotify-sexp arguments)))
	       arguments))))))

(define (execute-command-history-entry entry)
  (let ((history command-history))
    (if (not (equal? entry
		     (let loop ((entries (cdr history)) (tail history))
		       (if (eq? entries history)
			   (car tail)
			   (loop (cdr entries) entries)))))
	(begin
	  (set-car! history entry)
	  (set! command-history (cdr history)))))
  (apply (command-procedure (name->command (car entry)))
	 (map (let ((environment (->environment '(EDWIN))))
		(lambda (expression)
		  (eval-with-history (current-buffer) expression environment)))
	      (cdr entry))))

(define (interactive-argument key prompt)
  (let ((prompting
	 (lambda (value)
	   (values value (quotify-sexp value) true)))
	(prefix
	 (lambda (prefix)
	   (values prefix (quotify-sexp prefix) false)))
	(varies
	 (lambda (value expression)
	   (values value expression false))))
    (case key
      ((#\b)
       (prompting
	(buffer-name (prompt-for-existing-buffer prompt (current-buffer)))))
      ((#\B)
       (prompting (buffer-name (prompt-for-buffer prompt (current-buffer)))))
      ((#\c)
       (prompting (prompt-for-char prompt)))
      ((#\C)
       (prompting (command-name (prompt-for-command prompt))))
      ((#\d)
       (varies (current-point) '(CURRENT-POINT)))
      ((#\D)
       (prompting (prompt-for-directory prompt false)))
      ((#\f)
       (prompting (prompt-for-existing-file prompt false)))
      ((#\F)
       (prompting (prompt-for-file prompt false)))
      ((#\k)
       (prompting (prompt-for-key prompt (current-comtabs))))
      ((#\m)
       (varies (current-mark) '(CURRENT-MARK)))
      ((#\n)
       (prompting (prompt-for-number prompt false)))
      ((#\N)
       (prefix
	(or (command-argument-value (command-argument))
	    (prompt-for-number prompt false))))
      ((#\p)
       (prefix (command-argument-numeric-value (command-argument))))
      ((#\P)
       (prefix (command-argument)))
      ((#\r)
       (varies (current-region) '(CURRENT-REGION)))
      ((#\s)
       (prompting
	(or (prompt-for-string prompt #f 'DEFAULT-TYPE 'NULL-DEFAULT)
	    "")))
      ((#\v)
       (prompting (variable-name (prompt-for-variable prompt))))
      ((#\x)
       (prompting (prompt-for-expression prompt)))
      ((#\X)
       (prompting (prompt-for-expression-value prompt)))
      (else
       (editor-error "Invalid control letter "
		     key
		     " in interactive calling string")))))

(define (quotify-sexp sexp)
  (if (or (boolean? sexp)
	  (number? sexp)
	  (string? sexp)
	  (char? sexp))
      sexp
      `(QUOTE ,sexp)))