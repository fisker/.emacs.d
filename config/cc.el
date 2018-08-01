;;;; -*- lexical-binding:t -*-
;;;;
;; More reasonable Emacs on MacOS, Windows and Linux
;; https://github.com/junjiemars/.emacs.d
;;;;
;; cc.el
;;;;


(platform-supported-when windows-nt
  
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
					 (let* ((ver (car (directory-files vsroot t "[0-9]+" #'string-greaterp)))
									(bat (concat ver "/BuildTools/VC/Auxiliary/Build/vcvarsall.bat")))
						 (when (file-exists-p bat) bat)))))))


(platform-supported-when windows-nt
  
  (defun make-cc-env-bat ()
		"Make .cc-env.bat in `exec-path'."
    (let ((vcvarsall (check-vcvarsall-bat)))
      (when vcvarsall
        (save-str-to-file 
         (concat "@echo off\n"
								 "cd /d \"" (file-name-directory vcvarsall) "\"\n"
								 "call vcvarsall.bat " (downcase (getenv "PROCESSOR_ARCHITECTURE")) "\n"
								 "echo \"%INCLUDE%\"\n")
				 (expand-file-name (v-home% ".exec/" ".cc-env.bat")))))))


(defun check-cc-include ()
	"Return cc include paths list."
	(platform-supported-if windows-nt
			;; Windows: msvc
			(let ((cmd (shell-command* (make-cc-env-bat))))
				(when (zerop (car cmd))
					(var->paths
					 (car (nreverse 
								 (split-string* (cdr cmd) "\n" t "\""))))))
		;; Darwin/Linux: clang or gcc
		(let ((cmd (shell-command* "echo '' | cc -v -E 2>&1 >/dev/null -")))
			(when (zerop (car cmd))
				(take-while
				 (lambda (p)
					 (string-match "End of search list." p))
				 (drop-while
					(lambda (p)
						(string-match "#include <...> search starts here:" p))
					(split-string* (cdr cmd) "\n" t "[ \t\n]")))))))


(defvar system-cc-include nil
  "The system include paths used by C compiler.

This should be set with `system-cc-include'")


(defun system-cc-include (&optional cached)
  "Returns a list of system include directories. 

Load `system-cc-include' from file when CACHED is t, 
otherwise check cc include on the fly."
  (let ((c (v-home% "config/" ".cc-inc.el")))
    (if (and cached (file-exists-p (concat c "c")))
        (progn
          (load (concat c "c"))
          system-cc-include)
      (let ((paths (platform-supported-if darwin
											 (mapcar (lambda (x)
																 (string-trim> x " (framework directory)"))
															 (check-cc-include))
										 (check-cc-include))))
        (when (save-sexp-to-file
               `(setq system-cc-include ',paths) c)
          (byte-compile-file c))
        (setq system-cc-include paths)))))



(provide 'cc)
