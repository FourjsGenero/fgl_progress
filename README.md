# Genero progress dialog module

## Description

This Genero BDL library provides a type with methods to manage a typical progress dialog window.

![Genero Progress Dialog demo (GDC)](https://github.com/FourjsGenero/fgl_progress/raw/master/docs/fglprogress-screen-001.png)

## License

This library is under [MIT license](./LICENSE)

## Prerequisites

* Genero BDL 3.20.02+
* Genero Browser Client 1.00.52+
* Genero Desktop Client 3.20.02+
* Genero Mobile for Android 1.40.01+
* Genero Mobile for iOS 1.40.01+
* Genero Studio 3.20.02+
* GNU Make

## Features

* Customizable decoration (title, comment, current value, percentage, execution time)
* Supports application data ranges based on DECIMAL(32,6) (no conversion needed)
* Control of the display refresh interval
* Optional interruption of processing (Cancel button)
* Optional end of processing confirmation (Close button)
* Fixed range mode (start value, end value and step value)
* In fixed range mode, can compute a step value automatically if NULL is specified
* Undefined/infinite range mode (no start/end value, just show progress until finished)
* In infinite mode, adapts automatically display refresh to the frequency of step() calls
* Several programming modes (progress(v), step(), stepInfinite())
* Can automatically execute OPTIONS SQL INTERRUPT ON/OFF at open()/close().

## TODO

* Optional image / icon on the left of the comment.
* Multi-line comment
* FUNCTION reference/callback for custom rendering with webcomponent (SVG gauge)

## Code example: Fixed range mode

```
    DEFINE p fglprogress.progress_dialog
    CALL p.initialize("MyApp","Printing order report...",1,maxrows,1)
    CALL p.withConfirmation(TRUE)
    CALL p.withInterruption(TRUE)
    CALL p.setExecTimeDisplayFormat("%S%F3 secs")
    CALL p.setRefreshInterval("0.030")
    CALL p.open()
    WHILE TRUE
        IF p.interrupted() THEN
           IF NOT mbox_yn("Progress","Process interrupted by user, continue?") THEN
              EXIT WHILE
           END IF
        END IF
        IF p.getValue() >= maxrows/2 THEN
           CALL p.setComment("We are now half way...")
        END IF
        CALL p.step()
        ... your processing code goes here ...
    END WHILE
    IF p.wasCanceled() THEN
       ERROR "Process canceled..."
    ELSE
       CALL p.setComment("Done.")
       CALL p.show()
    END IF
    CALL p.close()
    CALL p.free()

```

## Code example: Undefined range mode

```
    DEFINE p fglprogress.progress_dialog
    CALL p.initialize("MyApp","Processing big data...",NULL,NULL,NULL)
    CALL p.withConfirmation(TRUE)
    CALL p.setExecTimeDisplayFormat(TRUE)
    CALL p.open()
    WHILE TRUE
        IF p.interrupted() THEN
           IF NOT mbox_yn("Progress","Process interrupted by user, continue?") THEN
              EXIT WHILE
           END IF
        END IF
        CALL p.stepInfinite()
        ... your processing code goes here ...
    END WHILE
    IF p.wasCanceled() THEN
       ERROR "Process canceled..."
    ELSE
       CALL p.setComment("Done.")
       CALL p.show()
    END IF
    CALL p.close()
    CALL p.free()
```


## Compilation from command line

1. make clean all

## Run in direct mode with GDC

1. make run

## Run with GBC/JGAS

1. make runjgas
2. Open a web browser and enter the URL ``http://localhost:8080/``

## Compilation in Genero Studio

1. Load the *fglprogress_demo.4pw* project
2. Build the project

## Programming API

See [Genero Progress Dialog documentation](http://htmlpreview.github.io/?github.com/FourjsGenero/fgl_progress/raw/master/docs/fglprogress.html)

## Bug fixes:

