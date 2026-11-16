dofile("tests/mock_wow.lua")
local files={}
for line in io.lines("Gemini/Gemini.toc") do
    if string.match(line,"%.lua$") then table.insert(files,line);assert(loadfile("Gemini/" .. line))() end
end
assert(#files==8)
Gemini.driver:Fire("OnEvent","ADDON_LOADED","Unrelated")
assert(not Gemini.ready)
Gemini.driver:Fire("OnEvent","ADDON_LOADED","Gemini")
local G,N,S,U,M=Gemini,Gemini.Nav,Gemini.Steering,Gemini.UI,Mock
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name .. ": " .. tostring(err)) end
    passed=passed+1;print("PASS " .. name)
end
local function reset()
    S.Stop("test reset");N.queue={};N.ClearPath();M.status.loaded=true;M.status.playerAvailable=true
    M.status.map=1;M.status.position={x=0,y=0,z=0};M.facing=0;M.ctrl=false;M.alt=false
    M.path={{x=0,y=0,z=0},{x=20,y=0,z=0}};M.pathError=nil;M.pickError=nil;M.clearSuccess=true
    M.moves={};M.clearCount=0;M.failMove=nil;G.pickDeadline=nil
end
test("addon bootstrap and every tab",function()
    assert(G.ready and not U.window:IsShown());assert(SlashCmdList.GEMINI)
    SlashCmdList.GEMINI("");assert(U.window:IsShown())
    for _,name in ipairs({"Overview","Objects","Navigation","Settings","Activity"}) do U.ShowTab(name);assert(U.panels[name]:IsShown()) end
    U.ShowTab("Navigation");assert(M.Button("Pick terrain (3s)"):IsShown())
end)
test("late DLL availability and nil/error preservation",function()
    local saved=C;C=nil;local value,err=G.Bridge.Call("NavPath",1,2,3);assert(value==nil and err)
    U.Update();C=saved
    M.pathError="no complete route";local path,reason=G.Bridge.Call("NavPath",1,2,3)
    assert(path==nil and reason=="no complete route");M.pathError=nil
end)
test("mesh configure and actual percentage",function()
    assert(N.LoadMesh("C:/meshes/world.wnavindex"));assert(M.configured==G.DB.meshIndex)
    M.status.loaded=false;M.status.loadingPercent=37;U.Update();assert(U.meshBar.value==37)
    M.status.loaded=true;U.Update();assert(U.meshBar.value==100)
end)
test("route validation and failure clears drawings",function()
    reset();assert(N.SetDestination({x=20,y=0,z=0}));assert(N.Plan());assert(#N.path==2)
    assert(M.calls.path[4]==5)
    assert(not N.SetDestination({x=0/0,y=0,z=0}))
    M.pathError="unreachable";assert(not N.Plan());assert(#N.path==0)
    G.Drawing.World();for _,line in ipairs(G.Drawing.lines) do assert(not line.texture.shown) end
end)
test("3 second terrain picker samples before reopening",function()
    reset();U.Show();assert(G.BeginPick());assert(not U.window:IsShown())
    M.Advance(1);M.Advance(1);assert(G.pickDeadline)
    M.cursor={960,540};M.Advance(1.01)
    assert(not G.pickDeadline and U.window:IsShown());assert(N.destination.x==20 and #N.path==2)
    assert(math.abs(M.calls.pick[1]-0.5)<0.001 and math.abs(M.calls.pick[2]-0.5)<0.001)
end)
test("scaled viewport and follow-camera axis conversion",function()
    WorldFrame.scale=0.5;WorldFrame.left=10;WorldFrame.bottom=20;WorldFrame:SetSize(1000,600)
    M.cursor={255,160};assert(G.Bridge.PickCursor())
    assert(math.abs(M.calls.pick[1]-0.5)<0.001 and math.abs(M.calls.pick[2]-0.5)<0.001)
    local camera=G.Bridge.Camera();assert(camera.estimated and camera.x<0 and math.abs(camera.y)<0.001)
    assert(math.abs(camera.yaw+math.pi/2)<0.001)
    WorldFrame.scale=1;WorldFrame.left=0;WorldFrame.bottom=0;WorldFrame:SetSize(1920,1080)
end)
test("Ctrl-click destination and Ctrl+Alt cancellation",function()
    reset();M.ctrl=true;WorldFrame:Fire("OnMouseDown","LeftButton");assert(N.destination and #N.path==2)
    M.ctrl=false;assert(G.BeginPick());M.ctrl=true;M.alt=true;M.Advance(0.1);assert(not G.pickDeadline)
    M.ctrl=false;M.alt=false
end)
test("explicit camera providers and commentator radians",function()
    G.CameraProvider=function()return {x=1,y=2,z=3,yaw=0,pitch=-0.4,fov=1}end
    assert(G.Bridge.Camera().source=="Camera provider");G.CameraProvider=nil
    C_Commentator={GetCamera=function()return 1,2,3,0,-0.4,0,60 end}
    local camera=G.Bridge.Camera()
    assert(camera.source=="Client camera" and math.abs(camera.fov-math.pi/3)<0.001)
    assert(math.abs(camera.yaw+math.pi/2)<0.001);C_Commentator=nil
end)
test("steering aligns north then releases on emergency stop",function()
    reset();assert(N.SetDestination({x=20,y=0,z=0}));assert(N.Plan());assert(S.Start())
    M.Advance(0.11);assert(S.forward and M.moves[1]=="MoveForwardStart")
    M.ctrl=true;M.alt=true;M.Advance(0.02)
    assert(not S.forward and not S.turn and S.state=="idle");assert(M.moves[2]=="MoveForwardStop")
    assert(M.clearCount==#M.moves)
end)
test("two second full turn calibration",function()
    reset();M.path={{x=0,y=0,z=0},{x=0,y=20,z=0}}
    N.SetDestination({x=0,y=20,z=0});assert(N.Plan());assert(S.Start());M.Advance(0.11)
    assert(S.turn=="left" and not S.forward and math.abs(S.remaining-0.5)<0.001)
    M.Advance(0.49);assert(S.turn=="left")
    M.facing=math.pi/2;M.Advance(0.02);assert(not S.turn)
    M.Advance(0.21);assert(S.forward)
end)
test("movement failure, map changes and long stalls release input",function()
    reset();N.SetDestination({x=20,y=0,z=0});assert(N.Plan());assert(S.Start())
    M.clearSuccess=false;M.Advance(0.11);assert(S.state=="blocked" and #M.moves==0)
    M.clearSuccess=true;assert(S.Start());M.Advance(0.11);assert(S.forward)
    M.status.map=2;M.Advance(0.02);assert(not S.forward and S.state=="blocked")
    M.status.map=1;assert(S.Start());M.Advance(0.11);assert(S.forward)
    M.Advance(1.1);assert(S.state=="paused" and not S.forward)
end)
test("stuck detection and waypoint completion",function()
    reset();N.SetDestination({x=20,y=0,z=0});assert(N.Plan());assert(S.Start())
    for _=1,55 do M.Advance(0.1) end
    assert(S.state=="blocked" and not S.forward)
    assert(S.Start());M.status.position={x=20,y=0,z=0};M.Advance(0.11)
    assert(S.state=="complete" and not S.forward)
end)
test("failed stop is retained and retried",function()
    reset();N.SetDestination({x=20,y=0,z=0});assert(N.Plan());assert(S.Start());M.Advance(0.11)
    M.failMove="MoveForwardStop";S.Stop("test stop");assert(S.state=="stopping" and S.forward)
    M.failMove=nil;M.Advance(0.21);assert(S.state=="idle" and not S.forward)
end)
test("saved routes, map guard and queue transition",function()
    reset();N.SetDestination({x=20,y=0,z=0});assert(N.Plan());assert(N.QueueDestination())
    N.SetDestination({x=40,y=0,z=0});N.QueueDestination();assert(N.Save("patrol"))
    assert(N.Load("patrol"));assert(N.destination.x==20 and #N.queue==1 and N.queue[1].x==40)
    M.status.map=2;assert(not N.Load("patrol"));M.status.map=1
    assert(S.Start());M.status.position={x=20,y=0,z=0}
    M.path={{x=20,y=0,z=0},{x=40,y=0,z=0}};M.Advance(0.11)
    assert(N.destination.x==40 and #N.queue==0 and S.state=="running")
end)
test("object pagination, filtering and selected field details",function()
    reset();M.objects={}
    for i=1,85 do
        local index=i
        M.objects[i]={Info=function()return {name="Unit " .. index,type=6,typeName="Unit",health=100,position={x=index,y=0,z=0}}end,GUID=function()return string.format("GUID%04d",index)end}
    end
    assert(G.Objects.Refresh());assert(#G.Objects.rows==85)
    G.Objects.page=8;U.Objects();assert(G.Objects.page==8 and U.objectRows[1].data)
    G.Objects.filter="Unit 85";U.Objects();assert(G.Objects.page==1 and U.objectRows[1].data.name=="Unit 85")
    G.Objects.Select(U.objectRows[1].data);assert(string.find(U.details:GetText(),"health: 100",1,true))
    G.Objects.filter="";G.Objects.kind=5;assert(#G.Objects.Filtered()==0);G.Objects.kind=nil
end)
test("missing/stale objects and world exit",function()
    M.objects={{Info=function()error("stale handle")end,GUID=function()return "stale"end}}
    assert(G.Objects.Refresh());assert(G.Objects.rows[1].error)
    reset();N.SetDestination({x=20,y=0,z=0});assert(N.Plan());assert(S.Start());M.Advance(0.11)
    G.driver:Fire("OnEvent","PLAYER_LEAVING_WORLD");assert(not S.forward and #N.path==0)
end)
test("all action buttons and settings remain callable",function()
    U.Show();U.ShowTab("Settings")
    M.Button("Apply settings"):Fire("OnClick");assert(G.DB.turnSeconds==2)
    U.ShowTab("Navigation");U.Update();G.Drawing.World()
    assert(U.pickButton:IsShown());assert(#G.logs<=80)
end)
print(string.format("Gemini: %d integration tests passed; %d Lua modules loaded",passed,#files))
