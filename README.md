# x11-border-color.nvim

## Neovim plugin to change the border color of your terminal to indicate what mode neovim is in.

Inspired by `chwb` from [wmutils](https://github.com/wmutils/core).
This uses [LuaJIT FFI](https://luajit.org/ext_ffi.html) to call some C functions from [XCB](https://xcb.freedesktop.org/) directly to change the window's border color.
This is made to work with [bspwm](https://github.com/baskerville/bspwm), but can probably work with other X11 WMs.

Requires: <sup><sub>(You probably already have these installed)</sub></sup>

  * `libxcb`
  * `xcb-utils`


<p align="center" width="100%">
 <img src=https://github.com/Kody-Quintana/x11-border-color.nvim/assets/35752790/803d37c8-1fe8-461b-b720-94eeb33d0a51 />
</p>

## Install
```lua
use 'Kody-Quintana/x11-border-color.nvim'
```

## Configuration:

```lua
require("x11-border-color").setup({
  normal_color = "#2cba1f",
  insert_color = "#e21855",
  --restore_color = "#FFFFFF",  -- If using bspwm, the default restore_color is the output of 'bspc config focused_border_color'
})
```
