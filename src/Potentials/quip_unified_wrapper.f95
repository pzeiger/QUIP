! H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! H0 X
! H0 X   libAtoms+QUIP: atomistic simulation library
! H0 X
! H0 X   Portions of this code were written by
! H0 X     Albert Bartok-Partay, Silvia Cereda, Gabor Csanyi, James Kermode,
! H0 X     Ivan Solt, Wojciech Szlachta, Csilla Varnai, Steven Winfield.
! H0 X     Tamas K. Stenczel
! H0 X
! H0 X   Copyright 2006-2020.
! H0 X
! H0 X   These portions of the source code are released under the GNU General
! H0 X   Public License, version 2, http://www.gnu.org/copyleft/gpl.html
! H0 X
! H0 X   If you would like to license the source code under different terms,
! H0 X   please contact Gabor Csanyi, gabor@csanyi.net
! H0 X
! H0 X   Portions of this code were written by Noam Bernstein as part of
! H0 X   his employment for the U.S. Government, and are not subject
! H0 X   to copyright in the USA.
! H0 X
! H0 X
! H0 X   When using this software, please cite the following reference:
! H0 X
! H0 X   http://www.libatoms.org
! H0 X
! H0 X  Additional contributions by
! H0 X    Alessio Comisso, Chiara Gattinoni, and Gianpietro Moras
! H0 X
! H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
!X
!X quip_wrapper subroutine
!X
!% wrapper to make it nicer for non-QUIP programs to use a QUIP potential
!X
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

module quip_unified_wrapper_module

use system_module, only : dp, print, system_initialise, system_abort, PRINT_ANALYSIS, PRINT_VERBOSE, PRINT_NORMAL, PRINT_SILENT, verbosity_push, &
   verbosity_pop, optional_default
use dictionary_module, only : dictionary, STRING_LENGTH
use periodictable_module, only : atomic_number_from_symbol
use mpi_context_module, only : mpi_context, initialise
use atoms_types_module, only : assign_pointer
use atoms_module, only : atoms, initialise, finalise, set_cutoff, calc_connect, set_lattice, get_param_value
use potential_module, only : potential, potential_filename_initialise, calc, cutoff, print, Finalise
implicit none

contains

subroutine quip_unified_wrapper(N,pos,frac_pos,lattice,symbol,Z, &
   quip_param_file,quip_param_file_len,init_args_str,init_args_str_len,calc_args_str,calc_args_str_len, &
   energy,force,virial,do_energy,do_force,do_virial,output_unit,mpi_communicator,reload_pot)
  !% Unified wrapper for QUIP potentials
  !%
  !% Notes: (tks32)
  !%  - changes in the potential on the fly are picked up only if reload_pot is specified
  !%  - MPI context cannot be changed on the fly

  use system_module, only: optional_default, print
  implicit none

  ! arguments in call order
  integer,                          intent(in)            :: N
  real(dp),         dimension(3,N), intent(in),  optional :: pos
  real(dp),         dimension(3,N), intent(in),  optional :: frac_pos
  real(dp),         dimension(3,3), intent(in),  optional :: lattice
  character(len=*), dimension(N),   intent(in),  optional :: symbol
  integer,          dimension(N),   intent(in),  optional :: Z
  integer,                          intent(in)            :: quip_param_file_len
  character(len=quip_param_file_len)                      :: quip_param_file
  integer,                          intent(in)            :: init_args_str_len
  character(len=init_args_str_len)                        :: init_args_str
  integer,                          intent(in)            :: calc_args_str_len
  character(len=calc_args_str_len)                        :: calc_args_str
  real(dp),                         intent(out), optional :: energy
  real(dp),         dimension(3,N), intent(out), optional :: force
  real(dp),         dimension(3,3), intent(out), optional :: virial
  logical,                          intent(in),  optional :: do_energy
  logical,                          intent(in),  optional :: do_force
  logical,                          intent(in),  optional :: do_virial
  integer,                          intent(in),  optional :: output_unit
  integer,                          intent(in),  optional :: mpi_communicator
  logical,                          intent(in),  optional :: reload_pot                ! reloads the potential

  ! internal variables
  integer                           :: i
  real(dp), dimension(:,:), pointer :: quip_wrapper_force
  character(len=STRING_LENGTH)      :: use_calc_args
  real(dp)                          :: use_lattice(3,3)
  logical                           :: use_do_energy, use_do_force, use_do_virial

  ! saved stuff
  type(atoms),       save :: at
  type(Potential),   save :: pot
  type(MPI_context), save :: mpi_glob
  logical,           save :: first_run = .true.

  if (present(lattice)) then
     use_lattice = lattice
  else
     use_lattice = 0.0_dp
  endif

  if( first_run ) then
     call system_initialise(verbosity=PRINT_SILENT,mainlog_unit=output_unit)
     call Initialise(mpi_glob,communicator=mpi_communicator)
     call Potential_Filename_Initialise(pot, args_str=trim(init_args_str), param_filename=quip_param_file,mpi_obj=mpi_glob)
     call verbosity_push(PRINT_NORMAL)
     call Print(pot)
     call verbosity_pop()
     call initialise(at,N,use_lattice)
  end if

  if (optional_default(.false., reload_pot)) then
    ! deallocate old potential -- this was initialised in first_run
    call Finalise(pot)
    ! initialise with new parameters
    call Potential_Filename_Initialise(pot, args_str=trim(init_args_str), param_filename=quip_param_file,mpi_obj=mpi_glob)
    call Print(pot)
  endif

  if( .not. first_run .and. (N /= at%N) ) then
     call finalise(at)
     call initialise(at,N,use_lattice)
  endif

  call set_lattice(at,use_lattice, scale_positions=.false.)

  if (present(Z)) then
     if (present(symbol)) call system_abort("quip_unified_wrapper got both Z and symbol, don't know which to use")
     at%Z = Z
  else ! no Z, use symbol
     if (.not. present(symbol)) call system_abort("quip_unified_wrapper got neither Z nor symbol")
     do i = 1, at%N
        at%Z(i) = atomic_number_from_symbol(symbol(i))
     enddo
  endif

  if (present(pos)) then
     if (present(frac_pos)) call system_abort("quip_unified_wrapper got both pos and frac_pos, don't know which to use")
     at%pos = pos
  else ! no pos, use frac_pos
     if (.not. present(frac_pos)) call system_abort("quip_unified_wrapper got neither pos nor frac_pos")
     at%pos = matmul(at%lattice,frac_pos)
  endif

  if(at%cutoff > 0) call calc_connect(at)

  use_calc_args = trim(calc_args_str)
  use_do_energy = optional_default(present(energy), do_energy)
  use_do_force = optional_default(present(force), do_force)
  use_do_virial = optional_default(present(virial), do_virial)
  if (use_do_energy .and. .not. present(energy)) call system_abort("quip_unified_wrapper got do_energy=.true. but not present(energy)")
  if (use_do_force .and. .not. present(force)) call system_abort("quip_unified_wrapper got do_force=.true. but not present(force)")
  if (use_do_virial .and. .not. present(virial)) call system_abort("quip_unified_wrapper got do_virial=.true. but not present(virial)")
  if(use_do_energy) use_calc_args = trim(use_calc_args)//" energy=quip_wrapper_energy "
  if(use_do_force) use_calc_args = trim(use_calc_args)//" force=quip_wrapper_force "
  if(use_do_virial) use_calc_args = trim(use_calc_args)//" virial=quip_wrapper_virial "

  call calc(pot,at,args_str=trim(use_calc_args))

  if(use_do_energy) call get_param_value(at, "quip_wrapper_energy", energy)
  if(use_do_virial) call get_param_value(at, "quip_wrapper_virial", virial)
  if(use_do_force) then
     if(.not. assign_pointer(at,"quip_wrapper_force",quip_wrapper_force) ) call system_abort("Could not calculate forces")
     force = quip_wrapper_force
  endif

  first_run = .false.

end subroutine quip_unified_wrapper

end module quip_unified_wrapper_module

subroutine quip_wrapper(N,lattice,symbol,pos,args_str,args_str_len,energy,force,virial,do_energy,do_force,do_virial)

  use system_module, only : dp
  use quip_unified_wrapper_module

  implicit none

  integer, intent(in) :: N
  real(dp), dimension(3,3), intent(inout) :: lattice
  character(len=3), dimension(N), intent(in) :: symbol
  integer, intent(in) :: args_str_len
  character(len=args_str_len) :: args_str
  real(dp), dimension(3,N), intent(in) :: pos
  real(dp), intent(out) :: energy
  real(dp), dimension(3,N), intent(out) :: force
  real(dp), dimension(3,3), intent(out) :: virial
  logical, intent(in) :: do_energy, do_force, do_virial

  call quip_unified_wrapper(N=N,lattice=lattice,symbol=symbol,pos=pos,init_args_str=args_str,init_args_str_len=args_str_len, &
                            energy=energy,force=force,virial=virial,do_energy=do_energy,do_force=do_force,do_virial=do_virial, &
                            quip_param_file="quip_params.xml", quip_param_file_len=15, calc_args_str="",calc_args_str_len=0)


endsubroutine quip_wrapper

subroutine quip_wrapper_castep(N,lattice,frac_pos,symbol, &
      quip_param_file,quip_param_file_len,init_args_str,init_args_str_len,calc_args_str,calc_args_str_len, &
      energy,force,virial,do_energy,do_force,do_virial,output_unit, reload_pot, mpi_communicator, use_mpi)

  !% Castep wrapper for QUIP potentials
  !%
  !% Notes: (tks32)
  !%  - added reload_pot optional arg
  !%  - lattice was intent(inout), made no sense so changed it to intent(in)
  !%  as it is in the unitied wrapper as well

  use system_module, only : dp
  use quip_unified_wrapper_module

  implicit none

  integer,                            intent(in)  :: N
  real(dp),         dimension(3,N),   intent(in)  :: frac_pos
  real(dp),         dimension(3,3),   intent(in)  :: lattice
  character(len=3), dimension(N),     intent(in)  :: symbol
  integer,                            intent(in)  :: quip_param_file_len
  character(len=quip_param_file_len), intent(in)  :: quip_param_file
  integer,                            intent(in)  :: init_args_str_len
  character(len=init_args_str_len),   intent(in)  :: init_args_str
  integer,                            intent(in)  :: calc_args_str_len
  character(len=calc_args_str_len),   intent(in)  :: calc_args_str
  real(dp),                           intent(out) :: energy
  real(dp),         dimension(3,N),   intent(out) :: force
  real(dp),         dimension(3,3),   intent(out) :: virial
  logical,                            intent(in)  :: do_energy
  logical,                            intent(in)  :: do_force
  logical,                            intent(in)  :: do_virial
  integer,                            intent(in)  :: output_unit
  logical,                            intent(in)  :: reload_pot            ! reloads the potential
  ! we should not have optional arguments,
  ! so we get told here if we should use MPI or not
  integer,                            intent(in)  :: mpi_communicator
  logical,                            intent(in)  :: use_mpi

  if (use_mpi) then
    call quip_unified_wrapper(N=N,frac_pos=frac_pos,lattice=lattice,symbol=symbol, &
            quip_param_file=quip_param_file, quip_param_file_len=quip_param_file_len, &
            init_args_str=init_args_str,init_args_str_len=init_args_str_len, &
            calc_args_str=calc_args_str,calc_args_str_len=calc_args_str_len, &
            energy=energy,force=force,virial=virial,&
            do_energy=do_energy,do_force=do_force,do_virial=do_virial,output_unit=output_unit, &
            reload_pot=reload_pot, mpi_communicator=mpi_communicator)
  else
    call quip_unified_wrapper(N=N,frac_pos=frac_pos,lattice=lattice,symbol=symbol, &
            quip_param_file=quip_param_file, quip_param_file_len=quip_param_file_len, &
            init_args_str=init_args_str,init_args_str_len=init_args_str_len, &
            calc_args_str=calc_args_str,calc_args_str_len=calc_args_str_len, &
            energy=energy,force=force,virial=virial,&
            do_energy=do_energy,do_force=do_force,do_virial=do_virial,output_unit=output_unit, &
            reload_pot=reload_pot)
  end if

endsubroutine quip_wrapper_castep


subroutine quip_wrapper_onetep(N, lattice, pos, Z, &
        quip_param_file_len, quip_param_file, &
        init_args_str_len, init_args_str, &
        calc_args_str_len, calc_args_str, &
        energy, force, &
        do_energy, do_force, &
        output_unit, reload_pot)

  !% ONETEP wrapper for QUIP potentials
  !%    does not interface virials, because onetep does not implement stresses
  !%
  !%    written by T. K. Stenczel, July 2021

  use system_module, only : dp
  use quip_unified_wrapper_module

  implicit none

  integer,                            intent(in)  :: N
  real(dp),         dimension(3,N),   intent(in)  :: pos
  real(dp),         dimension(3,3),   intent(in)  :: lattice
  integer,          dimension(N),     intent(in)  :: Z
  integer,                            intent(in)  :: quip_param_file_len
  character(len=quip_param_file_len), intent(in)  :: quip_param_file
  integer,                            intent(in)  :: init_args_str_len
  character(len=init_args_str_len),   intent(in)  :: init_args_str
  integer,                            intent(in)  :: calc_args_str_len
  character(len=calc_args_str_len),   intent(in)  :: calc_args_str
  real(dp),                           intent(out) :: energy
  real(dp),         dimension(3,N),   intent(out) :: force
  logical,                            intent(in)  :: do_energy
  logical,                            intent(in)  :: do_force
  integer,                            intent(in)  :: output_unit
  logical,                            intent(in)  :: reload_pot            ! reloads the potential

  call quip_unified_wrapper(N=N, pos=pos, lattice=lattice, Z=Z, &
     quip_param_file=quip_param_file, quip_param_file_len=quip_param_file_len, &
     init_args_str=init_args_str, init_args_str_len=init_args_str_len, &
     calc_args_str=calc_args_str, calc_args_str_len=calc_args_str_len, &
     energy=energy, force=force, &
     do_energy=do_energy, do_force=do_force, output_unit=output_unit, &
     reload_pot=reload_pot)


endsubroutine quip_wrapper_onetep

subroutine quip_wrapper_simple(N,lattice,Z,pos,energy,force,virial)

  use system_module, only : dp
  use quip_unified_wrapper_module

  implicit none

  integer, intent(in) :: N
  real(dp), dimension(3,3), intent(inout) :: lattice
  integer, dimension(N), intent(in)::Z
  real(dp), dimension(3,N), intent(in) :: pos
  real(dp), intent(out) :: energy
  real(dp), dimension(3,N), intent(out) :: force
  real(dp), dimension(3,3), intent(out) :: virial


  call quip_unified_wrapper(N=N,lattice=lattice,Z=Z,pos=pos,init_args_str="xml_label=default",init_args_str_len=17, &
                            energy=energy,force=force,virial=virial,do_energy=.true.,do_force=.true.,do_virial=.true., &
                            quip_param_file="quip_params.xml", quip_param_file_len=15, calc_args_str="",calc_args_str_len=0)


endsubroutine quip_wrapper_simple

