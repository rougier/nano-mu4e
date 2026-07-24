;;; nano-mu4e.el --- NANO mu4e -*- lexical-binding: t -*-

;; Copyright (C) 2025-2026 Nicolas P. Rougier
;;
;; Author: Nicolas P. Rougier <Nicolas.Rougier@inria.fr>
;; Homepage: https://github.com/rougier/nano-mu4e
;; Keywords: mail
;; Version: 1.0.0
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
;; clearly separated using boxes or blank lines

;; Usage example:
;;
;; (require 'nano-mu4e)
;; (nano-mu4e-mode)

;;; NEWS:
;;
;; Version  1.0.0
;; - Revamped layout with left margin
;; - Better synchronization with headers view
;; - Added tags style
;; - Folding status is now memorized when rerun or refresh search
;; - Fix several bugs with recursive navigation
;; - Fix bug with deprecated variable mu4e-threads-mode
;; - Rendering optimization

;; Version  0.1.0
;; - First public version

;;; Code:
(require 'mu4e)

;;; Customization groups
;;; ------------------------------------------------------------------------

(defgroup nano nil
  "N Λ N O"
  :group 'convenience)

(defgroup nano-mu4e nil
  "N Λ N O Mu4e"
  :group 'nano)

(defgroup nano-mu4e-faces nil
  "N Λ N O Mu4e faces"
  :group 'nano-mu4e)


;;; Faces
;;; ------------------------------------------------------------------------

(defface nano-mu4e-border
  `((t :inherit default))
  "Face for thread borders."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-preview
  `((t :inherit (italic)))
  "Face for message preview"
    :group 'nano-mu4e-faces)

(defface nano-mu4e-todo
  `((t :inherit (error bold)
       :inverse-video nil))
  "Face for TODO tag."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-tag-active
  `((t :inherit (link bold)
       :inverse-video nil))
  "Face for tags when active."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-tag-inactive
  `((t :inherit (shadow bold)
       :inverse-video nil))
  "Face for tags when inactive."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-title-active
  `((t :inherit (bold)))
  "Face for thread title when active."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-title-inactive
  `((t :inherit (shadow bold)))
  "Face for thread title when active."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-match
  `((t :inherit (bold)))
  "Face for matched emails"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-new
  `((t :inherit (link bold)))
  "Face for new messages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-unread
  `((t :inherit (link)))
  "Face for unread messages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-related
  `((t :inherit (shadow)))
  "Face for related messages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-draft
  `((t :inherit (shadow)))
  "Face for drafts"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-flagged
  `((t :inherit (link)))
  "Face for flagges messages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-archived
  `((t :inherit (shadow)))
  "Face for flagges messages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-sent
  `((t :inherit (shadow italic)))
  "Face for sent mesages"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-system
  `((t :inherit (error bold)))
  "Face for system information."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-gutter-head-active
  `((t :inherit (bold)
       :inverse-video t))
  "Face for gutter head when there is at least one unred mail in thread."
  :group 'nano-mu4e-faces)

(defface nano-mu4e-gutter-head-inactive
  `((t :inherit (shadow)
       :inverse-video t))
  "Face for gutter head"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-gutter-match
  `((t :inherit (shadow widget-field)))
  "Face for gutter head"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-gutter-body
  `((t :inherit (shadow widget-field)))
  "Face for gutter"
  :group 'nano-mu4e-faces)

(defface nano-mu4e-gutter-mark
  `((t :inherit (error bold)
       :inverse-video t))
  "Face for gutter mark"
  :group 'nano-mu4e-faces)


;;; Customization variables
;;; ------------------------------------------------------------------------

(defcustom nano-mu4e-tag-style 'round
  "One of regular, square or round."
  :group 'nano-mu4e
  :type '(choice (const :tag "Regular"                  regular)
                 (const :tag "Square"                   square)
                 (const :tag "Round (NERD font needed)" round)))

  
(defcustom nano-mu4e-view-style 'regular
  "One of simple regular, boxed, or compact

Simple:

[15] Thread subject 1                                                TAG-1 TAG-2
     Initial sender                                                    Yesterday
     --------------------------- 13 hidden messages ----------------------------
     Recipient 1                                                  Today at 10:21 
     ┊ New message content can be displayed inside the header view.
     Recipient 2                                                  Today at 11:07 

[ 1] Thread subject 2                                                      TAG-3
     Initial sender                                               Today at 10:32


Regular:

───────────────────────────────────────────────────────────────────────────────
[15] Thread subject 1                                               TAG-1 TAG-2
     Initial sender                                                   Yesterday
     --------------------------- 13 hidden messages ---------------------------
     Recipient 1                                                 Today at 10:21 
     ┊ New message content can be displayed inside the header view.
     Recipient 2                                                 Today at 11:07 
───────────────────────────────────────────────────────────────────────────────
[ 1] Thread subject 2                                                     TAG-3
     Initial sender                                              Today at 10:32
───────────────────────────────────────────────────────────────────────────────

Compact:

┌─────────────────────────────────────────────────────────────────────────────┐
│ [15] Thread subject 1                                           TAG-1 TAG-2 │
│      Initial sender                                               Yesterday │
│      ------------------------- 13 hidden messages ------------------------- │
│      Recipient 1                                             Today at 10:21 │
│      ┊ New message content can be displayed inside the header view.         │
│      Recipient 2                                             Today at 11:07 │
├─────────────────────────────────────────────────────────────────────────────┤
│ [P] Thread subject 2                                              TAG-3 [1] │
│     Initial sender                                           Today at 10:32 │
└─────────────────────────────────────────────────────────────────────────────┘


Boxed:

┌─────────────────────────────────────────────────────────────────────────────┐
│ [15] Thread subject 1                                           TAG-1 TAG-2 │
│     Initial sender                                                Yesterday │
│     ------------------------- 13 hidden messages -------------------------- │
│     Recipient 1                                              Today at 10:21 │
│     ┊ New message content can be displayed inside the header view.          │
│     Recipient 2                                              Today at 11:07 │
└─────────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────────┐
│ [ 1] Thread subject 2                                                 TAG-3 │
│      Initial sender                                          Today at 10:32 │
└─────────────────────────────────────────────────────────────────────────────┘
"
  :group 'nano-mu4e
  :type '(choice (const :tag "Simple"  simple)
                 (const :tag "Regular" regular)
                 (const :tag "Compact" compact)
                 (const :tag "Boxed"   boxed)))

(defcustom nano-mu4e-msg-preview nil
  "Whether to preview message."
  :group 'nano-mu4e
  :type 'boolean)

(defcustom nano-mu4e-msg-preview-func nil ;; #'nano-mu4e-msg-preview-p
  "Function pointer to decide whether to preview content of a message"
  :group 'nano-mu4e
  :type 'func)

(defcustom nano-mu4e-symbols
  '((github     . ("[G]" . " "))
    (list       . ("[L]" . " "))
    (personal   . ("[P]" . " "))
    (root       . ("[+]" . " "))    
    (unread     . (" U" . " "))
    (match      . ("[*]" . " "))
    (trash      . ("[T]" . " "))
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
                                  (string :tag "NERD"))))

;;; String utilities
;;; ------------------------------------------------------------------------

(defun nano-mu4e-justify (left &optional right left-edge right-edge use-space)
  "Return a justified string with LEFT on left, RIGHT on right, prepending
LEFT-EDGE on the left and appending RIGHT-EDGE on theright. Justification can
be done with a display property or spaces depending on USE-SPACE."
  
  (let* ((width (window-width))
         (has-border (and mu4e-search-threads
                      (memq nano-mu4e-view-style '(boxed compact))))
         (left-edge (or left-edge (if has-border "│ " "")))
         (right-edge (or right-edge (if has-border " │" "")))
         (left (concat (propertize left-edge 'face 'nano-mu4e-border)
                       (if (stringp left)
                           left
                         (mapconcat #'identity left ""))))
         (right (concat (if (stringp right)
                            right
                          (mapconcat #'identity right ""))
                        (propertize right-edge 'face 'nano-mu4e-border)))
         (left (truncate-string-to-width left (- width (length right) 2) nil nil "…"))
         (padding (if use-space
                      (make-string (max 0 (- (window-width) (length left) (length right) 1) ? ))
                    (propertize " " 'display
                                `(space :align-to (- right ,(length right) 1))))))
    (concat left padding right)))

(defvar nano-mu4e--fill-buffer nil
  "Hidden scratch buffer reused by `nano-mu4e-fill'.
Avoids repeatedly creating and killing a temp buffer (via
`with-temp-buffer') for every previewed message.")

(defun nano-mu4e--fill-buffer ()
  "Return the live scratch buffer used by `nano-mu4e-fill', creating it if needed."
  (unless (buffer-live-p nano-mu4e--fill-buffer)
    (setq nano-mu4e--fill-buffer (generate-new-buffer " *nano-mu4e-fill*" t)))
  nano-mu4e--fill-buffer)

(defun nano-mu4e-fill (text &optional width prefix suffix) 
  "Refill TEXT to given WIDTH (characters) using PREFIX for each line."

  (with-current-buffer (nano-mu4e--fill-buffer)
    (erase-buffer)
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

(defvar nano-mu4e--button-keymap
  (define-keymap
    "<mouse-2>"               #'push-button
    "<mode-line> <mouse-2>"   #'push-button
    "<header-line> <mouse-2>" #'push-button)
  "Shared keymap for nano-mu4e buttons.")

(defun nano-mu4e-make-button (text search help &optional mouse-face)
  "Create a clickable button displaying TEXT and HELP.
When clicked, a new SEARCH is initiated."

    (propertize text
                'pointer 'hand
                'button t
                'follow-link t
                'category t
                'button-data search
                'keymap nano-mu4e--button-keymap
                'action #'mu4e-search))

(defconst nano-mu4e--emoji-regex
  (concat "["
          "\U0001f300-\U0001f9ff"
          "\U0001f1e0-\U0001f1ff"
          "\U00002000-\U00002bff"
          "\U0000fe00-\U0000fe0f"
          "]")
  "Regex matching decorative symbols, flags, and modern emojis.")

(defun nano-mu4e-sanitize-string (str)
  "Clean emojis from STR. Targets decorative symbols, flags, and modern emojis."
  (when (stringp str)
    (let* ((no-emojis (replace-regexp-in-string nano-mu4e--emoji-regex "" str))
           (cleaned (string-trim (replace-regexp-in-string "  +" " " no-emojis))))
      cleaned)))


;;; Message field accessors
;;; ------------------------------------------------------------------------

(defun nano-mu4e-msg-from (msg)
  "Get MSG sender as a propertized string."

  (let* ((from (car (mu4e-message-field msg :from)))
         (from-email (or (mu4e-contact-email from)
                         "<no-email>"))
         (from-name (or (mu4e-contact-name from)
                        (mu4e-contact-email from)
                        "<no name>"))
         (from-name (nano-mu4e-sanitize-string from-name))
         (from-name (propertize from-name
                                'unread (nano-mu4e-msg-is-unread msg)
                                'root (nano-mu4e-msg-is-thread-root msg)
                                'from t)))
    (nano-mu4e-make-button from-name
                           (format "from:%s" from-email)
                           (format "Search mails from %s" from-name))))

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


(defun nano-mu4e-make-tag (tag &optional style is-active is-todo)
  "Make a clickable TAG button using provided STYLE"

  (let* ((style (or style nano-mu4e-tag-style))
         (face (cond (is-todo   'nano-mu4e-todo)
                     (is-active 'nano-mu4e-tag-active)
                     (t         'nano-mu4e-tag-inactive)))
         (decorated-tag (cond
               ((eq style 'round)
                (concat (propertize "" 'face `(:inherit ,face))
                        (propertize tag 'face `(:inherit ,face :inverse-video t))
                        (propertize "" 'face `(:inherit ,face))))
               ((eq style 'square)
                (concat (propertize " " 'face `(:inherit ,face :inverse-video t))
                        (propertize tag 'face `(:inherit ,face :inverse-video t))
                        (propertize "▕" 'face `(:inherit ,face :inverse-video t))))
               (t
                (concat (propertize tag 'face `(:inherit ,face)))))))
      (nano-mu4e-make-button decorated-tag
                             (format "tag:%s" tag)
                             (format "Search for tag %s" tag)
                             '(:weight bold))))

(defun nano-mu4e-msg-tags (msg)
    "Return a string of tags from MSG."
    (let* ((unread-count (nano-mu4e-thread-unread-count msg))
           (tags-list (mu4e-message-field msg :tags))
           (tags-list (if (member "TODO" tags-list)
                          (append (remove "TODO" tags-list) '("TODO"))
                        tags-list))
           (style nano-mu4e-tag-style)
           (sep (cond ((eq style 'round)  " ")
                      ((eq style 'square) "")
                      (t                  ",")))
           (is-active (> unread-count 0))
           (face (if (> unread-count 0)
                     'nano-mu4e-tag-active
                   'nano-mu4e-tag-inactive)))
      (if (> (length tags-list) 0)
          (mapconcat
           (lambda (tag)
             (let ((is-todo (string= tag "TODO")))
               (nano-mu4e-make-tag tag style is-active is-todo)))
           tags-list (propertize sep 'face face))
         "")))

(defun nano-mu4e-msg-subject (msg)
  "Get MSG subject as a propertized string"

  (let* ((subject (mu4e-message-field msg :subject))
         (subject (if (string-empty-p subject)
                      "Empty subject"
                    subject)))
    (propertize subject 'subject t)))

(defun nano-mu4e-msg-docid (msg)
  "Get MSG docid as a string"
  
  (plist-get msg :docid))


;;; Message predicates
;;; ------------------------------------------------------------------------

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

(defun nano-mu4e-msg-is-trash (msg)
  "Return whether MSG is in a trash folder."
  
  (let* ((maildir (plist-get msg :maildir)))
    (string-match-p "trash" (downcase maildir))))

(defun nano-mu4e-msg-is-junk (msg)
  "Return whether MSG is in a trash folder."
  
  (let* ((maildir (plist-get msg :maildir)))
    (string-match-p "junk" (downcase maildir))))

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

(defun nano-mu4e-msg-from-github (msg)
  "Return whether MSG is a GitHub notification."
  (let ((from (mu4e-contact-email (car (mu4e-message-field msg :from)))))
    (string= from "notifications@github.com")))

(defun nano-mu4e-msg-has-todo (msg)
  "Return whether MSG has attachment"
  
  (let* ((tags (mu4e-message-field msg :tags)))
    (member "TODO" tags)))

;;; Date predicates
;;; ------------------------------------------------------------------------

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


;;; Thread predicates and instrumentation
;;; ------------------------------------------------------------------------

(defun nano-mu4e-thread-fold-info (count unread)
  "Return a string divider with COUNT hidden messages, spanning the window width."
  (let* ((window-width (window-width))
         (message (format " %d hidden messages " count))
         (msg-length (length message))
         (left-edge (if (memq nano-mu4e-view-style '(boxed compact))
                        (propertize "├" 'face 'nano-mu4e-border)
                      (concat (propertize " -- " 'face 'nano-mu4e-gutter-body)
                              " ")))
         (right-edge (if (memq nano-mu4e-view-style '(boxed compact))
                        (propertize "┤" 'face 'nano-mu4e-border)
                       (propertize "╴" 'face 'shadow)))
         (line-char "╴")
         (remaining (- window-width
                       1
                       (length left-edge)
                       msg-length
                       (length right-edge)))
         (half (/ remaining 2))
         (line-left (make-string half (string-to-char line-char)))
         (line-right (make-string (- remaining half) (string-to-char line-char))))
    (concat left-edge
            (propertize (concat line-left message line-right) 'face 'shadow)
            right-edge
             "\n")))
  
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
    (error "MSG must be thread root"))
  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :thread-unread-first)))

(defun nano-mu4e-thread-unread-last (msg)
  "Return thread last unread docid. MSG must be thread root."

  (unless (nano-mu4e-msg-is-thread-root msg)
    (error "MSG must be thread root"))
  (let* ((meta (plist-get msg :meta)))
    (plist-get meta :thread-unread-last)))

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
  
  (let ((total 0)
        (prev-msg nil)
        (thread-count 0)
        (thread-root nil)
        (thread-unread-count 0)
        (thread-unread-first nil)
        (thread-unread-last nil))
    (dolist (msg msglst)      
      (let* ((meta (plist-get msg :meta))
             (flags (plist-get msg :flags))
             (orphan (plist-get meta :orphan))
             (is-related (nano-mu4e-msg-is-related msg))
             (first-child (plist-get meta :first-child))
             (is-root (or (plist-get meta :root) (and orphan first-child)))
             (is-unread (memq 'unread flags)))

        (unless is-related (setq total (1+ total)))
        
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

    (setq-local nano-mu4e--last-query-count total)

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


;;; 10. Message preview
;;; ------------------------------------------------------------------------

(defun nano-mu4e-msg-preview-p (msg)
  "Return t if message is new, and not from a list or GitHub."

  (let* ((new (nano-mu4e-msg-is-new msg))
         (from (mu4e-contact-email (car (mu4e-message-field msg :from))))
         (from-github (string= from "notifications@github.com"))
         (from-list (nano-mu4e-msg-is-list msg)))
    (and new (not from-github) (not from-list))))


(defun nano-mu4e-msg-preview (&optional msg size)
  "Extract a short preview from MSG, limiting it to SIZE characters."
  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (size (or size 256))
         (filename (mu4e-message-readable-path msg)))
    (with-temp-buffer
      (insert-file-contents-literally filename)
      (let* ((handles (mm-dissect-buffer t)))
        (unwind-protect
            (when-let* ((handle (if (bufferp (car handles))
                                    handles
                                  (or (mm-find-part-by-type (cdr handles) "text/plain" nil t)
                                      (mm-find-part-by-type (cdr handles) "text/html" nil t))))
                        (media-type (and handle (mm-handle-media-type handle)))
                        (type       (and handle (mm-handle-type handle)))
                        (charset    (and type (mail-content-type-get type 'charset)))
                        (content    (and handle (mm-get-part handle))))
              (cond ((null handle) "No message body found")
                    ((string= media-type "text/plain")
                     (with-temp-buffer
                       (insert (mm-decode-string content charset))
                       (nano-mu4e-preview--process size)))
                    ((string= media-type "text/html")
                     (with-temp-buffer
                       (insert (mm-decode-string content charset))
                       (shr-render-region (point-min) (point-max))
                       (nano-mu4e-preview--process size)))
                    (t "No message body found")))
          (mm-destroy-parts handles))))))

(defconst nano-mu4e--preview-greetings-re
  (concat "^[\t ]*\\("
          (mapconcat #'identity
                     '("Hello" "Hi" "Dear"
                       "Bonjour" "Coucou" "Salut"
                       "Chers" "Cher" "Chère" "Très chers")
                     "\\|")
          "\\)")
  "Regex matching an initial greeting line to skip in message previews.")

(defconst nano-mu4e--preview-attribution-re
  "^[\t ]*\\(On .* wrote:\\|Le .* a écrit *:\\)[\t ]*$"
  "Regex matching \"On ... wrote:\" / \"Le ... a écrit :\" attribution lines.")

(defconst nano-mu4e--preview-quote-marker-re
  (concat "^[\t ]*\\("
          "-\\{2,\\} ?Mail original ?-\\{2,\\}"
          "\\|-\\{2,\\} ?Original Message ?-\\{2,\\}"
          "\\|-\\{2,\\} ?Message d'origine ?-\\{2,\\}"
          "\\|-\\{2,\\} ?Forwarded [Mm]essage ?-\\{2,\\}"
          "\\)")
  "Regex matching hard delimiters introducing a quoted original message.")

(defconst nano-mu4e--preview-signature-re "^-- ?$"
  "Regex matching a signature delimiter line.")

(defun nano-mu4e-preview--process (&optional size)
  "Return a cleaned preview of the body in the current buffer, limited to SIZE characters."
  (let* ((size (or size 256))
         (greetings-re nano-mu4e--preview-greetings-re)
         (attribution-re nano-mu4e--preview-attribution-re)
         (quote-marker-re nano-mu4e--preview-quote-marker-re)
         (signature-re nano-mu4e--preview-signature-re)
         lines)
    (goto-char (point-min))
    ;; Skip an initial greeting line, if present, so it doesn't clutter the preview
    (when (re-search-forward greetings-re nil t)
      (forward-line 1))
    ;; Walk the buffer line by line, dropping quotes/attributions/blank runs,
    ;; and stopping at a signature block, quote marker, or once we have enough content.
    (while (and (not (eobp))
                (< (length (mapconcat #'identity (reverse lines) " ")) size))
      (let ((line (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
        (cond
         ;; Signature or quote-marker delimiter: stop entirely
         ((or (string-match-p signature-re line)
              (string-match-p quote-marker-re line))
          (goto-char (point-max)))
         ;; Quoted line or reply attribution: skip
         ((or (string-match-p "^[\t ]*>" line)
              (string-match-p attribution-re line)))
         ;; Blank line: skip without adding
         ((string-match-p "^[\t ]*$" line))
         (t (push line lines))))
      (forward-line 1))
    (let* ((summary (mapconcat #'identity (reverse lines) " "))
           (summary (string-trim summary))
           (summary (replace-regexp-in-string "[ \t]+" " " summary)))
      (if (> (length summary) size)
          (concat (string-trim-right
                   (substring summary 0 (or (string-match " [^ ]*$" summary 0 size) size)))
                  "…")
        summary))))

;;; Rendering
;;; ------------------------------------------------------------------------

(defun nano-mu4e-thread-top (msg)
  "Delimits a thread MSG at the top.
It depends on the nano-mu4e-view-style."

  (let ((first (nano-mu4e-msg-is-first msg))
         (last (nano-mu4e-msg-is-last msg)))
    (concat
     (if first
         (concat 
          (propertize (format "SEARCH (n=%d):" nano-mu4e--last-query-count)
                      'face '(:inherit (nano-mu4e-system bold)
                                       :inverse-video nil))
          " "
          (propertize (format "\"%s\"" mu4e--search-last-query)
                      'face 'default)
          (if (memq nano-mu4e-view-style '(boxed compact))
              "\n"
            "\n\n")
       ""))
     (propertize
      (cond ((eq nano-mu4e-view-style 'boxed)
             (concat "┌" (make-string (- (window-width) 3) ?─) "┐" "\n"))
            ((eq nano-mu4e-view-style 'compact)
             (if first 
                 (concat "┌" (make-string (- (window-width) 3) ?─) "┐" "\n")
               ""))
            (t  ""))
     'face 'nano-mu4e-border))))

(defun nano-mu4e-thread-bottom (msg)
  "Delimits a thread MSG at the bottom.
It depends on the nano-mu4e-view-style."
  
  (propertize
   (let ((first (nano-mu4e-msg-is-first msg))
         (last (nano-mu4e-msg-is-last msg)))
     (cond ((eq nano-mu4e-view-style 'compact)
            (if last
                (concat "└" (make-string (- (window-width) 3) ?─) "┘" "\n")
              (concat "├" (make-string (- (window-width) 3) ?─) "┤" "\n")))

           ((eq nano-mu4e-view-style 'boxed)
            (concat "└" (make-string (- (window-width) 3) ?─) "┘" "\n"))

            ((eq nano-mu4e-view-style 'regular)
             (concat "" (make-string (- (window-width) 1) ?─) "\n"))
            (t
             "\n")))
  'face 'nano-mu4e-border))

(defun nano-mu4e-symbol (symbol)
  "Return the given SYMBOL"

  (cdr (alist-get symbol nano-mu4e-symbols)))

(defun nano-mu4e-subject-symbol (msg)
  "Return a symbol to be displayed at the front of a thread subject. It
relies on NERD font."
  (propertize (nano-mu4e-symbol 'root) 'face 'default))

(defun nano-mu4e-message-symbol (msg)
  "Return a symbol to be displayed at the front of a message.  It
relies on the NERD font."
  
  ;; Order is important
  (cond ((nano-mu4e-msg-is-new msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'unread) 'face 'nano-mu4e-new)
          "flag:new AND NOT flag:trashed"
          "Search for new mails"))
        
        ((nano-mu4e-msg-is-unread msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'unread) 'face 'nano-mu4e-unread)
          "flag:unread AND NOT flag:trashed"
          "Search for unread mails"))
        
        ((nano-mu4e-msg-is-flagged msg)
         (nano-mu4e-make-button
          (propertize (nano-mu4e-symbol 'flagged) 'face 'nano-mu4e-flagged)
          "flag:flagged"
          "Search for flagged mails"))
        
        ((nano-mu4e-msg-is-draft msg)
         (nano-mu4e-make-button
         (propertize (nano-mu4e-symbol 'draft) 'face 'nano-mu4e-draft)
         "flag:draft"
         "Search for draft mails"))
        
         ((nano-mu4e-msg-is-sent msg)
           (propertize (nano-mu4e-symbol 'sent) 'face 'nano-mu4e-sent))

         ((and (nano-mu4e-msg-is-archived msg)
               (not (nano-mu4e-msg-is-related msg)))
           (propertize (nano-mu4e-symbol 'archived) 'face 'default))

         ((nano-mu4e-msg-is-archived msg)
           (propertize (nano-mu4e-symbol 'archived) 'face 'nano-mu4e-archived))
        (t
         (propertize " " 'face 'default))))


(defun nano-mu4e-subject-line (msg &optional _index)
  "Return a one line describing a thread topic. MSG must be thread root."
  
  (let* ((count (nano-mu4e-thread-count msg))
         (unread-count (nano-mu4e-thread-unread-count msg))
         (has-unread (> unread-count 0))
         (has-todo (nano-mu4e-msg-has-todo msg))
         (is-related (nano-mu4e-msg-is-related msg))
         (from-github (nano-mu4e-msg-from-github msg))
         (is-list (nano-mu4e-msg-is-list msg))
         (is-personal (nano-mu4e-msg-is-personal msg))
         (face  (cond (has-unread 'nano-mu4e-title-active)
                      (is-related 'nano-mu4e-related)
                      (t          'nano-mu4e-title-inactive)))
         (subject (propertize (nano-mu4e-msg-subject msg)
                              'face face))
         (subject (nano-mu4e-sanitize-string subject))
         (subject (cond ((nano-mu4e-msg-is-junk msg) (concat "[SPAM] " subject))
                        ((nano-mu4e-msg-is-trash msg) (concat "[TRASH] " subject))
                        (t subject)))
         (prefix (cond (from-github
                        (propertize (format "%s " (nano-mu4e-symbol 'github))
                                    'face face))
                       (is-personal
                        (propertize (format "%s " (nano-mu4e-symbol 'personal))
                                    'face face))
                       (is-list
                        (propertize (format "%s " (nano-mu4e-symbol 'list))
                                    'face face))
                       (t "")))
         (tags (nano-mu4e-msg-tags msg))
         (face (cond (has-todo           'nano-mu4e-gutter-mark)
                     ((> unread-count 0) 'nano-mu4e-gutter-head-active)
                     (t                  'nano-mu4e-gutter-head-inactive)))
         (count (if (> count 99)
                    (propertize " ++ " 
                                'face face
                                'help-echo (format "%d mails in thread" count))
                  (propertize (format " %02d " count)
                              'face face))))
    (propertize
     (concat
      (nano-mu4e-justify (list count " " prefix subject)
                         (list tags))
       "\n"))))

(defun nano-mu4e-message-line (msg)
  "Return a propertized description of MSG.
This is suitable for displaying in the header view."

  (let* ((width (window-width))
         (is-root (nano-mu4e-msg-is-thread-root msg))
         (tags (unless is-root
                 (mapconcat #'identity (mu4e-message-field msg :tags) ",")))
         (face (cond ((nano-mu4e-msg-is-new msg)            'nano-mu4e-new)
                     ((nano-mu4e-msg-is-unread msg)         'nano-mu4e-unread)
                     ((not (nano-mu4e-msg-is-related msg))  'default)
                     ((nano-mu4e-msg-is-archived msg)       'nano-mu4e-archived)
                     ((nano-mu4e-msg-is-sent msg)           'nano-mu4e-sent)
                     ((nano-mu4e-msg-is-related  msg)       'nano-mu4e-related)
                     ((and (nano-mu4e-msg-is-unread msg)
                           (nano-mu4e-msg-is-archived msg)) '(nano-mu4e-unread
                                                              nano-mu4e-archived))
                     (t                                     'default))))
    (propertize
     (concat
      (mu4e~headers-docid-cookie (nano-mu4e-msg-docid msg))             
      (nano-mu4e-justify
       (list (if (nano-mu4e-msg-is-related  msg)
                 (propertize "    "
                             'face 'nano-mu4e-gutter-body
                             'nano-mu4e-mark t)
               (propertize (format " %s " (nano-mu4e-symbol 'match))
                           'face 'nano-mu4e-gutter-match
                           'nano-mu4e-mark t))
             (propertize (nano-mu4e-thread-prefix msg) 'face 'shadow)
             (propertize " " 'face face)
             (cond ((nano-mu4e-msg-is-encrypted msg)
                    (concat 
                      (nano-mu4e-make-button
                       (propertize (nano-mu4e-symbol 'encrypted) 'face 'shadow)
                       "flag:encrypted"
                       "Search for encrypted mails")
                      " "))
                   ((nano-mu4e-msg-is-signed msg)
                    (concat 
                     (nano-mu4e-make-button
                      (propertize (nano-mu4e-symbol 'signed) 'face 'shadow)
                      "flag:signed"
                      "Search for signed emails")
                     " "))

                   ((nano-mu4e-msg-is-sent msg)
                    (concat 
                     (nano-mu4e-make-button
                      (propertize (nano-mu4e-symbol 'sent) 'face 'shadow)
                      "flag:sent"
                      "Search for sent emails")
                     " ")))
             (propertize (nano-mu4e-msg-from msg) 'face face)
             (when (nano-mu4e-msg-has-attach msg)
               (propertize "  " 'face 'shadow))
             (when (not  mu4e-search-threads)
               (concat " — "
                       (propertize (nano-mu4e-msg-subject msg) 'face face)))
             (if (and (stringp tags) (length> tags 0) (not is-root))
                 (format " (%s)" tags)
               "")
             )
       (list
        (propertize (nano-mu4e-msg-date msg)  'face face
                                             'nano-mu4e-date t)
        " "
        (propertize (nano-mu4e-message-symbol msg) 'nano-mu4e-mark t)))
      
      (when (and nano-mu4e-msg-preview
                 (functionp nano-mu4e-msg-preview-func)
                 (funcall nano-mu4e-msg-preview-func msg))
        (when-let* ((preview (nano-mu4e-msg-preview msg))
                    ((stringp preview))
                    ((length> preview 0)))
            (propertize
             (concat (propertize " " 'display "\n" 'face 'nano-mu4e-preview)
                     (if (and mu4e-search-threads
                              (memq nano-mu4e-view-style '(boxed compact)))
                         (nano-mu4e-fill
                          (propertize preview 'face 'nano-mu4e-preview)
                          (- width 12)
                          (concat
                           (propertize "│ " 'face 'nano-mu4e-border)
                           (propertize "    " 'face 'nano-mu4e-gutter-body)
                           (propertize " ┊ "    'face 'nano-mu4e-preview))
                          (propertize "│"  'face 'nano-mu4e-border))
                    (nano-mu4e-fill
                     (propertize preview  'face 'nano-mu4e-preview)
                     (- width 10)
                     (concat
                      (propertize "    " 'face 'nano-mu4e-gutter-body)
                      (propertize " ┊ " 'face 'nano-mu4e-preview))
                     "")))))))
      'msg msg)))


;;; Headers buffer population
;;; ------------------------------------------------------------------------

(defvar-local nano-mu4e--message-list nil
  "Full message list that is populated during the append handler call.")

(defun nano-mu4e-append-handler (msglst)
  "This handler differs from the default one since it first collects all
messages in a single list that is stored locally in the headers
buffer. This is necessary to get the whole message list to instrument
it. The actual writing to the headers buffer will be done in the found
handler."
    
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (if (and (eq (point-min) (point-max))
               (not nano-mu4e--message-list))
          (setq-local nano-mu4e--message-list msglst)
        (setq-local nano-mu4e--message-list
                    (append nano-mu4e--message-list msglst))))))

(defun nano-mu4e--populate (msglst)
  "Populate the headers buffer with MSGLIST"
  
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (setq nano-mu4e-mode t)
      (setq-local hl-line-range-function
                  #'nano-mu4e-headers-hl-line-range)
      (save-excursion
        (let ((inhibit-read-only t)
              (gc-cons-threshold (max gc-cons-threshold (* 64 1024 1024)))
              (gc-cons-percentage 0.6)
              (index 1))
          (goto-char (point-max))
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
           msglst))))))

(defun nano-mu4e-found-handler (&optional count)
  "This function first writes all the messages in the headers buffer and
then call the default found handler."

  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (let ((count (or count (length nano-mu4e--message-list))))
        (nano-mu4e--instrument nano-mu4e--message-list)
        (nano-mu4e--populate nano-mu4e--message-list)
        ;; (mu4e~headers-found-handler count)
        (goto-char (point-min))
        (if (and (boundp 'nano-mu4e--docid) nano-mu4e--docid)
            (unless (nano-mu4e-goto-msg nano-mu4e--docid)
              (goto-char (point-min))
              (nano-mu4e-next-msg))
          (nano-mu4e-next-msg))     
        (when hl-line-mode
          (hl-line-highlight))))))

(defun nano-mu4e-nop (&rest _args)
  "Do nothing")


;;; Marks and overlays
;;; ------------------------------------------------------------------------

(defun nano-mu4e-mark-as-new (&optional msg)
  "Mark as MSG as new"
  
  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (docid (plist-get msg :docid)))
    (when docid
      (mu4e--server-move docid nil "N" t)
      (nano-mu4e-refresh))))

(defun nano-mu4e-mark-execute-all (&optional _no-confirmation)
  "Make sure we're on a msg after execution."

  (interactive)
  (mu4e-mark-execute-all t)
  ;; mu4e-mark-execute is asynchronous and we have no way to know when
  ;; it is executed. This micro-sleep handles most commands but it is
  ;; far from ideal.
  (run-at-time 0.05 nil #'nano-mu4e-refresh))


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
      (overlay-put overlay 'display (propertize
                                     (format " %s " (or mark (nano-mu4e-symbol 'mark)))
                                     'face 'nano-mu4e-gutter-mark))
      (overlay-put overlay 'mu4e-mark t)
      (overlay-put overlay 'evaporate t))    
    (beginning-of-line)
    (when-let* ((match (text-property-search-forward 'nano-mu4e-date t t nil))
                (overlay (make-overlay (prop-match-beginning match)
                                       (prop-match-end match))))
      (overlay-put overlay 'display (propertize (format "%20s" target)
                                                'face 'nano-mu4e-system))
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

;;; Navigation commands
;;; ------------------------------------------------------------------------

(defun nano-mu4e-headers-hl-line-range ()
  (save-excursion
    (when-let ((match (text-property-search-forward 'from t t nil))
               (beg (prop-match-beginning match))
               (match (text-property-search-forward 'date t t nil))
               (match (text-property-search-forward 'date nil t nil))
               (end (prop-match-beginning match)))
      (cons beg end))))


(defun nano-mu4e-mouse-click ()
  "Move point to nearest message."

  (interactive)
  (nano-mu4e-prev-msg))

(defun nano-mu4e-check-cursor ()
  "Check if cursor is beyond messages and move point to the last msg if
this is the case."

  (interactive)
  (when (eobp)
    (nano-mu4e-prev-msg)))

(defun nano-mu4e-goto-msg (docid)
  "Move point to the message with given docid.
If found, leave point at the message; otherwise, restore initial point."
  (interactive)
  (when docid
    (let ((point (point))
          (found nil))
      (goto-char (point-min))
      (catch 'found
        (while (nano-mu4e-next-msg)
          (when (= (nano-mu4e-msg-docid (mu4e-message-at-point)) docid)
            (setq found docid)
            (throw 'found docid))))
      (unless found
        (goto-char point))
      found)))

(defun nano-mu4e-next-msg (&optional _n)
  "Move point to the next unfolded message ('from properties).
If no such message is found, leave the point unchanged."
  (interactive)
  (let ((found
         (save-excursion
           (catch 'found
             (while t
               (if-let ((prop-match (text-property-search-forward 'from t t t)))
                   (progn
                     (goto-char (prop-match-beginning prop-match))
                     (if (not (get-char-property (point) 'mu4e-thread-folded))
                         (throw 'found (point))
                       nil))
                 (throw 'found nil)))))))
    (if found
        (goto-char found)
      (message "No next message"))
    found))

(defun nano-mu4e-prev-msg (&optional _n)
  "Move point to the previous unfolded message.
If no such message is found, leave the point unchanged."
  (interactive)
  (let ((found
         (save-excursion
           (catch 'found
             (while t
               (if-let ((prop-match (text-property-search-backward 'from t t t)))
                   (progn
                     (goto-char (prop-match-beginning prop-match))
                     (if (not (get-char-property (point) 'mu4e-thread-folded))
                         (throw 'found (point))
                       (backward-char 1)))
                 (throw 'found nil)))))))
    (if found
        (goto-char found)
      (message "No previous message"))
    found))

(defun nano-mu4e-next-unread-msg (&optional _n)
  "Move point to the next unread and unfolded message.
If no such message is found, leave the point unchanged."

  (interactive)
  (let ((found
         (save-excursion
           (catch 'found
             (while t
               (if-let ((prop-match (text-property-search-forward 'from t t t)))
                   (progn
                     (goto-char (prop-match-beginning prop-match))
                     (when (and (nano-mu4e-msg-is-unread (mu4e-message-at-point))
                                (not (get-char-property (point) 'mu4e-thread-folded)))
                       (throw 'found (point))))
                 (throw 'found nil)))))))
    (if found
        (goto-char found)
      (message "No next unread message"))
    found))


(defun nano-mu4e-prev-unread-msg (&optional _n)
  "Move point to the previous unread and unfolded message.
If no such message is found, leave the point unchanged."

  (interactive)
  (let ((found
         (save-excursion
           (catch 'found
             (while t
               (if-let ((prop-match (text-property-search-backward 'from t t t)))
                   (progn
                     (goto-char (prop-match-beginning prop-match))
                     (if (and (nano-mu4e-msg-is-unread (mu4e-message-at-point))
                              (not (get-char-property (point) 'mu4e-thread-folded)))
                         (throw 'found (point))
                       (backward-char 1)))
                 (throw 'found nil)))))))
    (if found
        (goto-char found)
      (message "No previous unread message"))
    found))

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



;;; Style cycling and refresh
;;; ------------------------------------------------------------------------

(defun nano-mu4e-view-style-cycle ()
  "Cycle headers view style"
  
  (interactive)
  (let* ((styles '(#1=simple regular compact boxed #1#)))
    (setq nano-mu4e-view-style
          (cadr (member nano-mu4e-view-style styles)))
    (nano-mu4e-refresh)))

(defun nano-mu4e-tag-style-cycle ()
  "Cycle tag style"
  
  (interactive)
  (let* ((styles '(#1=regular square round #1#)))
    (setq nano-mu4e-tag-style
          (cadr (member nano-mu4e-tag-style styles)))
    (nano-mu4e-refresh)))

(defun nano-mu4e--collect-messages ()
  "Collect all message from the headers buffer and stored folded state for threads root."
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (let (messages)
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (when-let ((msg (mu4e-message-at-point t)))
              (if (and (nano-mu4e-msg-is-thread-root msg)
                       (mu4e-thread-is-folded))
                  (plist-put msg :folded t)
                (plist-put msg :folded nil))
              (push msg messages))
            (forward-line 1)))
        (nreverse messages)))))

(defun nano-mu4e-refresh ()
  "Refresh headers view"

  (interactive)
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (let* ((point (point))
             (inhibit-read-only t)
             (msg (mu4e-message-at-point t))
             (docid (nano-mu4e-msg-docid msg))
             (messages (nano-mu4e--collect-messages)))
        ;; Pass 1: render headers
        (erase-buffer)
        (nano-mu4e--populate messages)
        
        ;; Pass 2: apply saved folding state
        (goto-char (point-min))
        (when mu4e-search-threads
          (while (not (eobp))
            (when-let* ((msg (mu4e-message-at-point t))
                        (folded (plist-get msg :folded)))
                (mu4e-thread-fold))
            (forward-line 1)))

        ;; Move point to saved docid
        (unless (nano-mu4e-goto-msg docid)
          (goto-char point))))))

(defun nano-mu4e-rerun ()
  "Re-run search and ensure folded threads remamin folded."

  (interactive)
  (when (buffer-live-p (mu4e-get-headers-buffer))
    (with-current-buffer (mu4e-get-headers-buffer)
      (let* ((point (point))
             (msg (mu4e-message-at-point t))
             (docid (nano-mu4e-msg-docid msg))
             (folded-docids nil))

        ;; Collect folded docids
        (when mu4e-search-threads
          (goto-char (point-min))
          (while (not (eobp))
            (when-let* ((msg (mu4e-message-at-point t))
                        (docid (nano-mu4e-msg-docid msg)))
              (if (and (nano-mu4e-msg-is-thread-root msg)
                       (mu4e-thread-is-folded))
                  (push docid folded-docids)))
            (forward-line 1)))

        ;; Pass 1: rerun search
        (mu4e-search-rerun)

        ;; Without this microsleep, folding does not work
        (sleep-for 0.05)

        ;; Pass 2: apply saved folding state
        (goto-char (point-min))
        (when mu4e-search-threads
          (while (not (eobp))
            (when-let* ((msg (mu4e-message-at-point t))
                        (docid (nano-mu4e-msg-docid msg))
                        (is-folded (memq docid folded-docids)))
                (mu4e-thread-fold))
            (forward-line 1)))
        (unless (and docid
                     (nano-mu4e-goto-msg docid))
          (goto-char point))
        (recenter-top-bottom)))))

(defun nano-mu4e-toggle-todo-root (&optional msg)
  "Toggle the \"TODO\" tag on MSG thread root.
The mark is executed immediately."

  (interactive)
  (when-let* ((msg (or msg (mu4e-message-at-point)))
              (docid (plist-get msg :docid))
              (msg (if (nano-mu4e-msg-is-thread-root msg)
                       msg
                     (progn
                       (nano-mu4e-prev-thread)
                       (mu4e-message-at-point)))))
    (nano-mu4e-toggle-todo msg)
    (nano-mu4e-goto-msg docid)))

(defun nano-mu4e-toggle-todo (&optional msg)
  "Toggle the \"TODO\" tag on MSG thread root.
The mark is executed immediately."

  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (docid (plist-get msg :docid))
         (tags-list (mu4e-message-field msg :tags))
         (tags-list (if (member "TODO" tags-list)
                        (remove "TODO" tags-list)
                      (append tags-list (list "TODO"))))
         (tags-string (mapconcat #'identity tags-list ",")))
    (when docid
      (mu4e-mark-set 'tag tags-string)
      (nano-mu4e-mark-execute-all t)
      (nano-mu4e-refresh)
      (nano-mu4e-goto-msg docid))))

(defvar nano-mu4e-tags-history nil
  "Minibuffer history of tag strings.")

(defun nano-mu4e-edit-tags-root (&optional msg)
  "Edit the tags of MSG thread root."

  (interactive)
  (when-let* ((msg (or msg (mu4e-message-at-point)))
              (msg (if (nano-mu4e-msg-is-thread-root msg)
                       msg
                     (progn
                       (nano-mu4e-prev-thread)
                       (mu4e-message-at-point)))))
    (nano-mu4e-edit-tags msg)))

(defun nano-mu4e-edit-tags (&optional msg)
  "Edit the tags of MSG (default: message at point).

Prompts for a comma-separated list of tags in the minibuffer with completion,
using individual tags from `nano-mu4e-tags-history' as candidates.
Updates the history by splitting the input so only individual tags are stored."
  (interactive)
  (let* ((msg (or msg (mu4e-message-at-point)))
         (msg (if (nano-mu4e-msg-is-thread-root msg)
                  msg
                (progn
                  (nano-mu4e-prev-thread)
                  (mu4e-message-at-point))))
         (docid (plist-get msg :docid))
         (tags (mu4e-message-field msg :tags))
         (tags (completing-read-multiple
                "Tags: "
                nano-mu4e-tags-history
                nil nil
                (mapconcat #'identity tags ",")
                nil))
         (input (mapconcat #'identity tags ",")))
    
    (when docid
      (mu4e-mark-set 'tag input)
      (nano-mu4e-mark-execute-all t)
      (nano-mu4e-refresh)
      (nano-mu4e-goto-msg docid)

      ;; Add new tags to tags history
      (dolist (tag tags)
        (let ((trimmed (string-trim tag)))
          (unless (string-empty-p trimmed)
            (setq nano-mu4e-tags-history (delete trimmed nano-mu4e-tags-history))
            (push trimmed nano-mu4e-tags-history)))))))
 

;;; Minor mode
;;; ------------------------------------------------------------------------

;; This adds our custom view inside mu4e
(add-to-list 'mu4e-header-info-custom
             '(:nano-mu4e . (:name "NΛNO"
                                   :shortname "NΛNO mu4e"
                                   :function nano-mu4e-message-line)))

(defun nano-mu4e-mode-on ()
   (setq mu4e-headers-append-func #'nano-mu4e-append-handler
         mu4e-found-func #'nano-mu4e-found-handler
         mu4e-headers-fields '((:nano-mu4e))
         mu4e--mark-fringe "")

   ;; Set mu4e-marks with NERD font v3.0 (oct collection)
   (setq nano-mu4e--saved-marks (copy-tree mu4e-marks))
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

   (advice-add #'mu4e-thread-fold-info
               :override #'nano-mu4e-thread-fold-info)
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
        mu4e--mark-fringe (make-string mu4e--mark-fringe-len ?\s))
  (setq mu4e-marks (copy-tree nano-mu4e--saved-marks))
  
  (advice-remove #'mu4e-thread-fold-info
                 #'nano-mu4e-thread-fold-info)
  (advice-remove #'mu4e~headers-mark
                 #'nano-mu4e-nop)
  (advice-remove #'mu4e-mark-at-point
                 #'nano-mu4e-mark-at-point)
  (advice-remove #'mu4e-headers-mark-and-next
                 #'nano-mu4e-headers-mark-and-next)
  (mu4e-search-rerun)
  (setq nano-mu4e-mode nil))

;;;###autoload
(define-minor-mode nano-mu4e-mode
  "NΛNO mu4e headers mode"
  :init-value nil
  :keymap (list (cons (kbd "<up>")       #'nano-mu4e-prev-msg)
                (cons (kbd "<down>")     #'nano-mu4e-next-msg)
                (cons (kbd "S-<up>")     #'nano-mu4e-prev-thread)
                (cons (kbd "S-<down>")   #'nano-mu4e-next-thread)
                (cons (kbd "<SPC>")      #'nano-mu4e-mark-as-new)
                (cons (kbd "<mouse-1>")  #'nano-mu4e-mouse-click)
                (cons (kbd "C-l")        #'nano-mu4e-rerun)
                (cons (kbd "p")          #'nano-mu4e-prev-unread-msg)
                (cons (kbd "n")          #'nano-mu4e-next-unread-msg)
                (cons (kbd "x")          #'nano-mu4e-mark-execute-all)
                (cons (kbd "t")          #'nano-mu4e-toggle-todo-root)
                (cons (kbd "T")          #'nano-mu4e-toggle-todo)
                (cons (kbd "g")          #'nano-mu4e-edit-tags-root)
                (cons (kbd "G")          #'nano-mu4e-edit-tags)
                (cons (kbd "@")          #'nano-mu4e-tag-style-cycle)
                (cons (kbd ":")          #'nano-mu4e-view-style-cycle)
                (cons (kbd "<TAB>")      #'nano-mu4e-fold-toggle)
                (cons (kbd "<backtab>")  #'nano-mu4e-fold-toggle-all))
  (if (derived-mode-p '(mu4e-headers-mode))
      (if nano-mu4e-mode
          (nano-mu4e-mode-on)
        (nano-mu4e-mode-off))
    (error "nano-mu4e mode can only be used when in mu4e-headers mode")))

;;;###autoload
(defun nano-mu4e ()
  "Start mu4e in the background and search for bookmark ?i"
  (interactive)
  (mu4e t)
  (mu4e-search (mu4e-get-bookmark-query ?i)))

(provide 'nano-mu4e)
;;; nano-mu4e.el ends here

