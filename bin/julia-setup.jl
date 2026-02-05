#!/usr/bin/env julia

using Pkg
Pkg.activate()
packages = [
    "Revise", "BenchmarkTools", "Cthulhu", "Debugger", "DrWatson", "JET",
    "PkgTemplates", "ProgressMeter", "OhMyREPL", "Reexport",
    "Infiltrator", "ArtifactUtils", "ExplicitImports", "PreferenceTools",
]
for p in packages
    try
        Pkg.add(p)
        @info "Installed $p"
    catch e
        @warn "Error installing $p" exception = (e, catch_backtrace())
    end
end

# Install Runic via Apps interface
try
    Pkg.Apps.add("Runic")
    @info "Installed Runic"
catch e
    @warn "Error installing Runic" exception = (e, catch_backtrace())
end

# Install JETLS from GitHub
try
    Pkg.Apps.add(; url = "https://github.com/aviatesk/JETLS.jl", rev = "release")
    @info "Installed JETLS"
catch e
    @warn "Error installing JETLS" exception = (e, catch_backtrace())
end
