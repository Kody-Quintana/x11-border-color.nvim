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


  if config.disable_if_env_has == nil then
    config.disable_if_env_has = {
      'TMUX'
    }
  end
  for _, disabling_env_var in ipairs(config.disable_if_env_has) do
    for env_var, _ in pairs(vim.fn.environ()) do
      if disabling_env_var == env_var then
        return nil
      end
    end
  end


  if config.disable_if_env_matches == nil then
    config.disable_if_env_matches = {}
  end
  for disabling_env_var_name, disabling_env_var_value in pairs(config.disable_if_env_matches) do
    for env_var_name, env_var_value in pairs(vim.fn.environ()) do
      if disabling_env_var_name == env_var_name and disabling_env_var_value == env_var_value then
          return nil
      end
    end
  end


  -- These can be strings, or a list of strings that must all match in a row
  if config.disable_if_argv_has == nil then
    config.disable_if_argv_has = {
      '--remote-ui',
    }
  end
  for arg_index, arg in ipairs(vim.v.argv) do
    for _, disabling_arg in ipairs(config.disable_if_argv_has) do

      if type(disabling_arg) == "table" then
        -- Check if disabling_arg is a sub array of the rest of the args
        local num_matched = 0
        for disabling_arg_index, disabling_arg_element in ipairs(disabling_arg) do
          local arg_element = vim.v.argv[arg_index + disabling_arg_index - 1]
          if disabling_arg_element == arg_element then
            num_matched = num_matched + 1
          else
            break
          end
          if num_matched == #disabling_arg then
            return nil
          end
        end

      else
        if arg == disabling_arg then
          return nil
        end
      end

    end
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
