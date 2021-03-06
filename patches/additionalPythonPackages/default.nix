{ stdenv
, pythonPackages
, pkgs
}:


let

    self = pythonPackages;

in
 rec {

    # For a given list of python modules
    # return all there dependencies
    # based on pythonPackages.requiredPythonModules
    #
    getPyModRec = drvs: with pkgs.lib; let
        filterNull = list: filter (x: !isNull x) list;
        conditionalGetRecurse = attr: condition: drv: let f = conditionalGetRecurse attr condition; in
          (if (condition drv) then unique [drv]++(concatMap f (filterNull(getAttr attr drv))) else []);
        _required = drv: conditionalGetRecurse "propagatedBuildInputs" self.hasPythonModule drv;
      in (unique (concatMap _required (filterNull drvs)));


    # function able to gather recursively all the python dependencies of a nix python package
    # it returns the dependencies as a list [ a b c ]
    # used to generate module containing all the necessary python dependencies
    gatherPythonRecDep  = x: let
                                isPythonModule = drv: if (drv.drvAttrs ? pythonPath) then true else false;

                                getPropDepNative = drv: if ( drv.drvAttrs ? propagatedNativeBuildInputs != null)
                                                    then  drv.drvAttrs.propagatedNativeBuildInputs
                                                    else [];
                                getPropDepTarget = drv: if ( drv.drvAttrs ? propagatedBuildInputs != null)
                                                    then  drv.drvAttrs.propagatedBuildInputs
                                                    else [];

                                getPropDep = drv: (getPropDepNative drv) ++ (getPropDepTarget drv);


                                recConcat = deps: if ( deps == [] ) then []
                                                  else [ (builtins.head deps) ] ++ (recConcat (getPropDep (builtins.head deps) ) )
                                                        ++ (recConcat (builtins.tail deps));

                                allRecDep = recConcat ( getPropDep x);

                                allPythonRecDep = builtins.filter isPythonModule allRecDep;

                            in  allPythonRecDep;

  pythonAtLeast = stdenv.lib.versionAtLeast self.python.pythonVersion;

  callPackage = pkgs.newScope self;

  bootstrapped-pip =  callPackage ./bootstrapped-pip { };

  bb5 = self.buildPythonPackage (rec {
    name = "bb5";
    version = "0.2";
    src = pkgs.fetchgitPrivate {
        url = "git@github.com:BlueBrain/pybb5.git";
        rev = "aa26310a3a12db2b583d2e0d614a1e67e9b2a84a";
        sha256 = "1q5gq9xwqkm1j82nvy199vdiw2cd63h5xvyacf7ags4cqcq4n21z";
        leaveDotGit = true;
    };

    buildInputs = with pythonPackages; [
      coverage
      freezegun
      mock
      pep8
      pkgs.git
      pycodestyle
      pyscaffold
      pytest
      pytestcov
      pytest-mock
      setuptools_scm
      sphinx
      vcrpy
    ];

    propagatedBuildInputs = with pythonPackages; [
      clustershell
      docopt
      matplotlib
      pandas
      requests
      seaborn
      six
    ];
  });

  basalt = self.buildPythonPackage rec {
    name = "basalt-${version}";
    version = "0.1.1";
    src = pkgs.fetchgitPrivate {
      url = "git@github.com:tristan0x/basalt.git";
      rev = "v${version}";
      sha256 = "1pw50bq0iz79i4a3rs0rbkx2ka1viiv77q52yj14jzq65f9hrj72";
    };

    buildInputs = with self; [
      cached-property
      pkgs.cmake
      pkgs.gbenchmark
      pkgs.rocksdb
      self.docopt
      self.h5py
      self.humanize
      self.numpy
      progress
    ];

    propagatedBuildInputs = [
      cached-property
      self.docopt
      self.h5py
      self.humanize
      self.numpy
      progress
    ];
  };

  cmake_format = self.buildPythonPackage rec {
    name = "cmake_format-${version}";
    version = "0.4.5";
    src = pkgs.fetchurl {
      url = "mirror://pypi/c/cmake_format/${name}.tar.gz";
      sha256 = "0nl78yb6zdxawidp62w9wcvwkfid9kg86n52ryg9ikblqw428q0n";
    };
    buildInputs = with pythonPackages; [
      pyyaml
    ];
    doCheck = false;
  };

  pyscaffold = self.buildPythonPackage rec {
    name = "PyScaffold-${version}";
    version = "2.5.11";
    src = pkgs.fetchurl {
      url = "mirror://pypi/p/pyscaffold/${name}.tar.gz";
      sha256 = "0qgf13vd594gqi6ssvai3hcr03akn9a7nrj9ar1xqm71426sfaqc";
    };

    buildInputs = with pythonPackages; [
      six
    ];

    doCheck = false;
  };

  bokeh = callPackage ./bokeh {};

    funcsigs1_0_2 = self.buildPythonPackage rec {
        name = "funcsigs-1.0.2";

        src = pkgs.fetchurl {
          url = "mirror://pypi/f/funcsigs/${name}.tar.gz";
          sha256 = "0l4g5818ffyfmfs1a924811azhjj8ax9xd1cffr1mzd3ycn0zfx7";
        };

        buildInputs = with self; [
          unittest2
        ];

        doCheck = false;
    };

    rtree = self.buildPythonPackage (rec {
        name = "rtree-${version}";
        version = "0.8.3";

        src = pkgs.fetchurl {
          url = "mirror://pypi/r/rtree/Rtree-${version}.tar.gz";
          sha256 = "0jc62jbcqqpjcwcly7l9zk25bg72mrxmjykpvfiscgln00qczfbc";
        };

        patchPhase = ''
            sed -i 's@/usr/local@${pkgs.libspatialindex}@g' setup.cfg;
            sed -i "s@find_library(.*@'${pkgs.libspatialindex}/lib/libspatialindex_c.so'@g" rtree/core.py
        '';

        doCheck = false; # UTF-8 tests fails on python2


        buildInputs = with self; [ unittest2 pkgs.libspatialindex numpy ];
        propagatedBuildInputs = with self; [ pkgs.libspatialindex ];

    });

    cached-property = pythonPackages.buildPythonPackage rec {
      name = "cached-property-${version}";
      version = "1.5.1";
      src = pkgs.fetchurl {
        url = "mirror://pypi/c/cached-property/${name}.tar.gz";
        sha256 = "010m1bl380l2r3vwq24r5v14l6gwvgm9v0mqqjkjss552jgsa5wj";
      };
      buildInputs = with pythonPackages; [
        freezegun
      ];
    };

    certifi17 = pythonPackages.buildPythonPackage rec {
      name = "certifi-${version}";
      version = "2017.11.5";
      src = pkgs.fetchurl {
        url = "mirror://pypi/c/certifi/${name}.tar.gz";
        sha256 = "1h0k6sy3p4csfdayghg2wjbnb1hfz27i5qbr0c7v8dhira8l5isy";
      };
    };

    clustershell = pythonPackages.buildPythonPackage rec {
      name = "ClusterShell-${version}";
      version = "1.8";
      src = pkgs.fetchurl {
        url = "mirror://pypi/c/clustershell/${name}.tar.gz";
        sha256 = "1bm0pq8w2rql9q9i2bhs865rqvb6zck3h3gkb1d0mh59arrr7p4m";
      };
      propagatedBuildInputs = with self; [
        pyyaml
      ];
    };

    cookiecutter = pythonPackages.buildPythonPackage rec {
      name = "cookiecutter-${version}";
      version = "1.6.0";
      src = pkgs.fetchurl {
        url = "mirror://pypi/c/cookiecutter/${name}.tar.gz";
        sha256 = "0glsvaz8igi2wy1hsnhm9fkn6560vdvdixzvkq6dn20z3hpaa5hk";
      };

      propagatedBuildInputs = with self; [
        binaryornot
        click
        freezegun
        future
        jinja2-time
        poyo
        pytest
        requests
        whichcraft
      ];
    };

    hpcbench = pythonPackages.buildPythonPackage rec {
      name = "hpcbench-${version}";
      version = "0.10";
      src = pkgs.fetchurl {
       url = "mirror://pypi/h/hpcbench/${name}.tar.gz";
       sha256 = "1kzsjdchzad73djgzm4jgm1jrpbg1cnrq0q7mplamc12g0bmgvwm";
      };
      # # For development purpose, and add "pkgs.git" dependency
      # src = pkgs.fetchgit {
      #   url = "https://github.com/tristan0x/hpcbench.git";
      #   rev = "65e1f0dc65e3c874a69164d93096e533cc2bbdd8";
      #   sha256 = "00q97hvjs13r1w5bnhak1lphy3wxml1vl3qd2v7z3zadr5jvb5lm";
      #   leaveDotGit = true;
      # };
      propagatedBuildInputs = with self; [
        cached-property
        clustershell
        cookiecutter
        docopt
        jinja2
        mock
        numpy
        py-elasticsearch
        python_magic
        pyyaml
        setuptools_scm
        six
        pkgs.git
      ];

      # TODO: enable tests
      doCheck = false;
    };

    idna_2_6 = pythonPackages.buildPythonPackage rec {
      name = "idna-${version}";
      version = "2.6";
      src = pkgs.fetchurl {
        url = "mirror://pypi/i/idna/${name}.tar.gz";
        sha256 = "13qaab6d0s15gknz8v3zbcfmbj6v86hn9pjxgkdf62ch13imssic";
      };
    };

    jinja2 = pythonPackages.buildPythonPackage rec {
      pname = "Jinja2";
      version = "2.10";
      name = "${pname}-${version}";

      src = pythonPackages.fetchPypi {
        inherit pname version;
        sha256 = "190l36hfw3wb2n3n68yacjabxyb1pnxwn7vjx96cmjj002xy2jzq";
      };

      buildInputs = with pythonPackages; [
        pytest
      ];

      propagatedBuildInputs = with pythonPackages; [
        markupsafe
      ];

      checkPhase = ''
        pytest
      '';
    };

    jinja2-cli = pythonPackages.buildPythonPackage rec {
      pname = "jinja2-cli";
      version = "0.6.0";
      name = "${pname}-${version}";

      src = pythonPackages.fetchPypi {
        inherit pname version;
        sha256 = "1dr7ciiic8vahizrh9jxg67adhxz7q6kyp100bgk7wd8x1yf26sb";
      };

      propagatedBuildInputs = with self; [
        jinja2
        pyyaml
        xmltodict
      ];

      # TODO: enable tests
      doCheck = false;
    };

    jinja2-time = pythonPackages.buildPythonPackage rec {
      pname = "jinja2-time";
      version = "0.2.0";
      name = "${pname}-${version}";

      src = pythonPackages.fetchPypi {
        inherit pname version;
        sha256 = "0h0dr7cfpjnjj8bgl2vk9063a53649pn37wnlkd8hxjy656slkni";
      };

      buildInputs = with pythonPackages; [
        freezegun
        pytest
      ];

      propagatedBuildInputs = with pythonPackages; [
        arrow
        dateutil
        jinja2
      ];

      checkPhase = ''
        pytest
      '';
    };

    poyo = pythonPackages.buildPythonPackage rec {
      name = "poyo-${version}";
      version = "0.4.1";
      src = pkgs.fetchurl {
        url = "mirror://pypi/p/poyo/${name}.tar.gz";
        sha256 = "1mjjyc4siq8p44d5ciln0ykf5cldh8zy9aqwzsc50xn7w7ilwfqh";
      };
    };

    progress = pythonPackages.buildPythonPackage rec {
      name = "progress-${version}";
      version = "1.4";
      src = pkgs.fetchurl {
        url = "mirror://pypi/p/progress/${name}.tar.gz";
        sha256 = "12p5za4j243p53n2rg6z8b7qk595zpp3rvpvzxv6l8yqisl9sbsy";
      };
    };

    py-elasticsearch = pythonPackages.buildPythonPackage rec {
        name = "elasticsearch-${version}";
        version = "6.0.0";
        src = pkgs.fetchurl {
            url = "mirror://pypi/e/elasticsearch/${name}.tar.gz";
            sha256 = "029q603g95fzkh87xkbxxmjfq5s9xkr9y27nfik6d4prsl0zxmlz";
        };
        propagatedBuildInputs = with self; [ urllib3 ];
        doCheck = false;
    };

    python-libsbml = pythonPackages.buildPythonPackage rec {
        name = "python-libsbml-${version}";
        version = "5.17.0";
        src = pkgs.fetchurl {
            url = "mirror://pypi/p/python-libsbml/${name}.tar.gz";
            sha256 = "1zpcbka3r7zfrhrizhhbk0jkan1dd4cwp6zzbwvfk5d3i22vcx1i";
        };
    };

    python_magic = pythonPackages.buildPythonPackage rec {
      name = "python-magic-0.4.15";

      src = pkgs.fetchurl {
        url = "mirror://pypi/p/python-magic/${name}.tar.gz";
        sha256 = "1mgwig9pnzgkf86q9ji9pnc99bngms15lfszq5rgqb9db07mqxpk";
      };

      propagatedBuildInputs = with self; [ pkgs.file ];

      patchPhase = ''
        substituteInPlace magic.py --replace "ctypes.util.find_library('magic')" "'${pkgs.file}/lib/libmagic${stdenv.hostPlatform.extensions.sharedLibrary}'"
      '';

      doCheck = false;

      # TODO: tests are failing
      #checkPhase = ''
      #  ${python}/bin/${python.executable} ./test.py
      #'';

      meta = {
        description = "A python interface to the libmagic file type identification library";
        homepage = https://github.com/ahupp/python-magic;
      };
    };

    whichcraft = pythonPackages.buildPythonPackage rec {
        name = "whichcraft-${version}";
        version = "0.4.1";
        src = pkgs.fetchurl {
            url = "mirror://pypi/w/whichcraft/${name}.tar.gz";
            sha256 = "1zapij0ggmwp8gmr3yc4fy7pbnh3dag59nvyigrfkdvw734m23cy";
        };
        buildInputs = with pythonPackages; [
          pytest
        ];
    };

    tqdm =  pythonPackages.buildPythonPackage rec {
        name = "tqdm-${version}";
        version = "v4.10.0";

        src = pkgs.fetchFromGitHub {
            owner = "tqdm";
            repo = "tqdm";
            rev = "bbf08db39931fd6cdff5f8ab42e54148f8b4faa4";
            sha256 = "08vfbc1x64mgsc9z1zxaq8gdnnvx2y29p91s6r9j1bg7g9vv6w33";

        };

        buildInputs = [ pythonPackages.coverage pythonPackages.flake8 pythonPackages.nose ];

    };


    nose_xunitmp = pythonPackages.buildPythonPackage rec {
        name = "nose_xunitmp-${version}";
        version = "0.4";

        src = pkgs.fetchurl {
            url = "https://pypi.python.org/packages/86/cc/ab61fd10d25d090e80326e84dcde8d6526c45265b4cee242db3f792da80f/nose_xunitmp-0.4.0.tar.gz";
            sha256 = "10p363s46ddm2afl4mql7yxkrrc2g4mshprzglq8lyqf3yycig7k";
        };

        buildInputs = with pythonPackages; [ nose ];

    };

    nose_testconfig = pythonPackages.buildPythonPackage rec {
        name = "nose_testconfig-${version}";
        version = "0.10";

        src = pkgs.fetchurl {
            url = "https://pypi.python.org/packages/a0/1a/9bb934f1274715083cfe8139d7af6fa78ca5437707781a1dcc39a21697b4/nose-testconfig-0.10.tar.gz";
            sha256 = "1j4l3a77pwq6wgc5gfmhh52jba4sy9vbmy8sldxqg3wfxqh8lcjl";
        };

        buildInputs = with pythonPackages; [ nose ];

    };


    deepdish = pythonPackages.buildPythonPackage rec {
        name = "deepdish-${version}";
        version = "0.3.4";

        src = pkgs.fetchurl {
            url = "mirror://pypi/d/deepdish/${name}.tar.gz";
            sha256 = "198r0h27d8d0ikk79h2xc4jpaw2n602kpjvbm6mzx29l7zyr6f52";
        };

        buildInputs = with self; [ simplegeneric tables scipy pandas six ];

        propagatedBuildInputs = with self; [ scipy tables ];

        doCheck = false;

        passthru = {

        };

    };

    elephant = pythonPackages.buildPythonPackage rec {
        name = "elephant-${version}";
        version = "0.4.1";

        src = pkgs.fetchurl {
            url = "mirror://pypi/e/elephant/${name}.tar.gz";
            sha256 = "10dc5v4ff2qsywlwnfnpagayqhjvrn6p6lbgpak0kp5crd21mcl6";
        };

        buildInputs = with self; [ scipy six quantities neo ];

        propagatedBuildInputs = with self; [ scipy  six quantities neo ];

    };

    efel = pythonPackages.buildPythonPackage rec {
        name = "efel-${version}";
        version = "3.0.22";

        src = pkgs.fetchurl {
            url = "mirror://pypi/e/efel/${name}.tar.gz";
            sha256 = "18k4014m91gkh5zxvl7mjd74rrkcjcgbnfc5kr0ws4jv8ahc3clp";
        };


        propagatedBuildInputs = with self; [ scipy neo six ];

    };

    neuronpy = pythonPackages.buildPythonPackage rec {
        name = "neuronpy-${version}";
        version = "0.1.6";

        src = pkgs.fetchurl {
            url = "mirror://pypi/n/neuronpy/${name}.tar.gz";
            sha256 = "1clhc2b5fy2l8nfrji4dagmj9419nj6kam090yqxhq5c28sngk25";
        };


        propagatedBuildInputs = with self; [ scipy neo six ];

    };


    peewee = self.buildPythonPackage rec {
     name = "peewee-${version}";
     version = "2.10.2";

     src = pkgs.fetchurl {
         url = "mirror://pypi/p/peewee/peewee-${version}.tar.gz";
         sha256 = "10f2mrd5hw6rjklrzaix2lsxlgc8vx3xak54arcy6yd791zhchi3";
     };

     propagatedBuildInputs = with self; [ cython ];
    };


    neo = pythonPackages.buildPythonPackage rec {
        name = "neo-${version}";
        version = "0.5.1";

        src = pkgs.fetchurl {
            url = "mirror://pypi/n/neo/${name}.tar.gz";
            sha256 = "1yw0xlsyxglgvqqlp18wk197vhnslbr2pwaiv4nljljv7m3fqa32";
        };

        buildInputs = with self; [ scipy quantities ];

        propagatedBuildInputs = with self; [ scipy quantities ];

    };


  cov_core = pythonPackages.buildPythonPackage rec {
    pname = "cov-core";
    version = "1.15.0";
    name = "${pname}-${version}";

    src = pkgs.fetchurl {
        url = "mirror://pypi/${builtins.substring 0 1 pname}/${pname}/${name}.tar.gz";
        sha256 = "0k3np9ymh06yv1ib96sb6wfsxjkqhmik8qfsn119vnhga9ywc52a";
      };

    buildInputs = with self; [ coverage ];
  };

  tensorflow-tensorboard = callPackage ./tensorflow-tensorboard { };

  tensorflow =
    if stdenv.isDarwin
    then callPackage ./tensorflow/bin.nix {
    }
    else callPackage ./tensorflow rec {
      cudaSupport = pkgs.config.cudaSupport or false;
      inherit (pkgs.linuxPackages) nvidia_x11;
      cudatoolkit = pkgs.cudatoolkit9;
      cudnn = pkgs.cudnn_cudatoolkit9;
      inherit tensorflow-tensorboard absl-py;
    };

    absl-py = pythonPackages.buildPythonPackage rec {
      pname = "absl-py";
      version = "0.2.0";
      name = "${pname}-${version}";

      src = pkgs.fetchurl {
        url = "mirror://pypi/${builtins.substring 0 1 pname}/${pname}/${name}.tar.gz";
        sha256 = "1v1pxyc715zyba9axw97lg3jcwiajqq50s26b7cm8zdraj2dimvk";
      };

      propagatedBuildInputs = with self; [ six ];

      # checks use bazel; should be revisited
      doCheck = false;

      meta = {
        description = "Abseil Python Common Libraries";
        homepage = "https://github.com/abseil/abseil-py";
        license = stdenv.lib.licenses.asl20;
        maintainers = with stdenv.lib.maintainers; [ danharaj ];
      };
    };


  tensorflowWithoutCuda = tensorflow.override {
    cudaSupport = false;
  };

  tensorflowWithCuda = tensorflow.override {
    cudaSupport = true;
  };

  lazy = pythonPackages.buildPythonPackage rec {
    version = "1.3";
    name = "lazy-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/l/lazy/${name}.zip";
      sha256 = "0gcfwv411rng9c0kpild11qq5wzyzq690nc76wkppfh6f6zpf2n8";
    };
  };


  lazy_property = pythonPackages.buildPythonPackage rec {
    version = "0.0.1";
    name = "lazy-property-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/l/lazy-property/${name}.tar.gz";
      sha256 = "100iggkgnm90k3zgylsdj3ahk9hmjhb9wmms663lc8xk95lx671s";
    };

    propagatedBuildInputs = with self; [ simplegeneric ];

  };

  keras = pythonPackages.buildPythonPackage rec {
    version = "2.1.1";
    name = "Keras-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/k/keras/${name}.tar.gz";
      sha256 = "08siyp456avryhpj7dhwg39plc4m2yrk04i9ykni35qdqrc29jph";
    };

    propagatedBuildInputs = with self; [
      numpy
      pyyaml
      scipy
      six
    ];
  };

  py4j_0_10_7 = pythonPackages.buildPythonPackage rec {
    version = "0.10.7";
    name = "py4j-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/p/py4j/${name}.zip";
      sha256 = "199zhq7csaj3y9zw67sz201pn56m3mm7qbpv5lhjhz9sddhqj4bj";
    };
  };

  pypandoc = pythonPackages.buildPythonPackage rec {
    version = "1.4";
    name = "pypandoc-${version}";

    src = pkgs.fetchurl {
      url = "mirror://pypi/p/pypandoc/${name}.tar.gz";
      sha256 = "0nqsq43jzjf2f8w2kdfby0jqfc33knq0kng4hx47cxjaz3ayc579";
    };

    propagatedBuildInputs = with self; [
      pkgs.pandoc
      bootstrapped-pip
      wheel
    ];

    doCheck = false;
  };

  pyarrow = callPackage ./pyarrow {
    arrow = pkgs.arrow;
    parquet-cpp = pkgs.parquet-cpp;
  };

  pyspark = pythonPackages.buildPythonPackage rec {
    version = "2.3.2-rc2";
    name = "pyspark-${version}";

    src = pkgs.fetchurl {
      url = "https://github.com/matz-e/bbp-spark/releases/download/v2.3.2-rc2/pyspark-2.3.2-rc2-patched.tgz";
      sha256 = "0ngszlrbx3iz4qbc28pf62qvfdmr21jyawsb2cy8829haj3vmij5";
    };

    propagatedBuildInputs = with self; [
      py4j_0_10_7
      pyarrow
      pypandoc
      setuptools
      simplegeneric
    ];

    doCheck = false;
  };

  sphinx_1_3 = self.sphinx.overridePythonAttrs rec {
    pname = "Sphinx";
    name = "${pname}${version}";
    version = "1.3.6";
    src = pkgs.fetchurl {
      url = "mirror://pypi/s/sphinx/Sphinx-1.3.6.tar.gz";
      sha256 = "0b3be9221220af36090d139192347bb5f42b13401e4c53a4de8f5329a7a3ff8a";
    };

    buildInputs = with pythonPackages; [ sphinx_rtd_theme ];
  };

  sparkmanager = pythonPackages.buildPythonPackage rec {
    version = "0.7.0";
    pname = "sparkmanager";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1nf7iv9fdx46ffd0yq554xal66hn2kqv49iw55q7jnciij5p4n2q";
    };

    preConfigure = ''
        sed -i "/pytest-runner/d" setup.py
    '';

    propagatedBuildInputs = with self; [
      pyspark
      setuptools
      setuptools_scm
      six
    ];

    doCheck = false;
  };

  jprops = pythonPackages.buildPythonPackage rec {
    version = "2.0.2";
    pname = "jprops";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0b2v7m6pw9kb2qyp8qani7r1g63zi8agwj1ak0zhmkdn6cc275yj";
    };

    doCheck = false;
  };

  funcsigs = pythonPackages.buildPythonPackage rec {
    version = "1.0.2";
    pname = "funcsigs";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0l4g5818ffyfmfs1a924811azhjj8ax9xd1cffr1mzd3ycn0zfx7";
    };

    doCheck = false;
  };

  hdfs = pythonPackages.buildPythonPackage rec {
    version = "2.1.0";
    pname = "hdfs";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1ijbnhcnrrk2wdsvgwf3sxfl0mqvn871391kgcjc7d83rfffj3x4";
    };

    propagatedBuildInputs = with self; [
      docopt
      requests
      six
    ];

    doCheck = false;
  };

  snakebite = pythonPackages.buildPythonPackage rec {
    version = "2.11.0";
    pname = "snakebite";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "12lpmq2s4934r0n4nl3w6c63vb1nx56pkmb2xrccdfacjjs3hlh8";
    };

    preConfigure = ''
        sed -i "s@\s*'argparse']@]@g" setup.py
    '';

    propagatedBuildInputs = with self; [
      argparse
      protobuf
    ];

    doCheck = false;
  };

  scikit-learn = callPackage ./scikit-learn {
    blas = pkgs.openblasCompat;
  };

  scikit-optimize = callPackage ./scikit-optimize {
	inherit scikit-learn;
  };


  pyzmq4 = (pythonPackages.pyzmq.overrideDerivation ( oldAttr: {
        buildInputs =  ( stdenv.lib.remove pkgs.zeromq3 oldAttr.buildInputs ) ++  [ pkgs.zeromq4 pythonPackages.pytest pythonPackages.tornado ];

        propagatedBuildInputs =  ( stdenv.lib.remove pkgs.zeromq3 oldAttr.propagatedBuildInputs ) ++ [ pkgs.zeromq4 pythonPackages.pytest pythonPackages.tornado ];

  }));

  jsonpath_ng = pythonPackages.buildPythonPackage rec {
    version = "1.4.2";
    name = "jsonpath_ng-${version}";

    src = pkgs.fetchFromGitHub {
      owner = "h2non";
      repo = "jsonpath-ng";
      rev = "78868574750184b7540b6f7e401fa8624dbe2980";
      sha256 = "0kpdlz5z0qx63cgkpr6v9bahmla96svdvgj319qa3ywhzfpim35v";
    };

    buildInputs = with pythonPackages; [];
    propagatedBuildInputs = with pythonPackages; [
      tornado
      ply
      six
      decorator
    ];

    doCheck = false;
  };

  jsonschema-objets = pythonPackages.buildPythonPackage rec {
    version = "1.4.2";
    name = "jsonschema-objets-${version}";

    src = pkgs.fetchFromGitHub {
      owner = "cwacek";
      repo = "python-jsonschema-objects";
      rev = "5b059f5c4138b4fd55e65ea45ffd142a49d04f9d";
      sha256 = "0ap6h6cw92sf89dhvvy4vibk8qg9kps1pxcz243daa4ihnivsdnx";
    };

    preConfigure = ''
	sed -i 's@==@>=@g' requirements.txt
	sed -i 's@Markdown==@Markdown>=@g' setup.py
    '';

    buildInputs = with pythonPackages; [];

    propagatedBuildInputs = with pythonPackages; [
      jsonschema
      six
      inflection
      pandocfilters
      markdown
    ];

    doCheck = false;
  };


  equation = pythonPackages.buildPythonPackage rec {
    pname = "Equation";
    version = "1.2.01";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "075qaabmxywmkmw48zyv8cff6by4z269g1b4kg8qyx3cgp21v8n8";
    };

    propagatedBuildInputs = with pythonPackages; [ numpy scipy ];
  };

  pynrrd = pythonPackages.buildPythonPackage rec {
    pname = "pynrrd";
    version = "0.2.4";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1pkn5gxf037009wlndw08h3l45hn84ysha5c00m0a9hkz39s657i";
    };

    propagatedBuildInputs = with pythonPackages; [ numpy ];
  };

  luigi = pythonPackages.buildPythonPackage rec {
    pname = "luigi";
    version = "2.7.2";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "02z0cn1zwxnady47g7kxp3q8v69v0v3ayqaam76f4jhg22wd475p";
    };

    propagatedBuildInputs = with pythonPackages; [ pythondaemon tornado ];

    # TODO: enable tests
    doCheck = false;
  };

    metis = pythonPackages.buildPythonPackage rec {
        pname = "metis";
        version = "0.2a4";
        name = "${pname}-${version}";

        src = pythonPackages.fetchPypi {
          inherit pname version;
          sha256 = "0kzrqzlgq4q6kg5af9mfm0rix7p7ig2lgi5j5z7557v96n3hn43x";
        };

        preConfigure = ''
            sed -i "s@'METIS_DLL'@'METIS_DLL','${pkgs.metis}/lib/libmetis.so'@g" metis.py
        '';

        propagatedBuildInputs = with pythonPackages; [ pkgs.metis ];

  };



  ratelimiter = pythonPackages.buildPythonPackage rec {
    pname = "ratelimiter";
    version = "1.2.0";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1dhz85mj5bqd2mij84ncs6pz32hgidr79hay4aqfmzaa4rbb497p";
    };

    # no tests in source tarball
    doCheck = false;
  };

  configargparse = pythonPackages.buildPythonPackage rec {
    pname = "ConfigArgParse";
    version = "0.13.0";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "126pblafvr54sa111rg1yvgl5mqg4bifa22q0lid3lr3isjili76";
    };

    propagatedBuildInputs = with pythonPackages; [
      pyyaml
    ];

    # one test failing (??)
    doCheck = false;
  };

  snakemake = pythonPackages.buildPythonPackage rec {
    pname = "snakemake";
    version = "4.6.0";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0jri4mp7zb6msv60n8rmq672i07mywsdbjal7xva4cwjqm7f9qn5";
    };

    propagatedBuildInputs = with pythonPackages; [
      wrapt
      requests
      ratelimiter
      pyyaml
      configargparse
      appdirs
    ];

    # no tests in source tarball
    doCheck = false;
  };

  tess = pythonPackages.buildPythonPackage rec {
    pname = "tess";
    version = "0.2.2";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0j2ih1j6rysy234ghca9axnhscp17ap2alwgr5irn3caii8231p8";
    };

    buildInputs = with pythonPackages; [
      cython
      nose
    ];

    propagatedBuildInputs = with pythonPackages; [
    ];

    doCheck = false;
  };

  numpy-quaternion = pythonPackages.buildPythonPackage rec {
    pname = "numpy-quaternion";
    version = "2018.7.5.21.55.13";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1rqwcd1dhfgld2p2z9r5g1764pcdafljj7my42wj6gs3k04bf226";
    };

    buildInputs = with pythonPackages; [
      pytest
    ];

    propagatedBuildInputs = with pythonPackages; [
      numpy
    ];

    checkPhase = ''
      pytest
    '';
  };

  transforms3d = pythonPackages.buildPythonPackage rec {
    pname = "transforms3d";
    version = "0.3.1";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0y4dm1xrd9vlrnz5dzym8brww5smzh0ij223h35n394aqybpfk20";
    };

    buildInputs = with pythonPackages; [
      nose
    ];

    propagatedBuildInputs = with pythonPackages; [
      numpy
    ];

    checkPhase = ''
      nosetests transforms3d
    '';
  };

  add-site-dir = stdenv.mkDerivation rec {
    name = "register-site-packages";
    site-packages = pythonPackages.python.sitePackages;

    buildCommand = ''
        mkdir -p "$out/${site-packages}"
        cat <<EOF >"$out/${site-packages}/sitecustomize.py"
import site
import os
site.addsitedir(os.path.dirname(os.path.abspath(__file__)))
EOF
    '';
  };


  scoop = pythonPackages.buildPythonPackage rec {
    pname = "scoop";
    version = "0.7.1.1";
    name = "${pname}-${version}";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "1d32ra1q1zaiank65qal0c33zrnx87i9fyijwdqi345cgd649dnq";
    };

	preConfigure = ''
		sed -i "s@'argparse>=1.1',@@g" setup.py
	'';

    propagatedBuildInputs = with pythonPackages; [
      pyzmq
      greenlet
      argparse
    ];

  };

    deap = pythonPackages.buildPythonPackage rec {
		pname = "deap";
		version = "1.2.2";
		name = "${pname}-${version}";

		src = pkgs.fetchFromGitHub {
		  owner = "DEAP";
	      repo = "deap";
		  rev = version;
		  sha256 = "0xwvj1s4bhh7cp0x0f416bfyalgxhl9km8nnyvxldxj475xkdbbf";
		};


		propagatedBuildInputs = with pythonPackages; [

		];

  };

  gcovr = pythonPackages.buildPythonPackage rec {
    name = "gcovr-${version}";
    version = "3.4";

    src = pkgs.fetchurl {
      url = "mirror://pypi/g/gcovr/${name}.tar.gz";
      sha256 = "05fn8p96wdzqx1wspdh0cw1didjc36gk9ypwcnqfyv0yic21n9f9";
    };

    meta = {
      description = "A Python script for summarizing gcov data";
      license = "BSD";
    };
  };

  attrs = pythonPackages.buildPythonPackage rec {
    name = "${pname}-${version}";
    pname = "attrs";
    version = "18.2.0";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0s9ydh058wmmf5v391pym877x4ahxg45dw6a0w4c7s5wgpigdjqh";
    };

    # macOS needs clang for testing
    buildInputs = with self; [
      pytest hypothesis zope_interface pympler coverage six
    ] ++ stdenv.lib.optionals (stdenv.isDarwin) [ clang ];

    checkPhase = ''
      py.test
    '';

    meta = with stdenv.lib; {
      description = "Python attributes without boilerplate";
      homepage = https://github.com/hynek/attrs;
      license = licenses.mit;
    };
  };

  rpy2 = pythonPackages.buildPythonPackage rec {
    version = if pythonPackages.isPy27 then
      "2.8.6" # python2 support dropped in 2.9.x
    else
      "2.9.4";
    pname = "rpy2";
    disabled = pythonPackages.isPyPy;
    src = pythonPackages.fetchPypi {
      inherit version pname;
      sha256 = if self.isPy27 then
        "162zki5c1apgv6qbafi7n66y4hgpgp43xag7q75qb6kv99ri6k80" # 2.8.x
      else
        "0bl1d2qhavmlrvalir9hmkjh74w21vzkvc2sg3cbb162s10zfmxy"; # 2.9.x
    };
    buildInputs = with pkgs; [
      readline
      R
      pcre
      lzma
      bzip2
      zlib
      icu
    ];
    propagatedBuildInputs = with pythonPackages; [
      singledispatch
      six
      jinja2
    ];
    checkInputs = [ pythonPackages.pytest ];
    # Tests fail with `assert not _relpath.startswith('..'), "Path must be within the project"`
    # in the unittest `loader.py`. I don't know what causes this.
    doCheck = false;
    # without this tests fail when looking for libreadline.so
    LD_LIBRARY_PATH = stdenv.lib.makeLibraryPath buildInputs;

    meta = {
      homepage = http://rpy.sourceforge.net/rpy2;
      description = "Python interface to R";
      license = stdenv.lib.licenses.gpl2Plus;
      platforms = stdenv.lib.platforms.linux;
      maintainers = with stdenv.lib.maintainers; [ joelmo ];
    };
  };

  neurotools = pythonPackages.buildPythonPackage rec {
    pname = "NeuroTools";
    version = "0.3.1";
    disabled = pythonPackages.isPy3k;

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0ly6qa87l3afhksab06vp1iimlbm1kdnsw98mxcnpzz9q07l4nd4";
    };

    patches = [
      ./neurotools.patch
    ];

    # Tests are not automatically run
    # Many tests fail (using py.test), and some need R
    doCheck = false;

    propagatedBuildInputs = with pythonPackages; [
      scipy
      numpy
      matplotlib
      tables
      pyaml
      urllib3
      rpy2
      mpi4py
    ];

    meta = with stdenv.lib; {
      description = "Collection of tools to support analysis of neural activity";
      homepage = https://pypi.python.org/pypi/NeuroTools;
      license = licenses.gpl2;
      maintainers = with maintainers; [ nico202 ];
    };
  };

  colorspacious = self.buildPythonPackage rec {
    name = "colorspacious-${version}";
    version = "1.1.2";
    src = pkgs.fetchurl {
      url = "mirror://pypi/c/colorspacious/${name}.tar.gz";
      sha256 = "065n24zbm9ymy2gvf03vx5cggk1258vcjdaw8jn9v26arpl7542y";
    };
    buildInputs = with pythonPackages; [
      numpy
    ];
  };

  plottools = self.buildPythonPackage rec {
    name = "plottools-${version}";
    version = "0.2.0";
    src = pkgs.fetchurl {
      url = "mirror://pypi/p/plottools/${name}.zip";
      sha256 = "10h4mmdjymh34spr6h4zzv4d449w9rccgw2k95lg372sf8fzfyqj";
    };
    buildInputs = with pythonPackages; [
      numpy
      matplotlib
      colorspacious
    ];
  };
}
