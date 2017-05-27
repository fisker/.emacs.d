;;;;
;; Utils
;;;;


(defun take (n seq)
  "Returns a sequence of the first n itmes in seq, or all items if
   there are fewer than n."
  (let ((lexical-binding t))
    (let ((acc nil) (n1 n) (s1 seq))
      (while (and (> n1 0) s1)
        (setq acc (cons (car s1) acc))
        (setq n1 (1- n1) s1 (cdr s1)))
      (nreverse acc))))

(safe-do-when number-sequence (fset 'range 'number-sequence))

;; use `pp-eval-expression' or `pp-eval-last-sexp'
(safe-do-when cl-prettyexpand (fset 'pprint 'cl-prettyexpand))



(defun int-to-binary-string (i)
  "Display an integer in binary string representation."
  (let ((lexical-binding t))
    (let ((s ""))
      (while (not (= i 0))
        (setq s (concat (if (= 1 (logand i 1)) "1" "0") s))
        (setq i (lsh i -1)))
      (concat "#b" (if (string= s "") (setq s "0") s)))))

(comment
 (defun clone-themes ()
   "Clone themes from github, call it in elisp env."
   (let ((url "https://github.com/chriskempson/tomorrow-theme.git")
         (src-dir  "/tmp/xyz")
         (tmp-dir "/tmp"))
     (if (zerop (shell-command
                 (format "git -C %s clone --depth=1 %s" tmp-dir url)))
         (progn
           (when (file-exists-p src-dir)
             (copy-directory src-dir (format "%s.b0" src-dir) t t t))
           (copy-directory (format "%s/tomorrow-theme/GNU Emacs" tmp-dir)
                           src-dir t t t)
           (message "#clone themes %s." "successed"))
       (message "#clone themes %s." "failed")))))


(defmacro append-etags-paths (paths)
  `(let ((--paths-- nil))
     (setq --paths--
           (concat --paths-- (message " -path \"%s\"" (car ,paths))))
     (dolist (p (cdr ,paths))
       (setq --paths--
             (concat --paths-- (message " -o -path \"%s\"" p))))
     --paths--))

(defmacro append-etags-names (names)
  `(let ((--names-- nil))
     (setq --names--
           (concat --names-- (message " -name \"%s\"" (car ,names))))
     (dolist (n (cdr ,names))
       (setq --names--
             (concat --names-- (message " -o -name \"%s\"" n))))
     --names--))

(defun build-emacs-etags (dir &optional rebuild)
  "Make tags of DIR via etags."
  (when (and rebuild
             (file-exists-p (format "%sTAGS" dir)))
    (delete-file (format "%sTAGS" dir)))
  (eshell-command
   (message
    "%s"
    (format
     "find %s \\\( %s \\\) -prune -o \\\( %s \\\) | xargs etags -o %sTAGS -a "
     dir
     (append-etags-paths '("*/.git" "*/elpa" "*/g_*" "*/t_*"))
     (append-etags-names '("*.el"))
     dir))))

(defun build-emacs-src-etags (src tags-dir)
  "Make tags of SRC and append to DIR via etags."
  (eshell-command
   (message
    "%s"
    (format
     "find %s -type f \\\( %s \\\) | xargs etags -o %sTAGS -a"
     src
     (append-etags-names '("*.c" "*.h"))
     tags-dir))))
