;;;; -*- lexical-binding:t -*-
;;;;
;; More reasonable Emacs on MacOS, Windows and Linux
;; https://github.com/junjiemars/.emacs.d
;;;;
;; sample-self-env-spec.el: specify the private environment specs
;; 
;;;;



;; Basic Emacs' environment configurations


(def-self-env-spec
  :theme (list :name 'dracula
               :custom-theme-directory (emacs-home* "theme/")
               :compile nil ;; expert option
               :allowed t)

  :font (list :name (if-platform% 'darwin
                        "Monaco"
                      (if-platform% 'windows-nt
                          "Consolas"
                        "DejaVu Sans Mono"))
              :size 17
              :allowed nil)

  :glyph-font (list `(:name ,(if-platform% 'darwin
                                 "Hack"
                               (if-platform% 'windows-nt
                                   "Courier New"
                                 "DejaVu Sans Mono"))
                            :size 17
                            :scale nil
                            :scripts (greek)
                            :allowed nil)
                    `(:name ,(if-platform% 'darwin
                                 "PingFang"
                               (if-platform% 'windows-nt
                                   "Microsoft YaHei"
                                 "Noto Sans"))
                            :size 12
                            :scale nil
                            :scripts (han)
                            :allowed nil))
  
  :shell (list :copy-vars `("PATH")
               :spin-vars nil ;; `(("ZZZ" . "123"))
               :options '("-i" "2>/dev/null") ;; '("--login")
               :exec-path t
               :shell-file-name (executable-find% "bash")
               :prompt (list :zsh "%n@%m:%~ %# "
                             :bash "\\u@\\h:\\w\\$ ")
               :allowed nil)
  
  :desktop (list :files-not-to-save
                 "\.t?gz$\\|\.zip$\\|\.desktop\\|~$\\|^/sudo:\\|^/ssh[x]?:\\|\.elc$"
                 :buffers-not-to-save "^TAGS\\|\\.log"
                 :modes-not-to-save
                 '(dired-mode fundamental-mode eww-mode rmail-mode)
                 :restore-eager 8
                 :allowed nil)
  
  :eshell (list :visual-commands '("mtr")
                :destroy-buffer-when-process-dies nil
                :visual-subcommands nil ;; '(("git" "log"))
                :visual-options nil
                :allowed nil)
  
  :socks (list :port 32000
               :server "127.0.0.1"
               :version 5
               :allowed nil)
  
  :package (list :remove-unused nil
                 :package-check-signature 'allow-unsigned
                 :allowed nil)

  :edit (list :tab-width 2
              :standard-indent 2
              :auto-save-default nil
              :disable-indent-tabs-mode '(c-mode-common-hook
                                          sh-mode-hook
                                          emacs-lisp-mode-hook)
              :narrow-to-region nil
              :allowed t)
  
  ) ;; end of `def-self-env-spec'
