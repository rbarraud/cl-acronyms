(defpackage :info.isoraqathedh.acronyms.asdf
  (:use #:cl #:asdf))
(in-package :info.isoraqathedh.acronyms.asdf)

(defsystem acronyms
  :name "Acronym Expander"
  :author "Isoraķatheð Zorethan <isoraqathedh.zorethan@gmail.com>"
  :maintainer "Isoraķatheð Zorethan <isoraqathedh.zorethan@gmail.com>"
  :version "1.0.0"
  :licence "MIT"
  :description "A program that expands an acronym based on grammatical rules."
  :serial t
  :components ((:file "acronyms")))
