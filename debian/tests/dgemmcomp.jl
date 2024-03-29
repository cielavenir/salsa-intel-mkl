#!/usr/bin/julia-1.0
# Compare performance among different BLAS implementations
# Copyright (C) 2018 Mo Zhou <lumin@debian.org>, MIT/Expat License.
# Reference: Julia/stdlib/LinearAlgebra/src/blas.jl
using LinearAlgebra
using Logging

const N1 = 65536  # N for level1 calls
const N3 = 4096   # N for level3 calls
const netlibblas = "/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.8.0"
const atlas      = "/usr/lib/x86_64-linux-gnu/atlas/libblas.so.3.10.3"
const openblas   = "/usr/lib/x86_64-linux-gnu/openblas/libblas.so.3"
const mkl        = "/usr/lib/x86_64-linux-gnu/libmkl_rt.so"
const nvblas     = "/usr/lib/x86_64-linux-gnu/libnvblas.so"
const blis       = "/home/lumin/git/blis/lib/haswell/libblis.so"

BLASES = [blis, openblas, mkl, nvblas]

for N3 in 2 .^ [1:13...]
	julia_dgemm = false
	@warn("Matrix size = $N3")
	for libblas in BLASES
		@eval begin
			function ffi_gemm!(transA::Char, transB::Char,
							   alpha::Float64, A::AbstractVecOrMat{Float64},
							   B::AbstractVecOrMat{Float64}, beta::Float64,
							   C::AbstractVecOrMat{Float64})
				m = size(A, transA == 'N' ? 1 : 2)
				ka = size(A, transA == 'N' ? 2 : 1)
				kb = size(B, transB == 'N' ? 1 : 2)
				n = size(B, transB == 'N' ? 2 : 1) 
				ccall((:dgemm_, $libblas), Cvoid,
					(Ref{UInt8}, Ref{UInt8}, Ref{Int64}, Ref{Int64},
					 Ref{Int64}, Ref{Float64}, Ptr{Float64}, Ref{Int64},
					 Ptr{Float64}, Ref{Int64}, Ref{Float64}, Ptr{Float64},
					 Ref{Int64}),
					 transA, transB, m, n,
					 ka, alpha, A, max(1,stride(A,2)),
					 B, max(1,stride(B,2)), beta, C,
					 max(1,stride(C,2)))
			end
		end
		x, y, z = rand(N3, N3), rand(N3, N3), zeros(N3, N3)
		if !julia_dgemm
			@info("dgemm Julia")
			BLAS.gemm('N', 'N', x, y)  # JIT
			@time BLAS.gemm('N', 'N', x, y)
			julia_dgemm = true
		end
		@info("dgemm $libblas")
		ffi_gemm!('N', 'N', 1., x, y, 0., z)  # JIT
		@time ffi_gemm!('N', 'N', 1., x, y, 0., z)

		z2 = BLAS.gemm('N', 'N', x, y)
		ffi_gemm!('N', 'N', 1., x, y, 0., z)
		error = norm(z2 - z)
		if error > 1e-7
			@warn("dgemm Error : $error")  # correctness
		end
	end
end
