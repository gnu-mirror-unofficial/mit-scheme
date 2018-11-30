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

;;;; Test of arithmetic

(declare (usual-integrations))

(define (rsqrt x)
  (/ 1 (sqrt x)))

(define (assert-nan object)
  (assert-true (flo:flonum? object))
  (assert-true (flo:nan? object)))

(define (assert-inf- object)
  (assert-eqv object (flo:-inf.0)))

(define (assert-inf+ object)
  (assert-eqv object (flo:+inf.0)))

(define (not-integer? x)
  (not (integer? x)))

(define assert-integer
  (predicate-assertion integer? "integer"))

(define assert-not-integer
  (predicate-assertion not-integer? "not integer"))

(define assert-flonum
  (predicate-assertion flo:flonum? "flonum"))

(define assert-real
  (predicate-assertion real? "real number"))

(define (eqv-nan? x y)
  (if (and (flo:flonum? x) (flo:nan? x))
      (and (flo:flonum? y)
           (flo:nan? y)
           (eqv? (flo:safe-negative? x) (flo:safe-negative? y))
           (eqv? (flo:nan-quiet? x) (flo:nan-quiet? y))
           (eqv? (flo:nan-payload x) (flo:nan-payload y)))
      (and (not (and (flo:flonum? y) (flo:nan? y)))
           (eqv? x y))))

(define-comparator eqv-nan? 'eqv-nan?)

(define assert-eqv-nan
  (simple-binary-assertion eqv-nan? #f))

(define (with-expected-failure xfail body)
  (if (default-object? xfail)
      (body)
      (xfail body)))

(define (no-traps f)
  (if (flo:have-trap-enable/disable?)
      (flo:with-trapped-exceptions 0 f)
      (f)))

(define (define-enumerated-test prefix cases procedure)
  (for-each (lambda (arguments)
              (define-test (symbol prefix '/ arguments)
                (lambda ()
                  (apply procedure arguments))))
            cases))

(define (define-venumerated-test prefix elements procedure)
  (define-enumerated-test prefix (map list (vector->list elements)) procedure))

(define (define-venumerated^2-test* prefix elements procedure)
  (let ((n (vector-length elements)))
    (do ((i 0 (+ i 1))) ((>= i n))
      (do ((j 0 (+ j 1))) ((>= j n))
        (define-test
            (symbol prefix
                    '/ (vector-ref elements i)
                    '/ (vector-ref elements j))
          (lambda ()
            (procedure i (vector-ref elements i)
                       j (vector-ref elements j))))))))

(define (define-venumerated^2-test prefix elements procedure)
  (define-venumerated^2-test* prefix elements
    (lambda (i vi j vj)
      i j                               ;ignore
      (procedure vi vj))))

(define-venumerated^2-test 'ZEROS-ARE-EQUAL (vector -0. 0 +0.) =)

(define-venumerated^2-test* 'ORDER-WITH-INFINITIES
  (vector (flo:-inf.0) -2. -1 -0.5 0 +0.5 +1 +2. (flo:+inf.0))
  (lambda (i vi j vj)
    (if (< i j)
	(assert-true (< vi vj))
	(assert-false (< vi vj)))))

(let ((elements (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))))
  (define-venumerated-test '!NAN<X elements
    (lambda (v) (assert-false (< (flo:nan.0) v))))
  (define-venumerated-test '!X<NAN elements
    (lambda (v) (assert-false (< v (flo:nan.0))))))
(let ((elements (vector -2. -1 -0. 0 +0. +1 +2.)))

  (define-venumerated-test 'MIN-INF-/X elements
    (lambda (v) (assert-= (min (flo:-inf.0) v) (flo:-inf.0))))
  (define-venumerated-test 'MIN-INF+/X elements
    (lambda (v) (assert-= (min (flo:+inf.0) v) v)))
  (define-venumerated-test 'MIN-X/INF- elements
    (lambda (v) (assert-= (min v (flo:-inf.0)) (flo:-inf.0))))
  (define-venumerated-test 'MIN-X/INF+ elements
    (lambda (v) (assert-= (min v (flo:+inf.0)) v)))

  (define-venumerated-test 'MAX-INF-/X elements
    (lambda (v) (assert-= (max (flo:-inf.0) v) v)))
  (define-venumerated-test 'MAX-INF+/X elements
    (lambda (v) (assert-= (max (flo:+inf.0) v) (flo:+inf.0))))
  (define-venumerated-test 'MAX-X/INF- elements
    (lambda (v) (assert-= (max v (flo:-inf.0)) v)))
  (define-venumerated-test 'MAX-X/INF+ elements
    (lambda (v) (assert-= (max v (flo:+inf.0)) (flo:+inf.0)))))

(let ((elements (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))))
  (define-venumerated-test 'MIN-NAN/X elements
    (lambda (v) (assert-= (min (flo:nan.0) v) v)))
  (define-venumerated-test 'MIN-X/NAN elements
    (lambda (v) (assert-= (min v (flo:nan.0)) v)))
  (define-venumerated-test 'MAX-NAN/X elements
    (lambda (v) (assert-= (max (flo:nan.0) v) v)))
  (define-venumerated-test 'MAX-X/NAN elements
    (lambda (v) (assert-= (max v (flo:nan.0)) v))))

(define-venumerated-test 'NAN*X
  (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))
  (lambda (v) (assert-nan (* (flo:nan.0) v))))

(define-venumerated-test 'X*NAN
  (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))
  (lambda (v) (assert-nan (* v (flo:nan.0)))))

(define-venumerated-test 'NAN/X
  (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))
  (lambda (v) (assert-nan (/ (flo:nan.0) v))))

(define-venumerated-test 'X/NAN
  (vector (flo:-inf.0) -2. -1 -0. 0 +0. +1 +2. (flo:+inf.0))
  (lambda (v) (assert-nan (/ v (flo:nan.0)))))

(define-venumerated-test 'nan-order
  (vector 0 0. -0. 1 1. -1 -1. (flo:-inf.0) (flo:+inf.0) (flo:nan.0))
  (lambda (x)
    (let ((id identity-procedure))
      (assert-false ((id =) x (flo:nan.0)))
      (assert-false (= x (flo:nan.0)))
      (assert-false ((id <) x (flo:nan.0)))
      (assert-false (< x (flo:nan.0)))
      (assert-false ((id >=) x (flo:nan.0)))
      (assert-false (>= x (flo:nan.0)))
      (assert-false ((id >) x (flo:nan.0)))
      (assert-false (> x (flo:nan.0)))
      (assert-false ((id <=) x (flo:nan.0)))
      (assert-false (<= x (flo:nan.0)))
      (assert-false ((id =) (flo:nan.0) x))
      (assert-false (= (flo:nan.0) x))
      (assert-false ((id <) (flo:nan.0) x))
      (assert-false (< (flo:nan.0) x))
      (assert-false ((id >=) (flo:nan.0) x))
      (assert-false (>= (flo:nan.0) x))
      (assert-false ((id >) (flo:nan.0) x))
      (assert-false (> (flo:nan.0) x))
      (assert-false ((id <=) (flo:nan.0) x))
      (assert-false (<= (flo:nan.0) x)))))

(define-enumerated-test 'inf*0-exact
  (list (list 0 (flo:+inf.0))
        (list 0 (flo:-inf.0))
        (list (flo:+inf.0) 0)
        (list (flo:-inf.0) 0))
  (lambda (x y)
    (assert-nan (* x y))))

(define-enumerated-test 'polar0-real
  (list
   (list 0)
   (list 0.)
   (list -0.)
   (list 1)
   (list 1.)
   (list -1.)
   (list (flo:+inf.0))
   (list (flo:-inf.0)))
  (lambda (magnitude)
    (assert-real (make-polar magnitude 0))))

(define-test 'polar0-nan
  (lambda ()
    (assert-nan (make-polar (flo:nan.0) 0))))

(define-enumerated-test 'log1p-exact
  (list
   (list 0 0)
   (list 1 (log 2))
   (list (- (exp 1) 1) 1.)
   (list (expt 2 -53) (expt 2. -53))
   (list (- (expt 2 -53)) (- (expt 2. -53))))
  (lambda (x y)
    (assert-eqv (log1p x) y)))

(define-enumerated-test 'expm1-exact
  (list
   (list 0 0)
   (list (log 2) 1.)
   (list 1 (- (exp 1) 1))
   (list (expt 2 -53) (expt 2. -53))
   (list (- (expt 2 -53)) (- (expt 2. -53))))
  (lambda (x y)
    (assert-eqv (expm1 x) y)))

(define (relerr e a)
  (if (or (zero? e) (infinite? e))
      (if (eqv? a e) 0 1)
      (magnitude (/ (- e a) e))))

(define-enumerated-test 'expm1-approx
  (list
   (list -0.7 -0.5034146962085905)
   (list (- (log 2)) -0.5)
   (list -0.6 -0.45118836390597356)
   (list 0.6 .8221188003905089)
   (list (log 2) 1.)
   (list 0.7 1.0137527074704766))
  (lambda (x y)
    (assert-<= (relerr y (expm1 x)) 1e-15)))

(define-enumerated-test 'log1p-approx
  (list
   (list -0.3 -.35667494393873245)
   (list (- (sqrt 1/2) 1) -0.34657359027997264)
   (list -0.25 -.2876820724517809)
   (list 0.25 .22314355131420976)
   (list (- 1 (sqrt 1/2)) 0.25688251232181475)
   (list 0.3 .26236426446749106)
   (list -2 +3.141592653589793i))
  (lambda (x y #!optional xfail)
    (with-expected-failure xfail
      (lambda ()
        (assert-<= (relerr y (log1p x)) 1e-15)))))

(define-test 'log1p-inf
  (lambda ()
    (assert-inf- (log1p -1))
    (assert-inf- (log1p -1.))))

(define-enumerated-test 'log1mexp
  (list
   (list -1e-17 -39.1439465808987777)
   (list -0.69 -0.696304297144056727)
   (list (- (log 2)) (- (log 2)))
   (list -0.70 -0.686341002808385170)
   (list -708 -3.30755300363840783e-308))
  (lambda (x y)
    (assert-<= (relerr y (log1mexp x)) 1e-15)))

(define-enumerated-test 'log1pexp
  (list
   (list -1000 0.)
   (list -708 3.30755300363840783e-308)
   (list -38 3.13913279204802960e-17)
   (list -37 8.53304762574406580e-17)
   (list -36 2.31952283024356914e-16)
   (list 0 (log 2))
   (list 17 17.0000000413993746)
   (list 18 18.0000000152299791)
   (list 19 19.0000000056027964)
   (list 33 33.0000000000000071)
   (list 34 34.))
  (lambda (x y)
    (assert-<= (relerr y (log1pexp x)) 1e-15)))

(define-enumerated-test 'logsumexp-values
  (list
   (list (iota 1000) 999.45867514538713)
   (list '(999 1000) 1000.3132616875182)
   (list '(-1000 -1000) (+ -1000 (log 2)))
   (list '(0 0) (log 2)))
  (lambda (l s)
    (assert-<= (relerr s (logsumexp l)) 1e-15)))

(define-enumerated-test 'logsumexp-edges
  (list
   (list '() (flo:-inf.0))
   (list '(-1000) -1000)
   (list '(-1000.) -1000.)
   (list (list (flo:-inf.0)) (flo:-inf.0))
   (list (list (flo:-inf.0) 1) 1.)
   (list (list 1 (flo:-inf.0)) 1.)
   (list (list (flo:+inf.0)) (flo:+inf.0))
   (list (list (flo:+inf.0) 1) (flo:+inf.0))
   (list (list 1 (flo:+inf.0)) (flo:+inf.0))
   (list (list (flo:-inf.0) (flo:-inf.0)) (flo:-inf.0))
   (list (list (flo:+inf.0) (flo:+inf.0)) (flo:+inf.0)))
  (lambda (l s)
    (assert-eqv (logsumexp l) s)))

(define-enumerated-test 'logsumexp-nan
  (list
   (list (list (flo:-inf.0) (flo:+inf.0)))
   (list (list (flo:+inf.0) (flo:-inf.0)))
   (list (list 1 (flo:-inf.0) (flo:+inf.0)))
   (list (list (flo:-inf.0) (flo:+inf.0) 1))
   (list (list (flo:nan.0)))
   (list (list (flo:+inf.0) (flo:nan.0)))
   (list (list (flo:-inf.0) (flo:nan.0)))
   (list (list 1 (flo:nan.0)))
   (list (list (flo:nan.0) (flo:+inf.0)))
   (list (list (flo:nan.0) (flo:-inf.0)))
   (list (list (flo:nan.0) 1)))
  (lambda (l)
    (assert-nan (flo:with-trapped-exceptions 0 (lambda () (logsumexp l))))))

(define (designify0 x)
  (if (zero? x)
      (abs x)
      x))

(define-enumerated-test 'logit-logistic
  (list
   (list -36.7368005696771
           1.1102230246251565e-16
           (log 1.1102230246251565e-16))
   (list -1.0000001 0.2689414017088022 (log .2689414017088022))
   (list -0.9999999 0.26894144103118883 (log .26894144103118883))
   (list -1 0.2689414213699951 (log 0.2689414213699951))
   (list -4.000000000537333e-5 .49999 (log .49999))
   (list -4.000000108916879e-9 .499999999 (log .499999999))
   (list 0 1/2 (log 1/2))
   (list 3.999999886872274e-9 .500000001 (log .500000001))
   (list 8.000042667076279e-3 .502 (log .502))
   (list +0.9999999 0.7310585589688111 (log 0.7310585589688111))
   (list +1 0.7310585786300049 (log 0.7310585786300049))
   (list +1.0000001 0.7310585982911977 (log 0.7310585982911977))
   ;; Would like to do +/-710 but we get inexact result traps.
   (list +708 1 -3.307553003638408e-308)
   (list -708 3.307553003638408e-308 -708)
   (list +1000 1. -0.)
   (list -1000 0. -1000.))
  (lambda (x p t)
    (assert-<= (relerr p (logistic x)) 1e-15)
    (if (and (not (= p 0))
             (not (= p 1)))
        (assert-<= (relerr x (logit p)) 1e-15))
    (if (< p 1)
        (begin
          (assert-<= (relerr (- 1 p) (logistic (- x))) 1e-15)
          (if (<= 1/2 p)
              ;; In this case, 1 - p is evaluated exactly.
              (assert-<= (relerr (- x) (logit (- 1 p))) 1e-15)))
        (assert-<= (logistic (- x)) 1e-300))
    (assert-<= (relerr t (log-logistic x)) 1e-15)
    (if (<= x 709)
        (assert-<= (relerr (exact->inexact x) (designify0 (logit-exp t)))
                   1e-15))
    (if (< p 1)
        (assert-<= (relerr (log1p (- p)) (log-logistic (- x))) 1e-15))))

(define-enumerated-test 'logit-logistic-1/2
  (list
   (list 1e-300 4e-300)
   (list 1e-16 4e-16)
   (list .2310585786300049 1.)
   (list .49999999999999994 37.42994775023705)
   (list .5 38)
   (list .5 38)
   (list .5 709)
   (list .5 1000)
   (list .5 1e300))
  (lambda (p x)
    (if (< p .5)
        (begin
          (assert-<= (relerr x (logit1/2+ p)) 1e-15)
          (assert-= (- (logit1/2+ p)) (logit1/2+ (- p)))))
    (assert-<= (relerr p (logistic-1/2 x)) 1e-15)
    (assert-= (- (logistic-1/2 x)) (logistic-1/2 (- x)))))

(define-enumerated-test 'expt-exact
  (list
   (list 2. -1075 "0.")
   (list 2. -1074 "4.9406564584124654e-324")
   (list 2. -1024 "5.562684646268004e-309")
   (list 2. -1023 "1.1125369292536007e-308")
   (list 2. -1022 "2.2250738585072014e-308"))
  (lambda (x y x^y)
    (flo:with-trapped-exceptions 0
      (lambda ()
        (let ((x^y (string->number x^y)))
          (assert-eqv (expt x y) x^y)
          ;; For all the inputs, reciprocal is exact.
          (assert-eqv (expt (/ 1 x) (- y)) x^y)
          (assert-eqv (expt (* 2 x) (/ y 2)) x^y)
          (assert-eqv (expt (/ 1 (* 2 x)) (- (/ y 2))) x^y))))))

(define-enumerated-test 'atan2
  (list
   (list +0. -1. +3.1415926535897932)
   (list -0. -1. -3.1415926535897932)
   (list +0. -0. +3.1415926535897932)
   (list -0. -0. -3.1415926535897932)
   (list +0. +0. +0.)
   (list -0. +0. -0.)
   (list +0. +1. +0.)
   (list -0. +1. -0.)
   (list -1. -0. -1.5707963267948966)
   (list -1. +0. -1.5707963267948966)
   (list +1. -0. +1.5707963267948966)
   (list +1. +0. +1.5707963267948966)
   (list -1. (flo:-inf.0) -3.1415926535897932)
   (list +1. (flo:-inf.0) +3.1415926535897932)
   (list -1. (flo:+inf.0) -0.)
   (list +1. (flo:+inf.0) +0.)
   (list (flo:-inf.0) -1. -1.5707963267948966)
   (list (flo:+inf.0) -1. +1.5707963267948966)
   (list (flo:-inf.0) (flo:-inf.0) -2.356194490192345)
   (list (flo:+inf.0) (flo:-inf.0) +2.356194490192345)
   (list (flo:-inf.0) (flo:+inf.0) -.7853981633974483)
   (list (flo:+inf.0) (flo:+inf.0) +.7853981633974483))
  (lambda (y x theta)
    (if (zero? theta)
        (assert-eqv (atan y x) theta)
        (assert-<= (relerr theta (atan y x)) 1e-15))))

(define-enumerated-test 'negate-zero
  (list
   (list 0. -0.)
   (list -0. 0.))
  (lambda (x y)
    (assert-eqv (- x) y)
    (assert-eqv (- 0 (flo:copysign 1. x)) (flo:copysign 1. y))))

(define-enumerated-test 'integer?
  (list
   (list 0)
   (list 1)
   (list (* 1/2 (identity-procedure 2)))
   (list 0.)
   (list 1.)
   (list 1.+0.i))
  assert-integer)

(define-enumerated-test 'not-integer?
  (list
   (list 1/2)
   (list 0.1)
   (list 1+2i)
   (list (flo:nan.0))
   (list (flo:+inf.0))
   (list (flo:-inf.0)))
  assert-not-integer)

(define pi 3.1415926535897932)
(define pi/2 (/ pi 2))

(define-test 'asin-0
  (lambda ()
    (assert-eqv (asin 0) 0)
    (assert-eqv (asin (identity-procedure 0)) 0)
    (assert-eqv (asin 0.) 0.)
    (assert-eqv (asin (identity-procedure 0.)) 0.)
    (assert-eqv (asin -0.) -0.)
    (assert-eqv (asin (identity-procedure -0.)) -0.)))

(define-enumerated-test 'asin
  (list
   (list (/ (- (sqrt 6) (sqrt 2)) 4) (/ pi 12))
   (list (/ (sqrt (- 2 (sqrt 2))) 2) (/ pi 8))
   (list 1/2 (/ pi 6))
   (list (rsqrt 2) (/ pi 4))
   (list (/ (sqrt 3) 2) (/ pi 3))
   (list (/ (sqrt (+ 2 (sqrt 2))) 2) (* pi 3/8))
   (list (/ (+ (sqrt 6) (sqrt 2)) 4) (* pi 5/12))
   (list 1 (/ pi 2))
   (list 1+i .6662394324925153+1.0612750619050357i)
   (list -1+i -.6662394324925153+1.0612750619050357i)
   (list -1-i -.6662394324925153-1.0612750619050357i)
   (list 1-i .6662394324925153-1.0612750619050357i)
   (list 2 1.5707963267948966+1.3169578969248166i expect-failure)
   (list 2.+0.i 1.5707963267948966+1.3169578969248166i)
   (list 2.-0.i 1.5707963267948966-1.3169578969248166i)
   (list -2 -1.5707963267948966+1.3169578969248166i)
   (list -2.+0.i -1.5707963267948966+1.3169578969248166i)
   (list -2.-0.i -1.5707963267948966-1.3169578969248166i)
   (list 1e150 1.5707963267948966+346.0809111296668i expect-failure)
   (list 1e150+0.i 1.5707963267948966+346.0809111296668i expect-failure)
   (list 1e150-0.i 1.5707963267948966-346.0809111296668i)
   (list -1e150 -1.5707963267948966+346.0809111296668i)
   (list -1e150+0.i -1.5707963267948966+346.0809111296668i)
   (list -1e150-0.i -1.5707963267948966-346.0809111296668i expect-failure)
   (list 1e300 1.5707963267948966+691.4686750787736i expect-failure)
   (list 1e300+0.i 1.5707963267948966+691.4686750787736i expect-failure)
   (list 1e300-0.i 1.5707963267948966-691.4686750787736i)
   (list -1e300 -1.5707963267948966+691.4686750787736i)
   (list -1e300+0.i -1.5707963267948966+691.4686750787736i)
   (list -1e300-0.i -1.5707963267948966-691.4686750787736i expect-failure))
  (lambda (x t #!optional xfail)
    (with-expected-failure xfail
      (lambda ()
        (assert-<= (relerr t (asin x)) 1e-14)))))

(define-test 'acos-1
  (lambda ()
    (assert-eqv (acos 1) 0)
    (assert-eqv (acos (identity-procedure 1)) 0)
    (assert-eqv (acos 1.) 0.)
    (assert-eqv (acos (identity-procedure 1.)) 0.)))

(define-enumerated-test 'acos
  (list
   (list (/ (+ (sqrt 6) (sqrt 2)) 4) (/ pi 12))
   (list (/ (sqrt (+ 2 (sqrt 2))) 2) (/ pi 8))
   (list (/ (sqrt 3) 2) (/ pi 6))
   (list (rsqrt 2) (/ pi 4))
   (list 1/2 (/ pi 3))
   (list (/ (sqrt (- 2 (sqrt 2))) 2) (* pi 3/8))
   (list (/ (- (sqrt 6) (sqrt 2)) 4) (* pi 5/12))
   (list 0 (/ pi 2))
   (list 1+i .9045568943023813-1.0612750619050357i)
   (list -1+i 2.2370357592874117-1.0612750619050357i)
   (list -1-i 2.2370357592874117+1.0612750619050355i)
   (list 1-i .9045568943023814+1.0612750619050355i)
   (list 2 (* +i (log (- 2 (sqrt 3)))) expect-failure)
   (list 2.+0.i (* +i (log (- 2 (sqrt 3)))))
   (list 2.-0.i (* -i (log (- 2 (sqrt 3)))))
   (list -2 (+ pi (* +i (log (- 2 (sqrt 3))))))
   (list -2.+0.i (+ pi (* +i (log (- 2 (sqrt 3))))))
   (list -2.-0.i (+ pi (* -i (log (- 2 (sqrt 3))))))
   ;; -i log(z + sqrt(z^2 - 1))
   ;; \approx -i log(z + sqrt(z^2))
   ;; = -i log(z + z)
   ;; = -i log(2 z)
   (list 1e150 (* +i (log (* 2 1e150))) expect-failure)
   (list 1e150+0.i (* +i (log (* 2 1e150))) expect-failure)
   (list 1e150-0.i (* -i (log (* 2 1e150))) expect-failure)
   (list -1e150 (+ pi (* +i (log (* 2 1e150)))) expect-failure)
   (list -1e150+0.i (+ pi (* +i (log (* 2 1e150)))) expect-failure)
   (list -1e150-0.i (+ pi (* -i (log (* 2 1e150)))) expect-failure)
   (list 1e300 (* +i (log (* 2 1e300))) expect-failure)
   (list 1e300+0.i (* +i (log (* 2 1e300))) expect-failure)
   (list 1e300-0.i (* -i (log (* 2 1e300))) expect-failure)
   (list -1e300 (+ pi (* +i (log (* 2 1e300)))) expect-failure)
   (list -1e300+0.i (+ pi (* +i (log (* 2 1e300)))) expect-failure)
   (list -1e300-0.i (+ pi (* -i (log (* 2 1e300)))) expect-failure))
  (lambda (x t #!optional xfail)
    (with-expected-failure xfail
      (lambda ()
        (assert-<= (relerr t (acos x)) 1e-14)))))

(define-test 'atan-0
  (lambda ()
    (assert-eqv (atan 0) 0)
    (assert-eqv (atan (identity-procedure 0)) 0)
    (assert-eqv (atan 0.) 0.)
    (assert-eqv (atan (identity-procedure 0.)) 0.)
    (assert-eqv (atan -0.) -0.)
    (assert-eqv (atan (identity-procedure -0.)) -0.)))

(define-enumerated-test 'atan
  (list
   (list (- 2 (sqrt 3)) (/ 3.1415926535897932 12))
   (list (- (sqrt 2) 1) (/ 3.1415926535897932 8))
   (list (rsqrt 3) (/ 3.1415926535897932 6))
   (list 1 (/ 3.1415926535897932 4))
   (list (sqrt 3) (/ 3.1415926535897932 3))
   (list (+ (sqrt 2) 1) (* 3.1415926535897932 3/8))
   (list (+ 2 (sqrt 3)) (* 3.1415926535897932 5/12))
   (list 1+i 1.0172219678978514+.4023594781085251i)
   (list -1+i -1.0172219678978514+.4023594781085251i)
   (list -1-i -1.0172219678978514-.4023594781085251i)
   (list 1-i 1.0172219678978514-.4023594781085251i)
   (list +2i +1.5707963267948966+.5493061443340549i)
   (list +0.+2i +1.5707963267948966+.5493061443340549i)
   (list -0.+2i -1.5707963267948966+.5493061443340549i)
   (list -2i +1.5707963267948966-.5493061443340549i)
   (list +0.-2i +1.5707963267948966-.5493061443340549i)
   (list -0.-2i -1.5707963267948966-.5493061443340549i))
  (lambda (x t #!optional xfail)
    (with-expected-failure xfail
      (lambda ()
        (assert-<= (relerr t (atan x)) 1e-15)))))

(define-enumerated-test 'infinite-magnitude
  (list
   (list +inf.0)
   (list -inf.0)
   (list +inf.0+i)
   (list +inf.0-i)
   (list -inf.0-i)
   (list -inf.0+i)
   (list 1+inf.0i)
   (list 1-inf.0i)
   (list -1-inf.0i)
   (list -1+inf.0i)
   (list +inf.0+inf.0i)
   (list +inf.0-inf.0i)
   (list -inf.0-inf.0i)
   (list -inf.0+inf.0i))
  (lambda (z)
    (assert-inf+ (magnitude z))))

(define-enumerated-test 'infinite-angle
  (list
   (list +inf.0 0.)   ;XXX Why not exact, if imag-part is exact 0?
   (list -inf.0 pi)
   (list +inf.0+i 0.)
   (list +inf.0-i -0.)
   (list -inf.0-i (- pi))
   (list -inf.0+i pi)
   (list 1+inf.0i (* pi 1/2))
   (list 1-inf.0i (* pi -1/2))
   (list -1-inf.0i (* pi -1/2))
   (list -1+inf.0i (* pi 1/2))
   (list +inf.0+inf.0i (* pi 1/4))
   (list +inf.0-inf.0i (* pi -1/4))
   (list -inf.0-inf.0i (* pi -3/4))
   (list -inf.0+inf.0i (* pi 3/4)))
  (lambda (z t)
    (assert-<= (relerr t (angle z)) 1e-15)))

(define-enumerated-test 'sqrt-exact
  `((0 0)
    (0. 0.)
    (1 1)
    (1. 1.)
    ;; Square root of perfect square should be exact.
    (4 2)
    (4. 2.)
    ;; Square root of perfect square x times 2i should be exactly x+xi.
    (+2i 1+1i ,expect-failure)
    (+8i 2+2i ,expect-failure)
    (+18i 3+3i ,expect-failure)
    (+32i 4+4i ,expect-failure)
    (+2.i 1.+1.i ,expect-failure)
    (+8.i 2.+2.i ,expect-failure)
    (+18.i 3.+3.i ,expect-failure)
    (+32.i 4.+4.i ,expect-failure)
    ;; Likewise, sqrt of perfect square x times -2i should be x-xi.
    (-2i 1-1i ,expect-failure)
    (-8i 2-2i ,expect-failure)
    (-18i 3-3i ,expect-failure)
    (-32i 4-4i ,expect-failure)
    (-2.i 1.-1.i ,expect-failure)
    (-8.i 2.-2.i ,expect-failure)
    (-18.i 3.-3.i ,expect-failure)
    (-32.i 4.-4.i ,expect-failure)
    ;; Handle signed zero carefully.
    (+0.i 0.+0.i)
    (-0.i 0.-0.i ,expect-failure)
    (-0.+0.i +0.+0.i)
    (-0.-0.i +0.-0.i ,expect-failure)
    ;; Treat infinities carefully around branch cuts.
    (-inf.0 +inf.0i)
    (+inf.0 +inf.0)
    (-inf.0+1.i +inf.0i ,expect-failure)
    (+inf.0+1.i +inf.0 ,expect-failure)
    (-inf.0-1.i +inf.0i ,expect-failure)
    (+inf.0-1.i +inf.0 ,expect-failure)
    (-inf.0i -inf.0+inf.0i ,expect-failure)
    (+inf.0i +inf.0+inf.0i)
    (1.-inf.0i -inf.0+inf.0i ,expect-failure)
    (1.+inf.0i +inf.0+inf.0i)
    (-1.-inf.0i -inf.0+inf.0i ,expect-failure)
    (-1.+inf.0i +inf.0+inf.0i)
    ;; NaN should be preserved.
    (,(flo:qnan 1234) ,(flo:qnan 1234)))
  (lambda (z r #!optional xfail)
    (with-expected-failure xfail
      (lambda ()
        (assert-eqv-nan (no-traps (lambda () (sqrt z))) r)))))