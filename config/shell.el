;;;; -*- lexical-binding:t -*-
;;;;
;; Shell environment base on OS
;;;;




(defmacro self-spec->*shell (&rest keys)
  `(self-safe-call*
    "env-spec"
    (self-spec->* :shell ,@keys)))


(defmacro path-env-spec->% (&rest keys)
  "Extract a value from the list of virtualized `path-env-spec' 
via KEYS at compile time."
  (let ((spec `(list
                :source-file
                ,(concat (v-home* "config/") ".path-env.el")
                
                :compiled-file
                ,(concat (v-home* "config/") ".path-env.elc")
                
                :shell-name "bash"
                :shell-path ,(bin-path "bash")
                :shell-var "SHELL"
                :path-var "PATH"
                
                :echo-format
                ,(platform-supported-if windows-nt
                     "echo %%%s%% 2>/nul"
                   `'((:interactive-shell
                       . "$SHELL -l -i -c 'echo -n $%s' 2>/dev/null")
                      (:login-shell
                       . "$SHELL -l -c 'echo -n $%s' 2>/dev/null"))))))
    `(self-spec->% ,spec ,@keys)))


(defvar *default-path-env*
  (list :path nil
        :shell-file-name nil
        :exec-path nil
        :env-vars nil)
  "Default path environments, 
get via (path-env-> k) and put via (path-env<- k v) ")


(defmacro path-env-> (&optional k)
  "Extract the value from `*default-path-env*' via K."
  `(if ,k
       (plist-get *default-path-env* ,k)
     *default-path-env*))

(defmacro path-env<- (k v)
  "Change the value of `*default-path-env* via K and V."
  `(plist-put *default-path-env* ,k ,v))


(defmacro echo-var (var &optional echo-format)
  "Echo a $VAR."
  `(shell-command-to-string
    (format (if ,echo-format ,echo-format
              (platform-supported-if windows-nt
                  (path-env-spec->% :echo-format)
                (if (self-spec->*shell :interactive-shell)
                    (alist-get-> :interactive-shell
                                 (path-env-spec->% :echo-format))
                  (alist-get-> :login-shell
                               (path-env-spec->% :echo-format)))))
            ,var)))


(defmacro paths->var (path sep)
  "Convert a list of PATH to $PATH like VAR that separated by SEP."
  `(let (p)
     (dolist (x ,path p)
       (setq p (concat p (when p ,sep) x)))))


(defmacro var->paths (var)
  "Refine VAR like $PATH to list by `path-separator'."
  `(split-string>< (echo-var ,var) path-separator t "[ ]+\n"))


(defun save-path-env! ()
  (path-env<- :path (var->paths (path-env-spec->% :path-var)))
  (path-env<- :shell-file-name nil)
  (path-env<- :exec-path (dolist (p (path-env-> :path) exec-path)
                           (add-to-list 'exec-path p t #'string=)))
  (path-env<- :env-vars (let ((vars (self-spec->*shell :env-vars))
                              (x nil))
                          (dolist (v vars x)
                            (push (cons v (echo-var v)) x))))
  (save-sexpr-to-file
   (list 'setq '*default-path-env*
         (list 'list
               ':path (list 'quote (path-env-> :path))
               ':shell-file-name nil
               ':exec-path (list 'quote (path-env-> :exec-path))
               ':env-vars (list 'quote (path-env-> :env-vars))))
   (path-env-spec->% :source-file))
  (byte-compile-file (path-env-spec->% :source-file)))


(defmacro load-path-env! ()
  `(progn
     (if (file-exists-p (path-env-spec->% :compiled-file))
         (load (path-env-spec->% :compiled-file))
       (path-env<- :path (var->paths (path-env-spec->% :path-var))))
     (add-hook 'kill-emacs-hook #'save-path-env!)))


(defmacro copy-env-vars! (env vars)
  `(dolist (v ,vars)
     (setenv v (cdr (assoc-string v ,env)))))


(defmacro copy-exec-path-var! ()
  `(progn
     (setenv (path-env-spec->% :path-var)
             (paths->var (path-env-> :path) path-separator))
     (when (path-env-> :exec-path)
       (setq exec-path (path-env-> :exec-path)))))


;; set shell on darwin
(platform-supported-when
    darwin

  (when (self-spec->*shell :allowed)
    (load-path-env!)
    (setenv (path-env-spec->% :path-var)
            (paths->var (path-env-> :path) path-separator))
    (when (self-spec->*shell :exec-path)
      (copy-exec-path-var!))
    (copy-env-vars! (path-env-> :env-vars)
                    (self-spec->*shell :env-vars))))


;; set shell on Linux
(platform-supported-when
    gnu/linux
  (when (self-spec->*shell :allowed)
    (load-path-env!)
    (setenv (path-env-spec->% :shell-var)
            (path-env-spec->% :shell-path))
    (when (self-spec->*shell :exec-path)
      (copy-exec-path-var!))
    (copy-env-vars! (path-env-> :env-vars)
                    (self-spec->*shell :env-vars))))


;; set shell on Windows
(platform-supported-when
    windows-nt

  (load-path-env!)

  (defmacro windows-nt-posix-path (p)
    "Return the posix path that windows-nt can recoganized."
    `(replace-regexp-in-string "\\\\" "/" ,p))

  
  (defadvice ansi-term (before ansi-term-before compile)
    (let* ((n "*ansi-term*")
           (b (get-buffer-create n)))
      (apply 'make-comint-in-buffer n b "cmd" nil nil)
      (set-window-buffer (selected-window) b)))

  
  (when (file-exists-p (path-env-spec->% :shell-path))

    ;; keep `shell-file-name' between `ansi-term' and `shell'
    (path-env<- :shell-file-name shell-file-name)
    
    (defmacro windows-nt-unix-path (p)
      "Return the unix path that shell can regcoganized on windows-nt."
      `(replace-regexp-in-string "\\([a-zA-Z]\\):/" "/\\1/"
                                 (windows-nt-posix-path ,p)))

    (defadvice shell (before shell-before compile)
      (setenv (path-env-spec->% :shell-var) (path-env-spec->% :shell-path))
      (setenv (path-env-spec->% :path-var)
              (windows-nt-unix-path (paths->var (path-env-> :path) ":")))
      (setq shell-file-name (getenv (path-env-spec->% :shell-var))))

    (defadvice shell (after shell-after compile)
      (setenv (path-env-spec->% :shell-var) (path-env-> :shell-file-name))
      (setenv (path-env-spec->% :path-var)
              (paths->var (path-env-> :path) path-separator))
      (setq shell-file-name (path-env-> :shell-file-name)))))
