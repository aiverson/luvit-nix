local lpeg = require("lpeg") or error("lpeg not found")
local match, P = lpeg.match, lpeg.P
assert(match(P("a"), "aaa") == 2, "LPEG should find a match for P'a' in 'aaa'")
