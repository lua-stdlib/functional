local _ENV = require 'std.normalize' {
   'string',
   'table',
}

local format	= string.format
local concat	= table.concat



local argscheck
do
   local ok, typecheck = pcall(require, 'typecheck')
   if ok then
      argscheck = typecheck.argscheck
   else
      argscheck = function(decl, fn)
         return fn
      end
   end
end



--[[ ================= ]]--
--[[ Shared Functions. ]]--
--[[ ================= ]]--


local function copy(dest, src)
   if src == nil then
      dest, src = {}, dest
   end
   for k, v in next, src do dest[k] = v end
   return dest
end


local function toqstring(x)
   if type(x) ~= 'string' then
      return tostring(x)
   end
   return format('%q', x)
end


local function render(x, roots)
   roots = roots or {}

   local function stop_roots(x)
      return roots[x] or render(x, copy(roots))
   end

   if type(x) ~= 'table' or getmetamethod(x, '__tostring') then
      return toqstring(x)

   else
      local buf = {'{'} -- pre-buffer table open
      roots[x] = toqstring(x) -- recursion protection

      local kp, vp -- previous key and value
      for k, v in opairs(x) do
         if kp ~= nil then
            buf[#buf + 1] = ','
         end
         buf[#buf + 1] = stop_roots(k) .. '=' .. stop_roots(v)
         kp, vp = k, v
      end
      buf[#buf + 1] = '}' -- buffer << table close

      return concat(buf) -- stringify buffer
   end
end


local function serialize(...)
   local seq = pack(...)
   local buf = {}
   for i = 1, seq.n do
      buf[i] = render(seq[i], serialize_vtable)
   end
   return concat(buf, ',')
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   argscheck = argscheck,
   serialize = serialize,
   toqstring = toqstring,
}
