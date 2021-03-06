#|

Contains Shares widget related stuff, The Shares widget is the
QTreeWidget in the middle, which displays all shared files

|#

(in-package #:lodds-qt)
(in-readtable :qtools)

;; shares columns
(defvar +shares-name+ 0)
(defvar +shares-size+ 1)
(defvar +shares-path+ 2)

(define-widget shares (QTreeWidget)
  ((main-window :initarg :main-window
                :initform nil)
   (changes :accessor changes
            :initform (list)
            :type list
            :documentation "contains new changes which need to be
            added to the widget. This slot is used to transfer changes
            from other threads over to the main thread. The method
            ADD-CHANGE will add changes and then signal UPDATE-ENTRIES
            which will then update the widget inside the main
            thread. To safetly retrieve a change use GET-CHANGE.")
   (root :accessor root
         :initform nil
         :type shares-entry-dir
         :documentation "Root shares-entry-dir which has
         InvisibleRootItem widget attached. Will be set on init, see
         define-initializer setup-widget for shares")
   (changes-lock :accessor changes-lock
                 :initform (bt:make-lock)
                 :documentation "Lock to not nconc/pop two changes at
                 the same time. Lock is used by ADD-CHANGE and
                 GET-CHANGE.")
   (entries :accessor entries
            :initform (make-hash-table :test 'equal)
            :type hashtable
            :documentation "hash-table mapping generated widget path's
            to Information. Each element in shares has a hidden path
            column. If a item gets klicked you can get Information
            like the file owner or the filesize by looking up the path
            inside entries. Entries contains SHARES-ENTRY-DIR
            SHARES-ENTRY-FILE")))

(defmethod add-change ((shares shares) changes name)
  (bt:with-lock-held ((changes-lock shares))
    (if (null (changes shares))
        (setf (changes shares) (list changes))
        (nconc (changes shares) (list changes))))
  (signal! shares (update-entries string) name))

(defmethod get-change ((shares shares))
  (let ((change nil))
    (bt:with-lock-held ((changes-lock shares))
      (setf change (pop (changes shares))))
    change))

(defmethod get-selected-file ((shares shares) selected-item)
  "returns a list with info about the selected item. This list will be
  used by the download widget to set its fields.
  (get-selected-file shares selected-item)
  => (:file (\"21f2a2f...\"
             \"test.txt\"
             1789213
            (\"pete@192...\" \"steve@192...\")))
  (get-selected-file shares selected-item)
  => (:dir (\"/some/dir/somewhere/\"
            \"somewhere/\"
            \"pete@192.168.2.101:43210\"
            92421312
            17))"
  (let ((info (gethash (q+:text selected-item +shares-path+) (entries shares))))
    (etypecase info
      (shares-entry-dir
       (with-slots (user name path size childs) info
         (list :dir
               (list path
                     name
                     user
                     size
                     (hash-table-count childs)))))
      (shares-entry-file
       (with-slots (name checksum size) info
         (list :file
               (list checksum
                     name
                     size
                     (loop :for (user . rest)
                           :in (lodds:get-file-info checksum)
                           :collect user))))))))

(defclass shares-entry ()
  ((shares :reader shares-entry-shares
           :initform (error "Please specify shares which this entry
           belongs to")
           :initarg :shares
           :documentation "Contains shares widget this shares-entry
           belongs to.")
   (widget :reader shares-entry-widget
           :initform nil
           :documentation "A qt widget corresponding to
           the given path.")
   (name :accessor shares-entry-name
         :initform (error "Please specify entry name")
         :initarg :name
         :type string
         :documentation "Name of entry")
   (user :accessor shares-entry-user
         :initform (error "Please specify a user")
         :initarg :user
         :type string
         :documentation "User which shared the given entry")
   (size :accessor shares-entry-size
         :initform (error "Please specify a widget")
         :initarg :size
         :type bignum
         :documentation "Size of the given share in bytes")
   (parent :accessor shares-entry-parent
           :initform (error "Please specify a parent entry")
           :initarg :parent
           :type shares-entry-dir
           :documentation "Parent of current entry, nil on root")
   (path :accessor shares-entry-path
         :initform (error "Please specify the entry path")
         :initarg :path
         :type string
         :documentation "Path which describes the entry")))

(defclass shares-entry-dir (shares-entry)
  ((childs :accessor shares-entry-childs
           :initform (make-hash-table :test 'equal)
           :type hashtable
           :documentation "Child items with name as key, and either
           shares-entry-dir or shares-entry-file as value")))

(defclass shares-entry-file (shares-entry)
  ((checksum :accessor shares-entry-checksum
             :initform (error "Please specify a checksum")
             :initarg :checksum
             :type string
             :documentation "File entries checksum")))

(defun set-column-background (entry column color)
  (with-finalizing* ((qcolor (q+:make-qcolor color))
                     (qbrush (q+:make-qbrush qcolor)))
    (q+:set-background entry column qbrush)))

(defgeneric update-entry-display (shares-entry)
  (:documentation "Updates entries displayed size and tooltip")
  (:method :around ((entry shares-entry))
    (when (slot-value entry 'parent)
      (call-next-method)))
  (:method ((entry shares-entry))
    (with-slots (widget size user) entry
      (when (lodds.config:get-value :show-background-color-on-size)
        (set-column-background widget
                               +shares-size+
                               (lodds.core:get-size-color size)))
      (qdoto widget
             (q+:set-text +shares-size+
                          (lodds.core:format-size size))
             (q+:set-tool-tip +shares-size+
                              (format nil "~:d bytes" size))
             (q+:set-tool-tip +shares-name+
                              (format nil "Double click, right click ~
                              or press Enter to download.")))))
  (:method ((entry shares-entry-dir))
    (call-next-method)
    (with-slots (widget path user size childs) entry
      (if (string= "/" path)
          (lodds.core:split-user-identifier (name ip port) user
            (q+:set-tool-tip widget +shares-name+
                             (format nil "Ip: ~a~%Port: ~a~%Folder Shared: ~a"
                                     ip port (hash-table-count childs))))
          (q+:set-status-tip widget +shares-name+
                             (format nil "Items: ~a" (hash-table-count childs))))))
  (:method ((entry shares-entry-file))
    (call-next-method)
    (with-slots (widget checksum) entry
      (q+:set-status-tip widget +shares-name+
                         (format nil "Checksum: ~a" checksum)))))

(defmethod initialize-instance :after ((entry shares-entry) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (name size widget path shares user parent) entry
    (let ((full-path (concatenate 'string "/" user path)))
      (setf (gethash full-path (entries shares)) entry)
      (setf widget
            (if parent
                (q+:make-qtreewidgetitem (shares-entry-widget parent))
                (q+:invisible-root-item shares)))

      (when parent
        (setf (gethash name (shares-entry-childs parent))
              entry)
        (update-entry-display parent))

      (when (and (lodds.config:get-value :show-background-color-on-size)
                 parent)
        (set-column-background widget +shares-size+
                               (lodds.core:get-size-color size)))
      (qdoto widget
             (q+:set-flags (qt:enum-or (q+:qt.item-is-selectable)
                                       (q+:qt.item-is-enabled)))
             (q+:set-text-alignment +shares-size+
                                    (qt:enum-or (q+:qt.align-center)
                                                (q+:qt.align-right)))
             (q+:set-text +shares-name+ name)
             (q+:set-text +shares-size+ (lodds.core:format-size size))
             (q+:set-text +shares-path+ full-path)))))

(defmethod set-mime-icon ((entry shares-entry) mimetype)
  (when (lodds.config:get-value :show-filetype-icons)
    (let ((icon (load-filetype-icon mimetype)))
      (q+:set-icon (shares-entry-widget entry) 0 icon)
      (finalize icon))))

(defmethod initialize-instance :after ((entry shares-entry-dir) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (widget path name parent) entry
    (when parent
      (q+:insert-child (shares-entry-widget parent)
                       0
                       widget))
    (when (string= "/" path)
      (lodds.core:split-user-identifier (user ip port) name
        (q+:set-text widget +shares-name+ user)))
    (update-entry-display entry)
    (set-mime-icon entry "_folder")))

(defmethod initialize-instance :after ((entry shares-entry-file) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (path widget parent) entry
    (when parent
      (q+:add-child (shares-entry-widget parent)
                    widget))
    (update-entry-display entry)
    (set-mime-icon entry (get-namestring-type path))))

(define-signal (shares update-entries) (string))
(define-signal (shares remove-entry) (string))
(define-signal (shares dump-table) ())

(defparameter *new-checksum* nil)
(defparameter *new-size* nil)
(defparameter *new-user* nil)
(defmethod add-node ((shares shares) path path-left parent)
  "Add a new node described by path-left (list). path gets
concatenated on recursive calls."
  (let ((entry (gethash (car path-left) (shares-entry-childs parent))))
    (when entry
      (unless (cdr path-left)
        ;; if there is no path left but we have a matching node, it
        ;; means that the node we tried to add already exists ->
        ;; return nil to indicate an error
        (return-from add-node nil))
      ;; but if there is path left, add the node on the matching
      ;; child node.
      (if (add-node shares
                    (concatenate 'string path (car path-left))
                    (cdr path-left)
                    entry)
          ;; if add-node was successfull, update size and return. We
          ;; dont have to update items, since if the item was added
          ;; directly below the current node, items was already
          ;; updated
          (progn
            (incf (shares-entry-size entry) *new-size*)
            (update-entry-display entry)
            (return-from add-node t))
          ;; if add-child-node was not successfull, just go up the
          ;; stack and return nil
          (return-from add-node nil))))
  ;; when we get down here (entry was nil) it means there was no
  ;; matching node found with the current path, so lets add a new
  ;; node.
  (let ((current-path (concatenate 'string
                                   path
                                   (car path-left))))
    ;; if we got path left -> dir, if not -> leaf -> file
    (if (cdr path-left)
        ;; call add-node recursivly with a new shares-entry-dir and
        ;; return the result of calling add-node
        (add-node shares
                  (concatenate 'string path (car path-left))
                  (cdr path-left)
                  (make-instance 'shares-entry-dir
                                 :shares shares
                                 :parent parent
                                 :name (car path-left)
                                 :path (subseq current-path
                                               (length *new-user*))
                                 :size *new-size*
                                 :user *new-user*))
        ;; add a new shares-entry-file and return it to indicate
        ;; success
        (make-instance 'shares-entry-file
                       :shares shares
                       :parent parent
                       :name (car path-left)
                       :checksum *new-checksum*
                       :path (subseq current-path
                                     (length *new-user*))
                       :size *new-size*
                       :user *new-user*))))

(defmethod get-total-shares-size ((shares shares))
  (shares-entry-size (root shares)))

(defmethod cleanup-entry ((entry shares-entry))
  (with-slots (parent path shares name user) entry
    (when parent
      (with-slots (childs widget) parent
        (remhash name childs)
        (do-childs (element i widget)
          (when (string= name
                         (shares-entry-name
                          (gethash (q+:text element +shares-path+)
                                   (entries shares))))
            (finalize (q+:take-child widget i))
            (remhash (concatenate 'string "/" user path) (entries shares))
            (update-entry-display parent)
            (return-from cleanup-entry)))))))

(defmethod cleanup-entry ((entry shares-entry-dir))
  (maphash (lambda (key value)
             (declare (ignore key))
             (cleanup-entry value))
           (shares-entry-childs entry))
  (call-next-method))

(defmethod remove-node ((shares shares) path)
  "Remove node described by given path (unix namestring) starting by
parent"
  (let ((entry (gethash path (entries shares))))
    (when entry
      (let ((size (shares-entry-size entry))
            (parent (shares-entry-parent entry)))
        (cleanup-entry entry)
        (loop :while parent
              :do
              (let ((cur parent))
                (setf parent (shares-entry-parent cur))
                (if (and (eql 0 (hash-table-count (shares-entry-childs cur)))
                         parent)
                    (cleanup-entry cur)
                    (progn
                      (decf (shares-entry-size cur) size)
                      (update-entry-display cur)))))))))

(define-slot (shares update-entries) ((user string))
  (declare (connected shares (update-entries string)))
  (q+:set-updates-enabled shares nil)
  (let* ((changes (get-change shares))
         (amount (length changes))
         (current 0))
    (loop :for (type checksum size path) :in changes
          :do (let ((combined-path (concatenate 'string user path)))
                (when main-window
                  (q+:show-message
                   (q+:status-bar main-window)
                   (format nil "Updating Shares (~:d/~:d) ~a"
                           amount
                           (incf current)
                           path)))
                (ecase type
                  (:add (let* ((split-path (lodds.core:split-path combined-path))
                               (*new-checksum* checksum)
                               (*new-size* size)
                               (*new-user* user ))
                          (when (add-node shares "" split-path root)
                            (incf (shares-entry-size root) size))))
                  (:del (remove-node shares (concatenate 'string "/" combined-path)))))))
  (q+:set-updates-enabled shares t))

(define-slot (shares remove-entry) ((path string))
  (declare (connected shares (remove-entry string)))
  (remove-node shares path))

(defun dump-item (item &optional (depth 0))
  "dumps given item, and all its childs, if it has any. Just for
  debugging"
  (format t "ITEM: ~a~a~%"
          (make-string depth :initial-element #\ )
          (q+:text item +shares-name+))
  (loop :for i :from 0 :below (q+:child-count item)
        :do (dump-item (q+:child item i)
                       (+ depth 1))))

(define-slot (shares dump-table) ()
  (declare (connected shares (dump-table)))
  (loop :for i :from 0 :below (q+:top-level-item-count shares)
        :do (dump-item (q+:top-level-item shares i))))

(defun make-file-info-widget (checksum name size users)
  (declare (ignore users))
  (let* ((top-widget (q+:make-qwidget))
         (widget (q+:make-qwidget top-widget))
         (top-layout (q+:make-qvboxlayout top-widget))
         (layout (q+:make-qformlayout widget))
         (tree (qdoto (q+:make-qtreewidget top-widget)
                      (q+:set-column-count 1)
                      (q+:set-header-labels
                       (list "Users who share the given file:")))))
    (loop :for (user load size filenames)
          :in (lodds:get-file-info checksum)
          :do (let ((item (add-row (q+:invisible-root-item tree) user)))
                (loop :for file :in filenames
                      :do (add-row item file))))
    (qdoto layout
           (q+:set-form-alignment (q+:qt.align-top))
           (q+:add-row "Checksum: " (q+:make-qlabel checksum))
           (q+:add-row "Name: " (q+:make-qlabel name))
           (q+:add-row "Size: " (q+:make-qlabel (format nil "~a (~:d bytes)"
                                                        (lodds.core:format-size size)
                                                        size))))
    (q+:add-widget top-layout widget)
    (q+:add-widget top-layout tree)
    top-widget))

(defun open-info-file-dialog (checksum name size users)
  (make-instance 'dialog
                 :title "File Info"
                 :widget (make-file-info-widget checksum
                                                name
                                                size
                                                users)))

(defun open-info-folder-dialog (fullpath dir user size files)
  (make-instance 'dialog
                 :title "Folder Info"
                 :widget
                 (let ((widget (q+:make-qwidget)))
                   (qdoto (q+:make-qformlayout widget)
                          (q+:add-row "Fullpath:" (q+:make-qlabel
                                                   (concatenate 'string "/" user fullpath)))
                          (q+:add-row "Dir:" (q+:make-qlabel dir))
                          (q+:add-row "User:" (q+:make-qlabel user))
                          (q+:add-row "Size:" (q+:make-qlabel
                                               (format nil "~a (~:d bytes)"
                                                       (lodds.core:format-size size)
                                                       size)))
                          (q+:add-row "Files:" (q+:make-qlabel (format nil "~:d" files))))
                   widget)))

(defmethod download ((shares shares))
  (let ((selected-items (q+:selected-items shares)))
    (case (length selected-items)
      (0 nil)
      (1 (destructuring-bind (type info)
             (get-selected-file shares (car selected-items))
           (case type
             (:file
              (apply #'open-download-file-dialog info))
             (:dir
              (apply #'open-download-folder-dialog info)))))
      (t (open-download-multiple-dialog
          (mapcar (lambda (item)
                    (get-selected-file shares item))
                  (q+:selected-items shares)))))))

(defmethod info ((shares shares))
  (let ((selected-items (q+:selected-items shares)))
    (flet ((open-info (item)
             (destructuring-bind (type info)
                 (get-selected-file shares item)
               (case type
                 (:file
                  (apply #'open-info-file-dialog info))
                 (:dir
                  (apply #'open-info-folder-dialog info))))))
      (case (length selected-items)
        (0 nil)
        (1 (open-info (car selected-items)))
        (t (let ((items (length (q+:selected-items shares))))
             (make-instance 'dialog
                            :title "Are you Sure?"
                            :text
                            (format nil "This action would open ~a info dialogs.~%~
                                        Are you sure that you want to proceed~%~
                                        (aka open ~a info dialogs)?"
                                    items
                                    items)
                            :ok-text "Yes (I love dialogs)"
                            :cancel-text "No"
                            :on-success-fn
                            (lambda (widget)
                              (declare (ignore widget))
                              (mapcar (lambda (item)
                                        (open-info item))
                                      (q+:selected-items shares))))))))))

(define-override (shares key-press-event) (ev)
  (call-next-qmethod)
  (cond
    ((or (= (q+:key ev) (q+:qt.key_enter))
         (= (q+:key ev) (q+:qt.key_return)))
     (download shares))
    ((= (q+:key ev) (q+:qt.key_i))
     (info shares))))

(define-slot (shares prepare-menu) ((pos "const QPoint &"))
  (declare (connected shares (custom-context-menu-requested "const QPoint &")))
  (let ((widget (q+:item-at shares pos)))
    (when (qobject-alive-p widget)
      (with-finalizing ((global-pos (q+:map-to-global shares pos))
                        (menu (qdoto (q+:make-qmenu)
                                     (q+:add-action "Download")
                                     (q+:add-action "Info"))))
        (let ((option (q+:exec menu global-pos)))
          (cond
            ((null-qobject-p option))
            ((string= "Download" (q+:text option))
             (download shares))
            ((string= "Info" (q+:text option))
             (info shares))))))))

(defmethod update-font ((shares shares) new-font)
  (q+:set-font shares (get-font new-font)))

(define-initializer (shares setup-widget)
  (connect shares
           "itemDoubleClicked(QTreeWidgetItem *, int)"
           (lambda (selected-item column)
             (declare (ignore column selected-item))
             (download shares)))
  (setf root
        (make-instance 'shares-entry-dir
                       :shares shares
                       :parent nil
                       :name ""
                       :path ""
                       :size 0
                       :user ""))
  (update-font shares (lodds.config:get-value :shares-font))
  (qdoto shares
         (q+:set-mouse-tracking t)
         (q+:set-object-name "Shares")
         (q+:set-selection-behavior (q+:qabstractitemview.select-rows))
         (q+:set-selection-mode (q+:qabstractitemview.extended-selection))
         (q+:set-column-count 3)
         (q+:set-uniform-row-heights t)
         (q+:set-header-labels (list "Name" "Size" "Path"))
         (q+:hide-column +shares-path+)
         (q+:set-alternating-row-colors t)
         (q+:set-animated t)
         (q+:set-items-expandable t)
         (q+:set-context-menu-policy (q+:qt.custom-context-menu))
         (q+:set-expands-on-double-click nil))
  (qdoto (q+:header shares)
         (q+:hide)
         (q+:set-stretch-last-section nil)
         (q+:set-resize-mode +shares-name+ (q+:qheaderview.stretch))
         (q+:resize-section +shares-size+ (lodds.config:get-value :size-column-width))))

(define-initializer (shares setup-callbacks)
  ;; move this to list-view later
  (lodds.event:add-callback :qt-shares
                            (lambda (user)
                              (signal! shares
                                       (remove-entry string)
                                       (concatenate 'string "/" user "/")))
                            :user-removed)
  (lodds.event:add-callback :qt-shares
                            (lambda (name type timestamp changes)
                              (declare (ignore timestamp))
                              (when (eql type :all)
                                (signal! shares (remove-entry string)
                                         (concatenate 'string "/" name "/")))
                              (add-change shares changes name))
                            :list-update))

(define-initializer (shares setup-add-files)
  ;; add known users and their shared files
  (loop :for user :in (lodds:get-user-list)
        :do (let ((user-info (lodds:get-user-info user)))
              ;; add all files from user
              (let ((changes nil))
                (maphash (lambda (filename file-info)
                           (destructuring-bind (checksum size) file-info
                             (push (list :add checksum size filename) changes)))
                         (lodds:user-file-table-name user-info))
                (add-change shares changes user)))))

(define-finalizer (shares cleanup-callbacks)
  (lodds.event:remove-callback :qt-shares :user-removed)
  (lodds.event:remove-callback :qt-shares :list-update))
