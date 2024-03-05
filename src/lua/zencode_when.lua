--[[
--This file is part of zenroom
--
--Copyright (C) 2018-2021 Dyne.org foundation
--designed, written and maintained by Denis Roio <jaromil@dyne.org>
--
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU Affero General Public License v3.0
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Affero General Public License for more details.
--
--Along with this program you should have received a copy of the
--GNU Affero General Public License v3.0
--If not, see http://www.gnu.org/licenses/agpl.txt
--
--Last modified by Denis Roio
--on Friday, 26th November 2021
--]]

--- WHEN

-- nop to terminate IF blocks
When("done", function() end)


local function _is_found(el)
    return ACK[el] and (luatype(ACK[el]) == 'table' or tonumber(ACK[el]) or #ACK[el] ~= 0)
end

IfWhen("verify '' is found", function(el)
    zencode_assert(_is_found(el), "Cannot find object: "..el)
end)

IfWhen("verify '' is not found", function(el)
    zencode_assert(not _is_found(el), "Object should not be found: "..el)
end)

When("append '' to ''", function(src, dest)
		local val = have(src)
		local dst = have(dest)
		zencode_assert(luatype(dst) ~= 'table',
				   "Cannot append to table: "..dest)
		-- if the destination is a number, fix the encoding to string
		if isnumber(dst) then
		   dst = O.from_string( tostring(dst) )
		   CODEC[dest].encoding = "string"
		   CODEC[dest].zentype = 'e'
        end
        if isnumber(val) then
		   val = O.from_string( tostring(val) )
		end
        dst = dst:octet() .. val
		ACK[dest] = dst
end)

When("append string '' to ''", function(hstr, dest)
	local dst = have(dest)
	zencode_assert(luatype(dst) ~= 'table', "Cannot append to table: "..dest)
	-- if the destination is a number, fix encoding to string
	if isnumber(dst) then
	   dst = O.from_string( tostring(dst) )
	   CODEC[dest].encoding = "string"
	   CODEC[dest].zentype = 'e'
	end
	dst = dst:octet() .. O.from_string(hstr)
	ACK[dest] = dst
end)

When("append '' of '' to ''", function(enc, src, dest)
	local from = have(src)
	local to = have(dest)
	zencode_assert(type(to) == 'zenroom.octet', "Destination type is not octet: "..dest.." ("..type(to)..")")
	zencode_assert(CODEC[dest].encoding == 'string', "Destination encoding is not string: "..dest)
	local f = get_encoding_function(enc)
	zencode_assert(f, "Encoding format not found: "..enc)
	to = to .. O.from_string( f( from:octet() ) )
	ACK[dest] = to
end)

When("create ''", function(dest)
	empty (dest)
	ACK[dest] = { }
	CODEC[dest] = guess_conversion(ACK[dest], dest)
	CODEC[dest].name = dest
end)
When("create '' named ''", function(sch, name)
	empty(name)
	ACK[name] = { }
	CODEC[name] = guess_conversion(ACK[name], sch)
	CODEC[name].name = name
end)

-- simplified exception for I write: import encoding from_string ...
When("write string '' in ''", function(content, dest)
	empty(dest)
	ACK[dest] = O.from_string(content)
	new_codec(dest,
			  {encoding = 'string',
			   luatype = 'string',
			   zentype = 'e' })
end)

-- ... and from a number
When("write number '' in ''", function(content, dest)
	empty(dest)
	-- TODO: detect number base 10
	local num = tonumber(content)
	zencode_assert(num, "Cannot convert value to number: "..content)
--	if num > 2147483647 then
--		error('Overflow of number object over 32bit signed size')
		-- TODO: maybe support unsigned native here
--	end

    --- simulate input from Given to add a new number
    --- in order to make it distinguish float and time
	ACK[dest] = input_encoding('float').fun(num)
    new_codec(dest, {zentype = 'e', encoding = 'number'})
end)

When("create number from ''", function(from)
	empty'number'
	local get = have(from)
	ACK.number = BIG.from_decimal(get:octet():string())
	new_codec('number', {zentype = 'e' })
end)

When("set '' to '' as ''", function(dest, content, format)
	empty(dest)
	local guess = input_encoding(format)
	guess.raw = content
	guess.name = dest
	ACK[dest] = operate_conversion(guess)
--	new_codec(dest, { luatype = luatype(ACK[dest]), zentype = 'e' })
end)

When("create json escaped string of ''", function(src)
    local obj, codec = have(src)
    empty 'json_escaped_string'
    local encoding = codec.schema or codec.encoding
        or CODEC.output.encoding.name
    ACK.json_escaped_string = OCTET.from_string( JSON.encode(obj, encoding) )
    new_codec('json_escaped_string', {encoding = 'string', zentype = 'e'})
end)

When("create json unescaped object of ''", function(src)
    local obj = have(src)
    empty'json_unescaped_object'
    ACK.json_unescaped_object = deepmap(
        OCTET.from_string,
        JSON.decode(O.to_string(obj))
    )
    new_codec('json_unescaped_object', {encoding = 'string'})
end)

-- numericals
When("set '' to '' base ''", function(dest, content, base)
	empty(dest)
	local bas = tonumber(base)
	zencode_assert(bas, "Invalid numerical conversion for base: "..base)
	local num = tonumber(content,bas)
	zencode_assert(num, "Invalid numerical conversion for value: "..content)
	ACK[dest] = F.new(num)
	new_codec(dest, {encoding = 'number', zentype = 'e' })
end)

local function _delete_f(name)
   have(name)
   ACK[name] = nil
   CODEC[name] = nil
end
When("delete ''", _delete_f)
When("remove ''", _delete_f)

When("rename '' to ''", function(old,new)
	have(old)
	empty(new)
	ACK[new] = ACK[old]
	ACK[old] = nil
	CODEC[new] = CODEC[old]
	CODEC[old] = nil
end)
When("rename object named by '' to ''", function(old,new)
	local oldo = have(old)
	local olds = oldo:octet():string()
	have(olds)
	empty(new)
	ACK[new] = ACK[olds]
	ACK[olds] = nil
	CODEC[new] = CODEC[olds]
	CODEC[olds] = nil
end)
When("rename '' to named by ''", function(old,new)
	have(old)
	local newo = have(new)
	local news = newo:octet():string()
	empty(news)
	ACK[news] = ACK[old]
	ACK[old] = nil
	CODEC[news] = CODEC[old]
	CODEC[old] = nil
end)
When("rename object named by '' to named by ''", function(old,new)
	local oldo = have(old)
	local olds = oldo:octet():string()
	have(olds)
	local newo = have(new)
	local news = newo:octet():string()
	empty(news)
	ACK[news] = ACK[olds]
	ACK[olds] = nil
	CODEC[news] = CODEC[olds]
	CODEC[olds] = nil
end)

When("create '' string of ''", function(encoding, src)
		local orig = have(src)
		zencode_assert(luatype(orig) ~= 'table', "Source element is not a table: "..src)
		empty(encoding) -- destination name is encoding name
		local f = get_encoding_function(encoding)
		zencode_assert(f, "Encoding format not found: "..encoding)
		ACK[encoding] = O.from_string( f( orig:octet() ) )
		new_codec(encoding, { zentype = 'e',
							  luatype = 'string',
							  encoding = 'string' })
end)

When("copy '' to ''", function(old,new)
	have(old)
	empty(new)
	ACK[new] = deepcopy(ACK[old])
	new_codec(new, { }, old)
end)

When("copy contents of '' in ''", function(src,dst)
    local obj, obj_codec = have(src)
    zencode_assert(luatype(obj) == 'table', "Object is not a table: "..src)
    local dest, dest_codec = have(dst)
    zencode_assert(luatype(dest) == 'table', "Object is not a table: "..src)
    if dest_codec.zentype == 'a' then
        for _, v in pairs(obj) do
            table.insert(ACK[dst], v)
        end
    elseif dest_codec.zentype == 'd' then
        zencode_assert(obj_codec.zentype == 'd', "Can not copy contents of an array into a dictionary")
        for k, v in pairs(obj) do
            if ACK[dst][k] then error("Cannot overwrite: "..k.." in "..dst) end
            ACK[dst][k] = v
        end
    elseif dest_codec.zentype == 'e' and dest_codec.schema then
        local dest_schema = ZEN.schemas[dest_codec.schema]
        if luatype(dest_schema) ~= 'table' then -- old schema types are not open
            error("Schema is not open to accept extra objects: "..dst)
        elseif not dest_schema.schematype or dest_schema.schematype ~= 'open' then
            error("Schema is not open to accept extra objects: "..dst)
        end
        for k, v in pairs(obj) do
            if ACK[dst][k] then error("Cannot overwrite: "..k.." in "..dst) end
            ACK[dst][k] = v
        end
    end
end)

When("copy contents of '' named '' in ''", function(src,name,dst)
    local obj, obj_codec = have(src)
    zencode_assert(luatype(obj) == 'table', "Object is not a table: "..src)
    zencode_assert(obj_codec.zentype == 'd', "Object is not a dictionary: "..src)
    zencode_assert(obj[name], "Object not found: "..name.." inside ".. src)
    local dest, dest_codec = have(dst)
    zencode_assert(luatype(dest) == 'table', "Object is not a table: "..src)
    if dest_codec.zentype == 'a' then
        table.insert(ACK[dst], obj[name])
    elseif dest_codec.zentype == 'd' then
        zencode_assert(dest[name], "Cannot overwrite: "..name.." in "..dst)
        ACK[dst][name] = obj[name]
    elseif dest_codec.zentype == 'e' and dest_codec.schema then
        local dest_schema = ZEN.schemas[dest_codec.schema]
        if luatype(dest_schema) ~= 'table' then -- old schema types are not open
            error("Schema is not open to accept extra objects: "..dst)
        elseif not dest_schema.schematype or dest_schema.schematype ~= 'open' then
            error("Schema is not open to accept extra objects: "..dst)
        end
        zencode_assert(dest[name], "Cannot overwrite: "..name.." in "..dst)
        ACK[dst][name] = obj[name]
    end
end)

local function move_or_copy_from_to(ele, source, new)
    local src, src_codec = have(source)
    zencode_assert(src[ele], "Object not found: "..ele.." inside "..source)
    if ACK[new] then
        error("Cannot overwrite existing object: "..new.."\n"..
              "To copy/move element in existing element use:\n"..
              "When I move/copy '' from '' in ''", 2)
    end
    ACK[new] = deepcopy(src[ele])
    local n_codec = { encoding = src_codec.encoding }
    -- table of schemas can only contain elements
    if src_codec.schema then
        n_codec.schema = src_codec.schema
        n_codec.zentype = "e"
    end
    new_codec(new, n_codec)
end

When("copy '' from '' to ''", move_or_copy_from_to)

When("move '' from '' to ''", function(ele, source, new)
    move_or_copy_from_to(ele, source, new)
    ACK[source][ele] = nil
end)

When("split rightmost '' bytes of ''", function(len, src)
	local obj = have(src)
	empty'rightmost'
	local s = tonumber(len)
	zencode_assert(s, "Invalid number arg #1: "..type(len))
	local l,r = OCTET.chop(obj,#obj-s)
	ACK.rightmost = r
	ACK[src] = l
	new_codec('rightmost', { }, src)
end)

When("split leftmost '' bytes of ''", function(len, src)
	local obj = have(src)
	empty'leftmost'
	local s = tonumber(len)
	zencode_assert(s, "Invalid number arg #1: "..type(len))
	local l,r = OCTET.chop(obj,s)
	ACK.leftmost = l
	ACK[src] = r
	new_codec('leftmost', { }, src)
end)

local function _numinput(num)
	local t = type(num)
	if not iszen(t) then
		if t == 'table' then
			local aggr = nil
			for _,v in pairs(num) do
				if aggr then
                    aggr = aggr + _numinput(v)
                else
                    aggr = _numinput(v)
                end
			end
			return aggr
		elseif t ~= 'number' then
			error('Invalid numeric type: ' .. t, 2)
		end
		return num
	end
	if t == 'zenroom.octet' then
		return BIG.new(num)
	elseif t == 'zenroom.big' or t == 'zenroom.float' then
		return num
	else
		return BIG.from_decimal(num:octet():string()) -- may give internal errors
	end
	error("Invalid number", 2)
	return nil
end

-- escape math function overloads for pointers
local function _add(l,r) return(l + r) end
local function _sub(l,r) return(l - r) end
local function _mul(l,r) return(l * r) end
local function _div(l,r) return(l / r) end
local function _mod(l,r) return(l % r) end

local function _math_op(op, l, r, bigop)
	local left  = _numinput(l)
	local right = _numinput(r)
	local lz = type(left)
	local rz = type(right)
	if lz ~= rz then error("Incompatible numeric arguments", 2) end
	ACK.result = true -- new_codec checks existance
	if lz == "zenroom.big" then
		new_codec('result',
				  {encoding = 'integer',
				   zentype = 'e'}
		)

	else
		new_codec('result',
				  {encoding = 'float',
				   zentype = 'e'}
		)
	end
        if type(left) == 'zenroom.big'
          and type(right) == 'zenroom.big' then
          if bigop then
            op = bigop
          -- -- We should check if the operatoin is supported
          --else
          --  error("Operation not supported on big integers")
          end
        end
	return op(left, right)
end

When("create result of '' inverted sign", function(left)
	local l = have(left)
	empty 'result'
        local zero = 0;
        if type(l) == "zenroom.big" then
            zero = INT.new(0)
        elseif type(l) == "zenroom.float" then
            zero = F.new(0)
        end
	ACK.result = _math_op(_sub, zero, l, BIG.zensub)
end)

When("create result of '' + ''", function(left,right)
	local l = have(left)
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_add, l, r, BIG.zenadd)
end)

When("create result of '' in '' + ''", function(left, dict, right)
	local d = have(dict)
	local l = d[left]
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_add, l, r, BIG.zenadd)
end)

When("create result of '' in '' + '' in ''", function(left, ldict, right, rdict)
	local ld = have(ldict)
	local l = ld[left]
	local rd = have(rdict)
	local r = rd[right]
	empty 'result'
	ACK.result = _math_op(_add, l, r, BIG.zenadd)
end)

When("create result of '' - ''", function(left,right)
	local l = have(left)
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_sub, l, r, BIG.zensub)
end)

When("create result of '' in '' - ''", function(left, dict, right)
	local d = have(dict)
	local l = d[left]
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_sub, l, r, BIG.zensub)
end)

When("create result of '' in '' - '' in ''", function(left, ldict, right, rdict)
	local ld = have(ldict)
	local l = ld[left]
	local rd = have(rdict)
	local r = rd[right]
	empty 'result'
	ACK.result = _math_op(_sub, l, r, BIG.zensub)
end)

When("create result of '' * ''", function(left,right)
	local l = have(left)
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_mul, l, r, BIG.zenmul)
end)

When("create result of '' in '' * ''", function(left, dict, right)
	local d = have(dict)
	local l = d[left]
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_mul, l, r, BIG.zenmul)
end)

When("create result of '' * '' in ''", function(left, right, dict)
	local l = have(left)
	local d = have(dict)
	local r = d[right]
	empty 'result'
	ACK.result = _math_op(_mul, l, r, BIG.zenmul)
end)

When("create result of '' in '' * '' in ''", function(left, ldict, right, rdict)
	local ld = have(ldict)
	local l = ld[left]
	local rd = have(rdict)
	local r = rd[right]
	empty 'result'
	ACK.result = _math_op(_mul, l, r, BIG.zenmul)
end)

When("create result of '' / ''", function(left,right)
	local l = have(left)
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_div, l, r, BIG.zendiv)
end)

When("create result of '' in '' / ''", function(left, dict, right)
	local d = have(dict)
	local l = d[left]
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_div, l, r, BIG.zendiv)
end)

When("create result of '' / '' in ''", function(left, right, dict)
	local l = have(left)
	local d = have(dict)
	local r = d[right]
	empty 'result'
	ACK.result = _math_op(_div, l, r, BIG.zendiv)
end)

When("create result of '' in '' / '' in ''", function(left, ldict, right, rdict)
	local ld = have(ldict)
	local l = ld[left]
	local rd = have(rdict)
	local r = rd[right]
	empty 'result'
	ACK.result = _math_op(_div, l, r, BIG.zendiv)
end)

When("create result of '' % ''", function(left,right)
	local l = have(left)
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_mod, l, r, BIG.zenmod)
end)

When("create result of '' in '' % ''", function(left, dict, right)
	local d = have(dict)
	local l = d[left]
	local r = have(right)
	empty 'result'
	ACK.result = _math_op(_mod, l, r, BIG.zendiv)
end)

When("create result of '' in '' % '' in ''", function(left, ldict, right, rdict)
	local ld = have(ldict)
	local l = ld[left]
	local rd = have(rdict)
	local r = rd[right]
	empty 'result'
	ACK.result = _math_op(_mod, l, r, BIG.zendiv)
end)

local function _countchar(haystack, needle)
    return select(2, string.gsub(haystack, needle, ""))
end
When("create count of char '' found in ''", function(needle, haystack)
	local h = have(haystack)
	empty'count'
--	ACK.count = _countchar(O.to_string(h), needle)
	ACK.count = F.new(h:octet():charcount(tostring(needle)))
	new_codec('count',
		  {encoding = 'number',
		   zentype = 'e' })
end)

-- TODO:
-- When("set '' as '' with ''", function(dest, format, content) end)
-- When("append '' as '' to ''", function(content, format, dest) end)
-- When("write '' as '' in ''", function(content, dest) end)
-- implicit conversion as string

-- https://github.com/dyne/Zenroom/issues/175
When("remove zero values in ''", function(target)
    local types = {"number", "zenroom.float", "zenroom.big"}
    local zeros = {0, F.new(0), BIG.new(0)}
	have(target)
	ACK[target] = deepmap(function(v)
        for i =1,#types do
            if type(v) == types[i] then
                if v == zeros[i] then
                    return nil
                else
                    return v
                end
            end
            i = i + 1
        end
        return v
	end, ACK[target])
end)

When("remove spaces in ''", function(target)
    local src = have(target)
    zencode_assert(not isnumber(src), "Invalid number object: "..target)
    zencode_assert(luatype(src) ~= 'table', "Invalid table object: "..target)
    ACK[target] = src:octet():rmchar( O.from_hex('20') )
end)

When("remove newlines in ''", function(target)
    local src = have(target)
    zencode_assert(not isnumber(src), "Invalid number object: "..target)
    zencode_assert(luatype(src) ~= 'table', "Invalid table object: "..target)
    ACK[target] = src:octet():rmchar( O.from_hex('0A') )
end)

When("remove all occurrences of character '' in ''",
     function(char, target)
    local src = have(target)
    local ch = have(char)
    zencode_assert(not isnumber(src), "Invalid number object: "..target)
    zencode_assert(luatype(src) ~= 'table', "Invalid table object: "..target)
    zencode_assert(not isnumber(ch), "Invalid number object: "..char)
    zencode_assert(luatype(ch) ~= 'table', "Invalid table object: "..char)
    ACK[target] = src:octet():rmchar( ch:octet() )
end)

When("compact ascii strings in ''",
     function(target)
	local src = have(target)
	zencode_assert(not isnumber(src), "Invalid number object: "..target)
	zencode_assert(luatype(src) ~= 'table', "Invalid table object: "..target)
    ACK[target] = src:octet():compact_ascii()
end)

local function utrim(s)
  s = string.gsub(s, "^[%s_]+", "")
  s = string.gsub(s, "[%s_]+$", "")
  return s
end

-- When("remove all empty strings in ''", function(target)
-- 	have(target)
-- 	ACK[target] = deepmap(function(v) if trim(v) == '' then return nil end, ACK[target])
-- end)

When("create '' cast of strings in ''", function(conv, source)
	zencode_assert(CODEC[source], "Object has no codec: "..source)
	zencode_assert(CODEC[source].encoding == 'string', "Object has no string encoding: "..source)
	empty(conv)
	local src = have(source)
	local enc = input_encoding(conv)
	if luatype(src) == 'table' then
	   ACK[conv] = deepmap(function(v)
		 local s = OCTET.to_string(v)
		 zencode_assert(enc.check(s), "Object value is not a "..conv..": "..source)
		 return enc.fun( s )
	   end, src)
	else
	   local s = OCTET.to_string(src)
	   zencode_assert(enc.check(s), "Object value is not a "..conv..": "..source)
	   ACK[conv] = enc.fun(s)
	end
	new_codec(conv, {encoding = conv})
end)

When("create float '' cast of integer in ''", function(dest, source)
	empty(dest)
	local src = have(source)
    if type(src) ~= 'zenroom.big' then
        src = BIG.new(src)
    end
    ACK[dest] = F.new(BIG.to_decimal(src))
	new_codec(dest, {encoding = 'float'})
end)

When("seed random with ''",
     function(seed)
	local s = have(seed)
	zencode_assert(iszen(type(s)), "New random seed is not a valid zenroom type: "..seed)
	local fingerprint = random_seed(s) -- pass the seed for srand init
	act("New random seed of "..#s.." bytes")
	xxx("New random fingerprint: "..fingerprint:hex())
     end
)

local int_ops2 = {['+'] = BIG.zenadd, ['-'] = BIG.zensub, ['*'] = BIG.zenmul, ['/'] = BIG.zendiv}
local float_ops2 = {['+'] = F.add, ['-'] = F.sub, ['*'] = F.mul, ['/'] = F.div}

local function apply_op2(op, a, b)
  local fop = nil
  if type(a) == 'zenroom.big' and type(b) == 'zenroom.big' then
    fop = int_ops2[op]
  elseif type(a) == 'zenroom.float' and type(b) == 'zenroom.float' then
    fop = float_ops2[op]
  end
  zencode_assert(fop, "Unknown types to do arithmetics on", 2)
  return fop(a, b)
end

local int_ops1 = {['~'] = BIG.zenopposite}
local float_ops1 = {['~'] = F.opposite}

local function apply_op1(op, a)
  local fop = nil
  if type(a) == 'zenroom.big' then
    fop = int_ops1[op]
  elseif type(a) == 'zenroom.float' then
    fop = float_ops1[op]
  end
  zencode_assert(fop, "Unknown type to do arithmetics on", 2)
  return fop(a)
end


-- ~ is unary minus
local priorities = {['+'] = 0, ['-'] = 0, ['*'] = 1, ['/'] = 1, ['~'] = 2}
When("create result of ''", function(expr)
  local specials = {'(', ')'}
  local i, j
  empty 'result'
  for k, v in pairs(priorities) do
    table.insert(specials, k)
  end
  -- tokenizations
  local re = '[()*%-%/+]'
  local tokens = {}
  i = 1
  repeat
    j = expr:find(re, i)
    if j then
      if i < j then
        local val = utrim(expr:sub(i, j-1))
        if val ~= "" then table.insert(tokens, val) end
      end
      table.insert(tokens, expr:sub(j, j))
      i = j+1
    end
  until not j
  if i <= #expr then
    local val = utrim(expr:sub(i))
    if val ~= "" then table.insert(tokens, val) end
  end

  -- infix to RPN
  local rpn = {}
  local operators = {}
  for k, v in pairs(tokens) do
    if v == '-' and (#rpn == 0 or operators[#operators] == '(') then
        table.insert(operators, '~') -- unary minus (change sign)
    elseif priorities[v] then
      while #operators > 0 and operators[#operators] ~= '('
           and priorities[operators[#operators]]>=priorities[v] do
        table.insert(rpn, operators[#operators])
        operators[#operators] = nil
      end
      table.insert(operators, v)
    elseif v == '(' then
      table.insert(operators, v)
    elseif v == ')' then
      -- put every operator in rpn until I don't see the open parens
      while #operators > 0 and operators[#operators] ~= '(' do
        table.insert(rpn, operators[#operators])
        operators[#operators] = nil
      end
      zencode_assert(#operators > 0, "Paranthesis not balanced", 2)
      operators[#operators] = nil -- remove open parens
    else
      table.insert(rpn, v)
    end
  end

  -- all remaining operators have to be applied
  for i = #operators, 1, -1 do
    if operators[i] == '(' then
      zencode_assert(false, "Paranthesis not balanced", 2)
    end
    table.insert(rpn, operators[i])
  end

  local values = {}
  -- evaluate the expression
  for k, v in pairs(rpn) do
    if v == '~' then
      local op = values[#values]; values[#values] = nil
      table.insert(values, apply_op1(v, op))
    elseif priorities[v] then
      zencode_assert(#values >= 2)
      local op1 = values[#values]; values[#values] = nil
      local op2 = values[#values]; values[#values] = nil
      local res = apply_op2(v, op2, op1)
      table.insert(values, res)
    else
      local val
      -- is the current number a integer?
      if BIG.is_integer(v) then
        val = BIG.from_decimal(v)
      elseif F.is_float(v) then
        val = F.new(v)
      else
        val = have(v)
      end
      table.insert(values, val)
    end
  end

  zencode_assert(#values == 1, "Invalid arithmetical expression", 2)
  ACK.result = values[1]
  if type(values[1]) == 'zenroom.big' then
    new_codec('result',
			  {encoding = 'integer',
			   zentype = 'e' })
  elseif type(values[1]) == 'zenroom.float' then
    new_codec('result',
			  {encoding = 'number',
			   zentype = 'e' })
  end
end)
