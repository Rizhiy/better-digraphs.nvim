local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local util = require "better-digraphs.util"
local is_empty_string = require "better-digraphs.util".is_empty_string

local match_digraph_table_header = function(line)
  return string.match(line, "official name")
end

local match_digraph_table_footer = function(line)
  return string.match(line, "vim:tw=78:ts=8:noet:ft=help:norl:")
end

local get_digraph_from_doc = function()
  local digraph_doc = vim.fn.expand("$VIMRUNTIME/doc/digraph.txt")
  if not util.file_exists(digraph_doc) then return {} end
  local lines = {}
  local line_number = 1
  local table_found = false
  for line in io.lines(digraph_doc) do
    if string.match(line, "digraph%-table%-mbyte") then
      table_found = true
      line_number = 1
    elseif table_found
      and not match_digraph_table_header(line)
      and not is_empty_string(line)
      and not match_digraph_table_footer(line) then
        lines[line_number] = line
        line_number = line_number + 1
    end
  end
  return lines
end

local generate_default_digraphs = function()
  local digraph_raw_list = get_digraph_from_doc()
  return util.map(digraph_raw_list, function(line)
    local columns = util.split(line, "\t")
    return {columns[5], columns[2], columns[1]}
  end)
end

local picker_select_factory = function(mode, prompt_bufnr)
  return function()
    local selection = action_state.get_selected_entry()
    vim.g.digraph_map_sequences = vim.g.digraph_map_sequences or {}
    local digraph_map_sequences = {
      insert = vim.g.digraph_map_sequences.insert or "",
      normal = vim.g.digraph_map_sequences.normal or "",
      visual = vim.g.digraph_map_sequences.visual or ""
    }

    local place_digraph = {
      insert = function()
        actions.close(prompt_bufnr)
        if util.get_cursor_column() ~= 0 then
          vim.api.nvim_feedkeys("a", "", false)
        else
          vim.api.nvim_feedkeys("i", "", false)
        end
        vim.api.nvim_feedkeys(digraph_map_sequences.insert .. selection.value[2], "", false)
      end,
      normal = function()
        actions.close(prompt_bufnr)
        vim.api.nvim_feedkeys("r" .. digraph_map_sequences.normal .. selection.value[2], "", false)
      end,
      visual = function()
        actions.close(prompt_bufnr)
        vim.api.nvim_feedkeys("gvr" .. digraph_map_sequences.visual  .. selection.value[2], "", false)
      end
    }

    local deprecated_map = {
      ["i"] = "insert",
      ["r"] = "normal",
      ["gvr"] = "visual"
    }
    mode = util.map_deprecated_mode_to_new_mode(mode, deprecated_map)
    util.validate_mode(place_digraph, mode)

    place_digraph[mode]()
  end
end

local digraphs_factory = function(digraph_list)
  return function(mode, opts)
    opts = opts or require("telescope.themes").get_cursor{}
    pickers.new(opts, {
      prompt_title = "Digraphs",
      finder = finders.new_table {
        results = digraph_list,
        entry_maker = function(entry)
          if not entry[1] or not entry[2] or not entry[3] then
            return {}
          end
          return {
            value = entry,
            display = entry[3] .. " " .. entry[2],
            ordinal = entry[1] .. ", " .. entry[2],
          }
        end
      },
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(picker_select_factory(mode, prompt_bufnr))
        return true
      end,
      sorter = conf.generic_sorter(opts),
    }):find()
  end
end

local hash_map_digraph_list_by_digraph = function(list)
  local hash = {}
  for _, value in pairs(list) do
    hash[value[2]] = value
  end
  return hash
end

local digraph_list = generate_default_digraphs()
if vim.g.BetterDigraphsAdditions then
  local default_mapped_by_digraph = hash_map_digraph_list_by_digraph(digraph_list)
  for _, digraph_addition in pairs(vim.g.BetterDigraphsAdditions) do
    if string.len(digraph_addition.digraph) ~= 2 then
      error('Digraph ' .. digraph_addition.digraph .. ' should have 2 characters, found ' .. string.len(digraph_addition.digraph))
    end
    if vim.fn.strdisplaywidth(digraph_addition.symbol) ~= 1 then
      error('Digraph symbol ' .. digraph_addition.symbol .. ' should have 1 characters, found ' .. vim.fn.strdisplaywidth(digraph_addition.symbol))
    end
    default_mapped_by_digraph[digraph_addition.digraph] = {
      digraph_addition.name,
      digraph_addition.digraph,
      digraph_addition.symbol
    }
    vim.fn.digraph_set(digraph_addition.digraph, digraph_addition.symbol)
  end
  digraph_list = util.map(default_mapped_by_digraph, function(digraph, _)
    return digraph
  end)
end
local digraphs = digraphs_factory(digraph_list)

return {
  digraphs = digraphs
}

