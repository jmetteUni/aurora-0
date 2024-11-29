      MODULE equilibrium_tide_mod
!
!git $Id$
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2024 The ROMS/TOMS Group           John Wilkin   !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.md                                               !
!=======================================================================
!                                                                      !
!  This module computes the equilibrium tide defined as the shape      !
!  the sea surface (m) would assume if it were motionless and in       !
!  equilibrium with the tide generating forces on a fluid planet.      !
!  It is used to compute the tide generation force (TGF) terms for     !
!  the pressure gradient.                                              !
!                                                                      !
!  References:                                                         !
!                                                                      !
!  Arbic, B.K., Garner, S.T., Hallberg, R.W. and Simmons, H.L., 2004:  !
!    The accuracy of surface elevations in forward global barotropic   !
!    and baroclinic tide models. Deep Sea Research Part II: Topical    !
!    Studies in Oceanography, 51(25-26), pp. 3069-3101.                !
!                                                                      !
!  Arbic, B.K., Alford, M.H., Ansong, J.K., Buijsman, M.C., Ciotti,    !
!    R.B., Farrar, J.T., Hallberg, R.W., Henze, C.E., Hill, C.N.,      !
!    Luecke, C.A. and Menemenlis, D., 2018: Primer on Global Internal  !
!    Tide and Internal Gravity Wave Continuum Modeling in HYCOM and    !
!    MITgcm. In: New Frontiers in Operational Oceanography, E.         !
!    Chassignet, A. Pascual, J. Tintore and J. Verron (Eds.), GODAE    !
!    OceanView, 307-392, doi: 10.17125/gov2018.ch13.                   !
!                                                                      !
!  Doodson, A.T. and Warburg, H.D., 1941: Admiralty Manual of Tides.   !
!    His Majesty's Stationery Office, London, UK, 270 pp.              !
!                                                                      !
!  Egbert, G.D. and Ray, R.D., 2017. Tidal prediction, J. Mar. Res.,   !
!    75(3), pp.189-237.                                                !
!                                                                      !
!=======================================================================
!
      USE mod_kinds
!
      USE exchange_2d_mod
      USE dateclock_mod,   ONLY : datenum
      USE mp_exchange_mod, ONLY : mp_exchange2d
      USE mod_param,       ONLY : BOUNDS, iADM, iNLM, iRPM, iTLM,       &
     &                            NghostPoints
      USE mod_scalars,     ONLY : EWperiodic, NSperiodic, Lnodal,       &
     &                            deg2rad, tide_start, time, Rclock
!
      implicit none
!
!  Define equilibrium tide constituents structure.
!
      TYPE T_ETIDE
        real(r8) :: Afl        ! product: amp*f*love
        real(r8) :: amp        ! amplitude (m)
        real(r8) :: chi        ! phase at Greenwich meridian (degrees)
        real(r8) :: f          ! f nodal factor (nondimensional)
        real(r8) :: love       ! tidal Love number factor
        real(r8) :: nu         ! nu nodal factor (degrees)
        real(r8) :: omega      ! frequency (1/s)
      END TYPE T_ETIDE
!
      TYPE (T_ETIDE) :: Q1     ! Q1 component, diurnal
      TYPE (T_ETIDE) :: O1     ! O1 component, diurnal
      TYPE (T_ETIDE) :: K1     ! K1 component, diurnal
      TYPE (T_ETIDE) :: N2     ! N2 component, semi-diurnal
      TYPE (T_ETIDE) :: M2     ! M2 component, semi-diurnal
      TYPE (T_ETIDE) :: S2     ! S2 component, semi-diurnal
      TYPE (T_ETIDE) :: K2     ! N2 component, semi-diurnal
!
      PUBLIC :: equilibrium_tide
      PUBLIC :: harmonic_constituents
!
      CONTAINS
!
!***********************************************************************
      SUBROUTINE equilibrium_tide (ng, tile, model)
!***********************************************************************
!
      USE mod_grid
      USE mod_ocean
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile, model
!
!  Local variable declarations.
!
      character (len=*), parameter :: MyFile =                          &
     &  "ROMS/Utility/equilibrium_tide.F"
!
      integer :: IminS, ImaxS, JminS, JmaxS
      integer :: LBi, UBi, LBj, UBj, LBij, UBij
!
!  Set horizontal starting and ending indices for automatic private
!  storage arrays.
!
      IminS=BOUNDS(ng)%Istr(tile)-3
      ImaxS=BOUNDS(ng)%Iend(tile)+3
      JminS=BOUNDS(ng)%Jstr(tile)-3
      JmaxS=BOUNDS(ng)%Jend(tile)+3
!
!  Determine array lower and upper bounds in the I- and J-directions.
!
      LBi=BOUNDS(ng)%LBi(tile)
      UBi=BOUNDS(ng)%UBi(tile)
      LBj=BOUNDS(ng)%LBj(tile)
      UBj=BOUNDS(ng)%UBj(tile)
!
!  Set array lower and upper bounds for MIN(I,J) directions and
!  MAX(I,J) directions.
!
      LBij=BOUNDS(ng)%LBij
      UBij=BOUNDS(ng)%UBij
!
      CALL wclock_on (ng, iNLM, 11, 99, MyFile)
      CALL equilibrium_tide_tile (ng, tile, model,                      &
     &                            LBi, UBi, LBj, UBj,                   &
     &                            GRID(ng) % lonr,                      &
     &                            GRID(ng) % Cos2Lat,                   &
     &                            GRID(ng) % SinLat2,                   &
     &                            OCEAN(ng) % eq_tide)
      CALL wclock_off (ng, iNLM, 11, 114, MyFile)
!
      RETURN
      END SUBROUTINE equilibrium_tide
!
!***********************************************************************
      SUBROUTINE equilibrium_tide_tile (ng, tile, model,                &
     &                                  LBi, UBi, LBj, UBj,             &
     &                                  lonr, Cos2Lat, SinLat2,         &
     &                                  eq_tide)
!***********************************************************************
!
!  Imported variables declarations.
!
      integer, intent(in) :: ng, tile, model
      integer, intent(in) :: LBi, UBi, LBj, UBj
!
      real(r8), intent(in) :: lonr(LBi:,LBj:)
      real(r8), intent(in) :: SinLat2(LBi:,LBj:)          ! SIN(2*latr)
      real(r8), intent(in) :: Cos2Lat(LBi:,LBj:)          ! COS2(latr)
      real(r8), intent(out) :: eq_tide(LBi:,LBj:)
!
!  Local variables declarations.
!
      integer :: i, j
!
      real(dp) :: t_time_day, t_time_sec
!
!-----------------------------------------------------------------------
!  Set lower and upper tile bounds and staggered variables bounds for
!  this horizontal domain partition.  Notice that if tile=-1, it will
!  set the values for the global grid.
!-----------------------------------------------------------------------
!
      integer :: Istr, IstrB, IstrP, IstrR, IstrT, IstrM, IstrU
      integer :: Iend, IendB, IendP, IendR, IendT
      integer :: Jstr, JstrB, JstrP, JstrR, JstrT, JstrM, JstrV
      integer :: Jend, JendB, JendP, JendR, JendT
      integer :: Istrm3, Istrm2, Istrm1, IstrUm2, IstrUm1
      integer :: Iendp1, Iendp2, Iendp2i, Iendp3
      integer :: Jstrm3, Jstrm2, Jstrm1, JstrVm2, JstrVm1
      integer :: Jendp1, Jendp2, Jendp2i, Jendp3
!
      Istr   =BOUNDS(ng) % Istr   (tile)
      IstrB  =BOUNDS(ng) % IstrB  (tile)
      IstrM  =BOUNDS(ng) % IstrM  (tile)
      IstrP  =BOUNDS(ng) % IstrP  (tile)
      IstrR  =BOUNDS(ng) % IstrR  (tile)
      IstrT  =BOUNDS(ng) % IstrT  (tile)
      IstrU  =BOUNDS(ng) % IstrU  (tile)
      Iend   =BOUNDS(ng) % Iend   (tile)
      IendB  =BOUNDS(ng) % IendB  (tile)
      IendP  =BOUNDS(ng) % IendP  (tile)
      IendR  =BOUNDS(ng) % IendR  (tile)
      IendT  =BOUNDS(ng) % IendT  (tile)
      Jstr   =BOUNDS(ng) % Jstr   (tile)
      JstrB  =BOUNDS(ng) % JstrB  (tile)
      JstrM  =BOUNDS(ng) % JstrM  (tile)
      JstrP  =BOUNDS(ng) % JstrP  (tile)
      JstrR  =BOUNDS(ng) % JstrR  (tile)
      JstrT  =BOUNDS(ng) % JstrT  (tile)
      JstrV  =BOUNDS(ng) % JstrV  (tile)
      Jend   =BOUNDS(ng) % Jend   (tile)
      JendB  =BOUNDS(ng) % JendB  (tile)
      JendP  =BOUNDS(ng) % JendP  (tile)
      JendR  =BOUNDS(ng) % JendR  (tile)
      JendT  =BOUNDS(ng) % JendT  (tile)
!
      Istrm3 =BOUNDS(ng) % Istrm3 (tile)            ! Istr-3
      Istrm2 =BOUNDS(ng) % Istrm2 (tile)            ! Istr-2
      Istrm1 =BOUNDS(ng) % Istrm1 (tile)            ! Istr-1
      IstrUm2=BOUNDS(ng) % IstrUm2(tile)            ! IstrU-2
      IstrUm1=BOUNDS(ng) % IstrUm1(tile)            ! IstrU-1
      Iendp1 =BOUNDS(ng) % Iendp1 (tile)            ! Iend+1
      Iendp2 =BOUNDS(ng) % Iendp2 (tile)            ! Iend+2
      Iendp2i=BOUNDS(ng) % Iendp2i(tile)            ! Iend+2 interior
      Iendp3 =BOUNDS(ng) % Iendp3 (tile)            ! Iend+3
      Jstrm3 =BOUNDS(ng) % Jstrm3 (tile)            ! Jstr-3
      Jstrm2 =BOUNDS(ng) % Jstrm2 (tile)            ! Jstr-2
      Jstrm1 =BOUNDS(ng) % Jstrm1 (tile)            ! Jstr-1
      JstrVm2=BOUNDS(ng) % JstrVm2(tile)            ! JstrV-2
      JstrVm1=BOUNDS(ng) % JstrVm1(tile)            ! JstrV-1
      Jendp1 =BOUNDS(ng) % Jendp1 (tile)            ! Jend+1
      Jendp2 =BOUNDS(ng) % Jendp2 (tile)            ! Jend+2
      Jendp2i=BOUNDS(ng) % Jendp2i(tile)            ! Jend+2 interior
      Jendp3 =BOUNDS(ng) % Jendp3 (tile)            ! Jend+3
!
!-----------------------------------------------------------------------
!  Computes sea surface associated with the equilibrium tide
!-----------------------------------------------------------------------
!
!  Set equilibrium tide time in seconds. It can be negative if ROMS time
!  (seconds since reference date, Rclock%DateNumber) is earlier than the
!  date of zero phase (Rclock%tide_DateNumber) forcing tidal boundary
!  data. This zero phase date is set up when preparing the tidal NetCDF
!  file.
!
      t_time_sec=(Rclock%DateNumber(2)+time(ng))-                       &
     &           Rclock%tide_DateNumber(2)
!
!  Compute astronomial equilibrium tide (m) with diurnal and semidiurnal
!  constituents. The long-period constituents and high-order harmonics
!  are neglected.
!
      DO j=JstrT,JendT
        DO i=IstrT,IendT
          eq_tide(i,j)=Q1%Afl*SinLat2(i,j)*                             &
     &                 COS(Q1%omega*t_time_sec+                         &
     &                     deg2rad*(lonr(i,j)+Q1%chi+Q1%nu))+           &
     &                 O1%Afl*SinLat2(i,j)*                             &
     &                 COS(O1%omega*t_time_sec+                         &
     &                     deg2rad*(lonr(i,j)+O1%chi+O1%nu))+           &
     &                 K1%Afl*SinLat2(i,j)*                             &
     &                 COS(K1%omega*t_time_sec+                         &
     &                     deg2rad*(lonr(i,j)+K1%chi+K1%nu))+           &
     &                 N2%Afl*Cos2Lat(i,j)*                             &
     &                 COS(N2%omega*t_time_sec+                         &
     &                     deg2rad*(2.0_r8*lonr(i,j)+N2%chi+N2%nu))+    &
     &                 M2%Afl*Cos2Lat(i,j)*                             &
     &                 COS(M2%omega*t_time_sec+                         &
     &                     deg2rad*(2.0_r8*lonr(i,j)+M2%chi+M2%nu))+    &
     &                 S2%Afl*Cos2Lat(i,j)*                             &
     &                 COS(S2%omega*t_time_sec+                         &
     &                     deg2rad*(2.0_r8*lonr(i,j)+S2%chi+S2%nu))+    &
     &                 K2%Afl*Cos2Lat(i,j)*                             &
     &                 COS(K2%omega*t_time_sec+                         &
     &                     deg2rad*(2.0_r8*lonr(i,j)+K2%chi+K2%nu))
        END DO
      END DO
!
      IF (EWperiodic(ng).or.NSperiodic(ng)) THEN
        CALL exchange_r2d_tile (ng, tile,                               &
     &                          LBi, UBi, LBj, UBj,                     &
     &                          eq_tide)
      END IF
      CALL mp_exchange2d (ng, tile, iNLM, 1,                            &
     &                    LBi, UBi, LBj, UBj,                           &
     &                    NghostPoints,                                 &
     &                    EWperiodic(ng), NSperiodic(ng),               &
     &                    eq_tide)
!
      RETURN
      END SUBROUTINE equilibrium_tide_tile
!
!***********************************************************************
      SUBROUTINE harmonic_constituents (Lnodal)
!***********************************************************************
!
!  Imported variables declarations.
!
      logical,  intent(in) :: Lnodal      ! Apply lunar nodal correction
!
!  Local variables declarations.
!
      real(r8) :: N, T, h, p, s
      real(dp) :: Astro_DateNumber(2)     ! Jan 1, 2000 12:00:00
!
!-----------------------------------------------------------------------
!  Compute fundamental astronomical parameters. Adapted from Egbert and
!  Ray, 2017, Table 1.
!-----------------------------------------------------------------------
!
!  Set Egbert and Ray time reference for their astronomical parameters
!  (Table 1): days since 2000-01-01:12:00:00.
!
      CALL datenum (Astro_DateNumber, 2000, 1, 1, 12, 0, 0.0_dp)
!
!  Terrestial time (in centuries) since tide reference date number. It
!  is set-up according to the chosen "tide_start" in standard input file
!  or the tidal forcing NetCDF file if found (default, recommended).
!
!  Recall that the length of a year is 365.2425 days for the now called
!  Gregorian Calendar (corrected after 15 October 1582).
!
      T=(Rclock%tide_DateNumber(1)-Astro_DateNumber(1))/36524.25_r8
!
!  Mean longitude of the moon (Period = tropical month).
!
      s=218.316_r8+481267.8812_r8*T
!
!  Mean longitude of the sun (Period = tropical year).
!
      h=280.466_r8+36000.7698_r8*T
!
!  Mean longitude of lunar perigee (Period = 8.85 years).
!
      p=83.353_r8+4069.0137_r8*T
!
!  Mean longitude of lunar node (Period = 18.6 years).
!
      N=-234.955_r8-1934.1363_r8*T                       ! degrees
      N=N*deg2rad                                        ! radians
!
!-----------------------------------------------------------------------
!  Compute the harmonic constituents of the equilibrium tide at
!  Greenwich. Adapted from Doodson and Warburg, 1941, Table 1.
!-----------------------------------------------------------------------
!
!  Nodal factors "f" and "nu" account for the slow modulation of the
!  tidal constituents due (principally) to the 18.6-year lunar nodal
!  cycle.
!
      IF (Lnodal) THEN                                 ! f nodal factor
        O1%f=1.009_r8+0.187_r8*COS(N)-0.015_r8*COS(2.0_r8*N)
        K1%f=1.006_r8+0.115_r8*COS(N)-0.009_r8*COS(2.0_r8*N)
        M2%f=1.0_r8-0.037_r8*COS(N)
        S2%f=1.0_r8
        K2%f=1.024_r8+0.286_r8*COS(N)+0.008_r8*COS(2.0_r8*N)
      ELSE
        O1%f=1.0_r8
        K1%f=1.0_r8
        M2%f=1.0_r8
        S2%f=1.0_r8
        K2%f=1.0_r8
      END IF
      Q1%f=O1%f
      N2%f=M2%f
!
      IF (Lnodal) THEN                                 ! nu nodal factor
        O1%nu=10.8_r8*SIN(N)-1.3_r8*SIN(2.0_r8*N)
        K1%nu=-8.9_r8*SIN(N)+0.7_r8*SIN(2.0_r8*N)
        M2%nu=-2.1_r8*SIN(N)
        S2%nu=0.0_r8
        K2%nu=-17.7_r8*SIN(N)+0.7_r8*SIN(2.0_r8*N)
      ELSE
        O1%nu=0.0_r8
        K1%nu=0.0_r8
        M2%nu=0.0_r8
        S2%nu=0.0_r8
        K2%nu=0.0_r8
      END IF
      Q1%nu=O1%nu
      N2%nu=M2%nu
!
!  Compute tidal constituent phase "chi" (degrees) at Greenwich meridian,
!  lambda = 0.
!
      Q1%chi=h-3.0_r8*s+p-90.0_r8
      O1%chi=h-2.0_r8*s-90.0_r8
      K1%chi=h+90.0_r8
      N2%chi=2.0_r8*h-3.0_r8*s+p
      M2%chi=2.0_r8*h-2.0_r8*s
      S2%chi=0.0_r8
      K2%chi=2.0_r8*h
!
!  Compute tidal constituent frequency (1/s).
!
      Q1%omega=0.6495854E-4_r8
      O1%omega=0.6759774E-4_r8
      K1%omega=0.7292117E-4_r8
      N2%omega=1.378797E-4_r8
      M2%omega=1.405189E-4_r8
      S2%omega=1.454441E-4_r8
      K2%omega=1.458423E-4_r8
!
!  Compute tidal constituent amplitude (m).
!
      Q1%amp= 1.9273E-2_r8
      O1%amp=10.0661E-2_r8
      K1%amp=14.1565E-2_r8
      N2%amp= 4.6397E-2_r8
      M2%amp=24.2334E-2_r8
      S2%amp=11.2743E-2_r8
      K2%amp= 3.0684E-2_r8
!
!  Compute tidal constituent Love number factors (1+k2-h2).  The Love
!  number is defined as the ratio of the body tide to the height of
!  the static equilibrium tide.
!
      Q1%love=0.695_r8
      O1%love=0.695_r8
      K1%love=0.736_r8
      N2%love=0.693_r8
      M2%love=0.693_r8
      S2%love=0.693_r8
      K2%love=0.693_r8
!
!  Compute product of amp*f*love.
!
      Q1%Afl=Q1%amp*Q1%f*Q1%love
      O1%Afl=O1%amp*O1%f*O1%love
      K1%Afl=K1%amp*K1%f*K1%love
      N2%Afl=N2%amp*N2%f*N2%love
      M2%Afl=M2%amp*M2%f*M2%love
      S2%Afl=S2%amp*S2%f*S2%love
      K2%Afl=K2%amp*K2%f*K2%love
!
      RETURN
      END SUBROUTINE harmonic_constituents
      END MODULE equilibrium_tide_mod
