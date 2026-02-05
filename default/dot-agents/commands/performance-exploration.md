# performance-exploration

Use julia-mcp to explore alternative implementations.
Benchmark code against current implementation, using BenchmarkTools (available in base env).

## Suggested workflow

- Make scripts with implementations in `_research/performance` if the folder exists (may ask user to create it if not present)
- in the persistent julia-mcp session: load the files with `includet` to have revise keep the functions updated as they are modified.
- Run benchmarks using code evaluation, using the functions in the script.

