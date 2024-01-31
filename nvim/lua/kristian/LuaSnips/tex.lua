local get_visual = function(args, parent)
  if (#parent.snippet.env.LS_SELECT_RAW > 0) then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  else  -- If LS_SELECT_RAW is empty, return a blank insert node
    return sn(nil, i(1))
  end
end


return {
    --fraction
    s({trig="ff", dscr="Expand into \\frac{}{}"},
    fmta("\\frac{<>}{<>}",
    {i(1), i(2)}
    )
    ),

    --begin
    s({trig="beg", dscr="begin and end environment."},
    fmta(
    [[
    \begin{<>}
    <>
    \end{<>}
    ]],
    {i(1), i(2), rep(1)})
    ),

    --equation
    s({trig="eq", dscr="begin equation environment."},
    fmta(
    [[
    \begin{equation<>}
    <>
    \end{equation<>}
    ]],
    {i(1), i(2), rep(1)})
    ),

    --highlight
    s({trig="hl", dscr="highlight"},
    fmta("\\hl{<>}", {d(1, get_visual)})
    )

}
