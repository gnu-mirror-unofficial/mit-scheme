;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/artdebug.scm,v 1.5 1991/05/06 00:54:58 cph Exp $
;;;
;;;	Copyright (c) 1989-91 Massachusetts Institute of Technology
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

;;;; Continuation Browser

(declare (usual-integrations))

(define in-debugger? false)

(define (debug-scheme-error condition)
  (if in-debugger?
      (exit-editor-and-signal-error condition)
      (fluid-let ((in-debugger? true))
	(let ((buffer (continuation-browser condition)))
	  (select-buffer buffer)
	  (standard-output buffer
	    (lambda ()
	      (write-string
	       (substitute-command-keys
		"This is a debugger buffer:
Type \\[continuation-browser-quit] to exit.
Type \\[continuation-browser-print-subproblem-or-reduction] to see where you are.
Type \\[describe-mode] for more information.

The error that started the debugger is:
"))
	      (write-condition-report condition (current-output-port))))))))

(define-command browse-continuation
  "Invoke the continuation-browser on CONTINUATION."
  "XBrowse Continuation"
  (lambda (continuation)
    (if (not (continuation? continuation)) (editor-error "Not a continuation"))
    (let ((buffer (continuation-browser continuation)))
      (invoke-debugger-command command/print-subproblem-or-reduction buffer)
      (select-buffer buffer))))

(define (continuation-browser object)
  (let ((buffer (new-buffer "*debug*")))
    (set-buffer-major-mode! buffer (ref-mode-object continuation-browser))
    (buffer-put! buffer 'DEBUG-STATE (make-initial-dstate object))
    (with-selected-buffer buffer
      (lambda ()
	(setup-buffer-environment! buffer)))
    buffer))

(define-integrable (buffer-dstate buffer)
  (buffer-get buffer 'DEBUG-STATE))

(define (debugger-command-invocation command)
  (lambda ()
    (invoke-debugger-command command (current-buffer))))

(define (invoke-debugger-command command buffer)
  (with-debugger-hooks buffer
    (lambda ()
      (command (buffer-dstate buffer))))
  (setup-buffer-environment! buffer))

(define (with-debugger-hooks buffer thunk)
  (fluid-let ((hook/prompt-for-confirmation
	       (lambda (cmdl prompt)
		 cmdl			;ignore
		 (prompt-for-confirmation prompt)))
	      (hook/prompt-for-expression
	       (lambda (cmdl prompt)
		 cmdl			;ignore
		 (prompt-for-expression prompt)))
	      (hook/debugger-failure
	       (lambda (string)
		 (message string)
		 (editor-beep)))
	      (hook/debugger-message message)
	      (hook/presentation
	       (lambda (thunk)
		 (standard-output buffer (lambda () (thunk) (newline))))))
    (thunk)))

(define (standard-output buffer thunk)
  (set-buffer-writeable! buffer)
  (region-delete! (buffer-region buffer))
  (with-output-to-mark (buffer-point buffer) thunk)
  (buffer-not-modified! buffer)
  (set-buffer-read-only! buffer)
  (set-buffer-point! buffer (buffer-start buffer)))

(define (setup-buffer-environment! buffer)
  (set-variable!
   scheme-environment
   (let ((environment-list (dstate/environment-list (buffer-dstate buffer))))
     (if (and (pair? environment-list)
	      (environment? (car environment-list)))
	 (car environment-list)
	 'DEFAULT))))

(define-command continuation-browser-print-subproblem-or-reduction
  "Print the current subproblem or reduction in the standard format."
  ()
  (debugger-command-invocation command/print-subproblem-or-reduction))

(define-command continuation-browser-print-expression
  "Pretty print the current expression."
  ()
  (debugger-command-invocation command/print-expression))

(define-command continuation-browser-print-environment-procedure
  "Pretty print the procedure that created the current environment."
  ()
  (debugger-command-invocation command/print-environment-procedure))

(define-command continuation-browser-print-reductions
  "Print all the reductions of the current subproblem."
  ()
  (debugger-command-invocation command/print-reductions))

(define-command continuation-browser-summarize-subproblems
  "Print a summary of all subproblems."
  ()
  (debugger-command-invocation command/summarize-subproblems))

(define-command continuation-browser-goto
  "Move to an arbitrary subproblem.
Prompts for the subproblem number."
  ()
  (debugger-command-invocation command/goto))

(define-command continuation-browser-earlier-subproblem
  "Move to the next earlier subproblem."
  ()
  (debugger-command-invocation command/earlier-subproblem))

(define-command continuation-browser-earlier-reduction
  "Move to the next earlier reduction.
If there are no earlier reductions for this subproblem,
move to the next earlier subproblem."
  ()
  (debugger-command-invocation command/earlier-reduction))

(define-command continuation-browser-later-subproblem
  "Move to the next later subproblem."
  ()
  (debugger-command-invocation command/later-subproblem))

(define-command continuation-browser-later-reduction
  "Move to the next later reduction.
If there are no later reductions for this subproblem,
move to the next later subproblem."
  ()
  (debugger-command-invocation command/later-reduction))

(define-command continuation-browser-show-current-frame
  "Print the bindings of the current frame of the current environment."
  ()
  (debugger-command-invocation command/show-current-frame))

(define-command continuation-browser-show-all-frames
  "Print the bindings of all frames of the current environment."
  ()
  (debugger-command-invocation command/show-all-frames))

(define-command continuation-browser-move-to-parent-environment
  "Move to the environment frame that is the parent of the current one."
  ()
  (debugger-command-invocation command/move-to-parent-environment))

(define-command continuation-browser-move-to-child-environment
  "Move to the environment frame that is the child of the current one."
  ()
  (debugger-command-invocation command/move-to-child-environment))

(define-command continuation-browser-return
  "Invoke the continuation that is the current subproblem.
Prompts for a value to give the continuation as an argument."
  ()
  (debugger-command-invocation command/return))

(define-command continuation-browser-frame
  "Show the current subproblem's stack frame in internal format."
  ()
  (debugger-command-invocation command/frame))

(define-command continuation-browser-quit
  "Kill the current continuation browser."
  ()
  (lambda ()
    (kill-buffer-interactive (current-buffer))))

(define-command continuation-browser-condition-report
  "Show the error message that started the continuation browser, if any."
  ()
  (debugger-command-invocation command/condition-report))

(define-command continuation-browser-condition-restart
  "Continue the program using a standard restart option."
  ()
  (debugger-command-invocation command/condition-restart))

(define-major-mode continuation-browser read-only "Debug"
  "You are in the Scheme debugger, where you can do the following:

\\[continuation-browser-show-all-frames] shows All bindings of the current environment and its ancestors.
\\[continuation-browser-earlier-reduction] moves Back to the next reduction (earlier in time).
\\[continuation-browser-show-current-frame] shows bindings of identifiers in the Current environment.
\\[continuation-browser-later-subproblem] moves Down to the previous subproblem (later in time).
\\[continuation-browser-later-reduction] moves Forward to the previous reduction (later in time).
\\[continuation-browser-goto] Goes to an arbitrary subproblem.
\\[continuation-browser-summarize-subproblems] prints a summary (History) of all subproblems.
\\[continuation-browser-condition-report] prints the error message Info.
\\[continuation-browser-print-expression] pretty prints the current expression.
\\[continuation-browser-print-environment-procedure] pretty prints the procedure that created the current environment.
\\[continuation-browser-move-to-parent-environment] moves to the environment that is the Parent of the current environment.
\\[continuation-browser-print-reductions] shows the execution history (Reductions) of the current subproblem level.
\\[continuation-browser-move-to-child-environment] moves to the child of the current environment (in current chain).
\\[continuation-browser-print-subproblem-or-reduction] shows the current subproblem or reduction.
\\[continuation-browser-earlier-subproblem] moves Up to the next subproblem (earlier in time).
\\[continuation-browser-frame] displays the current stack frame in internal format.
\\[continuation-browser-return] returns (continues with) an expression after evaluating it."
  (local-set-variable! scheme-environment (ref-variable scheme-environment)))

(define-key 'continuation-browser #\? 'describe-mode)
(define-key 'continuation-browser #\a 'continuation-browser-show-all-frames)
(define-key 'continuation-browser #\b 'continuation-browser-earlier-reduction)
(define-key 'continuation-browser #\c 'continuation-browser-show-current-frame)
(define-key 'continuation-browser #\d 'continuation-browser-later-subproblem)
(define-key 'continuation-browser #\f 'continuation-browser-later-reduction)
(define-key 'continuation-browser #\g 'continuation-browser-goto)
(define-key 'continuation-browser #\h
  'continuation-browser-summarize-subproblems)
(define-key 'continuation-browser #\i 'continuation-browser-condition-report)
(define-key 'continuation-browser #\l 'continuation-browser-print-expression)
(define-key 'continuation-browser #\o
  'continuation-browser-print-environment-procedure)
(define-key 'continuation-browser #\p
  'continuation-browser-move-to-parent-environment)
(define-key 'continuation-browser #\q 'continuation-browser-quit)
(define-key 'continuation-browser #\r 'continuation-browser-print-reductions)
(define-key 'continuation-browser #\s
  'continuation-browser-move-to-child-environment)
(define-key 'continuation-browser #\t
  'continuation-browser-print-subproblem-or-reduction)
(define-key 'continuation-browser #\u 'continuation-browser-earlier-subproblem)
(define-key 'continuation-browser #\v 'eval-expression)
(define-key 'continuation-browser #\y 'continuation-browser-frame)
(define-key 'continuation-browser #\z 'continuation-browser-return)