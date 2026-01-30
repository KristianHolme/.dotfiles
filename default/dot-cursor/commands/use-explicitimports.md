# use-explicitimports

Make the package in question use explicit imports.

To get an overview of violations of explicit imports,
navigate to the correct package directory and run:

```bash
julia --project --startup-file=no -e "using ExplicitImports;using <package_name>;print_explicit_imports(<package_name>)"
```

You can also use the CLI wrapper:

```bash
explicit-imports-jl --help
explicit-imports-jl --check <path>
explicit-imports-jl --checklist all,<check1>,exclude_<check2> <path>
```

The CLI is equivalent to `julia -m ExplicitImports` and accepts a `<path>`
argument (default: current directory).

Then proceed to fix as many violations as possible. Use discretion, some printed violations may be okay.
If unclear, use the ask question tool to ask the user for clarification.
Make sure to differentiate between using and import statements,
and follow the SciMLStyle guide for modules (invoke the SciMLStyle skill and read the modules sections)

