local lu <const> = require 'luaunit'

require 'tests/TestProtocol'
require 'tests/TestField'
-- require 'tests/TestRegistrable'

os.exit(lu.LuaUnit.run())
