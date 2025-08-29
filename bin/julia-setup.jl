#!/usr/bin/env julia

using Pkg
Pkg.activate()
packages = ["Revise", "BenchmarkTools", "Cthulhu", "Debugger", "DrWatson",
    "PkgTemplates", "ProgressMeter", "BasicAutoloads", "OhMyREPL", "Reexport"]
for p in packages
    try
        Pkg.add(p)
        @info "Installed $p"
    catch e
        @warn "Error installing $p" exception = (e, catch_backtrace())
    end
end
