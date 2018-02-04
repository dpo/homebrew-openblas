class CeresSolver < Formula
  desc "C++ library for large-scale optimization"
  homepage "http://ceres-solver.org/"
  url "http://ceres-solver.org/ceres-solver-1.13.0.tar.gz"
  sha256 "1df490a197634d3aab0a65687decd362912869c85a61090ff66f073c967a7dcd"
  head "https://ceres-solver.googlesource.com/ceres-solver.git"

  unless OS.mac?
    fails_with :gcc => "5" do
      cause "Dependency glog is compiled with the GCC 4.8 ABI."
    end
  end

  depends_on "cmake" => :run
  depends_on "eigen"
  depends_on "gflags"
  depends_on "glog"
  depends_on "dpo/openblas/metis"
  depends_on "openblas"
  depends_on "dpo/openblas/suite-sparse"

  def install
    so = OS.mac? ? "dylib" : "so"
    system "cmake", ".", *std_cmake_args,
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_LIBRARY_PATH=#{Formula["openblas"].opt_lib}",
                    "-DEIGEN_INCLUDE_DIR=#{Formula["eigen"].opt_include}/eigen3",
                    "-DMETIS_LIBRARY=#{Formula["metis"].opt_lib}/libmetis.#{so}"
    system "make"
    system "make", "install"
    pkgshare.install "examples", "data"
    doc.install "docs/html" unless build.head?
  end

  test do
    cp pkgshare/"examples/helloworld.cc", testpath
    (testpath/"CMakeLists.txt").write <<~EOS
      cmake_minimum_required(VERSION 2.8)
      project(helloworld)
      find_package(Ceres REQUIRED)
      include_directories(${CERES_INCLUDE_DIRS})
      add_executable(helloworld helloworld.cc)
      target_link_libraries(helloworld ${CERES_LIBRARIES})
    EOS

    system "cmake", "-DCeres_DIR=#{share}/Ceres", "."
    system "make"
    assert_match "CONVERGENCE", shell_output("./helloworld", 0)
  end
end
