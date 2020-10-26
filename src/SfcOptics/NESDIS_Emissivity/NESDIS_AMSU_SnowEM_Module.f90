
MODULE NESDIS_AMSU_SnowEM_Module


  ! -----------------
  ! Environment setup
  ! -----------------
  ! Module use
  USE Type_Kinds, ONLY: fp, Double
  USE NESDIS_LandEM_Module
  USE NESDIS_SnowEM_Parameters
  ! Disable implicit typing
  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------
  PRIVATE
  PUBLIC :: NESDIS_AMSU_SNOWEM


  ! -----------------
  ! Module parameters
  ! -----------------


CONTAINS




subroutine  NESDIS_AMSU_SNOWEM(Satellite_Angle,                             &  ! INPUT
                               User_Angle,                                  &  ! INPUT
                               frequency,                                   &  ! INPUT
                               Snow_Depth,                                  &  ! INPUT
                               Ts,                                          &  ! INPUT
                               tba,                                         &  ! INPUT
                               tbb,                                         &  ! INPUT
                               Emissivity_H,                                &  ! OUPUT
                               Emissivity_V)                                   ! OUTPUT

  integer,PARAMETER ::  AMSU_ABTs_ALG    = 1

  integer,PARAMETER ::  AMSU_ATs_ALG     = 2

  integer,PARAMETER ::  AMSU_AB_ALG      = 3

  integer,PARAMETER ::  AMSU_amsua_ALG   = 4

  integer,PARAMETER ::  AMSU_BTs_ALG     = 5

  integer,PARAMETER ::  AMSU_amsub_ALG   = 6

  integer,PARAMETER ::  AMSU_ALandEM_Snow_ALG  = 7

  integer, parameter  :: nch = 10, nwcha = 4, nwchb = 2, nwch = 5,nalg = 7

  integer :: snow_type,input_type,i,np,k

  real(fp)    :: Satellite_Angle,User_Angle,frequency,Ts,Snow_Depth

  real(fp)    :: em_vector(2),esh1,esv1,esh2,esv2,desh,desv,dem

  real(fp)    :: tb(nwch),tba(nwcha),tbb(nwchb)

  real(fp), intent(out) :: Emissivity_H,Emissivity_V

  logical :: INDATA(nalg)




  call em_initialization(frequency,em_vector)

  snow_type  = INVALID_SNOW_TYPE

  input_type = INVALID_SNOW_TYPE

  do k = 1, nalg

     INDATA(k) = .TRUE.

  end do




  tb(1) = tba(1); tb(2) = tba(2); tb(3) = tba(3); tb(4) = tba(4); tb(5) = tbb(2)


  if((Ts <= 150.0_fp) .or. (Ts >= 290.0_fp) ) then

     INDATA(1:2) = .false.;   INDATA(5)  = .false.;  INDATA(7) = .false.

  end if

  do i=1,nwcha

     if((tba(i) <= 100.0_fp) .or. (tba(i) >= 290.0_fp) ) then

        INDATA(1:4)   = .false.

        exit

     end if

  end do

  do i=1,nwchb

     if((tbb(i) <= 100.0_fp) .or. (tbb(i) >= 290.0_fp) ) then

        INDATA(1)  = .false.;  INDATA(3) = .false.;  INDATA(5:6)  = .false.

        exit

     end if

  end do

  if((Snow_Depth < 0.0_fp) .or. (Snow_Depth >= 3000.0_fp)) INDATA(7) = .false.

  if((frequency >= 80._fp) .and. (INDATA(5))) then

     INDATA(2:3) = .false.

  end if


  do np = 1, nalg

     if (INDATA(np)) then

        input_type = np

        exit

     end if

  end do


  GET_option: SELECT CASE (input_type)

  CASE (AMSU_ABTs_ALG)

     call AMSU_ABTs(frequency,tb,Ts,snow_type,em_vector)

  CASE (AMSU_ATs_ALG)

     call AMSU_ATs(frequency,tba,Ts,snow_type,em_vector)

  CASE (AMSU_AB_ALG)

     call AMSU_AB(frequency,tb,snow_type,em_vector)

  CASE (AMSU_amsua_ALG)

     call AMSU_amsua(frequency,tba,snow_type,em_vector)

  CASE(AMSU_BTs_ALG)

     call AMSU_BTs(frequency,tbb,Ts,snow_type,em_vector)

  CASE(AMSU_amsub_ALG)

     call AMSU_amsub(frequency,tbb,snow_type,em_vector)

  CASE(AMSU_ALandEM_Snow_ALG)

     call AMSU_ALandEM_Snow(Satellite_Angle,frequency,Snow_Depth,Ts,snow_type,em_vector)

  END SELECT GET_option


  call NESDIS_LandEM(Satellite_Angle,frequency,0.0_fp,0.0_fp,Ts,Ts,0.0_fp,9,13,2.0_fp,esh1,esv1)

  call NESDIS_LandEM(User_Angle,frequency,0.0_fp,0.0_fp,Ts,Ts,0.0_fp,9,13,2.0_fp,esh2,esv2)

  desh = esh1 - esh2

  desv = esv1 - esv2

  dem = ( desh + desv ) * 0.5_fp

  Emissivity_H = em_vector(1) - dem;  Emissivity_V = em_vector(2)- dem

  if (Emissivity_H > one)         Emissivity_H = one

  if (Emissivity_V > one)         Emissivity_V = one

  if (Emissivity_H < 0.3_fp) Emissivity_H = 0.3_fp

  if (Emissivity_V < 0.3_fp) Emissivity_V = 0.3_fp


  return

end subroutine NESDIS_AMSU_SNOWEM




subroutine em_initialization(frequency,em_vector)


  integer ::  nch,ncand
  Parameter(nch = 10,ncand=16)
  real(fp)    :: frequency,em_vector(*),freq(nch)
  real(fp)    :: em(ncand,nch)
  real(fp)    :: kratio, bconst,emissivity
  integer :: ich

  ! Silence gfortran complaints about maybe-used-uninit by init to HUGE()
  emissivity = HUGE(emissivity)

  em(1, 1: N_FREQUENCY) = WET_SNOW_EMISS(1:N_FREQUENCY)
  em(2, 1: N_FREQUENCY) = GRASS_AFTER_SNOW_EMISS(1:N_FREQUENCY)
  em(3, 1: N_FREQUENCY) = RS_SNOW_A_EMISS(1:N_FREQUENCY)
  em(4, 1: N_FREQUENCY) = POWDER_SNOW_EMISS(1:N_FREQUENCY)
  em(5, 1: N_FREQUENCY) = RS_SNOW_B_EMISS(1:N_FREQUENCY)
  em(6, 1: N_FREQUENCY) = RS_SNOW_C_EMISS(1:N_FREQUENCY)
  em(7, 1: N_FREQUENCY) = RS_SNOW_D_EMISS(1:N_FREQUENCY)
  em(8, 1: N_FREQUENCY) = THIN_CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(9, 1: N_FREQUENCY) = RS_SNOW_E_EMISS(1:N_FREQUENCY)
  em(10, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_A_EMISS(1:N_FREQUENCY)
  em(11, 1: N_FREQUENCY) = SHALLOW_SNOW_EMISS(1:N_FREQUENCY)
  em(12, 1: N_FREQUENCY) = DEEP_SNOW_EMISS(1:N_FREQUENCY)
  em(13, 1: N_FREQUENCY) = CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(14, 1: N_FREQUENCY) = MEDIUM_SNOW_EMISS(1:N_FREQUENCY)
  em(15, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_B_EMISS(1:N_FREQUENCY)
  em(16, 1: N_FREQUENCY) = THICK_CRUST_SNOW_EMISS(1:N_FREQUENCY)


  freq = FREQUENCY_DEFAULT


  do ich = 2, nch
     if(frequency <  freq(1))   exit
     if(frequency >= freq(nch)) exit
     if(frequency <  freq(ich)) then
        emissivity = em(4,ich-1) + (em(4,ich) - em(4,ich-1))     &
             *(frequency - freq(ich-1))/(freq(ich) - freq(ich-1))
        exit
     end if
  end do

  if (frequency <= freq(1)) then
     kratio = (em(4,2) - em(4,1))/(freq(2) - freq(1))
     bconst = em(4,1) - kratio*freq(1)
     emissivity =  kratio*frequency + bconst
     if(emissivity >  one)         emissivity = one
     if(emissivity <= 0.8_fp) emissivity = 0.8_fp
  end if


  if (frequency >= freq(nch)) emissivity = em(4,nch)
  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine em_initialization



subroutine  em_interpolate(frequency,discriminator,emissivity,snow_type)


  integer,parameter:: ncand = 16,nch =10
  integer:: ich,ichmin,ichmax,i,k,snow_type
  real(fp)   :: dem,demmin0
  real(fp)   :: em(ncand,nch)
  real(fp)   :: frequency,freq(nch),emissivity,discriminator(*),emis(nch)
  real(fp)   :: cor_factor,adjust_check,kratio, bconst


  em(1, 1: N_FREQUENCY) = WET_SNOW_EMISS(1:N_FREQUENCY)
  em(2, 1: N_FREQUENCY) = GRASS_AFTER_SNOW_EMISS(1:N_FREQUENCY)
  em(3, 1: N_FREQUENCY) = RS_SNOW_A_EMISS(1:N_FREQUENCY)
  em(4, 1: N_FREQUENCY) = POWDER_SNOW_EMISS(1:N_FREQUENCY)
  em(5, 1: N_FREQUENCY) = RS_SNOW_B_EMISS(1:N_FREQUENCY)
  em(6, 1: N_FREQUENCY) = RS_SNOW_C_EMISS(1:N_FREQUENCY)
  em(7, 1: N_FREQUENCY) = RS_SNOW_D_EMISS(1:N_FREQUENCY)
  em(8, 1: N_FREQUENCY) = THIN_CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(9, 1: N_FREQUENCY) = RS_SNOW_E_EMISS(1:N_FREQUENCY)
  em(10, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_A_EMISS(1:N_FREQUENCY)
  em(11, 1: N_FREQUENCY) = SHALLOW_SNOW_EMISS(1:N_FREQUENCY)
  em(12, 1: N_FREQUENCY) = DEEP_SNOW_EMISS(1:N_FREQUENCY)
  em(13, 1: N_FREQUENCY) = CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(14, 1: N_FREQUENCY) = MEDIUM_SNOW_EMISS(1:N_FREQUENCY)
  em(15, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_B_EMISS(1:N_FREQUENCY)
  em(16, 1: N_FREQUENCY) = THICK_CRUST_SNOW_EMISS(1:N_FREQUENCY)


  freq = FREQUENCY_DEFAULT



  if (discriminator(4) > discriminator(2))    &
       discriminator(4) = discriminator(2) +(discriminator(5) - discriminator(2))*  &
       (150.0_fp - 89.0_fp)/(150.0_fp - 31.4_fp)
  if ( (discriminator(3) /= -999.9_fp) .and.       &
       ( ((discriminator(3)-0.01_fp) > discriminator(2)) .or.     &
       ((discriminator(3)-0.01_fp) < discriminator(4)))    )    &
       discriminator(3) = discriminator(2) +  &
       (discriminator(4) - discriminator(2))*(89.0_fp - 50.3_fp) &
       / (89.0_fp - 31.4_fp)

  if(snow_type .eq. -999) then
     demmin0 = 10.0_fp
     do k = 1, ncand
        dem = zero
        ichmin = 1
        ichmax = 3
        if(discriminator(1) == -999.9_fp) then
           ichmin = 2
           ichmax = 2
        end if
        do ich = ichmin,ichmax
           dem = dem + abs(discriminator(ich) - em(k,ich+4))
        end do
        do ich = 4,5
           dem = dem + abs(discriminator(ich) - em(k,ich+5))
        end do
        if (dem < demmin0) then
           demmin0 = dem
           snow_type = k
        end if
     end do
  end if

  cor_factor = discriminator(2) - em(snow_type,6)
  do ich = 1, nch
     emis(ich) = em(snow_type,ich) + cor_factor
     if(emis(ich) .gt. one)         emis(ich) = one
     if(emis(ich) .lt. 0.3_fp) emis(ich) = 0.3_fp
  end do

  adjust_check = zero
  do ich = 5, 9
     if (ich .le. 7) then
        if (discriminator(ich - 4) .ne. -999.9_fp) &
             adjust_check = adjust_check + abs(emis(ich) - discriminator(ich - 4))
     else
        if (discriminator(ich - 4) .ne. -999.9_fp)  &
             adjust_check = adjust_check + abs(emis(ich+1) - discriminator(ich - 4))
     end if
  end do

  if (adjust_check >= 0.04_fp) then
     if (discriminator(1) /= -999.9_fp) then
        if (discriminator(1) < emis(4)) then
           emis(5) = emis(4) + &
                (31.4_fp - 23.8_fp) * &
                (discriminator(2) - emis(4))/(31.4_fp - 18.7_fp)
        else
           emis(5) = discriminator(1)
        end if
     end if
     emis(6) = discriminator(2)
     if (discriminator(3) /= -999.9_fp) then
        emis(7) = discriminator(3)
     else
        emis(7) = emis(6) + (89.0_fp - 50.3_fp) * &
             (discriminator(4) - emis(6))/(89.0_fp - 31.4_fp)
     end if
     emis(8) = emis(7)
     emis(9) = discriminator(4)
     emis(10) = discriminator(5)
  end if

  do i = 2, nch
     if(frequency <  freq(1))   exit
     if(frequency >= freq(nch)) exit
     if(frequency <  freq(i)) then
        emissivity = emis(i-1) + (emis(i) - emis(i-1))*(frequency - freq(i-1))  &
             /(freq(i) - freq(i-1))
        exit
     end if
  end do

  if (frequency <= freq(1)) then
     kratio = (emis(2) - emis(1))/(freq(2) - freq(1))
     bconst = emis(1) - kratio*freq(1)
     emissivity =  kratio*frequency + bconst
     if(emissivity > one)          emissivity = one
     if(emissivity <= 0.8_fp) emissivity = 0.8_fp
  end if

  if (frequency >= freq(nch)) emissivity = emis(nch)

  return
end subroutine em_interpolate


subroutine AMSU_ABTs(frequency,tb,ts,snow_type,em_vector)


  integer,parameter:: ncand = 16,nch =10,nthresh=38
  integer,parameter:: nind=6,ncoe=8,nLIcoe=6,nHIcoe=12
  integer:: i,j,k,num,npass,snow_type,md0,md1,nmodel(ncand-1)
  real(fp)   :: frequency,tb150,LI,HI,DS1,DS2,DS3
  real(fp)   :: em(ncand,nch), em_vector(*)
  real(fp)   :: tb(*),freq(nch),DTB(nind-1),DI(nind-1),       &
       DI_coe(nind-1,0:ncoe-1),threshold(nthresh,nind),       &
       index_in(nind),threshold0(nind)
  real(fp)   :: LI_coe(0:nLIcoe-1),HI_coe(0:nHIcoe-1)
  real(fp)   :: ts,emissivity
  real(fp)   :: discriminator(5)
  logical:: pick_status,tindex(nind)
  save      threshold,DI_coe,LI_coe, HI_coe,nmodel

  data  nmodel/5,10,13,16,18,24,30,31,32,33,34,35,36,37,38/

  DI_coe(1,0:ncoe-1) = (/ &
       3.285557e-002_fp,  2.677179e-005_fp,  &
       4.553101e-003_fp,  5.639352e-005_fp,  &
       -1.825188e-004_fp,  1.636145e-004_fp,  &
       1.680881e-005_fp, -1.708405e-004_fp/)
  DI_coe(2,0:ncoe-1) = (/ &
       -4.275539e-002_fp, -2.541453e-005_fp,  &
       4.154796e-004_fp,  1.703443e-004_fp,  &
       4.350142e-003_fp,  2.452873e-004_fp,  &
       -4.748506e-003_fp,  2.293836e-004_fp/)
  DI_coe(3,0:ncoe-1) = (/ &
       -1.870173e-001_fp, -1.061678e-004_fp,  &
      2.364055e-004_fp, -2.834876e-005_fp,  &
      4.899651e-003_fp, -3.418847e-004_fp,  &
      -2.312224e-004_fp,  9.498600e-004_fp/)
  DI_coe(4,0:ncoe-1) = (/ &
       -2.076519e-001_fp,  8.475901e-004_fp,  &
       -2.072679e-003_fp, -2.064717e-003_fp,  &
       2.600452e-003_fp,  2.503923e-003_fp,  &
       5.179711e-004_fp,  4.667157e-005_fp/)
  DI_coe(5,0:ncoe-1) = (/ &
       -1.442609e-001_fp, -8.075003e-005_fp,  &
       -1.790933e-004_fp, -1.986887e-004_fp,  &
       5.495115e-004_fp, -5.871732e-004_fp,  &
       4.517280e-003_fp,  7.204695e-004_fp/)

  LI_coe = (/ &
       7.963632e-001_fp,  7.215580e-003_fp,  &
       -2.015921e-005_fp, -1.508286e-003_fp,  &
       1.731405e-005_fp, -4.105358e-003_fp/)

  HI_coe = (/ &
       1.012160e+000_fp,  6.100397e-003_fp, &
       -1.774347e-005_fp, -4.028211e-003_fp, &
       1.224470e-005_fp,  2.345612e-003_fp, &
       -5.376814e-006_fp, -2.795332e-003_fp, &
       8.072756e-006_fp,  3.529615e-003_fp, &
       1.955293e-006_fp, -4.942230e-003_fp/)


  threshold(1,1:6) = (/0.88_fp,0.86_fp,-999.9_fp,&
       0.01_fp,0.01_fp,200._fp/)
  threshold(2,1:6) = (/0.88_fp,0.85_fp,-999.9_fp,&
       0.06_fp,0.10_fp,200._fp/)
  threshold(3,1:6) = (/0.88_fp,0.83_fp,-0.02_fp,&
       0.12_fp,0.16_fp,204._fp/)
  threshold(4,1:6) = (/0.90_fp,0.89_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)
  threshold(5,1:6) = (/0.92_fp,0.85_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(6,1:6) = (/0.84_fp,0.83_fp,-999.9_fp,&
       0.08_fp,0.10_fp,195._fp/)
  threshold(7,1:6) = (/0.85_fp,0.85_fp,-999.9_fp,&
       0.10_fp,-999.9_fp,190._fp/)
  threshold(8,1:6) = (/0.86_fp,0.81_fp,-999.9_fp,&
       0.12_fp,-999.9_fp,200._fp/)
  threshold(9,1:6) = (/0.86_fp,0.81_fp,0.0_fp,&
       0.12_fp,-999.9_fp,189._fp/)
  threshold(10,1:6) = (/0.90_fp,0.81_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,195._fp/)

  threshold(11,1:6) = (/0.80_fp,0.76_fp,-999.9_fp,&
       0.05_fp,-999.9_fp,185._fp/)
  threshold(12,1:6) = (/0.82_fp,0.78_fp,-999.9_fp,&
       -999.9_fp,0.25_fp,180._fp/)
  threshold(13,1:6) = (/0.90_fp,0.76_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,180._fp/)

  threshold(14,1:6) = (/0.89_fp,0.73_fp,-999.9_fp,&
       0.20_fp,-999.9_fp,-999.9_fp/)
  threshold(15,1:6) = (/0.89_fp,0.75_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)
  threshold(16,1:6) = (/0.93_fp,0.72_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(17,1:6) = (/0.82_fp,0.70_fp,-999.9_fp,&
       0.20_fp,-999.9_fp,160._fp/)
  threshold(18,1:6) = (/0.83_fp,0.70_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,160._fp/)

  threshold(19,1:6) = (/0.75_fp,0.76_fp,-999.9_fp,&
       0.08_fp,-999.9_fp,172._fp/)
  threshold(20,1:6) = (/0.77_fp,0.72_fp,-999.9_fp,&
       0.12_fp,0.15_fp,175._fp/)
  threshold(21,1:6) = (/0.78_fp,0.74_fp,-999.9_fp,&
       -999.9_fp,0.20_fp,172._fp/)
  threshold(22,1:6) = (/0.80_fp,0.77_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,170._fp/)
  threshold(23,1:6) = (/0.82_fp,-999.9_fp,-999.9_fp,&
       0.15_fp,0.22_fp,170._fp/)
  threshold(24,1:6) = (/0.82_fp,0.73_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,170._fp/)

  threshold(25,1:6) = (/0.75_fp,0.70_fp,-999.9_fp,&
       0.15_fp,0.25_fp,167._fp/)
  threshold(26,1:6) = (/0.77_fp,0.76_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)
  threshold(27,1:6) = (/0.80_fp,0.72_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)
  threshold(28,1:6) = (/0.77_fp,0.73_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(29,1:6) = (/0.81_fp,0.71_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)
  threshold(30,1:6) = (/0.82_fp,0.69_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(31,1:6) = (/0.88_fp,0.58_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(32,1:6) = (/0.73_fp,0.67_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(33,1:6) = (/0.83_fp,0.66_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(34,1:6) = (/0.82_fp,0.60_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(35,1:6) = (/0.77_fp,0.60_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(36,1:6) = (/0.77_fp,0.7_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(37,1:6) = (/-999.9_fp,0.55_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)

  threshold(38,1:6) = (/0.74_fp,-999.9_fp,-999.9_fp,&
       -999.9_fp,-999.9_fp,-999.9_fp/)



  em(1, 1: N_FREQUENCY) = WET_SNOW_EMISS(1:N_FREQUENCY)
  em(2, 1: N_FREQUENCY) = GRASS_AFTER_SNOW_EMISS(1:N_FREQUENCY)
  em(3, 1: N_FREQUENCY) = RS_SNOW_A_EMISS(1:N_FREQUENCY)
  em(4, 1: N_FREQUENCY) = POWDER_SNOW_EMISS(1:N_FREQUENCY)
  em(5, 1: N_FREQUENCY) = RS_SNOW_B_EMISS(1:N_FREQUENCY)
  em(6, 1: N_FREQUENCY) = RS_SNOW_C_EMISS(1:N_FREQUENCY)
  em(7, 1: N_FREQUENCY) = RS_SNOW_D_EMISS(1:N_FREQUENCY)
  em(8, 1: N_FREQUENCY) = THIN_CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(9, 1: N_FREQUENCY) = RS_SNOW_E_EMISS(1:N_FREQUENCY)
  em(10, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_A_EMISS(1:N_FREQUENCY)
  em(11, 1: N_FREQUENCY) = SHALLOW_SNOW_EMISS(1:N_FREQUENCY)
  em(12, 1: N_FREQUENCY) = DEEP_SNOW_EMISS(1:N_FREQUENCY)
  em(13, 1: N_FREQUENCY) = CRUST_SNOW_EMISS(1:N_FREQUENCY)
  em(14, 1: N_FREQUENCY) = MEDIUM_SNOW_EMISS(1:N_FREQUENCY)
  em(15, 1: N_FREQUENCY) = BOTTOM_CRUST_SNOW_B_EMISS(1:N_FREQUENCY)
  em(16, 1: N_FREQUENCY) = THICK_CRUST_SNOW_EMISS(1:N_FREQUENCY)


  freq = FREQUENCY_DEFAULT



  dtb(1) = tb(1) - tb(2)
  dtb(2) = tb(2) - tb(4)
  dtb(3) = tb(2) - tb(5)
  dtb(4) = tb(3) - tb(5)
  dtb(5) = tb(4) - tb(5)
  tb150  = tb(5)

  LI = LI_coe(0)
  do i=0,1
     LI = LI + LI_coe(2*i+1)*tb(i+1) + LI_coe(2*i+2)*tb(i+1)*tb(i+1)
  end do
  LI = LI + LI_coe(nLIcoe-1)*ts

  HI = HI_coe(0)
  do i=0,4
     HI = HI + HI_coe(2*i+1)*tb(i+1) + HI_coe(2*i+2)*tb(i+1)*tb(i+1)
  end do
  HI = HI + HI_coe(nHIcoe-1)*ts

  do num=1,nind-1
     DI(num) = DI_coe(num,0) + DI_coe(num,1)*tb(2)
     do i=1,5
        DI(num) = DI(num) + DI_coe(num,1+i)*DTB(i)
     end do
     DI(num) = DI(num) +  DI_coe(num,ncoe-1)*ts
  end do

  !HI = DI(0) - DI(3)
  DS1 = DI(1) + DI(2)
  DS2 = DI(4) + DI(5)
  DS3 = DS1 + DS2 + DI(3)

  index_in(1) = LI
  index_in(2) = HI
  index_in(3) = DS1
  index_in(4) = DS2
  index_in(5) = DS3
  index_in(6) = tb150



  md0 = 1
  snow_type = ncand
  pick_status = .false.

  do i = 1, ncand - 1
     md1 = nmodel(i)
     do j = md0, md1
        npass = 0
        do k = 1 , nind
           threshold0(k) = threshold(j,k)
        end do
        CALL six_indices(nind,index_in,threshold0,tindex)

        if((i == 5)  .and. (index_in(2) >  0.75_fp)) tindex(2) = .false.
        if((i == 5)  .and. (index_in(4) >  0.20_fp)                        &
             .and. (index_in(1) >  0.88_fp)) tindex(1) = .false.
        if((i == 10) .and. (index_in(1) <= 0.83_fp)) tindex(1) = .true.
        if((i == 13) .and. (index_in(2) <  0.52_fp)) tindex(2) = .true.
        do k = 1, nind
           if(.not.tindex(k)) exit
           npass = npass + 1
        end do
        if(npass == nind) exit
     end do

     if(npass == nind) then
        pick_status = .true.
        snow_type  = i
     end if
     if(pick_status) exit
     md0 = md1 + 1
  end do

  discriminator(1) = LI + DI(1)
  discriminator(2) = LI
  discriminator(3) = DI(4) + HI
  discriminator(4) = LI - DI(2)
  discriminator(5) = HI

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_ABTs



subroutine six_indices(nind,index_in,threshold,tindex)


  integer ::  i,nind
  real(fp)    ::  index_in(*),threshold(*)
  logical ::  tindex(*)

  do i=1,nind
     tindex(i) = .false.
     if (threshold(i) .eq. -999.9_fp) then
        tindex(i) = .true.
     else
        if ( (i .le. 2) .or. (i .gt. (nind-1)) ) then
           if (index_in(i) .ge. threshold(i)) tindex(i) = .true.
        else
           if (index_in(i) .le. threshold(i)) tindex(i) = .true.
        end if
     end if
  end do
  return

end subroutine six_indices


subroutine AMSU_AB(frequency,tb,snow_type,em_vector)


  integer,parameter:: nch =10,nwch = 5,ncoe = 10
  real(fp)    :: tb(*),frequency
  real(fp)    :: em_vector(*),emissivity,discriminator(nwch)
  integer :: i,snow_type,ich,nvalid_ch
  real(fp)  :: coe(nwch*(ncoe+1))

  save coe

  coe(1:7) = (/&
       -1.326040e+000_fp,  2.475904e-002_fp, &
       -5.741361e-005_fp, -1.889650e-002_fp, &
       6.177911e-005_fp,  1.451121e-002_fp, &
       -4.925512e-005_fp/)

  coe(12:18) = (/ &
       -1.250541e+000_fp,  1.911161e-002_fp, &
       -5.460238e-005_fp, -1.266388e-002_fp, &
       5.745064e-005_fp,  1.313985e-002_fp, &
       -4.574811e-005_fp/)

  coe(23:29) = (/  &
       -1.246754e+000_fp,  2.368658e-002_fp, &
       -8.061774e-005_fp, -3.206323e-002_fp, &
       1.148107e-004_fp,  2.688353e-002_fp, &
       -7.358356e-005_fp/)

  coe(34:42) = (/ &
       -1.278780e+000_fp,  1.625141e-002_fp, &
       -4.764536e-005_fp, -1.475181e-002_fp, &
       5.107766e-005_fp,  1.083021e-002_fp, &
       -4.154825e-005_fp,  7.703879e-003_fp, &
       -6.351148e-006_fp/)

  coe(45:55) = (/&
     -1.691077e+000_fp,  3.352403e-002_fp, &
     -7.310338e-005_fp, -4.396138e-002_fp, &
     1.028994e-004_fp,  2.301014e-002_fp, &
     -7.070810e-005_fp,  1.270231e-002_fp, &
     -2.139023e-005_fp, -2.257991e-003_fp, &
     1.269419e-005_fp/)


  do ich = 1, nwch
     discriminator(ich) = coe(1+(ich-1)*11)
     if (ich .le. 3) nvalid_ch = 3
     if (ich .eq. 4) nvalid_ch = 4
     if (ich .eq. 5) nvalid_ch = 5
     do i=1,nvalid_ch
        discriminator(ich) = discriminator(ich) + coe((ich-1)*11 + 2*i)*tb(i) +  &
             coe((ich-1)*11 + 2*i+1)*tb(i)*tb(i)
     end do
  end do
  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_AB


subroutine AMSU_ATs(frequency,tba,ts,snow_type,em_vector)


  integer,parameter:: nch =10,nwch = 5,ncoe = 9
  real(fp)    :: tba(*)
  real(fp)    :: em_vector(*),emissivity,ts,frequency,discriminator(nwch)
  integer :: snow_type,i,ich,nvalid_ch
  real(fp)  :: coe(nch*(ncoe+1))

  save coe

  coe(1:6) = (/ &
       8.210105e-001_fp,  1.216432e-002_fp,  &
       -2.113875e-005_fp, -6.416648e-003_fp, &
       1.809047e-005_fp, -4.206605e-003_fp /)

  coe(11:16) = (/ &
       7.963632e-001_fp,  7.215580e-003_fp,  &
       -2.015921e-005_fp, -1.508286e-003_fp,  &
       1.731405e-005_fp, -4.105358e-003_fp /)

  coe(21:28) = (/ &
       1.724160e+000_fp,  5.556665e-003_fp, &
       -2.915872e-005_fp, -1.146713e-002_fp, &
       4.724243e-005_fp,  3.851791e-003_fp, &
       -5.581535e-008_fp, -5.413451e-003_fp /)

  coe(31:40) = (/ &
       9.962065e-001_fp,  1.584161e-004_fp, &
       -3.988934e-006_fp,  3.427638e-003_fp, &
       -5.084836e-006_fp, -6.178904e-004_fp, &
       1.115315e-006_fp,  9.440962e-004_fp, &
       9.711384e-006_fp, -4.259102e-003_fp /)

  coe(41:50) = (/ &
       -5.244422e-002_fp,  2.025879e-002_fp,  &
       -3.739231e-005_fp, -2.922355e-002_fp, &
       5.810726e-005_fp,  1.376275e-002_fp, &
       -3.757061e-005_fp,  6.434187e-003_fp, &
       6.190403e-007_fp, -2.944785e-003_fp/)


  DO ich = 1, nwch
     discriminator(ich) = coe(1+(ich-1)*10)
     if (ich .le. 2) nvalid_ch = 2
     if (ich .eq. 3) nvalid_ch = 3
     if (ich .ge. 4) nvalid_ch = 4
     do i=1,nvalid_ch
        discriminator(ich) = discriminator(ich) + coe((ich-1)*10 + 2*i)*tba(i) +  &
             coe((ich-1)*10 + 2*i+1)*tba(i)*tba(i)
     end do
     discriminator(ich) = discriminator(ich) + coe( (ich-1)*10 + (nvalid_ch+1)*2 )*ts
  end do

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_ATs


subroutine AMSU_amsua(frequency,tba,snow_type,em_vector)


  integer,parameter:: nch =10,nwch = 5,ncoe = 8
  real(fp)    :: tba(*)
  real(fp)    :: em_vector(*),emissivity,frequency,discriminator(nwch)
  integer :: snow_type,i,ich,nvalid_ch
  real(fp)  :: coe(50)
  save coe

  coe(1:7) = (/ &
       -1.326040e+000_fp,  2.475904e-002_fp, -5.741361e-005_fp, &
       -1.889650e-002_fp,  6.177911e-005_fp,  1.451121e-002_fp, &
       -4.925512e-005_fp/)

  coe(11:17) = (/ &
       -1.250541e+000_fp,  1.911161e-002_fp, -5.460238e-005_fp, &
       -1.266388e-002_fp,  5.745064e-005_fp,  1.313985e-002_fp, &
       -4.574811e-005_fp/)

  coe(21:27) = (/ &
       -1.246754e+000_fp,  2.368658e-002_fp, -8.061774e-005_fp, &
       -3.206323e-002_fp,  1.148107e-004_fp,  2.688353e-002_fp, &
       -7.358356e-005_fp/)

  coe(31:39) = (/ &
       -1.278780e+000_fp, 1.625141e-002_fp, -4.764536e-005_fp, &
       -1.475181e-002_fp, 5.107766e-005_fp,  1.083021e-002_fp, &
       -4.154825e-005_fp,  7.703879e-003_fp, -6.351148e-006_fp/)

  coe(41:49) = (/ &
       -1.624857e+000_fp, 3.138243e-002_fp, -6.757028e-005_fp, &
       -4.178496e-002_fp, 9.691893e-005_fp,  2.165964e-002_fp, &
       -6.702349e-005_fp, 1.111658e-002_fp, -1.050708e-005_fp/)



  do ich = 1, nwch
     discriminator(ich) = coe(1+(ich-1)*10)
     if (ich .le. 2) nvalid_ch = 3
     if (ich .ge. 3) nvalid_ch = 4
     do i=1,nvalid_ch
        discriminator(ich) = discriminator(ich) + coe((ich-1)*10 + 2*i)*tba(i) +  &
             coe((ich-1)*10 + 2*i+1)*tba(i)*tba(i)
     end do
  end do

  if(discriminator(4) .gt. discriminator(2))   &
       discriminator(4) = discriminator(2) + (150.0_fp - 89.0_fp)*  &
       (discriminator(5) - discriminator(2))/ &
       (150.0_fp - 31.4_fp)

  if((discriminator(3) .gt. discriminator(2)) .or.  &
       (discriminator(3) .lt. discriminator(4)))      &
       discriminator(3) = discriminator(2) + (89.0_fp - 50.3_fp)*   &
       (discriminator(4) - discriminator(2))/(89.0_fp - 31.4_fp)

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_amsua


subroutine AMSU_BTs(frequency,tbb,ts,snow_type,em_vector)


  integer,parameter:: nch =10,nwch = 3,ncoe = 5
  real(fp)    :: tbb(*)
  real(fp)    :: em_vector(*),emissivity,ts,frequency,ed0(nwch),discriminator(5)
  integer :: snow_type,i,ich,nvalid_ch
  real(fp)  :: coe(nch*(ncoe+1))
  save coe

  coe(1:6) = (/ 3.110967e-001_fp,  1.100175e-002_fp, -1.677626e-005_fp,    &
       -4.020427e-003_fp,  9.242240e-006_fp, -2.363207e-003_fp/)
  coe(11:16) = (/  1.148098e+000_fp,  1.452926e-003_fp,  1.037081e-005_fp, &
       1.340696e-003_fp, -5.185640e-006_fp, -4.546382e-003_fp /)
  coe(21:26) = (/ 1.165323e+000_fp, -1.030435e-003_fp,  4.828009e-006_fp,  &
       4.851731e-003_fp, -2.588049e-006_fp, -4.990193e-003_fp/)

  do ich = 1, nwch
     ed0(ich) = coe(1+(ich-1)*10)
     nvalid_ch = 2
     do i=1,nvalid_ch
        ed0(ich) = ed0(ich) + coe((ich-1)*10 + 2*i)*tbb(i) +   &
             coe((ich-1)*10 + 2*i+1)*tbb(i)*tbb(i)
     end do
     ed0(ich) = ed0(ich) + coe( (ich-1)*10 + (nvalid_ch+1)*2 )*ts
  end do

  if(ed0(2) .gt. ed0(1))     &
       ed0(2) = ed0(1) + (150.0_fp - 89.0_fp)*(ed0(3) - ed0(1)) / &
       (150.0_fp - 31.4_fp)

  discriminator(1) = -999.9_fp;  discriminator(2) = ed0(1)
  discriminator(3) = -999.9_fp; discriminator(4) = ed0(2); discriminator(5) = ed0(3)

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_BTs


subroutine AMSU_amsub(frequency,tbb,snow_type,em_vector)



  integer,parameter:: nch =10,nwch = 3,ncoe = 4
  real(fp)    :: tbb(*)
  real(fp)    :: em_vector(*),emissivity,frequency,ed0(nwch),discriminator(5)
  integer :: snow_type,i,ich,nvalid_ch
  real(fp)  :: coe(50)
  save coe

  coe(1:5) = (/-4.015636e-001_fp,9.297894e-003_fp, -1.305068e-005_fp, &
       3.717131e-004_fp, -4.364877e-006_fp/)
  coe(11:15) = (/-2.229547e-001_fp, -1.828402e-003_fp,1.754807e-005_fp, &
       9.793681e-003_fp, -3.137189e-005_fp/)
  coe(21:25) = (/-3.395416e-001_fp,-4.632656e-003_fp,1.270735e-005_fp, &
       1.413038e-002_fp,-3.133239e-005_fp/)

  do ich = 1, nwch
     ed0(ich) = coe(1+(ich-1)*10)
     nvalid_ch = 2
     do i=1,nvalid_ch
        ed0(ich) = ed0(ich) + coe((ich-1)*10 + 2*i)*tbb(i) +  &
             coe((ich-1)*10 + 2*i+1)*tbb(i)*tbb(i)
     end do
  end do

  if(ed0(2) .gt. ed0(1))     &
       ed0(2) = ed0(1) + (150.0_fp - 89.0_fp) * &
       (ed0(3) - ed0(1))/(150.0_fp - 31.4_fp)

  discriminator(1) = -999.9_fp; discriminator(2) = ed0(1)
  discriminator(3) = -999.9_fp; discriminator(4) = ed0(2); discriminator(5) = ed0(3)

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity
  em_vector(2) = emissivity

  return
end subroutine AMSU_amsub


subroutine AMSU_ALandEM_Snow(theta,frequency,snow_depth,ts,snow_type,em_vector)



  integer :: nw_ind
  parameter(nw_ind=3)
  real(fp) theta, frequency, freq,snow_depth, ts, em_vector(2)
  real(fp) esv,esh,esh0,esv0,theta0
  integer snow_type,ich
  real(fp)   freq_3w(nw_ind),esh_3w(nw_ind),esv_3w(nw_ind)
  complex(fp)  eair
  save freq_3w

  freq_3w = (/31.4_fp,89.0_fp,150.0_fp/)

  eair = cmplx(one,-zero,fp)

  snow_type = -999

  call NESDIS_LandEM(theta, frequency,0.0_fp,0.0_fp,ts,ts,0.0_fp,9,13,snow_depth,esh0,esv0)

  theta0 = theta
  do ich = 1, nw_ind
     freq =freq_3w(ich)
     theta = theta0
     call NESDIS_LandEM(theta, freq,0.0_fp,0.0_fp,ts,ts,0.0_fp,9,13,snow_depth,esh,esv)
     esv_3w(ich) = esv
     esh_3w(ich) = esh
  end do

  call ems_adjust(theta,frequency,snow_depth,ts,esv_3w,esh_3w,em_vector,snow_type)

  return

end subroutine AMSU_ALandEM_Snow



subroutine ems_adjust(theta,frequency,depth,ts,esv_3w,esh_3w,em_vector,snow_type)



  integer,parameter:: nch=10,nw_3=3

  integer,parameter:: ncoe=6

  real(fp),parameter  :: earthrad = 6374._fp, satheight = 833.4_fp

  integer     :: snow_type,ich

  real(fp)    :: theta,frequency,depth,ts,esv_3w(*),esh_3w(*)

  real(fp)    :: discriminator(5),emmod(nw_3),dem(nw_3)

  real(fp)    :: emissivity,em_vector(2)

  real(Double)  :: dem_coe(nw_3,0:ncoe-1),sinthetas,costhetas,deg2rad

  save  dem_coe

  dem_coe(1,0:ncoe-1) = (/ 2.306844e+000_Double, -7.287718e-003_Double, &

       -6.433248e-004_Double,  1.664216e-005_Double,  &

       4.766508e-007_Double, -1.754184e+000_Double/)

  dem_coe(2,0:ncoe-1) = (/ 3.152527e+000_Double, -1.823670e-002_Double, &

       -9.535361e-004_Double,  3.675516e-005_Double,  &

       9.609477e-007_Double, -1.113725e+000_Double/)

  dem_coe(3,0:ncoe-1) = (/ 3.492495e+000_Double, -2.184545e-002_Double,  &

       6.536696e-005_Double,  4.464352e-005_Double, &

       -6.305717e-008_Double, -1.221087e+000_Double/)



  deg2rad = 3.14159_fp*pi/180.0_fp

  sinthetas = sin(theta*deg2rad)* earthrad/(earthrad + satheight)

  sinthetas = sinthetas*sinthetas

  costhetas = one - sinthetas

  do ich = 1, nw_3

     emmod(ich) = costhetas*esv_3w(ich) + sinthetas*esh_3w(ich)

  end do

  do ich=1,nw_3

     dem(ich) = dem_coe(ich,0) + dem_coe(ich,1)*ts + dem_coe(ich,2)*depth +   &

          dem_coe(ich,3)*ts*ts + dem_coe(ich,4)*depth*depth         +   &

          dem_coe(ich,5)*emmod(ich)

  end do

  emmod(1) = emmod(1) + dem(1)

  emmod(2) = emmod(2) + dem(2)

  emmod(3) = emmod(3) + dem(3)



  discriminator(1) = -999.9_fp

  discriminator(2) = emmod(1)


  discriminator(3) = -999.9_fp

  discriminator(4) = emmod(2)

  discriminator(5) = emmod(3)

  call em_interpolate(frequency,discriminator,emissivity,snow_type)

  em_vector(1) = emissivity

  em_vector(2) = emissivity

  return

end subroutine ems_adjust


END MODULE NESDIS_AMSU_SnowEM_Module
