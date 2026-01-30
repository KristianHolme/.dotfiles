# use-explicitimports

Make the package in question use explicit imports.

To get an overview of violations of explicit imports,
navigate to the correctpackage directory and run:

```bash
julia --project --startup-file=no -e "using ExplicitImports;using <package_name>;print_explicit_imports(<package_name>)"
```

Then proceed to fix as many violations as possible. Use discretion, some printed violations may be okay.
If unclear, use the ask question tool to ask the user for clarification.
Make sure to differentiate between using and import statements,
and follow the SciMLStyle guide for modules (invoke the SciMLStyle skill and read the modules sections)

