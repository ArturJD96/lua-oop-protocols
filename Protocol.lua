local checks <const> = require 'checks'

-- Question: how to define a 'class'?
-- https://stackoverflow.com/questions/65961478/how-to-mimic-simple-inheritance-with-base-and-child-class-constructors-in-lua-t

local function _type(arg) -- any
    local arg_type <const> = type(arg)
    return (arg_type == 'table' and arg.__type) or arg_type
end

local function is_callable(arg)
    local metatable = getmetatable(arg)
    return (type(arg) == 'function') or (metatable and metatable.__call)
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
    self.constructor_metamethod_name = '__' .. self.constructor_name
    self.fields = fields
    return self
end

function Protocol:conform_table(tab)
    checks('Protocol', 'table')
    for field_name, field_check in pairs(self.fields) do
        if field_check.class_field then
            error(Protocol.errors.ClassFieldNotInClassError .. self.constructor_name)
        end
        tab[field_name] = field_check(tab, field_name, tab[field_name])
    end
end

function Protocol:conform_class(class)
    checks('Protocol', 'table')
    for field_name, field_check in pairs(self.fields) do
        if field_check.class_field or field_check.method_field then
            class[field_name] = field_check(class, field_name, class[field_name])
        end
    end
end

function Protocol:conform_instance(instance)
    checks('Protocol', 'table')
    for field_name, field_check in pairs(self.fields) do
        if not (field_check.method_field or field_check.class_field) then
            instance[field_name] = field_check(instance, field_name, instance[field_name])
        end
    end
end

function Protocol:is_class(obj)
    checks('table')
    local points_to_itself = (obj.__index == obj)
    local has_constructor  = obj[self.constructor_name] ~= nil
    return (points_to_itself and has_constructor)
end

function Protocol:apply(tab)
    checks('Protocol', 'table')

    --[[ If anything here fails, protocol SHOULD not get assigned! ]]

    if not tab.__protocols then tab.__protocols = {} end

    for _, protocol in ipairs(tab.__protocols) do
        if protocol == self then
            error('Protocol already implemented.')
        end
    end

    table.insert(tab.__protocols, self)

    local function conform()
        -- compare existing fields with protocol added fields
        local field_names = {}
        for field_name, field in pairs(self) do
            table.insert(field_names, field_name)
        end
        --[[
            Perhaps: first do semantic analysis:
            – which fields are applied, which are not,
            which were applied but shouldn't (then raise error)
            etc...

            This should be done, because if something goes wrong,
            we can "undo" the applied fields without mistakenly
            overwriting/removing fields that are correctly assigned
            from the beginning.
        ]]

        if self:is_class(tab) then
            self:conform_class(tab)
            tab[self.constructor_metamethod_name] = tab[self.constructor_metamethod_name] or tab[self.constructor_name]
            tab[self.constructor_name] = function(...)
                local obj <const> = tab.__new(...)
                for _, protocol in ipairs(tab.__protocols) do
                    protocol:conform_instance(obj)
                end
                return obj
            end
        else
            self:conform_table(tab)
        end
    end

    local _, err = pcall(conform)

    if err then
        -- how to "undo" the conformation?
        for id, protocol in ipairs(tab.__protocols) do
            if protocol == self then
                tab.__protocols[id] = nil
            end
        end
        -- if #self.__protocols == 0 then
        --     self.__protocols = nil
        --     self.__new = self.new
        --     self.__new = nil
        -- end
        error(err)
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
    ClassFieldNotInClassError =
    "Protocol error: cannot assign a protocol with class fields to a table not being a class.\nNote: for a table to be recognized as a class, it must have a constructor method (under a name recognized by this protocol) and tables's __index property equaling itself.\nAccepted constructor method name: ",
    MethodAlreadyImplemented = "Protocol method field error: method has been already implemented by class.",
    MethodNotImplemented = "Protocol method field error: method has not been implemented.",
    WrongMethodType = "Protocol method field error: must be a function or a callable table: "
}

local function CheckFactory(check)
    checks('function')
    local check_class = {
        __type = 'Check',
        __call = check,
    }
    check_class.__index = check_class
    check_class.new = function(value_getter)
        checks('?function|table')
        local self = setmetatable({}, check_class)
        self.value_getter = value_getter
        return self
    end
    return check_class
end

local check_type_field = function(self, obj, field_name, field_value)
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
end

local check_default_field = function(self, obj, field_name, field_value)
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
end

local check_final_field = function(self, obj, field_name, field_value)
    checks('Check', 'table', 'string', '?')
    if field_value ~= nil then
        error(Protocol.errors.FinalFieldReassignedError
            .. _type(obj) .. ' (final field "' .. field_name .. '")'
        )
    else
        return self:value_getter(obj)
    end
end

local check_method_field = function(self, obj, field_name, field_value)
    checks('Check', 'table', 'string', '?')
    local method = self.value_getter -- passing function directly!
    if method and field_value then
        error(Protocol.errors.MethodAlreadyImplemented)
    elseif not method and not field_value then
        error(Protocol.errors.MethodNotImplemented)
    elseif not method and field_value then
        return field_value
    elseif method and not field_value then
        return method
    end
end

local CheckType = CheckFactory(check_type_field)

Protocol.Type = {
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

local CheckDefault = CheckFactory(check_default_field)

Protocol.Default = {
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

local CheckFinal = CheckFactory(check_final_field)

Protocol.Final = {

    -- check = CheckFinal,

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

local MethodCheckFactory = function(...)
    local check_class = CheckFactory(...)
    check_class.method_field = true
    return check_class
end

local CheckMethod = MethodCheckFactory(check_method_field)

Protocol.Method = {

    __call = function(self, final_method)
        checks('table', '?function|table')
        if not (final_method == nil or is_callable(final_method)) then
            error(Protocol.errors.WrongMethodType)
        end
        return CheckMethod.new(final_method)
    end
}
setmetatable(Protocol.Method, Protocol.Method)

local ClassCheckFactory = function(...)
    local check_class = CheckFactory(...)
    check_class.class_field = true
    return check_class
end

local CheckClassType = ClassCheckFactory(check_type_field)

Protocol.ClassType = {
    __call = function(self, expected_type)
        expected_type = self._sanitize(expected_type)
        return CheckClassType.new(function() return expected_type end)
    end,

    _sanitize = function(type_)
        checks('string|table')
        if type(type_) == 'table' then
            return type_.__type or error(Protocol.errors.TypeFormatError)
        end
        return type_
    end,

    number = CheckClassType.new(function() return 'number' end),
    string = CheckClassType.new(function() return 'string' end),
    boolean = CheckClassType.new(function() return 'boolean' end),
    table = CheckClassType.new(function() return 'table' end),
    method = CheckClassType.new(function() return 'function' end) -- exception!
}
setmetatable(Protocol.ClassType, Protocol.ClassType)

local CheckClassDefault = ClassCheckFactory(check_default_field)

Protocol.ClassDefault = {
    __call = function(_, default_value)
        if default_value == nil then error(Protocol.errors.NilDefaultError) end
        return CheckClassDefault.new(function() return default_value end)
    end,

    table = CheckClassDefault.new(function() return {} end),

    instance = function(class, ...)
        checks('table')
        local constructor, args = class[Protocol._default_constructor_name], { ... }
        if not constructor then error(Protocol.errors.CannotInstantiateError) end
        return CheckClassDefault.new(function() return constructor(table.unpack(args)) end)
    end
}
setmetatable(Protocol.ClassDefault, Protocol.ClassDefault)


local CheckClassFinal = ClassCheckFactory(check_final_field)

Protocol.ClassFinal = {
    __call = function(self, final_value)
        if final_value == nil then error(Protocol.errors.NilFinalError) end
        return CheckClassFinal.new(function() return final_value end)
    end,

    table = CheckClassFinal.new(function() return {} end),

    instance = function(class, ...)
        checks('table')
        local constructor, args = class[Protocol._default_constructor_name], { ... }
        if not constructor then error(Protocol.errors.CannotInstantiateError) end
        return CheckClassFinal.new(function() return constructor(table.unpack(args)) end)
    end
}
setmetatable(Protocol.ClassFinal, Protocol.ClassFinal)

local ClassMethodCheckFactory = function(...)
    local check_class = CheckFactory(...)
    check_class.class_field = true
    check_class.method_field = true
    return check_class
end

Protocol.ClassMethod = Protocol.Method

return Protocol
