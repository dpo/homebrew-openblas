class HwlocAT111 < Formula
  desc "Portable abstraction of the hierarchical topology of modern architectures"
  homepage "https://www.open-mpi.org/projects/hwloc/"
  url "https://www.open-mpi.org/software/hwloc/v1.11/downloads/hwloc-1.11.9.tar.bz2"
  sha256 "394333184248d63cb2708a976e57f05337d03bb50c33aa3097ff5c5a74a85164"

  head do
    url "https://github.com/open-mpi/hwloc.git"
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  # fixed in master but the source tree structure changed
  # https://github.com/open-mpi/hwloc/commit/14e727976867931a2eb74f2630b0ce9137182874
  patch do
    url "https://gist.githubusercontent.com/dpo/3b421763b21b3c2120bec47a4d97ba29/raw/63c75056d8c956a8f2f80a22da73b1f2f6b7f0c8/a.rb"
    sha256 "229308e1da6ab31a8e4816602cc84d49357a07b19a582c562cb67e237c8eec42"
  end

  keg_only "conflicts with hwloc 2.0"

  depends_on "pkg-config" => :build
  depends_on "cairo" => :optional

  def install
    system "./autogen.sh" if build.head?
    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--enable-shared",
                          "--enable-static",
                          "--prefix=#{prefix}",
                          "--without-x"
    system "make", "install"

    pkgshare.install "tests"
  end

  test do
    system ENV.cc, opt_pkgshare/"tests/hwloc_groups.c", "-I#{opt_include}",
                   "-L#{opt_lib}", "-lhwloc", "-o", "test"
    system "./test"
  end
end
