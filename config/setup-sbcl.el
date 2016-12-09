;;;;
;; sbcl
;;;;

;; sbcl path
(platform-supported-p
 windows-nt
 (let* ((home (getenv "SBCL_HOME"))
        (path (windows-nt-path
               (file-name-directory
                (if home home (bin-path "sbcl"))))))
   (add-to-list 'exec-path path)
   (setq inferior-lisp-program "sbcl")))

(platform-supported-unless
 windows-nt
 (setq inferior-lisp-program (bin-path "sbcl")))


;; setup sbcl, it's slow process so be adviced
(defadvice slime (before slime-before compile)
  (add-hook 'sldb-hook (lambda () (linum-mode -1)))
  (add-hook
   'slime-repl-mode-hook
   (lambda ()
     (linum-mode -1)
     (local-set-key (kbd "<f12>") 'slime-selector)))
  (slime-setup '(slime-fancy slime-asdf)))

