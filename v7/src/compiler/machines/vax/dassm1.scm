#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/vax/dassm1.scm,v 4.3 1989/05/24 05:09:32 jinx Exp $
$MC68020-Header: dassm1.scm,v 4.10 88/12/30 07:05:04 GMT cph Exp $

Copyright (c) 1987, 1989 Massachusetts Institute of Technology

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

;;;; VAX Disassembler: User level

(declare (usual-integrations))

;;; Flags that control disassembler behavior

(define disassembler/symbolize-output? true)
(define disassembler/compiled-code-heuristics? true)
(define disassembler/write-offsets? true)
(define disassembler/write-addresses? false)

;;;; Top level entries

(define (compiler:write-lap-file filename #!optional symbol-table?)
  (let ((pathname (->pathname filename)))
    (with-output-to-file (pathname-new-type pathname "lap")
      (lambda ()
	(let ((object (fasload (pathname-new-type pathname "com")))
	      (info (let ((pathname (pathname-new-type pathname "binf")))
		      (and (if (default-object? symbol-table?)
			       (file-exists? pathname)
			       symbol-table?)
			   (fasload pathname)))))
	  (cond ((compiled-code-address? object)
		 (disassembler/write-compiled-code-block
		  (compiled-code-address->block object)
		  info
		  false))
		((not (scode/comment? object))
		 (error "compiler:write-lap-file : Not a compiled file"
			(pathname-new-type pathname "com")))
		(else
		 (scode/comment-components
		  object
		  (lambda (text expression)
		    expression ;; ignored
		    (if (dbg-info-vector? text)
			(let ((items (dbg-info-vector/items text)))
			  (for-each disassembler/write-compiled-code-block
				    (vector->list items)
				    (if (false? info)
					(make-list (vector-length items) false)
					(vector->list info))))
			(error "compiler:write-lap-file : Not a compiled file"
			       (pathname-new-type pathname "com"))))))))))))

(define disassembler/base-address)

(define (compiler:disassemble entry)
  (let ((block (compiled-entry/block entry)))
    (let ((info (compiled-code-block/dbg-info block)))
      (fluid-let ((disassembler/write-offsets? true)
		  (disassembler/write-addresses? true)
		  (disassembler/base-address (object-datum block)))
	(newline)
	(newline)
	(disassembler/write-compiled-code-block block info)))))

;;; Operations exported from the disassembler package

(define disassembler/instructions)
(define disassembler/instructions/null?)
(define disassembler/instructions/read)
(define disassembler/lookup-symbol)
(define disassembler/read-variable-cache)
(define disassembler/read-procedure-cache)
(define compiled-code-block/objects-per-procedure-cache)
(define compiled-code-block/objects-per-variable-cache)

(define (write-block block)
  (write-string "#[COMPILED-CODE-BLOCK ")
  (write-string
   (number->string (object-hash block) '(HEUR (RADIX D S))))
  (write-string " ")
  (write-string
   (number->string (object-datum block) '(HEUR (RADIX X E))))
  (write-string "]"))

(define (disassembler/write-compiled-code-block block info #!optional page?)
  (let ((symbol-table (and info (dbg-info/labels info))))
    (if (or (default-object? page?) page?)
	(begin
	  (write-char #\page)
	  (newline)))
    (write-string "Disassembly of ")
    (write-block block)
    (write-string ":\n")
    (write-string "Code:\n\n")
    (disassembler/write-instruction-stream
     symbol-table
     (disassembler/instructions/compiled-code-block block symbol-table))
    (write-string "\nConstants:\n\n")
    (disassembler/write-constants-block block symbol-table)
    (newline)))

(define (disassembler/instructions/compiled-code-block block symbol-table)
  (disassembler/instructions block
			     (compiled-code-block/code-start block)
			     (compiled-code-block/code-end block)
			     symbol-table))

(define (disassembler/instructions/address start-address end-address)
  (disassembler/instructions false start-address end-address false))

(define (disassembler/write-instruction-stream symbol-table instruction-stream)
  (fluid-let ((*unparser-radix* 16))
    (disassembler/for-each-instruction instruction-stream
      (lambda (offset instruction)
	(disassembler/write-instruction
	 symbol-table
	 offset
	 (lambda ()
	   (let ((string
		  (with-output-to-string
		    (lambda ()
		      (display instruction)))))
	     (string-downcase! string)
	     (write-string string))))))))

(define (disassembler/for-each-instruction instruction-stream procedure)
  (let loop ((instruction-stream instruction-stream))
    (if (not (disassembler/instructions/null? instruction-stream))
	(disassembler/instructions/read instruction-stream
	  (lambda (offset instruction instruction-stream)
	    (procedure offset instruction)
	    (loop (instruction-stream)))))))

(define (disassembler/write-constants-block block symbol-table)
  (fluid-let ((*unparser-radix* 16))
    (let ((end (system-vector-length block)))
      (let loop ((index (compiled-code-block/constants-start block)))
	(cond ((not (< index end)) 'DONE)
	      ((object-type?
		(let-syntax ((ucode-type
			      (macro (name) (microcode-type name))))
		  (ucode-type linkage-section))
		(system-vector-ref block index))
	       (loop (disassembler/write-linkage-section block
							 symbol-table
							 index)))
	      (else
	       (disassembler/write-instruction
		symbol-table
		(compiled-code-block/index->offset index)
		(lambda ()
		  (write-constant block
				  symbol-table
				  (system-vector-ref block index))))
	       (loop (1+ index))))))))

(define (write-constant block symbol-table constant)
  (write-string (cdr (write-to-string constant 60)))
  (cond ((lambda? constant)
	 (let ((expression (lambda-body constant)))
	   (if (and (compiled-code-address? expression)
		    (eq? (compiled-code-address->block expression) block))
	       (begin
		 (write-string "  (")
		 (let ((offset (compiled-code-address->offset expression)))
		   (let ((label
			  (disassembler/lookup-symbol symbol-table offset)))
		     (if label
			 (write-string (string-downcase label))
			 (write offset))))
		 (write-string ")")))))
	((compiled-code-address? constant)
	 (write-string "  (offset ")
	 (write (compiled-code-address->offset constant))
	 (write-string " in ")
	 (write-block (compiled-code-address->block constant))
	 (write-string ")"))
	(else false)))

(define (disassembler/write-linkage-section block symbol-table index)
  (define (write-caches index size how-many writer)
    (let loop ((index index) (how-many how-many))
      (if (zero? how-many)
	  'DONE
	  (begin
	    (disassembler/write-instruction
	     symbol-table
	     (compiled-code-block/index->offset index)
	     (lambda ()
	       (writer block index)))
	    (loop (+ size index) (-1+ how-many))))))

  (let* ((field (object-datum (system-vector-ref block index)))
	 (descriptor (integer-divide field #x10000)))
    (let ((kind (integer-divide-quotient descriptor))
	  (length (integer-divide-remainder descriptor)))
      (disassembler/write-instruction
       symbol-table
       (compiled-code-block/index->offset index)
       (lambda ()
	 (write-string "#[LINKAGE-SECTION ")
	 (write field)
	 (write-string "]")))
       (case kind
	 ((0)
	  (write-caches
	   (1+ index)
	   compiled-code-block/objects-per-procedure-cache
	   (quotient length compiled-code-block/objects-per-procedure-cache)
	   disassembler/write-procedure-cache))
	 ((1)
	  (write-caches
	   (1+ index)
	   compiled-code-block/objects-per-variable-cache
	   (quotient length compiled-code-block/objects-per-variable-cache)
	   (lambda (block index)
	     (disassembler/write-variable-cache "Reference" block index))))
	 ((2)
	  (write-caches
	   (1+ index)
	   compiled-code-block/objects-per-variable-cache
	   (quotient length compiled-code-block/objects-per-variable-cache)
	   (lambda (block index)
	     (disassembler/write-variable-cache "Assignment" block index))))
	 (else
	  (error "disassembler/write-linkage-section: Unknown section kind"
		 kind)))
      (1+ (+ index length)))))

(define-integrable (variable-cache-name cache)
  ((ucode-primitive primitive-object-ref 2) cache 1))

(define (disassembler/write-variable-cache kind block index)
  (write-string kind)
  (write-string " cache to ")
  (write (variable-cache-name (disassembler/read-variable-cache block index))))

(define (disassembler/write-procedure-cache block index)
  (let ((result (disassembler/read-procedure-cache block index)))
    (write (vector-ref result 2))
    (write-string " argument procedure cache to ")
    (case (vector-ref result 0)
      ((COMPILED INTERPRETED)
       (write (vector-ref result 1)))
      ((VARIABLE)
       (write-string "variable ")
       (write (vector-ref result 1)))
      (else
       (error "disassembler/write-procedure-cache: Unknown cache kind"
	      (vector-ref result 0))))))

(define (disassembler/write-instruction symbol-table offset write-instruction)
  (if symbol-table
      (let ((label (dbg-labels/find-offset symbol-table offset)))
	(if label
	    (begin
	      (write-char #\Tab)
	      (write-string (string-downcase (dbg-label/name label)))
	      (write-char #\:)
	      (newline)))))

  (if disassembler/write-addresses?
      (begin
	(write-string
	 (number->string (+ offset disassembler/base-address)
			 '(HEUR (RADIX X S))))
	(write-char #\Tab)))
  
  (if disassembler/write-offsets?
      (begin
	(write-string (number->string offset '(HEUR (RADIX X S))))
	(write-char #\Tab)))

  (if symbol-table
      (write-string "    "))
  (write-instruction)
  (newline))