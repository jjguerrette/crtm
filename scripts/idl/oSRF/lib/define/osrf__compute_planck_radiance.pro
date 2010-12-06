PRO OSRF::Compute_Planck_Radiance, $
  Temperature, $
  Debug=Debug

  ; Set up
  ; ...OSRF parameters
  @osrf_parameters
  ; ...Set up error handler
  @osrf_pro_err_handler

  ; Compute Planck radiance for each band
  FOR i = 0L, self.n_Bands-1L DO BEGIN
    Band = i+1
    self->Get_Property, $
      Band, $
      Frequency=f, $
      Debug=Debug
    IF ( self->Flag_Is_Set(FREQUENCY_UNITS_FLAG) ) THEN f = GHz_to_inverse_cm(f)
    result = Planck_Radiance(f, Temperature, *(*self.Radiance)[i])
    IF ( result NE SUCCESS ) THEN $
      MESSAGE, 'Error computing Planck radiance for band '+STRTRIM(i+1,2), $
               NONAME=MsgSwitch, NOPRINT=MsgSwitch
  ENDFOR

END ; PRO OSRF::Compute_Planck_Radiance
