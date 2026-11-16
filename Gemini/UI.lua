local G,B,N,S=Gemini,Gemini.Bridge,Gemini.Nav,Gemini.Steering
G.UI={panels={},buttons={},tab="Overview"}
local U=G.UI
local colors={text={0.87,0.91,0.96},muted={0.55,0.64,0.73},accent={0.22,0.91,0.73},gold={1,0.76,0.35}}
local function fill(parent,color,layer)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND")
    t:SetAllPoints(parent);t:SetTexture("Interface\\Buttons\\WHITE8X8");t:SetVertexColor(unpack(color));return t
end
local function text(parent,value,x,y,width,font,color)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,y);f:SetWidth(width or 500);f:SetJustifyH("LEFT")
    f:SetText(value);f:SetTextColor(unpack(color or colors.text));return f
end
local function box(parent,x,y,width,height,color)
    local f=CreateFrame("Frame",nil,parent);f:SetSize(width,height);f:SetPoint("TOPLEFT",x,y)
    fill(f,color or {0.045,0.065,0.09,1});return f
end
local function button(parent,value,x,y,width,fn,danger)
    local b=CreateFrame("Button",nil,parent);b:SetSize(width or 120,30);b:SetPoint("TOPLEFT",x,y)
    local normal=fill(b,danger and {0.35,0.10,0.13,1} or {0.09,0.20,0.22,1})
    b.caption=text(b,value,8,-8,(width or 120)-16,"GameFontHighlightSmall",danger and {1,0.68,0.67} or colors.accent)
    b.caption:SetJustifyH("CENTER")
    b:SetScript("OnEnter",function() normal:SetVertexColor(0.16,0.30,0.32,1) end)
    b:SetScript("OnLeave",function() normal:SetVertexColor(unpack(danger and {0.35,0.10,0.13,1} or {0.09,0.20,0.22,1})) end)
    b:SetScript("OnClick",function()
        local ok,a,err=pcall(fn)
        if not ok then G.Log("error",a) elseif a==false then G.Log("error",err or "Action failed") end
        U.Update()
    end)
    return b
end
local function edit(parent,x,y,width,value)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");e:SetSize(width,26);e:SetPoint("TOPLEFT",x,y)
    e:SetAutoFocus(false);e:SetMaxLetters(2048);e:SetText(value or "")
    e:SetScript("OnEscapePressed",e.ClearFocus);e:SetScript("OnEnterPressed",e.ClearFocus)
    return e
end
local function result(ok,err) if not ok then return false,err end;return true end
function U.ShowTab(tab)
    U.tab=tab
    for name,panel in pairs(U.panels) do if name==tab then panel:Show() else panel:Hide() end end
    for name,b in pairs(U.buttons) do b.caption:SetTextColor(unpack(name==tab and colors.accent or colors.muted)) end
    if tab=="Objects" then G.Objects.Refresh() end
    U.Update()
end
function U.Show() U.window:Show();U.Update() end
function U.Toggle() if U.window:IsShown() then U.window:Hide() else U.Show() end end
function U.Initialize()
    local window=CreateFrame("Frame","GeminiWindow",UIParent)
    U.window=window;window:SetSize(1040,720);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG")
    window:SetMovable(true);window:SetClampedToScreen(true);window:EnableMouse(true)
    local scale=math.min(G.DB.windowScale,(UIParent:GetWidth()-32)/1040,(UIParent:GetHeight()-32)/720)
    window:SetScale(math.max(0.4,scale))
    fill(window,{0.02,0.032,0.05,0.98})
    local header=box(window,0,0,1040,70,{0.035,0.057,0.078,1})
    header:EnableMouse(true);header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() window:StartMoving() end)
    header:SetScript("OnDragStop",function() window:StopMovingOrSizing() end)
    text(header,"GEMINI",22,-17,180,"GameFontNormalLarge",colors.accent)
    text(header,"BOT MANAGER   /   " .. G.version,23,-43,350,nil,colors.muted)
    U.headerState=text(header,"IDLE",700,-24,220,"GameFontNormal",colors.gold)
    button(header,"X",992,-18,30,function() window:Hide() end,true)
    box(window,0,-70,144,650,{0.028,0.044,0.064,1})
    for i,name in ipairs({"Overview","Objects","Navigation","Settings","Activity"}) do
        local tab=name
        U.buttons[tab]=button(window,tab,12,-94-(i-1)*43,120,function() U.ShowTab(tab) end)
        local panel=CreateFrame("Frame",nil,window);panel:SetSize(856,594);panel:SetPoint("TOPLEFT",164,-90)
        U.panels[tab]=panel;panel:Hide()
    end
    button(window,"STOP ALL",12,-616,120,function() G.CancelPick();S.Stop("Stopped by user") end,true)
    text(window,"CTRL + ALT\nEmergency stop",18,-661,116,nil,colors.muted)
    U.footer=text(window,"Waiting for grid.dll",164,-695,850,nil,colors.muted)
    local p=U.panels.Overview
    text(p,"SESSION CONTROL",0,0,500,"GameFontNormalLarge")
    U.summary=text(p,"",0,-36,820,"GameFontHighlight")
    local mesh=box(p,0,-96,836,148)
    text(mesh,"ACTIVE NAVIGATION MESH",16,-14,800,nil,colors.accent)
    U.meshName=text(mesh,"Waiting for mesh",16,-40,800)
    U.meshBar=CreateFrame("StatusBar",nil,mesh);U.meshBar:SetPoint("TOPLEFT",16,-70);U.meshBar:SetSize(804,20)
    fill(U.meshBar,{0.015,0.025,0.035,1})
    U.meshBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");U.meshBar:SetStatusBarColor(0.18,0.72,0.6)
    U.meshBar:SetMinMaxValues(0,100);U.meshBar:SetValue(0)
    U.meshPercent=text(mesh,"0%",18,-100,790)
    U.capabilities=text(p,"",0,-264,830,"GameFontHighlight")
    button(p,"Open route planner",0,-375,180,function() U.ShowTab("Navigation") end)
    button(p,"Inspect objects",192,-375,150,function() U.ShowTab("Objects") end)
    button(p,"Steer route",354,-375,130,function() return result(S.Start()) end)
    button(p,"Pause",496,-375,100,function() S.Pause() end)
    text(p,"WORKFLOW",0,-444,800,"GameFontNormal",colors.accent)
    text(p,"1  Load a mesh index in Navigation. The active region follows your player.\n\n2  Pick terrain, enter XYZ, or choose an object's position. Find a complete route.\n\n3  Steer to follow waypoints. Ctrl+Alt releases movement immediately.\n\n4  Save destinations as named routes. Queue several stops for a session.",0,-475,820)
    p=U.panels.Objects
    text(p,"OBJECT MANAGER",0,0,600,"GameFontNormalLarge")
    U.objectCount=text(p,"",400,-5,425,nil,colors.muted)
    U.search=edit(p,8,-39,310,"")
    U.search:SetScript("OnTextChanged",function(self) G.Objects.filter=self:GetText();G.Objects.page=1;U.Objects() end)
    U.typeButton=button(p,"All types",338,-37,150,function()
        local kind=G.Objects.kind
        G.Objects.kind=kind==nil and 0 or (kind<14 and kind+1 or nil)
        G.Objects.page=1;U.Objects()
    end)
    button(p,"Refresh",500,-37,110,function() G.Objects.Refresh() end)
    button(p,"Route to selected",622,-37,214,function()
        local selected=G.Objects.selected
        if not selected or not G.Point(selected.info.position) then return false,"Select an object with a position" end
        N.SetDestination(selected.info.position);U.ShowTab("Navigation");return result(N.Plan())
    end)
    local headings={{"TYPE",8,108},{"NAME",124,170},{"HEALTH",302,76},{"POSITION",386,170},{"DIST.",564,64},{"GUID",636,192}}
    local h=box(p,0,-82,836,27,{0.09,0.14,0.19,1})
    for _,col in ipairs(headings) do text(h,col[1],col[2],-7,col[3],nil,colors.muted) end
    U.objectRows={}
    for i=1,G.Objects.perPage do
        local row=CreateFrame("Button",nil,p);row:SetPoint("TOPLEFT",0,-110-(i-1)*25);row:SetSize(836,25)
        row.stripe=fill(row,i%2==0 and {0.055,0.078,0.105,1} or {0.035,0.053,0.075,1})
        row.cells={}
        for c,col in ipairs(headings) do row.cells[c]=text(row,"",col[2],-6,col[3]);row.cells[c]:SetWordWrap(false) end
        row:SetScript("OnClick",function(self) if self.data then G.Objects.Select(self.data) end end)
        U.objectRows[i]=row
    end
    button(p,"Previous",0,-421,105,function() G.Objects.page=math.max(1,G.Objects.page-1);U.Objects() end)
    U.pageLabel=text(p,"",120,-430,480,nil,colors.muted)
    button(p,"Next",731,-421,105,function() G.Objects.page=G.Objects.page+1;U.Objects() end)
    local details=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate")
    details:SetPoint("TOPLEFT",0,-467);details:SetSize(812,115)
    local body=box(details,0,0,804,115);details:SetScrollChild(body)
    U.detailBody=body;U.details=text(body,"Select an object to inspect all fields.",12,-8,780)
    p=U.panels.Navigation
    text(p,"MESH INDEX",0,0,700,"GameFontNormal",colors.accent)
    U.meshInput=edit(p,8,-26,666,G.DB.meshIndex)
    button(p,"Load index",694,-24,142,function() return result(N.LoadMesh(U.meshInput:GetText())) end)
    text(p,"DESTINATION   /   CLIENT X, Y, Z",0,-79,470,"GameFontNormal",colors.accent)
    U.coordinates={}
    for i,name in ipairs({"X","Y","Z"}) do
        text(p,name,(i-1)*148,-108,20,nil,colors.muted)
        U.coordinates[i]=edit(p,22+(i-1)*148,-104,112,"0")
    end
    button(p,"Find route",0,-148,133,function()
        local point={x=tonumber(U.coordinates[1]:GetText()),y=tonumber(U.coordinates[2]:GetText()),z=tonumber(U.coordinates[3]:GetText())}
        local ok,err=N.SetDestination(point);if not ok then return false,err end
        return result(N.Plan())
    end)
    U.pickButton=button(p,"Pick terrain (3s)",145,-148,160,function() return G.BeginPick() end)
    button(p,"Player position",317,-148,127,function()
        local status=B.Status();return N.SetDestination(status and status.position)
    end)
    button(p,"Steer",0,-191,133,function() return result(S.Start()) end)
    button(p,"Pause",145,-191,94,function() S.Pause() end)
    button(p,"Stop",251,-191,94,function() S.Stop("Stopped by user") end,true)
    button(p,"Queue stop",357,-191,87,function() return result(N.QueueDestination()) end)
    U.routeMessage=text(p,"",0,-241,448)
    U.routeProgress=text(p,"",0,-274,448,nil,colors.gold)
    U.routeMap=box(p,470,-79,366,222,{0.018,0.032,0.05,1})
    text(U.routeMap,"N  /  ROUTE PREVIEW",12,-10,340,nil,colors.muted)
    U.mapCanvas=box(U.routeMap,6,-30,354,184,{0.025,0.044,0.062,1})
    U.cameraHint=text(p,"",470,-315,366,nil,colors.muted)
    text(p,"UPCOMING WAYPOINTS",0,-350,446,"GameFontNormal",colors.accent)
    U.waypoints=text(p,"",0,-378,446)
    text(p,"DESTINATION QUEUE",470,-365,366,"GameFontNormal",colors.accent)
    U.queueText=text(p,"No queued stops",470,-392,366)
    button(p,"Clear queue",700,-480,136,function() N.queue={};G.Emit("queue") end)
    text(p,"SAVED ROUTES",0,-492,450,"GameFontNormal",colors.accent)
    U.routeName=edit(p,8,-521,290,"")
    button(p,"Save",316,-519,90,function() return result(N.Save(U.routeName:GetText())) end)
    button(p,"Load",418,-519,90,function() return result(N.Load(U.routeName:GetText())) end)
    button(p,"Next name",520,-519,120,function()
        local names={};for name in pairs(G.DB.savedRoutes) do table.insert(names,name) end;table.sort(names)
        if #names==0 then return false,"No saved routes" end
        local current=U.routeName:GetText();local index=0
        for i,name in ipairs(names) do if name==current then index=i end end
        U.routeName:SetText(names[index%#names+1])
    end)
    button(p,"Delete",652,-519,90,function() G.DB.savedRoutes[U.routeName:GetText()]=nil end,true)
    text(p,"Ctrl+left-click world terrain picks immediately. Button samples the cursor after 3 seconds.",0,-568,836,nil,colors.muted)
    p=U.panels.Settings
    text(p,"MOVEMENT & DISPLAY",0,0,800,"GameFontNormalLarge")
    U.settings={}
    local specs={
        {"turnSeconds","Full 360 turn (seconds)","2 seconds is your measured default.",0.5,10},
        {"arrival","Waypoint arrival radius (yards)","Stops near the final destination.",0.5,5},
        {"refreshSeconds","Object refresh (seconds)","Refreshes only while the object manager is visible.",0.5,10},
        {"cameraPitch","Follow-camera pitch (radians)","Fallback estimate; negative looks downward.",-1.5,0.4},
        {"cameraFov","Vertical field of view (degrees)","Used only by the estimated camera.",20,120},
        {"cameraHeight","Camera target height (yards)","Height above the player's position.",0,5},
    }
    for i,spec in ipairs(specs) do
        local y=-44-(i-1)*62
        text(p,spec[2],0,y,340,"GameFontHighlight")
        text(p,spec[3],0,y-23,620,nil,colors.muted)
        local e=edit(p,650,y+2,150,tostring(G.DB[spec[1]]))
        U.settings[spec[1]]={edit=e,min=spec[4],max=spec[5]}
    end
    button(p,"Apply settings",650,-435,150,function()
        for key,spec in pairs(U.settings) do
            local value=tonumber(spec.edit:GetText())
            if not G.Finite(value) or value<spec.min or value>spec.max then return false,key .. " is outside the allowed range" end
        end
        for key,spec in pairs(U.settings) do G.DB[key]=tonumber(spec.edit:GetText()) end
        G.Log("info","Settings saved")
    end)
    U.drawButton=button(p,"",0,-435,200,function() G.DB.drawWorld=not G.DB.drawWorld end)
    U.ctrlButton=button(p,"",212,-435,200,function() G.DB.ctrlClick=not G.DB.ctrlClick end)
    U.swimButton=button(p,"",424,-435,210,function()
        G.DB.pathFlags=G.DB.pathFlags==5 and 7 or 5;S.Stop("Traversal flags changed");N.ClearPath("Find a route with the new traversal flags")
    end)
    text(p,"Camera accuracy",0,-500,800,"GameFontNormal",colors.accent)
    text(p,"Terrain picks and world drawings use a client camera when available. Otherwise they use a clearly marked follow-camera estimate. Re-center the camera behind your player before picking; independent camera orbit changes the result. Top-down route coordinates remain exact.",0,-529,820)
    p=U.panels.Activity
    text(p,"SESSION ACTIVITY",0,0,700,"GameFontNormalLarge")
    button(p,"Clear",726,5,110,function() G.logs={};U.Logs() end)
    U.logText=text(p,"",0,-46,836)
    -- Hide during countdown; closing the manager also releases movement.
    window:SetScript("OnHide",function() S.Stop("Manager hidden") end)
    table.insert(UISpecialFrames,"GeminiWindow")
    U.picker=CreateFrame("Frame",nil,UIParent);U.picker:SetSize(470,64);U.picker:SetPoint("TOP",0,-90)
    U.picker:SetFrameStrata("TOOLTIP");fill(U.picker,{0.025,0.07,0.09,0.98})
    U.pickText=text(U.picker,"",16,-13,345,"GameFontHighlight")
    button(U.picker,"Cancel",365,-16,90,function() G.CancelPick() end,true)
    U.picker:Hide()
    U.ShowTab("Overview");window:Hide()
end
function U.Objects()
    if not U.objectRows then return end
    local O=G.Objects
    local filtered=O.Filtered();local pages=math.max(1,math.ceil(#filtered/O.perPage))
    O.page=G.Clamp(O.page,1,pages)
    U.objectCount:SetText(O.error or string.format("%d visible  /  %d matched",#O.rows,#filtered))
    U.typeButton.caption:SetText(O.kind and ("Type " .. O.kind) or "All types")
    U.pageLabel:SetText(string.format("Page %d of %d  |  %d objects",O.page,pages,#filtered))
    local status=B.Status();local player=status and status.position
    for i,row in ipairs(U.objectRows) do
        local data=filtered[(O.page-1)*O.perPage+i];row.data=data
        if data then
            local info=data.info
            local distance=G.Point(info.position) and G.Point(player) and G.Distance(info.position,player)
            local values={data.kind,data.name,tostring(info.healthExact or info.health or "--"),G.FormatPoint(info.position),distance and string.format("%.1f",distance) or "--",data.guid}
            for j,value in ipairs(values) do row.cells[j]:SetText(value) end
            row:Show()
        else row:Hide() end
    end
    U.details:SetText(O.Details(O.selected))
    U.detailBody:SetHeight(math.max(115,U.details:GetStringHeight()+24))
end
function U.Logs()
    if not U.logText then return end
    local lines={}
    for i=math.max(1,#G.logs-22),#G.logs do
        local e=G.logs[i]
        table.insert(lines,"|cff8296aa" .. e.time .. "|r  " .. (e.level=="error" and "|cffff927f" or "|cffb8d7cc") .. string.sub(e.text,1,126) .. "|r")
    end
    U.logText:SetText(table.concat(lines,"\n\n"))
end
function U.Update()
    if not U.window then return end
    local status,err=B.Status()
    U.headerState:SetText(string.upper(S.state) .. "  /  " .. (#N.path>0 and (#N.path .. " POINTS") or "NO ROUTE"))
    U.summary:SetText("Player: " .. G.FormatPoint(status and status.position) .. "\n\nMap: " .. tostring(status and status.map or "--") .. "   |   " .. S.message)
    local percent=status and (status.loaded and 100 or tonumber(status.loadingPercent)) or 0
    percent=G.Clamp(percent or 0,0,100)
    U.meshBar:SetValue(percent)
    U.meshName:SetText(status and status.mesh~="" and status.mesh or "No active mesh")
    U.meshPercent:SetText(string.format("%d%%   |   %s",percent,err or (status and status.loaded and "Region ready") or (status and status.error) or "Waiting for grid.dll"))
    local capabilities={}
    for _,name in ipairs({"Objects","NavStatus","NavConfigure","NavPath","NavScreenToWorld","WorldToScreen","ClearTaint"}) do
        table.insert(capabilities,(B.Has(name) and "|cff38e8baREADY|r   " or "|cffffa071MISSING|r   ") .. "C." .. name)
    end
    U.capabilities:SetText(table.concat(capabilities,"\n"))
    U.footer:SetText(err or ((status and status.error~="" and status.error) or ("grid.dll connected  |  " .. S.message)))
    if U.meshInput:GetText()=="" and status and status.index then U.meshInput:SetText(status.index) end
    U.routeMessage:SetText(N.message)
    U.routeProgress:SetText(S.message)
    local upcoming={}
    for i=N.waypoint,math.min(#N.path,N.waypoint+5) do table.insert(upcoming,string.format("%03d   %s",i,G.FormatPoint(N.path[i]))) end
    U.waypoints:SetText(#upcoming>0 and table.concat(upcoming,"\n\n") or "No route yet")
    local queue={}
    for i=1,math.min(4,#N.queue) do table.insert(queue,i .. "   " .. G.FormatPoint(N.queue[i])) end
    if #N.queue>4 then table.insert(queue,"+ " .. (#N.queue-4) .. " more") end
    U.queueText:SetText(#queue>0 and table.concat(queue,"\n\n") or "No queued stops")
    local camera=B.Camera()
    U.cameraHint:SetText(camera and (camera.source .. (camera.estimated and "\nRe-center behind player before picking." or "")) or "Camera unavailable")
    U.drawButton.caption:SetText("World route: " .. (G.DB.drawWorld and "ON" or "OFF"))
    U.ctrlButton.caption:SetText("Ctrl+click: " .. (G.DB.ctrlClick and "ON" or "OFF"))
    U.swimButton.caption:SetText(G.DB.pathFlags==7 and "Traversal: walk + swim" or "Traversal: walk + doors")
    G.Drawing.Map(U.mapCanvas,354,184)
    U.Logs()
end
G.On("objects",function() U.Objects() end)
G.On("selection",function() U.Objects() end)
G.On("destination",function(p)
    if U.coordinates then
        U.coordinates[1]:SetText(string.format("%.3f",p.x));U.coordinates[2]:SetText(string.format("%.3f",p.y));U.coordinates[3]:SetText(string.format("%.3f",p.z))
    end
end)
G.On("route",function() U.Update() end)
G.On("queue",function() U.Update() end)
G.On("log",function() U.Logs() end)
