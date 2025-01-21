local lu <const> = require 'luaunit'
local Protocol <const> = require 'Protocol'

TestMethod = {}

local Method <const> = Protocol.Method

function TestMethod:test_instance_methods_are_class_properties()
    local class_with_method = {}
    class_with_method.__index = class_with_method
    function class_with_method.new() return setmetatable({}, class_with_method) end

    local method = function() end
    class_with_method.method = method

    --[[
            Final method of the protocol should be implemented
            when applying protocol. Checking if it is findable in the prototype.
    ]]

    local protocol = Protocol.new({ method = Method() })

    protocol:apply(class_with_method)
    local instance = class_with_method.new()
    lu.assertEquals(instance.method, method)
    lu.assertEquals(class_with_method.method, method)
end

function TestMethod:test_method_already_implemented()
    local class = {}
    class.__index = class
    function class.new() return setmetatable({}, class) end

    --[[
            Final method of the protocol should be implemented
            when applying protocol. Checking if it is findable in the prototype.
    ]]

    local required_method = Method()
    local final_method = Method(function(self) return self.type end)

    local protocol_implemented_method = Protocol.new({ implemented_method = required_method })
    local protocol_final_method = Protocol.new({ final_method = final_method })

    lu.assertErrorMsgContains(ProtocolError.MethodNotImplemented, protocol_implemented_method.apply,
        protocol_implemented_method, class)
    function class:implemented_method() return self end

    protocol_implemented_method:apply(class) -- should work!
    function class:final_method() return self end

    lu.assertErrorMsgContains(ProtocolError.MethodAlreadyImplemented, protocol_final_method.apply,
        protocol_final_method, class)
    class.final_method = nil
    protocol_final_method:apply(class)
    local instance = class.new()
    lu.assertEquals(instance.implemented_method, class.implemented_method)
    lu.assertEquals(instance.final_method, class.final_method)
end

function TestMethod:test_instances_inherit_the_same_method()
    local class = {}
    class.__index = class
    function class.new(id) return setmetatable({ id = id }, class) end

    local method = function(self) return self.type end
    local protocol = Protocol.new({ method = Method(method) })
    protocol:apply(class)
    local instance_1 = class.new('1')
    local instance_2 = class.new('2')
    lu.assertNotEquals(instance_1.id, instance_2.id)
    lu.assertEquals(instance_1.method, instance_2.method, class.method)
end

function TestMethod:test_method_accepts_only_table_or_functions()
    local method_wrong_type = 'NOT A FUNCTION NOR TABLE'
    lu.assertErrorMsgContains('bad argument #2', Method, method_wrong_type)
end

function TestMethod:test_method_accepts_callable()
    local callable_tab = setmetatable({}, { __call = function() end })
    lu.assertEquals(Method(callable_tab).value_getter, callable_tab)
end

function TestMethod:test_method_assigned_to_table()
    local tab = {}
    local method = function(self) return end
    local protocol = Protocol.new({ method = Method(method) })
    protocol:apply(tab)
    lu.assertEquals()
end
