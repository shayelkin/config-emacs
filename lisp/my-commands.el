;;; my-commands.el --- Useful commands for Emacs. -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Author: Shay Elkin <shay@elkin.io>
;; Package-Requires: ((emacs "30.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:

(defun indent-whole-buffer ()
  "Indent the whole buffer."
  (interactive)
  (indent-region (point-min) (point-max) nil))

(defun rename-file-and-buffer (new-name)
  "Renames both the current buffer and the file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file name new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))


;;; ======================================================================
;;; Generate a GitHub link for the current position
;;; ======================================================================

(defun my--github-remote-urls ()
  "Return the URLs for the current buffer's git remotes that are hosted on GitHub."
  (declare-function magit-get "magit-git")
  (declare-function magit-list-remotes "magit-git")
  (seq-filter
   (lambda (r) (string-match-p "github\\.com" r))
   (mapcar
    (lambda (r) (magit-get "remote" r "url"))
    (magit-list-remotes))))

(defun github-url-at-point ()
  "Generate a GitHub link for current file position and copy it into the clipboard."
  (interactive)
  (require 'magit)
  (if-let* ((filename (buffer-file-name))
            (remote-url (car (my--github-remote-urls)))
            (relative-path (file-relative-name filename (magit-toplevel)))
            (github-url (format "%s/blob/%s/%s#L%d"
                                (replace-regexp-in-string
                                 "\\(git@github\\.com:\\|https://github\\.com/\\)\\(.*\\)\\.git$"
                                 "https://github.com/\\2"
                                 remote-url)
                                (magit-rev-parse "HEAD")
                                relative-path
                                (line-number-at-pos))))
      (progn
        (when (called-interactively-p 'interactive)
          (message github-url))
        (kill-new github-url)
        github-url)
    (when (called-interactively-p 'interactive)
      (message "Can't find a GitHub hosted remote for the current buffer"))))


;;; ======================================================================
;;; Add/remove window from a frame, keeping existing windows the same size
;;; ======================================================================

(defun shrink-frame-horizontally (&optional window)
  "Delete the window to the right of WINDOW.

If WINDOW is the right-most window in the row, delete the one to its left.
When on a window system, also shrink the frame by the size of the deleted window"
  (interactive)
  (if-let* ((window (or window (selected-window)))
            (window-to-delete (or (window-in-direction 'right window)
                                  (window-in-direction 'left window)))
            (frame (window-frame window-to-delete))
            (shrink-by (window-total-width window-to-delete)))
      (progn
        (delete-window window-to-delete)
        (when window-system
          (set-frame-width frame (- (frame-width frame) shrink-by))))
    (message "There is no other window in the row to delete.")))

(defun my--move-frame-left-if-needed (&optional frame)
  "Move FRAME to be inside the display if possible."
  (interactive)
  (let* ((frame (or frame (selected-frame)))
         (frame-width (frame-pixel-width frame))
         (display-width (display-pixel-width)))
    (when (> (+ (frame-parameter frame 'left) frame-width) display-width)
      (set-frame-position frame
                          (max 0 (- display-width frame-width))
                          (frame-parameter frame 'top)))))

(defun expand-frame-horizontally (&optional window)
  "Create a window to the right of WINDOW and on window system expand the frame."
  (interactive)
  (let* ((window (or window (selected-window)))
         (frame (window-frame window))
         (expand-by (window-total-width window))
         (original-frame-width (frame-width frame)))
    (when window-system
      ;; set-frame-width first, to have window and the new window
      ;; be the same size
      (set-frame-width frame (+ original-frame-width expand-by))
      (my--move-frame-left-if-needed))
    (unless (split-window-right nil window)
      (set-frame-width frame original-frame-width)
      (message "Failed to create new window"))))


;;; ======================================================================

(provide 'my-commands)
;;; my-commands.el ends here
