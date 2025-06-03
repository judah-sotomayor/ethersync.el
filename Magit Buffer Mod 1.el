;;;  Reuben Umana
;;;  Magit Buffer Window Modificaiton


(defcustom magit-display-buffer-function #'magit-display-buffer-traditional

  "The function used to display a Magit buffer. All Magit buffers (buffers whose major-modes derive from `magit-mode') are displayed using `magit-display-buffer', which in turn uses the function specified here."

  :package-version '(magit . "2.3.0")
  :group 'magit-buffers
  :type `(radio (function-item ,#'magit-display-buffer-traditional)
		(function-item ,#'magit-display-buffer-same-window-except-diff-v1)
		(function-item ,#'magit-display-buffer-fullframe-status-v1)
		(function-item ,#'magit-display-buffer-fullframe-status-topleft-v1)
		(function-item ,#'magit-display-buffer-fullcolumn-most-v1)
		(function-item ,#'display-buffer)
		(function :tag "Function")))



;;; ----------------------------------------------------------------------------


;;; TRANSIENT NOTES
;;;
;;; Important
;;;
;;; Given the terminology seciton of the Transient-Showcase guide:
;;; (transient-define-prefix magit-dispatch ()
;;; would be a prefix, and the following list
