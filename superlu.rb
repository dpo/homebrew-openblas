class Superlu < Formula
  desc "Solve large, sparse nonsymmetric systems of equations"
  homepage "http://crd-legacy.lbl.gov/~xiaoye/SuperLU/"
  url "http://crd-legacy.lbl.gov/~xiaoye/SuperLU/superlu_5.2.1.tar.gz"
  sha256 "28fb66d6107ee66248d5cf508c79de03d0621852a0ddeba7301801d3d859f463"

  option "with-matlab", "Build MEX files for use with Matlab"
  option "with-matlab-path=", "Directory that contains MATLAB bin and extern subdirectories"

  option "without-test", "skip build-time tests (not recommended)"
  option "with-openmp", "Enable OpenMP multithreading"

  depends_on :fortran
  depends_on "openblas"
  depends_on "tcsh" => :build unless OS.mac?

  needs :openmp if build.with? "openmp"

  def install
    ENV.deparallelize
    cp "MAKE_INC/make.mac-x", "./make.inc"
    build_args = ["RANLIB=true",
                  "SuperLUroot=#{buildpath}",
                  "SUPERLULIB=$(SuperLUroot)/lib/libsuperlu.a"]
    make_args = ["CC=#{ENV.cc}",
                 "CFLAGS=-fPIC #{ENV.cflags}",
                 "FORTRAN=#{ENV.fc}",
                 "FFLAGS=#{ENV.fcflags}",
                 "NOOPTS=-fPIC",
                 "BLASLIB=-L#{Formula["openblas"].opt_lib} -lopenblas"]

    make_args << ("LOADOPTS=" + ((build.with? "openmp") ? "-fopenmp" : ""))

    all_args = build_args + make_args
    system "make", "lib", *all_args
    if build.with? "test"
      system "make", "testing", *all_args
      cd "TESTING" do
        system "make", *all_args
        %w[stest dtest ctest ztest].each do |tst|
          ohai `tail -1 #{tst}.out`.chomp
        end
      end
    end

    cd "EXAMPLE" do
      system "make", *all_args
    end

    if build.with? "matlab"
      matlab = ARGV.value("with-matlab-path") || HOMEBREW_PREFIX
      cd "MATLAB" do
        system "make", "MATLAB=#{matlab}", *all_args
      end
    end

    prefix.install "make.inc"
    File.open(prefix/"make_args.txt", "w") do |f|
      make_args.each do |arg|
        var, val = arg.split("=", 2)
        f.puts "#{var}=\"#{val}\"" # Record options passed to make, preserve spaces.
      end
    end
    lib.install Dir["lib/*"]
    (include/"superlu").install Dir["SRC/*.h"]
    doc.install Dir["Doc/*"]
    (pkgshare/"examples").install Dir["EXAMPLE/*[^.o]"]
    (pkgshare/"matlab").install Dir["MATLAB/*"] if build.with? "matlab"
  end

  def caveats
    s = ""
    if build.with? "matlab"
      s += <<-EOS.undent
        Matlab interfaces are located in

          #{opt_pkgshare}/matlab
      EOS
    end
    s
  end

  test do
    ENV.fortran
    cp_r pkgshare/"examples", testpath
    cp prefix/"make.inc", testpath
    make_args = ["SuperLUroot=#{opt_prefix}",
                 "SUPERLULIB=#{opt_lib}/libsuperlu.a",
                 "HEADER=#{opt_include}/superlu"]
    File.readlines(opt_prefix/"make_args.txt").each do |line|
      make_args << line.chomp.delete('\\"')
    end

    cd "examples" do
      system "make", *make_args

      system "./superlu"
      system "./slinsol < g20.rua"
      system "./slinsolx  < g20.rua"
      system "./slinsolx1 < g20.rua"
      system "./slinsolx2 < g20.rua"

      system "./dlinsol < g20.rua"
      system "./dlinsolx  < g20.rua"
      system "./dlinsolx1 < g20.rua"
      system "./dlinsolx2 < g20.rua"

      system "./clinsol < cg20.cua"
      system "./clinsolx < cg20.cua"
      system "./clinsolx1 < cg20.cua"
      system "./clinsolx2 < cg20.cua"

      system "./zlinsol < cg20.cua"
      system "./zlinsolx < cg20.cua"
      system "./zlinsolx1 < cg20.cua"
      system "./zlinsolx2 < cg20.cua"

      system "./sitersol -h < g20.rua" # broken with Accelerate
      system "./sitersol1 -h < g20.rua"
      system "./ditersol -h < g20.rua"
      system "./ditersol1 -h < g20.rua"
      system "./citersol -h < g20.rua"
      system "./citersol1 -h < g20.rua"
      system "./zitersol -h < cg20.cua"
      system "./zitersol1 -h < cg20.cua"
    end
  end
end
