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

;;;; Tests for fasdumper

(declare (usual-integrations))

(define (define-enumerated-test name cases procedure)
  (define-test name
    (map (lambda (arguments)
           (lambda ()
             (apply procedure arguments)))
         cases)))

(define (equal-nan-scode? x y)
  (let loop ((x x) (y y))
    (cond ((and (flo:flonum? x) (flo:nan? x))
           (and (flo:flonum? y)
                (flo:nan? y)
                (eqv? (flo:sign-negative? x) (flo:sign-negative? y))
                (eqv? (flo:nan-quiet? x) (flo:nan-quiet? y))
                (eqv? (flo:nan-payload x) (flo:nan-payload y))))
          ((scode-access? x)
           (and (scode-access? y)
                (loop (scode-access-environment x)
                      (scode-access-environment y))
                (loop (scode-access-name x)
                      (scode-access-name y))))
          ((scode-assignment? x)
           (and (scode-assignment? y)
                (loop (scode-assignment-name x)
                      (scode-assignment-name y))
                (loop (scode-assignment-value x)
                      (scode-assignment-value y))))
          ((scode-assignment? x)
           (and (scode-assignment? y)
                (loop (scode-assignment-name x)
                      (scode-assignment-name y))
                (loop (scode-assignment-value x)
                      (scode-assignment-value y))))
          ((scode-combination? x)
           (and (scode-combination? y)
                (loop (scode-combination-operator x)
                      (scode-combination-operator y))
                (every loop
                       (scode-combination-operands x)
                       (scode-combination-operands y))))
          ((scode-comment? x)
           (and (scode-comment? y)
                (loop (scode-comment-text x)
                      (scode-comment-text y))
                (loop (scode-comment-expression x)
                      (scode-comment-expression y))))
          ((scode-conditional? x)
           (and (scode-conditional? y)
                (loop (scode-conditional-predicate x)
                      (scode-conditional-predicate y))
                (loop (scode-conditional-consequent x)
                      (scode-conditional-consequent y))
                (loop (scode-conditional-alternative x)
                      (scode-conditional-alternative y))))
          ((scode-definition? x)
           (and (scode-definition? y)
                (loop (scode-definition-name x)
                      (scode-definition-name y))
                (loop (scode-definition-value x)
                      (scode-definition-value y))))
          ((scode-delay? x)
           (and (scode-delay? y)
                (loop (scode-delay-expression x)
                      (scode-delay-expression y))))
          ((scode-disjunction? x)
           (and (scode-disjunction? y)
                (loop (scode-disjunction-predicate x)
                      (scode-disjunction-predicate y))
                (loop (scode-disjunction-alternative x)
                      (scode-disjunction-alternative y))))
          ((scode-lambda? x)
           (and (scode-lambda? y)
                (scode-lambda-components x
                  (lambda (xname xreq xopt xrest xaux xdecl xbody)
                    (scode-lambda-components y
                      (lambda (yname yreq yopt yrest yaux ydecl ybody)
                        (and (loop xname yname)
                             (every loop xreq yreq)
                             (every loop xopt yopt)
                             (loop xrest yrest)
                             (every loop xaux yaux)
                             (every loop xdecl ydecl)
                             (loop xbody ybody))))))))
          ((scode-quotation? x)
           (and (scode-quotation? y)
                (loop (scode-quotation-expression x)
                      (scode-quotation-expression y))))
          ((scode-sequence? x)
           (and (scode-sequence? y)
                (every loop
                       (scode-sequence-actions x)
                       (scode-sequence-actions y))))
          ((scode-the-environment? x)
           (scode-the-environment? y))
          ((scode-variable? x)
           (and (scode-variable? y)
                (loop (scode-variable-name x)
                      (scode-variable-name y))))
          (else
           (equal? x y)))))

(define-comparator equal-nan-scode? 'equal-nan-scode?)

(define assert-equal-nan-scode
  (simple-binary-assertion equal-nan-scode? #f))

(define-enumerated-test 'fasdump-invariance
  `(((1 . 2))
    (#())
    (#(0))
    (#(0 1))
    (#(0 1 2))
    (#(0 1 2 3))
    (#(0 1 2 3 4))
    (#(0 1 2 3 4 5))
    (#(0 1 2 3 4 5 6))
    (#(0 1 2 3 4 5 6 7))
    (#(0 1 2 3 4 5 6 7 8))
    (#(0 1 2 3 4 5 6 7 8 9))
    (#(0 1 2 3 4 5 6 7 8 9 10))
    (#(0 1 2 3 4 5 6 7 8 9 10 11))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12 13))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))
    (#(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17))
    ("")
    ("a")
    ("ab")
    ("abc")
    ("abcd")
    ("abcde")
    ("abcdef")
    ("abcdefg")
    ("abcdefgh")
    ("abcdefghi")
    ("abcdefghij")
    ("abcdefghijk")
    ("abcdefghijkl")
    ("abcdefghijklm")
    ("abcdefghijklmn")
    ("abcdefghijklmno")
    ("abcdefghijklmnop")
    ("abcdefghijklmnopq")
    ("abcdefghijklmnopqr")
    ("abcdefghijklmnopqrs")
    ("abcdefghijklmnopqrst")
    ("abcdefghijklmnopqrstu")
    ("abcdefghijklmnopqrstuv")
    ("abcdefghijklmnopqrstuvw")
    ("abcdefghijklmnopqrstuvwx")
    ("abcdefghijklmnopqrstuvwxy")
    ("abcdefghijklmnopqrstuvwxyz")
    ("\x0;abcdefghijklmnopqrstuvwxyz")
    (#u8())
    (#u8(1))
    (#u8(1 2))
    (#u8(1 2 3))
    (#u8(1 2 3 4))
    (#u8(1 2 3 4 5))
    (#u8(1 2 3 4 5 6))
    (#u8(1 2 3 4 5 6 7))
    (#u8(1 2 3 4 5 6 7 8))
    (#u8(1 2 3 4 5 6 7 8 9))
    (#u8(1 2 3 4 5 6 7 8 9 10))
    (#u8(1 2 3 4 5 6 7 8 9 10 11))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12 13))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))
    (#u8(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17))
    (#*)
    (#*0)
    (#*10)
    (#*010)
    (#*1010)
    (#*01010)
    (#*101010)
    (#*0101010)
    (#*10101010)
    (#*010101010)
    ;; XXX go up to 65
    (||)
    (x)
    (xyz)
    ;; XXX uninterned symbols
    (,(make-primitive-procedure 'quagga 42))
    ;; XXX reference trap
    ;; XXX interpreter return address, wtf?
    (#\U+0)
    (#\0)
    (#\U+1000)
    (,(expt 2 100))
    (-inf.0)
    (-123.)
    (,(flo:negate flo:smallest-positive-subnormal))
    (-0.)
    (0.)
    (,flo:smallest-positive-subnormal)
    (123.)
    (+inf.0)
    (,(flo:make-nan #f #t 0))
    (,(flo:make-nan #t #t 0))
    (,(flo:make-nan #f #t 1))
    (,(flo:make-nan #t #t 1))
    (,(flo:make-nan #f #f 1))
    (,(flo:make-nan #t #f 1))
    (1+2i)
    (1.+2.i)
    (#t)
    (#f)
    (())
    (#!key)
    (#!optional)
    (#!rest)
    (,(eof-object))
    (#!unspecific)
    (,(make-scode-access #f 'foo))
    (,(make-scode-assignment 'foo (make-scode-variable 'bar)))
    (,(make-scode-combination (make-scode-variable 'foo)
                              (list (make-scode-variable 'bar))))
    (,(make-scode-conditional (make-scode-variable 'p)
                              (make-scode-variable 'c)
                              (make-scode-variable 'a)))
    (,(make-scode-definition 'foo (make-scode-variable 'bar)))
    (,(make-scode-delay (make-scode-variable 'foo)))
    (,(make-scode-disjunction (make-scode-variable 'a)
                              (make-scode-variable 'b)))
    (,(syntax '(lambda (x y #!optional z #!rest w)
                 (declare (no-type-checks))
                 (define (foo) x)
                 (define (bar) z)
                 (list (foo) (bar) x y z w))
              (->environment '())))
    (,(make-scode-quotation '(fnord #(blarf 1.23 #u8(87)))))
    (,(make-scode-sequence
       (list (make-scode-assignment 'foo 8)
             (make-scode-assignment 'bar 'baz))))
    (,(make-scode-the-environment))
    (,(make-scode-variable 'foo)))
  (lambda (object)
    (with-test-properties
        (lambda ()
          (call-with-temporary-file-pathname
            (lambda (pathname)
              (let ((format fasdump-format:amd64))
                (portable-fasdump object pathname format))
              (let ((object* (fasload pathname)))
                (if (not (equal-nan-scode? object object*))
                    (begin
                      (pp 'fail)
                      (pp object)
                      (pp object*)))
                (assert-equal-nan-scode (fasload pathname) object)))))
      'SEED object)))