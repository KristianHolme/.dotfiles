# Global Instructions

These instructions apply across all projects and OpenCode sessions.

## Performance Workflow

When working with performance-related tasks, follow this workflow:

### Performance Exploration

Use the julia-mcp server to explore alternative implementations. Benchmark code against current implementation using BenchmarkTools (available in base env). Do not edit code, but report to the user on performance metrics and approaches.

### Performance Demonstration

When asked to demonstrate performance, create a script in `/_research/performance/` or another suitable folder that:

- Uses `Test.jl` to test equal outputs of current implementation
- Uses `BenchmarkTools` for benchmarking
- Uses `@benchmark` and `@info` to print out what implementation is benchmarked
- Uses sections (`##`) to section the script into different parts as appropriate, notebook-style

## Explicit Imports

When working with Julia packages, ensure they use explicit imports.

### Getting Overview of Violations

Navigate to the correct package directory and run:

```bash
julia --project --startup-file=no -e "using ExplicitImports;using <package_name>;print_explicit_imports(<package_name>)"
```

Or use the CLI wrapper:

```bash
explicit-imports-jl --help
explicit-imports-jl --check <path>
explicit-imports-jl --checklist all,<check1>,exclude_<check2> <path>
```

The CLI is equivalent to `julia -m ExplicitImports` and accepts a `<path>` argument (default: current directory).

### Fixing Violations

Proceed to fix as many violations as possible. Use discretion - some printed violations may be okay. If unclear, ask the user for clarification.

Make sure to differentiate between `using` and `import` statements, and follow the SciMLStyle guide for modules (invoke the SciMLStyle skill and read the modules sections).

## Available Skills

The following skills are assumed to be available and can be invoked as needed:
- `/SciMLStyle` - For SciML coding style and conventions
- `/makie-core` - Core Makie plotting guidance
- `/makie-dynamic` - Dynamic Makie visualizations
- `/algebra-of-graphics` - Algebra of Graphics plotting
- `/julia-performance-tips` - Julia performance optimization
- `/omarchy` - Omarchy system configuration
