-- Shared functions for links.lua and links-buf.lua
local M = {}

local function slugify(text)
  return text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function looks_like_path(text)
  if text:find("/", 1, true) then
    return true
  end
  -- A trailing ".ext" of 1-8 word characters, not preceded by another dot
  -- (so "v1.2" style titles don't accidentally count).
  return text:match("%.[%w]+$") ~= nil
end

--- Normalises a `[[wiki link]]` target (already stripped of any #anchor) into the filename it refers to.
function M.normalise(link)
  local page = link:match("^[^#]+") or link
  page = page:match("^%s*(.-)%s*$") -- trim surrounding whitespace
  if looks_like_path(page) then
    return page
  end

  return slugify(page) .. ".md"
end

return M
