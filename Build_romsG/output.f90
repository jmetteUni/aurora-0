      SUBROUTINE output (ng)
!
!git $Id$
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2024 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.md                                               !
!=======================================================================
!                                                                      !
!  This subroutine manages nonlinear model output. It creates output   !
!  NetCDF files and writes out data into NetCDF files. If requested,   !
!  it can create several history and/or time-averaged files to avoid   !
!  generating too large files during a single model run.               !
!                                                                      !
!=======================================================================
!
      USE mod_param
      USE mod_parallel
      USE mod_iounits
      USE mod_ncparam
      USE mod_scalars
!
      USE close_io_mod,    ONLY : close_file
      USE def_avg_mod,     ONLY : def_avg
      USE def_diags_mod,   ONLY : def_diags
      USE def_his_mod,     ONLY : def_his
      USE def_quick_mod,   ONLY : def_quick
      USE def_rst_mod,     ONLY : def_rst
      USE distribute_mod,  ONLY : mp_bcasts
      USE strings_mod,     ONLY : FoundError
      USE wrt_avg_mod,     ONLY : wrt_avg
      USE wrt_diags_mod,   ONLY : wrt_diags
      USE wrt_his_mod,     ONLY : wrt_his
      USE wrt_quick_mod,   ONLY : wrt_quick
      USE wrt_rst_mod,     ONLY : wrt_rst
!
      implicit none
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng
!
!  Local variable declarations.
!
      logical :: Ldefine, Lupdate, NewFile
!
      integer :: Fcount, ifile, status, tile
!
      character (len=*), parameter :: MyFile =                          &
     &  "ROMS/Nonlinear/output.F"
!
      SourceFile=MyFile
!
!-----------------------------------------------------------------------
!  Turn on output data time wall clock.
!-----------------------------------------------------------------------
!
      CALL wclock_on (ng, iNLM, 8, 104, MyFile)
!
!-----------------------------------------------------------------------
!  If appropriate, process nonlinear history NetCDF file.
!-----------------------------------------------------------------------
!
!  Set tile for local array manipulations in output routines.
!
      tile=MyRank
!
!  Turn off checking for analytical header files.
!
      IF (Lanafile) THEN
        Lanafile=.FALSE.
      END IF
!
!  If appropriate, set switch for updating biology header file global
!  attribute in output NetCDF files.
!
      Lupdate=.FALSE.
!
!  Create output history NetCDF file or prepare existing file to
!  append new data to it.  Also,  notice that it is possible to
!  create several files during a single model run.
!
      IF (LdefHIS(ng)) THEN
        IF (ndefHIS(ng).gt.0) THEN
          IF (idefHIS(ng).lt.0) THEN
            idefHIS(ng)=((ntstart(ng)-1)/ndefHIS(ng))*ndefHIS(ng)
            IF (idefHIS(ng).lt.iic(ng)-1) THEN
              idefHIS(ng)=idefHIS(ng)+ndefHIS(ng)
            END IF
          END IF
          IF ((nrrec(ng).ne.0).and.(iic(ng).eq.ntstart(ng))) THEN
            IF ((iic(ng)-1).eq.idefHIS(ng)) THEN
              HIS(ng)%load=0                  ! restart, reset counter
              Ldefine=.FALSE.                 ! finished file, delay
            ELSE                              ! creation of next file
              Ldefine=.TRUE.
              NewFile=.FALSE.                 ! unfinished file, inquire
            END IF                            ! content for appending
            idefHIS(ng)=idefHIS(ng)+nHIS(ng)  ! restart offset
          ELSE IF ((iic(ng)-1).eq.idefHIS(ng)) THEN
            idefHIS(ng)=idefHIS(ng)+ndefHIS(ng)
            IF (nHIS(ng).ne.ndefHIS(ng).and.iic(ng).eq.ntstart(ng)) THEN
              idefHIS(ng)=idefHIS(ng)+nHIS(ng)  ! multiple record offset
            END IF
            Ldefine=.TRUE.
            NewFile=.TRUE.
          ELSE
            Ldefine=.FALSE.
          END IF
          IF (Ldefine) THEN                     ! create new file or
            IF (iic(ng).eq.ntstart(ng)) THEN    ! inquire existing file
              HIS(ng)%load=0                    ! reset filename counter
            END IF
            ifile=(iic(ng)-1)/ndefHIS(ng)+1     ! next filename suffix
            HIS(ng)%load=HIS(ng)%load+1
            IF (HIS(ng)%load.gt.HIS(ng)%Nfiles) THEN
              IF (Master) THEN
                WRITE (stdout,10) 'HIS(ng)%load = ', HIS(ng)%load,      &
     &                             HIS(ng)%Nfiles, TRIM(HIS(ng)%base),  &
     &                             ifile
              END IF
              exit_flag=4
              IF (FoundError(exit_flag, NoError,                        &
     &                       179, MyFile)) RETURN
            END IF
            Fcount=HIS(ng)%load
            HIS(ng)%Nrec(Fcount)=0
            IF (Master) THEN
              WRITE (HIS(ng)%name,20) TRIM(HIS(ng)%base), ifile
            END IF
            CALL mp_bcasts (ng, iNLM, HIS(ng)%name)
            HIS(ng)%files(Fcount)=TRIM(HIS(ng)%name)
            CALL close_file (ng, iNLM, HIS(ng), HIS(ng)%name, Lupdate)
            CALL def_his (ng, NewFile)
            IF (FoundError(exit_flag, NoError, 192, MyFile)) RETURN
          END IF
          IF ((iic(ng).eq.ntstart(ng)).and.(nrrec(ng).ne.0)) THEN
            LwrtHIS(ng)=.FALSE.                 ! avoid writing initial
          ELSE                                  ! fields during restart
            LwrtHIS(ng)=.TRUE.
          END IF
        ELSE
          IF (iic(ng).eq.ntstart(ng)) THEN
            CALL def_his (ng, ldefout(ng))
            IF (FoundError(exit_flag, NoError, 202, MyFile)) RETURN
            LwrtHIS(ng)=.TRUE.
            LdefHIS(ng)=.FALSE.
          END IF
        END IF
      END IF
!
!  Write out data into history NetCDF file.  Avoid writing initial
!  conditions in perturbation mode computations.
!
      IF (LwrtHIS(ng)) THEN
        IF (LwrtPER(ng)) THEN
          IF ((iic(ng).gt.ntstart(ng)).and.                             &
     &        (MOD(iic(ng)-1,nHIS(ng)).eq.0)) THEN
            IF (nrrec(ng).eq.0.or.iic(ng).ne.ntstart(ng)) THEN
              CALL wrt_his (ng, tile)
            END IF
            IF (FoundError(exit_flag, NoError, 219, MyFile)) RETURN
          END IF
        ELSE
          IF (MOD(iic(ng)-1,nHIS(ng)).eq.0) THEN
            CALL wrt_his (ng, tile)
            IF (FoundError(exit_flag, NoError, 224, MyFile)) RETURN
          END IF
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  If appropriate, process nonlinear quicksave NetCDF file.
!-----------------------------------------------------------------------
!
!  Create output quicksave NetCDF file or prepare existing file to
!  append new data to it.  Also,  notice that it is possible to
!  create several files during a single model run.
!
      IF (LdefQCK(ng)) THEN
        IF (ndefQCK(ng).gt.0) THEN
          IF (idefQCK(ng).lt.0) THEN
            idefQCK(ng)=((ntstart(ng)-1)/ndefQCK(ng))*ndefQCK(ng)
            IF (idefQCK(ng).lt.iic(ng)-1) THEN
              idefQCK(ng)=idefQCK(ng)+ndefQCK(ng)
            END IF
          END IF
          IF ((nrrec(ng).ne.0).and.(iic(ng).eq.ntstart(ng))) THEN
            IF ((iic(ng)-1).eq.idefQCK(ng)) THEN
              QCK(ng)%load=0                  ! restart, reset counter
              Ldefine=.FALSE.                 ! finished file, delay
            ELSE                              ! creation of next file
              Ldefine=.TRUE.
              NewFile=.FALSE.                 ! unfinished file, inquire
            END IF                            ! content for appending
            idefQCK(ng)=idefQCK(ng)+nQCK(ng)  ! restart offset
          ELSE IF ((iic(ng)-1).eq.idefQCK(ng)) THEN
            idefQCK(ng)=idefQCK(ng)+ndefQCK(ng)
            IF (nQCK(ng).ne.ndefQCK(ng).and.iic(ng).eq.ntstart(ng)) THEN
              idefQCK(ng)=idefQCK(ng)+nQCK(ng)  ! multiple record offset
            END IF
            Ldefine=.TRUE.
            NewFile=.TRUE.
          ELSE
            Ldefine=.FALSE.
          END IF
          IF (Ldefine) THEN                     ! create new file or
            IF (iic(ng).eq.ntstart(ng)) THEN    ! inquire existing file
              QCK(ng)%load=0                    ! reset filename counter
            END IF
            ifile=(iic(ng)-1)/ndefQCK(ng)+1     ! next filename suffix
            QCK(ng)%load=QCK(ng)%load+1
            IF (QCK(ng)%load.gt.QCK(ng)%Nfiles) THEN
              IF (Master) THEN
                WRITE (stdout,10) 'QCK(ng)%load = ', QCK(ng)%load,      &
     &                             QCK(ng)%Nfiles, TRIM(QCK(ng)%base),  &
     &                             ifile
              END IF
              exit_flag=4
              IF (FoundError(exit_flag, NoError,                        &
     &                       380, MyFile)) RETURN
            END IF
            Fcount=QCK(ng)%load
            QCK(ng)%Nrec(Fcount)=0
            IF (Master) THEN
              WRITE (QCK(ng)%name,20) TRIM(QCK(ng)%base), ifile
            END IF
            CALL mp_bcasts (ng, iNLM, QCK(ng)%name)
            QCK(ng)%files(Fcount)=TRIM(QCK(ng)%name)
            CALL close_file (ng, iNLM, QCK(ng), QCK(ng)%name, Lupdate)
            CALL def_quick (ng, NewFile)
            IF (FoundError(exit_flag, NoError, 393, MyFile)) RETURN
          END IF
          IF ((iic(ng).eq.ntstart(ng)).and.(nrrec(ng).ne.0)) THEN
            LwrtQCK(ng)=.FALSE.                 ! avoid writing initial
          ELSE                                  ! fields during restart
            LwrtQCK(ng)=.TRUE.
          END IF
        ELSE
          IF (iic(ng).eq.ntstart(ng)) THEN
            CALL def_quick (ng, ldefout(ng))
            IF (FoundError(exit_flag, NoError, 403, MyFile)) RETURN
            LwrtQCK(ng)=.TRUE.
            LdefQCK(ng)=.FALSE.
          END IF
        END IF
      END IF
!
!  Write out data into quicksave NetCDF file.  Avoid writing initial
!  conditions in perturbation mode computations.
!
      IF (LwrtQCK(ng)) THEN
        IF (LwrtPER(ng)) THEN
          IF ((iic(ng).gt.ntstart(ng)).and.                             &
     &        (MOD(iic(ng)-1,nQCK(ng)).eq.0)) THEN
            IF (nrrec(ng).eq.0.or.iic(ng).ne.ntstart(ng)) THEN
              CALL wrt_quick (ng, tile)
            END IF
            IF (FoundError(exit_flag, NoError, 420, MyFile)) RETURN
          END IF
        ELSE
          IF (MOD(iic(ng)-1,nQCK(ng)).eq.0) THEN
            CALL wrt_quick (ng, tile)
            IF (FoundError(exit_flag, NoError, 425, MyFile)) RETURN
          END IF
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  If appropriate, process time-averaged NetCDF file.
!-----------------------------------------------------------------------
!
!  Create output time-averaged NetCDF file or prepare existing file
!  to append new data to it. Also, notice that it is possible to
!  create several files during a single model run.
!
      IF (LdefAVG(ng)) THEN
        IF (ndefAVG(ng).gt.0) THEN
          IF (idefAVG(ng).lt.0) THEN
            idefAVG(ng)=((ntstart(ng)-1)/ndefAVG(ng))*ndefAVG(ng)
            IF ((ndefAVG(ng).eq.nAVG(ng)).and.(idefAVG(ng).le.0)) THEN
              idefAVG(ng)=ndefAVG(ng)         ! one file per record
            ELSE IF (idefAVG(ng).lt.iic(ng)-1) THEN
              idefAVG(ng)=idefAVG(ng)+ndefAVG(ng)
            END IF
          END IF
          IF ((nrrec(ng).ne.0).and.(iic(ng).eq.ntstart(ng))) THEN
            IF ((iic(ng)-1).eq.idefAVG(ng)) THEN
              AVG(ng)%load=0                  ! restart, reset counter
              Ldefine=.FALSE.                 ! finished file, delay
            ELSE                              ! creation of next file
              NewFile=.FALSE.
              Ldefine=.TRUE.                  ! unfinished file, inquire
            END IF                            ! content for appending
            idefAVG(ng)=idefAVG(ng)+nAVG(ng)  ! restart offset
          ELSE IF ((iic(ng)-1).eq.idefAVG(ng)) THEN
            idefAVG(ng)=idefAVG(ng)+ndefAVG(ng)
            IF (nAVG(ng).ne.ndefAVG(ng).and.iic(ng).eq.ntstart(ng)) THEN
              idefAVG(ng)=idefAVG(ng)+nAVG(ng)
            END IF
            Ldefine=.TRUE.
            Newfile=.TRUE.
          ELSE
            Ldefine=.FALSE.
          END IF
          IF (Ldefine) THEN
            IF (iic(ng).eq.ntstart(ng)) THEN
              AVG(ng)%load=0                  ! reset filename counter
            END IF
            IF (ndefAVG(ng).eq.nAVG(ng)) THEN ! next filename suffix
              ifile=(iic(ng)-1)/ndefAVG(ng)
            ELSE
              ifile=(iic(ng)-1)/ndefAVG(ng)+1
            END IF
            AVG(ng)%load=AVG(ng)%load+1
            IF (AVG(ng)%load.gt.AVG(ng)%Nfiles) THEN
              IF (Master) THEN
                WRITE (stdout,10) 'AVG(ng)%load = ', AVG(ng)%load,      &
     &                             AVG(ng)%Nfiles, TRIM(AVG(ng)%base),  &
     &                             ifile
              END IF
              exit_flag=4
              IF (FoundError(exit_flag, NoError,                        &
     &                       487, MyFile)) RETURN
            END IF
            Fcount=AVG(ng)%load
            AVG(ng)%Nrec(Fcount)=0
            IF (Master) THEN
              WRITE (AVG(ng)%name,20) TRIM(AVG(ng)%base), ifile
            END IF
            CALL mp_bcasts (ng, iNLM, AVG(ng)%name)
            AVG(ng)%files(Fcount)=TRIM(AVG(ng)%name)
            CALL close_file (ng, iNLM, AVG(ng), AVG(ng)%name, Lupdate)
            CALL def_avg (ng, Newfile)
            IF (FoundError(exit_flag, NoError, 500, MyFile)) RETURN
            LwrtAVG(ng)=.TRUE.
          END IF
        ELSE
          IF (iic(ng).eq.ntstart(ng)) THEN
            CALL def_avg (ng, ldefout(ng))
            IF (FoundError(exit_flag, NoError, 506, MyFile)) RETURN
            LwrtAVG(ng)=.TRUE.
            LdefAVG(ng)=.FALSE.
          END IF
        END IF
      END IF
!
!  Write out data into time-averaged NetCDF file.
!
      IF (LwrtAVG(ng)) THEN
        IF (((iic(ng).gt.ntstart(ng)).and.                              &
     &       (MOD(iic(ng)-1,nAVG(ng)).eq.0)).or.                        &
     &      ((iic(ng).ge.ntsAVG(ng)).and.(nAVG(ng).eq.1))) THEN
          CALL wrt_avg (ng, tile)
          IF (FoundError(exit_flag, NoError, 520, MyFile)) RETURN
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  If appropriate, process time-averaged diagnostics NetCDF file.
!-----------------------------------------------------------------------
!
!  Create output time-averaged diagnostics NetCDF file or prepare
!  existing file to append new data to it. Also, notice that it is
!  possible to create several files during a single model run.
!
      IF (LdefDIA(ng)) THEN
        IF (ndefDIA(ng).gt.0) THEN
          IF (idefDIA(ng).lt.0) THEN
            idefDIA(ng)=((ntstart(ng)-1)/ndefDIA(ng))*ndefDIA(ng)
            IF ((ndefDIA(ng).eq.nDIA(ng)).and.(idefDIA(ng).le.0)) THEN
              idefDIA(ng)=ndefDIA(ng)         ! one file per record
            ELSE IF (idefDIA(ng).lt.iic(ng)-1) THEN
              idefDIA(ng)=idefDIA(ng)+ndefDIA(ng)
            END IF
          END IF
          IF ((nrrec(ng).ne.0).and.(iic(ng).eq.ntstart(ng))) THEN
            IF ((iic(ng)-1).eq.idefDIA(ng)) THEN
              DIA(ng)%load=0                  ! restart, reset counter
              Ldefine=.FALSE.                 ! finished file, delay
            ELSE                              ! creation of next file
              NewFile=.FALSE.
              Ldefine=.TRUE.                  ! unfinished file, inquire
            END IF                            ! content for appending
            idefDIA(ng)=idefDIA(ng)+nDIA(ng)  ! restart offset
          ELSE IF ((iic(ng)-1).eq.idefDIA(ng)) THEN
            idefDIA(ng)=idefDIA(ng)+ndefDIA(ng)
            IF (nDIA(ng).ne.ndefDIA(ng).and.iic(ng).eq.ntstart(ng)) THEN
              idefDIA(ng)=idefDIA(ng)+nDIA(ng)
            END IF
            Ldefine=.TRUE.
            Newfile=.TRUE.
          ELSE
            Ldefine=.FALSE.
          END IF
          IF (Ldefine) THEN
            IF (iic(ng).eq.ntstart(ng)) THEN
              DIA(ng)%load=0                  ! reset filename counter
            END IF
            IF (ndefDIA(ng).eq.nDIA(ng)) THEN ! next filename suffix
              ifile=(iic(ng)-1)/ndefDIA(ng)
            ELSE
              ifile=(iic(ng)-1)/ndefDIA(ng)+1
            END IF
            DIA(ng)%load=DIA(ng)%load+1
            IF (DIA(ng)%load.gt.DIA(ng)%Nfiles) THEN
              IF (Master) THEN
                WRITE (stdout,10) 'DIA(ng)%load = ', DIA(ng)%load,      &
     &                             DIA(ng)%Nfiles, TRIM(DIA(ng)%base),  &
     &                             ifile
              END IF
              exit_flag=4
              IF (FoundError(exit_flag, NoError,                        &
     &                       586, MyFile)) RETURN
            END IF
            Fcount=DIA(ng)%load
            DIA(ng)%Nrec(Fcount)=0
            IF (Master) THEN
              WRITE (DIA(ng)%name,20) TRIM(DIA(ng)%base), ifile
            END IF
            CALL mp_bcasts (ng, iNLM, DIA(ng)%name)
            DIA(ng)%files(Fcount)=TRIM(DIA(ng)%name)
            CALL close_file (ng, iNLM, DIA(ng), DIA(ng)%name, Lupdate)
            CALL def_diags (ng, Newfile)
            IF (FoundError(exit_flag, NoError, 599, MyFile)) RETURN
            LwrtDIA(ng)=.TRUE.
          END IF
        ELSE
          IF (iic(ng).eq.ntstart(ng)) THEN
            CALL def_diags (ng, ldefout(ng))
            IF (FoundError(exit_flag, NoError, 605, MyFile)) RETURN
            LwrtDIA(ng)=.TRUE.
            LdefDIA(ng)=.FALSE.
          END IF
        END IF
      END IF
!
!  Write out data into time-averaged diagnostics NetCDF file.
!
      IF (LwrtDIA(ng)) THEN
        IF (((iic(ng).gt.ntstart(ng)).and.                              &
     &       (MOD(iic(ng)-1,nDIA(ng)).eq.0)).or.                        &
     &      ((iic(ng).ge.ntsDIA(ng)).and.(nDIA(ng).eq.1))) THEN
          CALL wrt_diags (ng, tile)
          IF (FoundError(exit_flag, NoError, 619, MyFile)) RETURN
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  If appropriate, process restart NetCDF file.
!-----------------------------------------------------------------------
!
!  Create output restart NetCDF file or prepare existing file to
!  append new data to it.
!
      IF (LdefRST(ng)) THEN
        CALL def_rst (ng)
        IF (FoundError(exit_flag, NoError, 693, MyFile)) RETURN
        LwrtRST(ng)=.TRUE.
        LdefRST(ng)=.FALSE.
      END IF
!
!  Write out data into restart NetCDF file.
!
      IF (LwrtRST(ng)) THEN
        IF ((iic(ng).gt.ntstart(ng)).and.                               &
     &      (MOD(iic(ng)-1,nRST(ng)).eq.0)) THEN
          CALL wrt_rst (ng, tile)
          IF (FoundError(exit_flag, NoError, 704, MyFile)) RETURN
        END IF
      END IF
!
!-----------------------------------------------------------------------
!  Turn off output data time wall clock.
!-----------------------------------------------------------------------
!
      CALL wclock_off (ng, iNLM, 8, 744, MyFile)
!
 10   FORMAT (/,' OUTPUT - multi-file counter ',a,i0,                   &
     &          ', is greater than Nfiles = ',i0,1x,'dimension',        &
     &        /,10x,'in structure when creating next file: ',           &
     &           a,'_',i4.4,'.nc',                                      &
     &        /,10x,'Incorrect OutFiles logic in ''read_phypar''.')
 20   FORMAT (a,'_',i4.4,'.nc')
!
      RETURN
      END SUBROUTINE output
