(in-package #:lodds-qt)
(in-readtable :qtools)

(defmacro qdoto (instance &rest forms)
  (let ((inst (gensym "instance")))
    `(let ((,inst ,instance))
       ,@(loop :for (fn . arguments) :in forms
               :collect `(,fn ,(car arguments) ,inst ,@ (cdr arguments)))
       ,inst)))

(defun generate-timestamp (&optional unix-timestamp)
  "Returns current date formatted as a string. if unix-timestamp is
  given it formats that
  CL-USER> (generate-timestamp)
  => \"2017-02-28 13:02:24\"
  CL-USER> generate-timestamp (lodds.core:get-timestamp))
  => \"2017-02-28 13:02:59\""
  (multiple-value-bind (sec min hr day mon yr dow dst-p tz)
      (if unix-timestamp
          (decode-universal-time
           (+ lodds.core::*unix-epoch-difference*
              unix-timestamp))
          (get-decoded-time))
    (declare (ignore dow dst-p tz))
    (format nil "~4,'0d-~2,'0d-~2,'0d ~2,'0d:~2,'0d:~2,'0d"
            yr mon day hr min sec) ))

;; iterates over all children (QTreeWidgetItem) of a given parent
;; (QTreeWidgetItem) and binds the current child index to index and
;; the current child to child.
(defmacro do-childs ((child index parent) &body body)
  `(loop :for ,index :from 0 :below (q+:child-count ,parent)
         :do (let ((,child (q+:child ,parent ,index)))
               ,@body)))
