      MODULE stdout_mod
!
!git $Id$
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2024 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.md                                               !
!=======================================================================
!                                                                      !
!  It sets the ROMS standard output unit to write verbose execution    !
!  information. Notice that the default standard out unit in Fortran   !
!  is 6.                                                               !
!                                                                      !
!  In some applications like coupling or disjointed mpi-communications,!
!  it is advantageous to write standard output to a specific filename  !
!  instead of the default Fortran standard output unit 6. If that is   !
!  the case, it opens such formatted file for writing.                 !
!                                                                      !
!=======================================================================
!
      USE mod_parallel
      USE mod_iounits
      USE mod_scalars
!
      USE strings_mod,    ONLY : FoundError
!
      implicit none
      PUBLIC  :: stdout_unit
!
!-----------------------------------------------------------------------
!  Module parameters.
!-----------------------------------------------------------------------
!
!  The following switch tells if the standard output unit/file has
!  been specified. It must be set up only once to avoid errors and
!  is usually called at the beginning of ROMS_initialize. However,
!  it is required earlier during ESM coupling configurations.
!
      logical, save :: Set_StdOutUnit = .TRUE.
!
!-----------------------------------------------------------------------
      CONTAINS
!-----------------------------------------------------------------------
!
      FUNCTION stdout_unit (MyMaster) RESULT (StdOutUnit)
!
!***********************************************************************
!                                                                      !
!  This function determines ROMS standard output unit to write its     !
!  running verbose information.                                        !
!                                                                      !
!  On Input:                                                           !
!                                                                      !
!     MyMaster    Switch indicating Master process (logical)           !
!                                                                      !
!  On Output:                                                          !
!                                                                      !
!     StdOutUnit  Assigned standard output unit (integer; default=6)   !
!                                                                      !
!***********************************************************************
!
!  Imported variable declarations.
!
      logical, intent(in)  :: MyMaster
!
!  Local variable declararions
!
      integer :: io_err
      integer :: StdOutUnit
!
      character (len=10 )          :: stdout_file
      character (len=256)          :: io_errmsg
      character (len=*), parameter :: MyFile =                          &
     &  "ROMS/Utility/stdout_mod.F"//", stdout_unit"
!
      SourceFile=MyFile
!
!-----------------------------------------------------------------------
!  Set ROMS standard input unit. If requested, set and open standard
!  output file for writing.
!-----------------------------------------------------------------------
!
! Set default standard output unit in Fortran.
!
      StdOutUnit=6
!
      END FUNCTION stdout_unit
!
      END MODULE stdout_mod
