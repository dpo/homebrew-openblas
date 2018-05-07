class Octave < Formula
  desc "High-level interpreted language for numerical computing"
  homepage "https://www.gnu.org/software/octave/index.html"
  url "ftp://ftp.gnu.org/gnu/octave/octave-4.4.0.tar.lz"
  sha256 "777542ca425f3e7eddb3b31810563eaf8d690450a4f88c79c273bd338e31a75a"

  head do
    url "https://hg.savannah.gnu.org/hgweb/octave", :branch => "default", :using => :hg
  end

  # Additional dependencies for head and devel
  if build.head? || build.devel?
    depends_on "mercurial" => :build
    depends_on "bison" => :build
    depends_on "doxygen" => :build
    depends_on "icoutils" => :build
    depends_on "librsvg" => :build
  end

  option "with-qt", "Compile with qt-based graphical user interface"
  option "with-docs", "Create documentation (requires MacTeX)"
  option "without-test", "Skip compile-time make checks (not recommended)"

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
  depends_on "gnu-tar"
  depends_on "graphicsmagick"
  depends_on "hdf5"
  depends_on "libsndfile"
  depends_on "libtool"
  depends_on "pcre"
  depends_on "portaudio"
  depends_on "pstoedit"
  depends_on "qhull"
  depends_on "dpo/openblas/qrupdate"
  depends_on "readline"
  depends_on "dpo/openblas/suite-sparse"
  depends_on "openblas"
  depends_on "dpo/openblas/sundials27"
  depends_on "texinfo" # http://lists.gnu.org/archive/html/octave-maintainers/2018-01/msg00016.html
  depends_on :java => ["1.8+", :optional]

  # Dependencies for the graphical user interface
  if build.with?("qt")
    depends_on "qt"
    depends_on "qscintilla2"

    # Fix bug #49053: retina scaling of figures
    # see https://savannah.gnu.org/bugs/?49053
    patch do
      url "https://savannah.gnu.org/support/download.php?file_id=44041"
      sha256 "bf7aaa6ddc7bd7c63da24b48daa76f5bdf8ab3a2f902334da91a8d8140e39ff0"
    end

    # Fix bug #50025: Octave window freezes
    # see https://savannah.gnu.org/bugs/?50025
    patch :DATA

  end

  # Dependencies use Fortran, leading to spurious messages about GCC
  cxxstdlib_check :skip

  def install
    # do not execute a test that may trigger a dialog to install java
    inreplace "libinterp/octave-value/ov-java.cc", "usejava (\"awt\")", "false ()"

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
      --without-fltk
      --without-OSMesa
      --with-hdf5-includedir=#{Formula["hdf5"].opt_include}
      --with-hdf5-libdir=#{Formula["hdf5"].opt_lib}
      --with-x=no
      --with-blas=-L#{Formula["openblas"].opt_lib}\ -lopenblas
      --with-portaudio
      --with-sndfile
    ]

    if build.without? "java"
      args << "--disable-java"
    end

    if build.without? "qt"
      args << "--without-qt"
    else
      args << "--with-qt=5"
    end

    if build.without? "docs"
      args << "--disable-docs"
    else
      assert_predicate "/Library/TeX/texbin/latex", :executable?, "--with-docs requires Mactex"
      ENV.prepend_path "PATH", "/Library/TeX/texbin/"
    end

    if build.stable?
      # fix aclocal version issue
      system "autoreconf", "-f", "-i"
    else
      system "./bootstrap"
    end
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

    # create empty qt help to avoid error dialog of GUI
    # if no documentation is found
    if build.without?("docs") && build.with?("qt") && !build.stable?
      File.open("doc/octave_interpreter.qhcp", "w") do |f|
        f.write("<?xml version=\"1.0\" encoding=\"utf-8\" ?>")
        f.write("<QHelpCollectionProject version=\"1.0\" />")
      end
      system "#{Formula["qt"].opt_bin}/qcollectiongenerator", "doc/octave_interpreter.qhcp", "-o", "doc/octave_interpreter.qhc"
      (pkgshare/"#{version}/doc").install "doc/octave_interpreter.qhc"
    end
  end

  test do
    system bin/"octave", "--eval", "(22/7 - pi)/pi"
    # This is supposed to crash octave if there is a problem with veclibfort
    system bin/"octave", "--eval", "single ([1+i 2+i 3+i]) * single ([ 4+i ; 5+i ; 6+i])"
    # Test java bindings: check if javaclasspath is working, return error if not
    system bin/"octave", "--eval", "try; javaclasspath; catch; quit(1); end;" if build.with? "java"
  end
end

__END__
diff --git a/libgui/src/main-window.cc b/libgui/src/main-window.cc
--- a/libgui/src/main-window.cc
+++ b/libgui/src/main-window.cc
@@ -221,9 +221,6 @@
              this, SLOT (handle_octave_ready (void)));
 
     connect (m_interpreter, SIGNAL (octave_finished_signal (int)),
              this, SLOT (handle_octave_finished (int)));
-
-    connect (m_interpreter, SIGNAL (octave_finished_signal (int)),
-             m_main_thread, SLOT (quit (void)));
 
     connect (m_main_thread, SIGNAL (finished (void)),
@@ -1536,6 +1533,9 @@
 
   void main_window::handle_octave_finished (int exit_status)
   {
+    /* fprintf to stderr is needed by macOS */
+    fprintf(stderr, "\n");
+    m_main_thread->quit();
     qApp->exit (exit_status);
   }
 
