(in-package #:lodds-qt)
(in-readtable :qtools)

(defgeneric get-value (widget))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass setting ()
    ((config :initarg :config
             :documentation "The Current configuration")
     (key :initarg :key
          :documentation "Settings key to look up value, description
          etc. see lodds.config")
     (widget :documentation "The widget itself, will be set on widget
           init. is used to set tooltip on initialize-instance"))))

(defmethod initialize-instance :after ((setting setting) &rest initargs)
  (declare (ignorable initargs))
  (with-slots (widget key config) setting
    (q+:set-tool-tip widget
                     (lodds.config:get-description key config))))

;; Selection Widget

(define-widget selection-setting (QWidget setting)
  ())

(define-subwidget (selection-setting selector)
    (q+:make-qcombobox selection-setting)
  (with-slots (key widget config) selection-setting
    (setf (q+:size-policy selector) (values (q+:qsizepolicy.expanding)
                                            (q+:qsizepolicy.fixed)))
    (q+:add-items selector (lodds.config:get-selection-options key config))
    (setf widget selector)
    (let ((value (lodds.config:get-value key config)))
      (if value
          (let ((current-index (q+:find-text selector
                                             value)))
            (when (>= current-index 0)
              (q+:set-current-index selector current-index)))
          (q+:set-current-index selector -1)))))

(define-subwidget (selection-setting refresh)
    (q+:make-qpushbutton "Reload" selection-setting)
  (setf (q+:size-policy refresh) (values (q+:qsizepolicy.minimum)
                                         (q+:qsizepolicy.fixed))))

(define-slot (selection-setting refresh) ()
  (declare (connected refresh (pressed)))
  (with-slots (config key) selection-setting
    (q+:clear selector)
    (q+:add-items selector
                  (lodds.config:get-selection-options
                   key
                   config))))

(define-subwidget (selection-setting layout)
    (q+:make-qhboxlayout selection-setting)
  (qdoto layout
         (q+:add-widget selector)
         (q+:add-widget refresh)))

(defmethod get-value ((selection-setting selection-setting))
  (q+:current-text (slot-value selection-setting 'selector)))

;; Boolean Widget

(define-widget boolean-setting (QCheckBox setting)
  ())

(define-initializer (boolean-setting setup-widget)
  (with-slots (key widget config) boolean-setting
    (setf widget boolean-setting)
    (q+:set-checked boolean-setting (lodds.config:get-value key config))))

(defmethod get-value ((boolean-setting boolean-setting))
  (q+:is-checked boolean-setting))

;; Integer Widget

(define-widget integer-setting (QSpinBox setting)
  ())

(define-initializer (integer-setting setup-widget)
  (with-slots (key widget config) integer-setting
    (q+:set-range integer-setting
                  (lodds.config:get-integer-min key config)
                  (lodds.config:get-integer-max key config))
    (setf widget integer-setting)
    (q+:set-value integer-setting (lodds.config:get-value key config))))

(defmethod get-value ((integer-setting integer-setting))
  (q+:value integer-setting))

;; String Widget

(define-widget string-setting (QLineEdit setting)
  ())

(define-initializer (string-setting setup-widget)
  (with-slots (key widget config) string-setting
    (setf widget string-setting)
    (q+:set-text string-setting
                 (lodds.config:get-value key config))))

(defmethod get-value ((string-setting string-setting))
  (q+:text string-setting))

;; List Widget

(define-widget list-setting (QLineEdit setting)
  ())

(define-initializer (list-setting setup-widget)
  (with-slots (key widget config) list-setting
    (setf widget list-setting)
    (q+:set-text list-setting (format nil "~{~a~^,~}"
                                      (lodds.config:get-value key config)))))

(define-override (list-setting key-press-event) (ev)
  (with-slots (key config) list-setting
    (if (enum-equal (q+:key ev) (q+:qt.key_tab))
        (let* ((text (q+:text list-setting))
               (already-inserted (mapcar (lambda (str)
                                           (string-trim '(#\Space) str))
                                         (cl-strings:split text #\,)))
               (name-substring (car (last already-inserted)))
               (user (find name-substring
                           (lodds.config:get-suggestions
                            key
                            config)
                           :test (lambda (swap me)
                                   (cl-strings:starts-with me swap)))))
          (when user
            (setf (car (last already-inserted))
                  user)
            (q+:set-text list-setting
                         (format nil "~{~a~^,~}"
                                 already-inserted))))
        (stop-overriding))))

(defmethod get-value ((list-setting list-setting))
  (let ((line (q+:text list-setting)))
    (mapcar (lambda (str)
              (string-trim '(#\Space) str))
            (unless (eql 0 (length (string-trim '(#\Space) line)))
              (cl-strings:split line #\,)))))

;; Folder Widget

(define-widget folder-setting (QWidget setting)
  ())

(define-subwidget (folder-setting folder)
    (q+:make-qlineedit folder-setting)
  (with-slots (key) folder-setting
    (let* ((completer (q+:make-qcompleter folder))
           (dir-model (q+:make-qdirmodel completer)))
      (q+:set-filter dir-model (q+:qdir.dirs))
      (q+:set-model completer dir-model)
      (q+:set-completer folder completer)
      (q+:set-minimum-width folder 150))
    (setf (q+:size-policy folder) (values (q+:qsizepolicy.expanding)
                                          (q+:qsizepolicy.fixed)))))

(define-subwidget (folder-setting open)
    (q+:make-qpushbutton "Open" folder-setting)
  (setf (q+:size-policy open) (values (q+:qsizepolicy.minimum)
                                      (q+:qsizepolicy.fixed))))

(define-slot (folder-setting open) ()
  (declare (connected open (pressed)))
  (let ((dir (q+:qfiledialog-get-existing-directory)))
    (when (> (length dir)
             0)
      (q+:set-text folder dir))))

(define-subwidget (folder-setting layout)
    (q+:make-qhboxlayout folder-setting)
  (qdoto layout
         (q+:add-widget folder)
         (q+:add-widget open)))

(define-initializer (folder-setting setup-widget)
  (with-slots (key widget config) folder-setting
    (setf widget folder)
    (q+:set-text folder (lodds.config:get-value key config))))

(defmethod get-value ((folder-setting folder-setting))
  (q+:text (slot-value folder-setting 'folder)))

;; Functions

(defun make-setting (key config)
  (case (lodds.config:get-type key config)
    (:boolean   (make-instance 'boolean-setting   :key key :config config))
    (:list      (make-instance 'list-setting      :key key :config config))
    (:string    (make-instance 'string-setting    :key key :config config))
    (:integer   (make-instance 'integer-setting   :key key :config config))
    (:folder    (make-instance 'folder-setting    :key key :config config))
    (:selection (make-instance 'selection-setting :key key :config config))
    (t (error "Type ~a of key ~a not recognised"
              (lodds.config:get-type key config)
              key))))

(define-widget settings-widget (QScrollArea)
  ((config :initform nil
           :initarg :config)
   (update-inplace-p :initform t
                     :initarg :update-inplace-p)
   (settings :initform (list))))

(define-subwidget (settings-widget scrollarea)
    (q+:make-qscrollarea settings-widget))

(define-subwidget (settings-widget save)
    (q+:make-qpushbutton "Save to File" settings-widget))

(define-subwidget (settings-widget load-file)
    (q+:make-qpushbutton "Load from File" settings-widget))

(define-subwidget (settings-widget load-default)
    (q+:make-qpushbutton "Load Default" settings-widget))

(define-subwidget (settings-widget layout)
    (q+:make-qvboxlayout settings-widget)
  (let* ((button-widget (q+:make-qwidget settings-widget))
         (button-layout (q+:make-qhboxlayout button-widget)))
    (qdoto button-layout
           (q+:add-widget save)
           (q+:add-widget load-file)
           (q+:add-widget load-default))
    (qdoto layout
           (q+:add-widget button-widget)
           (q+:add-widget scrollarea))))

(defmethod generate-config-widget ((settings-widget settings-widget))
  (with-slots-bound (settings-widget settings-widget)
    (let* ((widget (q+:make-qwidget))
           (layout (q+:make-qformlayout widget)))
      (loop :for key :in (lodds.config:get-all-keys config)
            :do (let ((label (q+:make-qlabel
                              (format nil "~a:"
                                      (string-downcase (string key)))))
                      (setting (make-setting key config)))
                  (q+:set-tool-tip label
                                   (lodds.config:get-description key config))
                  (q+:add-row layout
                              label
                              setting)
                  (push setting settings))
            :finally (return widget)))))

(define-initializer (settings-widget setup-widget)
  (q+:set-widget-resizable scrollarea t)
  (q+:set-widget scrollarea
                 (generate-config-widget settings-widget)))

(define-slot (settings-widget save-pressed) ()
  (declare (connected save (pressed)))
  (let ((file-choosen (q+:qfiledialog-get-save-file-name)))
    (when (> (length file-choosen)
             0)
      (lodds.config:save-to-file file-choosen
                                 config))))

(defmethod generate-new-settings ((settings-widget settings-widget))
  (with-slots-bound (settings-widget settings-widget)
    (setf update-inplace-p nil)
    (finalize (q+:take-widget scrollarea))
    (setf settings (list))
    (q+:set-widget scrollarea
                   (generate-config-widget settings-widget))))

(define-slot (settings-widget load-default-pressed) ()
  (declare (connected load-default (pressed)))
  (setf config (lodds.config:generate-default-config))
  (generate-new-settings settings-widget))

(define-slot (settings-widget load-file-pressed) ()
  (declare (connected load-file (pressed)))
  (let ((file-choosen (q+:qfiledialog-get-open-file-name)))
    (when (> (length file-choosen)
             0)
      (multiple-value-bind (new-config error)
          (lodds.config:load-from-file file-choosen config)
        (if error
            (make-instance 'dialog
                           :title "Error Reading Config File"
                           :text error)
            (progn
              (setf config new-config)
              (generate-new-settings settings-widget)))))))

(defmethod update-setting ((settings-widget settings-widget))
  (with-slots (settings config update-inplace-p) settings-widget
    (loop :for setting :in settings
          :do
          (let* ((key (slot-value setting 'key))
                 (err (lodds.config:update-entry key
                                                 (get-value setting)
                                                 update-inplace-p
                                                 config)))
            (when err
              (make-instance 'dialog
                             :title "ERROR - Wrong Setting"
                             :text (format nil "Error on setting key: ~a~%~a"
                                           key
                                           err))
              (return nil)))
          :finally (return config))))

(defmethod validate-config ((settings-widget settings-widget))
  (with-slots (config update-inplace-p) settings-widget
    (let ((successfull (update-setting settings-widget)))
      (when (and successfull
                 (not update-inplace-p))
        (lodds:update-config config))
      successfull)))

(defun make-setting-dialog ()
  (make-instance 'dialog
                 :title "Settings"
                 :widget (make-instance 'settings-widget
                                        :config
                                        (slot-value lodds:*server*
                                                    'lodds:settings))
                 :width 600
                 :height 500
                 :on-success-fn
                 (lambda (settings)
                   (validate-config settings))))
