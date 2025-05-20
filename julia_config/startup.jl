using Pkg: Pkg
try
    using Revise
catch e
    @warn "Error initializing Revise" exception=(e, catch_backtrace())
end

atreplinit() do repl
    try
        @eval using OhMyREPL
    catch e
        @warn "error while importing OhMyREPL" e
    end
end
# if isinteractive()
#     import BasicAutoloads
#     BasicAutoloads.register_autoloads([
#         ["@benchmark", "@btime"] => :(using BenchmarkTools),
#         ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
#         "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
#                                     :(using Test),
#         ["@about"]               => :(using About; macro about(x) Expr(:call, About.about, x) end),
#     ])
# end


local_file = joinpath(homedir(), ".dotfiles", "julia_config", "local_startup.jl")
if isfile(local_file)
    include(local_file)
end
