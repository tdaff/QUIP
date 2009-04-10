!% This module contains the 'CrackParams' type which holds all parameters
!% for a fracture simulation. These parameters are used by both 'makecrack'
!% and 'crack'. The module also contains code to read parameters from
!% and XML file.
!%
!% The 'CrackParams' type contains all simulation parameters for a fracture simulation.
!% It is initialised from the '<crack_params>' stanza of an XML file, which
!% should contain some or all of the following tags:
!% \begin{enumerate}
!%   \item '<crack>' --- parameters used exclusively by 'makecrack' which
!%      define the geometry and structure of the simulation cell.
!%   \item 'simulation' --- high level parameters which define the task to be performed
!%      by the 'crack' program.
!%   \item 'md' --- parameters related to molecular dynamics, used when
!%      'simulation_task = md'.
!%   \item 'minim' --- parameters related to geometry optimsation, used when
!%      'simulation_task = minim'
!%   \item 'io' -- Input/output parameters
!%   \item 'selection' --- parameters that effect the choice of QM region
!%   \item 'classical' --- parameters that define which classical potential to use
!%   \item 'qm' --- parameters concerned with QM force evaluation, including which
!%       potential to use.
!%   \item 'fit' -- parameters relating to the adjustable potential used to reproduce
!%       quantum mechanical forces
!%   \item 'force_intergration' --- parameters for the force integration task, used
!%       when 'simulation_task = force_integration'.
!%   \item 'quasi_static' --- parameters for the quasi-static loading task, used
!%       when 'simulation_task = quasi_static'. 
!%   \item 'hack ' -- finally, nasty hacks required for some crack systems, for
!%      example it is necessary to zero the $z$-component of the QM forces to
!%      get a well behaved simulation of the fracture of two-dimensional graphene.
!% \end{enumerate}
!% Note that tag and attribute names are mapped into variable names by joining
!% them with an underscore: for example the 'task' attribute within  the 'simulation'
!% tag becomes the 'simulation_task' variables.
!% See below for a brief description of each parameter.
!% 
!% Here is a complete example of the '<crack_params>' XML stanza for a MD run
!% using the Bowler tight binding model in the QM region and the standard 
!% Stillinger-Weber potential for the classical region. 
!%
!%><crack_params>
!%>  <crack structure="diamond" element="Si" lattice_guess="5.44" 
!%>    name="(111)[11b0]" width="200.0" height="100.0" 
!%>    num_layers="1" G="1.0" seed_length="50.0"
!%>    strain_zone_width="50.0" vacuum_size="50.0"
!%>    hydrogenate="T" rescale_x_z="F" rescale_x="F" nerate_load="F" initial_loading_strain="0.005" />
!%>
!%>  <simulation task="md" seed="0" restart="0" classical="F" />
!%>
!%>  <md time_step="1.0" sim_temp="300.0" avg_time="50.0"
!%>     thermalise_tau="50.0" thermalise_wait_time="400.0" tau="500.0"
!%>     wait_time="500.0" interval_time="100.0"
!%>     extrapolate_steps="5" crust="2.0" />
!%>
!%>  <minim method="cg" tol="1e-3" eps_guess="0.01" max_steps="1000"
!%>     linminroutine="FAST_LINMIN" minimise_mm="F" />
!%>
!%>  <io verbosity="NORMAL" print_interval="10.0"
!%>    checkpoint_interval="100.0"  />
!%>
!%>  <selection max_qm_atoms="200" dynamic="T" ellipse="8.0 5.0 10.0"
!%>    ellipse_bias="0.5" ellipse_buffer="1.3" cutoff_plane="10.0" 
!%>    fit_on_eqm_coordination_only="F" />
!%>
!%>  <classical args="IP SW label=PRB_31_plus_H" reweight="1.0" />
!%>
!%>  <qm args="TB Bowler" small_clusters="F" terminate="T"
!%>    buffer_hops="3" vacuum_size="3.0" even_hydrogens="T"
!%>    randomise_buffer="T" force_periodic="F" />
!%> 
!%>  <fit hops="3" method="adj_pot_svd" />
!%></crack_params>
!%
!% Parameters for the classical and QM regions should be included in the same XML 
!% file, and all three stanzas should then be enclosed by some outer tags to make
!% a well formed XML file. For example this could be '<params>...</params>', 
!% but the choice of name is arbitrary.

module CrackParams_module

  use libAtoms_module
  use QUIP_module
  use QUIP_Common_module

  implicit none

  private

  integer, parameter :: MAX_PROPERTIES = 100

  public :: CrackParams

  !% This type contains all the parameters for a crack simulation, each of which is described briefly 
  !% below.
  type CrackParams

     ! Crack parameters (used only by makecrack)
     character(STRING_LENGTH) :: crack_structure !% Structure: so far 'diamond' and 'graphene' are supported
     character(STRING_LENGTH) :: crack_element !% Element to make slab from. Supported so far: Si, C and SiC
     character(STRING_LENGTH) :: crack_name !% Crack name, in format '(abc)[def]' with negative indices 
                                          !% denoted by a trailing 'b' (for bar), e.g. '(111)[11b0]'.
     real(dp) :: crack_lattice_guess      !% Guess at bulk lattice parameter, used to obtain accurate result. Unit:~\AA{}.
     real(dp) :: crack_width              !% Width of crack slab, in \AA{}.
     real(dp) :: crack_height             !% Height of crack slab, in \AA{}.
     integer  :: crack_num_layers         !% Number of primitive cells in $z$ direction
     real(dp) :: crack_G                  !% Initial energy release rate loading in J/m$^2$
     character(STRING_LENGTH) :: crack_loading !% 'unform' for constant load, 
                                               !% 'ramp' for linearly decreasing load along $x$, 
                                               !% 'kfield' for Irwin plane strain K-field,
                                               !% 'interp_kfield_uniform' to linearly interpolate between k-field 
                                               !% (at crack tip) and uniform at distance 'crack_load_interp_length'
     real(dp) :: crack_load_interp_length !% Length over which linear interpolation between k-field 
                                          !% and uniform strain field is carried out
     real(dp) :: crack_ramp_length        !% Length of ramp for the case 'crack_loading="ramp"'
     real(dp) :: crack_ramp_end_G         !% Loading at end of ramp for the case 'crack_loading="ramp"'
     real(dp) :: crack_initial_loading_strain        !% Rate of loading, expressed as strain of initial loading
     real(dp) :: crack_G_increment        !% Rate of loading, expressed as increment in G (override initial_loading_strain)
     real(dp) :: crack_seed_length        !% Length of seed crack. Unit:~\AA{}.
     real(dp) :: crack_strain_zone_width  !% Distance over which strain increases. Unit:~\AA{}.
     real(dp) :: crack_vacuum_size        !% Amount of vacuum around crack slab. Unit:~\AA{}.
     logical  :: crack_rescale_x_z        !% Rescale atomsatoms  in x direction by v and in z direction by v2 
     logical  :: crack_rescale_x          !% Rescale atomsatoms  in x direction by v 
     logical  :: crack_relax_loading_field      !% Should 'makecrack' relax the applied loading field
     real(dp) :: crack_edge_fix_tol       !% How close must an atom be to top or bottom to be fixed. Unit:~\AA{}.
     real(dp) :: crack_y_shift            !% Shift required to align y=0 with centre of a vertical bond. 
                                          !% This value is only used for unknown values of 'crack_name'. Unit:~\AA{}.
     real(dp) :: crack_seed_embed_tol     !% Atoms closer than this distance from crack tip will be used to seed embed region. Unit:~\AA{}.
     real(dp) :: crack_graphene_theta        !% Rotation angle of graphene plane, in radians.
     real(dp) :: crack_graphene_notch_width  !% Width of graphene notch. Unit:~\AA{}.
     real(dp) :: crack_graphene_notch_height !% Height of graphene notch. Unit:~\AA{}.
     character(STRING_LENGTH) :: crack_slab_filename !%Input file to use instead of generating slabs.
     
     ! Simulation parameters
     character(STRING_LENGTH) :: simulation_task !% Task to perform: 'md', 'minim', etc.
     integer  :: simulation_seed          !% Random number seed. Use zero for a random seed, or a particular value to repeat a previous run.
     logical  :: simulation_restart       !% Restart from checkfile containing velocites of all atoms.
     logical  :: simulation_classical     !% Perform a purely classical simulation
     logical  :: simulation_force_initial_load_step !% Force a load step at beginning of simulation

     ! Molecular dynamics parameters
     real(dp) :: md_time_step             !% Molecular Dynamics time-step, in fs.
     integer  :: md_extrapolate_steps     !% Number of steps to extrapolate for
     real(dp) :: md_crust                 !% Distance by which 'Atoms' cutoff should exceed that of MM potential, in \AA{}.
     real(dp) :: md_recalc_connect_factor !% Maximum atom movement as a fraction of 'md_crust' before connectivity is recalculated.
     real(dp) :: md_nneigh_tol            !% Nearest neighbour tolerance, as a fraction of sum of covalant radii.
     integer  :: md_eqm_coordination      !% Equilibrium coordination number of bulk (used for finding crack tip).
     real(dp) :: md_sim_temp              !% Target temperature for Langevin thermostat, in Kelvin.
     real(dp) :: md_avg_time              !% Averaging time for bonding/nearest neighbours etc. Unit:~fs.
     real(dp) :: md_thermalise_tau        !% Thermostat time constant during thermalisiation. Unit:~fs.
     real(dp) :: md_thermalise_wait_time  !% Minimium thermalisation time at each load before changing to (almost) microcanoical MD. Unit:~fs.
     real(dp) :: md_thermalise_wait_factor!% Factor controlling the thermalisation time at each load before changing to (almost) microcanonical MD     
     real(dp) :: md_tau                   !% Thermostat time constant during (almost) microcanonical MD. Unit:~fs.
     real(dp) :: md_wait_time             !% Minimum wait time between loadings. Unit:~fs.
     real(dp) :: md_interval_time         !% How long must there be no topological changes for before load is incremented. Unit:~fs.
     real(dp) :: md_calc_connect_interval !% How often should connectivity be recalculated?

     ! Minimisation parameters
     character(STRING_LENGTH) :: minim_method !% Minimisation method: use 'cg' for conjugate gradients or 'sd' for steepest descent. 
                                              !% See 'minim()' in 'libAtoms/minimisation.f95' for details.
     real(dp) :: minim_tol                !% Target force tolerance - geometry optimisation is considered to be 
                                          !% converged when $|\mathbf{f}|^2 <$ 'tol'
     real(dp) :: minim_eps_guess          !% Initial guess for line search step size $\epsilon$.
     integer  :: minim_max_steps          !% Maximum number of minimisation steps.
     character(STRING_LENGTH) :: minim_linminroutine !% Linmin routine, e.g. 'FAST_LINMIN' for classical potentials with total energy, or 
                                                     !% 'LINMIN_DERIV' when doing a LOTF hybrid simulation and only forces are available.
     logical :: minim_minimise_mm         !% Should we minimise classical degrees of freedom before each QM force evaluation
     character(STRING_LENGTH) :: minim_mm_method !% Minim method for MM minimisation, e.g. 'cg' for conjugate gradients
     real(dp) :: minim_mm_tol             !% Target force tolerance for MM minimisation
     real(dp) :: minim_mm_eps_guess       !% Initial guess for line search $\epsilon$ for MM minimisation
     integer  :: minim_mm_max_steps       !% Maximum number of cg cycles for MM minimisation
     character(STRING_LENGTH) :: minim_mm_linminroutine !% Linmin routine for MM minimisation
     character(STRING_LENGTH) :: minim_mm_args_str   !% Args string to be passed to MM calc() routine
     logical  :: minim_mm_use_n_minim     !% Whether or not to use n_minim for MM minimisation


     ! I/O parameters
     integer :: io_verbosity              !% Output verbosity. In XML file, this should be specified as one of
                                          !% 'ERROR', 'SILENT', 'NORMAL', 'VERBOSE', 'NERD' or 'ANAL'
     logical :: io_netcdf                 !% If true, output in NetCDF format instead of XYZ
     real(dp) :: io_print_interval        !% Interval between movie XYZ frames, in fs.
     logical  :: io_print_all_properties  !% If true, print all atom properties to movie file. This will generate large
                                          !% files but is useful for debugging.
     character(STRING_LENGTH), allocatable :: io_print_properties(:) !% List of properties to print to movie file.
     real(dp) :: io_checkpoint_interval   !% Interval between writing checkpoint files, in fs.
     character(STRING_LENGTH) :: io_checkpoint_path !% Path to write checkpoint files to. Set this to local scratch space to avoid doing 
                                                    !%lots of I/O to a network drive. Default is current directory.
     logical :: io_mpi_print_all !% Print output on all nodes. Useful for debugging. Default .false.

     ! Selection parameters
     integer  :: selection_max_qm_atoms   !% Maximum number of QM atoms to select
     logical  :: selection_dynamic        !% Should QM region be changed dynamically during simulation? If this is false, the 'hybrid'
                                          !% property will be read from input file and fixed for the entire simulation.
     real(dp) :: selection_ellipse(3)     !% Principal radii of selection ellipse along $x$, $y$ and $z$ in \AA{}.
     real(dp) :: selection_ellipse_bias   !% Shift applied to ellipses, expressed as fraction of ellipse radius in $x$ direction.
     real(dp) :: selection_ellipse_buffer !% Difference in size between inner and outer selection ellipses, i.e. amount of hysteresis.
     real(dp) :: selection_cutoff_plane   !% Only atoms within this distance from crack tip are candidates for QM selection. Unit: \AA{}.
     logical  :: selection_directionality !% Require good directionality of spring space spanning for atoms in embed region.
     real(dp) :: selection_edge_tol       !% Size of region at edges of crack slab which is ignored for selection purposes.

     ! Classical parameters
     character(STRING_LENGTH) :: classical_args !% Arguments used to initialise classical potential
     character(STRING_LENGTH) :: classical_args_str !% Arguments used by Calc Potential
     real(dp) :: classical_force_reweight !% Factor by which to reduce classical forces in the embed region. Default is unity.

     ! QM parameters
     character(STRING_LENGTH) :: qm_args  !% Arguments used to initialise QM potential
     character(STRING_LENGTH) :: qm_args_str  !% Arguments used by QM potential
     logical :: qm_small_clusters         !% One big cluster or lots of little ones?
     integer :: qm_buffer_hops            !% Number of bond hops used for buffer region
     logical :: qm_terminate              !% Terminate clusters with hydrogen atoms
     logical :: qm_force_periodic         !% Force clusters to be periodic in $z$ direction.
     logical :: qm_randomise_buffer       !% Randomise positions of outer layer of buffer atoms slightly to avoid systematic errors.
     logical :: qm_even_hydrogens         !% Discard a hydrogen if necessary to give an overall non-spin-polarised cluster 
                                          !% (i.e. one with an even number of hydrogen atoms).
     real(dp) :: qm_vacuum_size           !% Amount of vacuum surrounding cluster in non-periodic directions ($x$ and $y$ at least). Unit:~\AA{}.
     logical :: qm_calc_force_error       !% Do a full QM calculation at each stage in extrap and interp to measure force error
     logical :: qm_rescale_r              !% If true, rescale space in QM cluster to match QM lattice constant
     logical :: qm_hysteretic_buffer      !% If true, manage the buffer region hysteritcally
     real(dp) :: qm_hysteretic_buffer_inner_radius !% Inner radius used for hystertic buffer region
     real(dp) :: qm_hysteretic_buffer_outer_radius !% Outer radius used for hystertic buffer region

     ! Fit parameters
     integer :: fit_hops                  !% Number of hops used to generate fit region from embed region
     integer :: fit_spring_hops           !% Number of hops used when creating list of springs
     character(STRING_LENGTH) :: fit_method !% Method to use for force mixing: should be one of
     !% \begin{itemize}
     !%  \item 'lotf_adj_pot_svd' --- LOTF using SVD to optimised the Adj Pot
     !%  \item 'lotf_adj_pot_minim' --- LOTF using conjugate gradients to optimise the Adj Pot
     !%  \item 'lotf_adj_pot_sw' --- LOTF using old style SW Adj Pot
     !%  \item 'conserve_momentum' --- divide the total force on QM region over the fit atoms to conserve momentum 
     !%  \item 'force_mixing' --- force mixing with details depending on values of
     !%      'buffer_hops', 'transtion_hops' and 'weight_interpolation'
     !%  \item 'force_mixing_abrupt' --- simply use QM forces on QM atoms and MM forces on MM atoms 
     !%      (shorthand for 'method=force_mixing buffer_hops=0 transition_hops=0')
     !%  \item 'force_mixing_smooth' --- use QM forces in QM region, MM forces in MM region and 
     !%    linearly interpolate in buffer region  (shorthand for 'method=force_mixing weight_interpolation=hop_ramp')
     !%  \item 'force_mixing_super_smooth' --- as above, but weight forces on each atom by distance from 
     !%    centre of mass of core region (shorthand for 'method=force_mixing weight_interpolation=distance_ramp')
     !% \end{itemize}
     !% Default method is 'conserve_momentum'.

     ! Force intergration parameters
     character(STRING_LENGTH) :: force_integration_end_file  !% XYZ file containing ending configuration for force integration.
     integer  :: force_integration_n_steps !% Number of steps to take in force integration

     ! Quasi-static loading parameters
     real(dp) :: quasi_static_tip_move_tol !% How far cracktip must advance before we consider fracture to have occurred.

     ! Finally, nasty hacks
     logical :: hack_qm_zero_z_force       !% Zero $z$ component of all forces (used for graphene)
     logical  :: hack_fit_on_eqm_coordination_only !% Only include fit atoms that have coordination 
                                                   !% number equal to 'md_eqm_coordination' (used for graphene).

    
  end type CrackParams

  type(CrackParams), pointer :: parse_cp
  logical :: parse_in_crack

  public :: initialise
  interface initialise
     module procedure CrackParams_initialise 
  end interface

  public :: print
  interface print
     module procedure CrackParams_print
  end interface

  public :: read_xml
  interface read_xml
     module procedure CrackParams_read_xml
  end interface
  

contains
  
  !% Initialise this CrackParams structure and set default
  !% values for all parameters. WARNING: many of these defaults are
  !% only really appropriate for diamond structure silicon fracture.
  subroutine CrackParams_initialise(this)
    type(CrackParams), intent(inout) :: this
    
    ! Parameters for 'makecrack'
    this%crack_structure         = 'diamond'
    this%crack_element           = 'Si'
    this%crack_name              = '(111)[11b0]'
    this%crack_lattice_guess     = 5.43_dp  ! Angstrom, correct for Si
    this%crack_width             = 200.0_dp ! Angstrom
    this%crack_height            = 100.0_dp ! Angstrom
    this%crack_num_layers        = 1        ! number
    this%crack_G                 = 2.0_dp   ! J/m^2
    this%crack_loading           = 'uniform'
    this%crack_load_interp_length = 100.0_dp ! Angstrom
    this%crack_ramp_length       = 100.0_dp ! Angstrom
    this%crack_ramp_end_G        = 1.0_dp   ! J/m^2
    this%crack_initial_loading_strain       = 0.005_dp ! 0.5% per loading cycle
    this%crack_G_increment       = 0.0_dp   ! increment of G per loading cycle, override initial_loading_strain if present
    this%crack_seed_length       = 50.0_dp  ! Angstrom
    this%crack_strain_zone_width = 100.0_dp ! Angstrom
    this%crack_vacuum_size       = 100.0_dp ! Angstrom
    this%crack_relax_loading_field     = .true.
    this%crack_rescale_x_z       = .false. 
    this%crack_rescale_x         = .false. 
    this%crack_edge_fix_tol      = 2.7_dp   ! Angstrom
    this%crack_y_shift           = 0.0_dp   ! Angstrom
    this%crack_seed_embed_tol    = 3.0_dp   ! Angstrom

    ! Graphene specific crack parameters
    this%crack_graphene_theta        = 0.0_dp  ! Angle
    this%crack_graphene_notch_width  = 5.0_dp  ! Angstrom
    this%crack_graphene_notch_height = 5.0_dp  ! Angstrom
    this%crack_slab_filename = ''

    ! Basic simulation parameters
    this%simulation_task         = 'md'
    this%simulation_seed         = 0
    this%simulation_restart      = .false.
    this%simulation_classical    = .false.
    this%simulation_force_initial_load_step = .false.

    ! Molecular dynamics parameters
    this%md_time_step            = 1.0_dp   ! fs
    this%md_extrapolate_steps    = 10       ! number
    this%md_crust                = 2.0_dp   ! Angstrom
    this%md_recalc_connect_factor = 0.8_dp  ! fraction of md_crust
    this%md_nneigh_tol           = 1.3_dp   ! fraction of sum of covalent radii
    this%md_eqm_coordination     = 4
    this%md_sim_temp             = 300.0_dp ! Kelvin
    this%md_avg_time             = 50.0_dp  ! fs
    this%md_thermalise_tau       = 50.0_dp  ! fs
    this%md_thermalise_wait_time = 400.0_dp ! fs
    this%md_thermalise_wait_factor= 2.0_dp  ! number
    this%md_tau                  = 500.0_dp ! fs
    this%md_wait_time            = 500.0_dp ! fs
    this%md_interval_time        = 100.0_dp ! fs
    this%md_calc_connect_interval = 10.0_dp ! fs
    
    ! Minimisation parameters
    this%minim_method            = 'cg'
    this%minim_tol               = 1e-3_dp  ! norm2(force) eV/A
    this%minim_eps_guess         = 0.01_dp  ! Angstrom
    this%minim_max_steps         = 1000     ! number
    this%minim_linminroutine     = 'LINMIN_DERIV'
    this%minim_minimise_mm       = .false.
    this%minim_mm_method         = 'cg'
    this%minim_mm_tol            = 1e-6_dp  ! norm2(force) eV/A
    this%minim_mm_eps_guess      = 0.001_dp ! Angstrom
    this%minim_mm_max_steps      = 1000     ! number
    this%minim_mm_linminroutine  = 'FAST_LINMIN'
    this%minim_mm_args_str       = ''
    this%minim_mm_use_n_minim    = .false.

    ! I/O parameters
    this%io_verbosity            = NORMAL
    this%io_netcdf               = .false.
    this%io_print_interval       = 10.0_dp  ! fs
    this%io_print_all_properties = .false.
    if (allocated(this%io_print_properties)) deallocate(this%io_print_properties)
    allocate(this%io_print_properties(11))
    this%io_print_properties     = (/"species", "pos","hybrid","hybrid_mark","nn","changed_nn","old_nn", &
         "md_old_changed_nn","edge_mask","move_mask","load"/)
    this%io_checkpoint_interval  = 100.0_dp ! fs
    this%io_checkpoint_path      = ''
    this%io_mpi_print_all        = .false.

     ! Selection parameters
    this%selection_max_qm_atoms   = 200
    this%selection_dynamic        = .true.
    this%selection_ellipse        = (/8.0_dp, 5.0_dp, 10.0_dp /)  ! Angstrom
    this%selection_ellipse_bias   = 0.5_dp   ! Fraction of principal radius in x direction
    this%selection_ellipse_buffer = 1.3_dp   ! Angstrom
    this%selection_cutoff_plane   = 10.0_dp  ! Angstrom
    this%selection_directionality = .true.
    this%selection_edge_tol       = 10.0_dp  ! A


     ! Classical parameters
    this%classical_args           = 'IP SW' 
    this%classical_args_str       = ' ' 
    this%classical_force_reweight = 1.0_dp   ! Fraction

     ! QM parameters
    this%qm_args                  = 'FilePot ./castep_driver.py property_list=pos:embed'
    this%qm_args_str              = ' '
    this%qm_small_clusters        = .false.
    this%qm_buffer_hops           = 3        ! Number
    this%qm_terminate             = .true.
    this%qm_force_periodic        = .false.
    this%qm_randomise_buffer      = .true.
    this%qm_even_hydrogens        = .false.
    this%qm_vacuum_size           = 3.0_dp   ! Angstrom
    this%qm_calc_force_error      = .false.
    this%qm_rescale_r             = .false.
    this%qm_hysteretic_buffer     = .false.
    this%qm_hysteretic_buffer_inner_radius = 5.0_dp
    this%qm_hysteretic_buffer_outer_radius = 7.0_dp

    ! Fit parameters
    this%fit_hops                 = 3
    this%fit_spring_hops          = 3
    this%fit_method               = 'lotf_adj_pot_svd'

    ! Force integration parameters
    this%force_integration_end_file = ''  ! Filename
    this%force_integration_n_steps  = 10  ! number

    ! Quasi static loading 
    this%quasi_static_tip_move_tol  = 5.0_dp ! Angstrom

    ! Nasty hack
    this%hack_qm_zero_z_force        = .false.
    this%hack_fit_on_eqm_coordination_only = .false.


  end subroutine CrackParams_initialise


  !% Read crack parameters from 'xmlfile' into this CrackParams object.
  !% First we reset to default values by calling 'initialise(this)'.
  subroutine CrackParams_read_xml(this, xmlfile)
    type(CrackParams), intent(inout), target :: this
    type(Inoutput) :: xmlfile

    type (xml_t) :: fxml
    type(extendable_str) :: ss

    call initialise(this) ! Reset to defaults

    call Initialise(ss)
    call read(ss, xmlfile%unit, convert_to_string=.true.)

    if (len(trim(string(ss))) <= 0) return

    call open_xml_string(fxml, string(ss))

    parse_cp => this
    parse_in_crack = .false.

    call parse(fxml, &
         startElement_handler = CrackParams_startElement_handler, &
         endElement_handler = CrackParams_endElement_handler)

    call close_xml_t(fxml)

    call Finalise(ss)

  end subroutine CrackParams_read_xml

  !% OMIT
  subroutine CrackParams_startElement_handler(URI, localname, name, attributes)
    character(len=*), intent(in)   :: URI  
    character(len=*), intent(in)   :: localname
    character(len=*), intent(in)   :: name 
    type(dictionary_t), intent(in) :: attributes

    integer status
    character(len=1024) :: value

    logical             :: got_species
    integer             :: n_properties, i
    character(len=1024) :: tmp_properties(MAX_PROPERTIES)

    if (name == 'crack_params') then ! new crack_params stanza

       parse_in_crack = .true.

    elseif (parse_in_crack .and. name == 'crack') then

       call QUIP_FoX_get_value(attributes, "structure", value, status)
       if (status == 0) then
          parse_cp%crack_structure = value
       end if

       call QUIP_FoX_get_value(attributes, "element", value, status)
       if (status == 0) then
          parse_cp%crack_element = value
       end if

       call QUIP_FoX_get_value(attributes, "name", value, status)
       if (status == 0) then
          parse_cp%crack_name = value
       end if

       call QUIP_FoX_get_value(attributes, "lattice_guess", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_lattice_guess
       end if
       
       call QUIP_FoX_get_value(attributes, "width", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_width
       end if

       call QUIP_FoX_get_value(attributes, "height", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_height
       end if

       call QUIP_FoX_get_value(attributes, "num_layers", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_num_layers
       end if

       call QUIP_FoX_get_value(attributes, "G", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_G
       end if

       call QUIP_FoX_get_value(attributes, "loading", value, status)
       if (status == 0) then
          parse_cp%crack_loading = value
       end if

       call QUIP_FoX_get_value(attributes, "load_interp_length", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_load_interp_length
       end if

       call QUIP_FoX_get_value(attributes, "ramp_length", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_ramp_length
       end if

       call QUIP_FoX_get_value(attributes, "ramp_end_G", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_ramp_end_G
       end if

       call QUIP_FoX_get_value(attributes, "initial_loading_strain", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_initial_loading_strain
       end if

       call QUIP_FoX_get_value(attributes, "G_increment", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_G_increment
       end if

       call QUIP_FoX_get_value(attributes, "seed_length", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_seed_length
       end if

       call QUIP_FoX_get_value(attributes, "strain_zone_width", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_strain_zone_width
       end if

       call QUIP_FoX_get_value(attributes, "vacuum_size", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_vacuum_size
       end if

       call QUIP_FoX_get_value(attributes, "rescale_x_z", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_rescale_x_z
       end if

       call QUIP_FoX_get_value(attributes, "rescale_x", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_rescale_x
       end if

       call QUIP_FoX_get_value(attributes, "relax_loading_field", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_relax_loading_field
       end if

       call QUIP_FoX_get_value(attributes, "edge_fix_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_edge_fix_tol
       end if

       call QUIP_FoX_get_value(attributes, "y_shift", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_y_shift
       end if

       call QUIP_FoX_get_value(attributes, "seed_embed_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_seed_embed_tol
       end if

       call QUIP_FoX_get_value(attributes, "graphene_theta", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_graphene_theta
       end if

       call QUIP_FoX_get_value(attributes, "graphene_notch_width", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_graphene_notch_width
       end if

       call QUIP_FoX_get_value(attributes, "graphene_notch_height", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_graphene_notch_height
       end if

       call QUIP_FoX_get_value(attributes, "slab_filename", value, status)
       if (status == 0) then
          read (value, *) parse_cp%crack_slab_filename
       end if

    elseif (parse_in_crack .and. name == 'simulation') then

       call QUIP_FoX_get_value(attributes, "task", value, status)
       if (status == 0) then
          parse_cp%simulation_task = value
       end if

       call QUIP_FoX_get_value(attributes, "seed", value, status)
       if (status == 0) then
          read (value, *) parse_cp%simulation_seed
       end if

       call QUIP_FoX_get_value(attributes, "restart", value, status)
       if (status == 0) then
          read (value, *) parse_cp%simulation_restart
       end if

       call QUIP_FoX_get_value(attributes, "classical", value, status)
       if (status == 0) then
          read (value, *) parse_cp%simulation_classical
       end if

       call QUIP_FoX_get_value(attributes, "force_initial_load_step", value, status)
       if (status == 0) then
          read (value, *) parse_cp%simulation_force_initial_load_step
       end if

    elseif (parse_in_crack .and. name == 'md') then

       call QUIP_FoX_get_value(attributes, "time_step", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_time_step
       end if

       call QUIP_FoX_get_value(attributes, "sim_temp", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_sim_temp
       end if

       call QUIP_FoX_get_value(attributes, "extrapolate_steps", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_extrapolate_steps
       end if

       call QUIP_FoX_get_value(attributes, "crust", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_crust
       end if

       call QUIP_FoX_get_value(attributes, "recalc_connect_factor", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_recalc_connect_factor
       end if


       call QUIP_FoX_get_value(attributes, "nneigh_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_nneigh_tol
       end if

       call QUIP_FoX_get_value(attributes, "eqm_coordination", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_eqm_coordination
       end if

       call QUIP_FoX_get_value(attributes, "avg_time", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_avg_time
       end if

       call QUIP_FoX_get_value(attributes, "thermalise_tau", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_thermalise_tau
       end if

       call QUIP_FoX_get_value(attributes, "thermalise_wait_time", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_thermalise_wait_time
       end if

       call QUIP_FoX_get_value(attributes, "thermalise_wait_factor", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_thermalise_wait_factor
       end if

       call QUIP_FoX_get_value(attributes, "tau", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_tau
       end if

       call QUIP_FoX_get_value(attributes, "wait_time", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_wait_time
       end if

       call QUIP_FoX_get_value(attributes, "interval_time", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_interval_time
       end if

       call QUIP_FoX_get_value(attributes, "calc_connect_interval", value, status)
       if (status == 0) then
          read (value, *) parse_cp%md_calc_connect_interval
       end if


    elseif (parse_in_crack .and. name == 'minim') then

       call QUIP_FoX_get_value(attributes, "method", value, status)
       if (status == 0) then
          parse_cp%minim_method = value
       end if

       call QUIP_FoX_get_value(attributes, "tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_tol
       end if

       call QUIP_FoX_get_value(attributes, "eps_guess", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_eps_guess
       end if

       call QUIP_FoX_get_value(attributes, "max_steps", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_max_steps
       end if

       call QUIP_FoX_get_value(attributes, "linminroutine", value, status)
       if (status == 0) then
          parse_cp%minim_linminroutine = value
       end if

       call QUIP_FoX_get_value(attributes, "minimise_mm", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_minimise_mm
       end if

       call QUIP_FoX_get_value(attributes, "mm_method", value, status)
       if (status == 0) then
          parse_cp%minim_mm_method = value
       end if

       call QUIP_FoX_get_value(attributes, "mm_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_mm_tol
       end if
       
       call QUIP_FoX_get_value(attributes, "mm_eps_guess", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_mm_eps_guess
       end if

       call QUIP_FoX_get_value(attributes, "mm_max_steps", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_mm_max_steps
       end if

       call QUIP_FoX_get_value(attributes, "mm_linminroutine", value, status)
       if (status == 0) then
          parse_cp%minim_mm_linminroutine = value
       end if

       call QUIP_FoX_get_value(attributes, "mm_args_str", value, status)
       if (status == 0) then
          parse_cp%minim_mm_args_str = value
       end if

       call QUIP_FoX_get_value(attributes, "mm_use_n_minim", value, status)
       if (status == 0) then
          read (value, *) parse_cp%minim_mm_use_n_minim
       end if


    elseif (parse_in_crack .and. name == 'io') then
       
       call QUIP_FoX_get_value(attributes, "verbosity", value, status)
       if (status == 0) then
          parse_cp%io_verbosity = str_to_verbosity(value)
       end if

       call QUIP_FoX_get_value(attributes, "netcdf", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_netcdf
       end if

       call QUIP_FoX_get_value(attributes, "print_interval", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_print_interval
       end if

       call QUIP_FoX_get_value(attributes, "print_all_properties", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_print_all_properties
       end if

       call QUIP_FoX_get_value(attributes, "print_properties", value, status)
       if (status == 0) then

         ! Backwards compatibility: prepend species tag if it's missing
         call parse_string(value, ':', tmp_properties, n_properties)
	 got_species = .false.
	 do i=1, n_properties
	  if (trim(tmp_properties(i)) == 'species') then
	    if (i /= 1) then
	      tmp_properties(i) = tmp_properties(1)
	      tmp_properties(1) = 'species'
	    endif
	    got_species = .true.
	  endif
	 end do

	 if (got_species) then
	   value = trim(tmp_properties(1))
	   do i=2, n_properties
	     value = trim(value) // ':' // tmp_properties(i)
	   end do
	 else
	   value = 'species:'//trim(value)
	 endif
         
         call parse_string(value, ':', tmp_properties, n_properties)

         if (n_properties > MAX_PROPERTIES) &
              call system_abort('error reading io_print_properties: MAX_PROPERTIES('//MAX_PROPERTIES//') exceeded')

         if (allocated(parse_cp%io_print_properties)) deallocate(parse_cp%io_print_properties)
         allocate(parse_cp%io_print_properties(n_properties))
         parse_cp%io_print_properties(1:n_properties) = tmp_properties(1:n_properties)

       end if

       call QUIP_FoX_get_value(attributes, "checkpoint_interval", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_checkpoint_interval
       end if

       call QUIP_FoX_get_value(attributes, "checkpoint_path", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_checkpoint_path
       end if

       call QUIP_FoX_get_value(attributes, "mpi_print_all", value, status)
       if (status == 0) then
          read (value, *) parse_cp%io_mpi_print_all
       end if

    elseif (parse_in_crack .and. name == 'selection') then

       call QUIP_FoX_get_value(attributes, "max_qm_atoms", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_max_qm_atoms
       end if

       call QUIP_FoX_get_value(attributes, "dynamic", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_dynamic
       end if

       call QUIP_FoX_get_value(attributes, "ellipse", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_ellipse
       end if

       call QUIP_FoX_get_value(attributes, "ellipse_bias", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_ellipse_bias
       end if

       call QUIP_FoX_get_value(attributes, "ellipse_buffer", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_ellipse_buffer
       end if

       call QUIP_FoX_get_value(attributes, "cutoff_plane", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_cutoff_plane
       end if

       call QUIP_FoX_get_value(attributes, "directionality", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_directionality
       end if

       call QUIP_FoX_get_value(attributes, "edge_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%selection_edge_tol
       end if

    elseif (parse_in_crack .and. name == 'classical') then

       call QUIP_FoX_get_value(attributes, "args", value, status)
       if (status == 0) then
          parse_cp%classical_args = value
       end if

       call QUIP_FoX_get_value(attributes, "args_str", value, status)
       if (status == 0) then
          parse_cp%classical_args_str = value
       end if

       call QUIP_FoX_get_value(attributes, "force_reweight", value, status)
       if (status == 0) then
          read (value, *) parse_cp%classical_force_reweight
       end if

    elseif (parse_in_crack .and. name == 'qm') then
       
       call QUIP_FoX_get_value(attributes, "args", value, status)
       if (status == 0) then
          parse_cp%qm_args = value
       end if

       call QUIP_FoX_get_value(attributes, "args_str", value, status)
       if (status == 0) then
          parse_cp%qm_args_str = value
       end if

       call QUIP_FoX_get_value(attributes, "small_clusters", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_small_clusters
       end if

       call QUIP_FoX_get_value(attributes, "buffer_hops", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_buffer_hops
       end if

       call QUIP_FoX_get_value(attributes, "terminate", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_terminate
       end if

       call QUIP_FoX_get_value(attributes, "force_periodic", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_force_periodic
       end if

       call QUIP_FoX_get_value(attributes, "randomise_buffer", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_randomise_buffer
       end if

       call QUIP_FoX_get_value(attributes, "even_hydrogens", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_even_hydrogens
       end if

       call QUIP_FoX_get_value(attributes, "vacuum_size", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_vacuum_size
       end if

       call QUIP_FoX_get_value(attributes, "calc_force_error", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_calc_force_error
       end if

       call QUIP_FoX_get_value(attributes, "rescale_r", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_rescale_r
       end if

       call QUIP_FoX_get_value(attributes, "hysteretic_buffer", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_hysteretic_buffer
       end if

       call QUIP_FoX_get_value(attributes, "hysteretic_buffer_inner_radius", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_hysteretic_buffer_inner_radius
       end if

       call QUIP_FoX_get_value(attributes, "hysteretic_buffer_outer_radius", value, status)
       if (status == 0) then
          read (value, *) parse_cp%qm_hysteretic_buffer_outer_radius
       end if


    elseif (parse_in_crack .and. name == 'fit') then

       call QUIP_FoX_get_value(attributes, "hops", value, status)
       if (status == 0) then
          read (value, *) parse_cp%fit_hops
       end if

       call QUIP_FoX_get_value(attributes, "spring_hops", value, status)
       if (status == 0) then
          read (value, *) parse_cp%fit_spring_hops
       end if

       call QUIP_FoX_get_value(attributes, "method", value, status)
       if (status == 0) then
          parse_cp%fit_method = value
       end if


    elseif (parse_in_crack .and. name == 'force_integration') then
       
       call QUIP_FoX_get_value(attributes, "end_file", value, status)
       if (status == 0) then
          parse_cp%force_integration_end_file = value
       end if

       call QUIP_FoX_get_value(attributes, "n_steps", value, status)
       if (status == 0) then
          read (value, *) parse_cp%force_integration_n_steps
       end if

    elseif (parse_in_crack .and. name == 'quasi_static') then

       call QUIP_FoX_get_value(attributes, "tip_move_tol", value, status)
       if (status == 0) then
          read (value, *) parse_cp%quasi_static_tip_move_tol
       end if

    elseif (parse_in_crack .and. name == 'hack') then

       call QUIP_FoX_get_value(attributes, "qm_zero_z_force", value, status)
       if (status == 0) then
          read (value, *) parse_cp%hack_qm_zero_z_force
       end if

       call QUIP_FoX_get_value(attributes, "fit_on_eqm_coordination_only", value, status)
       if (status == 0) then
          read (value, *) parse_cp%hack_fit_on_eqm_coordination_only
       end if


    endif

  end subroutine CrackParams_startElement_handler

  !% OMIT
  subroutine CrackParams_endElement_handler(URI, localname, name)
    character(len=*), intent(in)   :: URI  
    character(len=*), intent(in)   :: localname
    character(len=*), intent(in)   :: name 

    if (parse_in_crack) then
       if (name == 'crack_params') then
          parse_in_crack = .false.
       endif
    endif

  end subroutine CrackParams_endElement_handler


  !% Print out this CrackParams structure
  subroutine CrackParams_print(this,file)
    type(CrackParams), intent(in) :: this
    type(Inoutput), optional, intent(in) :: file
    integer :: i

    call Print('  Crack parameters:',file=file)
    call Print('     structure             = '//trim(this%crack_structure),file=file)
    call Print('     element               = '//trim(this%crack_element),file=file)
    call Print('     lattice_guess         = '//this%crack_lattice_guess//' A',file=file)
    call Print('     name                  = '//trim(this%crack_name),file=file)
    call Print('     width                 = '//this%crack_width//' A', file=file)
    call Print('     height                = '//this%crack_height//' A', file=file)
    call Print('     num_layers            = '//this%crack_num_layers, file=file)
    call Print('     G                     = '//this%crack_G//' J/m^2', file=file)
    call Print('     loading               = '//this%crack_loading, file=file)
    call Print('     load_interp_length    = '//this%crack_load_interp_length, file=file)
    call Print('     ramp_length           = '//this%crack_ramp_length//' A', file=file)
    call Print('     ramp_end_G            = '//this%crack_ramp_end_G//' J/m^2', file=file)
    call Print('     initial_loading_strain= '//this%crack_initial_loading_strain, file=file)
    call Print('     G_increment           = '//this%crack_G_increment//'J/m^2 per load cycle', file=file)
    call Print('     seed_length           = '//this%crack_seed_length//' A', file=file)
    call Print('     strain_zone_width     = '//this%crack_strain_zone_width//' A', file=file)
    call Print('     vacuum_size           = '//this%crack_vacuum_size//' A', file=file)
    call Print('     relax_loading_field   = '//this%crack_relax_loading_field, file=file)
    call Print('     rescale_x_z           = '//this%crack_rescale_x_z, file=file)
    call Print('     rescale_x             = '//this%crack_rescale_x, file=file)
    call Print('     edge_fix_tol          = '//this%crack_edge_fix_tol//' A', file=file)
    call Print('     y_shift               = '//this%crack_y_shift//' A', file=file)
    call Print('     seed_embed_tol        = '//this%crack_seed_embed_tol//' A', file=file)
    call Print('     graphene_theta        = '//this%crack_graphene_theta//' rad', file=file)
    call Print('     graphene_notch_width  = '//this%crack_graphene_notch_width//' A', file=file)
    call Print('     graphene_notch_height = '//this%crack_graphene_notch_height//' A', file=file)
    call Print('     slab_filename         = '//this%crack_slab_filename, file=file)
    call Print('',file=file)
    call Print('  Simulation parameters:',file=file)
    call Print('     task                  = '//trim(this%simulation_task),file=file)
    call Print('     seed                  = '//this%simulation_seed,file=file)
    call Print('     restart               = '//this%simulation_restart,file=file)
    call Print('     classical             = '//this%simulation_classical,file=file)
    call Print('     force_initial_load_step = '//this%simulation_force_initial_load_step,file=file)
    call Print('',file=file)
    call Print('  MD parameters:',file=file)
    call Print('     time_step             = '//this%md_time_step//' fs',file=file)
    call Print('     extrapolate_steps     = '//this%md_extrapolate_steps,file=file)
    call Print('     crust                 = '//this%md_crust//' A',file=file)
    call Print('     recalc_connect_factor = '//this%md_recalc_connect_factor,file=file)
    call Print('     nneigh_tol            = '//this%md_nneigh_tol,file=file)
    call Print('     eqm_coordination      = '//this%md_eqm_coordination,file=file)
    call Print('     sim_temp              = '//this%md_sim_temp//' K',file=file)
    call Print('     avg_time              = '//this%md_avg_time//' fs',file=file)
    call Print('     thermalise_tau        = '//this%md_thermalise_tau//' fs',file=file)
    call Print('     thermalise_wait_time  = '//this%md_thermalise_wait_time//' fs',file=file)
    call Print('     thermalise_wait_factor  = '//this%md_thermalise_wait_factor//' fs',file=file)
    call Print('     tau                   = '//this%md_tau//' fs',file=file)
    call Print('     wait_time             = '//this%md_wait_time//' fs',file=file)
    call Print('     interval_time         = '//this%md_interval_time//' fs',file=file)
    call Print('     calc_connect_interval = '//this%md_calc_connect_interval//' fs',file=file)
    call Print('',file=file)
    call Print('  Minimisation parameters:',file=file)
    call Print('     method                = '//trim(this%minim_method),file=file)
    call Print('     tol                   = '//this%minim_tol//' (eV/A)^2',file=file)
    call Print('     eps_guess             = '//this%minim_eps_guess//' A',file=file)
    call Print('     max_steps             = '//this%minim_max_steps,file=file)
    call Print('     linminroutine         = '//trim(this%minim_linminroutine),file=file)
    call Print('     minimise_mm           = '//this%minim_minimise_mm,file=file)
    call Print('     mm_method             = '//trim(this%minim_mm_method),file=file)
    call Print('     mm_tol                = '//this%minim_mm_tol// ' (eV/A)^2',file=file)
    call Print('     mm_eps_guess          = '//this%minim_mm_eps_guess//' A',file=file)
    call Print('     mm_max_steps          = '//this%minim_mm_max_steps,file=file)
    call Print('     mm_linminroutine      = '//trim(this%minim_mm_linminroutine),file=file)
    call Print('     mm_args_str           = '//trim(this%minim_mm_args_str),file=file)
    call Print('     mm_use_n_minim        = '//this%minim_mm_use_n_minim,file=file)
    call Print('',file=file)
    call Print('  I/O parameters:',file=file)
    call Print('     verbosity             = '//trim(verbosity_to_str(this%io_verbosity)),file=file)
    call Print('     netcdf                = '//this%io_netcdf,file=file)
    call Print('     print_interval        = '//this%io_print_interval//' fs',file=file)
    call Print('     print_all_properties  = '//this%io_print_all_properties,file=file)
    line='     print_properties      = '
    do i=1,size(this%io_print_properties)
       line=trim(line)//' '//this%io_print_properties(i)
    end do
    call Print(line,file=file)

    call Print('     checkpoint_interval   = '//this%io_checkpoint_interval//' fs',file=file)
    call Print('     checkpoint_path       = '//this%io_checkpoint_path,file=file)
    call Print('     mpi_print_all         = '//this%io_mpi_print_all,file=file)
    call Print('',file=file)
    call Print('  Selection parameters:',file=file)
    call Print('     max_qm_atoms          = '//this%selection_max_qm_atoms,file=file)
    call Print('     dynamic               = '//this%selection_dynamic,file=file)
    call Print('     ellipse               = '//this%selection_ellipse//' A',file=file)
    call Print('     ellipse_bias          = '//this%selection_ellipse_bias//' radius fraction',file=file)
    call Print('     ellipse_buffer        = '//this%selection_ellipse_buffer//' A',file=file)
    call Print('     cutoff_plane          = '//this%selection_cutoff_plane//' A',file=file)
    call Print('     directionality        = '//this%selection_directionality)
    call Print('     edge_tol              = '//this%selection_edge_tol//' A',file=file)
    call Print('',file=file)
    call Print('  Classical parameters:',file=file)
    call Print('     args                  = '//trim(this%classical_args),file=file)
    call Print('     args_str              = '//trim(this%classical_args_str),file=file)
    call Print('     force_reweight        = '//this%classical_force_reweight,file=file)
    call Print('',file=file)
    call Print('  QM parameters:',file=file)
    call Print('     args                  = '//trim(this%qm_args),file=file)
    call Print('     args_str              = '//trim(this%qm_args_str),file=file)
    call Print('     small_clusters        = '//this%qm_small_clusters,file=file)
    call Print('     buffer_hops           = '//this%qm_buffer_hops,file=file)
    call Print('     terminate             = '//this%qm_terminate,file=file)
    call Print('     force_periodic        = '//this%qm_force_periodic,file=file)
    call Print('     randomise_buffer      = '//this%qm_randomise_buffer,file=file)
    call Print('     even_hydrogens        = '//this%qm_even_hydrogens,file=file)
    call Print('     vacuum_size           = '//this%qm_vacuum_size//' A',file=file)
    call Print('     calc_force_error      = '//this%qm_calc_force_error, file=file)
    call Print('     rescale_r             = '//this%qm_rescale_r, file=file)
    call Print('     hysteretic_buffer     = '//this%qm_hysteretic_buffer, file=file)
    call Print('     hysteretic_buffer_inner_radius = '//this%qm_hysteretic_buffer_inner_radius//' A', file=file)
    call Print('     hysteretic_buffer_outer_radius = '//this%qm_hysteretic_buffer_outer_radius//' A', file=file)
    call Print('',file=file)
    call Print('  Fit parameters:',file=file)
    call Print('     hops                  = '//this%fit_hops,file=file)
    call Print('     spring_hops           = '//this%fit_spring_hops, file=file)
    call Print('     method                = '//trim(this%fit_method),file=file)
    call Print('',file=file)
    call Print('  Force integration parameters',file=file)
    call Print('     end_file              = '//trim(this%force_integration_end_file),file=file)
    call Print('     n_steps               = '//this%force_integration_n_steps,file=file)
    call Print('',file=file)
    call Print('  Quasi static loading parameters',file=file)
    call Print('     tip_move_tol          = '//this%quasi_static_tip_move_tol,file=file)
    call Print('',file=file)
    call Print('  Nasty hacks:',file=file)
    call Print('     qm_zero_z_force       = '//this%hack_qm_zero_z_force,file=file)
    call Print('     fit_on_eqm_coordination_only = '//this%hack_fit_on_eqm_coordination_only)
    call Print('',file=file)

  end subroutine CrackParams_print

end module CrackParams_module
