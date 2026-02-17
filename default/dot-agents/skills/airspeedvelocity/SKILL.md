---
name: airspeedvelocity
description: Benchmark Julia packages over their commit history using AirspeedVelocity.jl. Use when benchmarking package performance, comparing revisions, or setting up CI benchmarking workflows.
triggers:
  - benchmark package
  - airspeedvelocity
  - benchpkg
  - compare revisions
  - performance regression
---

# AirspeedVelocity.jl

Benchmark Julia packages over their commit history. Inspired by Python's `asv`.

## Installation

Install the CLI tools:

```bash
julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

Executables are installed to `~/.julia/bin/` - ensure this is on your `PATH`.

## Quick Start

### 1. Create Benchmark Script

Create `benchmark/benchmarks.jl` in your package:

```julia
using BenchmarkTools
using YourPackage

const SUITE = BenchmarkGroup()

# Add benchmarks
SUITE["feature"]["fast"] = @benchmarkable your_function(args...)
SUITE["feature"]["slow"] = @benchmarkable another_function(args...)
```

**Requirements:**
- Must define `const SUITE = BenchmarkGroup()`
- Uses BenchmarkTools.jl syntax
- Access `PACKAGE_VERSION` constant for version-specific behavior

### 2. Run Benchmarks

**Current directory vs default branch:**
```bash
benchpkg
```

**Specific revisions:**
```bash
benchpkg YourPackage -r v0.4.20,v0.4.70,master
```

**With extra packages (dependencies for benchmarks):**
```bash
benchpkg YourPackage -a ExtraPkg1,ExtraPkg2,ExtraPkg3
```

**Custom benchmark script:**
```bash
benchpkg YourPackage -s path/to/custom_benchmark.jl
```

**Current dirty state:**
```bash
benchpkg -r dirty
```

**Full example with all options:**
```bash
benchpkg YourPackage \
    -r v0.15.3,v0.16.2,dirty \
    -s benchmark/benchmarks.jl \
    -o results/ \
    -a ExtraPkg1,ExtraPkg2 \
    -e "--threads=4 -O3" \
    --tune
```

## CLI Commands

### `benchpkg` - Run Benchmarks

```
benchpkg [package_name] [options]
```

**Key Options:**
- `-r, --rev <revs>` - Comma-separated revisions (default: default branch,dirty)
- `--url <url>` - Package URL
- `--path <path>` - Package path (default: current directory)
- `-o, --output-dir <dir>` - JSON output directory (default: .)
- `-e, --exeflags <flags>` - Julia executable flags (e.g., "--threads=4 -O3")
- `-a, --add <pkgs>` - Extra packages needed for benchmarks (comma-separated)
- `-s, --script <path>` - Benchmark script path (default: benchmark/benchmarks.jl)
- `--bench-on <rev>` - Revision to download benchmark script from
- `-f, --filter <pattern>` - Filter benchmarks to run
- `--nsamples-load-time <n>` - Load time samples (default: 5)
- `--tune` - Run tuning first
- `--dont-print` - Suppress table output

### `benchpkgtable` - Display Results

```
benchpkgtable [package_name] [options]
```

**Key Options:**
- `-r, --rev <revs>` - Revisions to display
- `-i, --input-dir <dir>` - JSON results directory (default: .)
- `--ratio` - Include ratio column (for 2 revisions)
- `--mode <modes>` - Table mode: time,memory (default: time)
- `--force-time-unit <unit>` - Force time unit: ns,μs,ms,s,h

**Examples:**
```bash
# Show time results
benchpkgtable YourPackage -r v0.4.20,v0.4.70

# Show memory usage
benchpkgtable YourPackage --mode=memory

# With ratios
benchpkgtable YourPackage -r v0.4.20,v0.4.70 --ratio
```

### `benchpkgplot` - Visualize Results

```
benchpkgplot package_name [options]
```

**Key Options:**
- `-r, --rev <revs>` - Revisions to plot
- `-i, --input-dir <dir>` - JSON results directory (default: .)
- `-o, --output-dir <dir>` - Output directory (default: .)
- `-n, --npart <n>` - Max plots per page (default: 10)
- `--format <fmt>` - Output format: png,pdf,svg (default: png)

**Example:**
```bash
benchpkgplot YourPackage \
    -r v0.4.20,v0.4.70,master \
    --format=pdf \
    -n 5
```

## CI/GitHub Actions

### Option 1: PR Comments

`.github/workflows/benchmark.yml`:

```yaml
name: Benchmark this PR
on:
  pull_request_target:
    branches: [master]
permissions:
  pull-requests: write

jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
        with:
          julia-version: '1'
          extra-pkgs: 'ExtraPkg1,ExtraPkg2'
```

### Option 2: Job Summary

```yaml
name: Benchmark this PR
on:
  pull_request:
    branches: [master]

jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
        with:
          julia-version: '1'
          job-summary: 'true'
          extra-pkgs: 'ExtraPkg1,ExtraPkg2'
```

### CI Parameters Mapping to CLI

| CI Parameter | CLI Flag | Description |
|-------------|----------|-------------|
| `extra-pkgs` | `-a, --add` | Extra packages for benchmarks |
| `script` | `-s, --script` | Custom benchmark script |
| `rev` | `-r, --rev` | Revisions to benchmark |
| `bench-on` | `--bench-on` | Freeze script at revision |
| `filter` | `-f, --filter` | Filter benchmarks |
| `exeflags` | `-e, --exeflags` | Julia flags |
| `tune` | `--tune` | Run tuning |

### Multiple Julia Versions

```yaml
strategy:
  matrix:
    julia: ['1', '1.10']

steps:
  - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
    with:
      julia-version: ${{ matrix.julia }}
      extra-pkgs: 'TestPkg'
```

## Complete Workflow Example

**Local development:**
```bash
# 1. Create benchmark script
# benchmark/benchmarks.jl

# 2. Test locally with extra deps
benchpkg -r dirty -a TestItems,Random

# 3. Compare specific versions
benchpkg MyPackage -r v1.0.0,v1.1.0,master -o results/

# 4. View results
benchpkgtable MyPackage -r v1.0.0,v1.1.0,master -i results/

# 5. Generate plots
benchpkgplot MyPackage -r v1.0.0,v1.1.0,master -i results/ -o plots/
```

**CI setup with extra packages:**
```yaml
- uses: MilesCranmer/AirspeedVelocity.jl@action-v1
  with:
    julia-version: '1'
    extra-pkgs: 'CUDA,KernelAbstractions'
    exeflags: '--threads=4'
```

## Tips

- **Extra packages**: Use `-a` or `extra-pkgs` for benchmark dependencies not in main Project.toml
- **Freezing script**: Use `--bench-on` to use the benchmark script from a specific revision
- **Filtering**: Use `-f` to run only specific benchmarks during development
- **Dirty state**: Use `-r dirty` to benchmark uncommitted changes
- **Tuning**: Use `--tune` for more accurate results (slower)
