return {
    s({trig="opt", dscr="standard opts"},
    fmta(
        [[
        opt = struct('<>', <>);
        opt = merge_options(opt, varargin{:});
        ]],
        {i(1), i(2)}
        )
    )

}
