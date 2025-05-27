;;; ethersync.el --- Ethersync for Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Judah Sotomayor
;;
;; Author: Judah Sotomayor <Judah.Sotomayor@pm.me>
;; Maintainer: Judah Sotomayor <Judah.Sotomayor@pm.me>
;; Created: May 24, 2025
;; Modified: May 27, 2025
;; Version: 0.0.1
;; Keywords: collaboration
;; Homepage: https://github.com/judah-sotomayor/ethersync.el
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;
;;
;;; Code:

(require 'cl-lib)
(require 'jsonrpc)

(defvar esync--directories '()
  "Association list of directories and ethersync processes: (DIRECTORY . PROCESS).")

(defcustom esync-ethersync-executable
  (executable-find "ethersync")
  "The path to the ethersync executable."
  :type 'string
  :group 'magit)

(defun esync--version-string ()
  "Get version of ethersync binary in `default-directory'."
  (with-temp-buffer
    (call-process esync-ethersync-executable nil t nil "--version")
    (buffer-string)))

(defun esync-insertion-filter (proc string)
  "Filter out ansi color codes in output STRING from PROC."
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (let ((moving (= (point) (process-mark proc))))
        (save-excursion
          ;; Insert the text, advancing the process marker.
          (goto-char (process-mark proc))
          (insert (ansi-color-filter-apply string))
          (set-marker (process-mark proc) (point)))
        (if moving (goto-char (process-mark proc)))))))

(defun esync--open-current-project ()
  "Manage the ethersync daemon for the current project."
  (if (not (assoc default-directory esync--directories) )
      (push `(,default-directory . ,(esync--start-daemon)) esync--directories)))

(defun esync--close-current-project ()
  "End the ethersync daemon for the current process."
  (let ((current-proc (alist-get default-directory esync--directories)))
    (if current-proc (progn
                       (kill-process current-proc)
                       (setq esync--directories (assoc-delete-all default-directory esync--directories))))))

(defun esync--start-daemon (&optional peer port debug)
  "Start an ethersync daemon in `default-directory'.
Optionally, connect to PEER.
Optionally, listen on PORT.
If DEBUG is non-nil, start ethersync in debug mode."
  (let* ((stdout (generate-new-buffer "*Ethersync Daemon*"))
         (stderr (generate-new-buffer "*Ethersync Daemon stderr*"))
         (peer-flag (if peer (format "--peer %s" peer)))
         (port-flag (if port (format "--port %s" port)))
         (debug-flag (if debug "--debug")))
    (make-process
     :name default-directory
     :command (flatten-tree `(,esync-ethersync-executable "daemon"
                              ,peer-flag ,port-flag ,debug-flag))
     :connection-type 'pipe
     :coding 'utf-8-emacs-unix
     :buffer stdout
     :stderr stderr
     :filter #'esync-insertion-filter)))

(provide 'ethersync)
;;; ethersync.el ends here
