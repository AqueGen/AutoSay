-- Minimal WoW globals for headless runs. Core modules must not need these
-- (deps are injected); this exists so future adapter-level tests can load.
_G.strsplit = _G.strsplit or function(sep, s)
  local out = {}
  for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
  return unpack(out)
end
return true
