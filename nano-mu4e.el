;;; nano-mu4e.el --- NANO mu4e -*- lexical-binding: t -*-

;; Copyright (C) 2025 Nicolas P. Rougier
;;
;; Author: Nicolas P. Rougier <Nicolas.Rougier@inria.fr>
;; Homepage: https://github.com/rougier/nano-mu4e
;; Keywords: mail
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (mu4e "1.12"))

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; nano-mu4e is an opinionated headers view for mu4e where threads are
;; clearly separated.

;; Usage example:
;;
;; (require 'nano-mu4e)
;; (nano-mu4e-mode)

;;; NEWS:
;;
;; Version  0.1.0
;; - First public version

;;; Code:
(require 'mu4e)

(defgroup nano nil
  "N Λ N O"
  :group 'convenience)

(defgroup nano-mu4e nil
  "N Λ N O Mu4e"
  :group 'nano)

(defcustom nano-mu4e-style 'compact
  "One of simple regular, boxed, or compact

Simple:

[L] Thread subject 1                                           TAG-1 TAG-2 [15]
    Initial sender                                                    Yesterday
    [13 hidden messages]                                                    ...
    Recipient 1                                                  Today at 10:21 
    ┊ New message content can be displayed inside the header view.
    Recipient 2                                                  Today at 11:07 

[P] Thread subject 2                                                  TAG-3 [1]
    Initial sender                                               Today at 10:32


Regular:

───────────────────────────────────────────────────────────────────────────────
[L] Thread subject 1                                           TAG-1 TAG-2 [15]
    Initial sender                                                    Yesterday
    [13 hidden messages]                                                    ...
    Recipient 1                                                  Today at 10:21 
    ┊ New message content can be displayed inside the header view.
    Recipient 2                                                  Today at 11:07 
───────────────────────────────────────────────────────────────────────────────
[P] Thread subject 2                                                  TAG-3 [1]
    Initial sender                                               Today at 10:32
───────────────────────────────────────────────────────────────────────────────

Compact:

┌─────────────────────────────────────────────────────────────────────────────┐
│ [L] Thread subject 1                                       TAG-1 TAG-2 [15] │
│     Initial sender                                                Yesterday │
│     [13 hidden messages]                                                ... │
│     Recipient 1                                              Today at 10:21 │
│     ┊ New message content can be displayed inside the header view.          │
│     Recipient 2                                              Today at 11:07 │
├─────────────────────────────────────────────────────────────────────────────┤
│ [P] Thread subject 2                                              TAG-3 [1] │
│     Initial sender                                           Today at 10:32 │
└─────────────────────────────────────────────────────────────────────────────┘


Boxed:

┌─────────────────────────────────────────────────────────────────────────────┐
│ [L] Thread subject 1                                       TAG-1 TAG-2 [15] │
│     Initial sender                                                Yesterday │
│     [13 hidden messages]                                                ... │
│     Recipient 1                                              Today at 10:21 │
│     ┊ New message content can be displayed inside the header view.          │
│     Recipient 2                                              Today at 11:07 │
└─────────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────────┐
│ [P] Thread subject 2                                              TAG-3 [1] │
│     Initial sender                                           Today at 10:32 │
└─────────────────────────────────────────────────────────────────────────────┘
"
  :group 'nano-mu4e
  :type '(choice (const :tag "Simple" simple)
                 (const :tag "Regular" regular)
                 (const :tag "Compact" compact)
                 (const :tag "Boxed" boxed)))

(defcustom nano-mu4e-msg-preview-func nil ;; #'nano-mu4e-msg-preview-p
  "Function pointer to decide whether to preview content of a message"
  :group 'nano-mu4e
  :type 'func)

(defface nano-mu4e-border-face
  `((t :foreground ,(face-foreground 'default t 'default)))
  "Face for thread borders")

(defface nano-mu4e-preview-face
  `((t :foreground ,(face-foreground 'shadow t 'default)))
  "Face for message preview")

(defcustom nano-mu4e-symbols
  '((github     . ("[!]" . " "))
    (list       . ("[=]" . " "))
    (personal   . ("[P]" . " "))
    (root       . ("[+]" . " "))    
    (unread     . ("[U]" . " "))
    (flagged    . ("[F]" . " "))
    (new        . ("[N]" . "󰝧 "))
    (draft      . ("[D]" . " "))
    (signed     . ("[S]" . " "))
    (encrypted  . ("[E]" . " "))
    (sent       . ("[O]" . " "))
    (archived   . ("[R]" . " "))
    (mark       . ("(M)" . " "))
    (unmark     . ("(m)" . " "))    
    (attachment . ("[A]" . " "))
    (tag        . (""    . " ")))
  "Symbols to use for various message flags.
The fancy version of symbols relies on NERD font v3.0 (oct collection)."
  :group 'nano-mu4e
  :type '(alist :key-type (symbol :tag "Symbol")
                :value-type (cons (string :tag "ASCII")
                                  (string :tag "UNICODE"))))

;; Set mu4e-marks with NERD font v3.0 (oct collection)
(setf (plist-get (alist-get 'refile mu4e-marks) :char)  '("(R)" . " ")
      (plist-get (alist-get 'move mu4e-marks) :char)    '("(M)" . " ")
      (plist-get (alist-get 'tag mu4e-marks) :char)     '("(T)" . " ")
      (plist-get (alist-get 'action mu4e-marks) :char)  '("(A)" . " ")
      (plist-get (alist-get 'delete mu4e-marks) :char)  '("(D)" . " ")
      (plist-get (alist-get 'flag mu4e-marks) :char)    '("(F)" . " ")
      (plist-get (alist-get 'unflag mu4e-marks) :char)  '("(F)" . " ")
      (plist-get (alist-get 'read mu4e-marks) :char)    '("(!)" . " ")
      (plist-get (alist-get 'unread mu4e-marks) :char)  '("(!)" . " ")
      (plist-get (alist-get 'trash mu4e-marks) :char)   '("(x)" . " ")
      (plist-get (alist-get 'untrash mu4e-marks) :char) '("(x)" . " "))


(defun nano-mu4e-justify (left &optional right left-edge right-edge use-space)
  "Return a justified string with LEFT on left, RIGHT on right, prepending
LEFT-EDGE on the left and appending RIGHT-EDGE on theright. Justification can
be done with a display property or spaces depending on USE-SPACE."
  
  (let* ((width (window-width))
         (has-border (and mu4e-search-threads
                      (memq nano-mu4e-style '(boxed compact))))
         (left-edge (or left-edge (if has-border "│ " "")))
         (right-edge (or right-edge (if has-border " │" "")))
         (left (concat (propertize left-edge 'face 'nano-mu4e-border-face)
                       (if (stringp left)
                           left
                         (mapconcat #'identity left ""))))
         (right (concat (if (stringp right)
                            right
                          (mapconcat #'identity right ""))
                        (propertize right-edge 'face 'nano-mu4e-border-face)))
         (left (truncate-string-to-width left (- width (length right) 2) nil nil "…"))
         (padding (if use-space
                      (make-string (- (window-width) (length left) (length right) 1) ? )
                    (propertize " " 'display
                                `(space :align-to (- right ,(length right) 1))))))
    (concat left padding right)))

(defun nano-mu4e-fill (text &optional width prefix suffix) 
  "Refill TEXT to given WIDTH (characters) using PREFIX for each line."
  
  (with-temp-buffer
    (let* ((suffix (or suffix ""))
           (prefix (or prefix ""))
           (fill-column (or width (- (window-width) 1 (length prefix)))))
      (insert text)
      (fill-paragraph)

      (concat
       prefix
       (string-replace "\n"
                       (concat (propertize " " 'display `(space :align-to (- right 2)))
                               suffix (propertize " " 'display (concat "\n" prefix)))
                       (buffer-substring (point-min) (point-max)))
       (propertize " " 'display `(space :align-to (- right 2)))
       suffix))))


(defun nano-mu4e-make-button (text search help)
  "Create a clickable button displaying TEXT and HELP.
When clicked, a new SEARCH is initiated."

  (let* ((keymap (define-keymap
                   "<mouse-2>" #'push-button
                   "<follow-link>" 'mouse-face
                   "<mode-line> <mouse-2>" #'push-button
                   "<header-line> <mouse-2>" #'push-button)))
    (propertize text
                'pointer 'hand
                'mouse-face `link
                'help-echo help
                'button t
                'follow-link t
                'category t
                'button-data search
                'keymap keymap
                'action #'mu4e-search)))

(defun nano-mu4e-msg-from (msg)
  "Get MSG sender as a propertized string."

  (let* ((from (car (mu4e-message-field msg :from)))
         (from-email (or (mu4e-contact-email from)
                         "<no-email>"))
         (from-name (or (mu4e-contact-name from)
                        (mu4e-contact-email from)
                        "<no name>"))
         (from-name (propertize from-name
                                'unread (nano-mu4e-msg-is-unread msg)
                                'root (nano-mu4e-msg-is-thread-root msg)
                                'from t)))
    (nano-mu4e-make-button from-name
                           (format "from:%s" from-email)
                           (format "Search mails from %s" from-name))))

(defun nano-mu4e-date-is-yesterday (date)
  "Return t if DATE is yesterday."
  
  (let* ((today (current-time))
         (yesterday (time-subtract today (days-to-time 1)))
         (date-day (format-time-string "%Y-%m-%d" date))
         (yesterday-day (format-time-string "%Y-%m-%d" yesterday)))
    (string= date-day yesterday-day)))

(defun nano-mu4e-date-is-today (date)
  "Return t if DATE is today."
  
  (let ((date-str (format-time-string "%Y-%m-%d" date))
        (today-str (format-time-string "%Y-%m-%d" (current-time))))
    (string= date-str today-str)))

(defun nano-mu4e-date-is-recent (date)
  "Return t if DATE is less than 5 minutes ago."

  (let ((delta (float-time (time-subtract (current-time) date))))
    (< delta (* 5 60))))

(defun nano-mu4e-date-is-this-week (date)
  "Return t if DATE is in the same ISO week as today."
  
  (let ((week (format-time-string "%V" date))  ;; ISO week number
        (year (format-time-string "%G" date))  ;; ISO week-based year
        (current-week (format-time-string "%V" (current-time)))
        (current-year (format-time-string "%G" (current-time))))
    (and (string= week current-week)
         (string= year current-year))))

(defun nano-mu4e-date-is-this-month (date)
  "Return t if DATE is in the current month."
  
  (let ((date-month (format-time-string "%Y-%m" date))
        (current-month (format-time-string "%Y-%m" (current-time))))
    (string= date-month current-month)))

(defun nano-mu4e-msg-date (msg)
  "Get MSG date as a string."

  ;; We want a minimal size (20 characters) for date because we'll use
  ;; this field to display mark target when necessary
  (format "%20s"
          (let* ((date (mu4e-message-field msg :date)))
            (propertize
             (cond ((nano-mu4e-date-is-recent date)
                    "Now")

                   ((nano-mu4e-date-is-today date)
                    (nano-mu4e-make-button
                     (format-time-string "Today at %H:%M" date)
                     (format-time-string "date:today..now")
                     (format-time-string "Search mails from today")))

                   ((nano-mu4e-date-is-yesterday date)
                    (nano-mu4e-make-button
                     (format-time-string "Yesterday at %H:%M" date)
                     (format-time-string "date:2d..today and not date:today..now")
                     (format-time-string "Search mails from yesterday")))

                   ;; How do make a search for this week ?
                   ((nano-mu4e-date-is-this-week date)
                    (nano-mu4e-make-button
                     (format-time-string "%A at %H:%M" date)
                     (format-time-string "date:7d..now")
                     (format-time-string "Search mails for last seven days")))
                   
                   (t
                    (concat
                     (nano-mu4e-make-button
                      (format-time-string "%B " date)
                      (format-time-string "date:%Y-%m" date)
                      (format-time-string "Search mails from %B %Y" date))
                     (nano-mu4e-make-button
                      (format-time-string "%d, " date)
                      (format-time-string "date:%Y-%m-%d" date)
                      (format-time-string "Search mails from %B %d, %Y" date))
                     (nano-mu4e-make-button
                      (format-time-string "%Y" date)
                      (format-time-string "date:%Y" date)
                      (format-time-string "Search mails from %Y" date)))))
             'date t))))

(defun nano-mu4e-make-tag (tag)
  "Make a clickable TAG button"
  (nano-mu4e-make-button tag
                         (format "tag:%s" tag)
                         (format "Search for tag %s" tag)))
  
(defun nano-mu4e-msg-tags (msg)
  "Get MSG tags as a propertized string"

  (let* ((tags (mu4e-message-field msg :tags))
         (symbol (nano-mu4e-symbol 'tag)))
    (if (> (length tags) 0)
        (propertize (concat symbol
                            (mapconcat #'nano-mu4e-make-tag tags (concat " " symbol)))
                    'tags t)
    "")))

(defun nano-mu4e-msg-subject (msg)
  "Get MSG subject as a propertized string"

  (let* ((subject (mu4e-message-field msg :subject)))
    (propertize subject 'subject t)))

(defun nano-mu4e-msg-docid (msg)
  "Get MSG docid as a string"
  
  (plist-get msg :docid))

(defun nano-mu4e-msg-has-attach (msg)
  "Return whether MSG has attachment"
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'attach flags)))

(defun nano-mu4e-msg-is-list (msg)
  "Return whether MSG is part of a list."

  (let* ((flags (plist-get msg :flags)))
    (memq 'list flags)))

(defun nano-mu4e-msg-is-sent (msg)
  "Return whether MSG is sent."

  (let* ((maildir (mu4e-message-field msg :maildir)))
    (string-search "sent" maildir)))

(defun nano-mu4e-msg-is-archived (msg)
  "Return whether MSG is archived."

  (let* ((maildir (mu4e-message-field msg :maildir)))
    (string-search "archive" maildir)))

(defun nano-mu4e-msg-is-draft (msg)
  "Return whether MSG is a draft."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'draft flags)))

(defun nano-mu4e-msg-is-unread (msg)
  "Return whether MSG is unread."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'unread flags)))

(defun nano-mu4e-msg-is-new (msg)
  "Return whether MSG is new."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'new flags)))

(defun nano-mu4e-msg-is-signed (msg)
  "Return whether MSG is signed."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'signed flags)))

(defun nano-mu4e-msg-is-encrypted (msg)
  "Return whether MSG is encrypted."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'encrypted flags)))

(defun nano-mu4e-msg-is-personal (msg)
  "Return whether MSG is personal."
  
  (let* ((flags (plist-get msg :flags)))
    (memq 'personal flags)))

(defun nano-mu4e-msg-is-flagged (msg)
  "Return whether MSG is flagged."

  (let* ((flags (plist-get msg :flags)))
    (memq 'flagged flags)))

(defun nano-mu4e-msg-is-related (msg)
  "Return whether MSG is related."
  
  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :related)))

(defun nano-mu4e-msg-is-first (msg)
  "Return whether MSG is first in list."

  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :is-first)))

(defun nano-mu4e-msg-is-last (msg)
  "Return whether MSG is last in list."

  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :is-last)))

(defun nano-mu4e-thread-fold-info (count unread)
  "Information to display when a thread is folded."

  (let ((text (propertize (format "[%d hidden messages%s]" count
                                  (if (> unread 0) (format ", %d unread" unread) ""))
                          'face 'error))
        (ellipsis (propertize "•••" 'face 'error)))
    (concat (nano-mu4e-justify (list "   " text)
                               (list ellipsis)
                               nil nil t) "\n")))
   
(defun nano-mu4e-msg-is-thread-root (msg)
  "Return whether MSG is thread root."

  (let* ((meta (plist-get msg :meta))
         (orphan (plist-get meta :orphan))
         (first-child (plist-get meta :first-child)))
    (or (plist-get meta :root) (and orphan first-child))))

(defun nano-mu4e-msg-is-thread-last (msg)
  "Return whether MSG is last message in thread."

  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :thread-is-last)))

(defun nano-mu4e-thread-count (msg)
  "Return thread message count. MSG must be thread root."

  (when (nano-mu4e-msg-is-thread-root msg)
    (let* ((meta (plist-get msg :meta)))
      (plist-get meta :thread-count))))

(defun nano-mu4e-thread-unread-count (msg)
  "Return thread unread count. MSG must be thread root."

  (when (nano-mu4e-msg-is-thread-root msg)
    (let* ((meta (plist-get msg :meta)))
      (plist-get meta :thread-unread-count))))

(defun nano-mu4e-thread-unread-first (msg)
  "Return thread first unread docid. MSG must be thread root."

  (unless (nano-mu4e-msg-is-thread-root msg)
    (error (message "MSG must be thread root")))
  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :thread-unread-first)))

(defun nano-mu4e-thread-unread-last (msg)
  "Return thread last unread docid. MSG must be thread root."

  (unless (nano-mu4e-msg-is-thread-root msg)
    (error (message "MSG must be thread root")))
  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :thread-unread-first)))

(defun nano-mu4e-thread-prefix (msg)
  "Return thread message prefix."

  ;; Could be probably simplified in order to try to avoid calling
  ;; mu4e~headers-thread-prefix which is internal
  (let* ((meta (plist-get msg :meta))
         (mu4e-headers-thread-root-prefix          '(""   . ""))
         (mu4e-headers-thread-first-child-prefix   '(""   . ""))
         (mu4e-headers-thread-child-prefix         '(""   . ""))
         (mu4e-headers-thread-last-child-prefix    '(""   . ""))
         (mu4e-headers-thread-connection-prefix    '(" │" . " │"))
         (mu4e-headers-thread-blank-prefix         '(""   . ""))
         (mu4e-headers-thread-orphan-prefix        '(""   . ""))
         (mu4e-headers-thread-single-orphan-prefix '(""   . ""))
         (mu4e-headers-thread-duplicate-prefix     '(""  . ""))
         (thread-prefix (mu4e~headers-thread-prefix meta)))
    thread-prefix))

(defun nano-mu4e--instrument (msglst)
  "This function adds information related to thread to each message of
MSGLST. Information is stored in each message or thread root message
depending on the nature of the information.

For every message, mark them with:

- message is first in message list (:is-first t)
- message is last in message list (:is-last t)
- message is the last in thread (:thread-is-last t)

For each thread root message, mark them with:

- thread root (:thread-is-root t)
- thread count (:thread-count #)
- thread unread count (:thread-unread-count #)
- thread unread first (:thread-unread-first docid)
- thread unread last (:thread-unread-last docid)
"
  
  (let ((prev-msg nil)
        (thread-count 0)
        (thread-root nil)
        (thread-unread-count 0)
        (thread-unread-first nil)
        (thread-unread-last nil))
    (dolist (msg msglst)      
      (let* ((meta (plist-get msg :meta))
             (flags (plist-get msg :flags))
             (orphan (plist-get meta :orphan))
             (first-child (plist-get meta :first-child))
             (is-root (or (plist-get meta :root) (and orphan first-child)))
             (is-unread (memq 'unread flags)))      
        (when is-root
          ;; Update thread root information
          (when thread-root
            (let ((meta (plist-get thread-root :meta)))
              (plist-put meta :thread-count thread-count)
              (plist-put meta :thread-unread-count thread-unread-count)
              (plist-put meta :thread-unread-first thread-unread-first)
              (plist-put meta :thread-unread-last thread-unread-last)))
          
          ;; Mark previous message as last in thread
          (when prev-msg
            (plist-put (plist-get prev-msg :meta) :thread-is-last t))

          ;; Mark new root
          (plist-put (plist-get msg :meta) :thread-is-root t)

          ;; Reset information
          (setq thread-root msg
                thread-count 0
                thread-unread-count 0
                thread-unread-first nil
                thread-unread-last nil))
        
        (setq thread-count (1+ thread-count))
        (when is-unread
          (setq thread-unread-count (1+ thread-unread-count))
          (unless thread-unread-first
            (setq thread-unread-first (plist-get msg :docid)))
          (setq thread-unread-last (plist-get msg :docid)))
        
        (setq prev-msg msg)))

    ;; Update thread root information
    (when thread-root
      (let ((meta (plist-get thread-root :meta)))
        (plist-put meta :thread-count thread-count)
        (plist-put meta :thread-unread-count thread-unread-count)
        (plist-put meta :thread-unread-first thread-unread-first)
        (plist-put meta :thread-unread-last thread-unread-last)))

    ;; Mark previous message as last in thread
    (when prev-msg
      (plist-put (plist-get prev-msg :meta) :thread-is-last t))

    ;; Mark last message
    (plist-put (plist-get (car (last msglst)) :meta) :is-last t)

    ;; Mark first message
    (plist-put (plist-get (car msglst) :meta) :is-first t)))

(defun nano-mu4e-msg-preview-p (msg)
  "Return t if message is new, and not from a list or GitHub."

  (let* ((new (nano-mu4e-msg-is-new msg))
         (from (mu4e-contact-email (car (mu4e-message-field msg :from))))
         (from-github (string= from "notifications@github.com"))
         (from-list (nano-mu4e-msg-is-list msg)))
    (and new (not from-github) (not from-list))))
  
(defun nano-mu4e-msg-preview (&optional msg size)
  "Extract answer from MSG , limiting it to SIZE characters"

  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (size (or size 256))
         (filename (mu4e-message-readable-path msg)))

    ;; (with-current-buffer (get-buffer-create (format "file-%s" filename))
    ;;  (insert-file-contents-literally filename))
      
    (with-temp-buffer
      (insert-file-contents-literally filename)
      (let* ((handles (mm-dissect-buffer t))
                (handle (if (eq (type-of (car handles)) 'buffer)
                            handles
                          (or (mm-find-part-by-type (cdr handles) "text/plain" nil t)
                              (mm-find-part-by-type (cdr handles) "text/html" nil t))))
                (media-type (mm-handle-media-type handle))
                (type       (mm-handle-type handle))
                (charset    (mail-content-type-get type 'charset))
                (buffer     (mm-handle-buffer handle))
                (content    (mm-get-part handle))
                (body       (cond ((string= media-type "text/plain")
                                   (with-temp-buffer
                                     (insert (mm-decode-string content charset))
                                     (nano-mu4e-preview--answer size)))
                                  ((string= media-type "text/html")
                                   (with-temp-buffer
                                     (insert (mm-decode-string content charset))
                                     (shr-render-region (point-min) (point-max))
                                     (nano-mu4e-preview--answer)))
                                  (t "No message body found"))))
          body))))

(defun nano-mu4e-preview--answer (&optional size)
  "Return actual answer in current buffer, limiting it to SIZE characters."

  (interactive)
  (let* ((size (or size 256))
         (greetings '("Hello" "Hi" "Dear"
                      "Bonjour" "Coucou" "Salut"
                      "Chers" "Cher" "Chère" "Très chers"))
         (greetings-re (concat
                        "^[\t ]*\\("
                        (mapconcat #'identity greetings "\\|")
                        "\\)")))
    ;; Go to message body
    (message-goto-body)
    ;; Go to greetings (if any)
    (re-search-forward greetings-re nil t)

    ;; We should skip citations here
    (while (and (not (eobp))       ; not at end of buffer
                (looking-at "^>")) ; line starts with '>'
      (forward-line 1))

    ;; Go to first sentence starting with a letter
    (re-search-forward "^[A-Za-z]+" nil t)
    (beginning-of-line)
    (let* ((answer (buffer-substring-no-properties
                    (point) (min (+ (point) size) (point-max))))
           (answer (string-trim-left answer))
           (answer (replace-regexp-in-string "\n" " " answer))
           (answer (replace-regexp-in-string "  " " " answer)))
      answer)))

(defun nano-mu4e-thread-top (msg)
  "Delimits a thread MSG at the top.
It depends on the nano-mu4e-style."

  (propertize
   (let ((first (nano-mu4e-msg-is-first msg)))
     (cond ((eq nano-mu4e-style 'boxed)
            (concat "┌" (make-string (- (window-width) 3) ?─) "┐" "\n"))
           
           ((eq nano-mu4e-style 'compact)
            (if first 
                (concat "┌" (make-string (- (window-width) 3) ?─) "┐" "\n")
              ""))
           
           ((and first (eq nano-mu4e-style 'regular))
            (concat "   " (make-string (- (window-width) 4) ?─) "\n"))
           (t "")))
   'face 'nano-mu4e-border-face))

(defun nano-mu4e-thread-bottom (msg)
  "Delimits a thread MSG at the bottom.
It depends on the nano-mu4e-style."
  
  (propertize
   (let ((last (nano-mu4e-msg-is-last msg)))
     (cond ((eq nano-mu4e-style 'compact)
            (if last
                (concat "└" (make-string (- (window-width) 3) ?─) "┘" "\n")
              (concat "├" (make-string (- (window-width) 3) ?─) "┤" "\n")))

           ((eq nano-mu4e-style 'boxed)
            (concat "└" (make-string (- (window-width) 3) ?─) "┘" "\n"))

            ((eq nano-mu4e-style 'regular)
             (concat "   " (make-string (- (window-width) 4) ?─) "\n"))
            (t
             "\n")))
  'face 'nano-mu4e-border-face))


(defun nano-mu4e-subject-line (msg &optional index)
  "Return a one line describing a thread topic. MSG must be thread root."
  
  (let* ((count (nano-mu4e-thread-count msg))
         (unread-count (nano-mu4e-thread-unread-count msg))
         (subject (propertize (nano-mu4e-msg-subject msg)
                              'face (if (> unread-count 0)
                                        '(mu4e-title-face bold)
                                      'mu4e-title-face)))
         (tags (propertize (nano-mu4e-msg-tags msg)
                           'face '(org-tag bold)))
         (count (when count
                    (propertize (format "[%d]" count)
                                'face (if (> unread-count 0)
                                          'bold
                                        'default)))))
    (propertize
     (concat
       (nano-mu4e-justify (list (nano-mu4e-subject-symbol msg) " "  subject)
;;      (nano-mu4e-justify (list (format "%-2d " index) subject)
                         (list tags " " count))
      "\n")
     ;; 'msg msg
     )))


(defun nano-mu4e-symbol (symbol)
  "Return the given SYMBOL"

  (cdr (alist-get symbol nano-mu4e-symbols)))

(defun nano-mu4e-subject-symbol (msg)
  "Return a symbol to be displayed at the front of a thread subject. It
relies on NERD font."
  
    (let* ((flags (plist-get msg :flags))
           (is-list (memq 'list flags))
           (list (mu4e-message-field msg :list))
           (is-personal (memq 'personal flags))
           (from (mu4e-contact-email (car (mu4e-message-field msg :from))))
           (from-github (string= from "notifications@github.com")))
      ;; Order is important
      (cond (from-github
             (nano-mu4e-make-button
              (propertize (nano-mu4e-symbol 'github)   'face 'default)
              "from:notifications@github.com"
              "Search mails from GitHub"))
            (is-list
             (nano-mu4e-make-button
              (propertize (nano-mu4e-symbol 'list)     'face 'default)
              (format "list:%s" list)
              (format "Search mail from/to %s" list)))
             (is-personal
              (nano-mu4e-make-button
               (propertize (nano-mu4e-symbol 'personal) 'face 'default)
               "flag:personal"
               "Search all mails flagged as personal"))
            (t
             (propertize (nano-mu4e-symbol 'root)     'face 'default)))))

(defun nano-mu4e-message-symbol (msg)
  "Return a symbol to be displayed at the front of a message.  It
relies on the NERD font."
  
  ;; Order is important
  (cond ((nano-mu4e-msg-is-new msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'new) 'face 'nano-critical)
          "flag:new AND NOT flag:trashed"
          "Search for new mails"))
        
        ((nano-mu4e-msg-is-unread msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'unread) 'face 'default)
          "flag:unread AND NOT flag:trashed"
          "Search for unread mails"))
        
        ((nano-mu4e-msg-is-flagged msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'flagged) 'face 'mu4e-flagged-face)
          "flag:flagged"
          "Search for flagged mails"))
        
        ((nano-mu4e-msg-is-draft msg)
         (nano-mu4e-make-button
         (propertize (nano-mu4e-symbol 'draft) 'face 'mu4e-draft-face)
         "flag:draft"
         "Search for draft mails"))
        
        ((nano-mu4e-msg-is-encrypted msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'encrypted) 'face 'shadow)
          "flag:encrypted"
          "Search for encrypted mails"))
        
        ((nano-mu4e-msg-is-signed msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'signed) 'face 'shadow)
          "flag:signed"
          "Search for encrypted mails"))
        
        ;; ((nano-mu4e-msg-is-sent msg)
        ;;   (propertize (nano-mu4e-symbol 'sent) 'face 'shadow))
        ;; ((nano-mu4e-msg-is-archived msg)
        ;;   (propertize (nano-mu4e-symbol 'archived) 'face 'shadow))
        (t
         (propertize "  " 'face 'nano-default))))

(defun nano-mu4e-message-line (msg)
  "Return a propertized description of MSG.
This is suitable for displaying in the header view."

  (let* ((width (window-width))
         (face  (cond ((nano-mu4e-msg-is-unread msg)          'bold)
                      ;; ((nano-mu4e-msg-is-thread-root msg)  'default)
                      ;; ((nano-mu4e-msg-is-archived msg)     'shadow)
                      ((nano-mu4e-msg-is-sent msg)            'shadow)
                      ((nano-mu4e-msg-is-related  msg)        'shadow)
                      ((and (nano-mu4e-msg-is-unread msg)
                            (nano-mu4e-msg-is-archived msg)) '(shadow bold))
                      ((nano-mu4e-msg-is-sent msg)           'shadow)
                      (t                                     'default))))
    (propertize
     (concat
      (mu4e~headers-docid-cookie (nano-mu4e-msg-docid msg))             
      (nano-mu4e-justify
       (list ;; "  "
             (propertize (nano-mu4e-message-symbol msg) 'nano-mu4e-mark t)
             (propertize (nano-mu4e-thread-prefix msg) 'face 'shadow)
             " "
             (propertize (nano-mu4e-msg-from msg) 'face face)
             (when (nano-mu4e-msg-has-attach msg)
               (propertize "  " 'face 'shadow))
             (when (not mu4e-search-threads)
               (concat " — "
                       (propertize (nano-mu4e-msg-subject msg) 'face face))))
       (list
        (propertize (nano-mu4e-msg-date msg) 'face face
                                             'nano-mu4e-date t)))
      (when (and nano-mu4e-msg-preview-func
                 (funcall nano-mu4e-msg-preview-func msg))
         (propertize
          (concat (propertize " " 'display "\n" 'face 'nano-mu4e-preview-face)
                  (if (and mu4e-search-threads
                           (memq nano-mu4e-style '(boxed compact)))
                      (nano-mu4e-fill
                          (propertize (nano-mu4e-msg-preview msg) 'face 'nano-mu4e-preview-face)
                          (- width 12)
                          (concat (propertize "│    " 'face 'nano-mu4e-border-face)
                                  (propertize "┊ "    'face 'nano-mu4e-preview-face))
                          (propertize "│"  'face 'nano-mu4e-border-face))
                    (nano-mu4e-fill
                          (propertize (nano-mu4e-msg-preview msg)  'face 'nano-mu4e-preview-face)
                          (- width 10)
                          (propertize "   ┊ " 'face 'nano-mu4e-preview-face)
                          "")))
          ;;          'face '(:weight regular :inherit (nano-default italic))
          )))
      'msg msg)))

(defvar-local nano-mu4e--message-list nil
  "Full message list that is populated during the append handler call.")

(defun nano-mu4e-append-handler (msglst)
  "This handler differs from the default one since it first collects all
messages in a single list that is stored locally in the headers
buffer. This is necessary to get the whole message list to insrument
it. The actual writing to the headers buffer will be done in the found
handler."
    
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (if (and (eq (point-min) (point-max))
               (not nano-mu4e--message-list))
          (setq-local nano-mu4e--message-list msglst)
        (setq-local nano-mu4e--message-list
                    (append nano-mu4e--message-list msglst))))))

(defun nano-mu4e--append (msglst)
  "Populate the headers buffer with MSGLIST"
  
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (message "MU4E thread mode: %s" 
      (setq nano-mu4e-mode t)
      (setq-local hl-line-range-function
                  #'nano-mu4e-headers-hl-line-range)
      (save-excursion
        (let ((inhibit-read-only t))
          (goto-char (point-max))

          ;;(seq-map-indexed
          (setq index 1)
          (seq-do
           (lambda (msg)
             ;; Subject line
             (when (and mu4e-search-threads
                        (nano-mu4e-msg-is-thread-root msg))
               (insert (nano-mu4e-thread-top msg))
               (insert (nano-mu4e-subject-line msg index))
               (setq index (1+ index)))
             ;; Message line
             (insert (nano-mu4e-message-line msg))
             (insert "\n")
             ;; Thread delimitation
             (when (and mu4e-search-threads
                        (nano-mu4e-msg-is-thread-last msg))
               (insert (nano-mu4e-thread-bottom msg))))
           msglst)))))))

(defun nano-mu4e-found-handler (&optional count)
  "This function first writes all the messages in the headers buffer and
then call the default found handler."

  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (let ((count (or count (length nano-mu4e--message-list))))
        (nano-mu4e--instrument nano-mu4e--message-list)
        (nano-mu4e--append nano-mu4e--message-list)
        (mu4e~headers-found-handler count)
        (goto-char (point-min))
        (if (and (boundp 'nano-mu4e--docid) nano-mu4e--docid)
            (unless (nano-mu4e-goto-msg nano-mu4e--docid)
              (goto-char (point-min))
              (nano-mu4e-next-msg))
          (nano-mu4e-next-msg))     
        (when hl-line-mode
          (hl-line-highlight))))))

(defun nano-mu4e-mark-as-new (&optional msg)
  "Mark as MSG as new"
  
  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (docid (plist-get msg :docid)))
    (when docid
      (mu4e--server-move docid nil "N"))))

(defun nano-mu4e-check-cursor ()
  "Check if cursor is beyond messages and move point to the last msg if
this is the case."

  (interactive)
  (when (eobp)
    (nano-mu4e-prev-msg)))

(defun nano-mu4e-cycle ()
  "Cycle display style"
  
  (interactive)
  (let* ((styles '(#1=simple regular compact boxed #1#)))
    (setq nano-mu4e-style
          (cadr (member nano-mu4e-style styles)))
    (nano-mu4e-refresh)))

(defun nano-mu4e-refresh ()
  "Refresh headers view"
  
  (interactive)
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (when-let* ((inhibit-read-only t)
                  (msg (mu4e-message-at-point))
                  (docid (nano-mu4e-msg-docid msg)))
        ;; Set our own range function for highlight
        (setq-local hl-line-range-function
                    #'nano-mu4e-headers-hl-line-range)
        (erase-buffer)
        (nano-mu4e-found-handler (length nano-mu4e--message-list))
        (nano-mu4e-goto-msg docid)))))

(defun nano-mu4e-goto-msg (docid)
  "Move point to the message with given docid."
  
  (interactive)
  (goto-char (point-min))
  (let ((found))
    (catch 'found
      (while (nano-mu4e-next-msg)
        (when (eq (nano-mu4e-msg-docid (mu4e-message-at-point)) docid)
          (setq found t)
          (throw 'found docid))))
    found))

(defun nano-mu4e-next-msg (&optional _n)
  "Move point to the next message ('from properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-forward 'from t t t)))
    (goto-char (prop-match-beginning prop-match))
    (if (get-char-property (point) 'mu4e-thread-folded)
        (nano-mu4e-next-msg)
      (point))))

(defun nano-mu4e-next-unread-msg (&optional _n)
  "Move point to the next message ('from properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-forward 'from t t t)))
    (goto-char (prop-match-beginning prop-match))
    (if (or (not (nano-mu4e-msg-is-unread (mu4e-message-at-point)))
            (get-char-property (point) 'mu4e-thread-folded))
        (nano-mu4e-next-unread-msg)
      (point))))

(defun nano-mu4e-prev-msg (&optional _n)
  "Move point to the previous message ('from properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-backward 'from t t t)))
    (goto-char (prop-match-beginning prop-match))
    (if (get-char-property (point) 'mu4e-thread-folded)
        (nano-mu4e-prev-msg)
      (point))))

(defun nano-mu4e-prev-unread-msg (&optional _n)
  "Move point to the previous message ('from properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-backward 'from t t t)))
    (goto-char (prop-match-beginning prop-match))
    (if (or (not (nano-mu4e-msg-is-unread (mu4e-message-at-point)))
            (get-char-property (point) 'mu4e-thread-folded))
        (nano-mu4e-prev-unread-msg)
      (point))))

(defun nano-mu4e-next-thread ()
  "Move point to the next thread ('root properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-forward 'root t t t)))
    (goto-char (prop-match-beginning prop-match))))

(defun nano-mu4e-prev-thread ()
  "Move point to the previous thread ('root properties)"
  
  (interactive)
  (when-let ((prop-match (text-property-search-backward 'root t t t)))
    (goto-char (prop-match-beginning prop-match))))

(defun nano-mu4e-mark-execute-all (&optional _no-confirmation)
  "Make sure we're on a msg after execution."

  (interactive)
  (mu4e-mark-execute-all t)
  ;; (mu4e-search-rerun)
  )

(defun nano-mu4e-fold-toggle ()
  "Fold current thread and make sure point is on a thread"

  (interactive)
  (mu4e-thread-fold-toggle)
  (when (get-char-property (point) 'mu4e-thread-folded)
    (nano-mu4e-prev-thread)))

(defun nano-mu4e-fold-toggle-all ()
  "Fold all threads and make sure point is on a thread"

  (interactive)
  (mu4e-thread-fold-toggle-all)
  (when (get-char-property (point) 'mu4e-thread-folded)
    (nano-mu4e-prev-thread)))

(defun nano-mu4e-headers-hl-line-range ()
  (save-excursion
    (when-let ((match (text-property-search-forward 'from t t nil)))
      (cons (prop-match-beginning match)
            (prop-match-end match)))))


;; This adds our custom view inside mu4e
(add-to-list 'mu4e-header-info-custom
             '(:nano-mu4e . (:name "NΛNO"
                                   :shortname "NΛNO mu4e"
                                   :function nano-mu4e-message-line)))

(defun nano-mu4e-search-rerun (&rest _args)
  "Save the current docid"
  
  (let* ((msg (mu4e-message-at-point t))
         (docid (nano-mu4e-msg-docid msg)))
    (setq nano-mu4e--docid docid)))

(defun nano-mu4e-nop (&rest _args)
  "Do nothing")

(defun nano-mu4e-headers-mark-and-next (mark)
  "Set MARK on the message at point or in region.
 Then, move to the next message."
   (interactive)
   (when (mu4e-thread-message-folded-p)
     (mu4e-warn "Cannot mark folded messages"))
   (mu4e-mark-set mark)
   (nano-mu4e-next-msg))

(defun nano-mu4e-mark (target &optional mark)
  "Add MARK and TARGET to the display of message at point."
  
  (save-excursion
    (beginning-of-line)
    (when-let* ((match (text-property-search-forward 'nano-mu4e-mark t t nil))
                (overlay (make-overlay (prop-match-beginning match)
                                       (prop-match-end match))))
      (overlay-put overlay 'display (propertize (or mark (nano-mu4e-symbol 'mark))
                                                'face 'nano-critical))
      (overlay-put overlay 'mu4e-mark t)
      (overlay-put overlay 'evaporate t))
    
    (beginning-of-line)
    (when-let* ((match (text-property-search-forward 'nano-mu4e-date t t nil))
                (overlay (make-overlay (prop-match-beginning match)
                                       (prop-match-end match))))
      (overlay-put overlay 'display (propertize (format "%20s" target)
                                                'face '(error bold)))
      (overlay-put overlay 'mu4e-mark t)
      (overlay-put overlay 'evaporate t))))

(defun nano-mu4e-mark-at-point (mark target)
  "Mark message at point with given MARK and TARGET"
  
  (interactive)
  (let* ((msg (mu4e-message-at-point))
         (docid (mu4e-message-field msg :docid))
         (markdesc (cdr (or (assq mark mu4e-marks)
                            (mu4e-error "Invalid mark %S" mark))))
         (get-markkar (lambda (char)
                        (if (listp char)
                            (if mu4e-use-fancy-chars (cdr char) (car char))
                          char)))
         (markkar (funcall get-markkar (plist-get markdesc :char)))
         (target (mu4e--mark-get-dyn-target mark target))
         (show-fct (plist-get markdesc :show-target))
         (shown-target (if show-fct
                           (funcall show-fct target)
                         (if target (format "%S" target)))))
         
    (unless docid (mu4e-warn "No message on this line"))
    (unless (eq major-mode 'mu4e-headers-mode)
      (mu4e-error "Not in headers-mode"))
    (save-excursion
      (remhash docid mu4e--mark-map)
      (remove-overlays (line-beginning-position) (line-end-position)
                       'mu4e-mark t)
      (unless (eql mark 'unmark)
        (puthash docid (cons mark target) mu4e--mark-map)
        (nano-mu4e-mark shown-target markkar)
        docid))))


(defun nano-mu4e-mode-on ()
  (setq mu4e-headers-append-func #'nano-mu4e-append-handler
        mu4e-found-func #'nano-mu4e-found-handler
        mu4e-headers-fields '((:nano-mu4e))
        mu4e--mark-fringe "")
  (advice-add #'mu4e-thread-fold-info
              :override #'nano-mu4e-thread-fold-info)
  (advice-add #'mu4e-search-rerun
              :before #'nano-mu4e-search-rerun)
  (advice-add #'mu4e-search-bookmark
              :before #'nano-mu4e-search-rerun)
  (advice-add #'mu4e~headers-mark
              :override #'nano-mu4e-nop)
  (advice-add #'mu4e-mark-at-point
              :override #'nano-mu4e-mark-at-point)
  (advice-add #'mu4e-headers-mark-and-next
              :override #'nano-mu4e-headers-mark-and-next)
  (setq nano-mu4e-mode 1))
  
(defun nano-mu4e-mode-off ()
  (setq mu4e-headers-append-func #'mu4e~headers-append-handler
        mu4e-found-func #'mu4e~headers-found-handler
        mu4e-headers-fields '((:human-date . 12)
                              (:flags . 6)
                              (:mailing-list . 10)
                              (:from . 22)
                              (:subject))
        mu4e--mark-fringe "")
  (advice-remove #'mu4e-thread-fold-info
                 #'nano-mu4e-thread-fold-info)
  (advice-remove #'mu4e-search-rerun
                 #'nano-mu4e-search-rerun)
  (advice-remove #'mu4e-search-bookmark
                 #'nano-mu4e-search-rerun)
  (advice-remove #'mu4e~headers-mark
                 #'nano-mu4e-nop)
  (advice-remove #'mu4e-mark-at-point
                 #'nano-mu4e-mark-at-point)
  (advice-remove #'mu4e-headers-mark-and-next
                 #'nano-mu4e-headers-mark-and-next)
  (mu4e-search-rerun)
  (setq nano-mu4e-mode -1))


;;;###autoload
(define-minor-mode nano-mu4e-mode
  "NΛNO mu4e headers mode"
  :init-value nil
  :keymap (list (cons (kbd "<up>")       #'nano-mu4e-prev-msg)
                (cons (kbd "<down>")     #'nano-mu4e-next-msg)
                (cons (kbd "S-<up>")     #'nano-mu4e-prev-thread)
                (cons (kbd "S-<down>")   #'nano-mnnu4e-next-thread)
                (cons (kbd "<SPC>")      #'nano-mu4e-mark-as-new)
                (cons (kbd "<mouse-1>")  #'nano-mu4e-check-cursor)
                (cons (kbd "p")          #'nano-mu4e-prev-unread-msg)
                (cons (kbd "n")          #'nano-mu4e-next-unread-msg)
                (cons (kbd "x")          #'nano-mu4e-mark-execute-all)
                (cons (kbd "<TAB>")      #'nano-mu4e-fold-toggle)
                (cons (kbd "<backtab>")  #'nano-mu4e-fold-toggle-all))

  (if (derived-mode-p '(mu4e-headers-mode))
      (if nano-mu4e-mode
          (nano-mu4e-mode-on)
        (nano-mu4e-mode-off))
    (error "nano-mu4e mode can only be used when in mu4e-headers mode")))
   
(provide 'nano-mu4e)
;;; nano-mu4e.el ends here

