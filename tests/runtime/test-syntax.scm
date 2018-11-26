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

;;;; Test of macro expander

(declare (usual-integrations))

(define test-environment
  (the-environment))

(define-test 'local-define-syntax/syntax
  (lambda ()
    (assert-error
     (lambda ()
       (assert-equal
        (unsyntax
         (syntax '(let ()
                    (define-syntax test
                      (syntax-rules () ((test) (lambda (y) y))))
                    (list ((test) 1) ((test) 2)))
                 test-environment))
        '(let () (list (let ((y 1)) y) (let ((y 2)) y))))))))

(define-test 'local-define-syntax/eval
  (lambda ()
    (assert-error
     (lambda ()
       (assert-equal
        (eval '(let ()
                 (define-syntax test
                   (syntax-rules () ((test) (lambda (y) y))))
                 (list ((test) 1) ((test) 2)))
              test-environment)
        '(1 2))))))

(define-test 'bug55090
  (lambda ()
    (expect-failure
     (lambda ()
       (assert-equal
        (unsyntax
         (cadddr
          (scode-open-block-actions
           (scode-sequence-actions
            (syntax '(begin
                       (define-syntax vector-edit-code
                         (syntax-rules ()
                           ((_ v r o s)
                            (let ((index (vector-length v)))
                              (subvector-move-left! v o index r (+ o s))
                              r))
                           ((_ v r o s i e)
                            (let ((index i))
                              (subvector-move-left! v o index r (+ o s))
                              (vector-set! r (+ s index) e)
                              (let ((skew (1+ s)))
                                (vector-edit-code v r index skew))))))
                       (let ((input (vector 0 1 3)))
                         (let ((array (make-vector 4)))
                           (vector-edit-code input array 0 0 2 2))))
                    test-environment)))))
        '(let ((input (vector 0 1 3)))
           (let ((array (make-vector 4)))
             (let ((index 2))
               (subvector-move-left! input 0 index array (+ 0 0))
               (vector-set! array (+ 0 index) 2)
               (let ((skew (1+ 0)))
                 (let ((.index.1-0 (vector-length input)))
                   (subvector-move-left! input index .index.1-0
                                         array (+ index skew))
                   array))))))))))