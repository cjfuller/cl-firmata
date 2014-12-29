cl-firmata
==========

Firmata protocol library for common lisp.

### Examples

Turn on and off an LED on your arduino:

```lisp
(with-firmata-io "/dev/cu.usbmodem1411"
                 (digital-write 13 (cmd 'on))
                 (digital-write 13 (cmd 'off)))
```

Note that the `with-firmata-io` macro runs the body forms within a cl-async
event loop, so you can use all its functionality there.


