local lu <const> = require 'luaunit'

require 'tests/TestProtocol'
require 'tests/TestField'

os.exit(lu.LuaUnit.run())
