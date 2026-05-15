(require 'org)
(require 'ob)

(let ((file (car command-line-args-left)))
  (unless file
    (error "expected a .org file argument"))
  (find-file file)
  (org-babel-execute-buffer)
  (save-buffer))
