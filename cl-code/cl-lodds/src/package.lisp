;;;; package.lisp

(defpackage #:lodds.core
  (:use #:cl)
  (:export #:with-server
           #:escape-wildcards
           #:ensure-directory-pathname
           #:generate-fake-checksum
           #:generate-checksum
           #:get-file-size
           #:format-timestamp
           #:format-checksum
           #:format-pathname
           #:input-rdy-p
           #:could-not-read-error
           #:out-of-data-error
           #:read-too-much-error
           #:copy-stream
           #:get-timestamp
           #:str-case
           #:format-size
           #:get-size-color
           #:split-user-identifier
           #:split-path
           #:ensure-trailing-slash
           #:format-seconds
           #:get-interfaces
           #:get-interface-info
           #:get-broadcast-address
           #:get-ip-address
           #:directory-exists
           #:file-exists
           #:set-socket-timeout
           #:octets-to-string
           #:string-to-octets))

(defpackage #:lodds.config
  (:use #:cl)
  (:export #:load-path
           #:*color-scanner*
           #:generate-default-config
           #:save-to-file
           #:validate-config
           #:update-entry
           #:load-from-file
           #:load-default-config-files
           #:get-all-keys
           #:get-value
           #:get-description
           #:get-type
           #:get-selection-options
           #:get-integer-min
           #:get-integer-max
           #:get-suggestions
           #:get-log-event-color))

(defpackage #:lodds.low-level-api
  (:use #:cl)
  (:export ;; conditions
           #:malformed-data
           #:malformed-advertise
           #:malformed-get
           #:malformed-info-head
           #:malformed-info-body
           #:timeout-reached
           ;; broadcast
           #:format-send-advertise
           #:send-advertise
           #:read-advertise
           ;; parses incomming requests
           #:parse-request
           ;; get family
           #:format-get-file
           #:get-file
           #:format-get-info
           #:get-info
           #:format-get-send-permission
           #:get-send-permission
           ;; respond family
           #:format-respond-info
           #:respond-info
           #:format-respond-send-permission
           #:respond-send-permission
           ;; handle family
           #:handle-info
           #:handle-send-permission))

(defpackage #:lodds.task
  (:use #:cl)
  (:export #:tasks
           #:tasks-get-load
           #:tasks-get-task-progresses
           #:tasks-get-task-count
           #:tasks-get-task-by-id
           #:tasks-cleanup
           #:task-request
           #:task-request-info
           #:task-send-permission
           #:task-request-file
           #:task-get-info
           #:task-send-file
           #:task-get-file-from-user
           #:task-get-file-from-users
           #:task-get-folder
           #:task-init
           #:task-id
           #:task-run
           #:task-load
           #:task-cancel
           #:task-info))

(defpackage #:lodds.watcher
  (:use #:cl)
  (:export #:watcher
           #:alive-p
           #:started-tracking
           #:dir-watchers
           #:list-of-changes
           #:last-change
           #:get-all-tracked-file-infos
           #:get-file-info
           #:get-shared-folders
           #:folder-already-shared-p
           #:folder-shareable-p
           #:share-folder
           #:unshare-folder
           #:folder-busy-p
           #:stop))

(defpackage #:lodds.event
  (:use #:cl)
  (:export #:event-queue
           #:add-callback
           #:remove-callback
           #:push-event
           #:cleanup
           #:start
           #:stop
           #:callback-exists-p))

(defpackage #:lodds.event-loop
  (:use #:cl)
  (:export #:event-loop
           #:with-event-loop
           #:ev-delay-interval
           #:start
           #:stop))

(defpackage #:lodds.listener
  (:use #:cl)
  (:export #:start
           #:stop
           #:listener
           #:alive-p))

(defpackage #:lodds.handler
  (:use #:cl)
  (:export #:start
           #:stop
           #:handler
           #:alive-p))

(defpackage #:lodds
  (:use #:cl)
  (:export ;; global variables and macros
           #:*server*
           #:*event-queue*
           ;; user-info reader/accessor
           #:user-info
           #:user-name
           #:user-last-message
           #:user-ip
           #:user-port
           #:user-last-change
           #:user-load
           #:user-file-table-name
           #:user-file-table-hash
           #:user-lock
           ;; lodds-server reader/accessors
           #:lodds-server
           #:name
           #:broadcast-port
           #:handler-port
           #:user-timeout
           #:interface
           #:users
           #:list-of-changes-lock
           #:list-of-changes
           #:advertise-timeout
           #:get-load
           #:remove-users
           #:get-timestamp-last-change
           #:get-user-list
           #:get-user-info
           #:get-user-by-ip
           #:get-file-info
           #:get-folder-info
           #:get-file-changes
           #:update-user
           #:get-checksum-from-path
           #:start
           #:stop
           #:shutdown
           #:generate-info-response
           #:find-best-user
           #:get-file
           #:get-folder
           #:send-file
           #:remove-old-users
           #:settings
           #:switch-config
           #:update-config
           #:get-status
           #:user-is-trusted
           #:user-is-blocked
           #:untrust-user
           #:trust-user
           #:unblock-user
           #:block-user
           #:get-event-loop
           #:get-watcher
           #:get-event-queue
           #:get-listener
           #:get-tasks
           #:get-handler))
