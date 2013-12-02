;+
; NAME:
;       oSRF_Writer
;
; PURPOSE:
;       This proceedure is the driver for writing oSRF netCDF files from
;       the original SRF data.
;
; CALLING SEQUENCE:
;       oSRF_Writer, $
;         Sensor_Id                              , $ ; Input
;         Path               = Path              , $ ; Input keyword
;         SensorInfo_File    = SensorInfo_File   , $ ; Input keyword
;         Response_Threshold = Response_Threshold, $ ; Input keyword
;         Version            = Version           , $ ; Input keyword, If not specified, default is OSRF_VERSION
;         No_Plot            = No_Plot           , $ ; Input keyword, If set plotting in driver turned off
;         No_Pause           = No_Pause          , $ ; Input keyword, If set then no pause between plots for channel
;         Debug              = Debug                 ; Input keyword, If set debug error messaging is turned on
;
;
; INPUTS:
;       Sensor_Id:          The Sensor_Id of the oSRF file to be written
;                           UNITS:      N/A
;                           TYPE:       CHARACTER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
; INPUT KEYWORDS:
;       Path:               Location of ASCII SRF *.inp files. If not specified,
;                           the default is "./<sensor_id>"
;                           UNITS:      N/A
;                           TYPE:       CHARACTER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       SensorInfo_File:    The sensor information file to use. If not specified,
;                           the default is "SensorInfo"
;                           UNITS:      N/A
;                           TYPE:       CHARACTER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       Response_Threshold: Specify this keyword to apply a response threshold. SRF
;                           data BELOW this threshold are not used.
;                           UNITS:      N/A
;                           TYPE:       DOUBLE
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       Version:            The version number of the data. If not specified, the
;                           parameter OSRF_VERSION is used.
;                           UNITS:      N/A
;                           TYPE:       INTEGER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       No_Interpolate:     Set this keyword to prevent the SRF data being interpolated
;                           to a fixed frequency grid. If not specified, the data are
;                           interpolated.
;                           UNITS:      N/A
;                           TYPE:       INTEGER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       No_Plot:            Set this keyword to prevent each channel's SRF being plotted.
;                           If not specified, the data are plotted.
;                           UNITS:      N/A
;                           TYPE:       INTEGER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       No_Pause:           Set this keyword to prevent execution pausing after each SRF
;                           data plot. Keyword is ignored if the No_Plot keyword is set.
;                           If not specified, execution pauses.
;                           UNITS:      N/A
;                           TYPE:       INTEGER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN)
;
;       Debug:              Set this keyword for debugging. If set then:
;                           - the error handler for this function is disabled
;                             so that execution halts where the error occurs,
;                           - more verbose output is produced.
;                           UNITS:      N/A
;                           TYPE:       INTEGER
;                           DIMENSION:  Scalar
;                           ATTRIBUTES: INTENT(IN), OPTIONAL
;
;
; INPUT ASCII SRF DATAFILE NAMING CONVENTION:
;       Naming convention for the original data is:
;
;         <sensor_id>[-bN]-<L>.inp
;
;       where
;
;         sensor_id:	Is the sensor identifier, e.g."gmi_gpm" or "imgrD1_g15".
;                       An entry for this sensor id must exist in the SensorInfo
;                       file.
;
;         -bN:          Optional designator for channels that have more than one
;                       passband where N is the passband number, e.g. "-b1", "-b2".
;
;         -L:           The designator for channel L, e.g. "-3" for channel 3,
;                       "-10" for channel 10.
;
;
; DEPENDENCIES:
;       Two additional datafiles are required:
;         1. A SensorInfo file containing an entry for the sensor in question.
;         2. A file called "source.comment" that resides in the same directory
;            as the "*.inp" channel data. The contents of this file will be used
;            for the netCDF file "comment" attribute.
;
;-

PRO oSRF_Writer, $
  Sensor_Id                              , $ ; Input
  Path               = path              , $ ; Input keyword
  SensorInfo_File    = sensorinfo_file   , $ ; Input keyword
  Response_Threshold = response_threshold, $ ; Input keyword
  Sigma              = sigma             , $ ; Input keyword
  Channel_List       = channel_list      , $ ; Input keyword
  Version            = version           , $ ; Input keyword
  No_Interpolate     = no_interpolate    , $ ; Input keyword
  No_Plot            = no_plot           , $ ; Input keyword
  No_Pause           = no_pause          , $ ; Input keyword
  wRef               = wref              , $ ; Input keyword
  Debug              = debug             , $ ; Input keyword
  eps=eps
;-

  ; Setup
  @osrf_parameters
  ; ...Set up error handler
  @osrf_pro_err_handler
  ; ...Check keywords
  path              = Valid_String(path)                    ? path            : Sensor_Id
  sensorinfo_file   = Valid_String(sensorinfo_file)         ? sensorinfo_file : "SensorInfo"
  apply_threshold   = (N_ELEMENTS(response_threshold) GT 0) ? TRUE            : FALSE
  version           = (N_ELEMENTS(version) GT 0)            ? version[0]      : OSRF_VERSION
  interpolate_data  = ~ KEYWORD_SET(no_interpolate)
  plot_data         = ~ KEYWORD_SET(no_plot)
  plot_pause        = ~ KEYWORD_SET(no_pause)
  ; ...Set parameters
  HISTORY = '$Id$'
  HISTORY_FILE = path+PATH_SEP()+'source.history'
  COMMENT_FILE = path+PATH_SEP()+'source.comment'


  ; Get the sensor information
  ; ...Read the SensorInfo file
  sinfo_list = SensorInfo_List(sensorinfo_file)
  sinfo_list->Read, Debug=debug
  ; ...Get the sensor entry
  sinfo = sinfo_list->Get(Sensor_Id=Sensor_Id,Count=count,Debug=debug)
  IF ( count NE 1 ) THEN $
    MESSAGE, Sensor_Id+' entry not found in '+STRTRIM(SensorInfo_File,2), $
             NONAME=MsgSwitch, NOPRINT=MsgSwitch
  ; ...Extract the sensor properties required
  sinfo->Get_Property, $
    Debug            = debug           , $
    Sensor_Name      = sensor_name     , $
    Satellite_Name   = satellite_name  , $
    WMO_Satellite_ID = wmo_satellite_id, $
    WMO_Sensor_ID    = wmo_sensor_id   , $
    Sensor_Type      = sensor_type     , $
    Sensor_Channel   = sensor_channel
  ; ...Set sone sensor data
  n_channels   = N_ELEMENTS(sensor_channel)
  is_microwave = (sensor_type EQ MICROWAVE_SENSOR )
  ; ...Set the default channel processing list if necessary
  channel_list = (N_ELEMENTS(chnnel_list) GT 0) ? channel_list : sensor_channel
  

  ; **** Reset interpolation keyword if microwave instrument ****
  ;      This may change in future. But for now, no interpolation
  ;      for microwave instruments!
  interpolate_reminder = FALSE
  IF ( is_microwave AND interpolate_data ) THEN BEGIN
    interpolate_data = FALSE
    msg = 'Interpolation disabled for microwave instruments!'
    MESSAGE, '**** '+msg+' ****', /INFORMATIONAL
    interpolate_reminder = TRUE
  ENDIF
  
  
  ; Get the source comment, and history if available
  Get_Comment, COMMENT_FILE, comment
  IF ( FILE_TEST(HISTORY_FILE) ) THEN BEGIN
    Get_Comment, HISTORY_FILE, source_history
    source_history = source_history + '; '
  ENDIF ELSE $
    source_history = ''


  ; Create an oSRF_File object array
  title = STRTRIM(satellite_name,2)+' '+STRTRIM(sensor_name,2)+' Spectral Response Funtions'
  osrf_file = OBJ_NEW( 'oSRF_File', $
                       path+PATH_SEP()+Sensor_Id+'.osrf.nc', $
                       Debug            = debug           , $
                       Version          = version         , $
                       Sensor_Id        = Sensor_Id       , $
                       WMO_Satellite_Id = wmo_satellite_id, $
                       WMO_Sensor_Id    = wmo_sensor_id   , $
                       Sensor_Type      = sensor_type     , $
                       Title            = title           , $
                       Comment          = comment           )


  ; Define a window object hash for output
  IF ( plot_data ) THEN wref = HASH()


  ; Begin channel loop
  FOR l = 0, n_channels-1 DO BEGIN
  
    idx = WHERE(channel_list EQ sensor_channel[l], count)
    IF ( count GT 0 ) THEN BEGIN
      PRINT, FORMAT='(//4x,"===================")'
      PRINT, FORMAT='(  4x,"Processing channel: ",i5)', sensor_channel[l]
      PRINT, FORMAT='(  4x,"===================")'
    ENDIF ELSE BEGIN
      PRINT, FORMAT='(//4x,"=#=#=#=#=#=#=#=#=")'
      PRINT, FORMAT='(  4x,"Skipping channel: ",i5)', sensor_channel[l]
      PRINT, FORMAT='(  4x,"=#=#=#=#=#=#=#=#=")'
      CONTINUE
    ENDELSE
    

    ; Create oSRF objects for this channel
    osrf = OBJ_NEW('oSRF', Debug = Debug)
    tsrf = OBJ_NEW('oSRF', Debug = Debug)
    isrf = OBJ_NEW('oSRF', Debug = Debug)


    ; Count the number of bands
    input_glob = Path+PATH_SEP()+Sensor_Id+'*-'+STRTRIM(sensor_channel[l],2)+'.inp'
    input_file = FILE_SEARCH(input_glob, COUNT = n_bands )
    PRINT, FORMAT='(6x,"Number of passbands: ",i1)', n_bands
    ; ...Cycle loop if no data
    IF ( n_bands EQ 0 ) THEN CONTINUE


    ; Get n_pts/band
    n_pts = !NULL
    FOR n = 0, n_bands-1 DO n_pts = [n_pts, FILE_LINES(input_file[n])]


    ; Allocate the current oSRF object
    osrf->Allocate, n_pts


    ; Begin band loop
    FOR n = 0, n_bands-1 DO BEGIN

      ; Output info
      band = n + 1
      PRINT, FORMAT='(6x,"Reading band #",i1," file: ",a)', band, input_file[n]


      ; Read the datafile
      channel_data = DBLARR(2,n_pts[n])
      OPENR, fid, input_file[n], /GET_LUN
      READF, fid, channel_data
      FREE_LUN, fid
      ; ...Split data into separate arrays
      frequency = REFORM(channel_data[0,*])
      response  = REFORM(channel_data[1,*])
      ; ...Convert frequency units if necessary
      IF ( is_microwave ) THEN frequency = GHz_to_inverse_cm(frequency)


      ; Add it to the oSRF object
      osrf->Set_Property, $
        band, $
        Debug            = Debug            , $
        Version          = Version          , $
        Sensor_Id        = Sensor_Id        , $
        WMO_Satellite_ID = wmo_satellite_id , $
        WMO_Sensor_ID    = wmo_sensor_id    , $
        Sensor_Type      = sensor_type      , $
        Channel          = sensor_channel[l], $
        Frequency        = Frequency        , $
        Response         = Response

    ENDFOR  ; Band loop


    ; Process the original SRF
    osrf->Integrate, Debug = Debug
    osrf->Compute_Central_Frequency, Debug = Debug
    osrf->Compute_Planck_Coefficients, Debug = Debug
    osrf->Compute_Polychromatic_Coefficients, Debug = Debug


    ; Apply a response threshold cutoff if requested
    ; ...Copy the original SRF
    osrf->Assign, $
      tsrf, $
      Debug = debug
    ; ...Now apply a threshold if required    
    IF ( apply_threshold ) THEN $
      tsrf->Apply_Response_Threshold, $
        Response_Threshold, $
        Debug = debug



    ; Interpolate SRF if required
    IF ( interpolate_data ) THEN BEGIN
      ; ...Linearly interpolate visible channels
      IF ( sensor_type EQ VISIBLE_SENSOR ) THEN $
        tsrf->Set_Flag, Debug=debug, /Linear_Interpolation
      ; ...Compute frequency grid and interpolate
      tsrf->Compute_Interpolation_Frequency, $
        isrf, $
        /LoRes, $
        Debug=debug
      ; ...and perform the actual interpolation
      tsrf->Interpolate, $
        isrf, $
        Sigma=sigma, $
        Debug=debug
    ENDIF ELSE BEGIN
      ; ...No interpolation, so just copy
      tsrf->Assign, $
        isrf, $
        Debug = debug
    ENDELSE


    ; Process the current SRF data
    isrf->Integrate, Debug = debug
    isrf->Compute_Central_Frequency, Debug = debug
    isrf->Compute_Planck_Coefficients, Debug = debug
    isrf->Compute_Polychromatic_Coefficients, Debug = debug
;    isrf->Compute_Bandwidth, Debug = Debug


    ; Add the SRF to the file container
    osrf_file->Add, isrf, Debug=debug


    ; Plot the data for inspection
    IF ( plot_data ) THEN BEGIN

      IF ( apply_threshold OR interpolate_data ) THEN BEGIN
        psrf  = osrf
        name  = 'Original'
        color = 'red'
      ENDIF ELSE BEGIN
        psrf  = isrf
        name  = 'Processed'
        color = 'blue'
      ENDELSE

      psrf->Plot, $
        Debug = debug, $
        NAME  = name, $
        COLOR = color

      IF ( apply_threshold OR interpolate_data ) THEN $
        psrf->Oplot, $
          isrf, $
          SYMBOL   = 'diamond', $
          SYM_SIZE = 0.6, $
          NAME     = 'Processed', $
          COLOR    = 'blue', $
          Debug    = debug
          
      ; ...Save the current window reference
      psrf->Get_Property, $
        wRef  = w, $
        Debug = Debug
      wref[sensor_channel[l]] = w

      ; ...Output an EPS file if requested
      IF ( KEYWORD_SET(eps) ) THEN BEGIN
        filename = Path+PATH_SEP()+Sensor_Id+'-'+STRTRIM(sensor_channel[l],2)+'.eps'
        ; Increase the font size for EPS files
        font_size = HASH()
        FOR band = 1, n_bands DO BEGIN
          psrf->Get_Property, band, pRef=pref, Debug=debug
          font_size[band] = pref.font_size
          pref.font_size = pref.font_size * 2.0
        ENDFOR
        ; Create the EPS file
        w.Save, filename
        ; Restore the font sizes
        FOR band = 1, n_bands DO BEGIN
          psrf->Get_Property, band, pRef=pref, Debug=debug
          pref.font_size = font_size[band]
        ENDFOR
      ENDIF
      
      ; ...Only pause if not at last channel
      not_last_channel = ~ (sensor_channel[l] EQ sensor_channel[-1])
      IF ( plot_pause AND not_last_channel ) THEN BEGIN
        PRINT, FORMAT='(/5x,"Press <ENTER> to continue, Q to quit")'
        q = GET_KBRD(1)
        IF ( STRUPCASE(q) EQ 'Q' ) THEN GOTO, Done
      ENDIF

    ENDIF

  ENDFOR  ; Channel loop


  ; Modify file comment as necessary
  IF ( apply_threshold ) THEN BEGIN
    comment = 'Response threshold cutoff of ' + $
              STRING(Response_Threshold,FORMAT='(e13.6)') + $
              ' applied to data; ' + $
              STRTRIM(comment,2)
  ENDIF
  IF ( interpolate_data ) THEN BEGIN
    comment = 'Input data interpolated to a regular frequency grid; ' + $
              STRTRIM(comment,2)
  ENDIF


  ; Write the processed SRFs
  osrf_file->Set_Property, $
      Debug   = Debug, $
      Title   = STRTRIM(satellite_name,2) + ' ' + $
                STRTRIM(sensor_name,2) + ' Spectral Response Functions', $
      History = source_history + HISTORY, $
      Comment = comment
  osrf_file->Write, Debug = Debug


  ; Cleanup
  Done:
  OBJ_DESTROY, osrf_file, Debug = Debug


  ; **** Reset interpolation keyword if microwave instrument ****
  ;      This is a reminder message output in case it was missed.
  IF ( is_microwave AND interpolate_reminder ) THEN $
    MESSAGE, '**** Reminder: '+msg+' ****', /INFORMATIONAL

END
