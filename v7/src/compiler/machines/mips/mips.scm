#| -*-Scheme-*-

$Id: mips.scm,v 1.3 2001/12/20 21:45:25 cph Exp $

Copyright (c) 1987, 1989, 1990, 1999, 2001 Massachusetts Institute of Technology

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
02111-1307, USA.
|#

;;;; MIPS instruction set

(declare (usual-integrations))

(let-syntax
    ((opcodes (lambda (suffix names)
       (let loop ((value 0)
		  (names names)
		  (result '()))
	 (cond ((null? names) `(BEGIN ,@result))
	       ((null? (car names)) (loop (+ value 1) (cdr names) result))
	       (else
		(loop (+ value 1) (cdr names)
		      (cons 
		       `(define-integrable
			  ,(string->symbol
			    (string-append (symbol->string (car names)) suffix))
			  ,value)
		       result))))))))
  ; OP CODES
  (opcodes "-op"
    (special bcond j    jal   beq  bne blez bgtz	; 0  - 7
     addi    addiu slti sltiu andi ori xori lui		; 8  - 15
     cop0    cop1  cop2 cop3  ()   ()  ()   ()		; 16 - 23
     ()      ()    ()   ()    ()   ()  ()   ()		; 24 - 31
     lb      lh    lwl  lw    lbu  lhu lwr  ()		; 32 - 39
     sb      sh    swl  sw    ()   ()  swr  ()		; 40 - 47
     lwc0    lwc1  lwc2 lwc3  ()   ()  ()   ()		; 48 - 55
     swc0    swc1  swc2 swc3  ()   ()  ()   ()))	; 56 - 63

  ; Special Function Codes
  (opcodes "-funct"
    (sll  ()    srl  sra  sllv    ()    srlv srav	; 0  - 7
     jr   jalr  ()   ()   syscall break ()   ()		; 8  - 15
     mfhi mthi  mflo mtlo ()      ()    ()   ()		; 16 - 23
     mult multu div  divu ()      ()    ()   ()		; 24 - 31
     add  addu  sub  subu and     or    xor  nor	; 32 - 39
     ()   ()    slt  sltu ()      ()    ()   ()		; 40 - 47
     ()   ()    ()   ()   ()      ()    ()   ()		; 48 - 55
     ()   ()    ()   ()   ()      ()    ()   ()))	; 56 - 63

  ; Condition codes for BCOND
  (opcodes "-cond"
    (bltz   bgez  () () () () () ()			; 0  - 7
     ()     ()    () () () () () ()			; 8  - 15
     bltzal bgezal  () () () () () ()			; 16 - 23
     ()     ()    () () () () () ()))			; 24 - 31

  ; Floating point function codes for use with COP1 instruction
  (opcodes "f-op"
    (add   sub    mul   div   ()    abs   mov   neg	; 0  - 7
     ()    ()     ()    ()    ()    ()    ()    ()	; 8  - 15
     ()    ()     ()    ()    ()    ()    ()    ()	; 16 - 23
     ()    ()     ()    ()    ()    ()    ()    ()	; 24 - 31
     cvt.s cvt.d  ()    ()    cvt.w ()    ()    ()	; 32 - 39
     ()    ()     ()    ()    ()    ()    ()    ()	; 40 - 47
     c.f   c.un   c.eq  c.ueq c.olt c.ult c.ole c.ule	; 48 - 55
     c.sf  c.ngle c.seq c.ngl c.lt  c.nge c.le  c.ngt)) ; 56 - 63
) ; let-syntax

; Operations on co-processors (for BCzFD, BCzT, CFCz, COPz, CTCz,
;                                  MFCz, and MTCz instructions)
; This is confusing ... according to the diagrams, these occupy bits
; 16 through 25, inclusive (10 bits).  But the tables indicate that
; only bits 16, and 21 through 25 matter.  In fact, bit 25 is always 0
; since that denotes a COPz instruction; hence COPz has 32 encodings
; and all the others have two encodings.

(define-integrable mf-cp-op #x000)
(define-integrable mt-cp-op #x080)
(define-integrable bcf-cp-op #x100)
(define-integrable bct-cp-op #x101)
(define-integrable cf-cp-op #x040)
(define-integrable ct-cp-op #x0C0)

(define-integrable mf-cp-op-alternate #x001)
(define-integrable mt-cp-op-alternate #x081)
(define-integrable bcf-cp-op-alternate #x180)
(define-integrable bct-cp-op-alternate #x181)
(define-integrable cf-cp-op-alternate #x041)
(define-integrable ct-cp-op-alternate #x0C1)

; Operations on co-processor 0
(define-integrable cop0-op:tlbr 1)
(define-integrable cop0-op:tlbwi 2)
(define-integrable cop0-op:tlbwr 6)
(define-integrable cop0-op:tlbp 8)
(define-integrable cop0-op:rfe 16)

; Floating point formats
(define-integrable single-precision-float 0)
(define-integrable double-precision-float 1)
