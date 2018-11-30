#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016,
    2017, 2018 Massachusetts Institute of Technology

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

;;;; SCode Optimizer: Global Constants List
;;; package: (scode-optimizer)

(declare (usual-integrations))

(define global-constant-objects
  '(char-bits-limit
    char-code-limit
    false
    scode-lambda-name:unnamed		;needed for cold load
    system-global-environment		;suppresses warnings about (access ...)
    the-empty-stream
    true
    undefined-scode-conditional-branch
    unspecific))

(define global-primitives
  '((%make-tagged-object %make-tagged-object 2)
    (%record %record)
    (%record-length %record-length)
    (%record-ref %record-ref)
    (%record-set! %record-set!)
    (%record? %record?)
    (%tagged-object-datum %tagged-object-datum 1)
    (%tagged-object-tag %tagged-object-tag 1)
    (%tagged-object? %tagged-object? 1)
    (%weak-cons weak-cons 2)
    (%weak-car weak-car 1)
    (%weak-set-car! weak-set-car! 2)
    (bit-string->unsigned-integer bit-string->unsigned-integer)
    (bit-string-allocate bit-string-allocate)
    (bit-string-and! bit-string-and!)
    (bit-string-andc! bit-string-andc!)
    (bit-string-clear! bit-string-clear!)
    (bit-string-fill! bit-string-fill!)
    (bit-string-length bit-string-length)
    (bit-string-move! bit-string-move!)
    (bit-string-movec! bit-string-movec!)
    (bit-string-or! bit-string-or!)
    (bit-string-ref bit-string-ref)
    (bit-string-set! bit-string-set!)
    (bit-string-xor! bit-string-xor!)
    (bit-string-zero? bit-string-zero?)
    (bit-string=? bit-string=?)
    (bit-string? bit-string?)
    (bit-substring-find-next-set-bit bit-substring-find-next-set-bit)
    (bit-substring-move-right! bit-substring-move-right!)
    (bytevector-length bytevector-length 1)
    (bytevector-u8-ref bytevector-u8-ref 2)
    (bytevector-u8-set! bytevector-u8-set! 3)
    (bytevector? bytevector? 1)
    (car car)
    (cdr cdr)
    (cell-contents cell-contents)
    (cell? cell?)
    (char->integer char->integer)
    (char? char?)
    (compiled-code-address->block compiled-code-address->block)
    (compiled-code-address->offset compiled-code-address->offset)
    (cons cons)
    (eq? eq?)
    (error-procedure error-procedure)
    (exact-integer? integer?)
    (false? not)
    (fix:* multiply-fixnum)
    (fix:+ plus-fixnum)
    (fix:- minus-fixnum)
    (fix:-1+ minus-one-plus-fixnum)
    (fix:1+ one-plus-fixnum)
    (fix:< less-than-fixnum?)
    (fix:= equal-fixnum?)
    (fix:> greater-than-fixnum?)
    (fix:and fixnum-and)
    (fix:andc fixnum-andc)
    (fix:divide divide-fixnum)
    (fix:fixnum? fixnum?)
    (fix:gcd gcd-fixnum)
    (fix:lsh fixnum-lsh)
    (fix:negative? negative-fixnum?)
    (fix:not fixnum-not)
    (fix:or fixnum-or)
    (fix:positive? positive-fixnum?)
    (fix:quotient fixnum-quotient)
    (fix:remainder fixnum-remainder)
    (fix:xor fixnum-xor)
    (fix:zero? zero-fixnum?)
    (fixnum? fixnum?)
    (flo:* flonum-multiply)
    (flo:+ flonum-add)
    (flo:- flonum-subtract)
    (flo:/ flonum-divide)
    (flo:< flonum-less?)
    (flo:<> flonum-is-less-or-greater?)
    (flo:= flonum-equal?)
    (flo:> flonum-greater?)
    (flo:abs flonum-abs)
    (flo:acos flonum-acos)
    (flo:asin flonum-asin)
    (flo:atan flonum-atan)
    (flo:atan2 flonum-atan2)
    (flo:ceiling flonum-ceiling)
    (flo:ceiling->exact flonum-ceiling->exact)
    (flo:cos flonum-cos)
    (flo:exp flonum-exp)
    (flo:expm1 flonum-expm1)
    (flo:expt flonum-expt)
    (flo:finite? flonum-is-finite?)
    (flo:flonum? flonum?)
    (flo:floor flonum-floor)
    (flo:floor->exact flonum-floor->exact)
    (flo:infinite? flonum-is-infinite?)
    (flo:log flonum-log)
    (flo:log1p flonum-log1p)
    (flo:nan? flonum-is-nan?)
    (flo:negate flonum-negate)
    (flo:negative? flonum-negative?)
    (flo:normal? flonum-is-normal?)
    (flo:positive? flonum-positive?)
    (flo:round flonum-round)
    (flo:round->exact flonum-round->exact)
    (flo:safe< flonum-is-less?)
    (flo:safe<= flonum-is-less-or-equal?)
    (flo:safe<> flonum-is-less-or-greater?)
    (flo:safe> flonum-is-greater?)
    (flo:safe>= flonum-is-greater-or-equal?)
    (flo:sign-negative? flonum-is-negative?)
    (flo:sin flonum-sin)
    (flo:sqrt flonum-sqrt)
    (flo:tan flonum-tan)
    (flo:truncate flonum-truncate)
    (flo:truncate->exact flonum-truncate->exact)
    (flo:unordered? flonum-is-unordered?)
    (flo:vector-cons floating-vector-cons)
    (flo:vector-length floating-vector-length)
    (flo:vector-ref floating-vector-ref)
    (flo:vector-set! floating-vector-set!)
    (flo:zero? flonum-zero?)
    (get-fixed-objects-vector get-fixed-objects-vector)
    (get-interrupt-enables get-interrupt-enables)
    (hunk3-cons hunk3-cons)
    (index-fixnum? index-fixnum?)
    (int:* integer-multiply)
    (int:+ integer-add)
    (int:- integer-subtract)
    (int:-1+ integer-subtract-1)
    (int:1+ integer-add-1)
    (int:< integer-less?)
    (int:= integer-equal?)
    (int:> integer-greater?)
    (int:divide integer-divide)
    (int:integer? integer?)
    (int:negate integer-negate)
    (int:negative? integer-negative?)
    (int:positive? integer-positive?)
    (int:quotient integer-quotient)
    (int:remainder integer-remainder)
    (int:zero? integer-zero?)
    (integer->char integer->char)
    (lexical-assignment lexical-assignment)
    (lexical-reference lexical-reference)
    (lexical-unassigned? lexical-unassigned?)
    (lexical-unbound? lexical-unbound?)
    (lexical-unreferenceable? lexical-unreferenceable?)
    (local-assignment local-assignment)
    (make-bit-string make-bit-string)
    (make-cell make-cell)
    (make-non-pointer-object make-non-pointer-object)
    (not not)
    (null? null?)
    (object-datum object-datum)
    (object-new-type object-set-type)
    (object-type object-type)
    (object-type? object-type?)
    (pair? pair?)
    (primitive-procedure-arity primitive-procedure-arity)
    (primitive-procedure-documentation primitive-procedure-documentation)
    (read-bits! read-bits!)
    (set-car! set-car!)
    (set-cdr! set-cdr!)
    (set-cell-contents! set-cell-contents!)
    (set-interrupt-enables! set-interrupt-enables!)
    (stack-address-offset stack-address-offset)
    (system-hunk3-cxr0 system-hunk3-cxr0)
    (system-hunk3-cxr1 system-hunk3-cxr1)
    (system-hunk3-cxr2 system-hunk3-cxr2)
    (system-hunk3-set-cxr0! system-hunk3-set-cxr0!)
    (system-hunk3-set-cxr1! system-hunk3-set-cxr1!)
    (system-hunk3-set-cxr2! system-hunk3-set-cxr2!)
    (system-list->vector system-list-to-vector)
    (system-pair-car system-pair-car)
    (system-pair-cdr system-pair-cdr)
    (system-pair-cons system-pair-cons)
    (system-pair-set-car! system-pair-set-car!)
    (system-pair-set-cdr! system-pair-set-cdr!)
    (system-pair? system-pair?)
    (system-subvector->list system-subvector-to-list)
    (system-vector-length system-vector-size)
    (system-vector-ref system-vector-ref)
    (system-vector-set! system-vector-set!)
    (system-vector? system-vector?)
    (unsigned-integer->bit-string unsigned-integer->bit-string)
    (vector vector)
    (vector-length vector-length)
    (vector-ref vector-ref)
    (vector-set! vector-set!)
    (vector? vector?)
    (weak-cdr weak-cdr 1)
    (weak-pair? weak-pair? 1)
    (weak-pair/car? weak-car 1)
    (weak-set-cdr! weak-set-cdr! 2)
    (with-history-disabled with-history-disabled)
    (with-interrupt-mask with-interrupt-mask)
    (write-bits! write-bits!)))