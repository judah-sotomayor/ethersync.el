;;; esync.el --- Ethersync in Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Judah Sotomayor
;;
;; Author: Judah Sotomayor <Judah.Sotomayor@pm.me>
;; Maintainer: Judah Sotomayor <Judah.Sotomayor@pm.me>
;; Created: July 05, 2025
;; Modified: July 05, 2025
;; Version: 0.0.1
;; Keywords: convenience, collaboration, crdt
;; Homepage: https://github.com/judah-sotomayor/esync
;; Package-Requires: ((emacs "24.3"))

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Esync is the premier Emacs extension for Ethersync.
;; Details on Ethersync can be found here:
;; https://ethersync.github.io/ethersync/

;;; Code:

(require 'jsonrpc)
(require 'url)
(require 'dash)

(defcustom ethersync-executable
  (executable-find "ethersync")
  "The path to the ethersync executable."
  :type 'string
  :group 'magit)

(cl-defstruct esync--workspace
  (root nil)
  (daemon nil)
  (client nil)
  (ewoc nil)
  (buffers nil)
  (status nil)
  (cursors nil))

;;; * Ethersync Client
;;; ** Process Management
(defun esync--start-client-process (workspace)
  "Start an ethersync client in WORKSPACE."
  (let* ((stderr (generate-new-buffer "*Ethersync Client::Stderr*"))
         (stdout (generate-new-buffer "*Ethersync Client::Stdout*"))
         (default-directory (expand-file-name (esync--workspace-root workspace))))
    (make-process
     :name "Ethersync Client"
     :command (flatten-tree
               `(,ethersync-executable
                 "client"))
     :connection-type 'pipe
     :coding 'utf-8-emacs-unix
     :noquery t
     :stderr stderr
     :filter #'esync--client-filter
     :file-handler t)))

(cl-defmethod esync-process-kill ((proc process))
  "Kill PROC if still running."
  (when (process-live-p process)
    (kill-process process)))

(defun esync--on-client-shutdown (connection)
  "Handle CONNECTION shutdown."
  (warn "Client Shutdown!!!"))


(defun esync--connect-to-daemon (workspace)
  "Connect WORKSPACE to an active daemon using a client process."
  (let* ((spread (lambda (fn)
                   (lambda (server method params)
                     (apply fn workspace server method (append params nil)))))
         (connection (make-instance
                      jsonrpc-process-connection
                      :process (esync--start-client-process
                                workspace)
                      :on-shutdown #'esync--on-client-shutdown
                      :notification-dispatcher (funcall
                                                spread
                                                #'esync--handle-notification))))
    (setf (esync--workspace-client workspace) connection)))

;;; *** Logging
(defun esync--create-log (&rest args)
  "Create a log using ARGS."
  (message (pp args)))

;;; ** JSONRPC Requests
(defun esync--client-open-file (client file)
  "Open FILE in CLIENT.
FILE must be in the lsp uri format: \"file:///path/to/file\""
  (jsonrpc-async-request client :open `(:uri ,file)
                         :success-fn (esync--create-log "Opened file" file)
                         :timeout-fn (esync--create-log "Done" file)))

;;; * Notification Handlers
(cl-defgeneric esync--handle-notification (workspace connection method &rest params)
  "Handle ethersync client CONNECTION's METHOD notification with PARAMS.
WORKSPACE is passed through for specific data needs.")

(cl-defmethod esync--handle-notification
  (_workspace _server method &key &allow-other-keys)
  "Handle unknown METHOD."
  (message (format "Bad request! %s" method)))

(cl-defmethod esync--handle-notification
  (workspace server (method (eql cursor)) &key name ranges uri userid)
  "Handle METHOD :cursor from SERVER in WORKSPACE.
Cursor notifications include URI, RANGE, NAME, and USERID parameters.
When a request arrives, update the buffer with a new overlay."
  (esync--update-overlay workspace name ranges uri userid))

;;; * Overlay Management
(defun esync--update-overlay (workspace name ranges uri userid)
  "Reset the overlay for USERID in WORKSPACE.
Overlay should be across RANGES. Use URI and NAME."
  (let* ((file (url-filename (url-generic-parse-url uri)))
         (buffer (get-file-buffer (file-name-nondirectory file))))

    (when buffer
      (with-current-buffer buffer
        (esync--clear-overlays userid)
        (esync--set-overlays userid ranges)
        (esync--register-cursor workspace name ranges file userid)
        ))))

(defun esync--clear-overlays (userid)
  "Remove overlays in current buffer for USERID."
  (dolist (o (car (overlay-lists)))
    (when (string-equal (overlay-get o 'esync-user-id) userid)
      (delete-overlay o))))

(defun esync--set-overlays (userid ranges)
  "Create an overlay in current buffer over RANGES for USERID."
  (seq-doseq (range ranges)
    (-let* (((&plist :start :end) range)
            ((&plist :character start-c :line start-l) start)
            ((&plist :character end-c :line end-l) end)
            (start-position
             (esync--position-from-ethersync-position start-l start-c))
            (end-position
             (+ (esync--position-from-ethersync-position end-l end-c)
                (if (= start-c end-c) 1 0)))
            (color (esync--get-user-color userid))
            (new-overlay (make-overlay start-position end-position nil t nil)))
      (overlay-put new-overlay 'category 'esync-cursor)
      (overlay-put new-overlay 'esync-user-id userid)
      (overlay-put new-overlay 'face `(:background ,color)))))

(defun esync--get-user-color (userid)
  "Return a color for USERID."
  "#fff000000")

;;; ** Cursor Management
(defun esync--register-cursor (workspace name ranges file userid)
  "Register cursor in WORKSPACE with NAME, RANGES, FILE, and USERID."
  (puthash userid
           (list :name name
                 :file file
                 :ranges ranges)
           (esync--workspace-cursors workspace)))

;;; * Position and Coordinates Control
(defmacro esync--with-position (line char &rest body)
  "Execute BODY at position LINE, CHAR."
  `(save-excursion
     (goto-char (point-min))
     (forward-line ,line)
     (move-to-column ,char)
     ,@body))

(defun esync--position-from-ethersync-position (line char)
  "Get position number in current buffer from LINE, CHAR."
  (esync--with-position line char
                        (point)))

;;; * Data Validation
(defun esync--valid-uri-p (workspace uri)
  "Determine if a URI is valid for the WORKSPACE."
  (let* ((parsed (url-generic-parse-url uri))
         (type (url-type parsed))
         (directory (file-name-directory (url-filename parsed))))
    (and (string-equal type "file"))))

(provide 'esync)
;;; esync.el ends here

