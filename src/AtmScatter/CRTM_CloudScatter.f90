!
! CRTM_CloudScatter
!
! Module to compute the cloud particle absorption and scattering properties
! required for radiative transfer in a cloudy atmosphere.
!
!
! CREATION HISTORY  
!        Written by:     Quanhua Liu,    QSS Group, Inc;  Quanhua.Liu@noaa.gov 
!                        Yong Han,       NOAA/NESDIS;     Yong.Han@noaa.gov
!                        Paul van Delst, CIMSS/SSEC;      paul.vandelst@ssec.wisc.edu
!                        02-July-2005
!

MODULE CRTM_CloudScatter

  ! -----------------
  ! Environment setup
  ! -----------------
  ! Module use
  USE Type_Kinds,               ONLY: fp
  USE Message_Handler,          ONLY: SUCCESS, FAILURE, Display_Message
  USE CRTM_Parameters,          ONLY: ZERO, ONE, POINT_5, ONEpointFIVE, &
                                      FOUR, &  ! <<< NEED TO REMOVE THIS IN FUTURE
                                      MAX_N_LAYERS, &
                                      MAX_N_CLOUDS, &
                                      WATER_CONTENT_THRESHOLD, &
                                      BS_THRESHOLD, &
                                      MAX_N_LEGENDRE_TERMS, &
                                      MAX_N_PHASE_ELEMENTS, &
                                      HGPHASE  ! <<< NEED TO REMOVE THIS IN FUTURE
  USE CRTM_SpcCoeff,            ONLY: SC, &
                                      INFRARED_SENSOR, MICROWAVE_SENSOR, VISIBLE_SENSOR
  USE CRTM_CloudCoeff,          ONLY: CloudC
  USE CRTM_Atmosphere_Define,   ONLY: CRTM_Atmosphere_type, &
                                      WATER_CLOUD, &
                                      ICE_CLOUD, &
                                      RAIN_CLOUD, &
                                      SNOW_CLOUD, &
                                      GRAUPEL_CLOUD, &
                                      HAIL_CLOUD
  USE CRTM_GeometryInfo_Define, ONLY: CRTM_GeometryInfo_type
  USE CRTM_Interpolation,       ONLY: NPTS        , &
                                      LPoly_type  , &
                                      find_index  , &
                                      interp_1D   , &
                                      interp_2D   , &
                                      interp_3D   , &
                                      interp_2D_TL, &
                                      interp_3D_TL, &
                                      interp_2D_AD, &
                                      interp_3D_AD, &
                                      Clear_LPoly , &
                                      LPoly       , &
                                      LPoly_TL    , &
                                      LPoly_AD
  USE CRTM_AtmScatter_Define,   ONLY: CRTM_AtmScatter_type      , &
                                      CRTM_Associated_AtmScatter, &
                                      CRTM_Destroy_AtmScatter   , &
                                      CRTM_Allocate_AtmScatter  , &
                                      CRTM_Assign_AtmScatter
  ! Disable implicit typing
  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------
  ! Everything private by default
  PRIVATE

  ! Public types
  ! ------------
  ! Use associated
  PUBLIC :: CRTM_AtmScatter_type
  
  ! Public procedures
  ! -----------------
  PUBLIC :: CRTM_Compute_CloudScatter
  PUBLIC :: CRTM_Compute_CloudScatter_TL
  PUBLIC :: CRTM_Compute_CloudScatter_AD
  ! Use associated
  PUBLIC :: CRTM_Associated_AtmScatter
  PUBLIC :: CRTM_Destroy_AtmScatter
  PUBLIC :: CRTM_Allocate_AtmScatter
  PUBLIC :: CRTM_Assign_AtmScatter


  ! -----------------
  ! Module parameters
  ! -----------------
  ! RCS Id for the module
  CHARACTER(*), PARAMETER :: MODULE_RCS_ID = &
  '$Id$'
  ! Message string length
  INTEGER, PARAMETER :: ML = 256
  ! Number of stream angle definitions
  INTEGER, PARAMETER :: TWO_STREAMS       =  2
  INTEGER, PARAMETER :: FOUR_STREAMS      =  4
  INTEGER, PARAMETER :: SIX_STREAMS       =  6
  INTEGER, PARAMETER :: EIGHT_STREAMS     =  8
  INTEGER, PARAMETER :: SIXTEEN_STREAMS   = 16
  INTEGER, PARAMETER :: THIRTYTWO_STREAMS = 32
  
!<<<<BEGIN TEMPORARY>>>>>
  ! LUT indexing variables
  REAL(fp), PARAMETER :: MINIMUM_WAVENUMBER = 102.0_fp
  REAL(fp), PARAMETER :: WAVENUMBER_SPACING = FOUR
!<<<<END TEMPORARY>>>>>


  ! --------------------------------------
  ! Structure definition to hold forward
  ! variables across FWD, TL, and AD calls
  ! --------------------------------------
  TYPE, PUBLIC :: CRTM_CSVariables_type
    PRIVATE
    REAL(fp), DIMENSION(MAX_N_LAYERS, MAX_N_CLOUDS) :: ke = ZERO  ! Mass extinction coefficient
    REAL(fp), DIMENSION(MAX_N_LAYERS, MAX_N_CLOUDS) :: w  = ZERO  ! Single scatter albedo
    REAL(fp), DIMENSION(MAX_N_LAYERS, MAX_N_CLOUDS) :: g  = ZERO  ! Asymmetry factor
    REAL(fp), DIMENSION(0:MAX_N_LEGENDRE_TERMS,&
                        MAX_N_PHASE_ELEMENTS,  &
                        MAX_N_LAYERS,          &
                        MAX_N_CLOUDS           ) :: pcoeff        ! Phase coefficients
    REAL(fp), DIMENSION(MAX_N_LAYERS) :: Total_bs = ZERO          ! Volume scattering coefficient
  END TYPE CRTM_CSVariables_type


CONTAINS


!------------------------------------------------------------------------------
!
! NAME:
!       CRTM_Compute_CloudScatter
!
! PURPOSE:
!       Function to compute the cloud particle absorption and scattering
!       properties and populate the output CloudScatter structure for a
!       single channel.
!
! CALLING SEQUENCE:
!       Error_Status = CRTM_Compute_CloudScatter( Atmosphere             , &  ! Input
!                                                 SensorIndex            , &  ! Input
!                                                 ChannelIndex           , &  ! Input
!                                                 CloudScatter           , &  ! Output
!                                                 CSVariables            , &  ! Internal variable output
!                                                 Message_Log=Message_Log  )  ! Error messaging 
!
! INPUT ARGUMENTS:
!       Atmosphere:      CRTM_Atmosphere structure containing the atmospheric
!                        profile data.
!                        UNITS:      N/A
!                        TYPE:       TYPE(CRTM_Atmosphere_type)
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN)
!
!       SensorIndex:     Sensor index id. This is a unique index associated
!                        with a (supported) sensor used to access the
!                        shared coefficient data for a particular sensor.
!                        See the ChannelIndex argument.
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN)
!
!       ChannelIndex:    Channel index id. This is a unique index associated
!                        with a (supported) sensor channel used to access the
!                        shared coefficient data for a particular sensor's
!                        channel.
!                        See the SensorIndex argument.
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN)
!
! OPTIONAL INPUT ARGUMENTS:
!       Message_Log:     Character string specifying a filename in which any
!                        messages will be logged. If not specified, or if an
!                        error occurs opening the log file, the default action
!                        is to output messages to standard output.
!                        UNITS:      N/A
!                        TYPE:       CHARACTER(*)
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN), OPTIONAL
!
! OUTPUT ARGUMENTS:
!        CloudScatter:   CRTM_AtmScatter structure containing the cloud particle
!                        absorption and scattering properties required for
!                        radiative transfer.
!                        UNITS:      N/A
!                        TYPE:       TYPE(CRTM_AtmScatter_type)
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN OUT)
!
!        CSVariables:    Structure containing internal variables required for
!                        subsequent tangent-linear or adjoint model calls.
!                        The contents of this structure are NOT accessible
!                        outside of the CRTM_CloudScatter module.
!                        UNITS:      N/A
!                        TYPE:       TYPE(CRTM_CSVariables_type)
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(OUT)
!
! FUNCTION RESULT:
!       Error_Status:    The return value is an integer defining the error status.
!                        The error codes are defined in the Message_Handler module.
!                        If == SUCCESS the computation was sucessful
!                           == FAILURE an unrecoverable error occurred
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!
! COMMENTS:
!       Note the INTENT on the output CloudScatter argument is IN OUT rather than
!       just OUT. This is necessary because the argument may be defined upon
!       input. To prevent memory leaks, the IN OUT INTENT is a must.
!
!
!------------------------------------------------------------------------------

  FUNCTION CRTM_Compute_CloudScatter( Atm         , &  ! Input
                                      SensorIndex , &  ! Input
                                      ChannelIndex, &  ! Input
                                      CScat       , &  ! Output
                                      CSV         , &  ! Internal variable output
                                      Message_Log ) &  ! Error messaging
                                    RESULT( Error_Status )
    ! Arguments
    TYPE(CRTM_Atmosphere_type) , INTENT(IN)     :: Atm
    INTEGER                    , INTENT(IN)     :: SensorIndex
    INTEGER                    , INTENT(IN)     :: ChannelIndex
    TYPE(CRTM_AtmScatter_type) , INTENT(IN OUT) :: CScat
    TYPE(CRTM_CSVariables_type), INTENT(OUT)    :: CSV
    CHARACTER(*),      OPTIONAL, INTENT(IN)     :: Message_Log
    ! Function result
    INTEGER :: Error_Status
    ! Function parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CRTM_Compute_CloudScatter'
    ! Local variables
    CHARACTER(ML) :: Message
    INTEGER  :: k, kc, l, m, n
    INTEGER  :: Sensor_Type
    REAL(fp) :: Frequency_MW, Frequency_IR
    LOGICAL  :: Layer_Mask(Atm%n_Layers)
    INTEGER  :: Layer_Index(Atm%n_Layers)
    INTEGER  :: nCloud_Layers
    REAL(fp) :: bs

    ! ------
    ! Set up
    ! ------
    Error_Status = SUCCESS
    ! Initialise and return if no clouds
    CScat%Optical_Depth         = ZERO
    CScat%Single_Scatter_Albedo = ZERO
    CScat%Asymmetry_Factor      = ZERO
    IF (CloudC%n_Phase_Elements > 0) CScat%Phase_Coefficient = ZERO
    IF (Atm%n_Clouds == 0) RETURN
    ! Spectral variables
    Sensor_Type  = SC(SensorIndex)%Sensor_Type
    Frequency_MW = SC(SensorIndex)%Frequency(ChannelIndex)
    Frequency_IR = SC(SensorIndex)%Wavenumber(ChannelIndex)
    ! Determine offset for Legendre coefficients in
    ! the CloudC lookup table corresponding to the
    ! number of streams
    SELECT CASE(CScat%n_Legendre_Terms)
      CASE (TWO_STREAMS)    ; CScat%lOffset = 0
      CASE (FOUR_STREAMS)   ; CScat%lOffset = 0
      CASE (SIX_STREAMS)    ; CScat%lOffset = 5
      CASE (EIGHT_STREAMS)  ; CScat%lOffset = 12
      CASE (SIXTEEN_STREAMS); CScat%lOffset = 21
      CASE DEFAULT
        CScat%lOffset = 0  ! Is this correct?
        ! Use two-stream model or HG and RAYLEIGH Phase function
        IF( HGPHASE ) THEN
          CScat%n_Legendre_Terms = 0
        ELSE
          Error_Status = FAILURE
          WRITE(Message,'("The n_Legendre_Terms in CloudScatter, ",i0,", do not fit model")') &
                        CScat%n_Legendre_Terms
          CALL Display_Message(ROUTINE_NAME, &
                               TRIM(Message), &
                               Error_Status, &
                               Message_Log=Message_Log)
          RETURN
        END IF
    END SELECT


    ! ---------------------------------------------
    ! Loop over the different clouds in the profile
    ! ---------------------------------------------
    Cloud_loop: DO n = 1, Atm%n_Clouds

      ! Only process clouds with more
      ! than the threshold water amount
      Layer_Mask    = Atm%Cloud(n)%Water_Content > WATER_CONTENT_THRESHOLD
      nCloud_Layers = COUNT(Layer_Mask)
      IF ( nCloud_Layers == 0 ) CYCLE Cloud_loop

      ! ------------------------------------
      ! Loop over the current cloud's layers
      ! ------------------------------------
      Layer_Index(1:nCloud_Layers) = PACK((/(k, k=1,Atm%Cloud(n)%n_Layers)/), Layer_Mask)
      Cloud_Layer_loop: DO k = 1, nCloud_Layers
        kc = Layer_Index(k)

        ! Call sensor specific routines
        SELECT CASE (Sensor_Type)
          CASE (MICROWAVE_SENSOR)
            CALL Get_Cloud_Opt_MW(CScat                              , & ! Input
                                  Frequency_MW                       , & ! Input
                                  Atm%Cloud(n)%Type                  , & ! Input
                                  Atm%Cloud(n)%Effective_Radius(kc)  , & ! Input
                                  Atm%Cloud(n)%Effective_Variance(kc), & ! Input
                                  Atm%Temperature(kc)                , & ! Input
                                  CSV%ke(kc,n)                       , & ! Output
                                  CSV%w(kc,n)                        , & ! Output
                                  CSV%g(kc,n)                        , & ! Output
                                  CSV%pcoeff(:,:,kc,n)                 ) ! Output
          CASE (INFRARED_SENSOR)
            CALL Get_Cloud_Opt_IR(CScat                              , & ! Input
                                  Frequency_IR                       , & ! Input
                                  Atm%Cloud(n)%Type                  , & ! Input
                                  Atm%Cloud(n)%Effective_Radius(kc)  , & ! Input
                                  Atm%Cloud(n)%Effective_Variance(kc), & ! Input
                                  CSV%ke(kc,n)                       , & ! Output
                                  CSV%w(kc,n)                        , & ! Output
                                  CSV%g(kc,n)                        , & ! Output
                                  CSV%pcoeff(:,:,kc,n)                 ) ! Output
          CASE DEFAULT
            CSV%ke(kc,n)         = ZERO
            CSV%w(kc,n)          = ZERO
            CSV%g(kc,n)          = ZERO
            CSV%pcoeff(:,:,kc,n) = ZERO
        END SELECT
        

        ! Compute the volume scattering coefficient for the current
        ! cloud layer and accumulate it for the layer total for the
        ! profile (i.e. all clouds)
        !   bs = rho.w.ke
        ! where
        !   bs  = volume scattering coefficient for a layer [dimensionless]
        !   rho = integrated cloud water density for a layer (g/m^2) [M.L^-2]
        !   w   = single scatter albedo [dimensionless]
        !   ke  = mass extintion coefficient (m^2/g) [L^2.M^-1]
        bs = Atm%Cloud(n)%Water_Content(kc) * CSV%w(kc,n) * CSV%ke(kc,n)
        CSV%Total_bs(kc) = CSV%Total_bs(kc) + bs

        ! Compute the optical depth (absorption + scattering)
        !   tau = rho.ke
        ! where
        !   rho = integrated cloud water density for a layer (g/m^2) [M.L^-2]
        !   ke  = mass extintion coefficient (m^2/g) [L^2.M^-1]
        ! Note that since all these computations are done for a given
        ! layer, the optical depth is the same as the volume extinction
        ! coefficient, be. Usually,
        !   tau = be.d(z)
        ! but we are working with height/thickness independent quantities
        ! so that
        !   tau = be
        ! This is why the optical depth is used in the denominator to
        ! compute the single scatter albedo in the Layer_loop below.
        CScat%Optical_Depth(kc) = CScat%Optical_Depth(kc) + &
                                  (CSV%ke(kc,n)*Atm%Cloud(n)%Water_Content(kc))

        ! Compute and sum the asymmetry factor
        !   g = g + g(LUT).bs
        ! where
        !   g(LUT) = the asymmetry factor from the LUT.
        CScat%Asymmetry_Factor(kc) = CScat%Asymmetry_Factor(kc) + &
                                     (CSV%g(kc,n) * bs)

        ! Compute the phase matrix coefficients
        !   p = p + p(LUT)*bs
        ! where
        !   p(LUT) = the phase coefficient from the LUT
        IF( CScat%n_Phase_Elements > 0 ) THEN
          DO m = 1, CScat%n_Phase_Elements
            DO l = 0, CScat%n_Legendre_Terms
              CScat%Phase_Coefficient(l,m,kc) = CScat%Phase_Coefficient(l,m,kc) + &
                                                (CSV%pcoeff(l,m,kc,n) * bs)
            END DO
          END DO
        END IF
      END DO Cloud_Layer_loop
    END DO Cloud_loop


    ! --------------------------------------------
    ! Accumulate optical properties for all clouds
    ! --------------------------------------------
    ! Some short names
    l = CScat%n_Legendre_Terms
    
    ! Begin full atmosphere layer loop
    Layer_loop: DO k = 1, Atm%n_Layers
    
      ! Only process layers that scatter
      IF (CSV%Total_bs(k) < BS_THRESHOLD) CYCLE Layer_loop
      
      ! Normalise the asymmetry factor with the total
      ! volume scattering coefficient, bs.
      CScat%Asymmetry_Factor(k) = CScat%Asymmetry_Factor(k) / CSV%Total_bs(k)

      IF (CScat%n_Phase_Elements > 0 ) THEN
        IF (l > 2) THEN
          ! Normalise the phase matrix coefficients with
          ! the total volume scattering coefficient, bs.
          DO m = 1, CScat%n_Phase_Elements
            CScat%Phase_Coefficient(0:l,m,k) = CScat%Phase_Coefficient(0:l,m,k) / &
                                               CSV%Total_bs(k)
          END DO
        ELSE
          ! Henyey-Greenstein phase function
          CScat%Phase_Coefficient(1,1,k) = ONEpointFIVE * CScat%Asymmetry_Factor(k)
          CScat%Phase_Coefficient(2,1,k) = ZERO
        END IF

        ! Normalization requirement
        CScat%Phase_Coefficient(0,1,k) = POINT_5
        CScat%Single_Scatter_Albedo(k) = CSV%Total_bs(k) / CScat%Optical_Depth(k)
        CScat%Delta_Truncation(k)      = CScat%Phase_Coefficient(l,1,k)
      END IF
    END DO Layer_loop

  END FUNCTION CRTM_Compute_CloudScatter


!------------------------------------------------------------------------------
!
! NAME:
!       CRTM_Compute_CloudScatter_TL
!
! PURPOSE:
!       Function to compute the tangent-linear cloud particle absorption and
!       scattering properties and populate the output CloudScatter_TL structure
!       for a single channel.
!
! CALLING SEQUENCE:
!       Error_Status = CRTM_Compute_CloudScatter_TL( Atmosphere             , &  ! Input
!                                                    CloudScatter           , &  ! Input
!                                                    Atmosphere_TL          , &  ! Input
!                                                    SensorIndex            , &  ! Input
!                                                    ChannelIndex           , &  ! Input
!                                                    CloudScatter_TL        , &  ! Output        
!                                                    CSVariables            , &  ! Internal variable input
!                                                    Message_Log=Message_Log  )  ! Error messaging 
!
! INPUT ARGUMENTS:
!       Atmosphere:       CRTM_Atmosphere structure containing the atmospheric
!                         profile data.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_Atmosphere_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       CloudScatter:     CRTM_AtmScatter structure containing the forward model
!                         cloud particle absorption and scattering properties
!                         required for radiative transfer.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_AtmScatter_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       Atmosphere_TL:    CRTM Atmosphere structure containing the tangent-linear
!                         atmospheric state data.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_Atmosphere_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       SensorIndex:      Sensor index id. This is a unique index associated
!                         with a (supported) sensor used to access the
!                         shared coefficient data for a particular sensor.
!                         See the ChannelIndex argument.
!                         UNITS:      N/A
!                         TYPE:       INTEGER
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       ChannelIndex:     Channel index id. This is a unique index associated
!                         with a (supported) sensor channel used to access the
!                         shared coefficient data for a particular sensor's
!                         channel.
!                         See the SensorIndex argument.
!                         UNITS:      N/A
!                         TYPE:       INTEGER
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       CSVariables:      Structure containing internal variables required for
!                         subsequent tangent-linear or adjoint model calls.
!                         The contents of this structure are NOT accessible
!                         outside of the CRTM_CloudScatter module.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_CSVariables_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
! OPTIONAL INPUT ARGUMENTS:
!       Message_Log:      Character string specifying a filename in which any
!                         messages will be logged. If not specified, or if an
!                         error occurs opening the log file, the default action
!                         is to output messages to standard output.
!                         UNITS:      N/A
!                         TYPE:       CHARACTER(*)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN), OPTIONAL
!
! OUTPUT ARGUMENTS:
!        CloudScatter_TL: CRTM_AtmScatter structure containing the tangent-linear
!                         cloud particle absorption and scattering properties
!                         required for radiative transfer.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_AtmScatter_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN OUT)
!
!
! FUNCTION RESULT:
!       Error_Status:    The return value is an integer defining the error status.
!                        The error codes are defined in the Message_Handler module.
!                        If == SUCCESS the computation was sucessful
!                           == FAILURE an unrecoverable error occurred
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!
! COMMENTS:
!       Note the INTENT on the output CloudScatter_TL argument is IN OUT rather
!       than just OUT. This is necessary because the argument may be defined
!       upon input. To prevent memory leaks, the IN OUT INTENT is a must.
!
!------------------------------------------------------------------------------

  FUNCTION CRTM_Compute_CloudScatter_TL( Atm         , &  ! FWD Input
                                         CScat       , &  ! FWD Input
                                         Atm_TL      , &  ! TL  Input
                                         SensorIndex , &  ! Input
                                         ChannelIndex, &  ! Input
                                         CScat_TL    , &  ! TL  Output
                                         CSV         , &  ! Internal variable input
                                         Message_Log ) &  ! Error messaging
                                       RESULT( Error_Status )
    ! Arguments
    TYPE(CRTM_Atmosphere_type) , INTENT(IN)     :: Atm
    TYPE(CRTM_AtmScatter_type) , INTENT(IN)     :: CScat
    TYPE(CRTM_Atmosphere_type) , INTENT(IN)     :: Atm_TL
    INTEGER                    , INTENT(IN)     :: SensorIndex
    INTEGER                    , INTENT(IN)     :: ChannelIndex
    TYPE(CRTM_AtmScatter_type) , INTENT(IN OUT) :: CScat_TL
    TYPE(CRTM_CSVariables_type), INTENT(IN)     :: CSV
    CHARACTER(*),      OPTIONAL, INTENT(IN)     :: Message_Log
    ! Function result
    INTEGER :: Error_Status
    ! Local parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CRTM_Compute_CloudScatter'
    ! Local variables
    CHARACTER(ML) :: Message
    INTEGER  :: k, kc, l, m, n
    INTEGER  :: n_Legendre_Terms, n_Phase_Elements
    INTEGER  :: Sensor_Type
    REAL(fp) :: Frequency_MW, Frequency_IR
    LOGICAL  :: Layer_Mask(Atm%n_Layers)
    INTEGER  :: Layer_Index(Atm%n_Layers)
    INTEGER  :: nCloud_Layers
    REAL(fp) :: ke_TL, w_TL, g_TL
    REAL(fp) :: pcoeff_TL(0:CScat%n_Legendre_Terms, CScat%n_Phase_Elements)
    REAL(fp) :: bs, bs_TL
    REAL(fp) :: Total_bs_TL(Atm%n_Layers)


    ! ------
    ! Set up
    ! ------
    Error_Status = SUCCESS
    ! Initialise and return if no clouds
    CScat_TL%Optical_Depth         = ZERO
    CScat_TL%Single_Scatter_Albedo = ZERO
    CScat_TL%Asymmetry_Factor      = ZERO
    IF (CloudC%n_Phase_Elements > 0) CScat_TL%Phase_Coefficient = ZERO
    IF (Atm%n_Clouds == 0) RETURN
    Total_bs_TL = ZERO
    ! Spectral variables
    Sensor_Type  = SC(SensorIndex)%Sensor_Type
    Frequency_MW = SC(SensorIndex)%Frequency(ChannelIndex)
    Frequency_IR = SC(SensorIndex)%Wavenumber(ChannelIndex)
    ! Phase matrix dimensions
    n_Legendre_Terms = CScat_TL%n_Legendre_Terms
    n_Phase_Elements = CScat_TL%n_Phase_Elements
    CScat_TL%lOffset = CScat%lOffset


    ! ---------------------------------------------
    ! Loop over the different clouds in the profile
    ! ---------------------------------------------
    Cloud_loop: DO n = 1, Atm%n_Clouds

      ! Only process clouds with more
      ! than the threshold water amount
      Layer_Mask    = Atm%Cloud(n)%Water_Content > WATER_CONTENT_THRESHOLD
      nCloud_Layers = COUNT(Layer_Mask)
      IF ( nCloud_Layers == 0 ) CYCLE Cloud_loop

      ! ------------------------------------
      ! Loop over the current cloud's layers
      ! ------------------------------------
      Layer_Index(1:nCloud_Layers) = PACK((/(k, k=1,Atm%Cloud(n)%n_Layers)/), Layer_Mask)
      Cloud_Layer_loop: DO k = 1, nCloud_Layers
        kc = Layer_Index(k)

        ! Call sensor specific routines
        SELECT CASE (Sensor_Type)
          CASE (MICROWAVE_SENSOR)
            CALL Get_Cloud_Opt_MW_TL(CScat_TL                              , & ! Input
                                     Frequency_MW                          , & ! Input
                                     Atm%Cloud(n)%Type                     , & ! Input
                                     Atm%Cloud(n)%Effective_Radius(kc)     , & ! FWD Input
                                     Atm%Cloud(n)%Effective_Variance(kc)   , & ! FWD Input
                                     Atm%Temperature(kc)                   , & ! FWD Input
                                     Atm_TL%Cloud(n)%Effective_Radius(kc)  , & ! TL  Input
                                     Atm_TL%Cloud(n)%Effective_Variance(kc), & ! TL  Input
                                     Atm_TL%Temperature(kc)                , & ! TL  Input
                                     ke_TL                                 , & ! TL  Output
                                     w_TL                                  , & ! TL  Output
                                     g_TL                                  , & ! TL  Output
                                     pcoeff_TL                               ) ! TL  Output
          CASE (INFRARED_SENSOR)
            CALL Get_Cloud_Opt_IR_TL(CScat_TL                              , & ! Input
                                     Frequency_IR                          , & ! Input
                                     Atm%Cloud(n)%Type                     , & ! Input
                                     Atm%Cloud(n)%Effective_Radius(kc)     , & ! FWD Input
                                     Atm%Cloud(n)%Effective_Variance(kc)   , & ! FWD Input
                                     Atm_TL%Cloud(n)%Effective_Radius(kc)  , & ! TL  Input
                                     Atm_TL%Cloud(n)%Effective_Variance(kc), & ! TL  Input
                                     ke_TL                                 , & ! TL  Output
                                     w_TL                                  , & ! TL  Output
                                     g_TL                                  , & ! TL  Output
                                     pcoeff_TL                               ) ! TL  Output
          CASE DEFAULT
            ke_TL     = ZERO
            w_TL      = ZERO
            g_TL      = ZERO
            pcoeff_TL = ZERO
        END SELECT


        ! Compute the volume scattering coefficient
        bs = Atm%Cloud(n)%Water_Content(kc) * CSV%w(kc,n) * CSV%ke(kc,n)
        bs_TL = (Atm_TL%Cloud(n)%Water_Content(kc) * CSV%w(kc,n) * CSV%ke(kc,n)) + &
                (Atm%Cloud(n)%Water_Content(kc)    * w_TL        * CSV%ke(kc,n)) + &
                (Atm%Cloud(n)%Water_Content(kc)    * CSV%w(kc,n) * ke_TL       )
        Total_bs_TL(kc) = Total_bs_TL(kc) + bs_TL

        ! Compute the optical depth (absorption + scattering)
        CScat_TL%Optical_Depth(kc) = CScat_TL%Optical_Depth(kc) + &
                                     (ke_TL        * Atm%Cloud(n)%Water_Content(kc)) + &
                                     (CSV%ke(kc,n) * Atm_TL%Cloud(n)%Water_Content(kc))
        
        ! Compute the asymmetry factor
        CScat_TL%Asymmetry_Factor(kc) = CScat_TL%Asymmetry_Factor(kc) + &
                                        (g_TL        * bs   ) + &
                                        (CSV%g(kc,n) * bs_TL)

        ! Compute the phase matrix coefficients
        IF( n_Phase_Elements > 0 ) THEN
          DO m = 1, n_Phase_Elements
            DO l = 0, n_Legendre_Terms
              CScat_TL%Phase_Coefficient(l,m,kc) = CScat_TL%Phase_Coefficient(l,m,kc) + &
                                                   (pcoeff_TL(l,m)       * bs   ) + &
                                                   (CSV%pcoeff(l,m,kc,n) * bs_TL)
            END DO
          END DO
        END IF
      END DO Cloud_Layer_loop
    END DO Cloud_loop


    ! --------------------------------------------
    ! Accumulate optical properties for all clouds
    ! --------------------------------------------
    ! Some short names
    l = n_Legendre_Terms
    
    ! Begin full atmosphere layer loop
    Layer_loop: DO k = 1, Atm%n_Layers
    
      ! Only process layers that scatter
      IF (CSV%Total_bs(k) < BS_THRESHOLD) CYCLE Layer_loop
      
      ! Normalise the asymmetry factor with the total
      ! volume scattering coefficient, bs.
      ! NOTE: the second term is NOT divided by
      !       CSV%Total_bs(k)**2 because the forward
      !       model asymmetry factor for this layer
      !       has already been divided once by
      !       CSV%Total_bs(k).
      CScat_TL%Asymmetry_Factor(k) = &
        (CScat_TL%Asymmetry_Factor(k) - (CScat%Asymmetry_Factor(k)*Total_bs_TL(k))) / &
        CSV%Total_bs(k)

      IF (n_Phase_Elements > 0 ) THEN
        IF (l > 2) THEN
          ! Normalise the phase matrix coefficients with
          ! the total volume scattering coefficient, bs.
          ! NOTE: the second term is NOT divided by
          !       CSV%Total_bs(k)**2 because the forward
          !       model phase coefficients for this layer
          !       have already been divided once by
          !       CSV%Total_bs(k).
          DO m = 1, n_Phase_Elements
            CScat_TL%Phase_Coefficient(0:l,m,k) = &
              (CScat_TL%Phase_Coefficient(0:l,m,k) - (CScat%Phase_Coefficient(0:l,m,k)*Total_bs_TL(k))) / &
              CSV%Total_bs(k)
          END DO
        ELSE
          ! Henyey-Greenstein phase function
          CScat_TL%Phase_Coefficient(1,1,k) = ONEpointFIVE * CScat_TL%Asymmetry_Factor(k)
          CScat_TL%Phase_Coefficient(2,1,k) = ZERO
        END IF

        ! Normalization requirement
        ! NOTE: the second term of the single scatter
        !       albedo computation is NOT divided by
        !       CloudScatter%Optical_Depth(k)**2 because
        !       the forward model single scatter albedo
        !       is used rather than recomputing it again
        !       here (i.e. the total scattering coefficient
        !       divided by the optical depth).
        CScat_TL%Phase_Coefficient(0,1,k) = ZERO
        CScat_TL%Single_Scatter_Albedo(k) = &
          (Total_bs_TL(k) - (CScat%Single_Scatter_Albedo(k)*CScat_TL%Optical_Depth(k))) / &
          CScat%Optical_Depth(k)
          
        CScat_TL%Delta_Truncation(k) = CScat_TL%Phase_Coefficient(l,1,k)
      END IF
    END DO Layer_loop

  END FUNCTION CRTM_Compute_CloudScatter_TL


!------------------------------------------------------------------------------
!
! NAME:
!       CRTM_Compute_CloudScatter_AD
!
! PURPOSE:
!       Function to compute the adjoint of the cloud particle absorption and
!       scattering properties for a single channel.
!
! CALLING SEQUENCE:
!       Error_Status = CRTM_Compute_CloudScatter_AD(  Atmosphere             , &  ! Input   
!                                                     CloudScatter           , &  ! Input   
!                                                     CloudScatter_AD        , &  ! Input   
!                                                     SensorIndex            , &  ! Input
!                                                     ChannelIndex           , &  ! Input
!                                                     Atmosphere_AD          , &  ! Output  
!                                                     CSVariables            , &  ! Internal variable input
!                                                     Message_Log=Message_Log  )  ! Error messaging 
!
! INPUT ARGUMENTS:
!       Atmosphere:       CRTM_Atmosphere structure containing the atmospheric
!                         profile data.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_Atmosphere_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       CloudScatter:     CRTM_AtmScatter structure containing the forward model
!                         cloud particle absorption and scattering properties
!                         required for radiative transfer.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_AtmScatter_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       CloudScatter_AD:  CRTM_AtmScatter structure containing the adjoint
!                         of the cloud particle absorption and scattering
!                         properties required for radiative transfer.
!                         **NOTE: On EXIT from this function, the contents of
!                                 this structure may be modified (e.g. set to
!                                 zero.)
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_AtmScatter_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN OUT)
!
!       SensorIndex:      Sensor index id. This is a unique index associated
!                         with a (supported) sensor used to access the
!                         shared coefficient data for a particular sensor.
!                         See the ChannelIndex argument.
!                         UNITS:      N/A
!                         TYPE:       INTEGER
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       ChannelIndex:     Channel index id. This is a unique index associated
!                         with a (supported) sensor channel used to access the
!                         shared coefficient data for a particular sensor's
!                         channel.
!                         See the SensorIndex argument.
!                         UNITS:      N/A
!                         TYPE:       INTEGER
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
!       ASVariables:      Structure containing internal variables required for
!                         subsequent tangent-linear or adjoint model calls.
!                         The contents of this structure are NOT accessible
!                         outside of the CRTM_AerosolScatter module.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_ASVariables_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN)
!
! OPTIONAL INPUT ARGUMENTS:
!       Message_Log:      Character string specifying a filename in which any
!                         messages will be logged. If not specified, or if an
!                         error occurs opening the log file, the default action
!                         is to output messages to standard output.
!                         UNITS:      N/A
!                         TYPE:       CHARACTER(*)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN), OPTIONAL
!
! OUTPUT ARGUMENTS:
!       Atmosphere_AD:    CRTM Atmosphere structure containing the adjoint
!                         atmospheric state data.
!                         UNITS:      N/A
!                         TYPE:       TYPE(CRTM_Atmosphere_type)
!                         DIMENSION:  Scalar
!                         ATTRIBUTES: INTENT(IN OUT)
!
!
! FUNCTION RESULT:
!       Error_Status:     The return value is an integer defining the error status.
!                         The error codes are defined in the Message_Handler module.
!                         If == SUCCESS the computation was sucessful
!                            == FAILURE an unrecoverable error occurred
!                         UNITS:      N/A
!                         TYPE:       INTEGER
!                         DIMENSION:  Scalar
!
! COMMENTS:
!       Note the INTENT on all of the adjoint arguments (whether input or output)
!       is IN OUT rather than just OUT. This is necessary because the INPUT
!       adjoint arguments are modified, and the OUTPUT adjoint arguments must
!       be defined prior to entry to this routine. So, anytime a structure is
!       to be output, to prevent memory leaks the IN OUT INTENT is a must.
!
!------------------------------------------------------------------------------

  FUNCTION CRTM_Compute_CloudScatter_AD( Atm         , &  ! FWD Input
                                         CScat       , &  ! FWD Input
                                         CScat_AD    , &  ! AD  Input
                                         SensorIndex , &  ! Input
                                         ChannelIndex, &  ! Input
                                         Atm_AD      , &  ! AD  Output
                                         CSV         , &  ! Internal variable input
                                         Message_Log ) &  ! Error messaging
                                       RESULT( Error_Status )
    ! Arguments
    TYPE(CRTM_Atmosphere_type) , INTENT(IN)     :: Atm
    TYPE(CRTM_AtmScatter_type) , INTENT(IN)     :: CScat
    TYPE(CRTM_AtmScatter_type) , INTENT(IN OUT) :: CScat_AD
    INTEGER                    , INTENT(IN)     :: SensorIndex
    INTEGER                    , INTENT(IN)     :: ChannelIndex
    TYPE(CRTM_Atmosphere_type) , INTENT(IN OUT) :: Atm_AD
    TYPE(CRTM_CSVariables_type), INTENT(IN)     :: CSV
    CHARACTER(*),      OPTIONAL, INTENT(IN)     :: Message_Log
    ! Function result
    INTEGER :: Error_Status
    ! Local parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CRTM_Compute_CloudScatter_AD'
    ! Local variables
    CHARACTER(ML) :: Message
    INTEGER  :: k, kc, l, m, n
    INTEGER  :: n_Legendre_Terms, n_Phase_Elements
    INTEGER  :: Sensor_Type
    REAL(fp) :: Frequency_MW, Frequency_IR
    LOGICAL  :: Layer_Mask(Atm%n_Layers)
    INTEGER  :: Layer_Index(Atm%n_Layers)
    INTEGER  :: nCloud_Layers
    REAL(fp) :: ke_AD, w_AD, g_AD
    REAL(fp) :: pcoeff_AD(0:CScat%n_Legendre_Terms, CScat%n_Phase_Elements)
    REAL(fp) :: bs, bs_AD
    REAL(fp) :: Total_bs_AD(Atm%n_Layers)

    ! ------
    ! Set up
    ! ------
    Error_Status = SUCCESS
    IF (Atm%n_Clouds == 0) RETURN
    ! Initialize local adjoint variables
    Total_bs_AD = ZERO
    ! Spectral variables
    Sensor_Type  = SC(SensorIndex)%Sensor_Type
    Frequency_MW = SC(SensorIndex)%Frequency(ChannelIndex)
    Frequency_IR = SC(SensorIndex)%Wavenumber(ChannelIndex)
    ! Phase matrix dimensions
    n_Legendre_Terms = CScat_AD%n_Legendre_Terms
    n_Phase_Elements = CScat_AD%n_Phase_Elements
    CScat_AD%lOffset = CScat%lOffset


    ! --------------------------------------------------------
    ! Adjoint of accumulated optical properties for all clouds
    ! --------------------------------------------------------
    ! Some short names
    l = n_Legendre_Terms
    
    ! Begin full atmosphere layer loop
    Layer_loop: DO k = Atm%n_Layers, 1, -1 !1, Atm%n_Layers
    
      ! Only process layers that scatter
      IF (CSV%Total_bs(k) < BS_THRESHOLD) CYCLE Layer_loop
      
      IF (n_Phase_Elements > 0 ) THEN

        ! Adjoint of the normalization requirements
        CScat_AD%Phase_Coefficient(0,1,k) = ZERO

        CScat_AD%Optical_Depth(k) = CScat_AD%Optical_Depth(k) - &
          (CScat_AD%Single_Scatter_Albedo(k)*CScat%Single_Scatter_Albedo(k) / &
           CScat%Optical_Depth(k))
        Total_bs_AD(k) = Total_bs_AD(k) + (CScat_AD%Single_Scatter_Albedo(k)/CScat%Optical_Depth(k))
        CScat_AD%Single_Scatter_Albedo(k) = ZERO

        CScat_AD%Phase_Coefficient(l,1,k) = CScat_AD%Phase_Coefficient(l,1,k) + &
                                            CScat_AD%Delta_Truncation(k)
        CScat_AD%Delta_Truncation(k) = ZERO

        ! Adjoint of phase matrix coefficients
        IF (l > 2) THEN
          ! Adjoint of the phase matrix coefficient normalisation
          ! with the total volume scattering coefficient, bs.
          DO m = 1, n_Phase_Elements
            Total_bs_AD(k) = Total_bs_AD(k) - &
                             (SUM(CScat_AD%Phase_Coefficient(0:l,m,k) * &
                                  CScat%Phase_Coefficient(0:l,m,k)) / &
                              CSV%Total_bs(k))
            CScat_AD%Phase_Coefficient(0:l,m,k) = CScat_AD%Phase_Coefficient(0:l,m,k) / &
                                                  CSV%Total_bs(k)
          END DO
        ELSE
          ! Henyey-Greenstein phase function
          CScat_AD%Asymmetry_Factor(k) = CScat_AD%Asymmetry_Factor(k) + &
                                         (ONEpointFIVE * CScat_AD%Phase_Coefficient(1,1,k))
          CScat_AD%Phase_Coefficient(1,1,k) = ZERO
          CScat_AD%Phase_Coefficient(2,1,k) = ZERO
        END IF

      END IF
      
      ! Adjoint of the asymmetry factor normalisation with
      ! the total volume scattering coefficient, bs.
      Total_bs_AD(k) = Total_bs_AD(k) - (CScat_AD%Asymmetry_Factor(k)*CScat%Asymmetry_Factor(k) / &
                                         CSV%Total_bs(k))
      CScat_AD%Asymmetry_Factor(k) = CScat_AD%Asymmetry_Factor(k)/CSV%Total_bs(k)

    END DO Layer_loop


    ! ---------------------------------------------
    ! Loop over the different clouds in the profile
    ! ---------------------------------------------
    Cloud_loop: DO n = 1, Atm%n_Clouds

      ! Only process clouds with more
      ! than the threshold water amount
      Layer_Mask    = Atm%Cloud(n)%Water_Content > WATER_CONTENT_THRESHOLD
      nCloud_Layers = COUNT(Layer_Mask)
      IF ( nCloud_Layers == 0 ) CYCLE Cloud_loop


      ! ------------------------------------
      ! Loop over the current cloud's layers
      ! ------------------------------------
      Layer_Index(1:nCloud_Layers) = PACK((/(k, k=1,Atm%Cloud(n)%n_Layers)/), Layer_Mask)
      Cloud_Layer_loop: DO k = nCloud_Layers, 1, -1 !1, nCloud_Layers
        kc = Layer_Index(k)

        ! Initialise the individual
        ! cloud adjoint variables
        bs_AD = ZERO
        pcoeff_AD = ZERO
        g_AD      = ZERO
        ke_AD     = ZERO
        w_AD      = ZERO


        ! Recompute the forward model volume scattering
        ! coefficient for the current cloud ONLY
        bs = Atm%Cloud(n)%Water_Content(kc) * CSV%w(kc,n) * CSV%ke(kc,n)

        ! Compute the adjoint of the
        ! phase matrix coefficients
        IF( n_Phase_Elements > 0 ) THEN
          DO m = 1, n_Phase_Elements
            DO l = 0, n_Legendre_Terms
              bs_AD = bs_AD + (CSV%pcoeff(l,m,kc,n) * CScat_AD%Phase_Coefficient(l,m,kc))
              pcoeff_AD(l,m) = pcoeff_AD(l,m) + (bs * CScat_AD%Phase_Coefficient(l,m,kc))
            END DO
          END DO
        END IF

        ! Compute the adjoint of
        ! the asymmetry factor
        bs_AD = bs_AD + (CSV%g(kc,n) * CScat_AD%Asymmetry_Factor(kc))
        g_AD  = g_AD  + (bs          * CScat_AD%Asymmetry_Factor(kc))

        ! Compute the adjoint of the optical 
        ! depth (absorption + scattering)
        Atm_AD%Cloud(n)%Water_Content(kc) = Atm_AD%Cloud(n)%Water_Content(kc) + &
                                            (CSV%ke(kc,n) * CScat_AD%Optical_Depth(kc))
        ke_AD = ke_AD + (Atm%Cloud(n)%Water_Content(kc) * CScat_AD%Optical_Depth(kc))

        ! Compute the adjoint of the volume
        ! scattering coefficient.
        ! NOTE: bs_AD is not reinitialised after this
        !       point since it is reinitialised at the
        !       start of the Cloud_Layer_loop.
        bs_AD = bs_AD + Total_bs_AD(kc)
        
        ke_AD = ke_AD + (Atm%Cloud(n)%Water_Content(kc) * CSV%w(kc,n)  * bs_AD )
        w_AD  = w_AD  + (Atm%Cloud(n)%Water_Content(kc) * CSV%ke(kc,n) * bs_AD )
        Atm_AD%Cloud(n)%Water_Content(kc) = Atm_AD%Cloud(n)%Water_Content(kc) + &
                                            ( CSV%w(kc,n) * CSV%ke(kc,n) * bs_AD )


        ! Call sensor specific routines
        SELECT CASE (Sensor_Type)
          CASE (MICROWAVE_SENSOR)
            CALL Get_Cloud_Opt_MW_AD(CScat_AD                              , & ! Input
                                     Frequency_MW                          , & ! Input
                                     Atm%Cloud(n)%Type                     , & ! Input
                                     Atm%Cloud(n)%Effective_Radius(kc)     , & ! FWD Input
                                     Atm%Cloud(n)%Effective_Variance(kc)   , & ! FWD Input
                                     Atm%Temperature(kc)                   , & ! FWD Input
                                     ke_AD                                 , & ! AD  Input
                                     w_AD                                  , & ! AD  Input
                                     g_AD                                  , & ! AD  Input
                                     pcoeff_AD                             , & ! AD  Input
                                     Atm_AD%Cloud(n)%Effective_Radius(kc)  , & ! AD  Input
                                     Atm_AD%Cloud(n)%Effective_Variance(kc), & ! AD  Input
                                     Atm_AD%Temperature(kc)                  ) ! AD  Input
          CASE (INFRARED_SENSOR)
            CALL Get_Cloud_Opt_IR_AD(CScat_AD                              , & ! Input
                                     Frequency_IR                          , & ! Input
                                     Atm%Cloud(n)%Type                     , & ! Input
                                     Atm%Cloud(n)%Effective_Radius(kc)     , & ! FWD Input
                                     Atm%Cloud(n)%Effective_Variance(kc)   , & ! FWD Input
                                     ke_AD                                 , & ! AD  Input
                                     w_AD                                  , & ! AD  Input
                                     g_AD                                  , & ! AD  Input
                                     pcoeff_AD                             , & ! AD  Input
                                     Atm_AD%Cloud(n)%Effective_Radius(kc)  , & ! AD  Output
                                     Atm_AD%Cloud(n)%Effective_Variance(kc)  ) ! AD  Output
          CASE DEFAULT
            ke_AD     = ZERO
            w_AD      = ZERO
            g_AD      = ZERO
            pcoeff_AD = ZERO
        END SELECT
      END DO Cloud_Layer_loop
    END DO Cloud_loop
                                 
  END FUNCTION CRTM_Compute_CloudScatter_AD




!################################################################################
!################################################################################
!##                                                                            ##
!##                        ## PRIVATE MODULE ROUTINES ##                       ##
!##                                                                            ##
!################################################################################
!################################################################################

  ! ------------------------------------------
  ! Subroutine to obtain the IR bulk
  ! optical properties of a cloud:
  !   extinction coefficient (ke),
  !   scattering coefficient (w)
  !   asymmetry factor (g), and
  !   spherical Legendre coefficients (pcoeff)
  ! ------------------------------------------
  SUBROUTINE Get_Cloud_Opt_IR( CloudScatter, &  ! Input  CloudScatter structure
                               Frequency   , &  ! Input  Frequency (cm^-1) 
                               cloud_type  , &  ! Input  see CRTM_Cloud_Define.f90
                               Reff        , &  ! Input  effective radius (mm)
                               Reff_Var    , &  ! Input  variance of effective radius
                               ke          , &  ! Output optical depth for 1 mm water content
                               w           , &  ! Output single scattering albedo
                               g           , &  ! Output asymmetry factor
                               pcoeff        )  ! Output spherical Legendre coefficients
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter
    REAL(fp)                  , INTENT(IN)     :: Frequency
    INTEGER                   , INTENT(IN)     :: Cloud_Type
    REAL(fp)                  , INTENT(IN)     :: Reff
    REAL(fp)                  , INTENT(IN)     :: Reff_Var
    REAL(fp)                  , INTENT(OUT)    :: ke
    REAL(fp)                  , INTENT(OUT)    :: w
    REAL(fp)                  , INTENT(OUT)    :: g
    REAL(fp)                  , INTENT(IN OUT) :: pcoeff(0:,:)
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k
    INTEGER  :: l
    REAL(fp) :: f_int, r_int
    REAL(fp), DIMENSION(NPTS) :: f, r
    TYPE(LPoly_type) :: wlp, xlp
    
    ! Find the frequency and effective
    ! radius indices for interpolation
    ! --------------------------------
    f_int = MAX(MIN(CloudC%Frequency_IR(CloudC%n_IR_Frequencies),Frequency),CloudC%Frequency_IR(1))
!    CALL find_index(CloudC%Frequency_IR, WAVENUMBER_SPACING, f_int, i1,i2)
    CALL find_index(CloudC%Frequency_IR, f_int, i1,i2)
    f = CloudC%Frequency_IR(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_IR(CloudC%n_IR_Radii),Reff),CloudC%Reff_IR(1))
    CALL find_index(CloudC%Reff_IR, r_int, j1,j2)
    r = CloudC%Reff_IR(j1:j2)
    
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output
 
    ! Determine the density index, k, for the clouds
    ! based on CloudC LUT organisation
    ! ----------------------------------------------
    SELECT CASE (Cloud_Type)
      CASE(WATER_CLOUD)  ; k=0  ! Liquid
      CASE(ICE_CLOUD)    ; k=3  ! Solid
      CASE(RAIN_CLOUD)   ; k=0  ! Liquid
      CASE(SNOW_CLOUD)   ; k=1  ! Solid
      CASE(GRAUPEL_CLOUD); k=2  ! Solid
      CASE(HAIL_CLOUD)   ; k=3  ! Solid
    END SELECT
    
    ! Perform interpolation
    ! ---------------------
    CALL interp_2D( CloudC%ke_IR(i1:i2,j1:j2,k), wlp, xlp, ke )
    CALL interp_2D( CloudC%w_IR(i1:i2,j1:j2,k) , wlp, xlp, w  )
    CALL interp_2D( CloudC%g_IR(i1:i2,j1:j2,k) , wlp, xlp, g  )
    IF (CloudScatter%n_Phase_Elements > 0 .AND. &
        CloudScatter%n_Legendre_Terms > 2       ) THEN
      DO l = 0, CloudScatter%n_Legendre_Terms
        CALL interp_2D( CloudC%pcoeff_IR(i1:i2,j1:j2,k,l+CloudScatter%lOffset), &
                        wlp, xlp, pcoeff(l,1) )
      END DO
    END IF
    
  END SUBROUTINE Get_Cloud_Opt_IR


  ! ---------------------------------------------
  ! Subroutine to obtain the tangent-linear
  ! IR bulk optical properties of a cloud:
  !   extinction coefficient (ke_TL),
  !   scattereing coefficient (w_TL)
  !   asymmetry factor (g_TL), and
  !   spherical Legendre coefficients (pcoeff_TL)
  ! ---------------------------------------------
  SUBROUTINE Get_Cloud_Opt_IR_TL( CloudScatter_TL, &  ! Input      CloudScatter TL structure
                                  Frequency      , &  ! Input      Frequency (cm^-1) 
                                  cloud_type     , &  ! Input      see CRTM_Cloud_Define.f90
                                  Reff           , &  ! FWD Input  effective radius (mm)
                                  Reff_Var       , &  ! FWD Input  variance of effective radius
                                  Reff_TL        , &  ! TL  Input  effective radius (mm)
                                  Reff_Var_TL    , &  ! TL  Input  variance of effective radius
                                  ke_TL          , &  ! TL  Output extinction coefficient (=~ optical depth for 1 mm water content)
                                  w_TL           , &  ! TL  Output single scattering albedo
                                  g_TL           , &  ! TL  Output asymmetry factor
                                  pcoeff_TL        )  ! TL  Output spherical Legendre coefficients
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter_TL
    REAL(fp),                   INTENT(IN)     :: Frequency
    INTEGER ,                   INTENT(IN)     :: Cloud_Type
    REAL(fp),                   INTENT(IN)     :: Reff
    REAL(fp),                   INTENT(IN)     :: Reff_Var
    REAL(fp),                   INTENT(IN)     :: Reff_TL
    REAL(fp),                   INTENT(IN)     :: Reff_Var_TL
    REAL(fp),                   INTENT(OUT)    :: ke_TL
    REAL(fp),                   INTENT(OUT)    :: w_TL
    REAL(fp),                   INTENT(OUT)    :: g_TL
    REAL(fp),                   INTENT(IN OUT) :: pcoeff_TL(0:,:)
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k
    INTEGER  :: l
    REAL(fp) :: f_int   , r_int
    REAL(fp) :: f_int_TL, r_int_TL
    REAL(fp), DIMENSION(NPTS) :: f   , r
    REAL(fp), DIMENSION(NPTS) :: f_TL, r_TL
    REAL(fp), DIMENSION(NPTS,NPTS) :: z, z_TL
    TYPE(LPoly_type) :: wlp, xlp
    TYPE(LPoly_type) :: wlp_TL, xlp_TL
    
    ! Setup
    ! -----
    ! No TL output when effective radius
    ! is outside LUT bounds
    IF ( Reff < CloudC%Reff_IR(1) .OR. &
         Reff > CloudC%Reff_IR(CloudC%n_IR_Radii) ) THEN
      ke_TL     = ZERO
      w_TL      = ZERO
      g_TL      = ZERO
      pcoeff_TL = ZERO
      RETURN
    END IF
    ! The TL inputs
    f_int_TL = ZERO
    f_TL     = ZERO
    r_int_TL = Reff_TL
    r_TL     = ZERO
    z_TL = ZERO

    ! Find the frequency and effective
    ! radius indices for interpolation
    ! --------------------------------
    f_int = MAX(MIN(CloudC%Frequency_IR(CloudC%n_IR_Frequencies),Frequency),CloudC%Frequency_IR(1))
!    CALL find_index(CloudC%Frequency_IR, WAVENUMBER_SPACING, f_int, i1,i2)
    CALL find_index(CloudC%Frequency_IR, f_int, i1,i2)
    f = CloudC%Frequency_IR(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_IR(CloudC%n_IR_Radii),Reff),CloudC%Reff_IR(1))
    CALL find_index(CloudC%Reff_IR, r_int, j1,j2)
    r = CloudC%Reff_IR(j1:j2)
    
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output
    
    ! Calculate the TL interpolating polynomials 
    ! ------------------------------------------
    ! Frequency term (always zero. This is a placeholder for testing)
    CALL LPoly_TL( f,    f_int,    & ! FWD Input
                   wlp,            & ! FWD Input
                   f_TL, f_int_TL, & ! TL  Input
                   wlp_TL          ) ! TL  Output
    ! Effective radius term
    CALL LPoly_TL( r, r_int,       & ! FWD Input
                   xlp,            & ! FWD Input
                   r_TL, r_int_TL, & ! TL  Input
                   xlp_TL          ) ! TL  Output
    
    ! Determine the density index, k, for the clouds
    ! based on CloudC LUT organisation
    ! ----------------------------------------------
    SELECT CASE (Cloud_Type)
      CASE(WATER_CLOUD)  ; k=0  ! Liquid
      CASE(ICE_CLOUD)    ; k=3  ! Solid
      CASE(RAIN_CLOUD)   ; k=0  ! Liquid
      CASE(SNOW_CLOUD)   ; k=1  ! Solid
      CASE(GRAUPEL_CLOUD); k=2  ! Solid
      CASE(HAIL_CLOUD)   ; k=3  ! Solid
    END SELECT
    
    ! Perform interpolation based on cloud type
    ! -----------------------------------------
    ! Extinction coefficient
    z = CloudC%ke_IR(i1:i2,j1:j2,k)
    CALL interp_2D_TL( z   , wlp   , xlp   , &  ! FWD Input
                       z_TL, wlp_TL, xlp_TL, &  ! TL  Input
                       ke_TL                 )  ! TL  Output
    ! Single scatter albedo
    z = CloudC%w_IR(i1:i2,j1:j2,k)
    CALL interp_2D_TL( z   , wlp   , xlp   , &  ! FWD Input
                       z_TL, wlp_TL, xlp_TL, &  ! TL  Input
                       w_TL                  )  ! TL  Output
    ! Asymmetry factor
    z = CloudC%g_IR(i1:i2,j1:j2,k)
    CALL interp_2D_TL( z   , wlp   , xlp   , &  ! FWD Input
                       z_TL, wlp_TL, xlp_TL, &  ! TL  Input
                       g_TL                  )  ! TL  Output
    ! Phase matrix coefficients
    IF ( CloudScatter_TL%n_Phase_Elements > 0 .AND. &
         CloudScatter_TL%n_Legendre_Terms > 2       ) THEN
      DO l = 0, CloudScatter_TL%n_Legendre_Terms
        z = CloudC%pcoeff_IR(i1:i2,j1:j2,k,l+CloudScatter_TL%lOffset)
        CALL interp_2D_TL( z   , wlp   , xlp   , &  ! FWD Input
                           z_TL, wlp_TL, xlp_TL, &  ! TL  Input
                           pcoeff_TL(l,1)        )  ! TL  Output
      END DO
    END IF

  END SUBROUTINE Get_Cloud_Opt_IR_TL


  ! ---------------------------------------------
  ! Subroutine to obtain the adjoint of the
  ! IR bulk optical properties of a cloud:
  !   effective radius (Reff_AD),
  !   effective variance (Reff_Var_AD)
  ! ---------------------------------------------
  SUBROUTINE Get_Cloud_Opt_IR_AD( CloudScatter_AD, &  ! Input      CloudScatter AD structure
                                  Frequency      , &  ! Input      Frequency (cm^-1) 
                                  cloud_type     , &  ! Input      see CRTM_Cloud_Define.f90
                                  Reff           , &  ! FWD Input  effective radius (mm)
                                  Reff_Var       , &  ! FWD Input  variance of effective radius
                                  ke_AD          , &  ! AD  Input  extinction coefficient (=~ optical depth for 1 mm water content)
                                  w_AD           , &  ! AD  Input  single scattering albedo
                                  g_AD           , &  ! AD  Input  asymmetry factor
                                  pcoeff_AD      , &  ! AD  Input  spherical Legendre coefficients
                                  Reff_AD        , &  ! AD  Output effective radius (mm)
                                  Reff_Var_AD      )  ! AD  Output variance of effective radius
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter_AD
    REAL(fp),                   INTENT(IN)     :: Frequency
    INTEGER ,                   INTENT(IN)     :: Cloud_Type
    REAL(fp),                   INTENT(IN)     :: Reff
    REAL(fp),                   INTENT(IN)     :: Reff_Var
    REAL(fp),                   INTENT(IN OUT) :: ke_AD           ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: w_AD            ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: g_AD            ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: pcoeff_AD(0:,:) ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: Reff_AD         ! AD  Output
    REAL(fp),                   INTENT(IN OUT) :: Reff_Var_AD     ! AD  Output
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k
    INTEGER  :: l
    REAL(fp) :: f_int   , r_int
    REAL(fp) :: f_int_AD, r_int_AD
    REAL(fp), DIMENSION(NPTS) :: f   , r
    REAL(fp), DIMENSION(NPTS) :: f_AD, r_AD
    REAL(fp), DIMENSION(NPTS,NPTS) :: z, z_AD
    TYPE(LPoly_type) :: wlp   , xlp
    TYPE(LPoly_type) :: wlp_AD, xlp_AD

    ! Setup
    ! -----
    ! No AD output when effective radius
    ! is outside LUT bounds
    IF ( Reff < CloudC%Reff_IR(1) .OR. &
         Reff > CloudC%Reff_IR(CloudC%n_IR_Radii) ) THEN
      Reff_AD     = ZERO
      Reff_Var_AD = ZERO
      ke_AD     = ZERO
      w_AD      = ZERO
      g_AD      = ZERO
      pcoeff_AD = ZERO
      RETURN
    END IF
    ! Initialise local adjoint variables
    f_int_AD = ZERO
    r_int_AD = ZERO
    f_AD = ZERO
    r_AD = ZERO
    z_AD = ZERO
    CALL Clear_LPoly(wlp_AD)
    CALL Clear_LPoly(xlp_AD)
    
    ! Find the frequency and effective
    ! radius indices for interpolation
    ! --------------------------------
    f_int = MAX(MIN(CloudC%Frequency_IR(CloudC%n_IR_Frequencies),Frequency),CloudC%Frequency_IR(1))
!    CALL find_index(CloudC%Frequency_IR, WAVENUMBER_SPACING, f_int, i1,i2)
    CALL find_index(CloudC%Frequency_IR, f_int, i1,i2)
    f = CloudC%Frequency_IR(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_IR(CloudC%n_IR_Radii),Reff),CloudC%Reff_IR(1))
    CALL find_index(CloudC%Reff_IR, r_int, j1,j2)
    r = CloudC%Reff_IR(j1:j2)
 
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output

    ! Determine the density index, k, for the clouds
    ! based on CloudC LUT organisation
    ! ----------------------------------------------
    SELECT CASE (Cloud_Type)
      CASE(WATER_CLOUD)  ; k=0  ! Liquid
      CASE(ICE_CLOUD)    ; k=3  ! Solid
      CASE(RAIN_CLOUD)   ; k=0  ! Liquid
      CASE(SNOW_CLOUD)   ; k=1  ! Solid
      CASE(GRAUPEL_CLOUD); k=2  ! Solid
      CASE(HAIL_CLOUD)   ; k=3  ! Solid
    END SELECT
    
    ! Perform interpolation
    ! ---------------------
    ! Phase matrix coefficients
    IF (CloudScatter_AD%n_Phase_Elements > 0 .AND. &
        CloudScatter_AD%n_Legendre_Terms > 2       ) THEN
      DO l = 0, CloudScatter_AD%n_Legendre_Terms
        z = CloudC%pcoeff_IR(i1:i2,j1:j2,k,l+CloudScatter_AD%lOffset)
        CALL interp_2D_AD( z   , wlp   , xlp   , &  ! FWD Input
                           pcoeff_AD(l,1)      , &  ! AD  Input
                           z_AD, wlp_AD, xlp_AD  )  ! AD  Output
      END DO
    END IF
    ! Asymmetry factor
    z = CloudC%g_IR(i1:i2,j1:j2,k)
    CALL interp_2D_AD( z   , wlp   , xlp   , &  ! FWD Input
                       g_AD                , &  ! AD  Input
                       z_AD, wlp_AD, xlp_AD  )  ! AD  Output
    ! Single scatter albedo
    z = CloudC%w_IR(i1:i2,j1:j2,k)
    CALL interp_2D_AD( z   , wlp   , xlp   , &  ! FWD Input
                       w_AD                , &  ! AD  Input
                       z_AD, wlp_AD, xlp_AD  )  ! AD  Output
    ! Extinction coefficient
    z = CloudC%ke_IR(i1:i2,j1:j2,k)
    CALL interp_2D_AD( z   , wlp   , xlp   , &  ! FWD Input
                       ke_AD               , &  ! AD  Input
                       z_AD, wlp_AD, xlp_AD  )  ! AD  Output

    ! Compute the AD of the interpolating polynomials
    ! -----------------------------------------------
    ! Efective radius term
    CALL LPoly_AD( r,    r_int,   & ! FWD Input
                   xlp,           & ! FWD Input
                   xlp_AD,        & ! AD  Input
                   r_AD, r_int_AD ) ! AD  Output
    ! Frequency term (always zero. This is a placeholder for testing)
    CALL LPoly_AD( f,    f_int,   & ! FWD Input
                   wlp,           & ! FWD Input
                   wlp_AD,        & ! AD  Input
                   f_AD, f_int_AD ) ! AD  Output
    
    ! The AD outputs
    ! --------------
    Reff_Var_AD = ZERO
    Reff_AD = Reff_AD + r_int_AD
    
  END SUBROUTINE Get_Cloud_Opt_IR_AD


  ! ------------------------------------------
  ! Subroutine to obtain the MW bulk
  ! optical properties of a cloud:
  !   extinction coefficient (ke),
  !   scattereing coefficient (w)
  !   asymmetry factor (g), and
  !   spherical Legendre coefficients (pcoeff)
  ! ------------------------------------------
  SUBROUTINE Get_Cloud_Opt_MW(CloudScatter, &  ! Input  CloudScatter structure
                              Frequency   , &  ! Input  Frequency (GHz) 
                              cloud_type  , &  ! Input  see CRTM_Cloud_Define.f90
                              Reff        , &  ! Input  effective radius (mm)
                              Reff_Var    , &  ! Input  variance of effective radius
                              Temperature , &  ! Input  cloudy temperature
                              ke          , &  ! Input optical depth for 1 mm water content
                              w           , &  ! Input single scattering albedo
                              g           , &  ! Input asymmetry factor
                              pcoeff        )  ! Output spherical Legendre coefficients
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter
    REAL(fp)                  , INTENT(IN)     :: Frequency
    INTEGER                   , INTENT(IN)     :: Cloud_Type
    REAL(fp)                  , INTENT(IN)     :: Reff
    REAL(fp)                  , INTENT(IN)     :: Reff_Var
    REAL(fp)                  , INTENT(IN)     :: Temperature
    REAL(fp)                  , INTENT(OUT)    :: ke
    REAL(fp)                  , INTENT(OUT)    :: w
    REAL(fp)                  , INTENT(OUT)    :: g
    REAL(fp)                  , INTENT(IN OUT) :: pcoeff(0:,:)
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k1, k2
    INTEGER  :: j, k, l, m
    REAL(fp) :: f_int, r_int, t_int
    REAL(fp), DIMENSION(NPTS) :: f, r, t
    TYPE(LPoly_type) :: wlp, xlp, ylp

    ! Initialise results that may
    ! not be interpolated
    ! ---------------------------
    w      = ZERO
    g      = ZERO
    pcoeff = ZERO
    
    ! Find the frequency, effective radius
    ! and temperature indices for interpolation
    ! -----------------------------------------
    f_int = MAX(MIN(CloudC%Frequency_MW(CloudC%n_MW_Frequencies),Frequency),CloudC%Frequency_MW(1))
    CALL find_index(CloudC%Frequency_MW, f_int, i1,i2)
    f = CloudC%Frequency_MW(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_MW(CloudC%n_MW_Radii),Reff),CloudC%Reff_MW(1))
    CALL find_index(CloudC%Reff_MW, r_int, j1,j2)
    r = CloudC%Reff_MW(j1:j2)
 
    t_int = MAX(MIN(CloudC%Temperature(CloudC%n_Temperatures),Temperature),CloudC%Temperature(1))
    CALL find_index(CloudC%Temperature, t_int, k1,k2)
    t = CloudC%Temperature(k1:k2)
    
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output
    ! Temperature term
    CALL LPoly( t, t_int, &  ! Input
                ylp       )  ! Output
        
    ! Perform interpolation based on cloud type
    ! -----------------------------------------
    SELECT CASE (Cloud_Type)
    
      ! Only 2-D interpolation of extinction coefficient as a
      ! fn. of frequency and temperature for water cloud; i.e.
      ! we're only considering Rayleigh scattering here.
      CASE (WATER_CLOUD)
        j = 1
        CALL interp_2D( CloudC%ke_L_MW(i1:i2,j,k1:k2), wlp, ylp, ke )

      ! All 3-D interpolations for rain cloud!
      CASE (RAIN_CLOUD)
        CALL interp_3D( CloudC%ke_L_MW(i1:i2,j1:j2,k1:k2), wlp, xlp, ylp, ke )
        CALL interp_3D( CloudC%w_L_MW(i1:i2,j1:j2,k1:k2) , wlp, xlp, ylp, w  )
        CALL interp_3D( CloudC%g_L_MW(i1:i2,j1:j2,k1:k2) , wlp, xlp, ylp, g  )
        IF ( CloudScatter%n_Phase_Elements > 0 .AND. &
             CloudScatter%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter%n_Phase_Elements
            DO l = 0, CloudScatter%n_Legendre_Terms
              CALL interp_3D( CloudC%pcoeff_L_MW(i1:i2,j1:j2,k1:k2,l+CloudScatter%lOffset,m), &
                              wlp, xlp, ylp, pcoeff(l,m) )
            END DO
          END DO
        END IF

      ! Only 1-D interpolation of extinction coefficient as a
      ! fn. of frequency for ice cloud
      CASE (ICE_CLOUD)
        j = 1; k = 3
        CALL interp_1D( CloudC%ke_S_MW(i1:i2,j,k), wlp, ke )

      ! The remaining cloud types have 2-D interpolation
      ! as a fn. of frequency and radius
      CASE DEFAULT
        ! Select the LUT temperature
        SELECT CASE (Cloud_Type)
          CASE (GRAUPEL_CLOUD); k = 2
          CASE (HAIL_CLOUD)   ; k = 3
          CASE DEFAULT        ; k = 1
        END SELECT
        ! Perform interpolation
        CALL interp_2D( CloudC%ke_S_MW(i1:i2,j1:j2,k), wlp, xlp, ke )
        CALL interp_2D( CloudC%w_S_MW(i1:i2,j1:j2,k) , wlp, xlp, w  )
        CALL interp_2D( CloudC%g_S_MW(i1:i2,j1:j2,k) , wlp, xlp, g  )
        IF (CloudScatter%n_Phase_Elements > 0 .AND. &
            CloudScatter%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter%n_Phase_Elements
            DO l = 0, CloudScatter%n_Legendre_Terms
              CALL interp_2D( CloudC%pcoeff_S_MW(i1:i2,j1:j2,k,l+CloudScatter%lOffset,m), &
                              wlp, xlp, pcoeff(l,m) )
            END DO
          END DO
        END IF
    END SELECT
    
  END SUBROUTINE Get_Cloud_Opt_MW


  ! ---------------------------------------------
  ! Subroutine to obtain the tangent-linear
  ! MW bulk optical properties of a cloud:
  !   extinction coefficient (ke_TL),
  !   scattereing coefficient (w_TL)
  !   asymmetry factor (g_TL), and
  !   spherical Legendre coefficients (pcoeff_TL)
  ! ---------------------------------------------
  SUBROUTINE Get_Cloud_Opt_MW_TL(CloudScatter_TL, &  ! Input      CloudScatter TL structure
                                 Frequency      , &  ! Input  frequency in GHz 
                                 cloud_type     , &  ! Input  see CRTM_Cloud_Define.f90
                                 Reff           , &  ! Input  effective radius (mm)
                                 Reff_Var       , &  ! Input  variance of effective radius
                                 Temperature    , &  ! Input  cloudy temperature
                                 Reff_TL        , &  ! Input  effective radius (mm)
                                 Reff_Var_TL    , &  ! Input  variance of effective radius
                                 Temperature_TL , &  ! Input  cloudy temperature
                                 ke_TL          , &  ! Output extinction coefficient (=~ optical depth for 1 mm water content)
                                 w_TL           , &  ! Output single scattering albedo
                                 g_TL           , &  ! Output asymmetry factor
                                 pcoeff_TL        )  ! Output spherical Legendre coefficients
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter_TL
    REAL(fp),                   INTENT(IN)     :: Frequency
    INTEGER ,                   INTENT(IN)     :: Cloud_Type
    REAL(fp),                   INTENT(IN)     :: Reff
    REAL(fp),                   INTENT(IN)     :: Reff_Var
    REAL(fp),                   INTENT(IN)     :: Temperature
    REAL(fp),                   INTENT(IN)     :: Reff_TL
    REAL(fp),                   INTENT(IN)     :: Reff_Var_TL
    REAL(fp),                   INTENT(IN)     :: Temperature_TL
    REAL(fp),                   INTENT(OUT)    :: ke_TL
    REAL(fp),                   INTENT(OUT)    :: w_TL
    REAL(fp),                   INTENT(OUT)    :: g_TL
    REAL(fp),                   INTENT(IN OUT) :: pcoeff_TL(0:,:)
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k1, k2
    INTEGER  :: j, k, l, m
    REAL(fp) :: f_int   , r_int   , t_int
    REAL(fp) :: f_int_TL, r_int_TL, t_int_TL
    REAL(fp), DIMENSION(NPTS) :: f   , r   , t
    REAL(fp), DIMENSION(NPTS) :: f_TL, r_TL, t_TL
    REAL(fp), DIMENSION(NPTS,NPTS)      :: z2, z2_TL
    REAL(fp), DIMENSION(NPTS,NPTS,NPTS) :: z3, z3_TL
    TYPE(LPoly_type) :: wlp   , xlp   , ylp
    TYPE(LPoly_type) :: wlp_TL, xlp_TL, ylp_TL

    ! Setup
    ! -----
    ! Initialise results that may
    ! not be interpolated
    w_TL      = ZERO
    g_TL      = ZERO
    pcoeff_TL = ZERO
    ! The local TL inputs
    f_int_TL = ZERO
    f_TL     = ZERO
    r_int_TL = Reff_TL
    r_TL     = ZERO
    t_int_TL = Temperature_TL
    t_TL     = ZERO
    z2_TL = ZERO
    z3_TL = ZERO
    
    ! Find the frequency, effective radius
    ! and temperature indices for interpolation
    ! -----------------------------------------
    f_int = MAX(MIN(CloudC%Frequency_MW(CloudC%n_MW_Frequencies),Frequency),CloudC%Frequency_MW(1))
    CALL find_index(CloudC%Frequency_MW, f_int, i1,i2)
    f = CloudC%Frequency_MW(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_MW(CloudC%n_MW_Radii),Reff),CloudC%Reff_MW(1))
    CALL find_index(CloudC%Reff_MW, r_int, j1,j2)
    r = CloudC%Reff_MW(j1:j2)
 
    t_int = MAX(MIN(CloudC%Temperature(CloudC%n_Temperatures),Temperature),CloudC%Temperature(1))
    CALL find_index(CloudC%Temperature, t_int, k1,k2)
    t = CloudC%Temperature(k1:k2)
 
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output
    ! Temperature term
    CALL LPoly( t, t_int, &  ! Input
                ylp       )  ! Output

    ! Calculate the TL interpolating polynomials 
    ! ------------------------------------------
    ! Frequency term (always zero. This is a placeholder for testing)
    CALL LPoly_TL( f,    f_int,    & ! FWD Input
                   wlp,            & ! FWD Input
                   f_TL, f_int_TL, & ! TL  Input
                   wlp_TL          ) ! TL  Output
    ! Effective radius term
    CALL LPoly_TL( r, r_int,       & ! FWD Input
                   xlp,            & ! FWD Input
                   r_TL, r_int_TL, & ! TL  Input
                   xlp_TL          ) ! TL  Output
    ! Temperature term
    CALL LPoly_TL( t, t_int,       & ! FWD Input
                   ylp,            & ! FWD Input
                   t_TL, t_int_TL, & ! TL  Input
                   ylp_TL          ) ! TL  Output
    
 
    ! Perform interpolation based on cloud type
    ! -----------------------------------------
    SELECT CASE (Cloud_Type)

      ! Only 2-D interpolation of extinction coefficient as a
      ! fn. of frequency and temperature for water cloud; i.e.
      ! we're only considering Rayleigh scattering here.
      CASE (WATER_CLOUD)
        ! No TL output when temperature
        ! is outside LUT bounds
        IF ( Temperature < CloudC%Temperature(1) .OR. &
             Temperature > CloudC%Temperature(CloudC%n_Temperatures) ) THEN
          ke_TL     = ZERO
          w_TL      = ZERO
          g_TL      = ZERO
          pcoeff_TL = ZERO
          RETURN
        END IF
        j = 1
        z2 = CloudC%ke_L_MW(i1:i2,j,k1:k2)
        CALL interp_2D_TL( z2   , wlp   , ylp   , &  ! FWD Input
                           z2_TL, wlp_TL, ylp_TL, &  ! TL  Input
                           ke_TL                  )  ! TL  Output

      ! All 3-D interpolations for rain cloud!
      CASE (RAIN_CLOUD)
        ! No TL output when both effective radius
        ! and temperature are outside LUT bounds
        IF ( ( Reff < CloudC%Reff_MW(1) .OR. &
               Reff > CloudC%Reff_MW(CloudC%n_MW_Radii) ) .AND. &
             ( Temperature < CloudC%Temperature(1) .OR. &
               Temperature > CloudC%Temperature(CloudC%n_Temperatures) ) ) THEN
          ke_TL = ZERO
          RETURN
        END IF
        ! Extinction coefficient
        z3 = CloudC%ke_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_TL( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           z3_TL, wlp_TL, xlp_TL, ylp_TL, &  ! TL  Input
                           ke_TL                          )  ! TL  Output
        ! Single scatter albedo
        z3 = CloudC%w_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_TL( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           z3_TL, wlp_TL, xlp_TL, ylp_TL, &  ! TL  Input
                           w_TL                           )  ! TL  Output
        ! Asymmetry factor
        z3 = CloudC%g_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_TL( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           z3_TL, wlp_TL, xlp_TL, ylp_TL, &  ! TL  Input
                           g_TL                           )  ! TL  Output
        ! Phase matrix coefficients
        IF ( CloudScatter_TL%n_Phase_Elements > 0 .AND. &
             CloudScatter_TL%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter_TL%n_Phase_Elements
            DO l = 0, CloudScatter_TL%n_Legendre_Terms
              z3 = CloudC%pcoeff_L_MW(i1:i2,j1:j2,k1:k2,l+CloudScatter_TL%lOffset,m)
              CALL interp_3D_TL( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                                 z3_TL, wlp_TL, xlp_TL, ylp_TL, &  ! TL  Input
                                 pcoeff_TL(l,m)                 )  ! TL  Output
            END DO
          END DO
        END IF

      ! No TL interpolation of extinction coefficient as it
      ! is only a fn. of frequency for ice cloud
      CASE (ICE_CLOUD)
        ke_TL = ZERO

      ! The remaining cloud types have 2-D interpolation
      ! as a fn. of frequency and radius
      CASE DEFAULT
        ! No TL output when effective radius
        ! is outside LUT bounds
        IF ( Reff < CloudC%Reff_MW(1) .OR. &
             Reff > CloudC%Reff_MW(CloudC%n_MW_Radii) ) THEN
          ke_TL = ZERO
          RETURN
        END IF
        ! Select the LUT temperature
        SELECT CASE (Cloud_Type)
          CASE (GRAUPEL_CLOUD); k = 2
          CASE (HAIL_CLOUD)   ; k = 3
          CASE DEFAULT        ; k = 1
        END SELECT
        ! Extinction coefficient
        z2 = CloudC%ke_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_TL( z2   , wlp   , xlp   , &  ! FWD Input
                           z2_TL, wlp_TL, xlp_TL, &  ! TL  Input
                           ke_TL                  )  ! TL  Output
        ! Single scatter albedo
        z2 = CloudC%w_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_TL( z2   , wlp   , xlp   , &  ! FWD Input
                           z2_TL, wlp_TL, xlp_TL, &  ! TL  Input
                           w_TL                   )  ! TL  Output
        ! Asymmetry factor
        z2 = CloudC%g_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_TL( z2   , wlp   , xlp   , &  ! FWD Input
                           z2_TL, wlp_TL, xlp_TL, &  ! TL  Input
                           g_TL                   )  ! TL  Output
        ! Phase matrix coefficients
        IF ( CloudScatter_TL%n_Phase_Elements > 0 .AND. &
             CloudScatter_TL%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter_TL%n_Phase_Elements
            DO l = 0, CloudScatter_TL%n_Legendre_Terms
              z2 = CloudC%pcoeff_S_MW(i1:i2,j1:j2,k,l+CloudScatter_TL%lOffset,m)
              CALL interp_2D_TL( z2   , wlp   , xlp   , &  ! FWD Input
                                 z2_TL, wlp_TL, xlp_TL, &  ! TL  Input
                                 pcoeff_TL(l,m)         )  ! TL  Output
            END DO
          END DO
        END IF
    END SELECT
    
  END SUBROUTINE Get_Cloud_Opt_MW_TL


  ! ---------------------------------------------
  ! Subroutine to obtain the adjoint of the
  ! MW bulk optical properties of a cloud:
  !   effective radius (Reff_AD),
  !   effective variance (Reff_Var_AD)
  !   temperature (temperature_AD)
  ! ---------------------------------------------
  SUBROUTINE Get_Cloud_Opt_MW_AD(CloudScatter_AD, &  ! Input      CloudScatter AD structure
                                 Frequency      , &  ! Input      frequency in GHz          
                                 cloud_type     , &  ! Input      see CRTM_Cloud_Define.f90 
                                 Reff           , &  ! FWD Input  effective radius (mm)
                                 Reff_Var       , &  ! FWD Input  variance of effective radius
                                 Temperature    , &  ! FWD Input  cloudy temperature
                                 ke_AD          , &  ! AD  Input  extinction coefficient (=~ optical depth for 1 mm water content)
                                 w_AD           , &  ! AD  Input  single scattering albedo
                                 g_AD           , &  ! AD  Input  asymmetry factor
                                 pcoeff_AD      , &  ! AD  Input  spherical Legendre coefficients
                                 Reff_AD        , &  ! AD  Output effective radius (mm)
                                 Reff_Var_AD    , &  ! AD  Output variance of effective radius
                                 Temperature_AD   )  ! AD  Output temperature
    ! Arguments
    TYPE(CRTM_AtmScatter_type), INTENT(IN)     :: CloudScatter_AD
    REAL(fp),                   INTENT(IN)     :: Frequency
    INTEGER ,                   INTENT(IN)     :: Cloud_Type
    REAL(fp),                   INTENT(IN)     :: Reff
    REAL(fp),                   INTENT(IN)     :: Reff_Var
    REAL(fp),                   INTENT(IN)     :: Temperature
    REAL(fp),                   INTENT(IN OUT) :: ke_AD           ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: w_AD            ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: g_AD            ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: pcoeff_AD(0:,:) ! AD  Input 
    REAL(fp),                   INTENT(IN OUT) :: Reff_AD         ! AD  Output
    REAL(fp),                   INTENT(IN OUT) :: Reff_Var_AD     ! AD  Output
    REAL(fp),                   INTENT(IN OUT) :: Temperature_AD  ! AD  Output
    ! Local variables
    INTEGER  :: i1, i2
    INTEGER  :: j1, j2
    INTEGER  :: k1, k2
    INTEGER  :: j, k, l, m
    REAL(fp) :: f_int   , r_int   , t_int
    REAL(fp) :: f_int_AD, r_int_AD, t_int_AD
    REAL(fp), DIMENSION(NPTS) :: f   , r   , t
    REAL(fp), DIMENSION(NPTS) :: f_AD, r_AD, t_AD
    REAL(fp), DIMENSION(NPTS,NPTS)      :: z2, z2_AD
    REAL(fp), DIMENSION(NPTS,NPTS,NPTS) :: z3, z3_AD
    TYPE(LPoly_type) :: wlp   , xlp   , ylp
    TYPE(LPoly_type) :: wlp_AD, xlp_AD, ylp_AD

    ! Setup
    ! -----
    ! Effective variance isn't used yet
    Reff_Var_AD = ZERO
    ! Initialise local adjoint variables
    f_int_AD = ZERO
    f_AD     = ZERO
    r_int_AD = ZERO
    r_AD     = ZERO
    t_int_AD = ZERO
    t_AD     = ZERO
    z2_AD = ZERO
    z3_AD = ZERO
    CALL Clear_LPoly(wlp_AD)
    CALL Clear_LPoly(xlp_AD)
    CALL Clear_LPoly(ylp_AD)
    
    ! Find the frequency, effective radius
    ! and temperature indices for interpolation
    ! -----------------------------------------
    f_int = MAX(MIN(CloudC%Frequency_MW(CloudC%n_MW_Frequencies),Frequency),CloudC%Frequency_MW(1))
    CALL find_index(CloudC%Frequency_MW, f_int, i1,i2)
    f = CloudC%Frequency_MW(i1:i2)

    r_int = MAX(MIN(CloudC%Reff_MW(CloudC%n_MW_Radii),Reff),CloudC%Reff_MW(1))
    CALL find_index(CloudC%Reff_MW, r_int, j1,j2)
    r = CloudC%Reff_MW(j1:j2)
 
    t_int = MAX(MIN(CloudC%Temperature(CloudC%n_Temperatures),Temperature),CloudC%Temperature(1))
    CALL find_index(CloudC%Temperature, t_int, k1,k2)
    t = CloudC%Temperature(k1:k2)
 
    ! Calculate the interpolating polynomials
    ! ---------------------------------------
    ! Frequency term
    CALL LPoly( f, f_int, &  ! Input
                wlp       )  ! Output
    ! Effective radius term
    CALL LPoly( r, r_int, &  ! Input
                xlp       )  ! Output
    ! Temperature term
    CALL LPoly( t, t_int, &  ! Input
                ylp       )  ! Output
 
    ! Perform interpolation based on cloud type
    ! -----------------------------------------
    SELECT CASE (Cloud_Type)

      ! Only 2-D interpolation of extinction coefficient as a
      ! fn. of frequency and temperature for water cloud; i.e.
      ! we're only considering Rayleigh scattering here.
      CASE (WATER_CLOUD)
        ! No AD output when temperature
        ! is outside LUT bounds
        IF ( Temperature < CloudC%Temperature(1) .OR. &
             Temperature > CloudC%Temperature(CloudC%n_Temperatures) ) THEN
          ke_AD     = ZERO
          w_AD      = ZERO
          g_AD      = ZERO
          pcoeff_AD = ZERO
          RETURN
        END IF
        ! Perform the AD interpolations
        j = 1
        z2 = CloudC%ke_L_MW(i1:i2,j,k1:k2)
        CALL interp_2D_AD( z2   , wlp   , ylp   , &  ! FWD Input
                           ke_AD                , &  ! AD  Input
                           z2_AD, wlp_AD, ylp_AD  )  ! AD  Output
        
                           
        ! Compute the AD of the interpolating polynomials
        ! -----------------------------------------------
        ! Temperature term
        CALL LPoly_AD( t,    t_int,   & ! FWD Input
                       ylp,           & ! FWD Input
                       ylp_AD,        & ! AD  Input
                       t_AD, t_int_AD ) ! AD  Output
        ! Frequency term (always zero. This is a placeholder for testing)
        CALL LPoly_AD( f,    f_int,   & ! FWD Input
                       wlp,           & ! FWD Input
                       wlp_AD,        & ! AD  Input
                       f_AD, f_int_AD ) ! AD  Output
        ! The AD outputs
        ! --------------
        Temperature_AD = Temperature_AD + t_int_AD

      ! All 3-D interpolations for rain cloud!
      CASE (RAIN_CLOUD)
        ! No TL output when both effective radius
        ! and temperature are outside LUT bounds
        IF ( ( Reff < CloudC%Reff_MW(1) .OR. &
               Reff > CloudC%Reff_MW(CloudC%n_MW_Radii) ) .AND. &
             ( Temperature < CloudC%Temperature(1) .OR. &
               Temperature > CloudC%Temperature(CloudC%n_Temperatures) ) ) THEN
          ke_AD     = ZERO
          w_AD      = ZERO
          g_AD      = ZERO
          pcoeff_AD = ZERO
          RETURN
        END IF
        ! Perform the AD interpolations
        ! -----------------------------
        ! Phase matrix coefficients
        IF (CloudScatter_AD%n_Phase_Elements > 0 .AND. &
            CloudScatter_AD%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter_AD%n_Phase_Elements
            DO l = 0, CloudScatter_AD%n_Legendre_Terms
              z3 = CloudC%pcoeff_L_MW(i1:i2,j1:j2,k1:k2,l+CloudScatter_AD%lOffset,m)
              CALL interp_3D_AD( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                                 pcoeff_AD(l,m)               , &  ! AD  Input
                                 z3_AD, wlp_AD, xlp_AD, ylp_AD  )  ! AD  Output
            END DO
          END DO
        END IF
        ! Asymmetry factor
        z3 = CloudC%g_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_AD( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           g_AD                         , &  ! AD  Input
                           z3_AD, wlp_AD, xlp_AD, ylp_AD  )  ! AD  Output
        ! Single scatter albedo
        z3 = CloudC%w_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_AD( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           w_AD                         , &  ! AD  Input
                           z3_AD, wlp_AD, xlp_AD, ylp_AD  )  ! AD  Output
        ! Extinction coefficient
        z3 = CloudC%ke_L_MW(i1:i2,j1:j2,k1:k2)
        CALL interp_3D_AD( z3   , wlp   , xlp   , ylp   , &  ! FWD Input
                           ke_AD                        , &  ! AD  Input
                           z3_AD, wlp_AD, xlp_AD, ylp_AD  )  ! AD  Output
        ! Compute the AD of the interpolating polynomials
        ! -----------------------------------------------
        ! Temperature term
        CALL LPoly_AD( t,    t_int,   & ! FWD Input
                       ylp,           & ! FWD Input
                       ylp_AD,        & ! AD  Input
                       t_AD, t_int_AD ) ! AD  Output
        ! Effective radius term
        CALL LPoly_AD( r,    r_int,   & ! FWD Input
                       xlp,           & ! FWD Input
                       xlp_AD,        & ! AD  Input
                       r_AD, r_int_AD ) ! AD  Output
        ! Frequency term (always zero. This is a placeholder for testing)
        CALL LPoly_AD( f,    f_int,   & ! FWD Input
                       wlp,           & ! FWD Input
                       wlp_AD,        & ! AD  Input
                       f_AD, f_int_AD ) ! AD  Output
        ! The AD outputs
        ! --------------
        Temperature_AD = Temperature_AD + t_int_AD
        Reff_AD = Reff_AD + r_int_AD

      ! No AD interpolation as it is only a fn.
      ! of frequency for ice cloud
      CASE (ICE_CLOUD)
        ke_AD     = ZERO
        w_AD      = ZERO
        g_AD      = ZERO
        pcoeff_AD = ZERO

      ! The remaining cloud types have 2-D interpolation
      ! as a fn. of frequency and radius
      CASE DEFAULT
        ! No TL output when effective radius
        ! is outside LUT bounds
        IF ( Reff < CloudC%Reff_MW(1) .OR. &
             Reff > CloudC%Reff_MW(CloudC%n_MW_Radii) ) THEN
          ke_AD     = ZERO
          w_AD      = ZERO
          g_AD      = ZERO
          pcoeff_AD = ZERO
          RETURN
        END IF
        ! Select the LUT temperature
        SELECT CASE (Cloud_Type)
          CASE (GRAUPEL_CLOUD); k = 2
          CASE (HAIL_CLOUD)   ; k = 3
          CASE DEFAULT        ; k = 1
        END SELECT
        ! Perform the AD interpolations
        ! -----------------------------
        ! Phase matrix coefficients
        IF (CloudScatter_AD%n_Phase_Elements > 0 .AND. &
            CloudScatter_AD%n_Legendre_Terms > 2       ) THEN
          DO m = 1, CloudScatter_AD%n_Phase_Elements
            DO l = 0, CloudScatter_AD%n_Legendre_Terms
              z2 = CloudC%pcoeff_S_MW(i1:i2,j1:j2,k,l+CloudScatter_AD%lOffset,m)
              CALL interp_2D_AD( z2   , wlp   , xlp   , &  ! FWD Input
                                 pcoeff_AD(l,m)       , &  ! AD  Input
                                 z2_AD, wlp_AD, xlp_AD  )  ! AD  Output
            END DO
          END DO
        END IF
        ! Asymmetry factor
        z2 = CloudC%g_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_AD( z2   , wlp   , xlp   , &  ! FWD Input
                           g_AD                 , &  ! AD  Input
                           z2_AD, wlp_AD, xlp_AD  )  ! AD  Output
        ! Single scatter albedo
        z2 = CloudC%w_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_AD( z2   , wlp   , xlp   , &  ! FWD Input
                           w_AD                 , &  ! AD  Input
                           z2_AD, wlp_AD, xlp_AD  )  ! AD  Output
        ! Extinction coefficient
        z2 = CloudC%ke_S_MW(i1:i2,j1:j2,k)
        CALL interp_2D_AD( z2   , wlp   , xlp   , &  ! FWD Input
                           ke_AD                , &  ! AD  Input
                           z2_AD, wlp_AD, xlp_AD  )  ! AD  Output
        ! Compute the AD of the interpolating polynomials
        ! -----------------------------------------------
        ! Effective radius term
        CALL LPoly_AD( r,    r_int,   & ! FWD Input
                       xlp,           & ! FWD Input
                       xlp_AD,        & ! AD  Input
                       r_AD, r_int_AD ) ! AD  Output
        ! Frequency term (always zero. This is a placeholder for testing)
        CALL LPoly_AD( f,    f_int,   & ! FWD Input
                       wlp,           & ! FWD Input
                       wlp_AD,        & ! AD  Input
                       f_AD, f_int_AD ) ! AD  Output
        ! The AD outputs
        ! --------------
        Reff_AD = Reff_AD + r_int_AD

    END SELECT
    
  END SUBROUTINE Get_Cloud_Opt_MW_AD

END MODULE CRTM_CloudScatter
