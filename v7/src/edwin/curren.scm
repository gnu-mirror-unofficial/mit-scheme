;;; -*-Scheme-*-
;;;
;;;	$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/edwin/curren.scm,v 1.92 1991/04/21 00:30:35 cph Exp $
;;;
;;;	Copyright (c) 1986, 1989-91 Massachusetts Institute of Technology
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

;;;; Current State

(declare (usual-integrations))

;;;; Screens

(define-integrable (screen-list)
  (editor-screens current-editor))

(define-integrable (selected-screen)
  (editor-selected-screen current-editor))

(define-integrable (selected-screen? screen)
  (eq? screen (selected-screen)))

(define-integrable (multiple-screens?)
  (display-type/multiple-screens? (current-display-type)))

(define (make-screen buffer . make-screen-args)
  (let ((display-type (current-display-type)))
    (if (not (display-type/multiple-screens? display-type))
	(error "display doesn't support multiple screens" display-type))
    (without-interrupts
     (lambda ()
       (let ((screen (display-type/make-screen display-type make-screen-args)))
	 (initialize-screen-root-window! screen
					 (editor-bufferset current-editor)
					 buffer)
	 (set-editor-screens! current-editor
			      (append! (editor-screens current-editor)
				       (list screen)))
	 (update-screen! screen false)
	 screen)))))

(define (delete-screen! screen)
  (without-interrupts
   (lambda ()
     (if (selected-screen? screen)
	 (let ((screen* (other-screen screen)))
	   (if (not screen*)
	       (error "can't delete only screen" screen))
	   (select-screen screen*)))
     (screen-discard! screen)
     (set-editor-screens! current-editor
			  (delq! screen
				 (editor-screens current-editor))))))

(define (select-screen screen)
  (without-interrupts
   (lambda ()
     (let ((message (current-message)))
       (clear-current-message!)
       (screen-exit! (selected-screen))
       (change-selected-buffer
	(window-buffer (screen-selected-window screen))
	true
	(lambda ()
	  (set-editor-selected-screen! current-editor screen)))
       (set-current-message! message)
       (screen-enter! screen)))))

(define (update-screens! display-style)
  (if display-style
      (let loop ((screens (screen-list)))
	(or (null? screens)
	    (and (update-screen! (car screens) display-style)
		 (loop (cdr screens)))))
      (let loop ((screens (cons (selected-screen) (screen-list))))
	(or (null? screens)
	    (and (or (screen-in-update? (car screens))
		     (update-screen! (car screens) false))
		 (loop (cdr screens)))))))

(define (update-selected-screen! display-style)
  (update-screen! (selected-screen) display-style))

(define-integrable (screen0)
  (car (screen-list)))

(define (screen1+ screen)
  (let ((screens (screen-list)))
    (let ((s (memq screen screens)))
      (if (not s)
	  (error "not a member of screen-list" screen))
      (if (null? (cdr s))
	  (car screens)
	  (cadr s)))))

(define (screen-1+ screen)
  (let ((screens (screen-list)))
    (if (eq? screen (car screens))
	(car (last-pair screens))
	(let loop ((previous screens) (screens (cdr screens)))
	  (if (null? screens)
	      (error "not a member of screen-list" screen))
	  (if (eq? screen (car screens))
	      (car previous)
	      (loop screens (cdr screens)))))))

(define (screen+ screen n)
  (cond ((positive? n)
	 (let loop ((n n) (screen screen))
	   (if (= n 1)
	       (screen1+ screen)
	       (loop (-1+ n) (screen1+ screen)))))
	((negative? n)
	 (let loop ((n n) (screen screen))
	   (if (= n -1)
	       (screen-1+ screen)
	       (loop (1+ n) (screen-1+ screen)))))
	(else
	 screen)))

(define (other-screen screen)
  (let ((screen* (screen1+ screen)))
    (and (not (eq? screen screen*))
	 screen*)))

;;;; Windows

(define-integrable (current-window)
  (screen-selected-window (selected-screen)))

(define (window-list)
  (append-map screen-window-list (screen-list)))

(define-integrable (current-window? window)
  (eq? window (current-window)))

(define-integrable (window0)
  (screen-window0 (selected-screen)))

(define (select-window window)
  (without-interrupts
   (lambda ()
     (let ((screen (window-screen window)))
       (if (selected-screen? screen)
	   (change-selected-buffer (window-buffer window) true
	     (lambda ()
	       (screen-select-window! screen window)))
	   (begin
	     (screen-select-window! screen window)
	     (select-screen screen)))))))

(define-integrable (select-cursor window)
  (screen-select-cursor! (window-screen window) window))

(define (window-visible? window)
  (or (typein-window? window)
      (let ((window0 (window0)))
	(let loop ((window* (window1+ window0)))
	  (or (eq? window window*)
	      (and (not (eq? window* window0))
		   (loop (window1+ window*))))))))

(define (other-window #!optional n)
  (let ((n (if (or (default-object? n) (not n)) 1 n))
	(window (current-window)))
    (cond ((positive? n)
	   (let loop ((n n) (window window))
	     (if (zero? n)
		 window
		 (loop (-1+ n)
		       (if (typein-window? window)
			   (window0)
			   (let ((window (window1+ window)))
			     (if (and (within-typein-edit?)
				      (eq? window (window0)))
				 (typein-window)
				 window)))))))
	  ((negative? n)
	   (let loop ((n n) (window window))
	     (if (zero? n)
		 window
		 (loop (1+ n)
		       (if (and (within-typein-edit?)
				(eq? window (window0)))
			   (typein-window)
			   (window-1+ (if (typein-window? window)
					  (window0)
					  window)))))))
	  (else
	   window))))

(define-integrable (typein-window)
  (screen-typein-window (selected-screen)))

(define-integrable (typein-window? window)
  (eq? window (screen-typein-window (window-screen window))))

(define-integrable (current-message)
  (window-override-message (typein-window)))

(define (set-current-message! message)
  (let ((window (typein-window)))
    (if message
	(window-set-override-message! window message)
	(window-clear-override-message! window))
    (if (not *executing-keyboard-macro?*)
	(window-direct-update! window true))))

(define (clear-current-message!)
  (let ((window (typein-window)))
    (window-clear-override-message! window)
    (if (not *executing-keyboard-macro?*)
	(window-direct-update! window true))))

;;;; Buffers

(define-integrable (buffer-list)
  (bufferset-buffer-list (current-bufferset)))

(define-integrable (buffer-alive? buffer)
  (memq buffer (buffer-list)))

(define-integrable (buffer-names)
  (bufferset-names (current-bufferset)))

(define-integrable (current-buffer? buffer)
  (eq? buffer (current-buffer)))

(define-integrable (current-buffer)
  (window-buffer (current-window)))

(define-integrable (previous-buffer)
  (other-buffer (current-buffer)))

(define (other-buffer buffer)
  (let loop ((less-preferred false) (buffers (buffer-list)))
    (cond ((null? buffers)
	   less-preferred)
	  ((or (eq? buffer (car buffers))
	       (minibuffer? (car buffers)))
	   (loop less-preferred (cdr buffers)))
	  ((buffer-visible? (car buffers))
	   (loop (or less-preferred (car buffers)) (cdr buffers)))
	  (else
	   (car buffers)))))

(define-integrable (bury-buffer buffer)
  (bufferset-bury-buffer! (current-bufferset) buffer))

(define-integrable (find-buffer name)
  (bufferset-find-buffer (current-bufferset) name))

(define-integrable (create-buffer name)
  (bufferset-create-buffer (current-bufferset) name))

(define-integrable (find-or-create-buffer name)
  (bufferset-find-or-create-buffer (current-bufferset) name))

(define-integrable (rename-buffer buffer new-name)
  (bufferset-rename-buffer (current-bufferset) buffer new-name))

(define (kill-buffer buffer)
  (let loop
      ((windows (buffer-windows buffer))
       (last-buffer false))
    (if (not (null? windows))
	(let ((new-buffer
	       (or (other-buffer buffer)
		   last-buffer
		   (error "Buffer to be killed has no replacement" buffer))))
	  (set-window-buffer! (car windows) new-buffer false)
	  (loop (cdr windows) new-buffer))))
  (for-each (lambda (process)
	      (hangup-process process true)
	      (set-process-buffer! process false))
	    (buffer-processes buffer))
  (bufferset-kill-buffer! (current-bufferset) buffer))

(define-integrable (select-buffer buffer)
  (set-window-buffer! (current-window) buffer true))

(define-integrable (select-buffer-no-record buffer)
  (set-window-buffer! (current-window) buffer false))

(define-integrable (select-buffer-in-window buffer window)
  (set-window-buffer! window buffer true))

(define (set-window-buffer! window buffer record?)
  (without-interrupts
   (lambda ()
     (if (current-window? window)
	 (change-selected-buffer buffer record?
	   (lambda ()
	     (%set-window-buffer! window buffer)))
	 (%set-window-buffer! window buffer)))))

(define-variable select-buffer-hook
  "An event distributor that is invoked when a buffer is selected.
The new buffer and the window in which it is selected are passed as arguments.
The buffer is guaranteed to be selected at that time."
  (make-event-distributor))

(define (change-selected-buffer buffer record? selection-thunk)
  (change-local-bindings! (current-buffer) buffer selection-thunk)
  (if record?
      (bufferset-select-buffer! (current-bufferset) buffer))
  (if (not (minibuffer? buffer))
      (event-distributor/invoke! (ref-variable select-buffer-hook) buffer)))

(define (with-selected-buffer buffer thunk)
  (let ((old-buffer))
    (dynamic-wind (lambda ()
		    (let ((window (current-window)))
		      (set! old-buffer (window-buffer window))
		      (if (buffer-alive? buffer)
			  (set-window-buffer! window buffer true)))
		    (set! buffer)
		    unspecific)
		  thunk
		  (lambda ()
		    (let ((window (current-window)))
		      (set! buffer (window-buffer window))
		      (if (buffer-alive? old-buffer)
			  (set-window-buffer! window old-buffer true)))
		    (set! old-buffer)
		    unspecific))))

(define (current-process)
  (let ((process (get-buffer-process (current-buffer))))
    (if (not process)
	(editor-error "Current buffer has no process"))
    process))

;;;; Point

(define-integrable (current-point)
  (window-point (current-window)))

(define-integrable (set-current-point! mark)
  (set-window-point! (current-window) mark))

(define (set-buffer-point! buffer mark)
  (let ((windows (buffer-windows buffer)))
    (if (null? windows)
	(%set-buffer-point! buffer mark)
	(for-each (lambda (window)
		    (set-window-point! window mark))
		  windows))))

(define (with-current-point point thunk)
  (let ((old-point))
    (dynamic-wind (lambda ()
		    (let ((window (current-window)))
		      (set! old-point (window-point window))
		      (set-window-point! window point))
		    (set! point)
		    unspecific)
		  thunk
		  (lambda ()
		    (let ((window (current-window)))
		      (set! point (window-point window))
		      (set-window-point! window old-point))
		    (set! old-point)
		    unspecific))))

(define-integrable (current-column)
  (mark-column (current-point)))

;;;; Mark and Region

(define-integrable (current-mark)
  (buffer-mark (current-buffer)))

(define (buffer-mark buffer)
  (let ((ring (buffer-mark-ring buffer)))
    (if (ring-empty? ring)
	(editor-error)
	(ring-ref ring 0))))

(define (set-current-mark! mark)
  (set-buffer-mark! (current-buffer) (guarantee-mark mark)))

(define-integrable (set-buffer-mark! buffer mark)
  (ring-set! (buffer-mark-ring buffer) 0 (mark-right-inserting-copy mark)))

(define-variable auto-push-point-notification
  "Message to display when point is pushed on the mark ring.
If false, don't display any message."
  "Mark set"
  string-or-false?)

(define (push-current-mark! mark)
  (push-buffer-mark! (current-buffer) (guarantee-mark mark))
  (let ((notification (ref-variable auto-push-point-notification)))
    (if (and notification
	     (not *executing-keyboard-macro?*)
	     (not (typein-window? (current-window))))
	(temporary-message notification))))

(define-integrable (push-buffer-mark! buffer mark)
  (ring-push! (buffer-mark-ring buffer) (mark-right-inserting-copy mark)))

(define-integrable (pop-current-mark!)
  (pop-buffer-mark! (current-buffer)))

(define-integrable (pop-buffer-mark! buffer)
  (ring-pop! (buffer-mark-ring buffer)))

(define-integrable (current-region)
  (make-region (current-point) (current-mark)))

(define (set-current-region! region)
  (set-current-point! (region-start region))
  (push-current-mark! (region-end region)))

(define (set-current-region-reversed! region)
  (push-current-mark! (region-start region))
  (set-current-point! (region-end region)))

;;;; Modes and Comtabs

(define-integrable (current-major-mode)
  (buffer-major-mode (current-buffer)))

(define-integrable (current-minor-modes)
  (buffer-minor-modes (current-buffer)))

(define-integrable (current-comtabs)
  (buffer-comtabs (current-buffer)))

(define-integrable (set-current-major-mode! mode)
  (set-buffer-major-mode! (current-buffer) mode))

(define-integrable (current-minor-mode? mode)
  (buffer-minor-mode? (current-buffer) mode))

(define-integrable (enable-current-minor-mode! mode)
  (enable-buffer-minor-mode! (current-buffer) mode))

(define-integrable (disable-current-minor-mode! mode)
  (disable-buffer-minor-mode! (current-buffer) mode))