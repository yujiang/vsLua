--The following string variations are all valid Lua and should equate to the same value.

a = 'alo\n123"'

a = "a\s\d\f"

a = '\97lo\10\04923"'

a = [[ test ]]
a = [[ foo
]]

a = [=[ 1 level comment
	[[ nested string (should be commented) ]]
 asdf ]=]

local a = "foo"

--The following are invalid string variations.
a = 5[[alo

  123 ]];
  
a = [=];
a = [=[ wtf [[
	]=] ]];