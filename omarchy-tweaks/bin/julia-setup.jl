#!/usr/bin/env julia

using Pkg
Pkg.activate()
packages = ["Revise", "BenchmarkTools", "Cthulhu", "Debugger", "DrWatson",
    "PkgTemplates", "ProgressMeter", "BasicAutoloads", "OhMyREPL"]
for p in packages
    try
        Pkg.add(p)
        @info "Installed $p"
    catch e
        @warn "Error installing $p" exception = (e, catch_backtrace())
    end
end

import Base.Filesystem: cp, mkpath, dirname

src = joinpath(homedir(), ".dotfiles", "julia_config", "startup.jl")
dest_dir = joinpath(homedir(), ".julia", "config")
dest = joinpath(dest_dir, "startup.jl")

mkpath(dest_dir)
cp(src, dest; force=true)
@info "Copied $src to $dest"
