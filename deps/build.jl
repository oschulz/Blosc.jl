using BinaryProvider # requires BinaryProvider 0.3.0 or later
include("compile.jl")

# env var to force compilation from source, for testing purposes
const forcecompile = get(ENV, "FORCE_COMPILE_BLOSC", "no") == "yes"

# Parse some basic command-line arguments
const verbose = ("--verbose" in ARGS) || forcecompile
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libblosc"], :libblosc),
]
verbose && forcecompile && Compat.@info("Forcing compilation from source.")

# Download binaries from hosted location
bin_prefix = "https://github.com/stevengj/BloscBuilder/releases/download/v1.14.3+5"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, :glibc) => ("$bin_prefix/Blosc.v1.14.3.aarch64-linux-gnu.tar.gz", "2c2af6cc54f9101420d2652a12d5da64dbd7526af8be7d748d4f1fd7686d5ecc"),
    Linux(:aarch64, :musl) => ("$bin_prefix/Blosc.v1.14.3.aarch64-linux-musl.tar.gz", "44da7bf787ae3992f619781e82d0546b156c1f4926c387201779184b710933f2"),
    Linux(:armv7l, :glibc, :eabihf) => ("$bin_prefix/Blosc.v1.14.3.arm-linux-gnueabihf.tar.gz", "d151548cd0d4f2c74f22bb9810baa6957bc91f7770c2952a3f98b9f61761d831"),
    Linux(:armv7l, :musl, :eabihf) => ("$bin_prefix/Blosc.v1.14.3.arm-linux-musleabihf.tar.gz", "01216681178d3ae7d01dba6670774e321364affb7c3077b8e31fcf367693b924"),
    Linux(:i686, :glibc) => ("$bin_prefix/Blosc.v1.14.3.i686-linux-gnu.tar.gz", "8b833b6544485c906729081b2f862798feb860b4744b467e8ef520a940da0aa6"),
    Linux(:i686, :musl) => ("$bin_prefix/Blosc.v1.14.3.i686-linux-musl.tar.gz", "9830099baae78d859c9e88d8ab2a93af5a953f56d46a122504eb9a27f909b8a6"),
    Windows(:i686) => ("$bin_prefix/Blosc.v1.14.3.i686-w64-mingw32.tar.gz", "97fd5573b324bdfc5a1a3f6b83095be8e2660e5e5ac0e33d865a9c7804f2bcd0"),
    Linux(:powerpc64le, :glibc) => ("$bin_prefix/Blosc.v1.14.3.powerpc64le-linux-gnu.tar.gz", "b25b60e907cba82d5f35387d6d2eb438d9898a4f6789bd702b114f3c0667b330"),
    MacOS(:x86_64) => ("$bin_prefix/Blosc.v1.14.3.x86_64-apple-darwin14.tar.gz", "d038eec02df45e3d83450b87182667d619c64b06a189d0d9be3be29877356c41"),
    Linux(:x86_64, :glibc) => ("$bin_prefix/Blosc.v1.14.3.x86_64-linux-gnu.tar.gz", "eb98760d5c54592b82f71aa11f28a1d6a1d588eb48c9d23977a74a513544cda0"),
    Linux(:x86_64, :musl) => ("$bin_prefix/Blosc.v1.14.3.x86_64-linux-musl.tar.gz", "ec25976201fba46cd8ce9674c9b25f87ad5d8e1399cf002cab94fa242a17aa3d"),
    FreeBSD(:x86_64) => ("$bin_prefix/Blosc.v1.14.3.x86_64-unknown-freebsd11.1.tar.gz", "d58104e836b8b39e665b957b27ccba41829cbbd8c803a49af9faffe797ae5f49"),
    Windows(:x86_64) => ("$bin_prefix/Blosc.v1.14.3.x86_64-w64-mingw32.tar.gz", "0eb9f0efd47bdaba7a506770c876575e2c49e9d1648aa8a41d083b7c996fe2b7"),
)

# source code tarball and hash for fallback compilation
source_url = "https://github.com/Blosc/c-blosc/archive/v1.14.3.tar.gz"
source_hash = "7217659d8ef383999d90207a98c9a2555f7b46e10fa7d21ab5a1f92c861d18f7"

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
if haskey(download_info, platform_key()) && !forcecompile
    url, tarball_hash = download_info[platform_key()]
    if !isinstalled(url, tarball_hash; prefix=prefix)
        # Download and install binaries
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)

        # check again whether the dependency is satisfied, which
        # may not be true if dlopen fails due to a libc++ incompatibility (#50)
        unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
    end
end

if unsatisfied || forcecompile
    # Fall back to building from source, giving the library a different name
    # so that it is not overwritten by BinaryBuilder downloads or vice-versa.
    libname = "libblosc_from_source"
    products = [ LibraryProduct(prefix, [libname], :libblosc) ]
    source_path = joinpath(prefix, "downloads", "src.tar.gz")
    if !isfile(source_path) || !verify(source_path, source_hash; verbose=verbose) || !satisfied(products[1]; verbose=verbose)
        compile(libname, source_url, source_hash, prefix=prefix, verbose=verbose)
    end
end

# Write out a deps.jl file that will contain mappings for our products
write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
