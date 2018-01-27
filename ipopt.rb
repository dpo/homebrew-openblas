class Ipopt < Formula
  desc "Large-scale nonlinear optimization package"
  homepage "https://projects.coin-or.org/Ipopt"
  url "https://www.coin-or.org/download/source/Ipopt/Ipopt-3.12.9.tgz"
  sha256 "8ff3fe1a8560896fc5559839a87c2530cac4ed231b0806e487bfd3cf2d294ab8"
  head "https://projects.coin-or.org/svn/Ipopt/trunk", :using => :svn

  option "without-test", "Skip build-time tests (not recommended)"

  depends_on "ampl-mp"
  depends_on "gcc"
  # IPOPT is not able to use parallel MUMPS.
  depends_on "mumps" => "without-mpi"
  depends_on "openblas"
  depends_on "pkg-config" => :build

  def install
    mumps_libs = %w[-ldmumps -lmumps_common -lpord -lmpiseq]
    mumps_incdir = Formula["mumps"].opt_libexec/"include"
    mumps_libcmd = "-L#{Formula["mumps"].opt_lib} " + mumps_libs.join(" ")

    args = ["--disable-debug",
            "--disable-dependency-tracking",
            "--prefix=#{prefix}",
            "--with-mumps-incdir=#{mumps_incdir}",
            "--with-mumps-lib=#{mumps_libcmd}",
            "--enable-shared",
            "--enable-static",
            "--with-blas-incdir=#{Formula["openblas"].opt_include}",
            "--with-blas-lib=-L#{Formula["openblas"].opt_lib} -lopenblas",
            "--with-lapack-incdir=#{Formula["openblas"].opt_include}",
            "--with-lapack-lib=-L#{Formula["openblas"].opt_lib} -lopenblas",
            "--with-asl-incdir=#{Formula["ampl-mp"].opt_include}/asl",
            "--with-asl-lib=-L#{Formula["ampl-mp"].opt_lib} -lasl"]

    system "./configure", *args
    system "make"
    ENV.deparallelize # Needs a serialized install
    system "make", "test" if build.with? "test"
    system "make", "install"
  end

  test do
    # IPOPT still fails to converge on the Waechter-Biegler problem?!?!
    system "#{bin}/ipopt", "#{Formula["ampl-mp"].opt_pkgshare}/example/wb"
  end
end
