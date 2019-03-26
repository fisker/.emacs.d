;;;; -*- lexical-binding:t -*-
;;;;
;; More reasonable Emacs on MacOS, Windows and Linux
;; https://github.com/junjiemars/.emacs.d
;;;;
;; on-cc-autoload.el
;;;;


;; msvc host environment

(platform-supported-when 'windows-nt
  
  (defun check-vcvarsall-bat ()
    "Return the path of vcvarsall.bat if which exists."
    (let* ((pfroot (windows-nt-posix-path (getenv "PROGRAMFILES")))
           (vsroot (concat pfroot " (x86)/Microsoft Visual Studio/"))
           (vswhere (concat vsroot "Installer/vswhere.exe")))
      (windows-nt-posix-path
       (or (let* ((cmd (shell-command* (shell-quote-argument vswhere)
                         "-nologo -latest -property installationPath"))
                  (bat (and (zerop (car cmd))
                            (concat (string-trim> (cdr cmd))
                                    "/VC/Auxiliary/Build/vcvarsall.bat"))))
             (when (file-exists-p bat) bat))
           (let* ((ver (car (directory-files
                             vsroot
                             t "[0-9]+" #'string-greaterp)))
                  (bat (concat
                        ver
                        "/BuildTools/VC/Auxiliary/Build/vcvarsall.bat")))
             (when (file-exists-p bat) bat)))))))


(platform-supported-when 'windows-nt
  
  (defun make-cc-env-bat ()
    "Make cc-env.bat in `exec-path'."
    (let ((vcvarsall (check-vcvarsall-bat))
          (arch (downcase (getenv "PROCESSOR_ARCHITECTURE"))))
      (when vcvarsall
        (save-str-to-file 
         (concat "@echo off\n"
                 (concat "rem generated by More Reasonable Emacs"
                         (more-reasonable-emacs) "\n\n")
                 "pushd %cd%\n"
                 "cd /d \"" (file-name-directory vcvarsall) "\"\n"
                 "\n"
                 "call vcvarsall.bat " arch "\n"
                 "set CC=cl" "\n"
                 "set AS=ml" (if (string-match "[_a-zA-Z]*64" arch) "64" "")
                 "\n"
                 "\n"
                 "popd\n"
                 "echo \"%INCLUDE%\"\n")
         (v-home% ".exec/cc-env.bat"))))))


(platform-supported-when 'windows-nt

  (defun make-xargs-bin ()
    "Make a GNU's xargs alternation in `exec-path'."
    (let* ((c (v-home% ".exec/xargs.c"))
           (exe (v-home% ".exec/xargs.exe"))
           (cc (concat "cc-env.bat &&"
                       " cl -nologo -W4 -DNDEBUG=1 -O2 -EHsc -utf-8"
                       " " c
                       " -Fo" (v-home% ".exec/")
                       " -Fe" exe
                       " -link -release")))
      (when (save-str-to-file
             (concat "#include <stdio.h>\n"
                     "#define _unused_(x) ((void)(x))\n"
                     "int main(int argc, char **argv) {\n"
                     "  _unused_(argc);\n"
                     "  _unused_(argv);\n"
                     "  int ch;\n"
                     "  while (EOF != (ch = fgetc(stdin))) {\n"
                     "    fputc(ch, stdout);\n"
                     "  }\n"
                     "  if (ferror(stdin)) {\n"
                     "    perror(\"read failed from stdin\");\n"
                     "    return 1;\n"
                     "  }\n"
                     "  return 0;\n"
                     "}\n")
             c)
        (let ((cmd (shell-command* cc)))
          (when (zerop (car cmd))
            (delete-file c)
            (delete-file (v-home% ".exec/xargs.obj"))
            exe))))))


 ;; msvc host environment


(defmacro norm-file-remote-p (file)
  "Return an identification when FILE specifies a location on a remote system.

On ancient Emacs, `file-remote-p' will return a vector."
  `(match-string* "^\\(/sshx?:[_-a-zA-Z0-9]+@?[_-a-zA-Z0-9]+:\\)"
                  ,file 1))

(defmacro norm-rid (remote)
  "Norm the REMOTE to '(method user [host]) form."
  `(split-string* ,remote "[:@]" t "/"))

(defmacro rid-user@host (remote)
  "Make a user@host form from REMOTE."
  `(let ((rid (norm-rid ,remote)))
     (concat (cadr rid) (when (caddr rid)
                          (concat "@" (caddr rid))))))


(defun check-cc-include (&optional remote)
  "Return a list of system cc include path."
  (let ((cmd (if remote
                 (when% (executable-find% "ssh")
                   (shell-command* "ssh"
                     (concat (rid-user@host remote)
                             " \"echo '' | cc -v -E 2>&1 >/dev/null -\"")))
               (platform-supported-if 'windows-nt
                   ;; Windows: msmvc
                   (shell-command* (or (executable-find% "cc-env.bat")
                                       (make-cc-env-bat)))
                 ;; Darwin/Linux: clang or gcc
                 (shell-command* "echo '' | cc -v -E 2>&1 >/dev/null -"))))
        (parser (lambda (preprocessed)
                  (take-while
                   (lambda (p)
                     (string-match "End of search list." p))
                   (drop-while
                    (lambda (p)
                      (string-match "#include <...> search starts here:" p))
                    (split-string* preprocessed "\n" t "[ \t\n]"))))))
    (when (zerop (car cmd))
      (if remote
          ;; Unix-like
          (funcall parser (cdr cmd))
        (platform-supported-if 'windows-nt
            ;; Windows: msvc
            (mapcar (lambda (x) (windows-nt-posix-path x))
                    (var->paths
                     (car (nreverse 
                           (split-string* (cdr cmd) "\n" t "\"")))))
          ;; Darwin/Linux: clang or gcc
          (let ((inc (funcall parser (cdr cmd))))
            (platform-supported-if 'darwin
                (mapcar (lambda (x)
                          (file-truename
                           (string-trim> x " (framework directory)")))
                        inc)
              inc)))))))


;; system cc include

(defun system-cc-include (&optional cached remote)
  "Returns a list of system include directories. 

Load `system-cc-include' from file when CACHED is t, 
otherwise check cc include on the fly.

If specify REMOTE argument then return a list of remote system
include directories. The REMOTE argument from `file-remote-p'."
  (let* ((rid (when remote
                (mapconcat #'identity (norm-rid remote) "-")))
         (c (if remote
                (v-home* (concat ".exec/.cc-inc-" rid ".el"))
              (v-home% ".exec/.cc-inc.el")))
         (cc (concat c "c"))
         (var (if remote
                  (intern (concat "system-cc-include@" rid))
                'system-cc-include)))
    (if (and cached (file-exists-p cc))
        (load cc)
      (let ((inc (if remote
                     (mapcar (lambda (x)
                               (concat remote x))
                             (check-cc-include remote))
                   (check-cc-include))))
        (set var inc)
        (when (save-sexp-to-file `(set ',var ',inc) c)
          (byte-compile-file c))))
    (symbol-value var)))


(defun system-cc-include-p (file)
  "Return t if FILE in `system-cc-include', otherwise nil."
  (when (stringp file)
    (member** (string-trim> (file-name-directory file) "/")
              (system-cc-include t (norm-file-remote-p file))
              :test (lambda (a b)
                      (let ((case-fold-search (platform-supported-when
                                                  'windows-nt t)))
                        (string-match b a))))))

    
(defun view-system-cc-include (buffer)
  "View BUFFER in `view-mode' when the filename of BUFFER in
`system-cc-include'."
  (when (and (bufferp buffer)
             (let ((m (buffer-local-value 'major-mode buffer)))
               (or (eq 'c-mode m)
                   (eq 'c++-mode m)))
             (system-cc-include-p (substring-no-properties
                                   (buffer-file-name buffer))))
    (with-current-buffer buffer (view-mode 1))))


 ;; end of system-cc-include


(defadvice ff-find-other-file (before ff-find-other-file-before compile)
  "Set `cc-search-directories' based on local or remote."
  (let ((file (buffer-file-name (current-buffer))))
    (setq% cc-search-directories
           (append (list (string-trim> (file-name-directory file) "/"))
                   (system-cc-include t (norm-file-remote-p file))))))

(defadvice ff-find-other-file (after ff-find-other-file-after compile)
  "View the other-file in `view-mode' when `system-cc-include-p' is t."
  (view-system-cc-include (current-buffer)))


(defadvice c-macro-expand (around c-macro-expand-around compile)
  "cl.exe cannot retrieve from stdin."
  (let ((remote (norm-file-remote-p (buffer-file-name (current-buffer)))))
    (if remote
        ;; remote: Unix-like
        (when% (executable-find% "ssh")
          (setq% c-macro-preprocessor
                 (concat "ssh " (rid-user@host remote)
                         " \'cc -E -o - -\'")
                 'cmacexp)
          ad-do-it)
      ;; local: msvc, clang, gcc
      (platform-supported-if 'windows-nt
          ;; [C-c C-e] macro expand for msvc
          (when% (and (or (executable-find% "cc-env.bat")
                          (make-cc-env-bat))
                      (or (executable-find%
                           "xargs"
                           (lambda (xargs)
                             (let ((x (shell-command* "echo xxx"
                                        "&& echo zzz"
                                        "|xargs -0")))
                               (and (zerop (car x))
                                    (string-match "^zzz" (cdr x))))))
                          (make-xargs-bin)))
            (let* ((tmp (make-temp-file
		                     (expand-file-name "cc-" temporary-file-directory)))
                   (c-macro-preprocessor
                    (format "xargs -0 > %s && cc-env.bat && cl -E %s"
                            tmp tmp)))
              (unwind-protect ad-do-it
                (delete-file tmp))))
        ;; Darwin/Linux
        (platform-supported-when 'darwin
          (when% (executable-find%
                  "cc"
                  (lambda (cc)
                    (let ((x (shell-command* "echo -e"
                               "\"#define _unused_(x) ((void)(x))\n_unused_(a);\""
                               "|cc -E -")))
                      (and (zerop (car x))
                           (string-match "((void)(a));" (cdr x))))))
            (setq% c-macro-preprocessor "cc -E -o - -" 'cmacexp)))
        ad-do-it))))


(with-eval-after-load 'cc-mode

  (when-var% c-mode-map 'cc-mode

    ;; keymap: find c include file
    (when-fn% 'ff-find-other-file 'find-file
      (define-key% c-mode-map (kbd "C-c f i") #'ff-find-other-file)
      (ad-activate #'ff-find-other-file t))

    ;; keymap: indent line or region
    (when-fn% 'c-indent-line-or-region 'cc-cmds
      (define-key% c-mode-map (kbd "TAB") #'c-indent-line-or-region))))


(with-eval-after-load 'cmacexp

  ;; [C-c C-e] `c-macro-expand' in `cc-mode'
  (setq% c-macro-prompt-flag t 'cmacexp)
  (ad-activate #'c-macro-expand t))


;; end of on-cc-autoload.el

