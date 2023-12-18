local M = {}

M.setup = function(config)
  if config == nil then
    config = {}
  end

  if not jit then
    return nil
  end

  local ffi = require('ffi')

  local function msg(message)
    local prefix = '[x11-border-color]: '
    print(prefix .. message)
  end

  local loaded_libxcb, xcb = pcall(ffi.load, 'xcb')
  if not loaded_libxcb then
    msg('failed to load xcb')
    return nil
  end
  local loaded_libxcb_util, xcb_util = pcall(ffi.load, 'xcb-util')
  if not loaded_libxcb_util then
    msg('failed to load xcb-util')
    return nil
  end

  if config.restore_color == nil then

    -- bspwm special default case:
    -- If bspwm is running, and no custom restore_color is specified, then assume
    -- we want to set color back to whatever the bspwm focused border color is
    local bspwm_focused_border_color = vim.fn.system({'bspc', 'config', 'focused_border_color'})
    if vim.v.shell_error == 0 then
        config.restore_color = bspwm_focused_border_color

    -- TODO grab the current border color before nvim opens?
    else
      config.restore_color = "#FFFFFF"
    end
  end

  config.insert_color = config.insert_color or "#e21855"
  config.normal_color = config.normal_color or "#2cba1f"

  local window_id_env_var = os.getenv('WINDOWID')
  if window_id_env_var == '' or window_id_env_var == nil then
    msg('WINDOWID env var not set')
    return nil
  end
  local window = tonumber(window_id_env_var)
  if window == nil then
    msg('invalid WINDOWID env var: "' .. window_id_env_var .. '"')
    return nil
  end

  -- Overrides `BorderPixmap`. A pixmap of undefined size filled with the specified
  -- border pixel is used for the border. Range checking is not performed on the
  -- border-pixel value, it is truncated to the appropriate number of bits.
  local XCB_CW_BORDER_PIXEL = 8

  ffi.cdef[[
    typedef struct xcb_connection_t xcb_connection_t;

    typedef uint32_t xcb_window_t;

    typedef struct {
      unsigned int sequence;
    } xcb_void_cookie_t;

    xcb_void_cookie_t xcb_change_window_attributes(
      xcb_connection_t *c,
      xcb_window_t      window,
      uint32_t          value_mask,
      const void       *value_list
    );

    xcb_connection_t *xcb_connect(const char *displayname, int *screenp);

    int xcb_connection_has_error(xcb_connection_t *c);

    void xcb_aux_sync(xcb_connection_t *c);

    void xcb_disconnect(xcb_connection_t *c);
  ]]

  local value_list = ffi.new('uint32_t[3]')

  local function set_border_color(color_hex_str)
    if os.getenv('DISPLAY') == nil then
      return nil
    end

    local color_int = tonumber(color_hex_str:gsub('#', ''), 16)
    if color_int == nil then
      msg('invalid color: "' .. color_hex_str .. '"')
      return nil
    end
    value_list[0] = color_int

    local conn = xcb.xcb_connect(nil, nil)
    if xcb.xcb_connection_has_error(conn) ~= 0 then
      msg('something went wrong connecting with xcb')
      return nil
    end

    xcb.xcb_change_window_attributes(conn, window, XCB_CW_BORDER_PIXEL, value_list);
    xcb_util.xcb_aux_sync(conn)
    xcb.xcb_disconnect(conn)
  end

  vim.api.nvim_create_autocmd('InsertEnter', {
    callback = function()
      set_border_color(config.insert_color)
    end
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    callback = function()
      set_border_color(config.normal_color)
    end
  })

  vim.api.nvim_create_autocmd({'FocusGained', 'VimEnter'}, {
    callback = function()
      if vim.api.nvim_get_mode().mode == 'i' then
        set_border_color(config.insert_color)
      else
        set_border_color(config.normal_color)
      end
    end
  })

  vim.api.nvim_create_autocmd('VimLeave', {
    callback = function()
      set_border_color(config.restore_color)
    end
  })
end

return M
