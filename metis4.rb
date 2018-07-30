class Metis4 < Formula
  desc "Serial graph partitioning and fill-reducing ordering"
  homepage "http://glaros.dtc.umn.edu/gkhome/views/metis"
  url "http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/OLD/metis-4.0.3.tar.gz"
  sha256 "5efa35de80703c1b2c4d0de080fafbcf4e0d363a21149a1ad2f96e0144841a55"
  revision 1

  keg_only "conflicts with metis (5.x)"

  def install
    if OS.mac?
      so = "dylib"
      all_load = "-Wl,-all_load"
      noall_load = ""
    else
      so = "so"
      all_load = "-Wl,-whole-archive"
      noall_load = "-Wl,-no-whole-archive"
    end
    cd "Lib" do
      system "make", "CC=#{ENV.cc}", "COPTIONS=-fPIC"
    end
    cd "Programs" do
      system "make", "CC=#{ENV.cc}", "COPTIONS=-fPIC"
    end
    system ENV.cc, "-fPIC", "-shared", all_load.to_s, "libmetis.a", noall_load.to_s, "-o", "libmetis.#{so}"
    bin.install %w[pmetis kmetis oemetis onmetis partnmesh partdmesh mesh2nodal mesh2dual graphchk]
    lib.install "libmetis.#{so}"
    include.install Dir["Lib/*.h"]
    pkgshare.install %w[Programs/io.c Test/mtest.c Graphs/4elt.graph Graphs/4elt.graph.part.10 Graphs/metis.mesh Graphs/test.mgraph]
  end

  test do
    cp pkgshare/"io.c", testpath
    cp pkgshare/"mtest.c", testpath
    cp pkgshare/"4elt.graph", testpath
    cp pkgshare/"4elt.graph.part.10", testpath
    cp pkgshare/"test.mgraph", testpath
    cp pkgshare/"metis.mesh", testpath
    if OS.linux?
      ENV["LD_LIBRARY_PATH"] = opt_lib.to_s
    end
    system ENV.cc, "-I#{include}", "-c", "io.c"
    system ENV.cc, "-I#{include}", "mtest.c", "io.o", "-o", "mtest", "-L#{opt_lib}", "-lmetis", "-lm"
    system "./mtest", "#{opt_pkgshare}/4elt.graph"
    system "#{bin}/kmetis", "4elt.graph", "10"
    system "#{bin}/onmetis", "4elt.graph"
    system "#{bin}/pmetis", "test.mgraph", "2"
    system "#{bin}/kmetis", "test.mgraph", "2"
    system "#{bin}/kmetis", "test.mgraph", "5"
    system "#{bin}/partnmesh", "metis.mesh", "10"
    system "#{bin}/partdmesh", "metis.mesh", "10"
    system "#{bin}/mesh2dual", "metis.mesh"
  end
end
