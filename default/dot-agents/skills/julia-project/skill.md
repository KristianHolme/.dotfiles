---
name: julia-project
description: Usefull tips for working with a scientific project in Julia.
---

## Bakwards compatibility when changing structs

Sometimes structs used in the project needs to change, maybe a struct ExperimentConfig needs to add a field.
When data is already saved with the old struct, we can migrate.

When structs (or modules) change, old JLD2 files can fail to load.
Use **JLD2’s typemap and `rconvert`** to upgrade stored data into current types.

**1. Define the conversion** – Implement `JLD2.rconvert(::Type{NewType}, nt::NamedTuple)`:
build the new struct from the stored fields. Use `get(nt, :field, default)` for
missing/renamed fields and `haskey(nt, :key)` to branch on old vs new layout.

**2. Register old type paths** – Build a typemap:
`Dict("OldModule.OldTypeName" => JLD2.Upgrade(NewType), ...)`.
JLD2 uses this to call your `rconvert` when it sees that type path in a file.

**3. Load with the typemap** – Always load as `load(path; typemap = typemap)`.
Converted objects are normal structs; saving them again persists the new types
so the typemap isn’t needed next time.

For conditional upgrades, use a typemap _function_ `(f, typepath, params) -> JLD2.Upgrade(SomeType)` or
`JLD2.default_typemap(f, typepath, params)` and pass it as `typemap`.
`rconvert`/`Upgrade`/`default_typemap` are used for migration and may be non-public APIs.
