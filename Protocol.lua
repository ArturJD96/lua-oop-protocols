local checks <const> = require 'checks'

local function _type(arg) -- any
    local arg_type <const> = type(arg)
    return (arg_type == 'table' and arg.__type) or arg_type
end

local Protocol = {
    __type = 'Protocol',
    _default_constructor_name = 'new'
}
Protocol.__index = Protocol

function Protocol.new(fields)
    checks('table')
    local self <const> = setmetatable({}, Protocol)
    self.constructor_name = Protocol._default_constructor_name
    self.fields = fields
    return self
end

function Protocol:conform(obj)
    checks('Protocol', 'table')
    for field_name, field_check in pairs(self.fields) do
        local field = field_check(obj, field_name, obj[field_name])
        obj[field_name] = field
    end
end

function Protocol.remove_all_protocols(class)
    class.__protocols = nil
    class.new = class.__new
    class.__new = nil
    return class
end

function Protocol:apply(class)
    checks('Protocol', 'table')

    if not class.__protocols then
        class.__protocols = {}
        class.__new = class.new
    end

    table.insert(class.__protocols, self)

    -- whenever constructor is called,
    -- the resulting object is checked
    -- if it conforms to all the protocols.
    class[self.constructor_name] = function(...)
        local obj <const> = class.__new(...)
        for _, protocol in ipairs(class.__protocols) do
            protocol:conform(obj)
        end
        return obj
    end
end

Protocol.errors = {
    TypeError = 'Protocol type error: ',
    TypeFormatError = 'Protocol type error: Type must be expressed as a string or table with .__type key.',
    FieldNotImplementedError = 'Protocol field error: field not implemented.\n',
    WrongFieldTypeError = 'Protocol type error: wrong field type.\n',
    -- CheckFunctionNotImplementedError = 'Protocol field subclass error: a field must have implemented "check" method accepting object, field name and field value.',
    NilDefaultError =
    'Protocol default field error: default value cannot be nil. To declare a typed field without default implementation, use "Type" instead.',
    NilFinalError =
    'Protocol final field error: final value cannot be nil. To declare a typed field without final implementation, use "Type" instead.',
    FinalFieldReassignedError = 'Protocol final field reassigned when instantiating ',
    CannotInstantiateError =
    'Protocol default/final field error: a field instantiated from class must have a constructor.',
}

local function CheckFactory(check)
    checks('function')
    local check_class = {
        __type = 'Check',
        __call = check,
    }
    check_class.__index = check_class
    check_class.new = function(value_getter)
        checks('function')
        local self = setmetatable({}, check_class)
        self.value_getter = value_getter
        return self
    end
    return check_class
end

local CheckType = CheckFactory(function(self, obj, field_name, field_value)
    checks('Check', 'table', 'string', '?')
    local expected_type = self:value_getter(obj)
    if field_value == nil then
        error(Protocol.errors.FieldNotImplementedError
            .. 'Field "' .. field_name
            .. '" of type ' .. expected_type
            .. ' not implemented in ' .. obj.__type .. ' instance.'
        )
    end
    if _type(field_value) ~= expected_type then
        error(Protocol.errors.WrongFieldTypeError
            .. _type(obj) .. ' instance field "' .. field_name .. '":\n'
            .. 'expected: ' .. expected_type .. '\n'
            .. 'actual:   ' .. _type(field_value)
        )
    end
end)

Protocol.Type = {
    __type = 'Protocol.InstanceField',
    __call = function(self, expected_type)
        expected_type = self._sanitize(expected_type)
        return CheckType.new(function() return expected_type end)
    end,

    _sanitize = function(type_)
        checks('string|table')
        if type(type_) == 'table' then
            return type_.__type or error(Protocol.errors.TypeFormatError)
        end
        return type_
    end,

    number = CheckType.new(function() return 'number' end),
    string = CheckType.new(function() return 'string' end),
    boolean = CheckType.new(function() return 'boolean' end),
    table = CheckType.new(function() return 'table' end),
    method = CheckType.new(function() return 'function' end) -- exception!
}
setmetatable(Protocol.Type, Protocol.Type)

local CheckDefault = CheckFactory(function(self, obj, field_name, field_value)
    checks('Check', 'table', 'string', '?')
    local default_value = self:value_getter(obj)
    if field_value == nil then
        return default_value
    end
    local expected_type = _type(default_value)
    if _type(field_value) ~= expected_type then
        error(Protocol.errors.WrongFieldTypeError
            .. _type(obj) .. ' instance field "' .. field_name .. '":\n'
            .. 'expected: ' .. expected_type .. '\n'
            .. 'actual:   ' .. _type(field_value)
        )
    end
    return field_value
end)

Protocol.Default = {
    __type = 'Protocol.InstanceField',
    __call = function(_, default_value)
        if default_value == nil then error(Protocol.errors.NilDefaultError) end
        return CheckDefault.new(function() return default_value end)
    end,

    table = CheckDefault.new(function() return {} end),

    instance = function(class, ...)
        checks('table')
        local constructor, args = class[Protocol._default_constructor_name], { ... }
        if not constructor then error(Protocol.errors.CannotInstantiateError) end
        return CheckDefault.new(function() return constructor(table.unpack(args)) end)
    end
}
setmetatable(Protocol.Default, Protocol.Default)

local CheckFinal = CheckFactory(function(self, obj, field_name, field_value)
    checks('Check', 'table', 'string', '?')
    if field_value ~= nil then
        error(Protocol.errors.FinalFieldReassignedError
            .. _type(obj) .. ' (final field "' .. field_name .. '")'
        )
    else
        return self:value_getter(obj)
    end
end)

Protocol.Final = {
    __type = 'Protocol.InstanceField',
    __call = function(self, final_value)
        if final_value == nil then error(Protocol.errors.NilFinalError) end
        return CheckFinal.new(function() return final_value end)
    end,

    table = CheckFinal.new(function() return {} end),

    instance = function(class, ...)
        checks('table')
        local constructor, args = class[Protocol._default_constructor_name], { ... }
        if not constructor then error(Protocol.errors.CannotInstantiateError) end
        return CheckFinal.new(function() return constructor(table.unpack(args)) end)
    end
}
setmetatable(Protocol.Final, Protocol.Final)

return Protocol
