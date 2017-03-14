#|

This file contains the Handler, his job is to listen for incomming
connections. When there is a connection he will submit a task-requst
thread to the tasker, which then handles the request.

|#

(in-package #:lodds.handler)

(defun open-socket ()
  (handler-case
      (usocket:socket-listen
       (lodds.core:get-ip-address (lodds.config:get-value :interface))
       (lodds.config:get-value :port)
       :reuse-address t
       :element-type '(unsigned-byte 8))
    (error (e)
      (lodds.event:push-event :error
                              (format nil "Error starting Listener (~a)" e))
      (sleep 1)
      (when (lodds.subsystem:alive-p (lodds:get-subsystem :handler))
        (open-socket)))))

(defun run ()
  (let ((socket (open-socket)))
    (unwind-protect
         (loop :while (lodds.subsystem:alive-p (lodds:get-subsystem :handler))
               :do (when (and (lodds.core:input-rdy-p socket 1)
                              (eql :read (usocket:socket-state socket)))
                     (lodds.task:submit-task
                      (make-instance 'lodds.task:task-request
                                     :name "request"
                                     :socket
                                     (let ((client-socket
                                             (usocket:socket-accept socket
                                                                    :element-type '(unsigned-byte 8))))
                                       (lodds.core:set-socket-timeout
                                        client-socket
                                        (lodds.config:get-value :socket-timeout))
                                       client-socket)))))
      (when socket
        (usocket:socket-close socket)))))
