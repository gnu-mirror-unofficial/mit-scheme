#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/bobcat/rules1.scm,v 1.1.1.1 1987/07/01 20:59:41 jinx Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. |#

;;;; LAP Generation Rules: Data Transfers

(declare (usual-integrations))

;;;; Transfers to Registers

;;; All assignments to pseudo registers are required to delete the
;;; dead registers BEFORE performing the assignment.  This is because
;;; the register being assigned may be PSEUDO-REGISTER=? to one of the
;;; dead registers, and thus would be flushed if the deletions
;;; happened after the assignment.

(define-rule statement
  (ASSIGN (REGISTER 12) (REGISTER 15))
  (enable-frame-pointer-offset! 0)
  (LAP))

(define-rule statement
  (ASSIGN (REGISTER 15) (OFFSET-ADDRESS (REGISTER 15) (? n)))
  (decrement-frame-pointer-offset! n (increment-anl 7 n)))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (OFFSET-ADDRESS (REGISTER 15) (? n)))
  (QUALIFIER (pseudo-register? target))
  (LAP
   (LEA (@AO 7 ,(* 4 n))
	,(reference-assignment-alias! target 'ADDRESS))))

(define-rule statement
  (ASSIGN (REGISTER 15) (REGISTER (? source)))
  (disable-frame-pointer-offset!
   (LAP (MOVE/SIMPLE L ,(coerce->any source) (A 7)))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (CONSTANT (? source)))
  (QUALIFIER (pseudo-register? target))
  (LAP ,(load-constant source (coerce->any target))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (VARIABLE-CACHE (? name)))
  (QUALIFIER (pseudo-register? target))
  (LAP (MOVE/SIMPLE L
		    (@PCR ,(free-reference-label name))
		    ,(reference-assignment-alias! target 'DATA))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (REGISTER (? source)))
  (QUALIFIER (pseudo-register? target))
  (move-to-alias-register! source 'DATA target)
  (LAP))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (OBJECT->ADDRESS (REGISTER (? source))))
  (QUALIFIER (pseudo-register? target))
  (let ((target (move-to-alias-register! source 'DATA target)))
    (LAP (AND L ,mask-reference ,target))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (OBJECT->TYPE (REGISTER (? source))))
  (QUALIFIER (pseudo-register? target))
  (let ((target (move-to-alias-register! source 'DATA target)))
    (LAP (RO L L (& 8) ,target))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (OFFSET (REGISTER (? address)) (? offset)))
  (QUALIFIER (pseudo-register? target))
  (let ((source (indirect-reference! address offset)))
    (delete-dead-registers!)
    ;; The fact that the target register here is a data register is a
    ;; heuristic that works reasonably well since if the value is a
    ;; pointer, we will probably want to dereference it, which
    ;; requires that we first mask it.
    (LAP (MOVE/SIMPLE L
		      ,source
		      ,(register-reference
			(allocate-alias-register! target 'DATA))))))

(define-rule statement
  (ASSIGN (REGISTER (? target)) (POST-INCREMENT (REGISTER 15) 1))
  (QUALIFIER (pseudo-register? target))
  (record-pop!)
  (delete-dead-registers!)
  (LAP (MOVE/SIMPLE L
		    (@A+ 7)
		    ,(register-reference
		      (allocate-alias-register! target 'DATA)))))

(define-rule statement
  (ASSIGN (REGISTER (? target))
	  (CONS-POINTER (CONSTANT (? type)) (REGISTER (? datum))))
  (QUALIFIER (pseudo-register? target))
  (let ((target* (coerce->any target))
	(datum (coerce->any datum)))
    (delete-dead-registers!)
    (if (register-effective-address? target*)
	(LAP (MOVE/SIMPLE L ,datum ,reg:temp)
	     (MOVE/SIMPLE B (& ,type) ,reg:temp)
	     (MOVE/SIMPLE L ,reg:temp ,target*))
	(LAP (MOVE/SIMPLE L ,datum ,target*)
	     (MOVE/SIMPLE B (& ,type) ,target*)))))

;;;; Transfers to Memory

(define-rule statement
  (ASSIGN (OFFSET (REGISTER (? a)) (? n))
	  (CONSTANT (? object)))
  (LAP ,(load-constant object (indirect-reference! a n))))

(define-rule statement
  (ASSIGN (OFFSET (REGISTER (? a)) (? n))
	  (REGISTER (? r)))
  (LAP (MOVE/SIMPLE L
		    ,(coerce->any r)
		    ,(indirect-reference! a n))))

(define-rule statement
  (ASSIGN (OFFSET (REGISTER (? a)) (? n))
	  (POST-INCREMENT (REGISTER 15) 1))
  (record-pop!)
  (LAP (MOVE/SIMPLE L
		    (@A+ 7)
		    ,(indirect-reference! a n))))

(define-rule statement
  (ASSIGN (OFFSET (REGISTER (? a)) (? n))
	  (CONS-POINTER (CONSTANT (? type)) (REGISTER (? r))))
  (let ((target (indirect-reference! a n)))
    (LAP (MOVE/SIMPLE L ,(coerce->any r) ,target)
	 (MOVE/SIMPLE B (& ,type) ,target))))

(define-rule statement
  (ASSIGN (OFFSET (REGISTER (? a0)) (? n0))
	  (OFFSET (REGISTER (? a1)) (? n1)))
  (let ((source (indirect-reference! a1 n1)))
    (LAP (MOVE/SIMPLE L
		      ,source
		      ,(indirect-reference! a0 n0)))))

;;;; Consing

(define-rule statement
  (ASSIGN (POST-INCREMENT (REGISTER 13) 1) (CONSTANT (? object)))
  (LAP ,(load-constant object (INST-EA (@A+ 5)))))

(define-rule statement
  (ASSIGN (POST-INCREMENT (REGISTER 13) 1) (UNASSIGNED))
  (LAP ,(load-non-pointer type-code:unassigned 0 (INST-EA (@A+ 5)))))

(define-rule statement
  (ASSIGN (POST-INCREMENT (REGISTER 13) 1) (REGISTER (? r)))
  (LAP (MOVE/SIMPLE L ,(coerce->any r) (@A+ 5))))

(define-rule statement
  (ASSIGN (POST-INCREMENT (REGISTER 13) 1) (OFFSET (REGISTER (? r)) (? n)))
  (LAP (MOVE/SIMPLE L ,(indirect-reference! r n) (@A+ 5))))

(define-rule statement
  (ASSIGN (POST-INCREMENT (REGISTER 13) 1) (ENTRY:PROCEDURE (? label)))
  (let ((temporary
	 (register-reference (allocate-temporary-register! 'ADDRESS))))
    (LAP (LEA (@PCR ,(procedure-external-label (label->procedure label)))
	      ,temporary)
	 (MOVE/SIMPLE L ,temporary (@A+ 5))
	 (MOVE/SIMPLE B (& ,type-code:return-address) (@AO 5 -4)))))

;;;; Pushes

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1) (CONSTANT (? object)))
  (record-push!
   (LAP ,(load-constant object (INST-EA (@-A 7))))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1) (UNASSIGNED))
  (record-push!
   (LAP ,(load-non-pointer type-code:unassigned 0 (INST-EA (@-A 7))))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1) (REGISTER (? r)))
  (record-push!
   (if (= r regnum:frame-pointer)
       (LAP (PEA ,(offset-reference regnum:stack-pointer
				    (frame-pointer-offset)))
	    (MOVE/SIMPLE B (& ,type-code:stack-environment) (@A 7)))
       (LAP (MOVE/SIMPLE L ,(coerce->any r) (@-A 7))))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1)
	  (CONS-POINTER (CONSTANT (? type)) (REGISTER (? r))))
  (record-push!
   (LAP (MOVE/SIMPLE L ,(coerce->any r) (@-A 7))
	(MOVE/SIMPLE B (& ,type) (@A 7)))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1) (OFFSET (REGISTER (? r)) (? n)))
  (record-push!
   (LAP (MOVE/SIMPLE L ,(indirect-reference! r n) (@-A 7)))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1)
	  (OFFSET-ADDRESS (REGISTER 12) (? n)))
  (record-push!
   (LAP (PEA ,(offset-reference regnum:stack-pointer
				(+ n (frame-pointer-offset))))
	(MOVE/SIMPLE B (& ,type-code:stack-environment) (@A 7)))))

(define-rule statement
  (ASSIGN (PRE-INCREMENT (REGISTER 15) -1) (ENTRY:CONTINUATION (? label)))
  (record-continuation-frame-pointer-offset! label)
  (record-push!
   (LAP (PEA (@PCR ,label))
	(MOVE/SIMPLE B (& ,type-code:return-address) (@A 7)))))
