#| -*-Scheme-*-

$Id: boot.scm,v 14.12 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1988-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; Boot Time Definitions
;;; package: ()

(declare (usual-integrations))

(define standard-unparser-method)
(define unparser/standard-method)
(let ((make-method
       (lambda (name unparser)
	 (lambda (state object)
	   (let ((port (unparser-state/port state))
		 (hash-string (number->string (hash object))))
	     (if *unparse-with-maximum-readability?*
		 (begin
		   (write-string "#@" port)
		   (write-string hash-string port))
		 (begin
		   (write-string "#[" port)
		   (if (string? name)
		       (write-string name port)
		       (with-current-unparser-state state
			 (lambda (port)
			   (write name port))))
		   (write-char #\space port)
		   (write-string hash-string port)
		   (if unparser (unparser state object))
		   (write-char #\] port))))))))
  (set! standard-unparser-method
	(lambda (name unparser)
	  (make-method name
		       (and unparser
			    (lambda (state object)
			      (with-current-unparser-state state
				(lambda (port)
				  (unparser object port))))))))
  (set! unparser/standard-method
	(lambda (name #!optional unparser)
	  (make-method name
		       (and (not (default-object? unparser))
			    unparser
			    (lambda (state object)
			      (unparse-char state #\space)
			      (unparser state object)))))))

(define (unparser-method? object)
  (and (procedure? object)
       (procedure-arity-valid? object 2)))

(define-integrable interrupt-bit/stack     #x0001)
(define-integrable interrupt-bit/global-gc #x0002)
(define-integrable interrupt-bit/gc        #x0004)
(define-integrable interrupt-bit/global-1  #x0008)
(define-integrable interrupt-bit/kbd       #x0010)
(define-integrable interrupt-bit/after-gc  #x0020)
(define-integrable interrupt-bit/timer     #x0040)
(define-integrable interrupt-bit/global-3  #x0080)
(define-integrable interrupt-bit/suspend   #x0100)
;; Interrupt bits #x0200 through #x4000 inclusive are reserved
;; for the Descartes PC sampler.

;; GC & stack overflow only
(define-integrable interrupt-mask/gc-ok    #x0007)

;; GC, stack overflow, and keyboard only
(define-integrable interrupt-mask/no-background #x0017)

;; GC, stack overflow, and timer only
(define-integrable interrupt-mask/timer-ok #x0047)

;; Absolutely everything off
(define-integrable interrupt-mask/none     #x0000)

;; Normal: all enabled
(define-integrable interrupt-mask/all      #xFFFF)

(define (with-absolutely-no-interrupts thunk)
  (with-interrupt-mask interrupt-mask/none
    (lambda (interrupt-mask)
      interrupt-mask
      (thunk))))

(define (without-interrupts thunk)
  (with-interrupt-mask interrupt-mask/gc-ok
    (lambda (interrupt-mask)
      interrupt-mask
      (thunk))))

(define (without-background-interrupts thunk)
  (with-interrupt-mask interrupt-mask/no-background
    (lambda (interrupt-mask)
      interrupt-mask
      (thunk))))

(define-primitives
  (object-pure? pure?)
  (object-constant? constant?)
  get-next-constant)

(define-integrable (future? object)
  ((ucode-primitive object-type? 2) (ucode-type future) object))