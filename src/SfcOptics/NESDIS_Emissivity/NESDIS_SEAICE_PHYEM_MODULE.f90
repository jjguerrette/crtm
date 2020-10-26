
MODULE NESDIS_SEAICE_PHYEM_MODULE


  ! -----------------
  ! Environment setup
  ! -----------------
  ! Module use
  USE Type_Kinds, ONLY: fp
  ! Disable implicit typing
  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------
  PRIVATE
  PUBLIC :: NESDIS_SIce_Phy_EM


  ! -----------------
  ! Module parameters
  ! -----------------


CONTAINS


  subroutine NESDIS_SIce_Phy_EM(Frequency,                                                 &  ! INPUT
                                Angle,                                                     &  ! INPUT
                                Ts_ice,                                                    &  ! INPUT
                                Salinity,                                                  &  ! INPUT
                                Emissivity_H,                                              &  ! OUTPUT
                                Emissivity_V)                                                 ! OUPTUT



     real(fp) ::  Angle,theta, Ts_ice, Salinity
     real(fp) ::  Frequency, Emissivity_H, Emissivity_V, slam, f1,epsx, epsy, pi
     integer :: ITYPE
     COMPLEX(fp) :: eair, eice
     COMPLEX(fp) :: cos_theta_i,cos_theta_t,sin_theta_i,sin_theta_t
     COMPLEX(fp) :: rv_ice, rh_ice


      pi = acos(-1.0_fp)

      theta = Angle*pi/180.0_fp

      slam = 300.0_fp/Frequency

      f1=Frequency*1.0e+9_fp

      eair = cmplx(1.0_fp, 0.0_fp, fp)

      ITYPE = 2

      call  permitivity(ITYPE,Ts_ice, Salinity, f1, epsx, epsy)

      eice = cmplx(epsx, -epsy, fp)

      sin_theta_i = sin(cmplx(theta,0.0_fp, fp))

      cos_theta_i = sqrt(1.0_fp - sin_theta_i*sin_theta_i)

      sin_theta_t = sin_theta_i*sqrt(eair)/sqrt(eice)

      cos_theta_t = sqrt(1.0_fp - sin_theta_t*sin_theta_t)

      call reflection_coefficient(eair, eice, cos_theta_i, cos_theta_t, rv_ice, rh_ice)

      Emissivity_V = 1.0_fp  - abs(rv_ice)*abs(rv_ice)

      Emissivity_H = 1.0_fp  - abs(rh_ice)*abs(rh_ice)

     return

     end subroutine NESDIS_SIce_Phy_EM


     subroutine permitivity(itype, temp, s, f, e_real, e_img)


     real(fp) ::  eo, esw, eswo, a, tswo, tsw, b, sswo, c,d, fi, ssw
     real(fp) ::  temp,t, t2, t3, s2, s3, epsp, epspp
     real(fp) ::  ESWI, EW0, TPTW, FH, X, Y, TPTWFQ
     real(fp) ::  e_real, e_img

     real(fp) ::  s,t4,t5,sigma
     real(fp) ::  ebo,eb,sb,nb,eb_real,eb_imag
     real(fp) ::   den_ice,den_sice,den_brine

     real(fp) ::   vss, cc, den_ss

     real(fp) ::   f,pi,vb,sigmao,vi

     integer :: itype

     COMPLEX(fp) :: ebrine,eice,eair,esice,xx

     ! Silence gfortran complaints about maybe-used-uninit by init to HUGE()
     sb = HUGE(sb)
     pi=acos(-1.0_fp)
     ESWI=4.9_fp
     t=temp-273.15_fp
     if (t.le.-65.0_fp) t = -65.0_fp
     t2=t*t
     t3=t2*t
     t4=t3*t
     t5=t4*t
     FH=f


   GET_DielectricC: SELECT CASE (ITYPE)

   CASE (1)


      s2 = s*s
      s3 = s**3
      eo   = 8.854e-12
      eswo = 87.134 - 1.949e-1 * t - 1.276e-2 * t2 + 2.491e-4 * t3
      a =1.0 +1.613e-5 * t*s - 3.656e-3*s + 3.210e-5*s2 - 4.232e-7*s3
      esw = eswo * a
      tswo = 1.1109e-10 - 3.824e-12 * t + 6.938e-14*t2 -5.096e-16*t3
      b = 1.0 + 2.282e-5*t*s -7.638e-4*s - 7.760e-6 *s2 + 1.105e-8*s3
      tsw = tswo*b
      epsp = ESWI + (esw - ESWI)/ (1.0 + (f*tsw)**2)
      sswo = s*(0.18252-1.4619e-3*s+2.093e-5*s2-1.282e-7*s3)
      d  = 25.0 - t
      fi = d * (2.033e-2 + 1.266e-4 * d + 2.464e-6 * d * d -   &
        s * (1.849e-5 - 2.551e-7 * d + 2.551e-8 * d * d))

      ssw = sswo * exp(-fi)
      epspp = tsw * f * (esw - ESWI) / (1.0 + (tsw * f)**2)
      epspp = epspp + ssw/(2.0 * pi * eo * f)

      e_real =   epsp
      e_img = - epspp

Case (2) ! sea ice

      eice = cmplx(3.15_fp, -0.001_fp,fp)
      eair = cmplx(1.0_fp, 0.0_fp,fp)


      if (t .le. -8.2) then
          vb = 0.001*s*(-43.795/t + 1.189)
          if (t .lt. -22.9) vb = 0.001*s*(-43.795/(-22.9) + 1.189)
      else
         if (t .le. -2.06) then
             vb = 0.001*s*(-45.917/t + 0.930)
        else
            vb = 0.001*s*(-52.56/t  - 2.28)
          if (t .gt. -0.5)  vb = 0.001*s*(-52.56/(-0.5)  - 2.28)
        endif
      endif


      if (t .le. -36.8) then
         sb = 508.18 + 14.535*t + 0.2018*t2
        if (t .lt. -43.2)sb = 508.18 + 14.535*(-43.2) + 0.2018*(-43.2)*(-43.2)
      endif
      if ((t .gt. -36.8) .and. (t .le. -22.9))   &
                        sb = 242.94 + 1.5299*t + 0.0429*t2
      if ((t .gt. -22.9) .and. (t .le. 8.2))       &
                        sb = 57.041 - 9.929*t - 0.16204*t2 - 0.002396*t3
      if(t .ge. -8.2) then
         sb = 1.725 - 18.756*t - 0.3964*t2
            if(t .gt. -2.0) sb = 1.725 - 18.756*(-2.0) - 0.3964*(-2.0)*(-2.0)
      endif


      nb  = sb*(1.707*0.01 + 1.205*1.0E-5*sb+4.058E-9*sb*sb)
      d  = 25.0 - t
      a = 1.0 - 0.255*nb + 5.15*0.01*nb*nb-6.89*1.0e-3*nb*nb*nb
      b = 1.0 + 0.146*0.01*t*nb-4.89*0.01*nb                  &
          -2.97*0.01*nb*nb +  5.64 *1.0e-3*nb*nb*nb
      c = 1.0 - 1.96*0.01*d + 8.08*1.0e-5*d*d                 &
          - nb*d*(3.02*1.0e-5 + 3.92*1.0e-5*d+nb*(1.72*1.0e-5 - 6.58*1.0e-6*d ))

      ebo = 88.045-0.4147*t+6.295E-4*t2+1.075E-5*t3

      tswo = 1.1109E-10-3.824E-12*t+6.938E-14*t2-5.096E-16*t3
      sigmao = nb*(10.39 - 2.378*nb+0.683*nb*nb-0.135*nb*nb*nb+1.01*0.01*nb**4.0)
      eb = ebo*a
      tsw = tswo*b
      sigma = sigmao*c
      eo   = 8.854e-12   ! the permittivity of free space (p. 2024)
      eb_real = ESWI + (eb - ESWI)/ (1.0 + (f*tsw)**2.)
      epspp = tsw * f * (eb - ESWI) / (1.0 + (tsw * f)**2.)
      eb_imag = epspp + sigma/(2.0 * pi * eo * f)
      ebrine=cmplx(eb_real,-eb_imag,fp)


    den_sice = 0.87
    if(t .lt. -18.0) den_sice = 0.77
    den_ice   = 0.917 - 1.403e-4*t
    den_brine = 1.0 + 0.0008*sb

    vi = (den_sice - vb*den_brine)/den_ice
    if ((vi+vb) .gt. 1.0) vi = 1.0 - vb
    if (vi .lt. 0.0) vi = 0.0

    xx = vb*sqrt(ebrine)+vi*sqrt(eice)+(1.0-vi-vb)*sqrt(eair)
    esice = xx*xx
    e_real = real(esice,fp)
    e_img =  -aimag(esice)
    cc = 0.387
    den_ss = 1.5
    vss =cc * den_brine*vb/den_ss

CASE Default

    EW0=88.045-0.4147*t+6.295E-4*t2+1.075E-5*t3

    TPTW=1.1109E-10-3.824E-12*t+6.938E-14*t2-5.096E-16*t3

    X=TPTW*FH

    TPTWFQ=1+X*X

    Y=(EW0-ESWI)/TPTWFQ

    e_real=ESWI+Y

    e_img=-X*Y

END SELECT GET_DielectricC

return

end subroutine permitivity


     SUBROUTINE reflection_coefficient(em1, em2, cos_theta_i, cos_theta_t, rv, rh)

    COMPLEX(fp) :: rh, rv,cos_theta_i,cos_theta_t

    COMPLEX(fp) :: em1, em2, m1, m2

    m1 = sqrt(em1)

    m2 = sqrt(em2)

    rv = (m1*cos_theta_t- m2*cos_theta_i)/(m1*cos_theta_t + m2*cos_theta_i)

    rh = (m1*cos_theta_i- m2*cos_theta_t)/(m1*cos_theta_i + m2*cos_theta_t)

    return

    end subroutine reflection_coefficient


END MODULE NESDIS_SEAICE_PHYEM_MODULE
