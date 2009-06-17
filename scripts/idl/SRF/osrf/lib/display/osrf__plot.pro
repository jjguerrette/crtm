;+
; NAME:
;       OSRF::Plot
;
; PURPOSE:
;       The OSRF::Plot procedure method displays a valid OSRF object.
;
; CALLING SEQUENCE:
;       Obj->[OSRF::]Plot, $
;         Debug=Debug  ; Input keyword
;
; INPUT KEYWORD PARAMETERS:
;       Debug:       Set this keyword for debugging.
;                    If NOT SET => Error handler is enabled. (DEFAULT)
;                       SET     => Error handler is disabled; Routine
;                                  traceback output is enabled.
;                    UNITS:      N/A
;                    TYPE:       INTEGER
;                    DIMENSION:  Scalar
;                    ATTRIBUTES: INTENT(IN), OPTIONAL
;
; INCLUDE FILES:
;       osrf_parameters: Include file containing OSRF specific
;                        parameter value definitions.
;
;       osrf_pro_err_handler: Error handler code for OSRF procedures.
;
; EXAMPLE:
;       Given an instance of a OSRF object,
;
;         IDL> HELP, x
;         X               OBJREF    = <ObjHeapVar8(OSRF)>
;
;       the data is plotted like so:
;
;         IDL> x->Plot
;
; CREATION HISTORY:
;       Written by:     Paul van Delst, 20-Apr-2009
;                       paul.vandelst@noaa.gov
;
;-

PRO OSRF::Plot, $
  OverPlot=OverPlot, $
  Debug=Debug ; Input keyword

  ; Set up
  @color_db
  ; ...OSRF parameters
  @osrf_parameters
  ; ...Set up error handler
  @osrf_pro_err_handler

  ; ...ALL *input* pointers must be associated
  IF ( self->Associated(Debug=Debug) EQ FALSE ) THEN $
    MESSAGE, 'Some or all input OSRF pointer members are NOT associated.', $
             NONAME=MsgSwitch, NOPRINT=MsgSwitch

  psave = !P
  !P.MULTI = [0,self.n_Bands,1]
  FOR i = 0L, self.n_Bands-1L DO BEGIN
    PLOT, *(*self.Frequency)[i], *(*self.Response)[i], $
          TITLE='Band #'+STRTRIM(i+1,2), $
          XTITLE='Frequency', $
          YTITLE='Relative response',yrange=[-0.2,1.2]
    IF ( N_ELEMENTS(OverPlot) GT 0 ) THEN BEGIN
      OPLOT, *(*OverPlot.Frequency)[i], *(*OverPlot.Response)[i], $
             COLOR=RED, PSYM=-4
    ENDIF
  ENDFOR
  !P = psave

END ; PRO OSRF::Plot
