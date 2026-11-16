local G, B = Gemini, Gemini.Bridge
G.Objects = { rows={}, filter="", kind=nil, page=1, perPage=12, error=nil }
local O = G.Objects
function O.Refresh()
    local objects, err = B.Call("Objects")
    O.rows, O.error = {}, nil
    if type(objects) ~= "table" then O.error = err or "Object query failed"; G.Emit("objects"); return false end
    for _, object in ipairs(objects) do
        local info, reason = B.Method(object, "Info")
        local guid = B.Method(object, "GUID")
        if type(info) == "table" then
            table.insert(O.rows, { object=object, guid=guid or info.guid or "?", info=info,
                name=info.name or "UNKNOWN", kind=info.typeName or tostring(info.type or "?"), type=info.type })
        else
            table.insert(O.rows, { object=object, guid=guid or "?", name="Unavailable", kind="?", info={}, error=reason })
        end
    end
    table.sort(O.rows, function(a,b)
        if a.kind == b.kind then
            if a.name == b.name then return a.guid < b.guid end
            return a.name < b.name
        end
        return a.kind < b.kind
    end)
    if O.selected then
        local selected = O.selected.guid
        O.selected = nil
        for _, row in ipairs(O.rows) do if row.guid == selected then O.selected=row; break end end
    end
    G.Emit("objects")
    return true
end
function O.Filtered()
    local result, filter = {}, string.lower(O.filter)
    for _, row in ipairs(O.rows) do
        local haystack = string.lower(row.name .. " " .. row.guid .. " " .. row.kind)
        if (not O.kind or O.kind == row.type) and (filter == "" or string.find(haystack,filter,1,true)) then
            table.insert(result,row)
        end
    end
    return result
end
function O.Select(row) O.selected=row; G.Emit("selection",row) end
function O.Details(row)
    if not row then return "Select an object to inspect its fields." end
    local fields = {"Name: " .. row.name, "Type: " .. row.kind, "GUID: " .. row.guid}
    local keys = {}
    for key in pairs(row.info) do table.insert(keys,key) end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local value=row.info[key]
        if G.Point(value) then value=G.FormatPoint(value) end
        table.insert(fields, key .. ": " .. tostring(value))
    end
    if row.error then table.insert(fields,"Error: " .. row.error) end
    return table.concat(fields,"\n")
end
