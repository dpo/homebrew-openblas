class QrMumps < Formula
  desc "Parallel sparse QR factorization"
  homepage "http://buttari.perso.enseeiht.fr/qr_mumps"
  url "http://buttari.perso.enseeiht.fr/qr_mumps/releases/qr_mumps-2.0.tgz"
  sha256 "d5972d729cec04c4fcd55d7576b6a571bc321da8703953babb53126498d07fc8"

  option "without-test", "Skip build-time tests (not recommended)"

  depends_on "gcc"
  depends_on "dpo/openblas/metis" => :recommended
  depends_on "openblas"
  depends_on "scotch5" => :optional
  depends_on "dpo/openblas/starpu" => :recommended
  depends_on "pkg-config" => :build if build.with? "starpu"

  resource "cage" do
    url "https://www.cise.ufl.edu/research/sparse/MM/vanHeukelum/cage6.tar.gz"
    sha256 "044d9fdaf462faf044ed57c5856238e80ea57c164914c53f179bb442649792f9"
  end

  def make_shared(l, extra)
    if OS.mac?
      so = "dylib"
      all_load = "-Wl,-all_load"
      noall_load = "-Wl,-noall_load" # gives a warning but gfortran doesn't want this empty.
    else
      so = "so"
      all_load = "-Wl,-whole-archive"
      noall_load = "-Wl,-no-whole-archive"
    end
    system "gfortran", "-fPIC", "-shared", all_load, "#{l}.a", noall_load, "-o", "#{l}.#{so}", "-lgomp", *extra
  end

  def install
    ENV.deparallelize
    make_args = ["topdir=#{pwd}", "BUILD=qrm_build",
                 "PLAT=gnu", "ARITH=d s c z",
                 "CC=#{ENV["CC"]} -fPIC", "FC=gfortran -fPIC",
                 "LBLAS=-L#{Formula["openblas"].opt_lib} -lopenblas",
                 "LLAPACK=-L#{Formula["openblas"].opt_lib} -lopenblas"]
    libs = ["-L#{Formula["openblas"].opt_lib}", "-lopenblas"]
    cfdefs = []
    if build.with? "metis"
      libs << "-L#{Formula["metis"].opt_lib}" << "-lmetis"
      cfdefs << "-Dhave_metis"
      make_args << "LMETIS=-L#{Formula["metis"].opt_lib} -lmetis"
      make_args << "IMETIS=-I#{Formula["metis"].opt_include}"
    end
    if build.with? "scotch5"
      libs << "-L#{Formula["scotch5"].opt_lib}" << "-lscotch" << "-lscotcherr"
      cfdefs << "-Dhave_scotch"
      make_args << "LSCOTCH=-L#{Formula["scotch5"].opt_lib} -lscotch -lscotcherr"
      make_args << "ISCOTCH=-I#{Formula["scotch5"].opt_include}"
    end
    if build.with? "starpu"
      ver = Formula["starpu"].version.to_f # should be 1.2
      starpulibs = `#{Formula["pkg-config"].opt_bin}/pkg-config starpu-#{ver} --libs`.strip
      libs += starpulibs.split
      make_args << "LSTARPU=#{starpulibs}"
      make_args << "ISTARPU=-I#{Formula["starpu"].opt_include}"
    end
    make_args << "CDEFS=#{cfdefs.join(" ")}" << "FDEFS=#{cfdefs.join(" ")}"

    system "make", *make_args

    cd "qrm_build/testing" do
      system "make", *make_args
    end

    # Build shared libraries.
    cd "qrm_build/lib" do
      make_shared "libqrm_common", libs
      %w[libsqrm libdqrm libcqrm libzqrm].each do |l|
        make_shared l, (["-L.", "-lqrm_common"] + libs)
      end
    end

    so = OS.mac? ? "dylib" : "so"
    lib.install Dir["qrm_build/lib/*.a"], Dir["qrm_build/lib/*.#{so}"]
    include.install Dir["qrm_build/include/*.h"]
    (libexec/"modules").install Dir["qrm_build/include/*.mod"]
    doc.install Dir["doc/*"]
    pkgshare.install "qrm_build/examples"
    (pkgshare/"testing").install Dir["qrm_build/testing/*"]

    prefix.install "makeincs/Make.inc.gnu" # For the record.
    File.open(prefix/"make_args.txt", "w") do |f|
      f.puts(make_args.join(" ")) # Record options passed to make.
    end
  end

  def caveats; <<~EOS
    Fortran modules were installed to
      "#{libexec}/modules"
    EOS
  end

  test do
    cp_r pkgshare/"testing", testpath
    resource("cage").stage do
      (testpath/"testing").install "cage6.mtx"
    end
    cd "testing" do
      Pathname.new("matfile.txt").write <<~EOF
        1
        cage6.mtx
      EOF
      system "./dqrm_testing"
    end
  end
end
