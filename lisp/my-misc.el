;;; my-misc.el --- Misc. Emacs customizations. -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Author: Shay Elkin <shay@elkin.io>
;; Package-Requires: ((emacs "30.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:


;;; ======================================================================
;;; Fonts
;;; ======================================================================

(set-charset-priority 'unicode)

(when (display-multi-font-p)
  (set-fontset-font t nil (font-spec :family "Noto Sans Symbols") nil :append)
  (set-fontset-font t nil (font-spec :family "Noto Sans Symbols 2") nil :append))


;;; ======================================================================
;;; Frame display
;;; ======================================================================

(defun my--hide-menu-bar-on-text-frames (&optional frame)
  "Toggle the menu bar based on FRAME being text-only or graphical."
  (let ((frame (or frame (selected-frame))))
    (set-frame-parameter frame 'menu-bar-lines
                         (if (display-graphic-p frame) 1 0))))

;; Hide the menu-bar in text (terminal) frames.
(add-hook 'after-make-frame-functions #'my--hide-menu-bar-on-text-frames)
;; Also apply to the already created initial frame.
(dolist (frame (frame-list))
  (my--hide-menu-bar-on-text-frames frame))

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

(setq frame-title-format '(buffer-file-name
                           (:eval (abbreviate-file-name (buffer-file-name)))
                           "%b"))

;;; ======================================================================
;;; Tree-sitter
;;; ======================================================================

(setq treesit-extra-load-path '("/usr/local/lib"))
(setopt treesit-font-lock-level 2)

;; `treesit-auto' is slow to load. Simply define major-mode-remap-alist for the
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

;; These ts-modes have no non-ts fallback and/or their `auto-mode-alist' setup runs only after load.
(dolist (entry '(("\\.ya?ml\\'"    . yaml-ts-mode)
                 ("/Dockerfile\\'" . dockerfile-ts-mode)
                 ("\\.go\\'"       . go-ts-mode)
                 ("/go\\.mod\\'"   . go-mod-ts-mode)
                 ("\\.lua\\'"      . lua-ts-mode)
                 ("\\.rs\\'"       . rust-ts-mode)
                 ("\\.ts\\'"       . typescript-ts-mode)
                 ("\\.tsx\\'"      . tsx-ts-mode)
                 ("\\.heex\\'"     . heex-ts-mode)
                 ("\\.exs?\\'"     . elixir-ts-mode)))
  (unless (assoc (car entry) auto-mode-alist)
    (push entry auto-mode-alist)))


;;; ======================================================================

(provide 'my-misc)
;;; my-misc.el ends here
