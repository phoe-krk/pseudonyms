;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; PSEUDONYMS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; thanks to:
;;;; #lisp@freenode:
;;;; pjb, blubjr, sid_cypher, PuercoPop, shka, Bicyclidine
;;;; for testing and ideas
;;;; 
;;;; license: FreeBSD (BSD 2-clause)
;;;;
;;;; pseudonyms.lisp

(in-package :pseudonyms)

;;; ========================================================================
;;; GLOBAL VARIABLES

(defparameter *pseudonym-table*
  (make-weak-hash-table :test #'equal :weakness :key)
  "This is a global package-name-indexed hashtable holding package-name-and-pseudonym plists.")

;;; ========================================================================
;;; HELPER FUNCTIONS AND TYPES

(deftype string-designator () '(or string symbol character))

(defun string=-getf (plist indicator)
  "This is a version of getf utilizing string= for comparison. Given a plist and a key, returns
a value."
  (loop for key in plist by #'cddr
     for value in (rest plist) by #'cddr
     when (string= key indicator)
     return value))

(defun string=-getf-key (plist indicator)
  "This is a version of getf utilizing string= for comparison. Given a plist and a value,
returns a key."
  (loop for key in plist by #'cddr
     for value in (rest plist) by #'cddr
     when (string= value indicator)
     return (values key)))

;;; ========================================================================
;;; DEFINE/UNDEFINE FUNCTIONS

(defun defpseudonym (package pseudonym &key (inside-package (package-name *package*)))
  "This, given a package name and a pseudonym for it, allows you to use a local pseudonym in
form $pseudonym:symbol instead of name:symbol within your code. This pseudonym is local to the
package you called defpseudonym in (as shown by the global variable *PACKAGE*).

Arguments must be a pair of non-empty non-equal string designators, although I suggest using
a lowercase string for the second argument.
An optional third argument allows you to set a pseudonym for a different package.

This will signal an error whenever a nickname or pseudonym is already taken."
  (check-type package string-designator)
  (check-type pseudonym string-designator)
  (check-type inside-package string-designator)
  (assert (not (member "" (list package pseudonym inside-package) :test #'string=))
	  (package pseudonym inside-package)
	  "Arguments may not be empty strings.")
  (let* ((table (gethash inside-package *pseudonym-table*))
	 (pseudonym (string pseudonym))
	 (first (car table))
	 (package (string package))
	 (inside-package (string inside-package)))
    (assert (not (string=-getf-key table pseudonym))
	    (pseudonym)
	    "This package is already taken by pseudonym ~S."
	    (string=-getf table package))
    (assert (not (string=-getf table package))
	    (package)
	    "This pseudonym is already taken by package ~S."
	    (string=-getf-key table pseudonym))
    (if (null table)
	(setf (gethash inside-package *pseudonym-table*)
	      (cons package (cons pseudonym nil)))
	(setf (car table) package
	      (cdr table) (cons pseudonym (cons first (cdr table)))))
    (format nil "~A => ~A" pseudonym  package)))

(defun pmakunbound (datum &key (inside-package (package-name *package*)))
  "This, given either a pseudonym-bound package name or a package name-bound pseudonym, clears
any name-pseudonym pair bound to it.

Argument must be a string designator.
An optional second argument allows you to clear a pseudonym for a different package."
  (check-type datum string-designator)
  (let ((table (gethash inside-package *pseudonym-table*))
	(datum (string datum)))
    (setf (gethash inside-package *pseudonym-table*)
	  (loop for (key value) on table by #'cddr
	     unless (or (equal key datum) (equal value datum))
	     collect key and collect value)))
  datum)

;;; ========================================================================
;;; UTILITIES

(defun print-pseudonyms (&key (inside-package (package-name *package*)))
  "This prints all pseudonyms in a fancy manner.
Optional argument designates the package name, from inside which pseudonyms should be printed."
  (check-type inside-package string)
  (let* ((table (gethash inside-package *pseudonym-table*)))
    (if (null table)
	(format t "No pseudonyms defined for package ~:@(~A~).~%" inside-package)
	(progn
	  (format t "pseudonym => name (inside package ~:@(~A~)):~%" inside-package)
	  (list-length
	   (loop for (key value) on table by #'cddr collect key
	      do (format t "~S => ~S~%" value key)))))))

;;; ========================================================================
;;; READER MACRO

(defun pseudonym-reader (stream char)
  "This is the reader macro for local pseudonyms.

This function is not meant to be called explicitly, unless you know what you're doing."
  (declare (ignore char))
  (labels ((valid (char)
	     (when (equal char (or #\Space #\Tab #\Return #\Newline))
	       (error "Whitespace encountered when processing nickname."))))
    (let* ((table (gethash (package-name *package*) *pseudonym-table*))
	   (pseudlist (loop for char = (read-char stream)
			 collect char
			 do (when (valid char))
			 until (equal (peek-char nil stream) #\:)))
	   (pseudonym (concatenate 'string pseudlist))
	   (name (string=-getf-key table pseudonym))
	   (intern-p (eq 2 (list-length (loop for char = (peek-char nil stream)
					   while (equal char #\:)
					   do (read-char stream)
					   collect char))))
	   (symbol (read stream)))
      (assert (not (null name))
	      () "Pseudonym ~S was not set. Check your spelling or use defpseudonym."
	      pseudonym)
      (assert (or intern-p
		  (equal :external (nth-value 1 (find-symbol (string symbol) name))))
	      () "Symbol ~S is not found or not external in the ~A package."
	      (string symbol) (string name))
      (intern (string symbol) name))))

;;; ========================================================================
;;; NAMED READTABLE

(defreadtable :pseudonyms
  (:merge :modern)
  (:macro-char #\$ #'pseudonym-reader t))
(let* ((current-char #\$)
       (rt (find-readtable :pseudonyms)))
  (defun set-pseudonym-macro-character (char)
    "Sets the macro character for nickname resolution. By default, it is set to #\$."
    (check-type char character)
    (set-macro-character current-char nil t rt)
    (set-macro-character char #'pseudonym-reader t rt)))

(defun pseudonyms-on ()
  "Gimme some sugar, baby."
  (use-package :pseudonyms)
  (in-readtable :pseudonyms)
  'OH-YEAH)

;;;; EOF
