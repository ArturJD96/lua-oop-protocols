local lu <const> = require 'luaunit'
local Protocol <const> = require 'Protocol'

local Final <const> = Protocol.Final

local ClassType <const> = Protocol.ClassType
local ClassDefault <const> = Protocol.ClassDefault
local ClassFinal <const> = Protocol.ClassFinal
--[[
    Note: Current understanding of classes
    (that a class is a table that points to itself and has constructor)
    doesn't allow for an effective static methods (ClassMethod) verification
    (i.e. static method can be called also from instance. That's a no-no?).'
]]

--[[ Testing: class vs instance method ]]

TestClassCheck = {}

function TestClassCheck:test_field_assignment()
    -- if table has a .__type field,
    -- apply all field Checks to instances
    -- using constructor wrapping;
    -- otherwise, apply it to class itself.

    local expected_field_value = 'a field value'

    local protocol = Protocol.new({
        field = Final(expected_field_value)
    })

    local class <const> = { __type = 'class' }
    class.__index = class
    function class.new() return setmetatable({}, class) end

    protocol:apply(class)
    lu.assertEquals(class.new().field, expected_field_value)
    lu.assertNil(class.field)

    local struct <const> = {}
    protocol:apply(struct)
    lu.assertEquals(struct.field, expected_field_value)
end

function TestClassCheck:test_class_field_assignment()
    local expected_class_field_value = 'a class field value'

    local protocol = Protocol.new({
        class_field = ClassFinal(expected_class_field_value)
    })

    local class <const> = { __type = 'class' }
    class.__index = class
    function class.new() return setmetatable({}, class) end

    protocol:apply(class)
    lu.assertEquals(class.new().class_field, expected_class_field_value) -- this is unfortunate but happens because of how lua class instances index back to it's prototype.'
    lu.assertEquals(class.class_field, expected_class_field_value)

    local not_class <const> = {}
    lu.assertErrorMsgContains(ProtocolError.ClassFieldNotInClassError, protocol.apply, protocol, not_class)
end

function TestClassCheck:test_class_fields()
    local class_default_field = 'class default field'
    local class_final_field = 'class final field'
    local protocol = Protocol.new({
        class_typed_field = ClassType.string,
        class_default_field = ClassDefault(class_default_field),
        class_final_field = ClassFinal(class_final_field)
    })

    local test_class <const> = { __type = 'class' }
    test_class.__index = test_class
    function test_class.new() return setmetatable({}, test_class) end

    print(test_class.__protocols, test_class.class_final_field)

    lu.assertErrorMsgContains(ProtocolError.FieldNotImplementedError, protocol.apply, protocol, test_class)

    print(test_class.__protocols, test_class.class_final_field)

    test_class.class_typed_field = 0
    lu.assertErrorMsgContains(ProtocolError.WrongFieldTypeError, protocol.apply, protocol, test_class)

    assert(false, "The test above SOMETIMES fails (lol?) with:"
        .. "./tests/TestField.lua:XXX: Error message does not contain:"
        .. '"Protocol type error: wrong field type."'
        .. 'Error message received:'
        .. "'./Protocol.lua:XXX: Protocol final field reassigned when instantiating class (final field \"class_final_field\")'")

    test_class.class_typed_field = 'string (that was expected!)'
    protocol:apply(test_class)

    lu.assertEquals(test_class.class_default_field, class_default_field)
end
