#!/usr/bin/env julia

using Pkg
Pkg.activate()
packages = [
    "Revise", "BenchmarkTools", "Cthulhu", "Debugger", "DrWatson", "JET",
    "PkgTemplates", "ProgressMeter", "OhMyREPL", "Reexport",
    "Infiltrator", "ArtifactUtils",
]
for p in packages
    try
        Pkg.add(p)
        @info "Installed $p"
    catch e
        @warn "Error installing $p" exception = (e, catch_backtrace())
    end
end

Pkg.activate("runic", shared = true)
Pkg.add("Runic")
