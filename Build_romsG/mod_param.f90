      MODULE mod_param
!
!git $Id$
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2024 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.md                                               !
!=======================================================================
!                                                                      !
!  Grid parameters:                                                    !
!                                                                      !
!  Im         Number of global grid points in the XI-direction         !
!               for each nested grid.                                  !
!  Jm         Number of global grid points in the ETA-direction        !
!               for each nested grid.                                  !
!  Lm         Number of interior grid points in the XI-direction       !
!               for each nested grid.                                  !
!  Mm         Number of internal grid points in the ETA-direction.     !
!               for each nested grid.                                  !
!  N          Number of vertical levels for each nested grid.          !
!  Ngrids     Number of nested and/or connected grids to solve.        !
!  NtileI     Number of XI-direction tiles or domain partitions for    !
!               each nested grid. Values used to compute tile ranges.  !
!  NtileJ     Number of ETA-direction tiles or domain partitions for   !
!               each nested grid. Values used to compute tile ranges.  !
!  NtileX     Number of XI-direction tiles or domain partitions for    !
!               each nested grid. Values used in parallel loops.       !
!  NtileE     Number of ETA-direction tiles or domain partitions for   !
!               each nested grid. Values used in parallel loops.       !
!  HaloBry    Buffers halo size for exchanging boundary arrays.        !
!  HaloSizeI  Maximum halo size, in grid points, in XI-direction.      !
!  HaloSizeJ  Maximum halo size, in grid points, in ETA-direction.     !
!  TileSide   Maximun tile side length in XI- or ETA-directions.       !
!  TileSize   Maximum tile size.                                       !
!                                                                      !
!  Configuration parameters:                                           !
!                                                                      !
!  Nbico      Number of balanced SSH elliptic equation iterations.     !
!  Nfloats    Number of floats trajectories.                           !
!  Nstation   Number of output stations.                               !
!  MTC        Maximum number of tidal components.                      !
!                                                                      !
!  State variables parameters:                                         !
!                                                                      !
!  NSA        Number of state array for error covariance.              !
!  NSV        Number of model state variables.                         !
!                                                                      !
!  Tracer parameters:                                                  !
!                                                                      !
!  NAT        Number of active tracer type variables (usually,         !
!               NAT=2 for potential temperature and salinity).         !
!  NBT        Number of biological tracer type variables.              !
!  NST        Number of sediment tracer type variables (NCS+NNS).      !
!  NPT        Number of extra passive tracer type variables to         !
!               advect and diffuse only (dyes, etc).                   !
!  MT         Maximum number of tracer type variables.                 !
!  NT         Total number of tracer type variables.                   !
!  NTCLM      Total number of climatology tracer type variables to     !
!               process.                                               !
!                                                                      !
!  Nbed       Number of sediment bed layers.                           !
!  NCS        Number of cohesive (mud) sediment tracers.               !
!  NNS        Number of non-cohesive (sand) sediment tracers.          !
!                                                                      !
!  Diagnostic fields parameters:                                       !
!                                                                      !
!  NDbio2d    Number of diagnostic 2D biology fields.                  !
!  NDbio3d    Number of diagnostic 3D biology fields.                  !
!  NDbio4d    Number of diagnostic 4D bio-optical fields.              !
!  NDT        Number of diagnostic tracer fields.                      !
!  NDM2d      Number of diagnostic 2D momentum fields.                 !
!  NDM3d      Number of diagnostic 3D momentum fields.                 !
!  NDrhs      Number of diagnostic 3D right-hand-side fields.          !
!                                                                      !
!  Estimated Dynamic and automatic memory parameters:                  !
!                                                                      !
!  BmemMax    Maximum automatic memory for distributed-memory buffers  !
!               (bytes).                                               !
!  Dmem       Dynamic memory requirements (array elements)             !
!                                                                      !
!=======================================================================
!
      USE mod_kinds
!
      implicit none
!
      PUBLIC :: allocate_param
      PUBLIC :: deallocate_param
      PUBLIC :: initialize_param
!
!-----------------------------------------------------------------------
!  Grid nesting parameters.
!-----------------------------------------------------------------------
!
!  Number of nested and/or connected grids to solve.
!
      integer :: Ngrids
!
!  Number of grid nesting layers. This parameter allows refinement and
!  composite grid combinations.
!
      integer :: NestLayers = 1
!
!  Number of grids in each nested layer.
!
      integer, allocatable :: GridsInLayer(:)   ! [NestLayers]
!
!  Application grid number as a function of the maximum number of grids
!  in each nested layer and number of nested layers.
!
      integer, allocatable :: GridNumber(:,:)   ! [Ngrids,NestLayers]
!
!  Maximum automatic memory (bytes) required in distributed-memory
!  buffers due to parallel exchanges.
!
      real(r8), allocatable :: BmemMax(:)       ! [Ngrids]
!
!  Estimated dynamic memory requirement (number of array elements) for
!  a particular application per nested grid.
!
      real(r8), allocatable :: Dmem(:)          ! [Ngrids]
!
!-----------------------------------------------------------------------
!  Lower and upper bounds indices per domain partition for all grids.
!-----------------------------------------------------------------------
!
!  Notice that these indices have different values in periodic and
!  nesting applications, and on tiles next to the boundaries. Special
!  indices are required to process overlap regions (suffices P and T)
!  lateral boundary conditions (suffices B and M) in nested grid
!  applications. The halo indices are used in private computations
!  which include ghost-points and are limited by MAX/MIN functions
!  on the tiles next to the  model boundaries. For more information
!  about all these indices, see routine "var_bounds" in file
!  "Utility/get_bounds.F".
!
!  All the 1D array indices are of size -1:NtileI(ng)*NtileJ(ng)-1. The
!  -1 index include the values for the full (no partitions) grid.
!
!  Notice that the starting (Imin, Jmin) and ending (Imax, Jmax) indices
!  for I/O processing are 3D arrays. The first dimension (1:4) is for
!  1=PSI, 2=RHO, 3=u, 4=v points; the second dimension (0:1) is number
!  of ghost points (0: no ghost points, 1: Nghost points), and the
!  the third dimension is for 0:NtileI(ng)*NtileJ(ng)-1.
!
      TYPE T_BOUNDS
        integer, pointer :: tile(:)  ! tile partition
        integer, pointer :: LBi(:)   ! lower bound I-dimension
        integer, pointer :: UBi(:)   ! upper bound I-dimension
        integer, pointer :: LBj(:)   ! lower bound J-dimension
        integer, pointer :: UBj(:)   ! upper bound J-dimension
        integer :: LBij              ! lower bound MIN(I,J)-dimension
        integer :: UBij              ! upper bound MAX(I,J)-dimension
        integer :: edge(4,4)         ! boundary edges I- or J-indices
        integer, pointer :: Istr(:)  ! starting tile I-direction
        integer, pointer :: Iend(:)  ! ending   tile I-direction
        integer, pointer :: Jstr(:)  ! starting tile J-direction
        integer, pointer :: Jend(:)  ! ending   tile J-direction
        integer, pointer :: IstrR(:) ! starting tile I-direction (RHO)
        integer, pointer :: IendR(:) ! ending   tile I-direction (RHO)
        integer, pointer :: IstrU(:) ! starting tile I-direction (U)
        integer, pointer :: JstrR(:) ! starting tile J-direction (RHO)
        integer, pointer :: JendR(:) ! ending   tile J-direction (RHO)
        integer, pointer :: JstrV(:) ! starting tile J-direction (V)
        integer, pointer :: IstrB(:) ! starting obc I-direction (RHO,V)
        integer, pointer :: IendB(:) ! ending   obc I-direction (RHO,V)
        integer, pointer :: IstrM(:) ! starting obc I-direction (PSI,U)
        integer, pointer :: JstrB(:) ! starting obc J-direction (RHO,U)
        integer, pointer :: JendB(:) ! ending   obc J-direction (RHO,U)
        integer, pointer :: JstrM(:) ! starting obc J-direction (PSI,V)
        integer, pointer :: IstrP(:) ! starting nest I-direction (PSI,U)
        integer, pointer :: IendP(:) ! ending   nest I-direction (PSI)
        integer, pointer :: JstrP(:) ! starting nest J-direction (PSI,V)
        integer, pointer :: JendP(:) ! ending   nest J-direction (PSI)
        integer, pointer :: IstrT(:) ! starting nest I-direction (RHO)
        integer, pointer :: IendT(:) ! ending   nest I-direction (RHO)
        integer, pointer :: JstrT(:) ! starting nest J-direction (RHO)
        integer, pointer :: JendT(:) ! ending   nest J-direction (RHO)
        integer, pointer :: Istrm3(:)    ! starting I-halo, Istr-3
        integer, pointer :: Istrm2(:)    ! starting I-halo, Istr-2
        integer, pointer :: Istrm1(:)    ! starting I-halo, Istr-1
        integer, pointer :: IstrUm2(:)   ! starting I-halo, IstrU-2
        integer, pointer :: IstrUm1(:)   ! starting I-halo, IstrU-1
        integer, pointer :: Iendp1(:)    ! ending   I-halo, Iend+1
        integer, pointer :: Iendp2(:)    ! ending   I-halo, Iend+2
        integer, pointer :: Iendp2i(:)   ! ending   I-halo, Iend+2
        integer, pointer :: Iendp3(:)    ! ending   I-halo, Iend+3
        integer, pointer :: Jstrm3(:)    ! starting J-halo, Jstr-3
        integer, pointer :: Jstrm2(:)    ! starting J-halo, Jstr-2
        integer, pointer :: Jstrm1(:)    ! starting J-halo, Jstr-1
        integer, pointer :: JstrVm2(:)   ! starting J-halo, JstrV-2
        integer, pointer :: JstrVm1(:)   ! starting J-halo, JstrV-1
        integer, pointer :: Jendp1(:)    ! ending   J-halo, Jend+1
        integer, pointer :: Jendp2(:)    ! ending   J-halo, Jend+2
        integer, pointer :: Jendp2i(:)   ! ending   J-halo, Jend+2
        integer, pointer :: Jendp3(:)    ! ending   J-halo, Jend+3
        integer, pointer :: Imin(:,:,:)  ! starting ghost I-direction
        integer, pointer :: Imax(:,:,:)  ! ending   ghost I-direction
        integer, pointer :: Jmin(:,:,:)  ! starting ghost J-direction
        integer, pointer :: Jmax(:,:,:)  ! ending   ghost J-direction
      END TYPE T_BOUNDS
      TYPE (T_BOUNDS), allocatable :: BOUNDS(:)
!
!-----------------------------------------------------------------------
!  Lower and upper bounds in NetCDF files.
!-----------------------------------------------------------------------
!
      TYPE T_IOBOUNDS
        integer :: ILB_psi       ! I-direction lower bound (PSI)
        integer :: IUB_psi       ! I-direction upper bound (PSI)
        integer :: JLB_psi       ! J-direction lower bound (PSI)
        integer :: JUB_psi       ! J-direction upper bound (PSI)
        integer :: ILB_rho       ! I-direction lower bound (RHO)
        integer :: IUB_rho       ! I-direction upper bound (RHO)
        integer :: JLB_rho       ! J-direction lower bound (RHO)
        integer :: JUB_rho       ! J-direction upper bound (RHO)
        integer :: ILB_u         ! I-direction lower bound (U)
        integer :: IUB_u         ! I-direction upper bound (U)
        integer :: JLB_u         ! J-direction lower bound (U)
        integer :: JUB_u         ! J-direction upper bound (U)
        integer :: ILB_v         ! I-direction lower bound (V)
        integer :: IUB_v         ! I-direction upper bound (V)
        integer :: JLB_v         ! J-direction lower bound (V)
        integer :: JUB_v         ! J-direction upper bound (V)
        integer :: IorJ          ! number of MAX(I,J)-direction points
        integer :: xi_psi        ! number of I-direction points (PSI)
        integer :: xi_rho        ! number of I-direction points (RHO)
        integer :: xi_u          ! number of I-direction points (U)
        integer :: xi_v          ! number of I-direction points (V)
        integer :: eta_psi       ! number of J-direction points (PSI)
        integer :: eta_rho       ! number of J-direction points (RHO)
        integer :: eta_u         ! number of I-direction points (U)
        integer :: eta_v         ! number of I-direction points (V)
      END TYPE T_IOBOUNDS
      TYPE (T_IOBOUNDS), allocatable :: IOBOUNDS(:)
!
!-----------------------------------------------------------------------
!  Domain boundary edges switches and tiles minimum and maximum
!  fractional grid coordinates.
!-----------------------------------------------------------------------
!
      TYPE T_DOMAIN
        logical, pointer :: Eastern_Edge(:)
        logical, pointer :: Western_Edge(:)
        logical, pointer :: Northern_Edge(:)
        logical, pointer :: Southern_Edge(:)
        logical, pointer :: NorthEast_Corner(:)
        logical, pointer :: NorthWest_Corner(:)
        logical, pointer :: SouthEast_Corner(:)
        logical, pointer :: SouthWest_Corner(:)
        logical, pointer :: NorthEast_Test(:)
        logical, pointer :: NorthWest_Test(:)
        logical, pointer :: SouthEast_Test(:)
        logical, pointer :: SouthWest_Test(:)
        real(r8), pointer :: Xmin_psi(:)
        real(r8), pointer :: Xmax_psi(:)
        real(r8), pointer :: Ymin_psi(:)
        real(r8), pointer :: Ymax_psi(:)
        real(r8), pointer :: Xmin_rho(:)
        real(r8), pointer :: Xmax_rho(:)
        real(r8), pointer :: Ymin_rho(:)
        real(r8), pointer :: Ymax_rho(:)
        real(r8), pointer :: Xmin_u(:)
        real(r8), pointer :: Xmax_u(:)
        real(r8), pointer :: Ymin_u(:)
        real(r8), pointer :: Ymax_u(:)
        real(r8), pointer :: Xmin_v(:)
        real(r8), pointer :: Xmax_v(:)
        real(r8), pointer :: Ymin_v(:)
        real(r8), pointer :: Ymax_v(:)
      END TYPE T_DOMAIN
      TYPE (T_DOMAIN), allocatable :: DOMAIN(:)
!
!-----------------------------------------------------------------------
!  Lateral Boundary Conditions (LBC) switches structure.
!-----------------------------------------------------------------------
!
!  The lateral boundary conditions are specified by logical switches
!  to facilitate applications with nested grids. It also allows to
!  set different boundary conditions between the nonlinear model and
!  the adjoint/tangent models. The LBC structure is allocated as:
!
!       LBC(1:4, nLBCvar, Ngrids)
!
!  where 1:4 are the number boundary edges, nLBCvar are the number
!  LBC state variables, and Ngrids is the number of nested grids.
!  For example, for free-surface gradient boundary conditions we
!  have:
!
!       LBC(iwest,  isFsur, ng) % gradient
!       LBC(ieast,  isFsur, ng) % gradient
!       LBC(isouth, isFsur, ng) % gradient
!       LBC(inorth, isFsur, ng) % gradient
!
      integer :: nLBCvar
!
      TYPE T_LBC
        logical :: acquire        ! process lateral boundary data
        logical :: Chapman_explicit
        logical :: Chapman_implicit
        logical :: clamped
        logical :: closed
        logical :: Flather
        logical :: gradient
        logical :: mixed
        logical :: nested
        logical :: nudging
        logical :: periodic
        logical :: radiation
        logical :: reduced
        logical :: Shchepetkin
      END TYPE T_LBC
      TYPE (T_LBC), allocatable :: LBC(:,:,:)
!
!-----------------------------------------------------------------------
!  Tracer horizontal and vertical advection switches structure.
!-----------------------------------------------------------------------
!
!  A different advection scheme is allowed for each tracer.  For
!  example, a positive-definite algorithm can be activated for salinity,
!  biological, and sediment tracers, while a different one is set for
!  temperature.
!
      TYPE T_ADV
        logical :: AKIMA4         ! fourth-order Akima
        logical :: CENTERED2      ! second-order centered differences
        logical :: CENTERED4      ! fourth-order centered differences
        logical :: HSIMT          ! third-order HSIMT-TVD
        logical :: MPDATA         ! recursive flux corrected MPDATA
        logical :: SPLINES        ! parabolic splines (vertical only)
        logical :: SPLIT_U3       ! split third-order upstream
        logical :: UPSTREAM3      ! third-order upstream bias
      END TYPE T_ADV
      TYPE (T_ADV), allocatable :: Hadvection(:,:)       ! horizontal
      TYPE (T_ADV), allocatable :: Vadvection(:,:)       ! vertical
!
!-----------------------------------------------------------------------
!  Field statistics STATS structure.
!-----------------------------------------------------------------------
!
      TYPE T_STATS
        integer(i8b) :: checksum  ! bit sum hash
        integer      :: count     ! processed values count
        real(r8) :: min           ! minimum value
        real(r8) :: max           ! maximum value
        real(r8) :: avg           ! arithmetic mean
        real(r8) :: rms           ! root mean square
      END TYPE T_STATS
!
!-----------------------------------------------------------------------
!  Model grid(s) parameters.
!-----------------------------------------------------------------------
!
!  Number of interior RHO-points in the XI- and ETA-directions. The
!  size of models state variables (C-grid) at input and output are:
!
!    RH0-type variables:  [0:Lm+1, 0:Mm+1]        ----v(i,j+1)----
!    PSI-type variables:  [1:Lm+1, 1:Mm+1]        |              |
!      U-type variables:  [1:Lm+1, 0:Mm+1]     u(i,j)  r(i,j)  u(i+1,j)
!      V-type variables:  [0:Lm+1, 1:Mm+1]        |              |
!                                                 -----v(i,j)-----
      integer, allocatable :: Lm(:)
      integer, allocatable :: Mm(:)
!
!  Global horizontal size of model arrays including padding.  All the
!  model state arrays are of same size to facilitate parallelization.
!
      integer, allocatable :: Im(:)
      integer, allocatable :: Jm(:)
!
!  Number of vertical levels. The vertical ranges of model state
!  variables are:
!                                                 -----W(i,j,k)-----
!    RHO-, U-, V-type variables: [1:N]            |                |
!              W-type variables: [0:N]            |    r(i,j,k)    |
!                                                 |                |
!                                                 ----W(i,j,k-1)----
      integer, allocatable :: N(:)
!
!-----------------------------------------------------------------------
!  Tracers parameters.
!-----------------------------------------------------------------------
!
!  Total number of tracer type variables, NT(:) = NAT + NBT + NPT + NST.
!  The MT corresponds to the maximum number of tracers between all
!  nested grids.
!
      integer, allocatable :: NT(:)
      integer :: MT
!
!  Total number of climatology tracer type variables to process.
!
      integer, allocatable :: NTCLM(:)
!
!  Number of active tracers. Usually, NAT=2 for potential temperature
!  and salinity.
!
      integer :: NAT = 0
!
!  Total number of inert passive tracers to advect and diffuse only
!  (like dyes, etc). This parameter is independent of the number of
!  biological and/or sediment tracers.
!
      integer :: NPT = 0
!
!  Number of biological tracers.
!
      integer :: NBT = 0
!
!-----------------------------------------------------------------------
!  Sediment tracers parameters.
!-----------------------------------------------------------------------
!
!  Number of sediment bed layes.
!
      integer :: Nbed = 0
!
!  Total number of sediment tracers, NST = NCS + NNS.
!
      integer :: NST = 0
!
!  Number of cohesive (mud) sediments.
!
      integer :: NCS = 0
!
!  Number of non-cohesive (sand) sediments.
!
      integer :: NNS = 0
!
!-----------------------------------------------------------------------
!  Maximum number of tidal constituents to process.
!-----------------------------------------------------------------------
!
      integer :: MTC
!
!-----------------------------------------------------------------------
!  Diagnostic fields parameters.
!-----------------------------------------------------------------------
!
!  Number of diagnostic tracer fields.
!
      integer :: NDT
!
!  Number of diagnostic momentum fields.
!
      integer :: NDM2d                  ! 2D momentum
      integer :: NDM3d                  ! 3D momentum
!
!  Number of diagnostic biology/bio-optical fields.  Currently, only
!  available for the Fennel and EcoSim models.
!
      integer :: NDbio2d                ! 2D fields
      integer :: NDbio3d                ! 3D fields
      integer :: NDbio4d                ! 4D fields
!
!  Number of diagnostic 3D right-hand-side fields.
!
      integer :: NDrhs
!
!-----------------------------------------------------------------------
!  Model state parameters.
!-----------------------------------------------------------------------
!
!  Number of model state variables.
!
      integer, allocatable :: NSV(:)
!
!  Set nonlinear, tangent linear, representer (finite-amplitude tangent
!  linear) and adjoint models identifiers.
!
      integer, parameter :: iNLM = 1   ! nonlinear
      integer, parameter :: iTLM = 2   ! perturbation tangent linear
      integer, parameter :: iRPM = 3   ! finite-amplitude tangent linear
      integer, parameter :: iADM = 4   ! adjoint
!
      character (len=3), dimension(4) :: KernelString =                 &
     &                                   (/ 'NLM','TLM','RPM','ADM' /)
!
!-----------------------------------------------------------------------
!  Domain partition parameters.
!-----------------------------------------------------------------------
!
!  Number of tiles or domain partitions in the XI- and ETA-directions.
!  These values are used to compute tile ranges [Istr:Iend, Jstr:Jend].
!
      integer, allocatable :: NtileI(:)
      integer, allocatable :: NtileJ(:)
!
!  Number of tiles or domain partitions in the XI- and ETA-directions.
!  These values are used to parallel loops to differentiate between
!  shared-memory and distributed-memory.  Notice that in distributed
!  memory both values are set to one.
!
      integer, allocatable :: NtileX(:)
      integer, allocatable :: NtileE(:)
!
!  Maximun number of points in the halo region for exchanging state
!  boundary arrays during convolutions.
!
      integer, allocatable :: HaloBry(:)
!
!  Maximum number of points in the halo region in the XI- and
!  ETA-directions.
!
      integer, allocatable :: HaloSizeI(:)
      integer, allocatable :: HaloSizeJ(:)
!
!  Maximum tile side length in XI- or ETA-directions.
!
      integer, allocatable :: TileSide(:)
!
!  Maximum number of points in a tile partition.
!
      integer, allocatable :: TileSize(:)
!
!  Set number of ghost-points in the halo region.  It is used in
!  periodic, nested, and distributed-memory applications.
!
      integer :: NghostPoints
!
!-----------------------------------------------------------------------
!  Staggered C-grid location identifiers.
!-----------------------------------------------------------------------
!
      integer, parameter :: p2dvar = 1         ! 2D PSI-variable
      integer, parameter :: r2dvar = 2         ! 2D RHO-variable
      integer, parameter :: u2dvar = 3         ! 2D U-variable
      integer, parameter :: v2dvar = 4         ! 2D V-variable
      integer, parameter :: p3dvar = 5         ! 3D PSI-variable
      integer, parameter :: r3dvar = 6         ! 3D RHO-variable
      integer, parameter :: u3dvar = 7         ! 3D U-variable
      integer, parameter :: v3dvar = 8         ! 3D V-variable
      integer, parameter :: w3dvar = 9         ! 3D W-variable
      integer, parameter :: b3dvar = 10        ! 3D BED-sediment
      integer, parameter :: l3dvar = 11        ! 3D spectral light
      integer, parameter :: l4dvar = 12        ! 4D spectral light
      integer, parameter :: r2dobc = 13        ! 2D OBC RHO-variable
      integer, parameter :: u2dobc = 14        ! 2D OBC U-variable
      integer, parameter :: v2dobc = 15        ! 2D OBC V-variable
      integer, parameter :: r3dobc = 16        ! 3D OBC RHO-variable
      integer, parameter :: u3dobc = 17        ! 3D OBC U-variable
      integer, parameter :: v3dobc = 18        ! 3D OBC V-variable
!
      CONTAINS
!
      SUBROUTINE allocate_param
!
!=======================================================================
!                                                                      !
!  This routine allocates several variables in the module that depend  !
!  on the number of nested grids.                                      !
!                                                                      !
!=======================================================================
!
!-----------------------------------------------------------------------
!  Allocate dimension parameters.
!-----------------------------------------------------------------------
!
      IF (.not.allocated(Lm)) THEN
        allocate ( Lm(Ngrids) )
      END IF
      IF (.not.allocated(Mm)) THEN
        allocate ( Mm(Ngrids) )
      END IF
      IF (.not.allocated(Im)) THEN
        allocate ( Im(Ngrids) )
      END IF
      IF (.not.allocated(Jm)) THEN
        allocate ( Jm(Ngrids) )
      END IF
      IF (.not.allocated(N)) THEN
        allocate ( N(Ngrids) )
      END IF
      IF (.not.allocated(NT)) THEN
        allocate ( NT(Ngrids) )
      END IF
      IF (.not.allocated(NTCLM)) THEN
        allocate ( NTCLM(Ngrids) )
      END IF
      IF (.not.allocated(NSV)) THEN
        allocate ( NSV(Ngrids) )
      END IF
      IF (.not.allocated(NtileI)) THEN
        allocate ( NtileI(Ngrids) )
      END IF
      IF (.not.allocated(NtileJ)) THEN
        allocate ( NtileJ(Ngrids) )
      END IF
      IF (.not.allocated(NtileX)) THEN
        allocate ( NtileX(Ngrids) )
      END IF
      IF (.not.allocated(NtileE)) THEN
        allocate ( NtileE(Ngrids) )
      END IF
      IF (.not.allocated(HaloBry)) THEN
        allocate ( HaloBry(Ngrids) )
      END IF
      IF (.not.allocated(HaloSizeI)) THEN
        allocate ( HaloSizeI(Ngrids) )
      END IF
      IF (.not.allocated(HaloSizeJ)) THEN
        allocate ( HaloSizeJ(Ngrids) )
      END IF
      IF (.not.allocated(TileSide)) THEN
        allocate ( TileSide(Ngrids) )
      END IF
      IF (.not.allocated(TileSize)) THEN
        allocate ( TileSize(Ngrids) )
      END IF
      IF (.not.allocated(BmemMax)) THEN
        allocate ( BmemMax(Ngrids) )
        BmemMax=0.0_r8
      END IF
      IF (.not.allocated(Dmem)) THEN
        allocate ( Dmem(Ngrids) )
        Dmem=0.0_r8
      END IF
!
      RETURN
      END SUBROUTINE allocate_param
!
      SUBROUTINE deallocate_param
!
!=======================================================================
!                                                                      !
!  This routine deallocates som of the variables in the module.        !
!  Notice that "destroy" cannot be use to deallocate the pointer       !
!  variables because of cyclic dependencies.                           !
!                                                                      !
!=======================================================================
!
!  Local variable declarations.
!
      integer :: ng
!
!-----------------------------------------------------------------------
!  Deallocate derived-type module structures:
!-----------------------------------------------------------------------
!
      IF (allocated(BOUNDS))        deallocate ( BOUNDS )
      IF (allocated(IOBOUNDS))      deallocate ( IOBOUNDS )
      IF (allocated(DOMAIN))        deallocate ( DOMAIN )
      IF (allocated(Hadvection))    deallocate ( Hadvection )
      IF (allocated(Vadvection))    deallocate ( Vadvection )
!
!-----------------------------------------------------------------------
!  Deallocate dimension parameters.
!-----------------------------------------------------------------------
!
      IF (allocated(Lm))           deallocate ( Lm )
      IF (allocated(Mm))           deallocate ( Mm )
      IF (allocated(Im))           deallocate ( Im )
      IF (allocated(Jm))           deallocate ( Jm )
      IF (allocated(N))            deallocate ( N )
      IF (allocated(NT))           deallocate ( NT )
      IF (allocated(NTCLM))        deallocate ( NTCLM )
      IF (allocated(NSV))          deallocate ( NSV )
      IF (allocated(NtileI))       deallocate ( NtileI )
      IF (allocated(NtileJ))       deallocate ( NtileJ )
      IF (allocated(NtileX))       deallocate ( NtileX )
      IF (allocated(NtileE))       deallocate ( NtileE )
      IF (allocated(HaloBry))      deallocate ( HaloBry )
      IF (allocated(HaloSizeI))    deallocate ( HaloSizeI )
      IF (allocated(HaloSizeJ))    deallocate ( HaloSizeJ )
      IF (allocated(TileSide))     deallocate ( TileSide )
      IF (allocated(TileSize))     deallocate ( TileSize )
      IF (allocated(BmemMax))      deallocate ( BmemMax )
      IF (allocated(Dmem))         deallocate ( Dmem )
      IF (allocated(GridsInLayer)) deallocate ( GridsInLayer )
      IF (allocated(GridNumber))   deallocate ( GridNumber )
!
      RETURN
      END SUBROUTINE deallocate_param
!
      SUBROUTINE initialize_param
!
!=======================================================================
!                                                                      !
!  This routine initializes several parameters in module "mod_param"   !
!  for all nested grids.                                               !
!                                                                      !
!=======================================================================
!
!  Local variable declarations
!
      integer :: I_padd, J_padd, Ntiles
      integer :: ibry, itrc, ivar, ng
!
!-----------------------------------------------------------------------
!  Now that we know the values for the tile partitions (NtileI,NtileJ),
!  allocate module structures.
!-----------------------------------------------------------------------
!
!  Allocate lower and upper bounds indices structure.
!
      IF (.not.allocated(BOUNDS)) THEN
        allocate ( BOUNDS(Ngrids) )
        DO ng=1,Ngrids
          Ntiles=NtileI(ng)*NtileJ(ng)-1
          allocate ( BOUNDS(ng) % tile(-1:Ntiles) )
          allocate ( BOUNDS(ng) % LBi(-1:Ntiles) )
          allocate ( BOUNDS(ng) % UBi(-1:Ntiles) )
          allocate ( BOUNDS(ng) % LBj(-1:Ntiles) )
          allocate ( BOUNDS(ng) % UBj(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Istr(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Iend(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jstr(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jend(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrR(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IendR(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrU(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrR(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JendR(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrV(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrB(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IendB(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrM(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrB(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JendB(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrM(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrP(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IendP(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrT(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IendT(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrP(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JendP(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrT(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JendT(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Istrm3(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Istrm2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Istrm1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrUm2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % IstrUm1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Iendp1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Iendp2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Iendp2i(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Iendp3(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jstrm3(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jstrm2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jstrm1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrVm2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % JstrVm1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jendp1(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jendp2(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jendp2i(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Jendp3(-1:Ntiles) )
          allocate ( BOUNDS(ng) % Imin(4,0:1,0:Ntiles) )
          allocate ( BOUNDS(ng) % Imax(4,0:1,0:Ntiles) )
          allocate ( BOUNDS(ng) % Jmin(4,0:1,0:Ntiles) )
          allocate ( BOUNDS(ng) % Jmax(4,0:1,0:Ntiles) )
        END DO
      END IF
!
!  DOMAIN structure containing boundary edges switches and fractional
!  grid lower/upper bounds for each tile.
!
      IF (.not.allocated(DOMAIN)) THEN
        allocate ( DOMAIN(Ngrids) )
        DO ng=1,Ngrids
          Ntiles=NtileI(ng)*NtileJ(ng)-1
          allocate ( DOMAIN(ng) % Eastern_Edge(-1:Ntiles) )
          allocate ( DOMAIN(ng) % Western_Edge(-1:Ntiles) )
          allocate ( DOMAIN(ng) % Northern_Edge(-1:Ntiles) )
          allocate ( DOMAIN(ng) % Southern_Edge(-1:Ntiles) )
          allocate ( DOMAIN(ng) % NorthEast_Corner(-1:Ntiles) )
          allocate ( DOMAIN(ng) % NorthWest_Corner(-1:Ntiles) )
          allocate ( DOMAIN(ng) % SouthEast_Corner(-1:Ntiles) )
          allocate ( DOMAIN(ng) % SouthWest_Corner(-1:Ntiles) )
          allocate ( DOMAIN(ng) % NorthEast_Test(-1:Ntiles) )
          allocate ( DOMAIN(ng) % NorthWest_Test(-1:Ntiles) )
          allocate ( DOMAIN(ng) % SouthEast_Test(-1:Ntiles) )
          allocate ( DOMAIN(ng) % SouthWest_Test(-1:Ntiles) )
          allocate ( DOMAIN(ng) % Xmin_psi(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmax_psi(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymin_psi(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymax_psi(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmin_rho(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmax_rho(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymin_rho(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymax_rho(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmin_u(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmax_u(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymin_u(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymax_u(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmin_v(0:Ntiles) )
          allocate ( DOMAIN(ng) % Xmax_v(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymin_v(0:Ntiles) )
          allocate ( DOMAIN(ng) % Ymax_v(0:Ntiles) )
        END DO
      END IF
!
!  Allocate lower and upper bounds structure for I/O NetCDF files.
!
      IF (.not.allocated(IOBOUNDS)) THEN
        allocate ( IOBOUNDS(Ngrids) )
      END IF
!
!-----------------------------------------------------------------------
!  Determine number of diagnostic variables.
!-----------------------------------------------------------------------
!
!  Tracer diagnostics.
!
      NDT=6          ! Acceleration, advection, vertical diffusion
      NDT=NDT+3      ! Horizontal (total, X-, Y-) diffusion
      NDT=NDT+1      ! Horizontal S-diffusion due to rotated tensor
!
!  2D Momentum diagnostics.
!
      NDM2d=4        ! Acceleration, 2D P-Gradient, stresses
      NDM2d=NDM2d+3  ! Horizontal total-, X-, and Y-advection
      NDM2d=NDM2d+1  ! Coriolis
      NDM2d=NDM2d+3  ! Horizontal total-, X-, and Y-viscosity
!
!  3D Momentum diagnostics and right-hand-side terms.
!
      NDM3d=3        ! Acceleration, 3D P-Gradient, vertical viscosity
      NDrhs=1        ! 3D P-Gradient
      NDM3d=NDM3d+4  ! Horizontal (total, X, Y) and vertical advection
      NDrhs=NDrhs+4
      NDM3d=NDM3d+1  ! Coriolis
      NDrhs=NDrhs+1
      NDM3d=NDM3d+3  ! Horizontal (total, X, Y) viscosity
!
!-----------------------------------------------------------------------
!  Derived dimension parameters.
!-----------------------------------------------------------------------
!
      DO ng=1,Ngrids
        I_padd=(Lm(ng)+2)/2-(Lm(ng)+1)/2
        J_padd=(Mm(ng)+2)/2-(Mm(ng)+1)/2
        Im(ng)=Lm(ng)+I_padd
        Jm(ng)=Mm(ng)+J_padd
        NT(ng)=NAT+NBT+NST+NPT
!
!  Number of state variables. The order is irrelevant for determining
!  the "NSV" dimension.
!
        NSV(ng)=5+NT(ng)         ! zeta, ubar, vbar, u, v, Tvar(1:MT)
        NSV(ng)=NSV(ng)+1        ! W
      END DO
!
!  Set the maximum number of tracers between all nested grids. It cannot
!  be zero. Usually, NAT=2 (temperature and salinity), but some Test
!  Cases do not include salinity.
!
      MT=MAX(1,MAX(NAT,MAXVAL(NT)))
!
!-----------------------------------------------------------------------
!  Allocate Lateral Boundary Conditions switches structure.
!-----------------------------------------------------------------------
!
!  Here, "nLBCvar" is larger than needed because it includes unused
!  state variables that need to be included because of their indices
!  are in a particular order due to data assimilation variables
!  associated with the state vector.
!
      nLBCvar=5+MT                 ! zeta, ubar, vbar, u, v, Tvar(1:MT)
!
      IF (.not.allocated(LBC)) THEN
        allocate ( LBC(4,nLBCvar,Ngrids) )
        DO ng=1,Ngrids
          DO ivar=1,nLBCvar
            DO ibry=1,4
              LBC(ibry,ivar,ng)%acquire = .FALSE.
              LBC(ibry,ivar,ng)%Chapman_explicit = .FALSE.
              LBC(ibry,ivar,ng)%Chapman_implicit = .FALSE.
              LBC(ibry,ivar,ng)%clamped = .FALSE.
              LBC(ibry,ivar,ng)%closed = .FALSE.
              LBC(ibry,ivar,ng)%Flather = .FALSE.
              LBC(ibry,ivar,ng)%gradient = .FALSE.
              LBC(ibry,ivar,ng)%mixed = .FALSE.
              LBC(ibry,ivar,ng)%nested = .FALSE.
              LBC(ibry,ivar,ng)%nudging = .FALSE.
              LBC(ibry,ivar,ng)%periodic = .FALSE.
              LBC(ibry,ivar,ng)%radiation = .FALSE.
              LBC(ibry,ivar,ng)%reduced = .FALSE.
              LBC(ibry,ivar,ng)%Shchepetkin = .FALSE.
            END DO
          END DO
        END DO
      END IF
!
!-----------------------------------------------------------------------
!  Allocate rracer horizontal and vertical advection switches structure.
!-----------------------------------------------------------------------
!
!  Nonlinear model kernel.
!
      IF (.not.allocated(Hadvection)) THEN
        allocate ( Hadvection(MAXVAL(NT),Ngrids) )
        DO ng=1,Ngrids
          DO itrc=1,NT(ng)
            Hadvection(itrc,ng)%AKIMA4 = .FALSE.
            Hadvection(itrc,ng)%CENTERED2 = .FALSE.
            Hadvection(itrc,ng)%CENTERED4 = .FALSE.
            Hadvection(itrc,ng)%HSIMT = .FALSE.
            Hadvection(itrc,ng)%MPDATA = .FALSE.
            Hadvection(itrc,ng)%SPLINES = .FALSE.
            Hadvection(itrc,ng)%SPLIT_U3 = .FALSE.
            Hadvection(itrc,ng)%UPSTREAM3 = .FALSE.
          END DO
        END DO
      END IF
!
      IF (.not.allocated(Vadvection)) THEN
        allocate ( Vadvection(MAXVAL(NT),Ngrids) )
        DO ng=1,Ngrids
          DO itrc=1,NT(ng)
            Vadvection(itrc,ng)%AKIMA4 = .FALSE.
            Vadvection(itrc,ng)%CENTERED2 = .FALSE.
            Vadvection(itrc,ng)%CENTERED4 = .FALSE.
            Vadvection(itrc,ng)%HSIMT = .FALSE.
            Vadvection(itrc,ng)%MPDATA = .FALSE.
            Vadvection(itrc,ng)%SPLINES = .FALSE.
            Vadvection(itrc,ng)%SPLIT_U3 = .FALSE.
            Vadvection(itrc,ng)%UPSTREAM3 = .FALSE.
          END DO
        END DO
      END IF
!
      RETURN
      END SUBROUTINE initialize_param
      END MODULE mod_param
