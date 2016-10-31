;;;; lodds-low-level-api.lisp

#|

This file contains the low-level-api implementation of the LODDS protocol,
functions are split into three 'families'. The 'get' family will initiate a
LODDS based communication by requesting data. The 'respond' family functions
will be the counter-part to them, responding with information. The information
is then read by the 'handle' family functions.

All functions will return a number. If zero no error occured and
everything went fine, on error a error code will be returned.
TODO: Where to lookup error codes?
Some functions return multiple values which can be handle with a
multiple-value-bind.

|#

(in-package #:lodds.low-level-api)

(defvar *advertise-scanner*
  (cl-ppcre:create-scanner
   ;; ip port timestamp load name
   "^(\\d{1,3}\\.){3}\\d{1,3} \\d{1,5} \\d+ \\d+ [^\\s]+\\n$")
  "used to scan advertise strings to check if they are correct")

(defvar *get-scanner*
  (cl-ppcre:create-scanner
   ;; expects one of:
   ;; get file checksum start end
   ;; get info timestamp
   ;; get send-permission size timeout filename
   "^get ((file [^\\s]{64} \\d+ \\d+)|(info \\d+)|(send-permission \\d+ \\d+ [^\\n]+))$")
  "used to scan get requests to check if they are correct")

(defvar *info-head-scanner*
  (cl-ppcre:create-scanner
   ;; type timestamp count
   "^(upd|all) \d+ \d+$")
  "used to scan get info head to check if they are correct")

(defvar *info-body-scanner*
  (cl-ppcre:create-scanner
   ;; type checksum size realtive-filename
   "^(add|del) [^\\s]{64} \\d+ [^\\n]+$")
  "used to scan get info body to check if they are correct")

;; broadcast family

(defun send-advertise (broadcast-host broadcast-port ad-info)
  "will format ad-info and write it to a udp-broadcast socket
   with given broadcast-host and broadcast-port.
   ad-info is a list containing ip, port, timestamp, load and name,
   in that order. for example:
   '(#(192 168 2 255) 12345 87654321 9999 \"username\")"
  (destructuring-bind (ip port timestamp load name) ad-info
    (let ((sock (usocket:socket-connect nil nil :protocol :datagram))
          (data (flexi-streams:string-to-octets
                 (format nil "~a ~a ~a ~a ~a~%"
                         (usocket:vector-quad-to-dotted-quad ip)
                         port
                         (if timestamp
                             timestamp
                             0)
                         load
                         name))))
      (setf (usocket:socket-option sock :broadcast) t)
      (usocket:socket-send sock data (length data)
                           :host broadcast-host
                           :port broadcast-port)
      (usocket:socket-close sock)))
  0)

(defun read-advertise (message)
  "counter-part to send-advertise, will parse the given message (byte
   vector) and return a list out of ip, port, timestamp, load and name.
   for example: '(#(192 168 2 255) 12345 9999 87654321 \"username\")
   will use *advertise-scanner* to check for syntax errors."
  (if (cl-ppcre:scan *advertise-scanner*
                     (flexi-streams:octets-to-string message))
      (destructuring-bind (ip port timestamp load . name)
          (cl-strings:split
           (flexi-streams:octets-to-string message))
        (values 0
                (list (usocket:dotted-quad-to-vector-quad ip)
                      (parse-integer port)
                      (parse-integer timestamp)
                      (parse-integer load)
                      (let ((name (cl-strings:join name)))
                        (cl-strings:shorten ;; delete \n
                         name
                         (- (length name) 1)
                         :truncate-string nil)))))
      2))

(defun parse-request (socket-stream)
  "parses a direct communication request. returns multiple values,
   the first is a number describing the error (or 0 on success) and
   one of the following lists, depending on request:
   (:file checksum start end)
   (:info timestamp)
   (:send-permission size timeout filename)
   will use *get-scanner* to to check for syntax errors"
  (let ((line (read-line socket-stream)))
    (unless (cl-ppcre:scan *get-scanner* line)
      (return-from parse-request 2))
    (destructuring-bind (get type . args)
        (cl-strings:split line)
      (declare (ignore get))
      (let ((requ-type (str-case type
                         ("file" :file)
                         ("info" :info)
                         ("send-permission" :send-permission))))
        (case requ-type
          (:file (values 0
                         (list :file
                               (car args)
                               (parse-integer (nth 1 args))
                               (parse-integer (nth 2 args)))))
          (:info (values 0
                         (list :info
                               (parse-integer (car args)))))
          (:send-permission (values 0
                                    (destructuring-bind (size timeout . filename)
                                        args
                                      (list :send-permission
                                            (parse-integer size)
                                            (parse-integer timeout)
                                            (cl-strings:join filename :separator " "))))))))))

;; get family
(defun get-file (socket-stream checksum start end)
  "will format and write a 'get file' request onto socket-stream requesting
   the specified (checksum) file's content from start till end"
  (format socket-stream "get file ~a ~a ~a~%" checksum start end)
  0)

(defun get-info (socket-stream timestamp)
  "will format and write a 'get info' request onto socket-stream requesting
   information about shared files. timestamp describes the last requested
   information the client currently holds. If timestamp is zero (0) it will
   request a full list of shared files from the client."
  (format socket-stream "get info ~a~%" timestamp)
  0)

(defun get-send-permission (socket-stream size timeout filename)
  "will format and write a 'get-send-permission' request onto socket-stream
   requesting send permission. size is a fixnum describing the file size of the
   to-be-transfered file. The requested client then has 'timeout' seconds to
   respond with either a OK or a connection close. filename is a string containing
   the filename."
  (format socket-stream "get send-permission ~a ~a ~a~%"
          size timeout filename)
  0)

;; response family

(defun respond-file (socket-stream file-stream start end)
  "response to a get-file writing data from file-stream to socket-stream.
   file-stream will be positioned at start, and only transfer till end."
  (unless (eql start 0)
    (file-position file-stream start))
  (lodds.core:copy-stream file-stream socket-stream (- end start))
  0)

(defun respond-info (socket-stream type timestamp file-infos)
  "response to a 'get info' request. Will format type timestamp and
   file-infos and write it onto socket-stream. type can be either :all or :upt.
   timestamp is a fixnum somewhat like a 'revision', describing the current state.
   file-infos a list containing lists with type, checksum, size and name describing
   all files. type will either be :add or :del and checksum is a sha-256 of the
   file's content. size is, as the name suggests, the file size. name is the
   relative pathname.
   TODO: relative pathname link to spec"
  (format socket-stream "~a ~a ~a~%"
          timestamp
          (if (eql type :all)
              "all"
              "upd")
          (length file-infos))
  (loop
     :for (type checksum size name) :in file-infos
     :do (format socket-stream "~a ~a ~a ~a~%"
                 (if (eql type :add)
                     "add"
                     "del")
                 checksum
                 size
                 name))
  0)

(defun respond-send-permission (socket-stream file-stream size)
  "response to a 'get send-permission', will send a OK and copy the
   socket-stream content (max size bytes) to file-stream."
  (format socket-stream "OK~%")
  (force-output socket-stream)
  (copy-stream socket-stream file-stream size)
  0)

;; handle family

(defun handle-file (socket-stream file-stream size)
  "handles a successfull 'get file' request and writes the incomming
   file content from socket-stream to file-stream. Size describes the
   maximum bytes read/written"
  (copy-stream socket-stream file-stream size)
  0)

(defun handle-info (socket-stream)
  "handles a successfull 'get info' request and returns (as second
   value) a list containing the parsed data. The list has the same format
   as 'file-infos' argument from respond-info function"
  (let ((line (read-line socket-stream)))
    (if (cl-ppcre:scan *info-head-scanner* line)
        (destructuring-bind (type timestamp count) (cl-strings:split line)
          (values 0
                  (cond
                    ((equalp type "add") :add)
                    ((equalp type "del") :del)
                    (t (error "TODO: handle-info add|del error")))
                  (parse-integer timestamp)
                  (loop
                     :repeat (parse-integer count)
                     :collect (progn
                                (setf line (read-line socket-stream))
                                (if (cl-ppcre:scan *info-body-scanner* line)
                                    (destructuring-bind (type checksum size . name)
                                        (cl-strings:split line)
                                      (list (cond
                                              ((equalp type "add") :add)
                                              ((equalp type "del") :del)
                                              (t (error "TODO: handle-info add|del error")))
                                            checksum
                                            (parse-integer size)
                                            (cl-strings:join name :separator " ")))
                                    2)))))
        2)))

(defun handle-send-permission (socket timeout file-stream)
  "handles a successfull 'get send-permission' request and waits
   maximum 'timeout' seconds for a OK. On success it writes data from
   file-stream to socket.
   TODO: implement parse of OK."
  (if (usocket:wait-for-input socket :timeout timeout)
      (let ((socket-stream (usocket:socket-stream socket)))
        (if (string= "OK"
                     (read-line socket-stream))
            (copy-stream file-stream
                         socket-stream)
            2)
       2)))
