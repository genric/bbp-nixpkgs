{ stdenv
, config
, fetchgitPrivate
, pkgconfig
, boost
, hpctools
, libxml2
, cmake
, mpiRuntime
, zlib
, python
, pythonPackages
, hdf5
, generateDoc ? true
, asciidoc
, xmlto
, docbook_xsl
, libxslt }:

let
  python-env = python.buildEnv.override {
		extraLibs = [ pythonPackages.h5py ];
  };

in

stdenv.mkDerivation rec {
  name = "functionalizer-${version}";
  version = "3.10.0";

  meta = {
    description = "Apply several steps of filtering on touches";
    longDescription = ''
      Functionalizer takes as input the touches information output by the
      BlueDetector and applies the distributed approach of parallel
      transposition of a matrix (representing neurons connections), in order
      to perform several steps of filtering and output the final synapses as
      hdf5 files. It does all IO operations using MPI IO and hdf5 IO - uses
      parallel hdf5 when available.
    '';
    platforms = stdenv.lib.platforms.unix;
    homepage = "https://bbpcode.epfl.ch/code/#/admin/projects/building/Functionalizer";
    repository = "ssh://bbpcode.epfl.ch/building/Functionalizer";
    license = {
      fullName = "Copyright 2012, Blue Brain Project";
    };
  };

  buildInputs = [ boost hpctools zlib mpiRuntime libxml2 hdf5 ];

  nativeBuildInputs = [
    cmake
    pkgconfig
    python-env
  ] ++ stdenv.lib.optional generateDoc [
    asciidoc
    docbook_xsl
    libxslt
    xmlto
  ];

  src = fetchgitPrivate {
    url = config.bbp_git_ssh + "/building/Functionalizer";
    rev = "a9267e74badc6eb2b4f7ef4ad851306cd9f7c942";
    sha256 = "140q5hxz6n4szsr97q2kcpd3pbpxq34hychlynfil0ya4sr80plr";
  };


  cmakeFlags = [
    "-DUNIT_TESTS=TRUE"
    ''-DLIB_SUFFIX=''
  ] ++ stdenv.lib.optional generateDoc "-DFUNCTIONALIZER_DOCUMENTATION=TRUE";

  enableParallelBuilding = true;

  outputs = [ "out" ] ++ stdenv.lib.optional generateDoc "doc";

  crossAttrs = {
    ## enforce mpiwrapper in cross compilation mode for bgq
    cmakeFlags = cmakeFlags ++ [
      "-DCMAKE_CXX_COMPILER=mpic++"
      "-DCMAKE_C_COMPILER=mpicc"
    ];
  };
}
