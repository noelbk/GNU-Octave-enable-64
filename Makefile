################################################################################
##
##  Building GNU Octave with --enable-64 on GNU Linux
##
################################################################################

# build libraries like "libopenblas_Octave64.so"
SONAME_SUFFIX ?= Octave64
# specify root directory (default: current directory)
ROOT_DIR      ?= ${PWD}

# create necessary file structure
SRC_CACHE = $(ROOT_DIR)/source-cache
BUILD_DIR = $(ROOT_DIR)/build
INSTALL_DIR  = $(ROOT_DIR)/install
LD_LIBRARY_PATH=$(INSTALL_DIR)/lib
IGNORE := $(shell mkdir -p $(SRC_CACHE) $(BUILD_DIR) $(INSTALL_DIR))

# if no SONAME suffix is wanted, leave everything blank
ifeq ($(strip $(SONAME_SUFFIX)),)
_SONAME_SUFFIX =
else
_SONAME_SUFFIX = _$(SONAME_SUFFIX)
endif

# small helper function to search for a library name pattern for replacing
fix_soname = grep -Rl '$(2)' $(BUILD_DIR)/$(1) | xargs sed -i "s/$(2)/$(3)/g";

.PHONY: clean

.EXPORT_ALL_VARIABLES:

all: octave

clean:
	rm -Rf $(BUILD_DIR) $(INSTALL_DIR) $(SRC_CACHE)

################################################################################
#
#   OpenBLAS  - http://www.openblas.net
#
#   The OpenBLAS library will be build from a specific version, ensuring
#   64 bit indices.
#
################################################################################

OPENBLAS_VER = 0.2.19

$(SRC_CACHE)/openblas-$(OPENBLAS_VER).zip:
	cd $(SRC_CACHE) \
	&& wget https://github.com/xianyi/OpenBLAS/archive/v$(OPENBLAS_VER).zip \
	&& mv v$(OPENBLAS_VER).zip openblas-$(OPENBLAS_VER).zip

$(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so: \
	$(SRC_CACHE)/openblas-$(OPENBLAS_VER).zip
	cd $(BUILD_DIR) \
	&& unzip $(SRC_CACHE)/openblas-$(OPENBLAS_VER).zip \
	&& mv OpenBLAS-$(OPENBLAS_VER) openblas
	cd $(BUILD_DIR)/openblas \
	&& $(MAKE) BINARY=64 INTERFACE64=1 LIBNAMESUFFIX=$(SONAME_SUFFIX) \
	&& $(MAKE) install PREFIX=$(INSTALL_DIR) LIBNAMESUFFIX=$(SONAME_SUFFIX)

openblas: $(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so


################################################################################
#
#   SuiteSparse  - http://www.suitesparse.com
#
#   The SuiteSparse library will be build from a specific version, ensuring
#   64 bit indices and using the self compiled OpenBLAS.
#
################################################################################

SUITESPARSE_VER = 4.5.3

SUITESPARSE_LIBS = amd camd colamd ccolamd csparse cxsparse cholmod umfpack \
	spqr klu rbio ldl btf suitesparseconfig

$(SRC_CACHE)/suitesparse-$(SUITESPARSE_VER).tar.gz:
	cd $(SRC_CACHE) \
	&& wget http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-$(SUITESPARSE_VER).tar.gz \
	&& mv SuiteSparse-$(SUITESPARSE_VER).tar.gz \
	      suitesparse-$(SUITESPARSE_VER).tar.gz

$(INSTALL_DIR)/lib/libsuitesparseconfig$(_SONAME_SUFFIX).so: \
	$(SRC_CACHE)/suitesparse-$(SUITESPARSE_VER).tar.gz \
	$(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so
	# unpack sources
	cd $(BUILD_DIR) \
	&& tar -xf $(SRC_CACHE)/suitesparse-$(SUITESPARSE_VER).tar.gz \
	&& mv SuiteSparse suitesparse
	# fix library names
	$(foreach l,$(SUITESPARSE_LIBS), \
		$(call fix_soname,suitesparse,LIBRARY = lib$(l),LIBRARY = lib$(l)$(_SONAME_SUFFIX)))
	$(foreach l,$(SUITESPARSE_LIBS), \
		$(call fix_soname,suitesparse,\-l$(l)\ ,\-l$(l)$(_SONAME_SUFFIX)\ ))
	$(foreach l,$(SUITESPARSE_LIBS), \
		$(call fix_soname,suitesparse,\-l$(l)$$,\-l$(l)$(_SONAME_SUFFIX)\ ))
	# build and install library
	cd $(BUILD_DIR)/suitesparse \
	&& $(MAKE) library \
	           LAPACK= \
	           BLAS=-lopenblas$(_SONAME_SUFFIX) \
	           UMFPACK_CONFIG=-D'LONGBLAS=long' \
	           CHOLMOD_CONFIG=-D'LONGBLAS=long' \
	           LDFLAGS='-L$(INSTALL_DIR)/lib -L$(BUILD_DIR)/suitesparse/lib' \
	&& $(MAKE) install \
	           INSTALL=$(INSTALL_DIR) \
	           INSTALL_DOC=/tmp/doc \
	           LAPACK= \
	           BLAS=-lopenblas$(_SONAME_SUFFIX) \
	           LDFLAGS='-L$(INSTALL_DIR)/lib -L$(BUILD_DIR)/suitesparse/lib'

suitesparse: $(INSTALL_DIR)/lib/libsuitesparseconfig$(_SONAME_SUFFIX).so


################################################################################
#
#   QRUPDATE  - http://sourceforge.net/projects/qrupdate/
#
#   The QRUPDATE library will be build from a specific version, ensuring
#   64 bit indices and using the self compiled OpenBLAS.
#
################################################################################

QRUPDATE_VER = 1.1.2

$(SRC_CACHE)/qrupdate-$(QRUPDATE_VER).tar.gz:
	cd $(SRC_CACHE) \
	&& wget http://downloads.sourceforge.net/project/qrupdate/qrupdate/1.2/qrupdate-$(QRUPDATE_VER).tar.gz

$(INSTALL_DIR)/lib/libqrupdate$(_SONAME_SUFFIX).so: \
	$(SRC_CACHE)/qrupdate-$(QRUPDATE_VER).tar.gz \
	$(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so
	# unpack sources
	cd $(BUILD_DIR) \
	&& tar -xf $(SRC_CACHE)/qrupdate-$(QRUPDATE_VER).tar.gz \
	&& mv qrupdate-$(QRUPDATE_VER) qrupdate
	# fix library name
	$(call fix_soname,qrupdate,libqrupdate,libqrupdate$(_SONAME_SUFFIX))
	# build and install library
	cd $(BUILD_DIR)/qrupdate \
	&& $(MAKE) install \
	           LAPACK="" \
	           BLAS="-lopenblas$(_SONAME_SUFFIX)" \
	           FFLAGS="-L$(INSTALL_DIR)/lib -fdefault-integer-8" \
	           PREFIX=$(INSTALL_DIR)

qrupdate: $(INSTALL_DIR)/lib/libqrupdate$(_SONAME_SUFFIX).so


################################################################################
#
#   ARPACK  - https://github.com/opencollab/arpack-ng
#
#   The ARPACK library will be build from a specific version, ensuring
#   64 bit indices and using the self compiled OpenBLAS.
#
################################################################################

ARPACK_VER = 3.4.0

$(SRC_CACHE)/arpack-$(ARPACK_VER).tar.gz:
	cd $(SRC_CACHE) \
	&& wget https://github.com/opencollab/arpack-ng/archive/$(ARPACK_VER).tar.gz \
	&& mv $(ARPACK_VER).tar.gz arpack-$(ARPACK_VER).tar.gz

$(INSTALL_DIR)/lib/libarpack$(_SONAME_SUFFIX).so: \
	$(SRC_CACHE)/arpack-$(ARPACK_VER).tar.gz \
	$(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so
	# unpack sources
	cd $(BUILD_DIR) \
	&& tar -xf $(SRC_CACHE)/arpack-$(ARPACK_VER).tar.gz \
	&& mv arpack-ng-$(ARPACK_VER) arpack
	# build and install library
	cd $(BUILD_DIR)/arpack \
	&& ./bootstrap \
	&& ./configure --prefix=$(INSTALL_DIR) \
	               --libdir=$(INSTALL_DIR)/lib \
	               --with-blas='-lopenblas$(_SONAME_SUFFIX)' \
	               --with-lapack='' \
	               INTERFACE64=1 \
	               LT_SYS_LIBRARY_PATH=$(INSTALL_DIR)/lib \
	               LDFLAGS='-L$(INSTALL_DIR)/lib' \
	               LIBSUFFIX='$(_SONAME_SUFFIX)' \
	&& $(MAKE) check && $(MAKE) install

arpack: $(INSTALL_DIR)/lib/libarpack$(_SONAME_SUFFIX).so


################################################################################
#
#   GNU Octave  - http://www.gnu.org/software/octave/
#
#   Build development version of GNU Octave using --enable-64 and all
#   requirements.
#
################################################################################

OCTAVE_VER = 4.2.0-rc4

LDSUITESPARSE = \
  '-lamd$(_SONAME_SUFFIX) \
   -lcamd$(_SONAME_SUFFIX) \
   -lcolamd$(_SONAME_SUFFIX) \
   -lccolamd$(_SONAME_SUFFIX) \
   -lcxsparse$(_SONAME_SUFFIX) \
   -lumfpack$(_SONAME_SUFFIX) \
   -lcholmod$(_SONAME_SUFFIX) \
   -lsuitesparseconfig$(_SONAME_SUFFIX)'

OCTAVE_CONFIG_FLAGS = \
  CPPFLAGS='-I$(INSTALL_DIR)/include' \
  LDFLAGS='-L$(INSTALL_DIR)/lib' \
  LD_LIBRARY_PATH='$(INSTALL_DIR)/lib' \
  --prefix=$(INSTALL_DIR) \
  --libdir='$(INSTALL_DIR)/lib' \
  --enable-64 \
  --with-blas='-lopenblas$(_SONAME_SUFFIX)' \
  --with-amd='-lamd$(_SONAME_SUFFIX) \
              -lsuitesparseconfig$(_SONAME_SUFFIX)' \
  --with-camd='-lcamd$(_SONAME_SUFFIX) \
               -lsuitesparseconfig$(_SONAME_SUFFIX)' \
  --with-colamd='-lcolamd$(_SONAME_SUFFIX) \
                 -lsuitesparseconfig$(_SONAME_SUFFIX)' \
  --with-ccolamd='-lccolamd$(_SONAME_SUFFIX) \
                  -lsuitesparseconfig$(_SONAME_SUFFIX)' \
  --with-cxsparse='-lcxsparse$(_SONAME_SUFFIX) \
                   -lsuitesparseconfig$(_SONAME_SUFFIX)' \
  --with-cholmod=$(LDSUITESPARSE) \
  --with-umfpack=$(LDSUITESPARSE) \
  --with-qrupdate='-lqrupdate$(_SONAME_SUFFIX)' \
  --with-arpack='-larpack$(_SONAME_SUFFIX)'

$(SRC_CACHE)/octave-$(OCTAVE_VER).tar.lz:
	cd $(SRC_CACHE) \
	&& wget ftp://alpha.gnu.org/gnu/octave/octave-$(OCTAVE_VER).tar.lz

$(INSTALL_DIR)/bin/octave: $(SRC_CACHE)/octave-$(OCTAVE_VER).tar.lz \
	$(INSTALL_DIR)/lib/libopenblas$(_SONAME_SUFFIX).so \
	$(INSTALL_DIR)/lib/libsuitesparseconfig$(_SONAME_SUFFIX).so \
	$(INSTALL_DIR)/lib/libqrupdate$(_SONAME_SUFFIX).so \
	$(INSTALL_DIR)/lib/libarpack$(_SONAME_SUFFIX).so
	cd $(BUILD_DIR) \
	&& tar -xf $(SRC_CACHE)/octave-$(OCTAVE_VER).tar.lz \
	&& mv octave-$(OCTAVE_VER) octave
	cd $(BUILD_DIR)/octave \
	&& ./configure $(OCTAVE_CONFIG_FLAGS) && $(MAKE) install \
	&& $(MAKE) check LD_LIBRARY_PATH='$(INSTALL_DIR)/lib'

octave: $(INSTALL_DIR)/bin/octave
