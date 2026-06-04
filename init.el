;;; init.el --- Emacs initialization file. -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Author: Shay Elkin <shay@elkin.io>
;; Package-Requires: ((emacs "30.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:

;;; ======================================================================

;; Don't bother with backwards compatibility.
(when (version< emacs-version "30")
  (error "It is time to upgrade this Emacs installation!"))

(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs loaded in %.3f seconds with %d garbage collections done."
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done)))

(defconst on-mac-window-system (memq window-system '(mac ns))
  "Non-nil when running on macOS graphical environment.")

;; Similar to `exec-path-from-shell', but just the essence, so hopefully faster.
;; Works on bash and zsh which is all I care about.
(when on-mac-window-system
  (let ((path-string (string-trim
                      (with-temp-buffer
                        (call-process (getenv "SHELL") nil t nil "-lc" "echo $PATH")
                        (buffer-string)))))
    (setq exec-path (parse-colon-path path-string))
    (setenv "PATH" path-string)))


(dolist (file
         ;; Drop the extension so the compiled file would be loaded when exists.
         (mapcar #'file-name-sans-extension
                 (directory-files
                  (expand-file-name "lisp" user-emacs-directory) t "\\.el\\'")))
  (load file))


;;; ======================================================================
;;; Misc. customizations
;;; ======================================================================

(setq fill-column 100)
(setq tab-always-indent 'complete)  ;; TAB indents, or if already indented, complete-at-point.

(setq delete-by-moving-to-trash t)
(setq blink-cursor-blinks 2)
(setq inhibit-startup-message t)
(setq mac-option-modifier 'meta)
(setq read-file-name-completion-ignore-case t)
(setq ring-bell-function 'ignore)
(setq show-trailing-whitespace t)

(setq create-lockfiles nil)
(setq read-process-output-max 65535)  ;; https://debbugs.gnu.org/cgi/bugreport.cgi?msg=5;bug=55737

(setq use-dialog-box nil)
(setq use-short-answers t)

(setq-default cursor-type 'hbar)
(setq-default indent-tabs-mode nil)

(add-hook 'text-mode-hook #'turn-on-auto-fill)
(add-hook 'text-mode-hook #'visual-line-mode)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'electric-pair-local-mode)
(add-hook 'before-save-hook #'delete-trailing-whitespace)

(setopt text-mode-ispell-word-completion nil)

;;; ======================================================================
;;; Key bindings
;;; ======================================================================

;; In this file because we need my-commands to load first
(require 'my-commands)

;; bind-key, package and use-package are the only packages that aren't
;; loaded with the `use-package' macro.
(require 'bind-key)

(bind-key "M-j" (lambda ()
                  "Joins the next line to this, regardless of where the point is in the line."
                  (interactive) (join-line -1)))

(bind-key "<f2>" #'revert-buffer-quick)
(bind-key* "C-." #'completion-at-point)

(bind-keys
 ("C-c C-k"    . kill-region)
 ("C-w"        . backward-kill-word)
 ("C-z"        . undo))

;; M-> is S-M-. which is set to effectively undo M-.
(bind-key "M->" #'pop-tag-mark)

;; Unset mouse wheel changing font size: easy to accidently trigger.
(keymap-global-unset "C-<wheel-up>")
(keymap-global-unset "C-<wheel-down>")
(bind-keys ("C-+" . text-scale-increase)
           ("C-_" . text-scale-decrease))
;; C-) (aka C-S-0) needs bind-key* to override a default binding in `paredit-mode-map'.
(bind-key* "C-)" (lambda ()
                   (interactive) (text-scale-increase 0)))

(when on-mac-window-system
  (keymap-global-unset  "s-t")
  (keymap-global-unset  "s-q")
  (bind-key "s-<return>" #'toggle-frame-maximized)
  (bind-key "s-w"        #'kill-ring-save)
  ;; Emulate a 3-button mouse (<mouse-2> is middle click, <mouse-3> right click)
  (keymap-set key-translation-map "s-<mouse-3>" "<mouse-2>"))

;; Those are defined in my-commands:
(bind-key* "C-c C-i" #'indent-whole-buffer)

(bind-keys* ("C-{" . shrink-frame-horizontally)
            ("C-}" . expand-frame-horizontally))

(bind-key "<f8>" #'github-url-at-point)


;;; ======================================================================
;;; Custom file
;;; ======================================================================

(setq custom-file
      (expand-file-name "custom.el" user-emacs-directory))
(load-file custom-file)


;;; ======================================================================

(provide 'init)
;;; init.el ends here
