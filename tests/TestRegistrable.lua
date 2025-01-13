local lu <const> = require 'luaunit'
local lfs <const> = require "lfs"
-- local Protocol <const> = require 'Protocol'
local Registrable <const> = require 'Registrable'

TestRegistrable = {}
function TestRegistrable:setup()
    -- make dummy class
    self.type = 'DummyClass'
    self.class = { __type = self.type }
    self.class.__index = self.class
    self.class.new = function(id)
        return setmetatable({ id = id }, self.class)
    end

    -- apply protocol
    Registrable:conform(self.class)

    -- register random number of objects
    self.objects_count = math.random(3, 10)
    for i = 1, self.objects_count, 1 do
        self.class.new('obj_' .. tostring(i))
    end
end

function TestRegistrable:teardown()
    self.class.reset_register()
end

function TestRegistrable:test_register_count()
    lu.assertEquals(self.class.register_count(), self.objects_count)
end

function TestRegistrable:test_delete()
    self.class.delete('obj_1')
    lu.assertEquals(self.class.register_count(), self.objects_count - 1)
    lu.assertNil(self.class._register['obj_1'])
end

function TestRegistrable:test_reset_register()
    self.class.reset_register()
    lu.assertEquals(self.class.register_count(), 0)
end

function TestRegistrable:test_default_id()
    self.class.reset_register()
    local obj = self.class.new()
    lu.assertEquals(obj.id, self.class._default_id .. '_1')
end

function TestRegistrable:test_new()
    self.class.new()
    self.class.new()
    self.class.new()
    lu.assertNotNil(self.class._register['class_1'])
    lu.assertNotNil(self.class._register['class_2'])
    lu.assertNotNil(self.class._register['class_3'])
    self.class.new('class_4')
    self.class.new()
    lu.assertNotNil(self.class._register['class_5'])
end

function TestRegistrable:test_delete_and_add_new()
    self.class.new()
    self.class.new()
    self.class.new()
    local expected_name = self.class._default_id .. '_2'
    local arbitrary_name = 'Test'
    lu.assertNotNil(self.class._register[expected_name])
    self.class.delete(expected_name)
    lu.assertNil(self.class._register[expected_name])
    self.class.new(arbitrary_name) --should not affect numeration.
    lu.assertNil(self.class._register[expected_name])
    self.class.new()
    lu.assertNotNil(self.class._register[expected_name])
    self.class.delete(arbitrary_name)
    lu.assertNotNil(self.class._register[expected_name])
end

function TestRegistrable:test_in_protocols_property()
    lu.assertEquals(#self.class.__protocols, 1)
    lu.assertEquals(self.class.__protocols, { Registrable })
end

function TestRegistrable:test_singleton()
    local expected_param = 'param'
    local class = { __type = 'class' }
    class.__index = self.class
    class.new = function(id)
        self = { param = expected_param }
        setmetatable(self, class)
        return self
    end
    Registrable:apply(class, { singleton = true })
    local c1 = self.class.new()
    local c2 = self.class.new() -- should return reference to c1 | OR THROW ERROR???
    lu.assertEquals(c1, c2)
end

os.exit(lu.LuaUnit.run())
