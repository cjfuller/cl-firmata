(defpackage :firmata
  (:use :cl)
  (:export #:initialize
           #:cmd
           #:write-bytes
           #:set-pin-mode
           #:digital-write
           #:with-firmata-io))

(in-package :firmata)

(ql:quickload :cl-async)
(ql:quickload :trivial-shell)


(defun alist->hash-table (alist)
  (let ((h (make-hash-table)))
    (mapc (lambda (pair)
            (setf (gethash (car pair) h) (cdr pair)))
          alist)
    h))

(defparameter *commands*
  (alist->hash-table
   '((input . #x00)
     (output . #x01)
     (analog . #x02)
     (pwm . #x03)
     (servo . #x04)
     (on . #x01)
     (off . #x00)
     (report-version . #xf9)
     (system-reset . #xff)
     (digital-message . #x90)
     (analog-message . #xe0)
     (report-analog . #xc0)
     (report-digital . #xd0)
     (pin-mode . #xf4)
     (start-sysex . #xf0)
     (end-sysex . #xf7)
     (capability-query . #x6b)
     (capability-response . #x6c)
     (pin-state-query . #x6d)
     (pin-state-response . #x6e)
     (analog-mapping-query . #x69)
     (analog-mapping-response . #x6a)
     (firmware-query . #x79))))

(defun cmd (sym)
  (gethash sym *commands*))

(defparameter *baudrate* 57600)
(defparameter *firmata-dev* nil)
(defparameter *analog-values* nil)
(defparameter *digital-values* nil)

(defun initialize (dev-fn)
  (trivial-shell:shell-command (format nil "stty -f ~a ~a cs8 cread clocal" dev-fn *baudrate*)))

(defun print+f (item)
  (print item)
  (finish-output))

(defun process-input (data)
  (cond
    ((= (boole boole-and data #xf0) (cmd 'analog-message))
     nil) ;; TODO
    ((= (boole boole-and data #xf0) (cmd 'digital-message))
     (let ((lsb (read-byte *firmata-dev*))
           (msb (read-byte *firmata-dev*))
           (port (boole boole-and data #x0f)))
       (setf (elt *digital-values* port) (boole boole-ior (ash msb 8) lsb))))
    ((= data (cmd 'report-version))
     (format t "Firmata version: ~a.~a" (read-byte *firmata-dev*) (read-byte *firmata-dev*)))))

(defun read-loop ()
   (process-input (read-byte *firmata-dev*))
   (cl-async:with-delay (0)
     (read-loop)))

(defmacro write-bytes (&body bytes)
  `(prog1
     (mapc (lambda (b)
           (write-byte (ldb (byte 8 0) b) *firmata-dev*))
           (list ,@bytes))
     (finish-output *firmata-dev*)))

(defun set-pin-mode (pin mode)
  (write-bytes
   (cmd 'pin-mode)
   pin
   (cmd mode)))

(defun digital-write (pin value)
  (let* ((port (truncate pin 8))
         (pin (mod pin 8))
         (new-value (if (= value (cmd 'off))
                           (boole boole-and
                                  (elt *digital-values* port)
                                  (lognot (ash 1 pin)))
                           (boole boole-ior
                                  (elt *digital-values* port)
                                  (ash 1 pin)))))
    (write-bytes (boole boole-ior (cmd 'digital-message) port)
                 (boole boole-and new-value #x3f)
                 (ash new-value -7))))

(defmacro with-firmata-io (dev-fn &body body)
  `(progn
     (with-open-file
         (*firmata-dev* ,dev-fn
                        :direction :io
                        :if-exists :overwrite
                        :element-type 'unsigned-byte)
       (sleep 1)
       (initialize ,dev-fn)
       (let ((*analog-values* (make-array 16 :initial-element 0))
             (*digital-values* (make-array 16 :initial-element 0)))
         (cl-async:start-event-loop
          (lambda ()
            (cl-async:with-delay (0)
              (read-loop)
              ,@body)))))))

(defun repl ()
  (princ "-> ")
  (finish-output)
  (print+f (eval (read)))
  (repl))

(defun test ()
  (with-firmata-io "/dev/cu.usbmodem1411"
    (cl-async:with-delay (0)
     (write-bytes (cmd 'report-version))
     (digital-write 13 (cmd 'on))
     (sleep 2)
     (digital-write 13 (cmd 'off))
     (repl))))
