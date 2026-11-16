local G = Gemini
G.Bridge = {}
local B = G.Bridge
function B.Has(name) return type(C) == "table" and type(C[name]) == "function" end
function B.Call(name, ...)
    if not B.Has(name) then return nil, "C." .. name .. " unavailable; load grid.dll" end
    local ok, a, b, c, d, e, f, g, h = pcall(C[name], ...)
    if not ok then return nil, "C." .. name .. ": " .. tostring(a) end
    return a, b, c, d, e, f, g, h
end
function B.Method(object, method, ...)
    local ok, fn = pcall(function() return object[method] end)
    if not ok or type(fn) ~= "function" then return nil, method .. " unavailable" end
    local success, a, b, c = pcall(fn, object, ...)
    if not success then return nil, tostring(a) end
    return a, b, c
end
function B.Status()
    local status, err = B.Call("NavStatus")
    if type(status) ~= "table" then return nil, err or "Invalid navigation status" end
    return status
end
function B.Move(name)
    local fn = _G[name]
    if type(fn) ~= "function" then return false, name .. " unavailable" end
    local stopping = string.sub(name, -4) == "Stop"
    local cleared, clearError = B.Call("ClearTaint")
    -- Stops are still attempted if the bridge disappears while movement is held.
    if cleared ~= true and not stopping then return false, clearError or "C.ClearTaint did not succeed" end
    local ok, err = pcall(fn)
    if not ok then return false, name .. ": " .. tostring(err) end
    return true
end
function B.Facing()
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, yaw = pcall(GetPlayerFacing)
    if ok and G.Finite(yaw) then return yaw end
end
local function validCamera(camera)
    return G.Point(camera) and G.Finite(camera.yaw) and G.Finite(camera.pitch) and
        G.Finite(camera.fov) and camera.fov > 0 and camera.fov < math.pi
end
function B.Camera()
    if type(G.CameraProvider) == "function" then
        local ok, camera = pcall(G.CameraProvider)
        if ok and validCamera(camera) then camera.source = "Camera provider"; return camera end
    end
    if type(C_Commentator) == "table" and type(C_Commentator.GetCamera) == "function" then
        local ok, x, y, z, yaw, pitch, roll, fov = pcall(C_Commentator.GetCamera)
        local camera = { x=x, y=y, z=z, yaw=yaw, pitch=pitch, fov=fov or roll, source="Client camera" }
        if ok then
            if G.Finite(camera.fov) and camera.fov > math.pi then camera.fov = math.rad(camera.fov) end
            if validCamera(camera) then
                camera.yaw=camera.yaw-math.pi/2
                return camera
            end
        end
    end
    local status, err = B.Status()
    local facing = B.Facing()
    local ok, zoom = false, nil
    if type(GetCameraZoom) == "function" then ok, zoom = pcall(GetCameraZoom) end
    if not status or not G.Point(status.position) or not facing or not ok or not G.Finite(zoom) then
        return nil, err or "Player position, facing or camera zoom unavailable"
    end
    local pitch, distance = G.DB.cameraPitch, math.max(0, zoom)
    local horizontal = distance * math.cos(pitch)
    return {
        x=status.position.x - math.cos(facing)*horizontal,
        y=status.position.y - math.sin(facing)*horizontal,
        z=status.position.z + G.DB.cameraHeight - distance*math.sin(pitch),
        -- grid's projection uses (-sin(yaw), cos(yaw)); movement uses
        -- (cos(facing), sin(facing)) in client X/Y coordinates.
        yaw=facing-math.pi/2, pitch=pitch, fov=math.rad(G.DB.cameraFov),
        source="Estimated follow camera", estimated=true,
    }
end
function B.Viewport()
    if not WorldFrame then return nil, "World viewport unavailable" end
    local width, height = WorldFrame:GetWidth(), WorldFrame:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return nil, "Invalid viewport size" end
    return width, height, WorldFrame:GetEffectiveScale(), WorldFrame:GetLeft() or 0, WorldFrame:GetBottom() or 0
end
function B.PickCursor()
    local status, err = B.Status()
    if not status or not status.loaded then return nil, err or (status and status.error) or "Load a mesh first" end
    local camera, reason = B.Camera()
    if not camera then return nil, reason end
    local width, height, scale, left, bottom = B.Viewport()
    if not width then return nil, height end
    local x, y = GetCursorPosition()
    local u, v = (x/scale-left)/width, 1-(y/scale-bottom)/height
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil, "Cursor is outside the world viewport" end
    local wx, wy, wz = B.Call("NavScreenToWorld", u, v, camera.x, camera.y, camera.z,
        camera.yaw, camera.pitch, camera.fov, width/height)
    local point = {x=wx,y=wy,z=wz}
    if not G.Point(point) then return nil, wy or "Ray missed the active walkable mesh" end
    return point, camera.source
end
