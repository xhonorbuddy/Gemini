local G, B = Gemini, Gemini.Bridge
G.Nav = { path={}, queue={}, waypoint=1, message="Choose a destination.", revision=0 }
local N=G.Nav
function N.ClearPath(message)
    N.path, N.waypoint = {}, 1
    N.revision = N.revision + 1
    N.message=message or "Route cleared"
    G.Emit("route")
end
function N.SetDestination(point)
    if not G.Point(point) then return false,"Destination must contain finite X, Y and Z" end
    if G.Steering then G.Steering.Stop("Destination changed") end
    N.destination=G.CopyPoint(point)
    N.ClearPath("Destination ready; find a route.")
    G.Emit("destination",N.destination)
    return true
end
function N.Plan()
    if G.Steering and G.Steering.state == "running" then G.Steering.Stop("Replanning") end
    if not N.destination then return false,"Choose a destination first" end
    local status, err = B.Status()
    if not status or not status.loaded or not status.playerAvailable then
        N.ClearPath(err or (status and status.error ~= "" and status.error) or "Mesh/player is unavailable")
        return false,N.message
    end
    local path, reason=B.Call("NavPath",N.destination.x,N.destination.y,N.destination.z,G.DB.pathFlags)
    if type(path) ~= "table" or #path == 0 then N.ClearPath(reason or "No complete route");return false,N.message end
    for _,point in ipairs(path) do
        if not G.Point(point) then N.ClearPath("Invalid waypoint returned by grid.dll");return false,N.message end
    end
    N.path, N.waypoint, N.map=path,math.min(2,#path),status.map
    N.revision=N.revision+1
    N.message=string.format("Route ready: %d waypoints | %.1f yd",#path,N.Length())
    G.Log("info",N.message)
    G.Emit("route")
    return true
end
function N.Length()
    local distance=0
    for i=2,#N.path do distance=distance+G.Distance(N.path[i-1],N.path[i]) end
    return distance
end
function N.LoadMesh(path)
    path=string.gsub(path or "","^%s*(.-)%s*$","%1")
    if path=="" then local status=B.Status();path=status and status.index or "" end
    if path=="" then return false,"Enter the full path to world.wnavindex" end
    if G.Steering then G.Steering.Stop("Mesh configuration changed") end
    N.ClearPath("Loading mesh index")
    local ok,err=B.Call("NavConfigure",path)
    if not ok then G.Log("error",err or "Mesh configuration failed");return false,err end
    G.DB.meshIndex=path
    G.Log("info","Mesh index configured; grid selects the player's region automatically")
    return true
end
function N.Pick()
    local point,source=B.PickCursor()
    if not point then G.Log("error","Terrain pick: " .. tostring(source));return false,source end
    N.SetDestination(point)
    G.Log("info","Picked " .. G.FormatPoint(point) .. " | " .. tostring(source))
    return N.Plan()
end
function N.QueueDestination()
    if not N.destination then return false,"Choose a destination first" end
    table.insert(N.queue,G.CopyPoint(N.destination));G.Emit("queue");return true
end
function N.Save(name)
    name=string.gsub(name or "","^%s*(.-)%s*$","%1")
    if name=="" or #name>64 then return false,"Use a route name of 1–64 characters" end
    local points={}
    for _,p in ipairs(N.queue) do table.insert(points,G.CopyPoint(p)) end
    if #points==0 and N.destination then points[1]=G.CopyPoint(N.destination) end
    if #points==0 then return false,"No destinations to save" end
    G.DB.savedRoutes[name]={points=points,map=N.map,meshIndex=G.DB.meshIndex}
    G.Log("info","Saved route: " .. name);return true
end
function N.Load(name)
    local route=G.DB.savedRoutes[name]
    if type(route)~="table" or type(route.points)~="table" or #route.points==0 then return false,"Saved route not found" end
    for _,point in ipairs(route.points) do if not G.Point(point) then return false,"Saved route contains an invalid destination" end end
    local status=B.Status()
    if route.map and status and route.map~=status.map then return false,"Saved route belongs to a different map" end
    if G.Steering then G.Steering.Stop("Loading saved route") end
    N.queue={}
    for i=2,#route.points do table.insert(N.queue,G.CopyPoint(route.points[i])) end
    N.SetDestination(route.points[1]);G.Emit("queue")
    return N.Plan()
end
