      MODULE wrt_quick_mod
!
!git $Id$
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2024 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.md                                               !
!=======================================================================
!                                                                      !
!  This routine writes requested model fields into QUICKSAVE file      !
!  using the standard NetCDF library or the Parallel-IO (PIO) library. !
!                                                                      !
!  Notice that only momentum is affected by the full time-averaged     !
!  masks.  If applicable, these mask contains information about        !
!  river runoff and time-dependent wetting and drying variations.      !
!                                                                      !
!=======================================================================
!
      USE mod_param
      USE mod_parallel
      USE mod_coupling
      USE mod_forces
      USE mod_grid
      USE mod_iounits
      USE mod_mixing
      USE mod_ncparam
      USE mod_ocean
      USE mod_scalars
      USE mod_stepping
!
      USE nf_fwrite2d_mod,     ONLY : nf_fwrite2d
      USE nf_fwrite3d_mod,     ONLY : nf_fwrite3d
      USE omega_mod,           ONLY : scale_omega
      USE strings_mod,         ONLY : FoundError
      USE uv_rotate_mod,       ONLY : uv_rotate2d
      USE uv_rotate_mod,       ONLY : uv_rotate3d
!
      implicit none
!
      PUBLIC  :: wrt_quick
      PRIVATE :: wrt_quick_nf90
!
      CONTAINS
!
!***********************************************************************
      SUBROUTINE wrt_quick (ng, tile)
!***********************************************************************
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
!
!  Local variable declarations.
!
      integer :: LBi, UBi, LBj, UBj
!
      character (len=*), parameter :: MyFile =                          &
     &  "ROMS/Utility/wrt_quick.F"
!
!-----------------------------------------------------------------------
!  Write out history fields according to IO type.
!-----------------------------------------------------------------------
!
      LBi=BOUNDS(ng)%LBi(tile)
      UBi=BOUNDS(ng)%UBi(tile)
      LBj=BOUNDS(ng)%LBj(tile)
      UBj=BOUNDS(ng)%UBj(tile)
!
      SELECT CASE (QCK(ng)%IOtype)
        CASE (io_nf90)
          CALL wrt_quick_nf90 (ng, iNLM, tile,                          &
     &                         LBi, UBi, LBj, UBj)
        CASE DEFAULT
          IF (Master) THEN
            WRITE (stdout,10) QCK(ng)%IOtype
          END IF
          exit_flag=3
      END SELECT
      IF (FoundError(exit_flag, NoError, 126, MyFile)) RETURN
!
  10  FORMAT (' WRT_QUICK - Illegal output file type, io_type = ',i0,   &
     &        /,13x,'Check KeyWord ''OUT_LIB'' in ''roms.in''.')
!
      RETURN
      END SUBROUTINE wrt_quick
!
!***********************************************************************
      SUBROUTINE wrt_quick_nf90 (ng, model, tile,                       &
     &                           LBi, UBi, LBj, UBj)
!***********************************************************************
!
      USE mod_netcdf
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, model, tile
      integer, intent(in) :: LBi, UBi, LBj, UBj
!
!  Local variable declarations.
!
      integer :: Fcount, gfactor, gtype, status
      integer :: i, itrc, j, k
!
      real(dp) :: scale
!
      real(r8), allocatable :: Ur2d(:,:)
      real(r8), allocatable :: Vr2d(:,:)
      real(r8), allocatable :: Ur3d(:,:,:)
      real(r8), allocatable :: Vr3d(:,:,:)
      real(r8), allocatable :: Wr3d(:,:,:)
!
      character (len=*), parameter :: MyFile =                          &
     &  "ROMS/Utility/wrt_quick.F"//", wrt_quick_nf90"
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
      SourceFile=MyFile
!
!-----------------------------------------------------------------------
!  Write out quicksave fields.
!-----------------------------------------------------------------------
!
      IF (FoundError(exit_flag, NoError, 174, MyFile)) RETURN
!
!  Set grid type factor to write full (gfactor=1) fields or water
!  points (gfactor=-1) fields only.
!
      gfactor=1
!
!  Set time record index.
!
      QCK(ng)%Rindex=QCK(ng)%Rindex+1
      Fcount=QCK(ng)%load
      QCK(ng)%Nrec(Fcount)=QCK(ng)%Nrec(Fcount)+1
!
!  Report.
!
      IF (Master) WRITE (stdout,10) kstp(ng), nrhs(ng), QCK(ng)%Rindex
!
!  Write out model time (s).
!
      CALL netcdf_put_fvar (ng, model, QCK(ng)%name,                    &
     &                      TRIM(Vname(1,idtime)), time(ng:),           &
     &                      (/QCK(ng)%Rindex/), (/1/),                  &
     &                      ncid = QCK(ng)%ncid,                        &
     &                      varid = QCK(ng)%Vid(idtime))
      IF (FoundError(exit_flag, NoError, 214, MyFile)) RETURN
!
!  Write time-varying depths of RHO-points.
!
      IF (Qout(idpthR,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*r3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idpthR,             &
     &                     QCK(ng)%Vid(idpthR),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     GRID(ng) % z_r,                              &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 322, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idpthR)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write time-varying depths of U-points.
!
      IF (Qout(idpthU,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*u3dvar
        DO k=1,N(ng)
          DO j=Jstr-1,Jend+1
            DO i=IstrU-1,Iend+1
              GRID(ng)%z_v(i,j,k)=0.5_r8*(GRID(ng)%z_r(i-1,j,k)+        &
     &                                    GRID(ng)%z_r(i  ,j,k))
            END DO
          END DO
        END DO
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idpthU,             &
     &                     QCK(ng)%Vid(idpthU),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     GRID(ng) % z_v,                              &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 354, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idpthU)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write time-varying depths of V-points.
!
      IF (Qout(idpthV,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*v3dvar
        DO k=1,N(ng)
          DO j=JstrV-1,Jend+1
            DO i=Istr-1,Iend+1
              GRID(ng)%z_v(i,j,k)=0.5_r8*(GRID(ng)%z_r(i,j-1,k)+        &
     &                                    GRID(ng)%z_r(i,j  ,k))
            END DO
          END DO
        END DO
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idpthV,             &
     &                     QCK(ng)%Vid(idpthV),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     GRID(ng) % z_v,                              &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 386, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idpthV)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write time-varying depths of W-points.
!
      IF (Qout(idpthW,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idpthW,             &
     &                     QCK(ng)%Vid(idpthW),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     GRID(ng) % z_w,                              &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 410, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idpthW)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out free-surface (m)
!
      IF (Qout(idFsur,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idFsur,             &
     &                     QCK(ng)%Vid(idFsur),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     OCEAN(ng) % zeta(:,:,kstp(ng)))
        IF (FoundError(status, nf90_noerr, 439, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idFsur)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out 2D U-momentum component (m/s).
!
      IF (Qout(idUbar,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idUbar,             &
     &                     QCK(ng)%Vid(idUbar),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     OCEAN(ng) % ubar(:,:,kstp(ng)))
        IF (FoundError(status, nf90_noerr, 462, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idUbar)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out 2D V-momentum component (m/s).
!
      IF (Qout(idVbar,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idVbar,             &
     &                     QCK(ng)%Vid(idVbar),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     OCEAN(ng) % vbar(:,:,kstp(ng)))
        IF (FoundError(status, nf90_noerr, 485, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVbar)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out 2D Eastward and Northward momentum components (m/s) at
!  RHO-points.
!
      IF (Qout(idu2dE,ng).and.Qout(idv2dN,ng)) THEN
        IF (.not.allocated(Ur2d)) THEN
          allocate (Ur2d(LBi:UBi,LBj:UBj))
            Ur2d(LBi:UBi,LBj:UBj)=0.0_r8
        END IF
        IF (.not.allocated(Vr2d)) THEN
          allocate (Vr2d(LBi:UBi,LBj:UBj))
            Vr2d(LBi:UBi,LBj:UBj)=0.0_r8
        END IF
        CALL uv_rotate2d (ng, tile, .FALSE., .TRUE.,                    &
     &                    LBi, UBi, LBj, UBj,                           &
     &                    GRID(ng) % CosAngler,                         &
     &                    GRID(ng) % SinAngler,                         &
     &                    OCEAN(ng) % ubar(:,:,kstp(ng)),               &
     &                    OCEAN(ng) % vbar(:,:,kstp(ng)),               &
     &                    Ur2d, Vr2d)
!
        scale=1.0_dp
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idu2dE,             &
     &                     QCK(ng)%Vid(idu2dE),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     Ur2d)
        IF (FoundError(status, nf90_noerr, 528, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idu2dE)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
!
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idv2dN,             &
     &                     QCK(ng)%Vid(idv2dN),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     Vr2d)
        IF (FoundError(status, nf90_noerr, 545, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idv2dN)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
        deallocate (Ur2d)
        deallocate (Vr2d)
      END IF
!
!  Write out 3D U-momentum component (m/s).
!
      IF (Qout(idUvel,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*u3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idUvel,             &
     &                     QCK(ng)%Vid(idUvel),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     OCEAN(ng) % u(:,:,:,nrhs(ng)))
        IF (FoundError(status, nf90_noerr, 572, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idUvel)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out 3D V-momentum component (m/s).
!
      IF (Qout(idVvel,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*v3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idVvel,             &
     &                     QCK(ng)%Vid(idVvel),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     OCEAN(ng) % v(:,:,:,nrhs(ng)))
        IF (FoundError(status, nf90_noerr, 595, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVvel)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out surface U-momentum component (m/s).
!
      IF (Qout(idUsur,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idUsur,             &
     &                     QCK(ng)%Vid(idUsur),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     OCEAN(ng) % u(:,:,N(ng),nrhs(ng)))
        IF (FoundError(status, nf90_noerr, 618, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idUsur)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out surface V-momentum component (m/s).
!
      IF (Qout(idVsur,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idVsur,             &
     &                     QCK(ng)%Vid(idVsur),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     OCEAN(ng) % v(:,:,N(ng),nrhs(ng)))
        IF (FoundError(status, nf90_noerr, 641, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVsur)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out 3D Eastward and Northward momentum components (m/s) at
!  RHO-points.
!
      IF ((Qout(idu3dE,ng).and.Qout(idv3dN,ng)).or.                     &
     &    (Qout(idUsuE,ng).and.Qout(idVsuN,ng))) THEN
        IF (.not.allocated(Ur3d)) THEN
          allocate (Ur3d(LBi:UBi,LBj:UBj,N(ng)))
          Ur3d(LBi:UBi,LBj:UBj,1:N(ng))=0.0_r8
        END IF
        IF (.not.allocated(Vr3d)) THEN
          allocate (Vr3d(LBi:UBi,LBj:UBj,N(ng)))
          Vr3d(LBi:UBi,LBj:UBj,1:N(ng))=0.0_r8
        END IF
        CALL uv_rotate3d (ng, tile, .FALSE., .TRUE.,                    &
     &                    LBi, UBi, LBj, UBj, 1, N(ng),                 &
     &                    GRID(ng) % CosAngler,                         &
     &                    GRID(ng) % SinAngler,                         &
     &                    OCEAN(ng) % u(:,:,:,nrhs(ng)),                &
     &                    OCEAN(ng) % v(:,:,:,nrhs(ng)),                &
     &                    Ur3d, Vr3d)
!
        IF ((Qout(idu3dE,ng).and.Qout(idv3dN,ng))) THEN
          scale=1.0_dp
          gtype=gfactor*r3dvar
          status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idu3dE,           &
     &                       QCK(ng)%Vid(idu3dE),                       &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, 1, N(ng), scale,       &
     &                       Ur3d)
          IF (FoundError(status, nf90_noerr, 686, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idu3dE)), QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
!
          status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idv3dN,           &
     &                       QCK(ng)%Vid(idv3dN),                       &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, 1, N(ng), scale,       &
     &                       Vr3d)
          IF (FoundError(status, nf90_noerr, 703, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idv3dN)), QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
          deallocate (Ur3d)
          deallocate (Vr3d)
        END IF
!
!  Write out surface Eastward and Northward momentum components (m/s) at
!  RHO-points.
!
        IF ((Qout(idUsuE,ng).and.Qout(idVsuN,ng))) THEN
          scale=1.0_dp
          gtype=gfactor*r2dvar
          status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idUsuE,           &
     &                       QCK(ng)%Vid(idUsuE),                       &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, scale,                 &
     &                       Ur3d(:,:,N(ng)))
          IF (FoundError(status, nf90_noerr, 729, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idUsuE)), QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
          status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idVsuN,           &
     &                       QCK(ng)%Vid(idVsuN),                       &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, scale,                 &
     &                       Vr3d(:,:,N(ng)))
          IF (FoundError(status, nf90_noerr, 746, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idVsuN)), QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
        END IF
        deallocate (Ur3d)
        deallocate (Vr3d)
      END IF
!
!  Write out S-coordinate omega vertical velocity (m/s).
!
      IF (Qout(idOvel,ng)) THEN
        IF (.not.allocated(Wr3d)) THEN
          allocate (Wr3d(LBi:UBi,LBj:UBj,0:N(ng)))
          Wr3d(LBi:UBi,LBj:UBj,0:N(ng))=0.0_r8
        END IF
        scale=1.0_dp
        gtype=gfactor*w3dvar
        CALL scale_omega (ng, tile, LBi, UBi, LBj, UBj, 0, N(ng),       &
     &                    GRID(ng) % pm,                                &
     &                    GRID(ng) % pn,                                &
     &                    OCEAN(ng) % W,                                &
     &                    Wr3d)
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idOvel,             &
     &                     QCK(ng)%Vid(idOvel),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     Wr3d)
        IF (FoundError(status, nf90_noerr, 781, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idOvel)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
        deallocate (Wr3d)
      END IF
!
!  Write out vertical velocity (m/s).
!
      IF (Qout(idWvel,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idWvel,             &
     &                     QCK(ng)%Vid(idWvel),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     OCEAN(ng) % wvel)
        IF (FoundError(status, nf90_noerr, 805, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idWvel)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out tracer type variables.
!
      DO itrc=1,NT(ng)
        IF (Qout(idTvar(itrc),ng)) THEN
          scale=1.0_dp
          gtype=gfactor*r3dvar
          status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idTvar(itrc),     &
     &                       QCK(ng)%Tid(itrc),                         &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, 1, N(ng), scale,       &
     &                       OCEAN(ng) % t(:,:,:,nrhs(ng),itrc))
          IF (FoundError(status, nf90_noerr, 829, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idTvar(itrc))),            &
     &                          QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
        END IF
      END DO
!
!  Write out surface tracer type variables.
!
      DO itrc=1,NT(ng)
        IF (Qout(idsurT(itrc),ng)) THEN
          scale=1.0_dp
          gtype=gfactor*r2dvar
          status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idsurT(itrc),     &
     &                       QCK(ng)%Vid(idsurT(itrc)),                 &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, scale,                 &
     &                       OCEAN(ng) % t(:,:,N(ng),nrhs(ng),itrc))
          IF (FoundError(status, nf90_noerr, 855, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idsurT(itrc))),            &
     &                          QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
        END IF
      END DO
!
!  Write out density anomaly.
!
      IF (Qout(idDano,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*r3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idDano,             &
     &                     QCK(ng)%Vid(idDano),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
     &                     OCEAN(ng) % rho)
        IF (FoundError(status, nf90_noerr, 880, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idDano)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out vertical viscosity coefficient.
!
      IF (Qout(idVvis,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idVvis,             &
     &                     QCK(ng)%Vid(idVvis),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     MIXING(ng) % Akv,                            &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 954, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVvis)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out vertical diffusion coefficient for potential temperature.
!
      IF (Qout(idTdif,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idTdif,             &
     &                     QCK(ng)%Vid(idTdif),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     MIXING(ng) % Akt(:,:,:,itemp),               &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 978, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idTdif)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out vertical diffusion coefficient for salinity.
!
      IF (Qout(idSdif,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, model, QCK(ng)%ncid, idSdif,             &
     &                     QCK(ng)%Vid(idSdif),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 0, N(ng), scale,         &
     &                     MIXING(ng) % Akt(:,:,:,isalt),               &
     &                     SetFillVal = .FALSE.)
        IF (FoundError(status, nf90_noerr, 1003, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idSdif)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out surface active tracers fluxes.
!
      DO itrc=1,NAT
        IF (Qout(idTsur(itrc),ng)) THEN
          IF (itrc.eq.itemp) THEN
            scale=rho0*Cp                   ! Celsius m/s to W/m2
          ELSE IF (itrc.eq.isalt) THEN
            scale=1.0_dp
          END IF
          gtype=gfactor*r2dvar
          status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idTsur(itrc),     &
     &                       QCK(ng)%Vid(idTsur(itrc)),                 &
     &                       QCK(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, scale,                 &
     &                       FORCES(ng) % stflx(:,:,itrc))
          IF (FoundError(status, nf90_noerr, 1246, MyFile)) THEN
            IF (Master) THEN
              WRITE (stdout,20) TRIM(Vname(1,idTsur(itrc))),            &
     &                          QCK(ng)%Rindex
            END IF
            exit_flag=3
            ioerror=status
            RETURN
          END IF
        END IF
      END DO
!
!  Write out E-P (m/s).
!
      IF (Qout(idEmPf,ng)) THEN
        scale=1.0_dp
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idEmPf,             &
     &                     QCK(ng)%Vid(idEmPf),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     FORCES(ng) % stflux(:,:,isalt))
        IF (FoundError(status, nf90_noerr, 1394, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idEmPf)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out surface U-momentum stress.
!
      IF (Qout(idUsms,ng)) THEN
        scale=rho0                          ! m2/s2 to Pa
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idUsms,             &
     &                     QCK(ng)%Vid(idUsms),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     FORCES(ng) % sustr)
        IF (FoundError(status, nf90_noerr, 1443, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idUsms)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out surface V-momentum stress.
!
      IF (Qout(idVsms,ng)) THEN
        scale=rho0
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idVsms,             &
     &                     QCK(ng)%Vid(idVsms),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     FORCES(ng) % svstr)
        IF (FoundError(status, nf90_noerr, 1466, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVsms)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out bottom U-momentum stress.
!
      IF (Qout(idUbms,ng)) THEN
        scale=-rho0
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idUbms,             &
     &                     QCK(ng)%Vid(idUbms),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     FORCES(ng) % bustr)
        IF (FoundError(status, nf90_noerr, 1489, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idUbms)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!  Write out bottom V-momentum stress.
!
      IF (Qout(idVbms,ng)) THEN
        scale=-rho0
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, model, QCK(ng)%ncid, idVbms,             &
     &                     QCK(ng)%Vid(idVbms),                         &
     &                     QCK(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
     &                     FORCES(ng) % bvstr)
        IF (FoundError(status, nf90_noerr, 1512, MyFile)) THEN
          IF (Master) THEN
            WRITE (stdout,20) TRIM(Vname(1,idVbms)), QCK(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  Synchronize quicksave NetCDF file to disk to allow other processes
!  to access data immediately after it is written.
!-----------------------------------------------------------------------
!
      CALL netcdf_sync (ng, model, QCK(ng)%name, QCK(ng)%ncid)
      IF (FoundError(exit_flag, NoError, 1576, MyFile)) RETURN
!
  10  FORMAT (2x,'WRT_QUICK_NF90   - writing quicksave', t42,           &
     &        'fields (Index=',i1,',',i1,') in record = ',i0)
  20  FORMAT (/,' WRT_QUICK_NF90 - error while writing variable: ',a,   &
     &        /,18x,'into quicksave NetCDF file for time record: ',i0)
!
      RETURN
      END SUBROUTINE wrt_quick_nf90
      END MODULE wrt_quick_mod
