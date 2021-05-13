#+ Progress dialog
#+

IMPORT util

PUBLIC TYPE progress_dialog_value_type DECIMAL(32,6)
PRIVATE CONSTANT min_disp_interval INTERVAL SECOND TO FRACTION(3) = INTERVAL(0.300) SECOND TO FRACTION(3)

PUBLIC TYPE progress_dialog RECORD
    initialized BOOLEAN,
    title STRING,
    icon STRING,
    comment STRING,
    vmin progress_dialog_value_type,
    vmax progress_dialog_value_type,
    vstp progress_dialog_value_type,
    value progress_dialog_value_type,
    confirm BOOLEAN,
    canintr BOOLEAN,
    sqlintr BOOLEAN,
    infinite BOOLEAN,
    dispval INTEGER,
    showtimefmt STRING,
    showtimerem BOOLEAN,
    showvalfmt STRING,
    canceled BOOLEAN,
    ts_start DATETIME YEAR TO FRACTION(3),
    ts_last DATETIME YEAR TO FRACTION(3),
    ts_infinite DATETIME YEAR TO FRACTION(3),
    ts_disp_interval INTERVAL SECOND TO FRACTION(3),
    window ui.Window,
    window_id STRING,
    form ui.Form
END RECORD

PRIVATE DEFINE _window_ids DYNAMIC ARRAY OF STRING
PRIVATE CONSTANT MAX_WINDOWS = 5

PRIVATE FUNCTION _fatal_error(msg STRING) RETURNS()
    DISPLAY "fglprogress: Fatal error: ", msg
    EXIT PROGRAM 1
END FUNCTION

PRIVATE FUNCTION _window_ids_new() RETURNS STRING
    DEFINE x INTEGER
    LET x = _window_ids.getLength()
    IF x==MAX_WINDOWS THEN
       CALL _fatal_error("All WINDOWs are used")
    ELSE
       LET x = x + 1
    END IF
    LET _window_ids[x] = SFMT("win%1", x)
    RETURN _window_ids[x]
END FUNCTION

PRIVATE FUNCTION _window_ids_del(name STRING)
    DEFINE x INTEGER
    LET x = _window_ids.search(NULL,name)
    IF x > 0 THEN
       CALL _window_ids.deleteElement(x)
    ELSE
       CALL _fatal_error(SFMT("Unknown WINDOW %1",name))
    END IF
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _check_initialized() RETURNS()
    IF NOT this.initialized THEN
        CALL _fatal_error("Not initialized")
    END IF
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _check_open(on BOOLEAN) RETURNS()
    CALL this._check_initialized()
    IF on AND this.window IS NULL THEN
        CALL _fatal_error("Not open")
    END IF
    IF NOT on AND this.window IS NOT NULL THEN
        CALL _fatal_error("Not closed")
    END IF
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _check_infinite(on BOOLEAN) RETURNS()
    CALL this._check_initialized()
    IF on AND NOT this.infinite THEN
        CALL _fatal_error("Progress has not limits")
    END IF
    IF NOT on AND this.infinite THEN
        CALL _fatal_error("Progress is not infinite")
    END IF
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _check_vstp() RETURNS()
    CALL this._check_initialized()
    IF this.vstp IS NULL THEN
        CALL _fatal_error("Step value is NULL")
    END IF
END FUNCTION

#+ Initializes a progress dialog object for a known range of values.
#+
#+ @param title The title of the progress window.
#+ @param comment The comment to be displayed in the progress window.
#+ @param vmin The minimum value for the progress bar.
#+ @param vmax The maximum value for the progress bar.
#+ @param vstp The step value to be used by the step() method.
#+
PUBLIC FUNCTION (this progress_dialog) initialize( title STRING, comment STRING,
                                                   vmin progress_dialog_value_type,
                                                   vmax progress_dialog_value_type,
                                                   vstp progress_dialog_value_type )
                                       RETURNS()
    IF this.initialized THEN
       CALL _fatal_error("Already in used")
    END IF
    LET this.initialized = TRUE
    LET this.title = title
    LET this.comment = comment
    LET this.confirm = FALSE
    LET this.canintr = TRUE
    LET this.sqlintr = FALSE
    LET this.ts_disp_interval = min_disp_interval
    LET this.value = NULL
    IF vmin IS NOT NULL AND vmax IS NOT NULL THEN
        LET this.infinite = FALSE
        IF vmax <= vmin THEN
            CALL _fatal_error("Max value must be greater as min value")
        END IF
        LET this.vmin = vmin
        LET this.vmax = vmax
        IF vstp IS NOT NULL THEN
           LET this.vstp = vstp
        ELSE
           LET this.vstp = (this.vmax - this.vmin) / 10
        END IF
    ELSE
        LET this.infinite = TRUE
        LET this.vmin = 1
        LET this.vmax = 100
        LET this.vstp = NULL -- Computed in _step()
    END IF
END FUNCTION

#+ Initializes a progress dialog object for a unknown range of values.
#+
#+ @param title The title of the progress window.
#+ @param comment The comment to be displayed in the progress window.
#+
PUBLIC FUNCTION (this progress_dialog) initializeInfinite( title STRING, comment STRING)
                                       RETURNS()
    CALL this.initialize(title, comment, NULL, NULL, NULL)
END FUNCTION

#+ Defines the time interval to refresh the display.
#+
#+ The show(), progress() or step()/stepInfinite() methods may be called very often.
#+ To avoid to many network roundtrips with the front-end, the module defines a
#+ default refresh internal of 100 milliseconds.
#+
#+ If the refresh time interval is NULL, the display is refreshed each time one of
#+ the above methods are used.
#+
#+ @param itv The display refresh interval.
#+
PUBLIC FUNCTION (this progress_dialog) setRefreshInterval(itv INTERVAL SECOND TO FRACTION(3)) RETURNS ()
    CALL this._check_initialized()
    IF itv < min_disp_interval THEN
       CALL _fatal_error(SFMT("Minimal display interval is %1", min_disp_interval))
    END IF
    LET this.ts_disp_interval = itv
END FUNCTION

#+ Sets the image to be displayed as icon.
#+
#+ @param resource The filename/URL of the image resource.
#+
PUBLIC FUNCTION (this progress_dialog) setIcon(resource STRING) RETURNS ()
    CALL this._check_initialized()
    LET this.icon = resource
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _get_exec_time() RETURNS STRING
    DEFINE pd, pr DECIMAL(10)
    DEFINE et INTERVAL HOUR(4) TO FRACTION(3)
    LET et = this.ts_last - this.ts_start
    IF this.showtimerem THEN
        IF this.infinite THEN
           RETURN NULL
        END IF
        LET pd = (this.value - this.vmin) / (this.vmax - this.vmin)
        LET pr = 1 - pd
        LET et = (et / pd) * pr
    END IF
    RETURN util.Interval.format(et, this.showtimefmt)
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _sync_deco() RETURNS()
    DEFINE exectime, dispvaltxt STRING
    -- Image
    IF length(this.icon)==0 THEN
        CALL this.form.setFieldHidden("icon", 1)
    ELSE
        CALL this.form.setFieldHidden("icon", 0)
        DISPLAY BY NAME this.icon
    END IF
    -- Comment
    IF length(this.comment)==0 THEN
        CALL this.form.setFieldHidden("comment", 1)
    ELSE
        CALL this.form.setFieldHidden("comment", 0)
        DISPLAY BY NAME this.comment
    END IF
    -- Execution time
    IF length(this.showtimefmt)==0 THEN
        CALL this.form.setFieldHidden("exectime", 1)
    ELSE
        CALL this.form.setFieldHidden("exectime", 0)
        LET exectime = this._get_exec_time()
        DISPLAY BY NAME exectime
    END IF
    -- Current value
    IF length(this.showvalfmt)==0 OR this.infinite THEN
        CALL this.form.setFieldHidden("dispvaltxt", 1)
    ELSE
        CALL this.form.setFieldHidden("dispvaltxt", 0)
        IF this.showvalfmt == "percentage" THEN
            LET dispvaltxt = SFMT("%1 %%",this.dispval)
        ELSE
            LET dispvaltxt = this.value USING this.showvalfmt
        END IF
        DISPLAY BY NAME dispvaltxt
    END IF
    -- Buttons
    CALL this.form.setElementHidden("interrupt", IIF(this.canintr,0,1))
    CALL this.form.setElementHidden("close", IIF(this.confirm,0,1))
END FUNCTION

#+ Sets the flag to get an OK button for confirmation when done.
#+
#+ @param on TRUE = with OK button, FALSE = without.
#+
PUBLIC FUNCTION (this progress_dialog) withConfirmation(on BOOLEAN)
    CALL this._check_initialized()
    LET this.confirm = on
END FUNCTION

#+ Sets the flag to get a Cancel button to interrupt the process.
#+
#+ @param on TRUE = with Cancel button, FALSE = without.
#+
PUBLIC FUNCTION (this progress_dialog) withInterruption(on BOOLEAN)
    CALL this._check_initialized()
    LET this.canintr = on
END FUNCTION

#+ Sets the flag to enable SQL interruption automatically.
#+
#+ The user interruption option must be enabled by withInterruption(TRUE).
#+
#+ When calling the open() method, OPTIONS SQL INTERRUPT ON is executed.
#+ When calling the close() method, OPTIONS SQL INTERRUPT OFF is executed.
#+
#+ @param on TRUE = with SQL interruption, FALSE = without.
#+
PUBLIC FUNCTION (this progress_dialog) withSqlInterruption(on BOOLEAN)
    CALL this._check_initialized()
    LET this.sqlintr = on
END FUNCTION

#+ Sets the format to show the execution time.
#+
#+ @param fmt The util.Intervale.format() style format, like "%H:%M:%S"
#+
PUBLIC FUNCTION (this progress_dialog) setExecTimeDisplayFormat(fmt STRING)
    CALL this._check_initialized()
    LET this.showtimefmt = fmt
END FUNCTION

#+ Sets the flag to show the remaining execution time.
#+
#+ The time format must be specified with setExecTimeDisplayFormat().
#+
#+ @param on TRUE to show the execution time as remaining time.
#+
PUBLIC FUNCTION (this progress_dialog) withRemainingExecTimeDisplay(on BOOLEAN)
    CALL this._check_initialized()
    LET this.showtimerem = on
END FUNCTION

#+ Sets the format to show the current value.
#+
#+ Note that in infinite mode, no value will be displayed.
#+
#+ @param fmt Can be "percentage" or a USING format like "----&.&&".
#+
PUBLIC FUNCTION (this progress_dialog) setValueDisplayFormat(fmt STRING)
    CALL this._check_initialized()
    LET this.showvalfmt = fmt
END FUNCTION

#+ Returns TRUE if the progress is infinite.
PUBLIC FUNCTION (this progress_dialog) isInfinite() RETURNS BOOLEAN
    CALL this._check_initialized()
    RETURN this.infinite
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _check_combinations() RETURNS ()
    IF this.sqlintr AND NOT this.canintr THEN
       CALL _fatal_error("SQL interruption on but user interruption is off")
    END IF
END FUNCTION

#+ Opens the progress window.
PUBLIC FUNCTION (this progress_dialog) open() RETURNS()
    CALL this._check_open(FALSE)
    CALL this._check_combinations()
    LET this.window_id = _window_ids_new() -- can fail
    LET int_flag = FALSE
    LET this.canceled = FALSE
    LET this.ts_start = CURRENT
    LET this.ts_last = this.ts_start
    LET this.ts_infinite = this.ts_start
    IF this.sqlintr THEN
       OPTIONS SQL INTERRUPT ON
    END IF
    CASE this.window_id
    WHEN "win1" OPEN WINDOW __fglprogress_1 WITH FORM "fglprogress" ATTRIBUTES(STYLE = "dialog2", TEXT=this.title)
    WHEN "win2" OPEN WINDOW __fglprogress_2 WITH FORM "fglprogress" ATTRIBUTES(STYLE = "dialog2", TEXT=this.title)
    WHEN "win3" OPEN WINDOW __fglprogress_3 WITH FORM "fglprogress" ATTRIBUTES(STYLE = "dialog2", TEXT=this.title)
    WHEN "win4" OPEN WINDOW __fglprogress_4 WITH FORM "fglprogress" ATTRIBUTES(STYLE = "dialog2", TEXT=this.title)
    WHEN "win5" OPEN WINDOW __fglprogress_5 WITH FORM "fglprogress" ATTRIBUTES(STYLE = "dialog2", TEXT=this.title)
    END CASE
    LET this.window = ui.Window.getCurrent()
    LET this.form = this.window.getForm()
    CALL this._sync_deco()
    CALL this.show()
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _set_value(value progress_dialog_value_type) RETURNS()
    DEFINE vlen progress_dialog_value_type
    CALL this._check_open(TRUE)
    IF value >= this.vmin AND value <= this.vmax THEN
        LET this.value = value
    ELSE
        IF value < this.vmin THEN
            LET this.value = this.vmin
        ELSE
            LET this.value = this.vmax
        END IF
    END IF
    LET vlen = (this.vmax - this.vmin)
    LET this.dispval = 100 * ((value - this.vmin) / vlen)
END FUNCTION

#+ Sets the progressbar value without display refresh.
#+
#+ @param value The value to be set in the progressbar.
#+
PUBLIC FUNCTION (this progress_dialog) setValue(value progress_dialog_value_type) RETURNS()
    CALL this._check_infinite(FALSE)
    CALL this._set_value(value)
END FUNCTION

#+ Returns current progress value.
PUBLIC FUNCTION (this progress_dialog) getValue() RETURNS progress_dialog_value_type
    CALL this._check_initialized()
    RETURN this.value
END FUNCTION

#+ Returns progress start value.
PUBLIC FUNCTION (this progress_dialog) getValueMin() RETURNS progress_dialog_value_type
    CALL this._check_initialized()
    RETURN this.vmin
END FUNCTION

#+ Returns progress end value.
PUBLIC FUNCTION (this progress_dialog) getValueMax() RETURNS progress_dialog_value_type
    CALL this._check_initialized()
    RETURN this.vmax
END FUNCTION

#+ Returns progress step value.
PUBLIC FUNCTION (this progress_dialog) getStep() RETURNS progress_dialog_value_type
    CALL this._check_initialized()
    RETURN this.vstp
END FUNCTION

#+ Returns TRUE if the progress was interrupted by user (INT_FLAG==TRUE).
#+
#+ The method resets INT_FLAG to FALSE, so callers do not have to reset it.
#+
PUBLIC FUNCTION (this progress_dialog) interrupted() RETURNS BOOLEAN
    CALL this._check_open(TRUE)
    IF this.canintr AND int_flag THEN
       LET int_flag = FALSE
       LET this.canceled = TRUE
       RETURN TRUE
    ELSE
       RETURN FALSE
    END IF
END FUNCTION

#+ Returns TRUE if the progress was canceled.
PUBLIC FUNCTION (this progress_dialog) wasCanceled() RETURNS BOOLEAN
    CALL this._check_initialized()
    RETURN this.canceled
END FUNCTION

#+ Sets the comment without display refresh.
#+
#+ @param comment The comment to be displayed in the progress window.
#+
PUBLIC FUNCTION (this progress_dialog) setComment(comment STRING) RETURNS()
    CALL this._check_initialized()
    LET this.comment = comment
END FUNCTION

#+ Returns current progress comment.
PUBLIC FUNCTION (this progress_dialog) getComment() RETURNS STRING
    CALL this._check_initialized()
    RETURN this.comment
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _refresh_display() RETURNS()
    CASE this.window_id
    WHEN "win1" CURRENT WINDOW IS __fglprogress_1
    WHEN "win2" CURRENT WINDOW IS __fglprogress_2
    WHEN "win3" CURRENT WINDOW IS __fglprogress_3
    WHEN "win4" CURRENT WINDOW IS __fglprogress_4
    WHEN "win5" CURRENT WINDOW IS __fglprogress_5
    END CASE
    CALL this._sync_deco()
    DISPLAY BY NAME this.dispval
    CALL ui.Interface.refresh()
END FUNCTION

#+ Displays current value in progress dialog window.
#+
#+ The method will not refresh the display, if the last call was done before
#+ the refresh interval has expired.
#+
PUBLIC FUNCTION (this progress_dialog) show() RETURNS()
    DEFINE ts INTERVAL SECOND TO FRACTION(3)
    CALL this._check_open(TRUE)
    IF this.ts_disp_interval IS NOT NULL
    AND this.ts_last != this.ts_start
    AND this.value < this.vmax
    THEN
        LET ts = CURRENT - this.ts_last
        IF ts < this.ts_disp_interval THEN
            RETURN
        END IF
    END IF
    CALL this._refresh_display()
    LET this.ts_last = CURRENT
END FUNCTION

#+ Sets the progress value and refreshes display.
#+
#+ This method is equivalent to setValue() + show().
#+
#+ @param value The value to be set in the progressbar.
#+
PUBLIC FUNCTION (this progress_dialog) progress(value progress_dialog_value_type)
    CALL this._check_open(TRUE)
    CALL this._check_infinite(FALSE)
    CALL this._set_value(value)
    CALL this.show()
END FUNCTION

PRIVATE FUNCTION (this progress_dialog) _step() RETURNS BOOLEAN
    DEFINE r BOOLEAN = TRUE
    DEFINE x progress_dialog_value_type
    CALL this._check_open(TRUE)
    IF this.value IS NULL THEN -- First call
       LET x = this.vmin
       CALL this._set_value(x)
       CALL this.show()
       IF NOT this.infinite THEN
          CALL this._check_vstp()
       ELSE
          LET this.vstp = (this.vmax - this.vmin - x) * 0.10
       END IF
    ELSE
       IF NOT this.infinite THEN
          LET x = this.value + this.vstp
          IF x > this.vmax THEN
              CALL this._set_value(this.vmax)
              CALL this._refresh_display() -- Always sync display
              LET r = FALSE -- Must stop now
          ELSE
              CALL this._set_value(x)
              CALL this.show()
          END IF
       ELSE
          IF CURRENT - this.ts_infinite > this.ts_disp_interval THEN
              LET this.ts_infinite = CURRENT
              LET x = this.value + this.vstp
              CALL this._set_value(x)
              CALL this.show()
              LET this.vstp = (this.vmax - this.vmin - x) * 0.10
          END IF
       END IF
    END IF
    RETURN r
END FUNCTION

#+ Increments the progress value and refreshes display.
#+
#+ Only to be used when the limits are know, as a replacement for progress().
#+
#+ @return TRUE if a new step could be done, FALSE if we reached the end.
#+
PUBLIC FUNCTION (this progress_dialog) step() RETURNS BOOLEAN
    CALL this._check_infinite(FALSE)
    RETURN this._step()
END FUNCTION

#+ Increments the progress value in infinite mode and refreshes display.
#+
#+ Only to show progress when the limits are unknown (specified as NULL).
#+ This method can be called infinitely: The progress bar increments will 
#+ be smaller and smaller, to never reach the end.
#+ Consider displaying execution time in the comment (withExecutionTime())
#+ The display refresh is optimized: If this method is called many times
#+ in a loop, the progress value and the display refresh will be adapted,
#+ to avoid to much network roundtrips with the front-end.
#+
#+ @code
#+ DEFINE p fglprogress.progress_dialog, x INTEGER
#+ ...
#+ CALL p.initialize("title","comment",NULL,NULL,NULL)
#+ CALL p.open()
#+ FOR x=1 TO 100000
#+     CALL p.stepInfinite()
#+ END FOR
#+ CALL p.close()
#+
PUBLIC FUNCTION (this progress_dialog) stepInfinite() RETURNS ()
    DEFINE b BOOLEAN
    CALL this._check_infinite(TRUE)
    LET b = this._step()
END FUNCTION

#+ Cancels the progress session.
#+
#+ Simulates a user interruption. Closing the progress dialog will not
#+ ask for user confirmation if configured.
#+
PUBLIC FUNCTION (this progress_dialog) cancel()
    CALL this._check_open(TRUE)
    LET this.canceled = TRUE
END FUNCTION

#+ Terminates a progress session.
#+
#+ This method closes the progress dialog window.
#+ Progress dialog window can be re-opened with open()
#+
PUBLIC FUNCTION (this progress_dialog) close()
    CALL this._check_open(TRUE)
    IF this.sqlintr THEN
       OPTIONS SQL INTERRUPT OFF
    END IF
    IF this.confirm AND NOT this.canceled THEN
       MENU ""
          ON ACTION close EXIT MENU
       END MENU
    END IF
    CASE this.window_id
    WHEN "win1" CLOSE WINDOW __fglprogress_1
    WHEN "win2" CLOSE WINDOW __fglprogress_2
    WHEN "win3" CLOSE WINDOW __fglprogress_3
    WHEN "win4" CLOSE WINDOW __fglprogress_4
    WHEN "win5" CLOSE WINDOW __fglprogress_5
    END CASE
    CALL _window_ids_del(this.window_id)
    LET this.window_id = 0
    LET this.window = NULL
    LET this.form = NULL
END FUNCTION

#+ Finalizes the progress dialog object usage.
#+
#+ Progress dialog object can be re-initialized with initialize()
#+
PUBLIC FUNCTION (this progress_dialog) free()
    CALL this._check_initialized()
    CALL this._check_open(FALSE)
    INITIALIZE this.* TO NULL
    LET this.initialized = FALSE
END FUNCTION
