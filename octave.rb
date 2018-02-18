class Octave < Formula
  desc "High-level interpreted language for numerical computing"
  homepage "https://www.gnu.org/software/octave/index.html"
  url "https://ftp.gnu.org/gnu/octave/octave-4.2.1.tar.gz"
  mirror "https://ftpmirror.gnu.org/octave/octave-4.2.1.tar.gz"
  sha256 "80c28f6398576b50faca0e602defb9598d6f7308b0903724442c2a35a605333b"
  revision 1

  devel do
    url "https://hg.savannah.gnu.org/hgweb/octave", :revision => "d0221e3675ef", :using => :hg
    version "4.3-d0221e3675ef"
  end

  head do
    url "https://hg.savannah.gnu.org/hgweb/octave", :branch => "default", :using => :hg
  end

  # Additional dependencies for head and devel
  if build.head? || build.devel?
    depends_on "mercurial" => :build
    depends_on "bison" => :build
    depends_on "icoutils" => :build
    depends_on "librsvg" => :build
    depends_on "dpo/openblas/sundials27"
  end

  option "with-qt", "Compile with qt-based graphical user interface"
  option "without-test", "Skip compile-time make checks (Not Recommended)"

  # Complete list of dependencies at https://wiki.octave.org/Building
  depends_on "automake" => :build
  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build # https://lists.gnu.org/archive/html/octave-maintainers/2016-09/msg00193.html
  depends_on "pkg-config" => :build
  depends_on "dpo/openblas/arpack"
  depends_on "epstool"
  depends_on "fftw"
  depends_on "fig2dev"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "ghostscript"
  depends_on "gl2ps"
  depends_on "glpk"
  depends_on "gnuplot"
  depends_on "graphicsmagick"
  depends_on "hdf5"
  depends_on "libsndfile"
  depends_on "libtool" => :run
  depends_on "pcre"
  depends_on "portaudio"
  depends_on "pstoedit"
  depends_on "qhull"
  depends_on "dpo/openblas/qrupdate"
  depends_on "readline"
  depends_on "dpo/openblas/suite-sparse"
  depends_on "openblas"
  depends_on "texinfo" # http://lists.gnu.org/archive/html/octave-maintainers/2018-01/msg00016.html
  depends_on :java => ["1.8+", :optional]

  # Dependencies for the graphical user interface
  if build.with?("qt")
    depends_on "qt"
    depends_on "qscintilla2"

    if build.devel?
      # Bug #50025: "Octave window freezes when I quit Octave GUI"
      #  https://savannah.gnu.org/bugs/?50025
      patch do
        url "https://savannah.gnu.org/bugs/download.php?file_id=42886"
        sha256 "6ad49b3a569b40f17273a34fa820b8ed2161b1dedb5396976c41f221f4012b00"
      end
      # Fix bug #49053: retina scaling of figures
      # see https://savannah.gnu.org/bugs/?49053
      patch do
        url "https://savannah.gnu.org/support/download.php?file_id=43077"
        sha256 "989dc8f6c6e11590153df08c9c1ae2e7372c56cd74cd88aea6b286fe71793b35"
      end
    else
      # patches require default branch <= revision d0221e3675ef
      odie "Option '--with-qt' requires '--DEVEL'."
    end
  end

  # Dependencies use Fortran, leading to spurious messages about GCC
  cxxstdlib_check :skip

  def install
    if build.stable?
      # Remove for > 4.2.1
      # Remove inline keyword on file_stat destructor which breaks macOS
      # compilation (bug #50234).
      # Upstream commit from 24 Feb 2017 https://hg.savannah.gnu.org/hgweb/octave/rev/a6e4157694ef
      inreplace "liboctave/system/file-stat.cc",
        "inline file_stat::~file_stat () { }", "file_stat::~file_stat () { }"
      inreplace "scripts/java/module.mk",
        "-source 1.3 -target 1.3", ""
      # allow for Oracle Java (>=1.8) without requiring the old Apple Java 1.6
      # this is more or less the same as in https://savannah.gnu.org/patch/index.php?9439
      inreplace "libinterp/octave-value/ov-java.cc",
       "#if ! defined (__APPLE__) && ! defined (__MACH__)", "#if 1" # treat mac's java like others
      inreplace "configure.ac",
       "-framework JavaVM", "" # remove framework JavaVM as it requires Java 1.6 after build
    else
      # do not execute a test that may trigger a dialog to install java
      inreplace "libinterp/octave-value/ov-java.cc", "usejava (\"awt\")", "false ()"
    end

    # Default configuration passes all linker flags to mkoctfile, to be
    # inserted into every oct/mex build. This is unnecessary and can cause
    # cause linking problems.
    inreplace "src/mkoctfile.in.cc", /%OCTAVE_CONF_OCT(AVE)?_LINK_(DEPS|OPTS)%/, '""'

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-link-all-dependencies
      --enable-shared
      --disable-static
      --disable-docs
      --without-fltk
      --without-OSMesa
      --with-hdf5-includedir=#{Formula["hdf5"].opt_include}
      --with-hdf5-libdir=#{Formula["hdf5"].opt_lib}
      --with-x=no
      --with-blas=-L#{Formula["openblas"].opt_lib}\ -lopenblas
      --with-portaudio
      --with-sndfile
    ]

    args << "--without-qt" if build.without? "qt"
    args << "--disable-java" if build.without? "java"

    system "./bootstrap" unless build.stable?
    system "./configure", *args
    system "make", "all"

    if build.with? "test"
      system "make check 2>&1 | tee \"test/make-check.log\""
      # check if all tests have passed (FAIL 0)
      results = File.readlines "test/make-check.log"
      matches = results.join("\n").match(/^\s*(FAIL)\s*0/i)
      if matches.nil?
        opoo "Some tests failed. Details are given in #{opt_prefix}/make-check.log."
      end
      # install test results
      prefix.install "test/fntests.log"
      prefix.install "test/make-check.log"
    end

    # make sure that Octave uses the modern texinfo
    rcfile = buildpath/"scripts/startup/site-rcfile"
    rcfile.append_lines "makeinfo_program(\"#{Formula["texinfo"].opt_bin}/makeinfo\");"

    system "make", "install"
  end

  test do
    system bin/"octave", "--eval", "(22/7 - pi)/pi"
    # This is supposed to crash octave if there is a problem with veclibfort
    system bin/"octave", "--eval", "single ([1+i 2+i 3+i]) * single ([ 4+i ; 5+i ; 6+i])"
    # Test java bindings: check if javaclasspath is working, return error if not
    system bin/"octave", "--eval", "try; javaclasspath; catch; quit(1); end;" if build.with? "java"
  end
end
