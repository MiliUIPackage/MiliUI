local L = Exlist.L



-- use key if there's no translation
setmetatable(Exlist.L, {__index = function(self, key)
  key = key or ""
  self[key] = key---(key and "<LOCAL>" .. key or "")
  return key
end})
