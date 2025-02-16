# H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# H0 X
# H0 X   libAtoms+QUIP: atomistic simulation library
# H0 X
# H0 X   Portions of this code were written by
# H0 X     Albert Bartok-Partay, Silvia Cereda, Gabor Csanyi, James Kermode,
# H0 X     Ivan Solt, Wojciech Szlachta, Csilla Varnai, Steven Winfield.
# H0 X
# H0 X   Copyright 2006-2010.
# H0 X
# H0 X   These portions of the source code are released under the GNU General
# H0 X   Public License, version 2, http://www.gnu.org/copyleft/gpl.html
# H0 X
# H0 X   If you would like to license the source code under different terms,
# H0 X   please contact Gabor Csanyi, gabor@csanyi.net
# H0 X
# H0 X   Portions of this code were written by Noam Bernstein as part of
# H0 X   his employment for the U.S. Government, and are not subject
# H0 X   to copyright in the USA.
# H0 X
# H0 X
# H0 X   When using this software, please cite the following reference:
# H0 X
# H0 X   http://www.libatoms.org
# H0 X
# H0 X  Additional contributions by
# H0 X    Alessio Comisso, Chiara Gattinoni, and Gianpietro Moras
# H0 X
# H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

PROGRAMS = minimal_md xyz2pdb convert

.PHONY: default all clean docclean

default: libatoms.a

all: default ${PROGRAMS}

ifeq (${QUIP_ARCH},)
  include Makefile.arch
else
  include Makefile.${QUIP_ARCH}
endif
include Makefile.inc
include Makefile.rules

# indicator that compiler is not set up properly
ifeq (${SIZEOF_FORTRAN_T},)
  $(error SIZEOF_FORTRAN_T is not set. Check compiler and re-run 'make config')
endif

LIBATOMS_F95_FILES = \
  error \
  kind_module \
  System \
  LinkedList \
  ExtendableStr \
  MPI_context \
  Units \
  linearalgebra \
  Quaternions \
  statistics \
  Dictionary \
  Table \
  ParamReader \
  PeriodicTable \
  minimization \
  Atoms_types \
  Connection \
  DomainDecomposition \
  Atoms \
  RigidBody \
  Group \
  angular_functions \
  steinhardt_nelson_qw \
  gamma_functions \
  Constraints \
  Thermostat \
  Barostat \
  DynamicalSystem \
  Spline \
  Sparse \
  CInOutput \
  clusters \
  Structures \
  frametools\
  nye_tensor \
  Topology \
  Atoms_ll \
  ringstat \
  histogram1d \
  find_surface_atoms \
  k_means_clustering \
  SocketTools \
  partition \
  libAtoms \
  libAtoms_misc_utils \
  libAtoms_utils_no_module \
  f90wrap_stub \
  ScaLAPACK \
  Matrix \
  task_manager

LIBATOMS_F77_FILES= \
   lbfgs

LIBATOMS_C_FILES = \
  md5\
  cutil\
  netcdf\
  xyz\
  sockets


LIBATOMS_F77_SOURCES = ${addsuffix .f, ${LIBATOMS_F77_FILES}}
LIBATOMS_F77_OBJS = ${addsuffix .o, ${LIBATOMS_F77_FILES}}
LIBATOMS_F95_SOURCES = ${addsuffix .f95, ${LIBATOMS_F95_FILES}}
LIBATOMS_F95_OBJS = ${addsuffix .o, ${LIBATOMS_F95_FILES}}
LIBATOMS_C_SOURCES = ${addsuffix .c, ${LIBATOMS_C_FILES}}
LIBATOMS_C_OBJS = ${addsuffix .o, ${LIBATOMS_C_FILES}}

LIBATOMS_SOURCES = ${LIBATOMS_F77_SOURCES} ${LIBATOMS_F95_SOURCES} ${LIBATOMS_C_SOURCES}
LIBATOMS_OBJS = ${LIBATOMS_F77_OBJS} ${LIBATOMS_F95_OBJS} ${LIBATOMS_C_OBJS}

LIBS = -L. -latoms

libatoms.a: ${LIBATOMS_OBJS}
ifneq (${LIBTOOL},)
	${LIBTOOL} -o libatoms.a ${LIBATOMS_OBJS}
else
	${AR} ${AR_ADD} libatoms.a $?
endif

clean:
	rm -f libatoms.a *.o *.mod *.mod.save *.mod.txt *.mod.save.txt *.fpp *.f90doc libAtoms.depend

allclean: clean docclean


${LIBATOMS_C_OBJS}  : %.o : %.c
	${CC} ${CFLAGS} -c $<


${PROGRAMS} ${EXTRA_PROGRAMS}: % :  %.o libatoms.a
	$(LINKER) $(LINKFLAGS) -o $@ ${F90OPTS} $@.o ${OBJS} ${LIBS}  ${LINKOPTS}


install:
