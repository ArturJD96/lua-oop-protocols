local checks <const> = require 'checks'
local lu <const> = require 'luaunit'
local Protocol <const> = require 'Protocol'

local Type <const> = Protocol.Type
local Default <const> = Protocol.Default
local Final <const> = Protocol.Final
local Condition <const> = Protocol.Condition

ProtocolError = Protocol.errors

local function shallow_copy(tab)
    checks('table')
    local copy = {}
    for key, value in pairs(tab) do copy[key] = value end
    return copy
end

local function get_random_key(tab)
    checks('table')
    local keys <const> = {}
    for key, _ in pairs(tab) do table.insert(keys, key) end
    return keys[math.random(1, #keys)]
end

local function compare_refs(lu_assertion_func, ...)
    lu.TABLE_EQUALS_KEYBYCONTENT = false
    lu_assertion_func(...)
    lu.TABLE_EQUALS_KEYBYCONTENT = true
end

local function assertRefsEquals(...)
    lu.TABLE_EQUALS_KEYBYCONTENT = false
    lu.assertEquals(...)
    lu.TABLE_EQUALS_KEYBYCONTENT = true
end

local function assertRefsNotEquals(...)
    lu.TABLE_EQUALS_KEYBYCONTENT = false
    lu.assertNotEquals(...)
    lu.TABLE_EQUALS_KEYBYCONTENT = true
end

TestField = { __type = 'TestField' }
TestField.__index = TestField

function TestField:setup_classes() -- make it into a separate function and call it in each setup
    self.type = 'class'
    -- dummy implementation of a tested class
    self.class = { __type = self.type }
    self.class.__index = self.class
    function self.class:set_constructor_table(tab)
        self.new = function()
            local obj = (tab and shallow_copy(tab)) or {}
            return setmetatable(obj, self)
        end
    end

    -- adding method outside constructor (as is the custom)
    function self.class:method() return 'method-value' end

    -- some other class
    self.some_class = { __type = 'SomeType' }
    self.some_class.__index = self.some_class
    self.some_class.new = function(arg) return setmetatable({ arg = 'arg' }, self.some_class) end

    -- a class that cannot exist
    self.non_existent_typed_class = { __type = 'NonExistentType' }
    self.non_existent_typed_class.__index = self.non_existent_typed_class
    self.non_existent_typed_class.new = function() return setmetatable({}, self.non_existent_typed_class) end
end

TestType = setmetatable({ __type = 'TestType' }, TestField)

function TestType:setup()
    self:setup_classes()
    self.protocol = Protocol.new({
        -- lua types
        number = Type.number,
        string = Type.string,
        boolean = Type.boolean,
        table = Type.table,
        method = Type.method, -- 'function' is not allowed here. Usually implemented outside constructor (covered!).
        -- other class instances
        instance_typed_with_class = Type(self.some_class),
        instance_typed_with_string = Type(self.some_class.__type)
    })
    self.constructor_table = {
        number = 42,
        string = 'Poland',
        boolean = false,
        table = {},
        -- Note: 'method' field set by self.class definition.
        instance_typed_with_class = self.some_class.new(),
        instance_typed_with_string = self.some_class.new()
    }
end

function TestType:test_correct_constructor()
    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    lu.assertEquals(self.class.new().__type, self.type)
end

function TestType:test_constructor_lacking_required_type_field()
    local random_removed_key <const> = get_random_key(self.constructor_table)
    local insufficient_constructor <const> = shallow_copy(self.constructor_table)
    insufficient_constructor[random_removed_key] = nil
    self.class:set_constructor_table(insufficient_constructor)
    self.protocol:apply(self.class)
    lu.assertErrorMsgContains(ProtocolError.FieldNotImplementedError, self.class.new)
end

function TestType:test_constructor_has_field_of_wrong_type()
    local random_key <const> = get_random_key(self.constructor_table)
    local wrong_constructor <const> = shallow_copy(self.constructor_table)
    wrong_constructor[random_key] = self.non_existent_typed_class
    self.class:set_constructor_table(wrong_constructor)
    self.protocol:apply(self.class)
    lu.assertErrorMsgContains(ProtocolError.WrongFieldTypeError, self.class.new)
end

TestDefault = setmetatable({ __type = 'TestDefault' }, TestField)

function TestDefault:setup()
    self:setup_classes()
    self.same_table = {}
    self.same_instance = self.some_class.new('same instance!')
    self.make_args = function(self_of_class_instance)
        return tostring(self_of_class_instance.number) ..
            self_of_class_instance.string
    end
    self.default_implementation_values = {
        -- default implementations (can be overwritten)
        number = 0,
        string = 'default-string',
        boolean = true,
        -- referencing same objects:
        method = function(self) return self.type end,
        table_refencing_same_table = self.same_table,
        instance_referencing_same_object = self.same_instance,
        -- referencing various objects:
        -- NOTE: those values are unknown and can't be checked yet
        --       because the are different for each class instance.
        -- table_refencing_different_tables
        -- instance_referencing_different_objects
    }
    self.protocol = Protocol.new({
        number = Default(self.default_implementation_values.number),
        string = Default(self.default_implementation_values.string),
        boolean = Default(self.default_implementation_values.boolean),
        -- referencing same objects:
        method = Default(self.default_implementation_values.method),
        table_refencing_same_table = Default(self.same_table),
        instance_referencing_same_object = Default(self.same_instance),
        -- referencing various objects:
        table_refencing_different_tables = Default.table,
        instance_referencing_different_objects = Default.instance(self.some_class, 'arg'),
    })
    local other_table <const> = {}
    local other_instance <const> = self.some_class.new('other instance (but still same for all class instances)!')
    self.constructor_table = {
        -- overriding all default implementations
        number = 42,
        string = 'Poland',
        boolean = false,
        -- Note: 'method' field set by self.class definition.
        table_refencing_same_table = {},
        instance_referencing_same_object = self.same_instance.new(),
        table_refencing_different_tables = {},
        instance_referencing_different_objects = self.same_instance.new(),
    }
end

function TestDefault:test_constructor_lacking_required_type_field()
    local empty_constructor_table = {}
    self.class.method = nil
    self.class:set_constructor_table(empty_constructor_table)
    self.protocol:apply(self.class)
    local obj_all_fields_default <const> = self.class.new()
    for field, value in pairs(self.default_implementation_values) do
        lu.assertEquals(obj_all_fields_default[field], value)
    end
end

function TestDefault:test_constructor_overriding_default_values()
    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    local obj_all_fields_overriden <const> = self.class.new()
    for field, _ in pairs(self.default_implementation_values) do
        if field ~= 'method' then
            lu.assertEquals(obj_all_fields_overriden[field], self.constructor_table[field])
        end
    end
    lu.assertEquals(obj_all_fields_overriden.method, self.class.method)
end

function TestDefault:test_constructor_has_field_of_wrong_type()
    local random_key <const> = get_random_key(self.constructor_table)
    local wrong_constructor <const> = shallow_copy(self.constructor_table)
    wrong_constructor[random_key] = self.non_existent_typed_class
    self.class:set_constructor_table(wrong_constructor)
    self.protocol:apply(self.class)
    lu.assertErrorMsgContains(ProtocolError.WrongFieldTypeError, self.class.new)
end

function TestDefault:test_two_instances_reference_different_default_tables()
    self.class:set_constructor_table({})
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertFalse(obj1.table_refencing_different_tables == obj2.table_refencing_different_tables)
end

function TestDefault:test_two_instances_reference_same_default_objects()
    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertTrue(obj1.table_refencing_same_table == obj2.table_refencing_same_table)
    lu.assertTrue(obj1.instance_referencing_same_object == obj2.instance_referencing_same_object)
end

function TestDefault:test_two_instances_reference_different_new_objects()
    self.class:set_constructor_table()
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertFalse(obj1.table_refencing_different_tables == obj2.table_refencing_different_tables)
    lu.assertFalse(obj1.instance_referencing_different_objects == obj2.instance_referencing_different_objects)
end

TestFinal = setmetatable({ __type = 'TestFinal' }, TestField)

function TestFinal:setup()
    self:setup_classes()
    self.class.method = nil -- will be assigned using final.
    self.same_table = {}
    self.same_instance = self.some_class.new('same instance!')
    self.make_args = function(self_of_class_instance)
        return tostring(self_of_class_instance.number) ..
            self_of_class_instance.string
    end
    self.final_implementation_values = {
        -- default implementations (can be overwritten)
        number = 0,
        string = 'final-string',
        boolean = true,
        -- referencing same objects:
        method = function(self) return self.type end,
        table_refencing_same_table = self.same_table,
        instance_referencing_same_object = self.same_instance,
        -- referencing various objects:
        -- NOTE: those values are unknown and can't be checked yet
        --       because the are different for each class instance.
        -- table_refencing_different_tables
        -- instance_referencing_different_objects
    }
    self.protocol = Protocol.new({
        number = Final(self.final_implementation_values.number),
        string = Final(self.final_implementation_values.string),
        boolean = Final(self.final_implementation_values.boolean),
        -- referencing same objects:
        method = Final(self.final_implementation_values.method),
        table_refencing_same_table = Final(self.same_table),
        instance_referencing_same_object = Final(self.same_instance),
        -- referencing various objects:
        table_refencing_different_tables = Final.table,
        instance_referencing_different_objects = Final.instance(self.some_class, 'arg')
    })
    self.constructor_table = {
        non_final_property = self.some_class.new()
    }
end

function TestFinal:test_instance_receiving_final_fields()
    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    local obj_with_final_fields <const> = self.class.new()
    lu.assertEquals(self.class.new().__type, self.type)
    for field, value in pairs(self.final_implementation_values) do
        lu.assertEquals(obj_with_final_fields[field], value)
    end
    lu.assertEquals(obj_with_final_fields.some_property, self.constructor_table.some_property)
end

function TestFinal:test_constructor_reassigning_final_fields()
    local random_key <const> = get_random_key(self.final_implementation_values)
    local wrong_constructor <const> = shallow_copy(self.constructor_table)
    wrong_constructor[random_key] = self.non_existent_typed_class.new()
    self.class:set_constructor_table(wrong_constructor)
    self.protocol:apply(self.class)
    lu.assertErrorMsgContains(ProtocolError.FinalFieldReassignedError, self.class.new)
end

function TestFinal:test_reassigning_final_method_using_method_definition()
    function self.class:method()
        return "attempting to reassing final method"
    end

    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    lu.assertErrorMsgContains(ProtocolError.FinalFieldReassignedError, self.class.new)
end

function TestFinal:test_two_instances_reference_different_default_tables()
    self.class:set_constructor_table()
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertFalse(obj1.table_refencing_different_tables == obj2.table_refencing_different_tables)
end

function TestFinal:test_two_instances_reference_same_default_objects()
    -- this is desired behaviour!
    self.class:set_constructor_table(self.constructor_table)
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertTrue(obj1.table_refencing_same_table == obj2.table_refencing_same_table)
    lu.assertTrue(obj1.instance_referencing_same_object == obj2.instance_referencing_same_object)
end

function TestFinal:test_two_instances_reference_different_new_objects()
    -- this is desired behaviour!
    self.class:set_constructor_table()
    self.protocol:apply(self.class)
    local obj1 = self.class.new()
    local obj2 = self.class.new()
    lu.assertFalse(obj1.table_refencing_different_tables == obj2.table_refencing_different_tables)
    lu.assertFalse(obj1.instance_referencing_different_objects == obj2.instance_referencing_different_objects)
end

os.exit(lu.LuaUnit.run())
