;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/edtfrm.scm,v 1.76 1989/06/20 16:09:08 markf Exp $
;;;
;;;	Copyright (c) 1985, 1989 Massachusetts Institute of Technology
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

;;;; Editor Frame

(declare (usual-integrations))

;;; Editor Frame

(define-class editor-frame vanilla-window
  (screen
   root-inferior
   typein-inferior
   selected-window
   cursor-window
   select-time
   properties))

(define (make-editor-frame root-screen main-buffer typein-buffer)
  (let ((window (make-object editor-frame)))
    (with-instance-variables editor-frame
			     window
			     (root-screen main-buffer typein-buffer)
      (set! superior false)
      (set! x-size (screen-x-size root-screen))
      (set! y-size (screen-y-size root-screen))
      (set! redisplay-flags (list false))
      (set! inferiors '())
      (set! properties (make-1d-table))
      (let ((main-window (make-buffer-frame window main-buffer true))
	    (typein-window (make-buffer-frame window typein-buffer false)))
	(set! screen root-screen)
	(set! root-inferior (find-inferior inferiors main-window))
	(set! typein-inferior (find-inferior inferiors typein-window))
	(set! selected-window main-window)
	(set! cursor-window main-window)
	(set! select-time 2)
	(set-window-select-time! main-window 1)
	(=> (window-cursor main-window) :enable!))
      (set-editor-frame-size! window x-size y-size))
    window))

(define-method editor-frame (:update-root-display! window display-style)
  (with-instance-variables editor-frame window (display-style)
    (with-screen-in-update! screen
      (lambda ()
	(if (and (or display-style (car redisplay-flags))
		 (update-inferiors! window screen 0 0
				    0 x-size 0 y-size
				    display-style))
	    (set-car! redisplay-flags false))))))

(define (set-editor-frame-size! window x y)
  (with-instance-variables editor-frame window (x y)
    (usual=> window :set-size! x y)
    (set-inferior-start! root-inferior 0 0)
    (let ((y* (- y typein-y-size)))
      (set-inferior-start! typein-inferior 0 y*)
      (set-inferior-size! root-inferior x y*))
    (set-inferior-size! typein-inferior x-size typein-y-size)))

(define-method editor-frame :set-size!
  set-editor-frame-size!)

(define typein-y-size 1)

(define-method editor-frame (:new-root-window! window window*)
  (set! root-inferior (find-inferior inferiors window*))
  unspecific)

(define-integrable (editor-frame-window0 window)
  (with-instance-variables editor-frame window ()
    (window0 (inferior-window root-inferior))))

(define-integrable (editor-frame-typein-window window)
  (with-instance-variables editor-frame window ()
    (inferior-window typein-inferior)))

(define-integrable (editor-frame-selected-window window)
  (with-instance-variables editor-frame window ()
    selected-window))

(define-integrable (editor-frame-cursor-window window)
  (with-instance-variables editor-frame window ()
    cursor-window))

(define-integrable (editor-frame-root-window window)
  (with-instance-variables editor-frame window ()
    (inferior-window root-inferior)))

(define-integrable (editor-frame-screen window)
  (with-instance-variables editor-frame window ()
    screen))
(define (editor-frame-select-window! window window*)
  (with-instance-variables editor-frame window (window*)
    (if (not (buffer-frame? window*))
	(error "Attempt to select non-window" window*))
    (=> (window-cursor cursor-window) :disable!)
    (set! selected-window window*)
    (set-window-select-time! window* select-time)
    (set! select-time (1+ select-time))
    (set! cursor-window window*)
    (=> (window-cursor cursor-window) :enable!)))

(define (editor-frame-select-cursor! window window*)
  (with-instance-variables editor-frame window (window*)
    (if (not (buffer-frame? window*))
	(error "Attempt to select non-window" window*))
    (=> (window-cursor cursor-window) :disable!)
    (set! cursor-window window*)
    (=> (window-cursor cursor-window) :enable!)))

;; Button events

(define (make-down-button button-number)
  (string->symbol
   (string-append "#[button-down-"
		  (number->string button-number)
		  "]")))

(define (make-up-button button-number)
  (string->symbol
   (string-append "#[button-up-"
		  (number->string button-number)
		  "]")))

(define up-buttons
  (do ((vec (make-vector (1+ (max-button-number))))
       (i (max-button-number) (-1+ i)))
      ((negative? i) vec)
    (vector-set! vec i (make-up-button i))))

(define down-buttons
  (do ((vec (make-vector (1+ (max-button-number))))
       (i (max-button-number) (-1+ i)))
      ((negative? i) vec)
    (vector-set! vec i (make-down-button i))))

(define (button? object)
  (or (vector-find-next-element up-buttons object)
      (vector-find-next-element down-buttons object)))
(define-integrable (get-up-button button-number)
  (vector-ref up-buttons button-number))

(define-integrable (get-down-button button-number)
  (vector-ref down-buttons button-number))

(define-integrable (button-upify button-number)
  (get-up-button button-number))

(define-integrable (button-downify button-number)
  (get-down-button button-number))

(define (buffer-button-down buffer button-number)
  (comtab-entry (buffer-comtabs buffer)
		(button-downify button-number)))

(define (buffer-button-up buffer button-number)
  (comtab-entry (buffer-comtabs buffer)
		(button-upify button-number)))

(define (editor-frame-button editor-frame button-number
			     x-coord y-coord buffer-event)
  (values-let
   (((frame relative-x relative-y)
     (find-buffer-frame editor-frame
			x-coord
			y-coord)))
   (and frame
	(let* ((buffer-window
		(frame-text-inferior frame))
	       (button-command
		(buffer-event (%window-buffer buffer-window) button-number)))
	  (and button-command
	       (execute-command
		button-command
		(list frame relative-x relative-y)))))))
			     
(define-method editor-frame (:button-up window button-number x-coord y-coord)
  (editor-frame-button window button-number x-coord y-coord buffer-button-up))

(define-method editor-frame (:button-down window button-number x-coord y-coord)
  (editor-frame-button window button-number x-coord y-coord buffer-button-down))

(define (find-buffer-frame editor-frame x-coord y-coord)
  (values-let
   (((window relative-x relative-y)
     (inferior-containing-coordinates editor-frame
				      x-coord
				      y-coord
				      buffer-frame?)))
   (if window
       (=> window :leaf-containing-coordinates
	   relative-x relative-y)
       (values false 0 0))))