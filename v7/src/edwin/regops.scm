;;; -*-Scheme-*-
;;;
;;; $Id: regops.scm,v 1.87 1999/01/02 06:11:34 cph Exp $
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

;;;; Region/Mark Operations

(declare (usual-integrations))

(define (region-insert! mark region)
  (let ((string (region->string region))
	(group (mark-group mark))
	(start (mark-index mark)))
    (let ((n (string-length string)))
      (group-insert-substring! group start string 0 n)
      (%make-region (make-temporary-mark group start false)
		    (make-temporary-mark group (+ start n) true)))))

(define (region-insert-string! mark string)
  (group-insert-substring! (mark-group mark) (mark-index mark)
			   string 0 (string-length string)))

(define (region-insert-substring! mark string start end)
  (group-insert-substring! (mark-group mark) (mark-index mark)
			   string start end))

(define (region-insert-newline! mark)
  (group-insert-char! (mark-group mark) (mark-index mark) #\newline))

(define (region-insert-char! mark char)
  (group-insert-char! (mark-group mark) (mark-index mark) char))

(define (region->string region)
  (group-extract-string (region-group region)
			(region-start-index region)
			(region-end-index region)))

(define (region-delete! region)
  (group-delete! (region-group region)
		 (region-start-index region)
		 (region-end-index region)))

(define (mark-left-char mark)
  (and (not (group-start? mark))
       (group-left-char (mark-group mark) (mark-index mark))))

(define (mark-right-char mark)
  (and (not (group-end? mark))
       (group-right-char (mark-group mark) (mark-index mark))))

(define (mark-delete-left-char! mark)
  (if (group-start? mark)
      (error "No left char:" mark))
  (group-delete-left-char! (mark-group mark) (mark-index mark)))

(define (mark-delete-right-char! mark)
  (if (group-end? mark)
      (error "No right char:" mark))
  (group-delete-right-char! (mark-group mark) (mark-index mark)))

;;; **** This is not a great thing to do.  It will screw up any marks
;;; that are within the region, pushing them to either side.
;;; Conceptually we just want the characters to be altered.

(define (region-transform! region operation)
  (let ((m (mark-right-inserting-copy (region-start region)))
	(string (operation (region->string region))))
    (region-delete! region)
    (region-insert-string! m string)
    (mark-temporary! m)))

;;;; Clipping

(define (group-narrow! group start end)
  (record-clipping! group start end)
  (%group-narrow! group start end))

(define (%group-narrow! group start end)
  (let ((start (make-permanent-mark group start false))
	(end (make-permanent-mark group end true)))
    (set-group-start-mark! group start)
    (set-group-end-mark! group end)
    (set-group-display-start! group start)
    (set-group-display-end! group end)))

(define (group-widen! group)
  (record-clipping! group 0 (group-length group))
  (%group-widen! group))

(define (%group-widen! group)
  (%group-narrow! group 0 (group-length group)))

(define (region-clip! region)
  (let ((group (region-group region))
	(start (region-start region))
	(end (region-end region)))
    (let ((point (group-point group)))
      (cond ((mark< point start) (set-group-point! group start))
	    ((mark> point end) (set-group-point! group end))))
    (let ((buffer (group-buffer group)))
      (if buffer
	  (for-each
	   (lambda (window)
	     (let ((point (window-point window)))
	       (cond ((mark< point start) (set-window-point! window start))
		     ((mark> point end) (set-window-point! window end)))))
	   (buffer-windows buffer))))
    (group-narrow! group (mark-index start) (mark-index end))))

(define (with-region-clipped! new-region thunk)
  (let ((group (region-group new-region))
	(old-region))
    (unwind-protect (lambda ()
		      (set! old-region (group-region group))
		      (region-clip! new-region)
		      (set! new-region)
		      unspecific)
		    thunk
		    (lambda ()
		      (region-clip! old-region)))))

(define (without-group-clipped! group thunk)
  (let ((old-region))
    (unwind-protect (lambda ()
		      (set! old-region (group-region group))
		      (group-widen! group))
		    thunk
		    (lambda ()
		      (region-clip! old-region)))))

(define (group-clipped? group)
  (not (and (zero? (group-start-index group))
	    (= (group-end-index group) (group-length group)))))

(define (group-unclipped-region group)
  (make-region (make-mark group 0)
	       (make-mark group (group-length group))))