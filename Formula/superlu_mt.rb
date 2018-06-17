class SuperluMt < Formula
  desc "Multithreaded solution of large, sparse nonsymmetric systems"
  homepage "http://crd-legacy.lbl.gov/~xiaoye/SuperLU"
  url "http://crd-legacy.lbl.gov/~xiaoye/SuperLU/superlu_mt_3.0.tar.gz"
  sha256 "e5750982dc83ac62f4da31f24638aa62dbfe3ff00f9b8b786ad2eed5f9cabf56"

  option "with-openmp", "use OpenMP instead of Pthreads interface"

  depends_on "gcc" if build.with? "openmp"
  depends_on "tcsh" if OS.linux?

  # Accelerate single precision is buggy and causes certain single precision
  # tests to fail.
  depends_on "openblas"

  def install
    ENV.deparallelize
    make_args = %W[CC=#{ENV.cc} CFLAGS=#{ENV.cflags} FORTRAN= LOADER=#{ENV.cc}]

    if build.with? "openmp"
      make_inc = "make.openmp"
      libname = "libsuperlu_mt_OPENMP.a"
      ENV.append_to_cflags "-D__OPENMP"
      make_args << "MPLIB=-fopenmp"
      make_args << "PREDEFS=-D__OPENMP -fopenmp"
    else
      make_inc = "make.pthread"
      libname = "libsuperlu_mt_PTHREAD.a"
      ENV.append_to_cflags "-D__PTHREAD"
    end
    cp "MAKE_INC/#{make_inc}", "make.inc"

    make_args << "BLASLIB=-L#{Formula["openblas"].opt_lib} -lopenblas"

    system "make", *make_args
    lib.install Dir["lib/*.a"]
    ln_s lib/libname, lib/"libsuperlu_mt.a"
    (include/"superlu_mt").install Dir["SRC/*.h"]
    pkgshare.install "EXAMPLE"
    doc.install Dir["DOC/*.pdf"]
    prefix.install "make.inc"
    File.open(prefix/"make_args.txt", "w") do |f|
      make_args.each do |arg|
        var, val = arg.split("=")
        f.puts "#{var}=\"#{val}\"" # Record options passed to make, preserve spaces.
      end
    end
  end

  def caveats; <<~EOS
    Default SuperLU_MT build options are recorded in

      #{opt_prefix}/make.inc

    Specific options for this build are in

      #{opt_prefix}/make_args.txt
    EOS
  end

  test do
    cp_r pkgshare/"EXAMPLE", testpath
    cp prefix/"make.inc", testpath
    make_args = []
    File.readlines(opt_prefix/"make_args.txt").each do |line|
      make_args << line.chomp.delete('\\"')
    end
    make_args << "HEADER=#{opt_include}/superlu_mt"
    make_args << "LOADOPTS="

    cd "EXAMPLE" do
      inreplace "Makefile", "../lib/$(SUPERLULIB)", "#{opt_lib}/libsuperlu_mt.a"
      system "make", *make_args
      # simple driver
      system "./pslinsol -p 2 < big.rua"
      system "./pdlinsol -p 2 < big.rua"
      system "./pclinsol -p 2 < cmat"
      system "./pzlinsol -p 2 < cmat"
      # expert driver
      system "./pslinsolx -p 2 < big.rua"
      system "./pdlinsolx -p 2 < big.rua"
      system "./pclinsolx -p 2 < cmat"
      system "./pzlinsolx -p 2 < cmat"
      # expert driver on several systems with same sparsity pattern
      system "./pslinsolx1 -p 2 < big.rua"
      system "./pdlinsolx1 -p 2 < big.rua"
      system "./pclinsolx1 -p 2 < cmat"
      system "./pzlinsolx1 -p 2 < cmat"
      # example with symmetric mode
      system "./pslinsolx2 -p 2 < big.rua"
      system "./pdlinsolx2 -p 2 < big.rua"
      # system "./pclinsolx2 -p 2 < cmat" # bus error
      # system "./pzlinsolx2 -p 2 < cmat" # bus error
      # example with repeated factorization of systems with same sparsity pattern
      # system "./psrepeat -p 2 < big.rua" # malloc error
      system "./pdrepeat -p 2 < big.rua"
      # system "./pcrepeat -p 2 < cmat" # malloc error
      # system "./pzrepeat -p 2 < cmat" # malloc error
      # example that integrates with other multithreaded application
      system "./psspmd -p 2 < big.rua"
      system "./pdspmd -p 2 < big.rua"
      system "./pcspmd -p 2 < cmat"
      system "./pzspmd -p 2 < cmat"
    end
  end
end
