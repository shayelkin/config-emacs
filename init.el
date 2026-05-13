;;; init.el --- Emacs initialization file. -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Author: Shay Elkin <shay@elkin.io>
;; Package-Requires: ((emacs "30.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:

;; Don't bother with backwards compatibility.
(when (version< emacs-version "30")
  (error "It is time to upgrade this Emacs installation!"))

(defconst on-mac-window-system (memq window-system '(mac ns))
  "Non-nil when running on macOS graphical environment.")

(defvar elisp-src-dir
  (expand-file-name "~/src/elisp")
  "Directory containing local sources for Emacs packages.")

;; Similar to `exec-path-from-shell', but just the essence, so hopefully faster.
;; Works on bash and zsh which is all I care about.
(when on-mac-window-system
  (let ((path-string (string-trim
                      (with-temp-buffer
                        (call-process (getenv "SHELL") nil t nil "-lc" "echo $PATH")
                        (buffer-string)))))
    (setq exec-path (parse-colon-path path-string))
    (setenv "PATH" path-string)))


;; --- Package management:

;; The only packages not configured by `use-package'. All three are internal.

(require 'package)
(setq package-archives '(("gnu"          . "https://elpa.gnu.org/packages/")
			 ("melpa-stable" . "https://stable.melpa.org/packages/")
                         ("melpa"        . "https://melpa.org/packages/"))
      package-archive-priorities '(("melpa-stable" . 0)
                                   ("gnu"          . 1)
                                   ("melpa"        . 2)))

(require 'bind-key)

;; --- Useful commands:

(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs loaded in %.3f seconds with %d garbage collections done."
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done)))

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

(defun my/github-remote-urls ()
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
            (remote-url (car (my/github-remote-urls)))
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

(bind-key "<f8>" 'github-url-at-point)

;; Add or remove a pane and change the size of the frame, keeping the existing
;; windows in the frame the same size.

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

(defun my/move-frame-left-if-needed (&optional frame)
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
      (my/move-frame-left-if-needed))
    (unless (split-window-right nil window)
      (set-frame-width frame original-frame-width)
      (message "Failed to create new window"))))

(bind-keys* ("C-{" . shrink-frame-horizontally)
            ("C-}" . expand-frame-horizontally))


;; --- Fonts:

(set-charset-priority 'unicode)

(when (display-multi-font-p)
  (set-fontset-font t nil (font-spec :family "Noto Sans Symbols") nil :append)
  (set-fontset-font t nil (font-spec :family "Noto Sans Symbols 2") nil :append))


;; --- Misc customizations:

;; Set macOS GUI dark appearance based on frame background
(defun my/ns-adjust-appereance (frame &rest _)
  (modify-frame-parameters frame `((ns-appearance . ,(frame-parameter frame 'background-mode)))))

(when on-mac-window-system
  (advice-add 'frame-set-background-mode :after 'my/ns-adjust-appereance))

(defun my/hide-menu-bar-on-text-frames (&optional frame)
  "Toggle the menu bar based on FRAME being text-only or graphical."
  (let ((frame (or frame (selected-frame))))
    (set-frame-parameter frame 'menu-bar-lines
                         (if (display-graphic-p frame) 1 0))))

;; Hide the menu-bar in text (terminal) frames.
(add-hook 'after-make-frame-functions #'my/hide-menu-bar-on-text-frames)
;; Also apply to the already created initial frame.
(dolist (frame (frame-list))
  (my/hide-menu-bar-on-text-frames frame))

(add-hook 'after-make-frame-functions (lambda (&optional frame)
                                        (unless (or xterm-mouse-mode (display-graphic-p frame))
                                          (xterm-mouse-mode))))

;; On macOS `display-mm-width' lies, but `frame-monitor-attribute' has the correct value.
;; We can only maximize an already created frame, so can't use `inital-frame-alist'.
(when-let* ((mm-width (car (alist-get 'mm-size (frame-monitor-attributes))))
            ((< mm-width 450)))
  (set-frame-parameter nil 'fullscreen 'maximized))

;; Split the inital frame
(when (< split-width-threshold (frame-parameter nil 'width))
  (split-window-horizontally))

(show-paren-mode)
(global-goto-address-mode)  ;; Buttonize URLs and e-mail addresses.

(setq frame-title-format '(buffer-file-name
                           (:eval (abbreviate-file-name (buffer-file-name)))
                           "%b"))
(setq
 fill-column 100
 blink-cursor-blinks 2
 create-lockfiles nil
 delete-by-moving-to-trash t
 inhibit-startup-message t
 mac-option-modifier 'meta
 read-file-name-completion-ignore-case t
 read-process-output-max 65535  ;; https://debbugs.gnu.org/cgi/bugreport.cgi?msg=5;bug=55737
 ring-bell-function 'ignore
 show-trailing-whitespace t
 tab-always-indent 'complete    ;; TAB indents, if already indented, complete-at-point.
 use-dialog-box nil
 use-short-answers t)

(setq-default cursor-type 'hbar
              indent-tabs-mode nil)

;; Don't use Ispell to complete words in text modes.
(setopt text-mode-ispell-word-completion nil
        treesit-font-lock-level 2)

(add-hook 'text-mode-hook #'turn-on-auto-fill)
(add-hook 'text-mode-hook #'visual-line-mode)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'electric-pair-local-mode)

(add-hook 'before-save-hook #'delete-trailing-whitespace)

;; Mode line customization moved to its own file:
(load (expand-file-name "my-mode-line" user-emacs-directory))

;; `treesit-auto' is slow to load. Just define major-mode-remap-alist for the
;; built-in modes instead:
(setq major-mode-remap-alist '((conf-toml-mode . toml-ts-mode)
                               (ruby-mode . ruby-ts-mode)
                               (python-mode . python-ts-mode)
                               (js-json-mode . json-ts-mode)
                               (javascript-mode . js-ts-mode)
                               (js-mode . js-ts-mode)
                               (java-mode . java-ts-mode)
                               (sgml-mode . html-ts-mode)
                               (mhtml-mode . html-ts-mode)
                               (css-mode . css-ts-mode)
                               (c++-mode . c++-ts-mode)
                               (csharp-mode . csharp-ts-mode)
                               (c-mode . c-ts-mode)
                               (sh-mode . bash-ts-mode)
                               (awk-mode . awk-ts-mode)
                               (perl-mode . perl-ts-mode)))

;; --- Key bindings:

(bind-key "M-j" (lambda ()
                  "Joins the next line to this, regardless of where the point is in the line."
                  (interactive) (join-line -1)))

(bind-keys
 ("<f1>"       . scratch-buffer)
 ("<f2>"       . revert-buffer-quick)
 ("C-."        . completion-at-point)
 ("C-c C-k"    . kill-region)
 ("C-w"        . backward-kill-word)
 ("C-z"        . undo)
 ("M-<return>" . fill-paragraph)
 ;; M-> is S-M-. which undos M-.
 ("M->"        . pop-tag-mark))

;; Unset mouse wheel changing font size: easy to accidently trigger.
(keymap-global-unset "C-<wheel-up>")
(keymap-global-unset "C-<wheel-down>")
(bind-keys ("C-+" . text-scale-increase)
           ("C-_" . text-scale-decrease))
;; C-) (aka C-S-0) needs bind-key* to override a default binding in `paredit-mode-map'.
(bind-key* "C-)" (lambda ()
                   (interactive) (text-scale-increase 0)))


(defun indent-whole-buffer ()
  "Indent the whole buffer."
  (interactive)
  (indent-region (point-min) (point-max) nil))

(bind-key* "C-c C-i"  #'indent-whole-buffer)

(when on-mac-window-system
  (keymap-global-unset  "s-t")
  (keymap-global-unset  "s-q")
  (bind-key "s-<return>" #'toggle-frame-maximized)
  (bind-key "s-w"        #'kill-ring-save)
  ;; Emulate a 3-button mouse (<mouse-2> is middle click, <mouse-3> right click)
  (keymap-set key-translation-map "s-<mouse-3>" "<mouse-2>"))

;; Per package settings move to their own file:
(load (expand-file-name "use-packages" user-emacs-directory))

;; --- custom-file:

(setq custom-file
      (expand-file-name "custom.el" user-emacs-directory))
(load-file custom-file)

(use-package server ;; built in
  :config (server-start))

(provide 'init)
;;; init.el ends here
