;;;; tests for the DESCRIBE function

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; While most of SBCL is derived from the CMU CL system, the test
;;;; files (like this one) were written from scratch after the fork
;;;; from CMU CL.
;;;;
;;;; This software is in the public domain and is provided with
;;;; absolutely no warranty. See the COPYING and CREDITS files for
;;;; more information.

(load "assertoid.lisp")
(load "test-util.lisp")
(use-package "ASSERTOID")
(use-package "TEST-UTIL")

(defmacro assert-non-empty-output (&body forms)
  `(assert (plusp (length (with-output-to-string (*standard-output*)
                            ,@forms)))))

(defstruct to-be-described a b)
(defclass forward-describe-class (forward-describe-ref) (a))

(with-test (:name (describe :empty-gf))
  (assert-no-signal
   (assert-non-empty-output
    (describe (make-instance 'generic-function)))
   warning)
  (assert-signal
   (assert-non-empty-output
    (describe (make-instance 'standard-generic-function)))
   warning))

;;; DESCRIBE should run without signalling an error.
(with-test (:name (describe :no-error))
  (assert-non-empty-output (describe (make-to-be-described)))
  (assert-non-empty-output (describe 12))
  (assert-non-empty-output (describe "a string"))
  (assert-non-empty-output (describe 'symbolism))
  (assert-non-empty-output (describe (find-package :cl)))
  (assert-non-empty-output (describe '(a list)))
  (assert-non-empty-output (describe #(a vector))))

(let ((sb-ext:*evaluator-mode* :compile))
  (eval `(let (x) (defun closure-to-describe () (incf x)))))

(with-test (:name (describe :no-error :closure :bug-824974))
  (assert-non-empty-output (describe 'closure-to-describe)))

;;; DESCRIBE shouldn't fail on rank-0 arrays (bug reported and fixed
;;; by Lutz Euler sbcl-devel 2002-12-03)
(with-test (:name (describe :no-error array :rank 0))
  (assert-non-empty-output (describe #0a0))
  (assert-non-empty-output (describe #(1 2 3)))
  (assert-non-empty-output (describe #2a((1 2) (3 4)))))

;;; The DESCRIBE-OBJECT methods for built-in CL stuff should do
;;; FRESH-LINE and TERPRI neatly.
(with-test (:name (describe fresh-line terpri))
  (dolist (i (list (make-to-be-described :a 14) 12 "a string"
                   #0a0 #(1 2 3) #2a((1 2) (3 4)) 'sym :keyword
                   (find-package :keyword) (list 1 2 3)
                   nil (cons 1 2) (make-hash-table)
                   (let ((h (make-hash-table)))
                     (setf (gethash 10 h) 100
                           (gethash 11 h) 121)
                     h)
                   (make-condition 'simple-error)
                   (make-condition 'simple-error :format-control "fc")
                   #'car #'make-to-be-described (lambda (x) (+ x 11))
                   (constantly 'foo) #'(setf to-be-described-a)
                   #'describe-object (find-class 'to-be-described)
                   (find-class 'forward-describe-class)
                   (find-class 'forward-describe-ref) (find-class 'cons)))
    (let ((s (with-output-to-string (s)
               (write-char #\x s)
               (describe i s))))
      (macrolet ((check (form)
                   `(or ,form
                        (error "misbehavior in DESCRIBE of ~S:~%   ~S" i ',form))))
        (check (char= #\x (char s 0)))
        ;; one leading #\NEWLINE from FRESH-LINE or the like, no more
        (check (char= #\newline (char s 1)))
        (check (char/= #\newline (char s 2)))
        ;; one trailing #\NEWLINE from TERPRI or the like, no more
        (let ((n (length s)))
          (check (char= #\newline (char s (- n 1))))
          (check (char/= #\newline (char s (- n 2)))))))))

(with-test (:name (describe :argument-precedence-order))
  ;; Argument precedence order information is only interesting for two
  ;; or more required parameters.
  (assert (not (search "Argument precedence order"
                       (with-output-to-string (stream)
                         (describe #'class-name stream)))))
  (assert (search "Argument precedence order"
                  (with-output-to-string (stream)
                    (describe #'add-method stream)))))

(with-test (:name (describe sb-kernel:funcallable-instance))
  (assert (search "Slots with :INSTANCE allocation"
                  (with-output-to-string (stream)
                    (describe #'class-name stream)))))