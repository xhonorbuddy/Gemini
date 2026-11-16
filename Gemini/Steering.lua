local G,B,N=Gemini,Gemini.Bridge,Gemini.Nav
G.Steering={state="idle",message="Ready",forward=false,turn=nil,remaining=0,elapsed=0}
local S=G.Steering
local function forward(wanted)
    if S.forward==wanted then return true end
    local ok,err=B.Move(wanted and "MoveForwardStart" or "MoveForwardStop")
    if ok then S.forward=wanted end
    return ok,err
end
local function turn(wanted)
    if S.turn==wanted then return true end
    if S.turn then
        local ok,err=B.Move(S.turn=="left" and "TurnLeftStop" or "TurnRightStop")
        if not ok then return false,err end
        S.turn=nil
    end
    if wanted then
        local ok,err=B.Move(wanted=="left" and "TurnLeftStart" or "TurnRightStart")
        if not ok then return false,err end
        S.turn=wanted
    end
    return true
end
function S.Stop(reason, state)
    local wasActive=S.state=="running" or S.forward or S.turn
    local a,errA=forward(false)
    local b,errB=turn(nil)
    S.remaining,S.elapsed=0,0
    S.state=(a and b) and (state or "idle") or "stopping"
    S.message=(a and b) and (reason or "Stopped") or (errA or errB or "Retrying movement stop")
    if wasActive then G.Log((a and b) and "info" or "error",S.message) end
    G.Emit("steering")
    return a and b
end
function S.Start()
    if S.state=="running" then return true end
    if S.state=="stopping" then return false,"Movement stop is still pending" end
    if #N.path==0 or not N.destination then return false,"Find a route first" end
    for _,name in ipairs({"MoveForwardStart","MoveForwardStop","TurnLeftStart","TurnLeftStop","TurnRightStart","TurnRightStop"}) do
        if type(_G[name])~="function" then return false,name .. " unavailable" end
    end
    if not B.Has("ClearTaint") then return false,"C.ClearTaint unavailable" end
    local status,err=B.Status()
    if not status or not status.loaded or not status.playerAvailable or not G.Point(status.position) then
        return false,err or "Mesh/player unavailable"
    end
    if status.map~=N.map then return false,"Map changed; find a new route" end
    S.state,S.message,S.elapsed="running","Following route",0
    S.bestDistance,S.progressAt,S.waypointAt=math.huge,GetTime(),GetTime()
    G.Log("info","Steering started | Ctrl+Alt stops")
    G.Emit("steering")
    return true
end
function S.Pause() return S.Stop("Paused; Steer resumes this route","paused") end
local function arrive()
    S.Stop("Destination reached","complete")
    if S.state=="stopping" then return end
    if #N.queue>0 then
        local point=table.remove(N.queue,1)
        N.SetDestination(point);G.Emit("queue")
        local ok,err=N.Plan()
        if ok then ok,err=S.Start() end
        if not ok then S.Stop(err or "Queued route failed","blocked");G.Log("error",S.message) end
    end
end
function S.Tick(elapsed)
    if S.state=="stopping" then
        S.elapsed=S.elapsed+elapsed
        if S.elapsed>=0.2 then S.Stop("Movement stopped") end
        return
    end
    if S.state~="running" then return end
    if IsControlKeyDown() and IsAltKeyDown() then S.Stop("Emergency stop: Ctrl+Alt");return end
    if elapsed>1 then S.Stop("Paused after a long frame stall","paused");return end
    local status,err=B.Status()
    if not status or not status.loaded or not status.playerAvailable or not G.Point(status.position) or status.map~=N.map then
        S.Stop(err or "Mesh, player or map changed","blocked");return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then S.Stop("Player is dead","blocked");return end
    if S.turn then
        S.remaining=S.remaining-elapsed
        if S.remaining>0 then return end
        local ok,reason=turn(nil)
        if not ok then S.Stop(reason,"blocked") end
        S.elapsed=-0.1 -- Let facing settle after releasing the turn.
        return
    end
    S.elapsed=S.elapsed+elapsed
    if S.elapsed<0.1 then return end
    S.elapsed=0
    local position=status.position
    local waypoint=N.path[N.waypoint]
    while waypoint and G.Distance(position,waypoint)<=G.DB.arrival do
        N.waypoint=N.waypoint+1
        S.bestDistance,S.progressAt,S.waypointAt=math.huge,GetTime(),GetTime()
        waypoint=N.path[N.waypoint]
        G.Emit("waypoint")
    end
    if not waypoint then arrive();return end
    local distance=G.Distance(position,waypoint)
    if distance<S.bestDistance-0.25 then S.bestDistance,S.progressAt=distance,GetTime() end
    if (S.forward and GetTime()-S.progressAt>5) or GetTime()-S.waypointAt>30 then
        S.Stop("No progress; inspect the route, door or obstacle","blocked");return
    end
    local facing=B.Facing()
    if not facing then S.Stop("Player facing unavailable","blocked");return end
    local dx,dy=waypoint.x-position.x,waypoint.y-position.y
    local desired=G.Atan2(dy,dx)
    local difference=(desired-facing+math.pi)%(2*math.pi)-math.pi
    local ok,reason
    if math.abs(difference)>0.16 then
        ok,reason=forward(false)
        if ok then ok,reason=turn(difference>0 and "left" or "right") end
        if ok then
            S.remaining=math.min(0.5,math.abs(difference)*G.DB.turnSeconds/(2*math.pi))
            S.message=string.format("Turning %s | %.0f degrees",S.turn,math.deg(math.abs(difference)))
        end
    else
        ok,reason=forward(true)
        if ok then S.message=string.format("Waypoint %d/%d | %.1f yd",N.waypoint,#N.path,distance) end
    end
    if not ok then S.Stop(reason or "Movement failed","blocked");G.Log("error",S.message) end
    G.Emit("steering")
end
