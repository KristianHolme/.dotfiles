---
name: scimlstyle
description: Apply the SciML Style Guide to Julia code with focus on safety, generic interfaces, naming, and formatting. Use when writing or reviewing Julia code for SciML projects, when the user requests SciMLStyle, or when aligning code with SciML conventions.
---

# Use SciMLStyle

Apply the SciML Style Guide for Julia. Source references:

- <https://docs.sciml.ai/SciMLStyle/stable/>
- <https://github.com/SciML/SciMLStyle/blob/main/README.md>

## Quick Workflow

- Match the existing file style first; avoid repo-wide reformatting.
- Apply the key SciMLStyle rules to any new or edited code.
- Prefer minimal, focused changes; do not mix style-only changes with behavior changes.

## Core Principles

- Prefer generic, interface-based code over concrete assumptions.
- Favor readability, safety, and maintainability over micro-optimizations.
- Avoid mixing mutating and non-mutating styles in the same logic path.

## Formatting and Layout

- 4-space indentation, no tabs.
- Keep lines within a 92-character limit.
- Avoid extra whitespace inside `()`, `[]`, `{}`.
- Surround most binary operators with single spaces.
- Do not add spaces around `:`, `^`, or `//` (range, exponent, rational).
- Use `for x in xs` (never `=` or `∈`) in loops and comprehensions.
- Use short-form function definitions only when they fit on one line.
- Separate positional and keyword arguments with `;` in calls.

## Naming Rules

- Public APIs should avoid Unicode identifiers.
- Functions/variables: lowercase; constants: uppercase; types: CamelCase.
- Abstract types begin with `Abstract`.
- Private/internal names use `__` prefix.

## Functions and APIs

- Mutating functions must end with `!`.
- Avoid type piracy (only extend functions/types you own).
- Prefer instances over types as arguments (for extensibility and specialization).
- Keep functions focused on one underlying principle.
- Expose internal choices as options where practical.

## Types and Annotations

- Prefer concrete, parametric field types over abstract fields.
- Use general argument types; avoid overly narrow annotations.
- Keep unions small (two or three types) and avoid elaborate union chains.

## Interfaces and Generic Code

- Prefer generic interfaces: broadcasting, iteration, indexing, etc.
- Avoid hard-coded indexing when a broadcast or iterator works.
- Use trait/interface packages where appropriate (e.g., SciMLBase, ArrayInterface).
- If mutation is required, check mutability and provide contextual errors.

## Safety and Robustness

- Avoid `eval`, unsafe operations, and non-public Base APIs.
- Avoid `@inbounds`; if used, add explicit safety checks.
- Avoid `ccall` unless necessary; use safe C types and `GC.@preserve`.
- Initialize memory explicitly; avoid uninitialized allocations unless fully filled.
- Validate user input early and use domain-specific error messages.

## Modules, Imports, Exports

- Place imports at the top; separate `using` and `import` with a blank line.
- Do not shadow functions; use distinct names or extend intentionally.
- Export only stable, documented API symbols.

## Documentation and Tests

- Use Documenter.jl and concise docstrings for public APIs.
- Keep tutorials before reference materials in docs.
- Ensure tests cover a broad range of numeric and array types.
- Follow the project’s test framework and CI conventions.
