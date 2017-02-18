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

;;;; Unicode strings
;;; package: (runtime ustring)

;;; This implementation supports all R7RS and some MIT/GNU string operations in
;;; which all the names have "string" replaced by "ustring".  This is a
;;; transitional implementation to convert MIT/GNU Scheme to full Unicode string
;;; support.
;;;
;;; For simplicity, the implementation uses the UTF-32 encoding for non-8-bit
;;; strings.  This is not a good long-term approach and should be revisited once
;;; the runtime system has been converted to this string abstraction.
;;;
;;; At some point in the future we'll eliminate legacy string support and rename
;;; everything to "string".

(declare (usual-integrations))

;;;; Code-point vectors

(define-integrable (cp->byte-index index)
  (fix:* index 3))

(define-integrable (byte->cp-index index)
  (fix:quotient index 3))

(define-integrable (make-cp b0 b1 b2)
  (fix:+ b0
	 (fix:+ (fix:lsh b1 8)
		(fix:lsh b2 16))))

(define-integrable (cp-byte-0 cp) (fix:and cp #xFF))
(define-integrable (cp-byte-1 cp) (fix:and (fix:lsh cp -8) #xFF))
(define-integrable (cp-byte-2 cp) (fix:and (fix:lsh cp -16) #x1F))

(define (make-cp-vector length)
  (make-bytevector (cp->byte-index length)))

(define (cp-vector-length bytes)
  (byte->cp-index (bytevector-length bytes)))

(define (cp-vector-ref bytes index)
  (let ((i (cp->byte-index index)))
    (make-cp (bytevector-u8-ref bytes i)
	     (bytevector-u8-ref bytes (fix:+ i 1))
	     (bytevector-u8-ref bytes (fix:+ i 2)))))

(define (cp-vector-set! bytes index cp)
  (let ((i (cp->byte-index index)))
    (bytevector-u8-set! bytes i (cp-byte-0 cp))
    (bytevector-u8-set! bytes (fix:+ i 1) (cp-byte-1 cp))
    (bytevector-u8-set! bytes (fix:+ i 2) (cp-byte-2 cp))))

(define-integrable (cp-vector-copy! to at from start end)
  (bytevector-copy! to (cp->byte-index at)
		    from (cp->byte-index start) (cp->byte-index end)))

(define (cp-vector-fill! bytes start end cp)
  (do ((i start (fix:+ i 1)))
      ((not (fix:< i end)))
    (cp-vector-set! bytes i cp)))

;;;; Component types

(define-primitives
  (legacy-string? string? 1)
  (legacy-string-allocate string-allocate 1)
  (legacy-string-length string-length 1)
  (legacy-string-ref string-ref 2)
  (legacy-string-set! string-set! 3))

(define (full-string? object)
  (and (%record? object)
       (fix:= 2 (%record-length object))
       (eq? %full-string-tag (%record-ref object 0))))

(define-integrable (full-string-allocate k)
  (%record %full-string-tag (make-cp-vector k)))

(define %full-string-tag
  '|#[(runtime ustring)full-string]|)

(define (%full-string-cp-vector string)
  (%record-ref string 1))

(define (make-full-string k #!optional char)
  (let ((string (full-string-allocate k)))
    (if (not (default-object? char))
	(ustring-fill! string char))
    string))

(define-integrable (full-string-length string)
  (cp-vector-length (%full-string-cp-vector string)))

(define-integrable (%full-string-ref string index)
  (integer->char (cp-vector-ref (%full-string-cp-vector string) index)))

(define-integrable (%full-string-set! string index char)
  (cp-vector-set! (%full-string-cp-vector string) index (char->integer char)))

(define (register-ustring-predicates!)
  (register-predicate! ustring? 'ustring)
  (register-predicate! legacy-string? 'legacy-string '<= ustring?)
  (register-predicate! full-string? 'full-string '<= ustring?)
  (register-predicate! ->ustring-component? '->ustring-component))

;;;; Strings

(define (ustring? object)
  (or (legacy-string? object)
      (full-string? object)))

(define (make-ustring k #!optional char)
  (guarantee index-fixnum? k 'make-ustring)
  (if (fix:> k 0)
      (make-full-string k char)
      (legacy-string-allocate 0)))

(define (ustring-length string)
  (cond ((legacy-string? string) (legacy-string-length string))
	((full-string? string) (full-string-length string))
	(else (error:not-a ustring? string 'ustring-length))))

(define (ustring-ref string index)
  (guarantee index-fixnum? index 'ustring-ref)
  (cond ((legacy-string? string)
	 (legacy-string-ref string index))
	((full-string? string)
	 (if (not (fix:< index (full-string-length string)))
	     (error:bad-range-argument index 'ustring-ref))
	 (%full-string-ref string index))
	(else
	 (error:not-a ustring? string 'ustring-ref))))

(define (ustring-set! string index char)
  (guarantee index-fixnum? index 'ustring-set!)
  (guarantee bitless-char? char 'ustring-set!)
  (cond ((legacy-string? string)
	 (legacy-string-set! string index char))
	((full-string? string)
	 (if (not (fix:< index (full-string-length string)))
	     (error:bad-range-argument index 'ustring-set!))
	 (%full-string-set! string index char))
	(else
	 (error:not-a ustring? string 'ustring-set!))))

(define (ustring-copy! to at from #!optional start end)
  (let* ((end (fix:end-index end (ustring-length from) 'ustring-copy!))
	 (start (fix:start-index start end 'ustring-copy!)))
    (guarantee index-fixnum? at 'ustring-copy!)
    (if (not (fix:<= (fix:+ at (fix:- end start)) (ustring-length to)))
	(error:bad-range-argument to 'ustring-copy!))
    (if (legacy-string? to)
	(if (legacy-string? from)
	    (copy-loop legacy-string-set! to at
		       legacy-string-ref from start end)
	    (copy-loop legacy-string-set! to at
		       %full-string-ref from start end))
	(if (legacy-string? from)
	    (copy-loop %full-string-set! to at
		       legacy-string-ref from start end)
	    (%full-string-copy! to at from start end)))))

(define-integrable (%full-string-copy! to at from start end)
  (cp-vector-copy! (%full-string-cp-vector to) at
		   (%full-string-cp-vector from) start end))

(define (ustring-copy string #!optional start end)
  (let* ((end (fix:end-index end (ustring-length string) 'ustring-copy))
	 (start (fix:start-index start end 'ustring-copy)))
    (cond ((legacy-string? string)
	   (let ((to (legacy-string-allocate (fix:- end start))))
	     (copy-loop legacy-string-set! to 0
			legacy-string-ref string start end)
	     to))
	  ((%full-string-8-bit? string start end)
	   (let ((to (legacy-string-allocate (fix:- end start))))
	     (copy-loop legacy-string-set! to 0
			%full-string-ref string start end)
	     to))
	  (else
	   (let ((to (full-string-allocate (fix:- end start))))
	     (%full-string-copy! to 0 string start end)
	     to)))))

(define (ustring-head string end)
  (ustring-copy string 0 end))

(define (ustring-tail string start)
  (ustring-copy string start))

(define (%ustring=? string1 string2)
  (and (fix:= (ustring-length string1) (ustring-length string2))
       (ustring-every char=? string1 string2)))

(define (%ustring-ci=? string1 string2)
  (and (fix:= (ustring-length string1) (ustring-length string2))
       (ustring-every char-ci=? string1 string2)))

;; Non-Unicode implementation, acceptable to R7RS.
(define-integrable (%string-comparison-maker c= c<)
  (lambda (string1 string2)
    (let ((end1 (ustring-length string1))
	  (end2 (ustring-length string2)))
      (let ((end (fix:min end1 end2)))
	(let loop ((i 0))
	  (if (fix:< i end)
	      (let ((c1 (ustring-ref string1 i))
		    (c2 (ustring-ref string2 i)))
		(if (c= c1 c2)
		    (loop (fix:+ i 1))
		    (c< c1 c2)))
	      (fix:< end1 end2)))))))

(define %ustring<? (%string-comparison-maker char=? char<?))
(define %ustring<=? (%string-comparison-maker char=? char<=?))
(define %ustring>? (%string-comparison-maker char=? char>?))
(define %ustring>=? (%string-comparison-maker char=? char>=?))

(define %ustring-ci<? (%string-comparison-maker char-ci=? char-ci<?))
(define %ustring-ci<=? (%string-comparison-maker char-ci=? char-ci<=?))
(define %ustring-ci>? (%string-comparison-maker char-ci=? char-ci>?))
(define %ustring-ci>=? (%string-comparison-maker char-ci=? char-ci>=?))

(define-integrable (string-comparison-maker %compare)
  (lambda (string1 string2 . strings)
    (let loop ((string1 string1) (string2 string2) (strings strings))
      (if (pair? strings)
	  (and (%compare string1 string2)
	       (loop string2 (car strings) (cdr strings)))
	  (%compare string1 string2)))))

(define ustring=? (string-comparison-maker %ustring=?))
(define ustring<? (string-comparison-maker %ustring<?))
(define ustring<=? (string-comparison-maker %ustring<=?))
(define ustring>? (string-comparison-maker %ustring>?))
(define ustring>=? (string-comparison-maker %ustring>=?))

(define ustring-ci=? (string-comparison-maker %ustring-ci=?))
(define ustring-ci<? (string-comparison-maker %ustring-ci<?))
(define ustring-ci<=? (string-comparison-maker %ustring-ci<=?))
(define ustring-ci>? (string-comparison-maker %ustring-ci>?))
(define ustring-ci>=? (string-comparison-maker %ustring-ci>=?))

(define-integrable (prefix-maker c= caller)
  (lambda (prefix string #!optional start end)
    (let* ((end (fix:end-index end (ustring-length string) caller))
	   (start (fix:start-index start end caller))
	   (n (ustring-length prefix)))
      (and (fix:<= n (fix:- end start))
	   (let loop ((i 0) (j start))
	     (if (fix:< i n)
		 (and (c= (ustring-ref prefix i) (ustring-ref string j))
		      (loop (fix:+ i 1) (fix:+ j 1)))
		 #t))))))

(define-integrable (suffix-maker c= caller)
  (lambda (suffix string #!optional start end)
    (let* ((end (fix:end-index end (ustring-length string) caller))
	   (start (fix:start-index start end caller))
	   (n (ustring-length suffix)))
      (and (fix:<= n (fix:- end start))
	   (let loop ((i 0) (j (fix:- end n)))
	     (if (fix:< i n)
		 (and (c= (ustring-ref suffix i) (ustring-ref string j))
		      (loop (fix:+ i 1) (fix:+ j 1)))
		 #t))))))

(define ustring-prefix? (prefix-maker eq? 'ustring-prefix?))
(define ustring-suffix? (suffix-maker eq? 'ustring-suffix?))

(define ustring-prefix-ci? (prefix-maker char-ci=? 'ustring-prefix-ci?))
(define ustring-suffix-ci? (suffix-maker char-ci=? 'ustring-suffix-ci?))

(define (ustring-downcase string)
  (case-transform char-downcase-full string))

(define (ustring-foldcase string)
  (case-transform char-foldcase-full string))

(define (ustring-upcase string)
  (case-transform char-upcase-full string))

(define (case-transform transform string)
  (let ((chars (append-map transform (ustring->list string))))
    (let ((n (length chars)))
      (let ((result
	     (if (every char-8-bit? chars)
		 (legacy-string-allocate n)
		 (full-string-allocate n))))
	(do ((chars chars (cdr chars))
	     (i 0 (fix:+ i 1)))
	    ((not (pair? chars)))
	  (ustring-set! result i (car chars)))
	result))))

(define (list->ustring chars)
  (if (every char-8-bit? chars)
      (let ((string (legacy-string-allocate (length chars))))
	(do ((chars chars (cdr chars))
	     (i 0 (fix:+ i 1)))
	    ((not (pair? chars)))
	  (legacy-string-set! string i (car chars)))
	string)
      (let ((string (full-string-allocate (length chars))))
	(do ((chars chars (cdr chars))
	     (i 0 (fix:+ i 1)))
	    ((not (pair? chars)))
	  (%full-string-set! string i (car chars)))
	string)))

(define (ustring->list string #!optional start end)
  (let* ((end (fix:end-index end (ustring-length string) 'ustring->list))
	 (start (fix:start-index start end 'ustring->list)))
    (if (legacy-string? string)
	(do ((i (fix:- end 1) (fix:- i 1))
	     (chars '() (cons (legacy-string-ref string i) chars)))
	    ((not (fix:>= i start)) chars))
	(do ((i (fix:- end 1) (fix:- i 1))
	     (chars '() (cons (%full-string-ref string i) chars)))
	    ((not (fix:>= i start)) chars)))))

(define (ustring->vector string #!optional start end)
  (let* ((end (fix:end-index end (ustring-length string) 'ustring->vector))
	 (start (fix:start-index start end 'ustring->vector)))
    (if (legacy-string? string)
	(let ((to (make-vector (fix:- end start))))
	  (copy-loop vector-set! to 0
		     legacy-string-ref string start end)
	  to)
	(let ((to (make-vector (fix:- end start))))
	  (copy-loop vector-set! to 0
		     %full-string-ref string start end)
	  to))))

(define (ustring-append . strings)
  (%ustring-append* strings))

(define (ustring-append* strings)
  (guarantee list? strings 'ustring-append*)
  (%ustring-append* strings))

(define (%ustring-append* strings)
  (let ((string
	 (do ((strings strings (cdr strings))
	      (n 0 (fix:+ n (ustring-length (car strings))))
	      (8-bit? #t (and 8-bit? (ustring-8-bit? (car strings)))))
	     ((not (pair? strings))
	      (if 8-bit?
		  (legacy-string-allocate n)
		  (full-string-allocate n))))))
    (let loop ((strings strings) (i 0))
      (if (pair? strings)
	  (let ((n (ustring-length (car strings))))
	    (ustring-copy! string i (car strings) 0 n)
	    (loop (cdr strings) (fix:+ i n)))))
    string))

(define (ustring . objects)
  (%ustring* objects 'ustring))

(define (ustring* objects)
  (guarantee list? objects 'ustring*)
  (%ustring* objects 'ustring*))

(define (%ustring* objects caller)
  (%ustring-append*
   (map (lambda (object)
	  (->ustring object caller))
	objects)))

(define (->ustring object caller)
  (cond ((not object) "")
	((bitless-char? object) (make-ustring 1 object))
	((ustring? object) object)
	((symbol? object) (symbol->string object))
	((pathname? object) (->namestring object))
	((number? object) (number->string object))
	((uri? object) (uri->string object))
	(else (error:not-a ->ustring-component? object caller))))

(define (->ustring-component? object)
  (cond (not object)
	(bitless-char? object)
	(ustring? object)
	(symbol? object)
	(pathname? object)
	(number? object)
	(uri? object)))

(define (mapper-values proc string strings)
  (cond ((null? strings)
	 (values (ustring-length string)
		 (lambda (i)
		   (proc (ustring-ref string i)))))
	((null? (cdr strings))
	 (let* ((string2 (car strings))
		(n (fix:min (ustring-length string)
			    (ustring-length string2))))
	   (values n
		   (lambda (i)
		     (proc (ustring-ref string i)
			   (ustring-ref string2 i))))))
	(else
	 (let ((n (min-length ustring-length string strings)))
	   (values n
		   (lambda (i)
		     (apply proc
			    (ustring-ref string i)
			    (map (lambda (string)
				   (ustring-ref string i))
				 strings))))))))

(define (min-length string-length string strings)
  (do ((strings strings (cdr strings))
       (n (string-length string)
	  (fix:min n (string-length (car strings)))))
      ((null? strings) n)))

(define (ustring-for-each proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (do ((i 0 (fix:+ i 1)))
	((not (fix:< i n)))
      (proc i))))

(define (ustring-map proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let ((result (full-string-allocate n)))
      (do ((i 0 (fix:+ i 1)))
	  ((not (fix:< i n)))
	(%full-string-set! result i (proc i)))
      result)))

(define (ustring-count proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let loop ((i 0) (count 0))
      (if (fix:< i n)
	  (loop (fix:+ i 1)
		(if (proc i)
		    (fix:+ count 1)
		    count))
	  count))))

(define (ustring-any proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let loop ((i 0))
      (and (fix:< i n)
	   (if (proc i)
	       #t
	       (loop (fix:+ i 1)))))))

(define (ustring-every proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let loop ((i 0))
      (if (fix:< i n)
	  (and (proc i)
	       (loop (fix:+ i 1)))
	  #t))))

(define (ustring-find-first-index proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let loop ((i 0))
      (and (fix:< i n)
	   (if (proc i)
	       i
	       (loop (fix:+ i 1)))))))

(define (ustring-find-last-index proc string . strings)
  (receive (n proc) (mapper-values proc string strings)
    (let loop ((i (fix:- n 1)))
      (and (fix:>= i 0)
	   (if (proc i)
	       i
	       (loop (fix:- i 1)))))))

(define (ustring-find-first-char string char #!optional start end)
  (let* ((caller 'ustring-find-first-char)
	 (end (fix:end-index end (ustring-length string) caller))
	 (start (fix:start-index start end caller)))
    (let ((index
	   (ustring-find-first-index (char=-predicate char)
				     (ustring-copy string start end))))
      (and index
	   (fix:+ start index)))))

(define (ustring-find-last-char string char #!optional start end)
  (let* ((caller 'ustring-find-last-char)
	 (end (fix:end-index end (ustring-length string) caller))
	 (start (fix:start-index start end caller)))
    (let ((index
	   (ustring-find-last-index (char=-predicate char)
				    (ustring-copy string start end))))
      (and index
	   (fix:+ start index)))))

(define (ustring-find-first-char-in-set string char-set #!optional start end)
  (let* ((caller 'ustring-find-first-char-in-set)
	 (end (fix:end-index end (ustring-length string) caller))
	 (start (fix:start-index start end caller)))
    (let ((index
	   (ustring-find-first-index (char-set-predicate char-set)
				     (ustring-copy string start end))))
      (and index
	   (fix:+ start index)))))

(define (ustring-find-last-char-in-set string char-set #!optional start end)
  (let* ((caller 'ustring-find-last-char-in-set)
	 (end (fix:end-index end (ustring-length string) caller))
	 (start (fix:start-index start end caller)))
    (let ((index
	   (ustring-find-last-index (char-set-predicate char-set)
				    (ustring-copy string start end))))
      (and index
	   (fix:+ start index)))))

(define (ustring-fill! string char #!optional start end)
  (guarantee bitless-char? char 'ustring-fill!)
  (let* ((end (fix:end-index end (ustring-length string) 'ustring-fill!))
	 (start (fix:start-index start end 'ustring-fill!)))
    (if (legacy-string? string)
	(do ((index start (fix:+ index 1)))
	    ((not (fix:< index end)) unspecific)
	  (legacy-string-set! string index char))
	(let ((bytes (%full-string-cp-vector string))
	      (cp (char->integer char)))
	  (do ((i start (fix:+ i 1)))
	      ((not (fix:< i end)))
	    (cp-vector-set! bytes i cp))))))

(define (ustring-hash string #!optional modulus)
  (let ((string* (string-for-primitive string)))
    (if (default-object? modulus)
	((ucode-primitive string-hash) string*)
	((ucode-primitive string-hash-mod) string* modulus))))

(define (ustring->legacy-string string)
  (cond ((legacy-string? string) string)
	((full-string? string)
	 (let ((end (full-string-length string)))
	   (and (%full-string-8-bit? string 0 end)
		(let ((to (legacy-string-allocate end)))
		  (copy-loop legacy-string-set! to 0
			     %full-string-ref string 0 end)
		  to))))
	(else (error:not-a ustring? string 'ustring->legacy-string))))

(define (ustring-8-bit? string)
  (cond ((legacy-string? string) #t)
	((full-string? string)
	 (%full-string-8-bit? string 0 (full-string-length string)))
	(else (error:not-a ustring? string 'ustring-8-bit?))))

(define (%full-string-8-bit? string start end)
  (every-loop char-8-bit? %full-string-ref string start end))

(define (string-for-primitive string)
  (cond ((legacy-string? string)
	 (let ((end (legacy-string-length string)))
	   (if (every-loop char-ascii? legacy-string-ref string 0 end)
	       string
	       (string->utf8 string))))
	((full-string? string)
	 (let ((end (full-string-length string)))
	   (if (every-loop char-ascii? %full-string-ref string 0 end)
	       (let ((to (legacy-string-allocate end)))
		 (copy-loop legacy-string-set! to 0
			    %full-string-ref string 0 end)
		 to)
	       (string->utf8 string))))
	(else
	 (error:not-a ustring? string 'ustring-ascii?))))

(define (legacy-string-downcase string)
  (let ((end (legacy-string-length string)))
    (let ((string* (legacy-string-allocate end)))
      (do ((i 0 (fix:+ i 1)))
	  ((fix:= i end))
	(legacy-string-set! string* i
			    (char-downcase (legacy-string-ref string i))))
      string*)))

(define-integrable (copy-loop to-set! to at from-ref from start end)
  (do ((i start (fix:+ i 1))
       (j at (fix:+ j 1)))
      ((not (fix:< i end)))
    (to-set! to j (from-ref from i))))

(define-integrable (every-loop proc ref string start end)
  (let loop ((i start))
    (if (fix:< i end)
	(and (proc (ref string i))
	     (loop (fix:+ i 1)))
	#t)))