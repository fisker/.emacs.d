;;;; -*- lexical-binding:t -*-
;;;;
;; More reasonable Emacs on MacOS, Windows and Linux
;; https://github.com/junjiemars/.emacs.d
;;;;
;; on-edit-autoload.el
;;;;


(terminal-supported-p
  ;;above version 23 transient-mark-mode is enabled by default
  (version-supported-when > 23 (transient-mark-mode t))
  (set-face-background 'region "white")
  (set-face-foreground 'region "black"))

;; No cursor blinking, it's distracting
(when-fn% 'blink-cursor-mode nil (blink-cursor-mode 0))

;; full path in title bar
(graphic-supported-p
  (setq% frame-title-format "%b (%f)"))

;; Ignore ring bell
(setq% ring-bell-function 'ignore)


;; Changes all yes/no questions to y/n type
;; (defalias 'yes-or-no-p 'y-or-n-p)

;; Highlights matching parenthesis
(show-paren-mode 1)


;; enable save minibuffer history
(version-supported-if
    <= 24
    (savehist-mode)
  (savehist-mode t))

;; enable save-place
(version-supported-if
    <= 25.1
    (save-place-mode t)
  (setq% save-place t 'saveplace))

;; Shows all options when running apropos. For more info,
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Apropos.html
;;enable apropos-do-all, but slower
(setq% apropos-do-all t 'apropos)


;; Save before kill
(setq% save-interprogram-paste-before-kill t 'simple)

;; Mouse yank commands yank at point instead of at click.
(setq% mouse-yank-at-point t 'mouse)


;; no need for ~ files when editing
(setq% create-lockfiles nil)


;; Greek letters C-x 8 <RET> greek small letter lambda
;; (global-set-key (kbd "C-c l") "λ")


;; enable upcase/downcase region
(put 'downcase-region 'disabled nil)
(put 'upcase-region 'disabled nil)


;; enable column number mode
(setq% column-number-mode t 'simple)


;; comments
(defun toggle-comment ()
  "Toggle comment on current line or region."
  (interactive)
  (comment-or-uncomment-region
   (region-active-if (region-beginning) (line-beginning-position))
   (region-active-if (region-end) (line-end-position)))
  (if-fn% 'next-logical-line nil
          (next-logical-line)
    (forward-line)))

;; toggle comment key strike
(define-key (current-global-map) (kbd "C-c ;") #'toggle-comment)

;; auto org-mode
(version-supported-when >= 23
  (add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode)))


;; :edit
(when (self-spec->*env-spec :edit :allowed)
  ;; default tab-width
  (setq-default tab-width (self-spec->*env-spec :edit :tab-width))
  ;; default auto-save-default
  (setq auto-save-default (self-spec->*env-spec :edit :auto-save-default)))


;; find-tag and pop-tag-mark
;; same as Emacs22+
(unless-fn% 'xref-find-definitions 'xref
  (when-fn% 'pop-tag-mark 'etags
    (with-eval-after-load 'etags
      ;; define keys for `pop-tag-mark' and `tags-loop-continue'
      (define-key% (current-global-map) (kbd "M-,") #'pop-tag-mark)
      (define-key% (current-global-map) (kbd "M-*") #'tags-loop-continue))))


(version-supported-when > 24.4
  ;; fix: no quit key to hide *Messages* buffer
  ;; [DEL] for `scroll-down'
  ;; [SPC] for `scroll-up'
  (with-current-buffer (get-buffer "*Messages*")
    (if-fn% 'read-only-mode nil
            (read-only-mode 1)
      (toggle-read-only t))
    (local-set-key (kbd "q") #'quit-window)
    (local-set-key (kbd "DEL") #'scroll-down)
    (local-set-key (kbd "SPC") #'scroll-up)))


(version-supported-when > 24
  ;; fix: `uniquify' may not be autoloaded on ancient Emacs.
  (when% (let ((x byte-compile-warnings))
           (setq byte-compile-warnings nil)
           (prog1 (require 'uniquify nil t)
             (setq byte-compile-warnings x)))
    (require 'uniquify)
    (setq uniquify-buffer-name-style 'post-forward-angle-brackets)))


(defmacro pprint (form)
  "Insert a pretty-printed rendition of a Lisp FORM in current buffer."
  `(cl-prettyprint ,form))
(autoload 'cl-prettyprint "cl-extra")


;; abbreviated `eshell' prompt
(version-supported-when > 23
  (when% (and (require 'em-prompt) (require 'em-dirs))
    (setq eshell-prompt-function
          #'(lambda ()
              (concat (abbreviate-file-name (eshell/pwd))
                      (if (= (user-uid) 0) " # " " $ "))))))


;; Mark thing at point

(eval-when-compile
  
  (defmacro _mark-thing@ (begin end)
    "Mark THING at point."
    `(progn
       ,begin
       (set-mark (point))
       ,end)))

(defun mark-symbol@ ()
  "Mark symbol at point."
  (interactive)
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (when bounds
      (_mark-thing@ (goto-char (car bounds))
                    (goto-char (cdr bounds))))))

(defun mark-filename@ ()
  "Mark filename at point."
  (interactive)
  (let ((bounds (bounds-of-thing-at-point 'filename)))
    (when bounds
      (_mark-thing@ (goto-char (car bounds))
                    (goto-char (cdr bounds))))))

(defun mark-word@ ()
  "Mark filename at point."
  (interactive)
  (let ((bounds (bounds-of-thing-at-point 'word)))
    (when bounds
      (_mark-thing@ (goto-char (car bounds))
                    (goto-char (cdr bounds))))))

(defun mark-line@ (&optional arg)
  "Mark line at point.
If ARG is non-nil should mark the whole line."
  (interactive "P")
  (_mark-thing@ (if arg
                    (back-to-indentation)
                  (beginning-of-line))
                (end-of-line)))

(defun mark-list@ ()
  "Mark list at point.
More accurate than `mark-sexp'."
  (interactive)
  (let ((bounds (bounds-of-thing-at-point 'list)))
    (when bounds
      (_mark-thing@ (goto-char (car bounds))
                    (goto-char (cdr bounds))))))

(defun mark-defun@ ()
  "Mark function at point.
More accurate than `mark-defun'."
  (interactive)
  (let ((bounds (bounds-of-thing-at-point 'defun)))
    (when bounds
      (_mark-thing@ (goto-char (car bounds))
                    (goto-char (cdr bounds))))))

(unless-fn% 'thing-at-point-bounds-of-list-at-point 'thingatpt
  ;; fix the wrong behavior of (bounds-of-thing-at-point 'list) on
  ;; ancient Emacs.
  (defun thing-at-point-bounds-of-list-at-point ()
    "Return the bounds of the list at point.
 [Internal function used by `bounds-of-thing-at-point'.]"
    (save-excursion
      (let* ((st (parse-partial-sexp (point-min) (point)))
             (beg (or (and (eq 4 (car (syntax-after (point))))
                           (not (nth 8 st))
                           (point))
                      (nth 1 st))))
        (when beg
          (goto-char beg)
          (forward-sexp)
          (cons beg (point))))))
  
  (put 'list 'bounds-of-thing-at-point
       'thing-at-point-bounds-of-list-at-point))

(unless% (or (get 'defun 'beginning-of-defun)
             (get 'defun 'end-of-defun))
  ;; fix wrong behavior (bounds-of-thing-at-point 'defun) on ancient
  ;; Emacs.
  (put 'defun 'beginning-op 'beginning-of-defun)
  (put 'defun 'end-op       'end-of-defun)
  (put 'defun 'forward-op   'end-of-defun))


(define-key (current-global-map) (kbd "C-c m s") #'mark-symbol@)
(define-key (current-global-map) (kbd "C-c m f") #'mark-filename@)
(define-key (current-global-map) (kbd "C-c m w") #'mark-word@)
(define-key (current-global-map) (kbd "C-c m l") #'mark-line@)
(define-key (current-global-map) (kbd "C-c m a") #'mark-list@)
(define-key (current-global-map) (kbd "C-c m d") #'mark-defun@)


;; Makes killing/yanking interact with the clipboard

;; Save clipboard strings into kill ring before replacing them.
;; When one selects something in another program to paste it into Emacs,
;; but kills something in Emacs before actually pasting it,
;; this selection is gone unless this variable is non-nil
;; I'm actually not sure what this does but it's recommended?
;; http://emacswiki.org/emacs/CopyAndPaste
(version-supported-if
    <= 24.1
    (setq% select-enable-clipboard t)
  (setq% x-select-enable-clipboard t))
(version-supported-if
    <= 25.1
    (setq% select-enable-primary t 'select)
  (setq% x-select-enable-primary t 'select))

(terminal-supported-p
  (platform-supported-unless 'windows-nt
    (eval-when-compile
      
      (defmacro _defun-x-select-text* (bin &rest args)
        "Define `x-select-text*'"
        `(defun x-select-text* (text &optional _unused_)
           "Copy TEXT to system clipboard."
           (with-temp-buffer
             (insert text)
             (call-process-region (point-min) (point-max)
                                  ,bin
                                  nil 0 nil
                                  ,@args))))

      (defmacro _defun-x-selection-value* (bin &rest args)
        "Define `x-selection-value*'"
        `(defun x-selection-value* ()
           "Paste from system clipboard."
           (let ((out (shell-command* ,bin ,@args)))
             (when (zerop (car out))
               (cdr out)))))

      (defmacro _enable-x-select-clipboard! ()
        "Enable `x-select-clipboard'"
        `(progn
           (setq interprogram-cut-function #'x-select-text*)
           (setq interprogram-paste-function #'x-selection-value*)))))
  
  (platform-supported-when 'darwin
    (_defun-x-select-text* "pbcopy")
    (_defun-x-selection-value* "pbpaste")
    (_enable-x-select-clipboard!))

  (platform-supported-when 'gnu/linux
    (when% (executable-find% "xsel")
      (_defun-x-select-text* "xsel" "--clipboard" "--input")
      (_defun-x-selection-value* "xsel" "--clipboard" "--output")
      (_enable-x-select-clipboard!))))

 ;; end of mark thing at point


;; isearch


(eval-when-compile

  (defmacro _symbol@ ()
    "Return the symbol at point."
    `(let ((ss (region-active-if
                   (prog1
                       (buffer-substring (region-beginning)
                                         (region-end))
                     (setq mark-active nil))
                 (thing-at-point 'symbol))))
       (and (stringp ss) (substring-no-properties ss))))
  
  (defmacro _defun-isearch-forward-or-backward (direction)
    "Define `isearch-forward*' or `isearch-backward*'"
    (let ((fn (intern (format "isearch-%s*" (symbol-name direction))))
          (dn (intern (format "isearch-%s" (symbol-name direction)))))
      `(defun ,fn (&optional arg)
         ,(format "Do incremental region or symbol search %s."
                  `,(symbol-name direction))
         (interactive "P")
         (,dn nil 1)
         (when (not arg)
           (let ((s (_symbol@)))
             (when s (isearch-yank-string s))))))))


(_defun-isearch-forward-or-backward forward)
(_defun-isearch-forward-or-backward backward)

(define-key (current-global-map) (kbd "C-s") #'isearch-forward*)
(define-key (current-global-map) (kbd "C-r") #'isearch-backward*)


 ;; end of isearch


;; hippie

(with-eval-after-load 'hippie-exp
  (setq% hippie-expand-try-functions-list
         '(try-complete-file-name-partially
           try-complete-file-name
           try-expand-all-abbrevs
           ;; try-expand-list
           ;; try-expand-line
           try-expand-dabbrev
           try-expand-dabbrev-all-buffers
           try-expand-dabbrev-from-kill
           try-complete-lisp-symbol-partially
           try-complete-lisp-symbol)
         'hippie-exp))


;; Key binding to use "hippie expand" for text autocompletion
;; http://www.emacswiki.org/emacs/HippieExpand
(define-key (current-global-map) (kbd "M-/") #'hippie-expand)

 ;; end of hippie

(defun find-web@ (engine)
  "Find web via search ENGINE."
  (interactive "sfind-web@ bing|duck|google|so: ")
  (let ((q (_symbol@)))
    (when q
      (browse-url
       (concat (cadr
                (assoc** (or (let ((s (string-trim>< engine)))
                               (and (not (string= "" s)) s))
                             "bing")
                         '(("bing"
                            "https://www.bing.com/search?q=")
                           ("duck"
                            "https://duckduckgo.com/search?q=")
                           ("google"
                            "https://www.google.com/search?q=")
                           ("so"
                            "https://stackoverflow.com/search?q="))
                         #'string=))
               q)))))

(define-key (current-global-map) (kbd "C-c f w") #'find-web@)

 ;; end of `find-web@'

;; open-*-line fn
;; control indent or not of `open-next-line' and `open-previous-line'.
;; see also: https://www.emacswiki.org/emacs/OpenNextLine

(defun open-next-line (n)
  "Move to the next line and then open N lines, like vi's o command.
See also `open-line'."
  (interactive "*p")
  (end-of-line)
  (open-line n)
  (forward-line 1)
  (indent-according-to-mode))

(defun open-previous-line (n)
  "Open N lines above the current one, like vi's O command.
See also `open-line' and `split-line'."
  (interactive "*p")
  (beginning-of-line)
  (open-line n)
  (indent-according-to-mode))

(defun toggle-open-line-indent! (&optional arg)
  "Toggle whether indent or not when `open-line' or `split-line'.
With prefix argument ARG, indent as default when ARG is non-nil."
  (interactive "P")
  (let ((indent? (cond ((or arg
                            (eq 'open-line
                                (lookup-key
                                 (current-global-map) (kbd "C-o"))))
                        (cons #'open-next-line #'open-previous-line))
                       (t (cons #'open-line #'split-line)))))
    (define-key (current-global-map) (kbd "C-o") (car indent?))
    (define-key (current-global-map) (kbd "C-M-o") (cdr indent?))
    (message "indent open-line %s"
             (if (eq #'open-line (car indent?))
                 "disabled"
               "enabled"))))

(toggle-open-line-indent! t)

 ;; end of open-*-line


;; open emacs source in `view-mode'
(with-eval-after-load 'help-mode
  (let ((help-fn (button-type-get 'help-function-def 'help-function)))
    (button-type-put
     'help-function-def 'help-function
     `(lambda (fn file)
        (funcall ,help-fn fn file)
        (view-mode t)))))


;; tramp
(with-eval-after-load 'tramp
  (when% (executable-find% "ssh")
    ;; ssh faster than scp on ancient Emacs?
    (setq% tramp-default-method "ssh")))


;; end of file
