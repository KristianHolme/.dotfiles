---
name: algebra-of-graphics
description: Create statistical visualizations in Julia using AlgebraOfGraphics.jl. Use when the user asks for "aog" or "AlgebraOfGraphics" plotting, statistical plots, data visualization with DataFrames, or complex faceted visualizations in Julia. Dont use if desired visualisation is too custom/complex for AoG.
---

# AlgebraOfGraphics.jl Skill

This skill guides the creation of statistical visualizations using `AlgebraOfGraphics.jl` (AoG). AoG provides a declarative, compositional API for plotting, built on top of Makie.jl.

## Core Workflow

The fundamental pattern in AoG is composing layers with `*` (combine) and `+` (overlay), then drawing the result:

```julia
using AlgebraOfGraphics, CairoMakie

# 1. Define data and mapping
plt = data(df) * mapping(:x_col, :y_col, color=:group_col)

# 2. Add visual geometry (optional, defaults usually work)
plt *= visual(Scatter)

# 3. Draw the plot
draw(plt)
```

## Key Building Blocks

### 1. Data (`data`)
Wraps the data source.
- `data(df)`: Use a DataFrame.
- `data(dict)`: Use a dictionary of vectors.
- `data((x=..., y=...))`: Use a NamedTuple of vectors.

### 2. Mapping (`mapping`)
Maps data columns to visual aesthetics.
- **Positional**: `mapping(:x, :y, :z)` maps to x, y, z axes.
- **Keyword**:
    - `color`, `marker`, `linestyle`: Group and style by column.
    - `layout`, `row`, `col`: Facet by column.
    - `group`: Group data without explicit styling.
- **Transformations**: `mapping(:x => (t -> t^2) => "X Squared")` applies a function and renames the label.

### 3. Visual (`visual`)
Specifies the Makie plot type and attributes.
- `visual(Scatter)`: Scatter plot.
- `visual(Lines)`: Line plot.
- `visual(BarPlot)`: Bar plot.
- `visual(BoxPlot)`: Box plot.
- `visual(Scatter, markersize=10, alpha=0.5)`: Pass fixed attributes here.

### 4. Analyses
AoG includes analysis layers that process data before plotting.
- `density()`: Kernel density estimation.
- `histogram()`: Histogram (bins).
- `frequency()`: Count occurrences (categorical).
- `linear()`: Linear regression.
- `smooth()`: LOESS smoothing.
- `expectation()`: Compute mean and error bars.

### 5. Operators
- `*` (Multiplication): Combines specifications (Cartesian product). merges data, mapping, and visual.
    - `data(df) * mapping(:x, :y)`
- `+` (Addition): Layers specifications on top of each other.
    - `(visual(Scatter) + linear())`: Overlay points and regression line.

## Customization (`draw`)

The `draw` function renders the plot and accepts customization for the Figure, Axis, and Scales.

```julia
draw(plt;
    # Figure attributes
    figure = (; size=(800, 600), title="My Plot"),
    
    # Axis attributes (Makie Axis)
    axis = (; 
        xlabel="Time (s)", 
        ylabel="Value",
        titlesize=20,
        xgridvisible=false
    ),
    
    # Legend and Colorbar attributes
    legend = (; position=:top, title="Groups"),
    colorbar = (; width=20),
    
    # Scale configuration (palettes, order)
    scales = (; 
        color = (; palette=:viridis),
        marker = (; palette=[:circle, :rect])
    )
)
```

## Faceting

Faceting is handled via `mapping(layout=...)`, `mapping(row=...)`, or `mapping(col=...)`.

```julia
# Facet by 'category' column
plt = data(df) * mapping(:x, :y, layout=:category)
draw(plt)

# Grid faceting
plt = data(df) * mapping(:x, :y, row=:row_cat, col=:col_cat)
draw(plt)
```

## Examples

### 1. Grouped Scatter with Regression
```julia
using AlgebraOfGraphics, CairoMakie

df = (x=rand(100), y=rand(100), group=rand(["A", "B"], 100))

# Define base spec
base = data(df) * mapping(:x, :y, color=:group)

# Combine scatter and linear regression
spec = base * (visual(Scatter) + linear())

draw(spec)
```

### 2. Complex Faceted Plot
```julia
using AlgebraOfGraphics, CairoMakie

spec = data(penguins) * 
    mapping(:bill_length_mm, :bill_depth_mm, color=:species) * 
    (visual(Scatter, alpha=0.5) + linear()) * 
    mapping(col=:island)

draw(spec, axis=(; title="Penguin Measurements"))
```

### 3. Histogram
```julia
using AlgebraOfGraphics, CairoMakie

# Automatic binning
spec = data(df) * mapping(:value, color=:group) * histogram(bins=20)
draw(spec)
```

## Troubleshooting

1.  **Nothing shows up?**
    -   Ensure you piped to `|> draw` or called `draw(spec)`.
    -   In a script, make sure to explicitly display the figure if it's not the last line.

2.  **"Column not found" error?**
    -   Check that column names are Symbols (`:colname`) and exist in the DataFrame.
    -   Verify `data()` is correctly passed.

3.  **Visual kwargs vs Mapping**
    -   Use `mapping(color=:col)` for data-driven color.
    -   Use `visual(Scatter, color=:red)` for fixed color.

## Resources

-   **Docs**: [aog.makie.org](https://aog.makie.org)
-   **Gallery**: [aog.makie.org/stable/gallery](https://aog.makie.org/stable/gallery/gallery)
-   **Issues**: [github.com/MakieOrg/AlgebraOfGraphics.jl](https://github.com/MakieOrg/AlgebraOfGraphics.jl)
