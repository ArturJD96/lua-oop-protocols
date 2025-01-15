local lu <const> = require 'luaunit'
local Protocol <const> = require 'Protocol'

TestProtocol = {}

function TestProtocol:test_is_class()
    local protocol = Protocol.new({})

    local true_class = {}
    true_class.__index = true_class
    function true_class.new() return setmetatable({}, true_class) end

    lu.assertTrue(protocol:is_class(true_class))

    local class_instance = true_class.new()
    lu.assertFalse(protocol:is_class(class_instance))

    local table_pointing_to_itself   = { __type = 'dupa' }
    table_pointing_to_itself.__index = table_pointing_to_itself
    lu.assertFalse(protocol:is_class(table_pointing_to_itself))

    local table_only_with_constructor = {}
    function table_pointing_to_itself.new() return setmetatable({}, table_pointing_to_itself) end

    lu.assertFalse(protocol:is_class(table_only_with_constructor))

    local normal_table = {}
    lu.assertFalse(protocol:is_class(normal_table))
end

return TestProtocol
