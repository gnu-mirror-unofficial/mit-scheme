;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/winout.scm,v 1.1 1989/03/14 08:08:57 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989 Massachusetts Institute of Technology
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

;;;; Buffer I/O Ports

(declare (usual-integrations))

(define (with-output-to-current-point thunk)
  (with-output-to-window-point (current-window) thunk))

(define (with-output-to-window-point window thunk)
  (with-interactive-output-port (window-output-port window) thunk))

(define (with-interactive-output-port port thunk)
  (with-output-to-port port
    (lambda ()
      (with-cmdl/output-port (nearest-cmdl) port thunk))))

(define (window-output-port window)
  (output-port/copy window-output-port-template window))

(define (operation/write-char port char)
  (let ((window (output-port/state port)))
    (let ((buffer (window-buffer window))
	  (point (window-point window)))
      (if (and (null? (cdr (buffer-windows buffer)))
	       (line-end? point)
	       (buffer-auto-save-modified? buffer)
	       (or (not (window-needs-redisplay? window))
		   (window-direct-update! window false)))
	  (cond ((and (group-end? point)
		      (char=? char #\newline)
		      (< (1+ (window-point-y window)) (window-y-size window)))
		 (window-direct-output-insert-newline! window))
		((and (char-graphic? char)
		      (< (1+ (window-point-x window)) (window-x-size window)))
		 (window-direct-output-insert-char! window char))
		(else
		 (region-insert-char! point char)))
	  (region-insert-char! point char)))))

(define (operation/write-string port string)
  (let ((window (output-port/state port)))
    (let ((buffer (window-buffer window))
	  (point (window-point window)))
      (if (and (null? (cdr (buffer-windows buffer)))
	       (line-end? point)
	       (buffer-auto-save-modified? buffer)
	       (or (not (window-needs-redisplay? window))
		   (window-direct-update! window false))
	       (not (string-find-next-char-in-set string char-set:not-graphic))
	       (< (+ (string-length string) (window-point-x window))
		  (window-x-size window)))
	  (window-direct-output-insert-substring! window
						  string
						  0
						  (string-length string))
	  (region-insert-string! point string)))))

(define (operation/flush-output port)
  (let ((window (output-port/state port)))
    (if (window-needs-redisplay? window)
	(window-direct-update! window false))))

(define (operation/print-self state port)
  (unparse-string state "to window ")
  (unparse-object state (output-port/state port)))

(define window-output-port-template
  (make-output-port `((FLUSH-OUTPUT ,operation/flush-output)		      (PRINT-SELF ,operation/print-self)
		      (WRITE-CHAR ,operation/write-char)
		      (WRITE-STRING ,operation/write-string))
		    false))