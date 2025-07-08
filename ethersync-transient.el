;;; ethersync-transient.el --- Transient UI for Ethersync -*- lexical-binding: t; -*-
;;;  Reuben Umana
;;;  Magit Buffer Window Modificaiton
;;;
;;; Doom / Emacs Configuration Helper
;;; Prefix: my/doom-helper-transient
;;;
;;; Suffixes / Infixes:
;;;
;;;     Open (infix)
;;;     - init.el
;;;     - config.el
;;;     - packages.el
;;;
;;;     Reload Doom config (doom/reload) (Suffix)
;;;
;;;     Open messages buffer (Suffix)
;;;
;;;     Open Doom documentation (Infix)
;;;
;;;
;;;
;;;
;;;
;;;



;;; (transient-define-prefix doom-config-helper()
;;;   "Navigate the configs"
;;;   ["Navigate the configs with these commands"
;;;    [("R" "Reload Doom Config"          doom/reload)]]
;;;     ;;; a
;;;    ;;; ("b" "Branch"         magit-branch)
;;;    ;;; ("B" "Bisect"         magit-bisect)
;;;    ;;; ("c" "Commit"         magit-commit)


;;;
(get-buffer-create "test_buffer")


;;; (display-buffer "test_buffer"
;;;                 transient-display-buffer-action)

;;; (display-buffer BUFFER-OR-NAME &optional ACTION FRAME)
(display-buffer "test_buffer")


(with-current-buffer "test_buffer"
  (insert "Hi"))

(transient-define-prefix ethersync-dispatch()
  "Invoke an Ethersync command from a list of available commands."
  ["Available Commands"
   [("s" "Share"          ether-share)
    ("j" "Join"           ether-join)
    ("c" "Status"         ether-status)
    ]])



;;; (transient-define-prefix test_buffer_menu ()
;;;   "Defining a new test transient."
;;;
;;;   [("t" "test        'print-buffer)]
;;;
;;;   )
