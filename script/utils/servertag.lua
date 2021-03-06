--[[

  Generate (or set) a unique tag for filenames generated by a server instance.

]]--

return setmetatable({}, { __index = function(t, name)
  if name == "tag" then return tostring(cs.serverport)
  elseif name == "fntag" then return t.tag:gsub("([^\\/])$", "%1.") end
end })
