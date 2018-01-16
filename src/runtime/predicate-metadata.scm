#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016,
    2017 Massachusetts Institute of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.

|#

;;;; Predicates: metadata
;;; package: (runtime predicate-metadata)

(declare (usual-integrations))

(define get-predicate-tag)
(define set-predicate-tag!)
(add-boot-init!
 (lambda ()
   (let ((table (make-hashed-metadata-table)))
     (set! predicate? (table 'has?))
     (set! get-predicate-tag (table 'get))
     (set! set-predicate-tag! (table 'put!))
     unspecific)))

(define (predicate-name predicate)
  (tag-name (predicate->tag predicate 'predicate-name)))

(define (predicate->tag predicate #!optional caller)
  (let ((tag (get-predicate-tag predicate #f)))
    (if (not tag)
        (error:not-a predicate? predicate caller))
    tag))

(define (make-metatag name)
  (guarantee tag-name? name 'make-metatag)
  (letrec*
      ((predicate
	(lambda (object)
	  (and (%record? object)
	       (eq? metatag (%record-ref object 0)))))
       (metatag (%make-tag metatag-tag name predicate #f)))
    (set-tag<=! metatag metatag-tag)
    metatag))

(define (metatag-constructor metatag #!optional caller)
  (guarantee metatag? metatag 'metatag-constructor)
  (lambda (name predicate extra)
    (guarantee tag-name? name caller)
    (guarantee unary-procedure? predicate caller)
    (if (predicate? predicate)
	(error "Can't assign multiple tags to the same predicate:" predicate))
    (%make-tag metatag name predicate extra)))

(define (metatag? object)
  (and (%record? object)
       (eq? metatag-tag (%record-ref object 0))))

(define (tag-name? object)
  (or (symbol? object)
      (and (pair? object)
	   (symbol? (car object))
	   (list? (cdr object))
	   (every (lambda (elt)
		    (or (object-non-pointer? elt)
			(tag-name? elt)))
		  (cdr object)))))

(define metatag-tag)
(define simple-tag-metatag)
(define %make-simple-tag)
(add-boot-init!
 (lambda ()
   (set! metatag-tag (%make-tag #f 'metatag metatag? #f))
   (%record-set! metatag-tag 0 metatag-tag)
   (set! simple-tag-metatag
	 (make-metatag 'simple-tag))
   (set! %make-simple-tag
	 (metatag-constructor simple-tag-metatag 'register-predicate!))
   (run-deferred-boot-actions 'make-metatag)
   (set! register-predicate!
	 (named-lambda (register-predicate! predicate name . keylist)
	   (guarantee keyword-list? keylist 'register-predicate!)
	   (let ((tag (%make-simple-tag name predicate #f)))
	     (for-each (lambda (superset)
			 (set-tag<=! tag (predicate->tag superset)))
		       (get-keyword-values keylist '<=))
	     tag)))
   unspecific))

(defer-boot-action 'predicate-relations
  (lambda ()
    (set-predicate<=! metatag? tag?)))

(define (%make-tag metatag name predicate extra)
  (let ((tag (%record metatag name predicate extra (%make-weak-set))))
    (set-predicate-tag! predicate tag)
    tag))

(define (tag? object)
  (and (%record? object)
       (metatag? (%record-ref object 0))))

(define-unparser-method tag?
  (simple-unparser-method
   (lambda (tag)
     (if (metatag? tag) 'metatag 'tag))
   (lambda (tag)
     (list (tag-name tag)))))

(define-integrable (%tag-name tag)
  (%record-ref tag 1))

(define-integrable (%tag->predicate tag)
  (%record-ref tag 2))

(define-integrable (%tag-extra tag)
  (%record-ref tag 3))

(define-integrable (%tag-supersets tag)
  (%record-ref tag 4))

(define (tag-metatag tag)
  (guarantee tag? tag 'tag-metatag)
  (%record-ref tag 0))

(define (tag-name tag)
  (guarantee tag? tag 'tag-name)
  (%record-ref tag 1))

(define (tag->predicate tag)
  (guarantee tag? tag 'tag->predicate)
  (%tag->predicate tag))

(define (tag-extra tag)
  (guarantee tag? tag 'tag-extra)
  (%tag-extra tag))

(define (any-tag-superset procedure tag)
  (guarantee tag? tag 'any-tag-superset)
  (%weak-set-any procedure (%tag-supersets tag)))

(define (add-tag-superset tag superset)
  (guarantee tag? tag 'add-tag-superset)
  (guarantee tag? superset 'add-tag-superset)
  (%add-to-weak-set superset (%tag-supersets tag)))

(add-boot-init!
 (lambda ()
   (register-predicate! %record? '%record)
   (register-predicate! %tagged-object? 'tagged-object)
   (register-predicate! predicate? 'predicate)
   (register-predicate! tag-name? 'tag-name)
   (register-predicate! tag? 'tag '<= %record?)))

;;; Registration of standard predicates
(add-boot-init!
 (lambda ()
   ;; R7RS
   (register-predicate! boolean? 'boolean)
   (register-predicate! bytevector? 'bytevector)
   (register-predicate! char? 'char)
   (register-predicate! default-object? 'default-object)
   (register-predicate! eof-object? 'eof-object)
   (register-predicate! list? 'list)
   (register-predicate! number? 'number)
   (register-predicate! pair? 'pair)
   (register-predicate! procedure? 'procedure)
   (register-predicate! string? 'string)
   (register-predicate! symbol? 'symbol)
   (register-predicate! vector? 'vector)

   (register-predicate! real? 'real-number '<= number?)
   (register-predicate! rational? 'rational-number '<= real?)
   (register-predicate! integer? 'integer '<= rational?)

   (register-predicate! null? 'empty-list '<= list?)

   ;; SRFI-1
   (register-predicate! circular-list? 'circular-list)
   (register-predicate! dotted-list? 'dotted-list)
   (register-predicate! not-pair? 'not-pair)))

;;; Registration of predicates defined earlier in the boot load, or
;;; needed before their packages are initialized.
(add-boot-init!
 (lambda ()
   ;; MIT/GNU Scheme: specialized arithmetic
   (register-predicate! exact-integer? 'exact-integer '<= integer?)
   (register-predicate! exact-nonnegative-integer? 'exact-nonnegative-integer
			'<= exact-integer?)
   (register-predicate! exact-positive-integer? 'exact-positive-integer
			'<= exact-integer?)
   (register-predicate! exact-rational? 'exact-rational '<= rational?)

   (register-predicate! fix:fixnum? 'fixnum '<= exact-integer?)
   (register-predicate! index-fixnum? 'index-fixnum
			'<= fix:fixnum?
			'<= exact-nonnegative-integer?)
   (register-predicate! negative-fixnum? 'negative-fixnum '<= fix:fixnum?)
   (register-predicate! positive-fixnum? 'positive-fixnum
			'<= fix:fixnum?
			'<= exact-positive-integer?)
   (register-predicate! non-negative-fixnum? 'non-negative-fixnum
			'<= fix:fixnum?
			'<= exact-nonnegative-integer?)
   (register-predicate! non-positive-fixnum? 'non-positive-fixnum
			'<= fix:fixnum?)
   (register-predicate! radix? 'radix '<= index-fixnum?)

   (register-predicate! flo:flonum? 'flonum '<= real?)

   ;; MIT/GNU Scheme: lists
   (register-predicate! alist? 'association-list '<= list?)
   (register-predicate! keyword-list? 'keyword-list '<= list?)
   (register-predicate! list-of-unique-symbols? 'list-of-unique-symbols
			'<= list?)
   (register-predicate! non-empty-list? 'non-empty-list
			'<= list?
			'<= pair?)
   (register-predicate! unique-keyword-list? 'unique-keyword-list
			'<= keyword-list?)

   ;; MIT/GNU Scheme: procedures
   (register-predicate! apply-hook? 'apply-hook '<= procedure?)
   (register-predicate! binary-procedure? 'binary-procedure '<= procedure?)
   (register-predicate! compiled-procedure? 'compiled-procedure '<= procedure?)
   (register-predicate! entity? 'entity '<= procedure?)
   (register-predicate! memoizer? 'memoizer '<= apply-hook?)
   (register-predicate! primitive-procedure? 'primitive-procedure
			'<= procedure?)
   (register-predicate! procedure-arity? 'procedure-arity)
   (register-predicate! thunk? 'thunk '<= procedure?)
   (register-predicate! unary-procedure? 'unary-procedure '<= procedure?)
   (register-predicate! unparser-method? 'unparser-method '<= procedure?)))

(add-boot-init!
 (lambda ()
   ;; MIT/GNU Scheme: misc
   (register-predicate! 8-bit-char? '8-bit-char '<= char?)
   (register-predicate! ascii-char? 'ascii-char '<= 8-bit-char?)
   (register-predicate! bit-string? 'bit-string)
   (register-predicate! bitless-char? 'bitless-char '<= char?)
   (register-predicate! cell? 'cell)
   (register-predicate! code-point-list? 'code-point-list '<= list?)
   (register-predicate! compiled-code-address? 'compiled-code-address)
   (register-predicate! compiled-code-block? 'compiled-code-block)
   (register-predicate! compiled-expression? 'compiled-expression)
   (register-predicate! compiled-return-address? 'compiled-return-address)
   (register-predicate! dispatch-tag? 'dispatch-tag)
   (register-predicate! ephemeron? 'ephemeron)
   (register-predicate! environment? 'environment)
   (register-predicate! equality-predicate? 'equality-predicate
			'<= binary-procedure?)
   (register-predicate! interned-symbol? 'interned-symbol '<= symbol?)
   (register-predicate! keyword? 'keyword '<= symbol?)
   (register-predicate! lambda-tag? 'lambda-tag)
   (register-predicate! named-structure? 'named-structure)
   (register-predicate! named-list? 'named-list
			'<= non-empty-list?
			'<= named-structure?)
   (register-predicate! named-vector? 'named-vector
			'<= vector?
			'<= named-structure?)
   (register-predicate! population? 'population)
   (register-predicate! promise? 'promise)
   (register-predicate! record? 'record
			'<= %record?
			'<= named-structure?)
   (register-predicate! stack-address? 'stack-address)
   (register-predicate! thread-mutex? 'thread-mutex)
   (register-predicate! undefined-value? 'undefined-value)
   (register-predicate! unicode-code-point? 'unicode-code-point
			'<= index-fixnum?)
   (register-predicate! unicode-scalar-value? 'unicode-scalar-value
			'<= unicode-code-point?)
   (register-predicate! uninterned-symbol? 'uninterned-symbol '<= symbol?)
   (register-predicate! weak-list? 'weak-list)
   (register-predicate! weak-pair? 'weak-pair)

   (run-deferred-boot-actions 'predicate-registrations)))