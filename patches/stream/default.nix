{ stdenv
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  name = "STREAM-${version}";
  version = "5.10";

  src = fetchFromGitHub {
    owner = "jeffhammond";
    repo = "STREAM";
    rev = "32e57a2571890b7a2b6628b5d2d4b7b3fae947b8";
    sha256 = "00r88rywxz34chl6whhpjzfbkjnb509qdjzd7bv34wi7bwvw6hwi";
  };

  passthru = {
    src = src;
  };

  meta = {
    description = "STREAM benchmark";
    longDescription = ''
      STREAM is the de facto industry standard benchmark
      for measuring sustained memory bandwidth.
      Documentation for STREAM is on the web at:
      http://www.cs.virginia.edu/stream/ref.html
    '';
  };

  postPatch = ''
    sed -e "/^CC =/d" -i Makefile
    sed -e "s/^CFLAGS =.*/CFLAGS = -mcmodel medium -shared-intel -O3 -xMIC-AVX512 -DN=134217728 -DOFFSET=0 -DNTIMES=10 -qopenmp -qopt-streaming-stores always/" -i Makefile
    sed -e "s/^FFLAGS =.*/FFLAGS = -O3/" -i Makefile
  '';

  buildFlags = "stream_c.exe";
}
