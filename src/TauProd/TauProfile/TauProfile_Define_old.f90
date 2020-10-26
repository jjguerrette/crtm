
MODULE TauProfile_Define_old


  ! ----------
  ! Module use
  ! ----------

  USE Type_Kinds
  USE Message_Handler
  USE Compare_Float_Numbers


  ! -----------------------
  ! Disable implicit typing
  ! -----------------------

  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------

  PRIVATE
  PUBLIC :: Associated_TauProfile
  PUBLIC :: Destroy_TauProfile
  PUBLIC :: Allocate_TauProfile
  PUBLIC :: Assign_TauProfile
  PUBLIC :: Concatenate_TauProfile
  PUBLIC :: Information_TauProfile


  ! ---------------------
  ! Procedure overloading
  ! ---------------------

  INTERFACE Destroy_TauProfile
    MODULE PROCEDURE Destroy_TauProfile_scalar
    MODULE PROCEDURE Destroy_TauProfile_rank1
  END INTERFACE ! Destroy_TauProfile


  ! -------------------------
  ! PRIVATE Module parameters
  ! -------------------------

  ! -- RCS Id for the module
  CHARACTER( * ), PRIVATE, PARAMETER :: MODULE_RCS_ID = &
  '$Id$'

  ! -- TauProfile invalid values
  INTEGER, PRIVATE, PARAMETER :: INVALID = -1
  INTEGER, PRIVATE, PARAMETER :: INVALID_WMO_SATELLITE_ID = 1023
  INTEGER, PRIVATE, PARAMETER :: INVALID_WMO_SENSOR_ID    = 2047

  ! -- Keyword set value
  INTEGER, PRIVATE, PARAMETER :: SET = 1


  ! -------------------------------
  ! TauProfile data type definition
  ! -------------------------------

  TYPE, PUBLIC :: TauProfile_type
    INTEGER :: n_Allocates = 0

    INTEGER( Long ) :: n_Layers        = 0 ! == K
    INTEGER( Long ) :: n_Channels      = 0 ! == L
    INTEGER( Long ) :: n_Angles        = 0 ! == I
    INTEGER( Long ) :: n_Profiles      = 0 ! == M
    INTEGER( Long ) :: n_Molecule_Sets = 0 ! == J

    INTEGER( Long ) :: NCEP_Sensor_ID   = INVALID
    INTEGER( Long ) :: WMO_Satellite_ID = INVALID_WMO_SATELLITE_ID
    INTEGER( Long ) :: WMO_Sensor_ID    = INVALID_WMO_SENSOR_ID   

    REAL( Double ),  DIMENSION( : ), POINTER :: Level_Pressure => NULL() ! K+1
    INTEGER( Long ), DIMENSION( : ), POINTER :: Channel        => NULL() ! L
    REAL( Double ),  DIMENSION( : ), POINTER :: Angle          => NULL() ! I
    INTEGER( Long ), DIMENSION( : ), POINTER :: Profile        => NULL() ! M
    INTEGER( Long ), DIMENSION( : ), POINTER :: Molecule_Set   => NULL() ! J

    REAL( Double ), DIMENSION( :, :, :, :, : ), POINTER :: Tau => NULL() ! K x L x I x M x J

  END TYPE TauProfile_type


CONTAINS







  SUBROUTINE Clear_TauProfile( TauProfile )

    TYPE( TauProfile_type ), INTENT( IN OUT ) :: TauProfile

    TauProfile%n_Layers        = 0
    TauProfile%n_Channels      = 0
    TauProfile%n_Angles        = 0
    TauProfile%n_Profiles      = 0
    TauProfile%n_Molecule_Sets = 0

    TauProfile%NCEP_Sensor_ID   = INVALID
    TauProfile%WMO_Satellite_ID = INVALID_WMO_SATELLITE_ID
    TauProfile%WMO_Sensor_ID    = INVALID_WMO_SENSOR_ID   

  END SUBROUTINE Clear_TauProfile







  FUNCTION Associated_TauProfile( TauProfile, & ! Input
                                  ANY_Test )  & ! Optional input
                                RESULT( Association_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Input
    TYPE( TauProfile_type ), INTENT( IN ) :: TauProfile

    ! -- Optional input
    INTEGER,       OPTIONAL, INTENT( IN ) :: ANY_Test


    ! ---------------
    ! Function result
    ! ---------------

    LOGICAL :: Association_Status


    ! ---------------
    ! Local variables
    ! ---------------

    LOGICAL :: ALL_Test



    !#--------------------------------------------------------------------------#
    !#                           -- CHECK INPUT --                              #
    !#--------------------------------------------------------------------------#

    ! -- Default is to test ALL the pointer members
    ! -- for a true association status....
    ALL_Test = .TRUE.

    ! ...unless the ANY_Test argument is set.
    IF ( PRESENT( ANY_Test ) ) THEN
      IF ( ANY_Test == SET ) ALL_Test = .FALSE.
    END IF



    !#--------------------------------------------------------------------------#
    !#           -- TEST THE STRUCTURE POINTER MEMBER ASSOCIATION --            #
    !#--------------------------------------------------------------------------#

    Association_Status = .FALSE.

    IF ( ALL_Test ) THEN

      IF ( ASSOCIATED( TauProfile%Level_Pressure ) .AND. &
           ASSOCIATED( TauProfile%Channel        ) .AND. &
           ASSOCIATED( TauProfile%Angle          ) .AND. &
           ASSOCIATED( TauProfile%Profile        ) .AND. &
           ASSOCIATED( TauProfile%Molecule_Set   ) .AND. &
           ASSOCIATED( TauProfile%Tau            )       ) THEN
        Association_Status = .TRUE.
      END IF

    ELSE

      IF ( ASSOCIATED( TauProfile%Level_Pressure ) .OR. &
           ASSOCIATED( TauProfile%Channel        ) .OR. &
           ASSOCIATED( TauProfile%Angle          ) .OR. &
           ASSOCIATED( TauProfile%Profile        ) .OR. &
           ASSOCIATED( TauProfile%Molecule_Set   ) .OR. &
           ASSOCIATED( TauProfile%Tau            )      ) THEN
        Association_Status = .TRUE.
      END IF

    END IF

  END FUNCTION Associated_TauProfile






  FUNCTION Destroy_TauProfile_scalar( TauProfile,   &  ! Output
                                      No_Clear,     &  ! Optional input
                                      RCS_Id,       &  ! Revision control
                                      Message_Log ) &  ! Error messaging
                                    RESULT( Error_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Output
    TYPE( TauProfile_type ),  INTENT( IN OUT ) :: TauProfile

    ! -- Optional input
    INTEGER,        OPTIONAL, INTENT( IN )     :: No_Clear

    ! -- Revision control
    CHARACTER( * ), OPTIONAL, INTENT( OUT )    :: RCS_Id

    ! - Error messaging
    CHARACTER( * ), OPTIONAL, INTENT( IN )     :: Message_Log


    ! ---------------
    ! Function result
    ! ---------------

    INTEGER :: Error_Status


    ! ----------------
    ! Local parameters
    ! ----------------

    CHARACTER( * ), PARAMETER :: ROUTINE_NAME = 'Destroy_TauProfile(scalar)'


    ! ---------------
    ! Local variables
    ! ---------------

    CHARACTER( 256 ) :: Message
    LOGICAL :: Clear
    INTEGER :: Allocate_Status



    !#--------------------------------------------------------------------------#
    !#                    -- SET SUCCESSFUL RETURN STATUS --                    #
    !#--------------------------------------------------------------------------#

    Error_Status = SUCCESS



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#                      -- CHECK OPTIONAL ARGUMENTS --                      #
    !#--------------------------------------------------------------------------#

    ! -- Default is to clear scalar members...
    Clear = .TRUE.
    ! -- ....unless the No_Clear argument is set
    IF ( PRESENT( No_Clear ) ) THEN
      IF ( No_Clear == SET ) Clear = .FALSE.
    END IF


    
    !#--------------------------------------------------------------------------#
    !#                     -- PERFORM RE-INITIALISATION --                      #
    !#--------------------------------------------------------------------------#

    ! -----------------------------
    ! Initialise the scalar members
    ! -----------------------------

    IF ( Clear ) CALL Clear_TauProfile( TauProfile )


    ! -----------------------------------------------------
    ! If ALL pointer members are NOT associated, do nothing
    ! -----------------------------------------------------

    IF ( .NOT. Associated_TauProfile( TauProfile ) ) RETURN


    ! -----------------------------------------
    ! Deallocate the TauProfile pointer members
    ! -----------------------------------------

    ! -- Level pressure
    IF ( ASSOCIATED( TauProfile%Level_Pressure ) ) THEN

      DEALLOCATE( TauProfile%Level_Pressure, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile level pressure member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF

    ! -- Channel list
    IF ( ASSOCIATED( TauProfile%Channel ) ) THEN

      DEALLOCATE( TauProfile%Channel, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile Channel member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF

    ! -- Angle list
    IF ( ASSOCIATED( TauProfile%Angle ) ) THEN

      DEALLOCATE( TauProfile%Angle, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile Angle member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF

    ! -- Profile list
    IF ( ASSOCIATED( TauProfile%Profile ) ) THEN

      DEALLOCATE( TauProfile%Profile, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile Profile member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF

    ! -- Molecule set list
    IF ( ASSOCIATED( TauProfile%Molecule_Set ) ) THEN

      DEALLOCATE( TauProfile%Molecule_Set, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile Molecule_Set member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF

    ! -- Transmitance
    IF ( ASSOCIATED( TauProfile%Tau ) ) THEN

      DEALLOCATE( TauProfile%Tau, &
                  STAT = Allocate_Status )

      IF ( Allocate_Status /= 0 ) THEN
        Error_Status = FAILURE
        WRITE( Message, '( "Error deallocating TauProfile TAU member. ", &
                          &"STAT = ", i5 )' ) &
                        Allocate_Status
        CALL Display_Message( ROUTINE_NAME,    &
                              TRIM( Message ), &
                              Error_Status,    &
                              Message_Log = Message_Log )
      END IF
    END IF



    !#--------------------------------------------------------------------------#
    !#               -- DECREMENT AND TEST ALLOCATION COUNTER --                #
    !#--------------------------------------------------------------------------#

    TauProfile%n_Allocates = TauProfile%n_Allocates - 1

    IF ( TauProfile%n_Allocates /= 0 ) THEN
      Error_Status = FAILURE
      WRITE( Message, '( "Allocation counter /= 0, Value = ", i5 )' ) &
                      TauProfile%n_Allocates
      CALL Display_Message( ROUTINE_NAME,    &
                            TRIM( Message ), &
                            Error_Status,    &
                            Message_Log = Message_Log )
    END IF

  END FUNCTION Destroy_TauProfile_scalar





  FUNCTION Destroy_TauProfile_rank1( TauProfile,   &  ! Output
                                     No_Clear,     &  ! Optional input
                                     RCS_Id,       &  ! Revision control
                                     Message_Log ) &  ! Error messaging

                                   RESULT( Error_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Output
    TYPE( TauProfile_type ), DIMENSION( : ), INTENT( IN OUT ) :: TauProfile

    ! -- Optional input
    INTEGER,                 OPTIONAL,       INTENT( IN )     :: No_Clear

    ! -- Revision control
    CHARACTER( * ),          OPTIONAL,       INTENT( OUT )    :: RCS_Id

    ! - Error messaging
    CHARACTER( * ),          OPTIONAL,       INTENT( IN )     :: Message_Log


    ! ---------------
    ! Function result
    ! ---------------

    INTEGER :: Error_Status


    ! ----------------
    ! Local parameters
    ! ----------------

    CHARACTER( * ), PARAMETER :: ROUTINE_NAME = 'Destroy_TauProfile(rank-1)'


    ! ---------------
    ! Local variables
    ! ---------------

    CHARACTER( 256 ) :: Message

    INTEGER :: Scalar_Status
    INTEGER :: i



    !#--------------------------------------------------------------------------#
    !#                    -- SET SUCCESSFUL RETURN STATUS --                    #
    !#--------------------------------------------------------------------------#

    Error_Status = SUCCESS



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#                     -- PERFORM RE-INITIALISATION --                      #
    !#--------------------------------------------------------------------------#

    DO i = 1, SIZE( TauProfile )

      ! -- Clear the current structure array element
      Scalar_Status = Destroy_TauProfile_scalar( TauProfile(i), &
                                                 No_Clear = No_Clear, &
                                                 Message_Log = Message_Log )

      ! -- If it failed, set the return error status, but
      ! -- continue to attempt to destroy structure array
      IF ( Scalar_Status /= SUCCESS ) THEN
        Error_Status = Scalar_Status
        WRITE( Message, '( i10 )' ) i
        CALL Display_Message( ROUTINE_NAME, &
                            'Error destroying TauProfile structure array element '//&
                            TRIM( Message ), &
                            Error_Status, &
                            Message_Log = Message_Log )
      END IF

    END DO

  END FUNCTION Destroy_TauProfile_rank1





  FUNCTION Allocate_TauProfile( n_Layers,        &  ! Input
                                n_Channels,      &  ! Input
                                n_Angles,        &  ! Input
                                n_Profiles,      &  ! Input
                                n_Molecule_Sets, &  ! Input

                                TauProfile,      &  ! Output

                                RCS_Id,          &  ! Revision control

                                Message_Log )    &  ! Error messaging

                              RESULT( Error_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Input
    INTEGER,                  INTENT( IN )     :: n_Layers
    INTEGER,                  INTENT( IN )     :: n_Channels
    INTEGER,                  INTENT( IN )     :: n_Angles
    INTEGER,                  INTENT( IN )     :: n_Profiles
    INTEGER,                  INTENT( IN )     :: n_Molecule_Sets

    ! -- Output
    TYPE( TauProfile_type ),  INTENT( IN OUT ) :: TauProfile

    ! -- Revision control
    CHARACTER( * ), OPTIONAL, INTENT( OUT )    :: RCS_Id

    ! - Error messaging
    CHARACTER( * ), OPTIONAL, INTENT( IN )     :: Message_Log


    ! ---------------
    ! Function result
    ! ---------------

    INTEGER :: Error_Status


    ! ----------------
    ! Local parameters
    ! ----------------

    CHARACTER( * ), PARAMETER :: ROUTINE_NAME = 'Allocate_TauProfile'


    ! ---------------
    ! Local variables
    ! ---------------

    CHARACTER( 256 ) :: Message

    INTEGER :: Allocate_Status



    !#--------------------------------------------------------------------------#
    !#                    -- SET SUCCESSFUL RETURN STATUS --                    #
    !#--------------------------------------------------------------------------#

    Error_Status = SUCCESS



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#                            -- CHECK INPUT --                             #
    !#--------------------------------------------------------------------------#

    ! ----------
    ! Dimensions
    ! ----------

    IF ( n_Layers        < 1 .OR. &
         n_Channels      < 1 .OR. &
         n_Angles        < 1 .OR. &
         n_Profiles      < 1 .OR. &
         n_Molecule_Sets < 1      ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'Input TauProfile dimensions must all be > 0.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! -----------------------------------------------
    ! Check if ANY pointers are already associated
    ! If they are, deallocate them but leave scalars.
    ! -----------------------------------------------

    IF ( Associated_TauProfile( TauProfile, ANY_Test = SET ) ) THEN

      Error_Status = Destroy_TauProfile( TauProfile, &
                                         No_Clear = SET, &
                                         Message_Log = Message_Log )

      IF ( Error_Status /= SUCCESS ) THEN
        CALL Display_Message( ROUTINE_NAME,    &
                              'Error deallocating TauProfile pointer members.', &
                              Error_Status,    &
                              Message_Log = Message_Log )
        RETURN
      END IF

    END IF



    !#--------------------------------------------------------------------------#
    !#                       -- PERFORM THE ALLOCATION --                       #
    !#--------------------------------------------------------------------------#

    ALLOCATE( TauProfile%Level_Pressure( n_Layers+1 ), &     
              TauProfile%Channel( n_Channels ), &     
              TauProfile%Angle( n_Angles ), &
              TauProfile%Profile( n_Profiles ), &
              TauProfile%Molecule_Set( n_Molecule_Sets ), &
              TauProfile%Tau( n_Layers, &
                              n_Channels, &
                              n_Angles, &
                              n_Profiles, &
                              n_Molecule_Sets ), & 

              STAT = Allocate_Status )

    IF ( Allocate_Status /= 0 ) THEN
      Error_Status = FAILURE
      WRITE( Message, '( "Error allocating TauProfile data arrays. STAT = ", i5 )' ) &
                      Allocate_Status
      CALL Display_Message( ROUTINE_NAME,    &
                            TRIM( Message ), &
                            Error_Status,    &
                            Message_Log = Message_Log )
      RETURN
    END IF



    !#--------------------------------------------------------------------------#
    !#                        -- ASSIGN THE DIMENSIONS --                       #
    !#--------------------------------------------------------------------------#

    TauProfile%n_Layers        = n_Layers
    TauProfile%n_Channels      = n_Channels
    TauProfile%n_Angles        = n_Angles
    TauProfile%n_Profiles      = n_Profiles
    TauProfile%n_Molecule_Sets = n_Molecule_Sets



    !#--------------------------------------------------------------------------#
    !#          -- FILL THE POINTER MEMBERS WITH INVALID VALUES --              #
    !#--------------------------------------------------------------------------#

    TauProfile%Level_Pressure = REAL( INVALID, fp_kind )
    TauProfile%Channel        = INVALID
    TauProfile%Angle          = REAL( INVALID, fp_kind )
    TauProfile%Profile        = INVALID
    TauProfile%Molecule_Set   = INVALID
    TauProfile%Tau            = REAL( INVALID, fp_kind )



    !#--------------------------------------------------------------------------#
    !#                -- INCREMENT AND TEST ALLOCATION COUNTER --               #
    !#--------------------------------------------------------------------------#

    TauProfile%n_Allocates = TauProfile%n_Allocates + 1

    IF ( TauProfile%n_Allocates /= 1 ) THEN
      Error_Status = WARNING
      WRITE( Message, '( "Allocation counter /= 1, Value = ", i5 )' ) &
                      TauProfile%n_Allocates
      CALL Display_Message( ROUTINE_NAME,    &
                            TRIM( message ), &
                            Error_Status,    &
                            Message_Log = Message_Log )
    END IF

  END FUNCTION Allocate_TauProfile






  FUNCTION Assign_TauProfile( TauProfile_in,  &  ! Input
                              TauProfile_out, &  ! Output
                              RCS_Id,         &  ! Revision control
                              Message_Log )   &  ! Error messaging
                            RESULT( Error_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Input
    TYPE( TauProfile_type ),  INTENT( IN )     :: TauProfile_in

    ! -- Output
    TYPE( TauProfile_type ),  INTENT( IN OUT ) :: TauProfile_out

    ! -- Revision control
    CHARACTER( * ), OPTIONAL, INTENT( OUT )    :: RCS_Id

    ! - Error messaging
    CHARACTER( * ), OPTIONAL, INTENT( IN )     :: Message_Log


    ! ---------------
    ! Function result
    ! ---------------

    INTEGER :: Error_Status


    ! ----------------
    ! Local parameters
    ! ----------------

    CHARACTER( * ), PARAMETER :: ROUTINE_NAME = 'Assign_TauProfile'



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#           -- TEST THE STRUCTURE ARGUMENT POINTER ASSOCIATION --          #
    !#--------------------------------------------------------------------------#

    ! ---------------------------------------
    ! ALL *input* pointers must be associated
    ! ---------------------------------------

    IF ( .NOT. Associated_TauProfile( TauProfile_In ) ) THEN

      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME,    &
                            'Some or all INPUT TauProfile pointer '//&
                            'members are NOT associated.', &
                            Error_Status,    &
                            Message_Log = Message_Log )
      RETURN
    END IF


    !#--------------------------------------------------------------------------#
    !#                       -- PERFORM THE ASSIGNMENT --                       #
    !#--------------------------------------------------------------------------#

    ! ---------------------
    ! Assign scalar members
    ! ---------------------

    TauProfile_out%NCEP_Sensor_ID   = TauProfile_in%NCEP_Sensor_ID
    TauProfile_out%WMO_Satellite_ID = TauProfile_in%WMO_Satellite_ID
    TauProfile_out%WMO_Sensor_ID    = TauProfile_in%WMO_Sensor_ID


    ! -----------------
    ! Assign array data
    ! -----------------

    ! -- Allocate data arrays
    Error_Status = Allocate_TauProfile( TauProfile_in%n_Layers, &
                                        TauProfile_in%n_Channels, &
                                        TauProfile_in%n_Angles, &
                                        TauProfile_in%n_Profiles, &
                                        TauProfile_in%n_Molecule_Sets, &
                                        TauProfile_out, &
                                        Message_Log = Message_Log )

    IF ( Error_Status /= SUCCESS ) THEN
      CALL Display_Message( ROUTINE_NAME,    &
                            'Error allocating output TauProfile arrays.', &
                            Error_Status,    &
                            Message_Log = Message_Log )
      RETURN
    END IF

    ! -- Copy array data
    TauProfile_out%Level_Pressure = TauProfile_in%Level_Pressure
    TauProfile_out%Channel        = TauProfile_in%Channel
    TauProfile_out%Angle          = TauProfile_in%Angle
    TauProfile_out%Profile        = TauProfile_in%Profile
    TauProfile_out%Molecule_Set   = TauProfile_in%Molecule_Set
    TauProfile_out%Tau            = TauProfile_in%Tau

  END FUNCTION Assign_TauProfile






  FUNCTION Concatenate_TauProfile( TauProfile1,  &  ! Input/Output
                                   TauProfile2,  &  ! Input
                                   By_Profile,   &  ! Optional Input
                                   RCS_Id,       &  ! Revision control
                                   Message_Log ) &  ! Error messaging
                                 RESULT( Error_Status )



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Input/Output
    TYPE( TauProfile_type ),  INTENT( IN OUT )  :: TauProfile1
    TYPE( TauProfile_type ),  INTENT( IN )      :: TauProfile2

    ! -- Optional input
    INTEGER,        OPTIONAL, INTENT( IN )      :: By_Profile

    ! -- Revision control
    CHARACTER( * ), OPTIONAL, INTENT( OUT )     :: RCS_Id

    ! - Error messaging
    CHARACTER( * ), OPTIONAL, INTENT( IN )      :: Message_Log


    ! ---------------
    ! Function result
    ! ---------------

    INTEGER :: Error_Status


    ! ----------------
    ! Local parameters
    ! ----------------

    CHARACTER( * ), PARAMETER :: ROUTINE_NAME = 'Concatenate_TauProfile'


    ! ---------------
    ! Local variables
    ! ---------------

    LOGICAL :: By_Molecule_Set

    INTEGER :: n_Profiles,      m1, m2
    INTEGER :: n_Molecule_Sets, j1, j2

    TYPE( TauProfile_type ) :: TauProfile_Tmp



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#          -- CHECK CONCATENATION DIMENSION OPTIONAL ARGUMENT --           #
    !#--------------------------------------------------------------------------#

    ! ------------------------------------
    ! Concatentation is along the molecule
    ! set dimension by default...
    ! ------------------------------------

    By_Molecule_Set = .TRUE.


    ! ---------------------------------
    ! ...unless the BY_PROFILE optional
    ! argument is set
    ! ---------------------------------

    IF ( PRESENT( By_Profile ) ) THEN
      IF ( By_Profile == SET ) By_Molecule_Set = .FALSE.
    END IF



    !#--------------------------------------------------------------------------#
    !#             -- CHECK STRUCTURE POINTER ASSOCIATION STATUS --             #
    !#                                                                          #
    !#                ALL structure pointers must be associated                 #
    !#--------------------------------------------------------------------------#

    ! -------------------
    ! The first structure
    ! -------------------

    IF ( .NOT. Associated_TauProfile( TauProfile1 ) ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME,    &
                            'Some or all INPUT TauProfile1 pointer '//&
                            'members are NOT associated.', &
                            Error_Status,    &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! --------------------
    ! The second structure
    ! --------------------

    IF ( .NOT. Associated_TauProfile( TauProfile2 ) ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME,    &
                            'Some or all INPUT TauProfile2 pointer '//&
                            'members are NOT associated.', &
                            Error_Status,    &
                            Message_Log = Message_Log )
      RETURN
    END IF



    !#--------------------------------------------------------------------------#
    !#                -- CHECK THE INPUT STRUCTURE CONTENTS --                  #
    !#--------------------------------------------------------------------------#

    ! --------------------------------
    ! The non-concatenation dimensions
    ! --------------------------------

    IF ( TauProfile1%n_Layers   /= TauProfile2%n_Layers   .OR. &
         TauProfile1%n_Channels /= TauProfile2%n_Channels .OR. &
         TauProfile1%n_Angles   /= TauProfile2%n_Angles        ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'n_Layers, n_Channels, or n_Angles TauProfile dimensions are different.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! ----------------------------
    ! The concatenation dimensions
    ! ----------------------------

    IF ( By_Molecule_Set ) THEN

      IF ( TauProfile1%n_Profiles /= TauProfile2%n_Profiles ) THEN
        Error_Status = FAILURE
        CALL Display_Message( ROUTINE_NAME, &
                              'n_Profiles TauProfile dimensions are different.', &
                              Error_Status, &
                              Message_Log = Message_Log )
        RETURN
      END IF

    ELSE

      IF ( TauProfile1%n_Molecule_Sets /= TauProfile2%n_Molecule_Sets ) THEN
        Error_Status = FAILURE
        CALL Display_Message( ROUTINE_NAME, &
                              'n_Molecule_Sets TauProfile dimensions are different.', &
                              Error_Status, &
                              Message_Log = Message_Log )
        RETURN
      END IF

    END IF


    ! -------
    ! The IDs
    ! -------

    IF ( TauProfile1%NCEP_Sensor_ID   /= TauProfile2%NCEP_Sensor_ID   .OR. &
         TauProfile1%WMO_Satellite_ID /= TauProfile2%WMO_Satellite_ID .OR. &
         TauProfile1%WMO_Sensor_ID    /= TauProfile2%WMO_Sensor_ID         ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'TauProfile sensor ID values are different.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! --------------------------------------------
    ! The level pressure, channel, or angle values
    ! --------------------------------------------

    ! -- All the pressures must be the same
    IF ( ANY( .NOT. Compare_Float( TauProfile1%Level_Pressure, &
                                   TauProfile2%Level_Pressure  ) ) ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'TauProfile level pressure values are different.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF

    ! -- All the channels numbers must be the same
    IF ( ANY( ( TauProfile1%Channel - TauProfile2%Channel ) /= 0 ) ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'TauProfile channel values are different.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF

    ! -- All the angle values must be the same
    IF ( ANY( .NOT. Compare_Float( TauProfile1%Angle, &
                                   TauProfile2%Angle  ) ) ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'TauProfile angle values are different.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! ----------------------------------
    ! The profile or molecule set values
    ! ----------------------------------

    IF ( By_Molecule_Set ) THEN

      ! -- All the molecule set IDs must be the same
      IF ( ANY( ( TauProfile1%Molecule_Set - TauProfile2%Molecule_Set ) /= 0 ) ) THEN
        Error_Status = FAILURE
        CALL Display_Message( ROUTINE_NAME, &
                              'TauProfile molecule set IDs are different.', &
                              Error_Status, &
                              Message_Log = Message_Log )
        RETURN
      END IF

    ELSE

      ! -- All the profile number values must be the same
      IF ( ANY( ( TauProfile1%Profile - TauProfile2%Profile ) /= 0 ) ) THEN
        Error_Status = FAILURE
        CALL Display_Message( ROUTINE_NAME, &
                              'TauProfile profile numbers are different.', &
                              Error_Status, &
                              Message_Log = Message_Log )
        RETURN
      END IF

    END IF



    !#--------------------------------------------------------------------------#
    !#                -- COPY FIRST INPUT TauProfile STRUCTURE --               #
    !#--------------------------------------------------------------------------#

    Error_Status = Assign_TauProfile( TauProfile1, TauProfile_Tmp, &
                                      Message_Log = Message_Log )

    IF ( Error_Status /= SUCCESS ) THEN
      CALL Display_Message( ROUTINE_NAME, &
                            'Error copying TauProfile1 structure.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF
   


    !#--------------------------------------------------------------------------#
    !#             -- REALLOCATE FIRST INPUT TauProfile STRUCTURE --            #
    !#--------------------------------------------------------------------------#

    ! ----------
    ! Destroy it
    ! ----------

    Error_Status = Destroy_TauProfile( TauProfile1, &
                                       Message_Log = Message_Log )

    IF ( Error_Status /= SUCCESS ) THEN
      CALL Display_Message( ROUTINE_NAME, &
                            'Error destroying TauProfile1 structure.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF


    ! --------------
    ! Re-Allocate it
    ! --------------

    Reallocate_TauProfile1: IF ( By_Molecule_Set ) THEN

      ! -- Set the total number of molecule sets
      n_Molecule_Sets = TauProfile_Tmp%n_Molecule_Sets + TauProfile2%n_Molecule_Sets

      ! -- Perform the allocation
      Error_Status = Allocate_TauProfile( TauProfile_Tmp%n_Layers, &
                                          TauProfile_Tmp%n_Channels, &
                                          TauProfile_Tmp%n_Angles, &
                                          TauProfile_Tmp%n_Profiles, &
                                          n_Molecule_Sets, &
                                          TauProfile1, &
                                          Message_Log = Message_Log )

    ELSE ! Reallocate_TauProfile1

      ! -- Set the total number of profiles
      n_Profiles = TauProfile_Tmp%n_Profiles + TauProfile2%n_Profiles

      ! -- Perform the allocation
      Error_Status = Allocate_TauProfile( TauProfile_Tmp%n_Layers, &
                                          TauProfile_Tmp%n_Channels, &
                                          TauProfile_Tmp%n_Angles, &
                                          n_Profiles, &
                                          TauProfile_Tmp%n_Molecule_Sets, &
                                          TauProfile1, &
                                          Message_Log = Message_Log )

    END IF Reallocate_TauProfile1

    ! -- Check for errors
    IF ( Error_Status /= SUCCESS ) THEN
      CALL Display_Message( ROUTINE_NAME, &
                            'Error reallocating TauProfile1 structure.', &
                            Error_Status, &
                            Message_Log = Message_Log )
      RETURN
    END IF



    !#--------------------------------------------------------------------------#
    !#                       -- PERFORM THE CONCATENATION --                    #
    !#--------------------------------------------------------------------------#

    ! ---------------------------------
    ! Assign the non-concatenation data
    ! ---------------------------------

    TauProfile1%NCEP_Sensor_ID   = TauProfile_Tmp%NCEP_Sensor_ID
    TauProfile1%WMO_Satellite_ID = TauProfile_Tmp%WMO_Satellite_ID
    TauProfile1%WMO_Sensor_ID    = TauProfile_Tmp%WMO_Sensor_ID

    TauProfile1%Level_Pressure = TauProfile_Tmp%Level_Pressure
    TauProfile1%Channel        = TauProfile_Tmp%Channel
    TauProfile1%Angle          = TauProfile_Tmp%Angle


    ! -----------------------------
    ! Concatenate the required bits
    ! -----------------------------

    Concatenate_TauProfile1: IF ( By_Molecule_Set ) THEN


      ! -----------------------------
      ! Concatenate the molecule sets
      ! -----------------------------

      ! -- Assign the profile numbers
      TauProfile1%Profile = TauProfile_Tmp%Profile

      ! -- The first part
      j1 = 1
      j2 = TauProfile_Tmp%n_Molecule_Sets

      TauProfile1%Molecule_Set(j1:j2) = TauProfile_Tmp%Molecule_Set
      TauProfile1%Tau(:,:,:,:,j1:j2)  = TauProfile_Tmp%Tau

      ! -- The second part
      j1 = j2 + 1
      j2 = n_Molecule_Sets

      TauProfile1%Molecule_Set(j1:j2) = TauProfile2%Molecule_Set
      TauProfile1%Tau(:,:,:,:,j1:j2)  = TauProfile2%Tau

    ELSE ! Concatenate_TauProfile1


      ! ------------------------
      ! Concatenate the profiles
      ! ------------------------

      ! -- Assign the molecule set ID values
      TauProfile1%Molecule_Set = TauProfile_Tmp%Molecule_Set

      ! -- The first part
      m1 = 1
      m2 = TauProfile_Tmp%n_Profiles

      TauProfile1%Profile(m1:m2)     = TauProfile_Tmp%Molecule_Set
      TauProfile1%Tau(:,:,:,m1:m2,:) = TauProfile_Tmp%Tau

      ! -- The second part
      m1 = m2 + 1
      m2 = n_Molecule_Sets

      TauProfile1%Profile(m1:m2)     = TauProfile2%Molecule_Set
      TauProfile1%Tau(:,:,:,m1:m2,:) = TauProfile2%Tau

    END IF Concatenate_TauProfile1



    !#--------------------------------------------------------------------------#
    !#            -- DEALLOCATE THE TEMPORARY TauProfile STRUCTURE --           #
    !#--------------------------------------------------------------------------#

    Error_Status = Destroy_TauProfile( TauProfile_Tmp, &
                                       Message_Log = Message_Log )

    IF ( Error_Status /= SUCCESS ) THEN
      Error_Status = WARNING
      CALL Display_Message( ROUTINE_NAME, &
                            'Error destroying TauProfile_Tmp structure.', &
                            Error_Status, &
                            Message_Log = Message_Log )
    END IF

  END FUNCTION Concatenate_TauProfile






  SUBROUTINE Information_TauProfile( TauProfile,  &  ! Input
                                     Information, &  ! Output
                                     RCS_Id       )  ! Revision control



    !#--------------------------------------------------------------------------#
    !#                        -- TYPE DECLARATIONS --                           #
    !#--------------------------------------------------------------------------#

    ! ---------
    ! Arguments
    ! ---------

    ! -- Input
    TYPE( TauProfile_type ),  INTENT( IN )  :: TauProfile

    ! -- Output
    CHARACTER( * ),           INTENT( OUT ) :: Information

    ! -- Revision control
    CHARACTER( * ), OPTIONAL, INTENT( OUT ) :: RCS_Id


    ! ----------
    ! Parameters
    ! ----------

    INTEGER, PARAMETER :: CARRIAGE_RETURN = 13
    INTEGER, PARAMETER :: LINEFEED = 10


    ! ---------------
    ! Local variables
    ! ---------------

    CHARACTER( 512 ) :: Long_String



    !#--------------------------------------------------------------------------#
    !#                -- SET THE RCS ID ARGUMENT IF SUPPLIED --                 #
    !#--------------------------------------------------------------------------#

    IF ( PRESENT( RCS_Id ) ) THEN
      RCS_Id = ' '
      RCS_Id = MODULE_RCS_ID
    END IF



    !#--------------------------------------------------------------------------#
    !#                     -- FILL THE VERSION INFO STRING --                   #
    !#--------------------------------------------------------------------------#

    ! -------------------------------------------
    ! Write the required data to the local string
    ! -------------------------------------------

    WRITE( Long_String, '( a,1x,"TauProfile: ", &
                           &"N_LAYERS=",i3,2x,&
                           &"N_CHANNELS=",i4,2x,&
                           &"N_ANGLES=",i1,2x,&
                           &"N_PROFILES=",i3,2x,&
                           &"N_MOLECULE_SETS=",i2 )' ) &
                         ACHAR(CARRIAGE_RETURN)//ACHAR(LINEFEED), &
                         TauProfile%n_Layers, &
                         TauProfile%n_Channels, &
                         TauProfile%n_Angles, &
                         TauProfile%n_Profiles, &
                         TauProfile%n_Molecule_Sets


    ! ----------------------------
    ! Trim the output based on the
    ! dummy argument string length
    ! ----------------------------

    Information = Long_String(1:MIN( LEN( Information ), LEN_TRIM( Long_String ) ))

  END SUBROUTINE Information_TauProfile

END MODULE TauProfile_Define_old


