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
  (or  (executable-find "ethersync") "ethersync")
  "The path to the ethersync executable."
  :type 'string
  :group 'esync)

(defcustom esync-support-evil t
  "Whether to support evil-mode or not."
  :type 'string
  :group 'esync)

(defvar-local esync--last-point nil)
(defvar-local esync--last-mark nil)
(defvar-local esync--cached-workspace nil
  "A cached reference to the current esync workspace.")

(defvar esync--workspaces-by-project (make-hash-table :test #'equal)
  "A hash-table of all the esync workspaces, keyed to the containing project path.")

(cl-defstruct esync--workspace
  (root nil)
  (daemon nil)
  (connection nil)
  (ewoc nil)
  (buffers nil)
  (status nil)
  (cursors nil))

;;; * Hooks
(defvar esync--buffer-hooks-alist
  '((post-command-hook . esync--signal-cursor)
    (kill-buffer-hook . esync--close-current-buffer)))

(defun esync--install-buffer-hooks ()
  "Install esync hooks in the current buffer."
  (-map
   (-lambda ((hook . function))
     (add-hook hook function nil t))
   esync--buffer-hooks-alist))

(defun esync--uninstall-buffer-hooks ()
  "Install the hooks for a buffer."
  (-map
   (-lambda ((hook . function))
     (remove-hook hook function t))
   esync--buffer-hooks-alist))

(define-minor-mode esync-mode
  "Mode for collaborative buffers."
  :lighter " ESYNC"
  (if esync-mode
      (progn
        (unless (esync--current-workspace)
          (puthash (esync--current-project-root)
                   (esync--create-buffer-workspace)
                   esync--workspaces-by-project))
        (esync--install-buffer-hooks))

    (esync--uninstall-buffer-hooks)
    (setq esync--cached-workspace nil
          esync--last-mark nil
          esync--last-point nil)))

(defun esync--current-workspace ()
  "Return the default workspace for the current buffer."
  (or esync--cached-workspace
      (setq esync--cached-workspace
            (gethash (esync--current-project-root) esync--workspaces-by-project))))

(defun esync--maybe-activate-esync-mode ()
  "Maybe activate `esync-mode'.

Do not activate if it is already activated, if the file is not a project file,
 or if there is no open esync workspace.
If activated, signal open and send the cursor to the current connection."
  (unless esync-mode
    (when (and buffer-file-name (esync--current-workspace))
      (esync-mode)
      (esync--open-current-buffer))))
(add-hook 'after-change-major-mode-hook #'esync--maybe-activate-esync-mode)

;;; * Ethersync Client
;;; ** Process Management
(defun esync--start-connection (workspace)
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
     :buffer stdout
     :stderr stderr
     :filter #'esync--connection-filter
     )))

(cl-defmethod esync-process-kill ((proc process))
  "Kill PROC if still running."
  (when (process-live-p proc)
    (kill-process proc)))

(defun esync--on-connection-shutdown (connection)
  "Handle CONNECTION shutdown."
  (warn "Client Shutdown!!!"))


(defun esync--connect-to-daemon (workspace)
  "Connect WORKSPACE to an active daemon using a client process."
  (let* ((spread (lambda (fn)
                   (lambda (connection method params)
                     (apply fn workspace connection method (append params nil)))))
         (connection (make-instance
                      jsonrpc-process-connection
                      :process (esync--start-connection
                                workspace)
                      :on-shutdown #'esync--on-connection-shutdown
                      :notification-dispatcher (funcall spread
                                                        #'esync--handle-notification))))
    (setf (esync--workspace-connection workspace) connection)))

;;; *** Logging
(defun esync--create-log (&rest args)
  "Create a log using ARGS."
  (message (pp args)))

;;; ** Editor-to-Client Signals (JSONRPC Requests)


(defun esync--signal-open-file (connection file)
  "Open FILE in CONNECTION.
FILE must be in the lsp uri format: \"file:///path/to/file\""
  (jsonrpc-async-request connection :open `(:uri ,file)
                         :success-fn (esync--create-log "Opened file" file)))

(defun esync--signal-close-file (connection file)
  "Close FILE in CONNECTION.
FILE must be in the lsp uri format: \"file:///path/to/file\""
  (jsonrpc-async-request connection :close `(:uri ,file)
                         :success-fn (esync--create-log "Closed file" file)))

(defun esync--signal-cursor ()
  "Check for point or mark movement and notify the daemon."
  (if-let* ((ranges (esync--local-cursor-ranges))
            (connection (esync--workspace-connection (esync--current-workspace)))
            (file (esync--url-for-buffer)))
      (jsonrpc-notify connection
                      :cursor `(:uri ,file :ranges ,ranges))))

;;; ** Notification Handlers
(cl-defgeneric esync--handle-notification (workspace connection method &rest params)
  "Handle ethersync client CONNECTION's METHOD notification with PARAMS.
  WORKSPACE is passed through for specific data needs.")

(cl-defmethod esync--handle-notification
  (_workspace _connection method &key &allow-other-keys)
  "Handle unknown METHOD."
  (message (format "Bad request! %s" method)))

(cl-defmethod esync--handle-notification
  (workspace connection (method (eql cursor)) &key name ranges uri userid)
  "Handle METHOD :cursor from CONNECTION in WORKSPACE.
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
        (esync--set-overlays userid ranges name)
        (esync--register-cursor workspace name ranges file userid)
        ))))

(defun esync--clear-overlays (userid)
  "Remove overlays in current buffer for USERID."
  (dolist (o (car (overlay-lists)))
    (when (string-equal (overlay-get o 'esync-user-id) userid)
      (delete-overlay o))))

(defun esync--set-overlays (userid ranges name)
  "Create an overlay in current buffer over RANGES for USERID."
  (-let* ((r (seq-elt ranges 0))
          ((&plist :start ) r)
          ((&plist :line start-l) start)
          (start-position (esync--position-from-ethersync-position start-l 0))
          (end-position (esync--with-position start-l 0 (end-of-line) (point)))
          (new-overlay (make-overlay start-position end-position nil t nil)))

    (overlay-put new-overlay 'category 'esync-name)
    (overlay-put new-overlay 'esync-user-id userid)
    (overlay-put new-overlay 'after-string
                 (propertize (concat " " name) 'face
                             `(:foreground ,(esync--get-user-color userid)))))
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
      (overlay-put new-overlay 'face `(:background ,color))
      )))

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



;;; *** Position and Coordinates Control
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

(defun esync--cursor-position-line-char ()
  "Return current cursor position line and column."
  (without-restriction
    (let ((line (- (string-to-number (format-mode-line "%l")) 1))
          (char (current-column)))
      (list :line line :character char))))

(defun esync--local-cursor-ranges ()
  "Return the ranges for the current cursor and mark.
  If these ranges are unchanged since the last invocation, return nil."
  (if (and esync-support-evil evil-visual-block-overlays)
      (save-excursion
        (cl-map 'vector (lambda (o)
                          (list :start (progn
                                         (goto-char (overlay-start o))
                                         (esync--cursor-position-line-char))
                                :end (progn
                                       (goto-char (overlay-end o))
                                       (esync--cursor-position-line-char))))
                evil-visual-block-overlays))
    ;; else
    (let ((point (point))
          (mark (when (use-region-p) (mark))))
      (unless (and (eq point esync--last-point)
                   (eq mark esync--last-mark))
        (setq esync--last-point point
              esync--last-mark mark)
        (vector (list :start (esync--cursor-position-line-char)
                      :end
                      (if (null mark)
                          (esync--cursor-position-line-char)
                        (save-mark-and-excursion
                          (goto-char mark)
                          (esync--cursor-position-line-char)))))))))

;;; * Data Validation


;;; * File Handling
;;; Functions in here relate to the management of buffers and files.
;;; For example, creating a URL for a buffer.
(defun esync--url-for-buffer ()
  "Return the URL for the current buffer, as a string.

If the current buffer is not a file, return nil."
  (let ((name (buffer-file-name)))
    (if name (concat "file://" name))))


(defun esync--valid-url-p (url)
  "Determine if URL is valid for the current workspace.

To be valid, the URL must point to a file in the current workspace.
The file URL points to need not exist.
The current workspace's directory will of course exist."
  (let* ((parsed (url-generic-parse-url url))
         (type (url-type parsed))
         (file (url-filename parsed)))
    (and (string= type "file")
         (length> file 0)
         (file-in-directory-p
          file
          (esync--workspace-root esync--cached-workspace)))))

(defun esync--open-current-buffer ()
  "signal open for the current file."
  (let ((file (esync--url-for-buffer)))
    (esync--signal-open-file
     (esync--workspace-connection esync--cached-workspace)
     file)))

(defun esync--close-current-buffer ()
  "Signal close for the current file."
  (let ((file (esync--url-for-buffer)))
    (esync--signal-close-file
     (esync--workspace-connection esync--cached-workspace)
     file)))

(defun esync--create-buffer-workspace ()
  "Initialize a workspace in the current buffer.
Connect the workspace to the daemon."
  (let ((root (file-name-directory (buffer-file-name))))
    (prog1 (setq esync--cached-workspace (make-esync--workspace :root root))
      (esync--connect-to-daemon esync--cached-workspace))))

(defun esync--current-project-root ()
  "Return the current project's root."
  (project-root (project-current)))
;;; * ENDING

(provide 'esync)
;;; esync.el ends here
