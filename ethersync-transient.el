;;; ethersync-transient.el --- Transient UI for Ethersync -*- lexical-binding: t; -*-
;;;  Reuben Umana
;;;  Magit Buffer Window Modificaiton


;;;   Common Functions

(defun esync--unix-socket ()
  "Specify the unix socket that ethersync should use."
  (interactive)
  (message "Opening text input field..."))

(defun esync--debug ()
  "Debug the Ethersync session."
  (interactive)
  (message "Passing debug argument..."))

;;; Ether-Share Functions
(defun esync--start-daemon ()
  "Start the ethersync daemon."
  (interactive)
  (message "Starting the Daemon..."))

(defun esync--specify-directory ()
  "Specify the directory you would like to share."
  (interactive)
  (message "Running find in the minibuffer..."))

(transient-define-prefix ether-share(name)
  "Host an Ethersync session."
  ["Available Commands"
   ("s" "Start the daemon"          esync--start-daemon)
    ("d" "Specify a directory"      esync--specify-directory)
    ("n" "Specify Unix Socket Name" esync--unix-socket)
    ("v" "Debug the daemon" esync--debug)
    ])

;;; Ether-Join Functions
(defun esync--join-session ()
  "Join an Ethersync session."
  (interactive)
  (message "Opening text input field..."))

(transient-define-prefix ether-join(name)
  "Join an Ethersync session."
  ["Available Commands"
   ("j" "Join a session"          esync--join-session)
    ("n" "Specify Unix Socket Name" esync--unix-socket)
    ("v" "Debug the connection" esync--debug)
    ])

;;; Ether-Status Function
(defun ether-status ()
  "Loading details about the session."
  (interactive)
  (message "Status..."))


;;; Ethersync Dispatcher
(transient-define-prefix ethersync-dispatch()
  "Invoke an Ethersync command from a list of available commands."
  [" -- Ethersync for Emacs --\n"
   ("s" "Share"          ether-share)
    ("j" "Join"           ether-join)
    ("c" "Status"         ether-status)
    ])

(ethersync-dispatch)

