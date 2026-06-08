;;; my-use-packages.el -- Emacs package configurations. -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Author: Shay Elkin <shay@elkin.io>
;; Package-Requires: ((emacs "30.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:

;;; ======================================================================

(eval-when-compile
  (require 'use-package)
  (require 'use-package-ensure))

(require 'bind-key)

(setq use-package-compute-statistics t
      use-package-always-ensure t)


;;; ======================================================================
;;; Package management
;;; ======================================================================

(require 'package)
(setq package-archives '(("gnu"          . "https://elpa.gnu.org/packages/")
			 ("melpa-stable" . "https://stable.melpa.org/packages/")
                         ("melpa"        . "https://melpa.org/packages/"))
      package-archive-priorities '(("melpa-stable" . 0)
                                   ("gnu"          . 1)
                                   ("melpa"        . 2)))


;;; ======================================================================
;;; Non-modes
;;; ======================================================================

(use-package smtpmail  ;; built-in
  :autoload smtpmail-send-it
  :custom
  (send-mail-function 'smtpmail-send-it)
  (smtpmail-smtp-server "smtp.gmail.com")
  (smtpmail-smtp-service 465)
  (smtpmail-stream-type 'ssl)
  (smtpmail-servers-requiring-authorization "\\.gmail\\.com"))

(use-package windmove  ;; built-in
  :config (windmove-default-keybindings))

(use-package magit
  :bind ("C-x g" . magit-status)
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1)
  (magit-section-initial-visibility-alist '((stashes . show)
                                            (recent . show)
                                            (unpushed . show)))
  (magit-status-margin '(t age magit-log-margin-width nil 18))
  :hook (git-commit-setup . (lambda () (setq-local fill-column 72)))
  :config (magit-add-section-hook 'magit-status-sections-hook
                                  'magit-insert-stashes
                                  'magit-insert-worktrees t))

;; (use-package windsize
;;   :config (windsize-default-keybindings))

(use-package vterm
  :bind ("<f12>" . vterm-other-window))

(use-package deadgrep
  :ensure-system-package (rg . ripgrep)
  :bind ("<f3>" . deadgrep))

(use-package speedbar  ;; built-in
  :custom (speedbar-show-unknown-files t)
  :defer t)

(use-package sr-speedbar
  ;; Don't :after speedbar, as then use-package won't bind-key. Instead, :defer
  ;; the speedbar package.
  :custom (sr-speedbar-use-frame-root-window t)
  :commands (sr-speed-bar-toggle)
  :bind ("<f10>" . sr-speedbar-toggle))

(use-package dash-at-point
  :if on-mac-window-system
  :ensure-system-package "/Applications/Dash.app"
  :bind ("C-?" . dash-at-point))

(use-package server  ;; built-in
  :config (server-start))


;;; ======================================================================
;;; Minor modes
;;; ======================================================================

 ;; Buttonize URLs and e-mail addresses.)
(use-package goto-addr
  :config (global-goto-address-mode))

(use-package paren  ;; built-in
  :config (show-paren-mode))

(use-package flyspell
  :hook ((text-mode . flyspell-mode)
         (prog-mode . flyspell-prog-mode)))

(use-package paredit
  :hook ((lisp-mode emacs-lisp-mode lisp-data-mode) . enable-paredit-mode))

;; (use-package hl-line  ;; built-in
;;   :disabled
;;   :hook (prog-mode text-mode))

(use-package diff-hl
  :after magit
  :config (global-diff-hl-mode)
  :hook ((magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

(use-package which-func  ;; built-in
  :config
  (setq which-func-unknown "")
  ;; Drop the brackets
  (when (equal (car which-func-format) "[")
    (setq which-func-format (cadr which-func-format)))
  :custom-face (which-func ((t (:inherit nil))))
  ;; Package is called `which-func', but mode is `which-function-mode'
  :hook ((c++-ts-mode java-ts-mode js-ts-mode) . which-function-mode))

(use-package yasnippet
  :defer t)

;; Corfu for in-buffer completions, Vertico for mini-buffer completions
(use-package corfu
  :config
  (global-corfu-mode)
  ;; Show corfu-info-documentation in a popup
  (corfu-popupinfo-mode))

(use-package vertico
  :config (vertico-mode))

(use-package marginalia
  :after vertico
  :config (marginalia-mode)
  :bind ((:map minibuffer-local-map ("M-A" . marginalia-cycle))
         (:map completion-list-mode-map ("M-A" . marginalia-cycle)))
  ;; :bind implies defer, but this need to be started not only in response
  ;; to the defined keybindings
  :demand t)

(use-package which-key
  :config (which-key-mode))

(use-package auto-dim-other-buffers
  ;; There's massive speedup from starting this in `after-init-hook', but doing it there
  ;; would override a face if set by a theme loaded earlier. Explicitly save and restore it.
  :hook (after-init . (lambda ()
                        (let ((bg (face-attribute 'auto-dim-other-buffers :background)))
                          (auto-dim-other-buffers-mode)
                          (set-face-attribute 'auto-dim-other-buffers nil :background bg)))))

;; ultra-scroll takes longer to load than any other package I use. Disabled for now.
;; (use-package ultra-scroll
;;   :config (ultra-scroll-mode))

(use-package makefile-executor
  :hook (makefile-mode . makefile-executor-mode))

(use-package uv-mode
  :hook ((python-ts-mode python-mode) . uv-mode-auto-activate-hook))


;;; ======================================================================
;;; Flymake
;;; ======================================================================

(defvar flymake-ignore-patterns nil
  "Buffer-local list of regexes for flymake diagnostics text to ignore.")
(make-variable-buffer-local 'flymake-ignore-patterns)

(defun my--flymake-filter-by-pattern (orig-fn &rest args)
  "Advice around `flymake--publish-diagnostics'"
  (if (null flymake-ignore-patterns)
      (apply orig-fn args)
    (let ((diags (car args)))
      (apply orig-fn
             (cons (cl-remove-if
                    (lambda (d)
                      (let ((text (flymake-diagnostic-text d)))
                        (cl-some (lambda (re) (string-match-p re text)) flymake-ignore-patterns)))
                    diags)
                   (cdr args))))))

(use-package flymake ;; built-in
  :custom
  (flymake-fringe-indicator-position 'right-fringe)
  (flymake-wrap-around t)
  :config (advice-add 'flymake--publish-diagnostics :around  #'my--flymake-filter-by-pattern)
  :bind
  ("<f7>" . flymake-show-buffer-diagnostics)
  (:map flymake-mode-map
        ("M-n" . flymake-goto-next-error)
        ("M-p" . flymake-goto-prev-error))
  ;; Usually flymake-mode would be started by Eglot, but `emacs-lisp-mode'
  ;; doesn't use LSP/Eglot.
  :hook (emacs-lisp-mode . flymake-mode ))


;;; ======================================================================
;;; Major modes
;;; ======================================================================

(use-package js ;; built-in
  :defer
  :custom (js-indent-level 2))

;; `markdown-ts-mode' exists, but markdown-mode has better ergonomics.
(use-package markdown-mode
  :mode "\\.md\\'"
  :custom
  (markdown-header-scaling t)
  (markdown-header-scaling-values '(1.7 1.5 1.3 1.2 1.1 1.1))
  ;; Make the default font for markdown buffers variable-pitch
  :hook (markdown-mode . (lambda ()
                           (setq buffer-face-mode-face '(:inherit variable-pitch :height 1.1))
                           (buffer-face-mode))))

;; (use-package markdown-ts-mode
;;   :mode "\\.md\\'"
;;   :config
;;   (add-to-list 'treesit-language-source-alist
;;                '(markdown
;;                  "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
;;                  "split_parser"
;;                  "tree-sitter-markdown/src"))
;;   (add-to-list 'treesit-language-source-alist
;;                '(markdown-inline
;;                  "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
;;                  "split_parser"
;;                  "tree-sitter-markdown-inline/src")))


(use-package swift-ts-mode
  :ensure nil
  :mode "\\.swift\\'")
;; To build tree-sitter-swift:
;; 1. https://github.com/alex-pinkus/tree-sitter-swift/blob/main/README.md#where-is-your-parserc
;; 2. `cc -fPIC -c -I. -shared parser.c scanner.c -o ~/.config/emacs/tree-sitter/tree-sitter-swift.dylib`

(use-package go-ts-mode  ;; built-in
  :mode "\\.go\\'"
  :hook ((go-ts-mode . (lambda ()
                         (setq-local indent-tabs-mode nil)))))

(use-package protobuf-ts-mode
  :mode "\\.proto\\'"
  :config (add-to-list 'treesit-language-source-alist
                       '(proto "https://github.com/mitchellh/tree-sitter-proto")))

(use-package terraform-mode
  :mode "\\.t\\(f\\(vars\\)?\\|ofu\\)\\'")

(use-package awk-ts-mode
  :mode "\\.[mg]?awk\\'")

(use-package perl-ts-mode
  :mode "\\.pl\\'")

(use-package scala-ts-mode
  :ensure nil
  :mode "\\.sc\\(ala\\)?\\'" "\\.sbt\\'")


;;; ======================================================================

(provide 'my-use-packages)
;;; my-use-packages.el ends here
