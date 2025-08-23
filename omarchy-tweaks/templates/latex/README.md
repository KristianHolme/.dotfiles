# LaTeX Templates for omarchy-tweaks

This directory contains LaTeX project templates for use with the `dotfiles-latex-init.sh` script.

## Available Templates

### UiO-Specific Templates
- **`uio-presentation.tex`** - University of Oslo official beamer presentation
- **`uio-preamble.tex`** - Comprehensive UiO beamer options and configuration

## UiO Beamer Template

The UiO beamer template provides:

### Features
- Official University of Oslo branding and colors
- Professional presentation layout following UiO guidelines  
- Comprehensive preamble with all theme options documented
- Support for section headers, TOC, summary slides
- Multiple font options (Arial, Noto, Arev)
- Official UiO color palette

### Theme Options Available
- `sectionheaders` - Show section/subsection names in header
- `summary` - Add summary page at end
- `toc` - Automatically insert table of contents
- `uiostandard` - Follow UiO standard strictly (square bullets, etc.)
- `sectionsep=color` - Add colored section separator frames
- `font=arial|noto|arev|none` - Font selection

### UiO Colors
- Blues: `uioblue1`, `uioblue2`, `uioblue3`
- Greens: `uiogreen1`, `uiogreen2`, `uiogreen3`  
- Oranges: `uioorange1`, `uioorange2`, `uioorange3`
- Pinks: `uiopink1`, `uiopink2`, `uiopink3`
- Others: `uioyellow`, `uiogrey`

### Special Commands
- `\uiofrontpage[options]` - Create official UiO front page
- `\uioemail{email}` - Set email address
- `\uiobigimage{title}{file}{copyright}` - Full-page image with frame
- `\uiofullpageimage{file}` - Completely full-page image
- `uioimageframe` environment - Half text, half image slides

## Usage

Create a new UiO presentation:

```bash
./dotfiles-latex-init.sh -t uio-presentation my-uio-talk
```

## Dependencies

The UiO beamer theme requires the UiO beamer package to be installed. At UiO, this is typically available in:
- `/home/kristian/texmf/tex/latex/beamer/uiobeamer/`

For personal computers, download from:
- https://www.mn.uio.no/ifi/tjenester/it/hjelp/latex/uiobeamer.zip

## Notes

- UiO presentations should use 16:9 aspect ratio (default in template)
- Front page images should ideally be 8:9 aspect ratio
- Full-page images should be 16:9 aspect ratio
- The preamble file contains extensive documentation of all options
- Template is integrated with VimTeX for easy compilation