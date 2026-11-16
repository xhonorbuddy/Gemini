local G,B,N=Gemini,Gemini.Bridge,Gemini.Nav
G.Drawing={}
local D=G.Drawing
function D.Line(parent,color,width)
    local texture=parent:CreateTexture(nil,"ARTWORK")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(unpack(color))
    texture:Hide()
    return {texture=texture,width=width or 2}
end
function D.Segment(line,parent,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.5 then line.texture:Hide();return end
    local t=line.texture
    t:ClearAllPoints()
    t:SetPoint("CENTER",parent,"BOTTOMLEFT",(ax+bx)/2,(ay+by)/2)
    t:SetSize(length,line.width)
    if t.SetRotation then t:SetRotation(G.Atan2(dy,dx)) end
    t:Show()
end
function D.Initialize()
    D.world=CreateFrame("Frame",nil,WorldFrame)
    D.world:SetAllPoints(WorldFrame)
    D.world:SetFrameStrata("LOW")
    D.world:EnableMouse(false)
    D.lines={}
    for i=1,96 do D.lines[i]=D.Line(D.world,{0.2,0.95,0.72,0.85},3) end
end
function D.World()
    if not D.lines then return end
    local camera=G.DB.drawWorld and #N.path>1 and B.Has("WorldToScreen") and B.Camera()
    local width,height=B.Viewport()
    local count=0
    if camera and width then
        local stride=math.max(1,math.ceil((#N.path-1)/#D.lines))
        for i=1,#N.path-1,stride do
            count=count+1
            local a,b=N.path[i],N.path[math.min(#N.path,i+stride)]
            local ax,ay,av=B.Call("WorldToScreen",a.x,a.y,a.z+0.15,camera.x,camera.y,camera.z,camera.yaw,camera.pitch,camera.fov,width/height)
            local bx,by,bv=B.Call("WorldToScreen",b.x,b.y,b.z+0.15,camera.x,camera.y,camera.z,camera.yaw,camera.pitch,camera.fov,width/height)
            if G.Finite(ax) and G.Finite(ay) and G.Finite(bx) and G.Finite(by) and av and bv then
                D.Segment(D.lines[count],D.world,ax*width,(1-ay)*height,bx*width,(1-by)*height)
            else D.lines[count].texture:Hide() end
        end
    end
    for i=count+1,#D.lines do D.lines[i].texture:Hide() end
end
function D.Map(frame,width,height)
    if not frame.lines then
        frame.lines={}
        for i=1,96 do frame.lines[i]=D.Line(frame,{0.2,0.95,0.72,1}) end
        frame.player=frame:CreateTexture(nil,"OVERLAY")
        frame.player:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.player:SetVertexColor(1,0.78,0.3,1);frame.player:SetSize(7,7)
    end
    for _,line in ipairs(frame.lines) do line.texture:Hide() end
    frame.player:Hide()
    if #N.path==0 then return end
    local minX,maxX,minY,maxY=N.path[1].x,N.path[1].x,N.path[1].y,N.path[1].y
    local status=B.Status()
    local player=status and status.position
    for _,point in ipairs(N.path) do
        minX,maxX=math.min(minX,point.x),math.max(maxX,point.x)
        minY,maxY=math.min(minY,point.y),math.max(maxY,point.y)
    end
    if G.Point(player) then
        minX,maxX=math.min(minX,player.x),math.max(maxX,player.x)
        minY,maxY=math.min(minY,player.y),math.max(maxY,player.y)
    end
    local scale=math.min((width-32)/math.max(1,maxY-minY),(height-32)/math.max(1,maxX-minX))
    local function project(p)
        -- Client +X is north, +Y is west. Keep north up and west left.
        return width/2-(p.y-(minY+maxY)/2)*scale,height/2+(p.x-(minX+maxX)/2)*scale
    end
    local stride=math.max(1,math.ceil((#N.path-1)/#frame.lines))
    local count=0
    for i=1,#N.path-1,stride do
        count=count+1
        local ax,ay=project(N.path[i]);local bx,by=project(N.path[math.min(#N.path,i+stride)])
        D.Segment(frame.lines[count],frame,ax,ay,bx,by)
    end
    if G.Point(player) then
        local x,y=project(player)
        frame.player:ClearAllPoints();frame.player:SetPoint("CENTER",frame,"BOTTOMLEFT",x,y);frame.player:Show()
    end
end
