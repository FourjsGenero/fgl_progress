IMPORT FGL fglprogress

DEFINE rec RECORD
           icon STRING,
           title STRING,
           comment STRING,
           vmin DECIMAL(20,5),
           vmax DECIMAL(20,5),
           vstp DECIMAL(20,5),
           waitsecs SMALLINT,
           confirm BOOLEAN,
           canintr BOOLEAN,
           showtimefmt STRING,
           showtimerem BOOLEAN,
           showvalfmt STRING,
           refreshtm STRING
       END RECORD


MAIN
    DEFER INTERRUPT

    OPEN FORM f1 FROM "fglprogress_demo"
    DISPLAY FORM f1

    LET rec.icon = "fourjs_logo.png"
    LET rec.title = "My application"
    LET rec.comment = "Processing data..."
    LET rec.vmin = -0.20
    LET rec.vmax = 0.50
    LET rec.vstp = 0.05
    LET rec.waitsecs = 1
    LET rec.confirm = TRUE
    LET rec.canintr = TRUE
    LET rec.showtimefmt = NULL
    LET rec.showtimerem = FALSE
    LET rec.showvalfmt = NULL
    LET rec.refreshtm = "0.500"

    INPUT BY NAME rec.* WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED)

        ON ACTION clear
           LET rec.vmin = NULL
           LET rec.vmax = NULL
           LET rec.vstp = NULL
           LET rec.waitsecs = 0

        ON ACTION test
           IF length(rec.vmin)==0 OR length(rec.vmax)==0 THEN
              CALL test_infinite( )
           ELSE
              CALL test_finite( )
           END IF

    END INPUT

END MAIN

FUNCTION test_infinite()
    DEFINE p fglprogress.progress_dialog

    CALL p.initializeInfinite(rec.title,rec.comment)
    CALL p.setIcon(rec.icon)
    CALL p.withConfirmation(rec.confirm)
    IF NOT rec.canintr THEN
       IF NOT mbox_yn("Progress","Do you really want to start an infinite loop without interruption button?") THEN
          RETURN
       END IF
       CALL p.withInterruption(rec.canintr)
    END IF
    CALL p.setExecTimeDisplayFormat(rec.showtimefmt)
    CALL p.withRemainingExecTimeDisplay(rec.showtimerem)
    CALL p.setValueDisplayFormat(rec.showvalfmt)
    CALL p.setRefreshInterval(rec.refreshtm) -- Converted from string

    CALL p.open()
    WHILE TRUE
        IF p.interrupted() THEN
           IF NOT mbox_yn("Progress","Process interrupted by user, continue?") THEN
              EXIT WHILE
           END IF
        END IF
        CALL p.stepInfinite()
        IF p.getValue() > 97 THEN EXIT WHILE END IF
        IF rec.waitsecs>0 THEN SLEEP rec.waitsecs END IF
    END WHILE
    IF p.wasCanceled() THEN
       ERROR "Process canceled..."
    ELSE
       CALL p.setComment("Done.")
       CALL p.show()
    END IF
    CALL p.close()
    CALL p.free()

END FUNCTION

FUNCTION test_finite()
    DEFINE p fglprogress.progress_dialog

    CALL p.initialize(rec.title,rec.comment,rec.vmin,rec.vmax,rec.vstp)
    CALL p.setIcon(rec.icon)
    LET rec.vstp = p.getStep() -- Get default from fglprogress if NULL specified
    CALL p.withConfirmation(rec.confirm)
    CALL p.withInterruption(rec.canintr)
    CALL p.setExecTimeDisplayFormat(rec.showtimefmt)
    CALL p.withRemainingExecTimeDisplay(rec.showtimerem)
    CALL p.setValueDisplayFormat(rec.showvalfmt)
    CALL p.setRefreshInterval(rec.refreshtm) -- Converted from string

    CALL p.open()
    WHILE TRUE
        IF p.interrupted() THEN
           IF NOT mbox_yn("Progress","Process interrupted by user, continue?") THEN
              EXIT WHILE
           END IF
        END IF
        IF rec.comment THEN
           IF p.getValue() >= rec.vmin+((rec.vmax-rec.vmin)/2) THEN
              CALL p.setComment("We are now half way...")
           END IF
           IF p.getValue() > rec.vmax * 0.95 THEN
              CALL p.setComment("Finishing...")
           END IF
        END IF
        IF NOT p.step() THEN EXIT WHILE END IF
        IF rec.waitsecs>0 THEN SLEEP rec.waitsecs END IF
    END WHILE
    IF p.wasCanceled() THEN
       ERROR "Process canceled..."
    ELSE
       CALL p.setComment("Done.")
       CALL p.show()
    END IF
    CALL p.close()
    CALL p.free()

END FUNCTION

FUNCTION mbox_yn(ttl STRING, cmt STRING)
    DEFINE r BOOLEAN
    MENU ttl ATTRIBUTES(STYLE="dialog",COMMENT=cmt)
        COMMAND "Yes" LET r = TRUE EXIT MENU
        COMMAND "No"  LET r = FALSE EXIT MENU
    END MENU
    RETURN r
END FUNCTION 
