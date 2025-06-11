;;; Magit Buffer Mod 1.el --- Trying to define my own transient -*- lexical-binding: t; -*-
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



(transient-define-prefix my/doom-config-helper()
  "Navigate the configs"
  ["Transient and dwim commands"
   ;; → bound in magit-mode-map or magit-section-mode-map
   ;; ↓ bound below
   [("R" "Reload Doom Config"          doom/reload)]]
    ;;; a
   ;;; ("b" "Branch"         magit-branch)
   ;;; ("B" "Bisect"         magit-bisect)
   ;;; ("c" "Commit"         magit-commit)
