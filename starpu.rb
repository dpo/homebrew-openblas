class Starpu < Formula
  desc "Unified Runtime System for Heterogeneous Multicore Architectures"
  homepage "http://starpu.gforge.inria.fr/"
  url "http://starpu.gforge.inria.fr/files/starpu-1.2.3/starpu-1.2.3.tar.gz"
  sha256 "295d39da17ad17752c1cb91e0009fc9b3630bc4ac7db7e2e43433ec9024dc6db"

  head do
    url "https://scm.gforge.inria.fr/anonscm/git/starpu/starpu.git"
    depends_on "automake" => :build
    depends_on "autoconf" => :build
    depends_on "libtool" => :build
    depends_on "openblas"
  end

  option "with-openmp", "Enable OpenMP multithreading"

  depends_on "gcc" if build.with? "openmp"
  depends_on "dpo/openblas/hwloc@1.11"
  depends_on "pkg-config" => :run

  fails_with :clang if build.with? "openmp"

  def install
    if build.head?
      ENV["LIBTOOL"] = "glibtool"
      system "./autogen.sh"
    end

    mkdir "build" do
      args = ["--disable-debug",
              "--disable-dependency-tracking",
              "--disable-silent-rules",
              "--enable-quick-check",
              "--disable-build-examples",
              "--without-x",
              "--prefix=#{prefix}"]
      args << "--enable-openmp" if build.with? "openmp"

      # should become standard at the next release
      args << "--enable-blas-lib=openblas" if build.head?

      system "../configure", *args
      system "make"
      # system "make", "check"
      system "make", "install"
    end
  end

  test do
    (testpath/"hello-starpu.c").write <<~EOF
      #include <stdio.h>
      static void my_task (int x) __attribute__ ((task));
      static void my_task (int x) {
        printf ("Hello, world!  With x = %d\\n", x);
      }
      int main (void) {
        #pragma starpu initialize
        my_task (42);
        #pragma starpu wait
        #pragma starpu shutdown
        return 0;
      }
    EOF

    ENV.prepend_path "PKG_CONFIG_PATH", Formula["hwloc@1.11"].opt_prefix

    ver = Formula["starpu"].version.to_f # should be 1.2
    cflags = `#{Formula["pkg-config"].opt_bin}/pkg-config starpu-#{ver} --cflags`
    libs = `#{Formula["pkg-config"].opt_bin}/pkg-config starpu-#{ver} --libs`
    system ENV["CC"], cflags, "hello-starpu.c", libs
    system "./a.out"
  end
end
