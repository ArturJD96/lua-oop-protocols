local checks <const> = require 'checks'
local Protocol = require 'Protocol'

local registrable <const> = Protocol.new(
--[[
        Registrable class stores its each new instance
        in its static "_register"" and assigns it
        a unique ".id" property
        (see "_get_default_id" static method).
    ]]
    {
        -- _singleton = function(class)
        --     checks('table')
        --     return class.singleton
        -- end,

        -- _register = Protocol.table
        _register = Protocol.Final({})

        -- _default_id = Protocol.ClassProperty('__type')
        _default_id = function(class)
            checks('table')
            return class.__type
        end,

        -- id = Protocol.Property('string', function() end)
        id = { 'string', function(class) end },

        new = function(class, constructor)
            checks('table', 'function')
            -- print(class.singleton)
            local _new = function(...)
                local obj <const> = constructor(...)
                if not obj.id then
                    obj.id = class._get_default_id()
                end
                class._register[obj.id] = obj
                return obj
            end
            local get_singleton = function(...)
                -- for _, unique_object in pairs(class._register) do
                --     return unique_object
                -- end
                return _new
            end
            local singleton = get_singleton()
            if class.singleton then
                return singleton
            else
                return _new
            end
        end,

        -- return_register = function(class)
        --     return function()
        --         return class._register
        --     end
        -- end,

        -- delete = Protocol.Method(function(id) end)
        delete = function(class)
            return function(id)
                checks('string')
                assert(class._register[id], 'Cannot delete ' .. id .. '. Object not present in register.')
                class._register[id] = nil
            end
        end,

        -- reset_count = Protocol.Method(function() end)
        register_count = function(class)
            return function()
                local c = 0
                for id, _ in pairs(class._register) do c = c + 1 end
                return c
            end
        end,

        -- reset_register = Protocol.Method(function() end)
        reset_register = function(class)
            return function()
                class._register = {}
                collectgarbage()
            end
        end,

        -- delete = Protocol.Method(function() end)
        _get_default_id = function(class)
            return function()
                checks()
                --[[
                    Get the next default name for a new registrable object
                    (if it's id is not provided).

                    When creating a new registrable object without giving it
                    an explicit id, a default ID is assigned.

                    This default ID consists of registrable object class name
                    (in ._default_id property) and an index number.

                    Continuity of numbers is strived to be preserved.
                    Thus, next id will end with the highest number
                    UNLESS there is a gap between numbers – then,
                    the missing id will be chosen.

                    Examples:
                    1) Sequence_1, Sequence_2, Sequence_3 -> Sequence_4
                    2) Sequence_1, Sequence_3, Sequence_5 -> Sequence_2 (between 1 and 3)
                ]]
                local ids <const>, id_num = {}, nil
                local separator <const> = '_'
                local _join <const> = function(id, sep, num)
                    checks('string', 'string', 'string')
                    return id .. sep .. num
                end
                for id, _ in pairs(class._register) do
                    id_num = id:match('^' .. _join(class._default_id, separator, '(%d+)$'))
                    if id_num and (id_num:sub(0, 1) ~= 0) then
                        table.insert(ids, tonumber(id_num))
                    end
                end
                if #ids == 0 then return _join(class._default_id, separator, '1') end
                table.sort(ids)
                local id = 0
                for _, n in ipairs(ids) do
                    if n - id == 1 then id = n else break end
                end
                local default_id <const> = _join(class._default_id, separator, tostring(id + 1))
                return default_id
            end
        end

    })

--[[
    Make Protocol class registrable.
    (Manually, because Protocol.register
    is not present yet due to lack of, well,
    conforming to registrable protocol).
]]
-- registrable:conform(Protocol)
-- Protocol._register[registrable.id] = registrable

return registrable
