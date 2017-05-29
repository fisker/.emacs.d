;;
;; TAGS defintion and make
;;



;; Versionized TAGS directories, use `visit-tag-table' to visit
(defvar vdir-tags (expand-file-name (make-vdir ".tags/")))
(setq tags-table-list (list vdir-tags))


(defmacro append-etags-paths (paths)
  `(when ,paths
     (let ((s (concat (format " -path \"%s\"" (car ,paths)))))
       (dolist (p (cdr, paths))
         (setq s (concat s (format " -o -path \"%s\"" p))))
       s)))

(defmacro append-etags-names (names)
  `(when ,names
     (let ((s (concat (format " -name \"%s\"" (car ,names)))))
       (dolist (n (cdr ,names))
         (setq s (concat s (format " -o -name \"%s\"" n))))
       s)))

(defun make-emacs-etags (&optional emacs-src emacs-lisp)
  "Make tags of `emacs-home' via etags."
  (let ((tags (concat vdir-tags "TAGS"))
        (lisp-src-format
         "%s %s %s %s | %s etags -o %s -a ")
        (c-src-format
         "%s %s -type f \\\( %s \\\) | %s etags -o %s -a")
        (find-bin (platform-supported-if windows-nt "/usr/bin/find" "find"))
        (xargs-bin (platform-supported-if windows-nt "/usr/bin/xargs" "xargs")))
    (when (file-exists-p tags) (delete-file tags))
    (shell-command
     (format
      lisp-src-format
      find-bin
      emacs-home
      (format
       "\\\( %s \\\) -prune "
       (append-etags-paths '("*/.git" "*/elpa" "*/g_*" "*/t_*")))
      (format
       "-o \\\( %s \\\)"
       (append-etags-names '("*.el")))
      xargs-bin
      tags))
    (when (and emacs-src (file-exists-p emacs-src))
      (shell-command
       (format
        c-src-format
        find-bin
        emacs-src
        (append-etags-names '("*.c" "*.h"))
        xargs-bin
        tags)))
    (when (and emacs-lisp (file-exists-p emacs-lisp))
      (shell-command
       (format
        lisp-src-format
        find-bin
        emacs-lisp
        ""
        (append-etags-names '("*.el"))
        xargs-bin
        tags)))))
