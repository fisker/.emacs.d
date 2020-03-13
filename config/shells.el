;;;; -*- lexical-binding:t -*-
;;;;
;; More reasonable Emacs on MacOS, Windows and Linux
;; https://github.com/junjiemars/.emacs.d
;;;;
;; shells.el
;;;;


(defmacro shells-spec->% (&rest keys)
  "Extract value from the list of spec via KEYS at compile time."
  (declare (indent 0))
  `(self-spec->%
       (list :source-file ,(v-home! ".exec/.shell-env.el")
             :compiled-file ,(v-home! ".exec/.shell-env.elc")
             :SHELL "SHELL"
             :PATH "PATH")
     ,@keys))


(defmacro shells-spec->* (&rest keys)
  "Extract value from the list of :shell spec via KEYS at runtime."
  (declare (indent 0))
   `(self-spec->*env-spec :shell ,@keys))


(defvar *default-shell-env*
  (list :exec-path nil
        :env-vars nil)
  "Default shell environments, 
get via `(shell-env-> k)' and put via `(shell-env<- k v)'")


(defmacro shell-env-> (&optional k)
  "Extract the value from `*default-shell-env*' via K."
  `(if ,k
       (plist-get *default-shell-env* ,k)
     *default-shell-env*))

(defmacro shell-env<- (k v)
  "Put K and V into `*default-shell-env*'."
  `(plist-put *default-shell-env* ,k ,v))



(defmacro paths->var (path &optional predicate)
  "Convert a list of PATH to $PATH like var that separated by `path-separator'."
  `(string-trim> (apply #'concat
                        (mapcar #'(lambda (s)
                                    (if (functionp ,predicate)
                                        (when (funcall ,predicate s)
                                          (concat s path-separator))
                                      (concat s path-separator)))
                                ,path))
                 path-separator))

(defmacro var->paths (var)
  "Refine VAR like $PATH to list by `path-separator'.
See also: `parse-colon-path'."
  `(when (stringp ,var)
     (split-string* ,var path-separator t "[ ]+\n")))



(defun save-shell-env! ()
  (shell-env<- :exec-path
               (mapc (lambda (p)
                       (when (stringp p)
                         (add-to-list 'exec-path p t #'string=)))
                     (append (var->paths (getenv (shells-spec->% :PATH)))
                             (unless-platform% 'windows-nt
                               (list (v-home% ".exec/"))))))
  (shell-env<- :env-vars
               (let ((vars nil))
                 (mapc (lambda (v)
                         (when (stringp v)
                           (push (cons v (getenv v)) vars)))
                       (shells-spec->* :env-vars))
                 vars))
  (when (save-sexp-to-file
         (list 'setq '*default-shell-env*
               (list 'list
                     ':exec-path (list 'quote (shell-env-> :exec-path))
                     ':env-vars (list 'quote (shell-env-> :env-vars))))
         (shells-spec->% :source-file))
    (byte-compile-file (shells-spec->% :source-file))))


(defmacro read-shell-env! ()
  `(progn
     (when (file-exists-p (shells-spec->% :compiled-file))
       (load (shells-spec->% :compiled-file)))
     (add-hook 'kill-emacs-hook #'save-shell-env! t)))


(defmacro copy-env-vars! (env vars)
  `(mapc (lambda (v)
           (when v (let ((v1 (cdr (assoc** v ,env #'string=))))
                     (when v1 (setenv v v1)))))
         ,vars))


(defmacro copy-exec-path! (path)
  `(when ,path (setq exec-path ,path)))




;; Windows ansi-term/shell

(when-platform% 'windows-nt
  
  (defadvice ansi-term (before ansi-term-before compile)
    (set-window-buffer (selected-window)
                       (make-comint-in-buffer "ansi-term" nil "cmd"))))


(when-platform% 'windows-nt
  (with-eval-after-load 'term (ad-activate #'ansi-term t)))


(when-platform% 'windows-nt

  (defun windows-nt-env-path+ (dir &optional append)
    "APPEND or push DIR to %PATH%."
    (let ((env (var->paths (getenv (shells-spec->% :PATH)))))
      (when (or (and (null append) (not (string= dir (first env))))
                (and append (not (string= dir (last env)))))
        (let ((path (remove** dir env :test #'string=)))
          (setenv (shells-spec->% :PATH)
                  (paths->var (if append
                                  (append path dir)
                                (cons dir path)))))))))

 ;; end of Windows ansi-term/shell


;; allowed/disallowed `shells-spec->*'

(if (shells-spec->* :allowed)
    (progn
      (read-shell-env!)
      
      (when (shells-spec->* :shell-file-name)
        (setenv (shells-spec->% :SHELL)
                (shells-spec->* :shell-file-name)))
      
      (when (shells-spec->* :exec-path)
        (copy-exec-path! (shell-env-> :exec-path)))

      (when (shells-spec->* :env-vars)
        (copy-env-vars! (shell-env-> :env-vars)
                        (shells-spec->* :env-vars))))
  ;; disallowed: append .exec/ to `exec-path'
  (add-to-list 'exec-path (v-home% ".exec/") t #'string=))


 ;; end of allowed/disallowed `shells-spec->*'





 ;; end of shells.el
