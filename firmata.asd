(asdf:defsystem firmata
  :description "A common lisp firmata protocol (partial) implementation"
  :version "0.0.1"
  :license "MIT"
  :depends-on (:trivial-shell :cl-async)
  :components
  ((:module "src"
            :components
            ((:file "firmata")))))
