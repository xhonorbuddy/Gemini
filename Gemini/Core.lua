Gemini = { version = "1.0.0", listeners = {}, logs = {}, elapsed = 0 }
local G = Gemini
local defaults = {
    turnSeconds = 2, arrival = 1.5, cameraPitch = -0.45, cameraFov = 60,
    cameraHeight = 1.6, drawWorld = true, ctrlClick = true, pathFlags = 5,
    refreshSeconds = 1, savedRoutes = {}, meshIndex = "", windowScale = 1,
}
function G.InitializeDB()
    GeminiDB = type(GeminiDB) == "table" and GeminiDB or {}
    for key, value in pairs(defaults) do
        if type(GeminiDB[key]) ~= type(value) then
            GeminiDB[key] = type(value) == "table" and {} or value
        end
    end
    G.DB = GeminiDB
    G.DB.turnSeconds = G.Clamp(G.DB.turnSeconds, 0.5, 10)
    G.DB.arrival = G.Clamp(G.DB.arrival, 0.5, 5)
    G.DB.refreshSeconds = G.Clamp(G.DB.refreshSeconds, 0.5, 10)
    G.DB.cameraPitch = G.Clamp(G.DB.cameraPitch, -1.5, 0.4)
    G.DB.cameraFov = G.Clamp(G.DB.cameraFov, 20, 120)
    G.DB.cameraHeight = G.Clamp(G.DB.cameraHeight, 0, 5)
    G.DB.windowScale = G.Clamp(G.DB.windowScale, 0.5, 1.5)
    if G.DB.pathFlags ~= 5 and G.DB.pathFlags ~= 7 then G.DB.pathFlags = 5 end
end
function G.Finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
function G.Clamp(n, low, high) return math.max(low, math.min(high, n)) end
function G.Point(p)
    return type(p) == "table" and G.Finite(p.x) and G.Finite(p.y) and G.Finite(p.z)
end
function G.CopyPoint(p) return { x = p.x, y = p.y, z = p.z } end
function G.Distance(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function G.On(event, callback)
    G.listeners[event] = G.listeners[event] or {}
    table.insert(G.listeners[event], callback)
end
function G.Emit(event, ...)
    for _, fn in ipairs(G.listeners[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok and event ~= "log" then G.Log("error", event .. ": " .. tostring(err)) end
    end
end
function G.Log(level, message)
    local entry = { time = type(date) == "function" and date("%H:%M:%S") or "--:--", level = level, text = tostring(message) }
    table.insert(G.logs, entry)
    if #G.logs > 80 then table.remove(G.logs, 1) end
    if level == "error" and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffb454Gemini:|r " .. entry.text)
    end
    G.Emit("log", entry)
end
function G.FormatPoint(p)
    if not G.Point(p) then return "Unavailable" end
    return string.format("%.2f, %.2f, %.2f", p.x, p.y, p.z)
end
function G.Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y/x) end
    if x < 0 then return math.atan(y/x) + (y >= 0 and math.pi or -math.pi) end
    if y == 0 then return 0 end
    return y > 0 and math.pi/2 or -math.pi/2
end
