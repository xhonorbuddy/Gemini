local G,N,S,U=Gemini,Gemini.Nav,Gemini.Steering,Gemini.UI
G.driver=CreateFrame("Frame")
function G.CancelPick(reason)
    if not G.pickDeadline then return end
    G.pickDeadline=nil;U.picker:Hide()
    if G.pickWasVisible then U.Show() end
    G.pickWasVisible=nil
    if reason then G.Log("info",reason) end
end
function G.BeginPick()
    local status,err=G.Bridge.Status()
    if not status or not status.loaded then return false,err or "Load the active mesh first" end
    S.Stop("Picking terrain")
    G.pickDeadline=GetTime()+3;G.pickWasVisible=U.window:IsShown()
    U.window:Hide();U.picker:Show()
    U.pickText:SetText("Aim at terrain. Picking in 3 seconds...")
    return true
end
function G.Tick(elapsed)
    if not G.ready then return end
    if G.pickDeadline then
        if IsControlKeyDown() and IsAltKeyDown() then G.CancelPick("Pick cancelled by Ctrl+Alt")
        elseif GetTime()>=G.pickDeadline then
            -- Sample the cursor before restoring the panel underneath it.
            local ok,err=N.Pick()
            G.CancelPick()
            if not ok then N.message="Terrain pick failed: " .. tostring(err) end
            U.Update()
        else U.pickText:SetText(string.format("Aim at terrain. Picking in %.1fs",G.pickDeadline-GetTime())) end
    end
    S.Tick(elapsed)
    G.elapsed=G.elapsed+elapsed
    G.drawElapsed=(G.drawElapsed or 0)+elapsed
    if G.drawElapsed>=0.1 then G.drawElapsed=0;G.Drawing.World() end
    G.objectElapsed=(G.objectElapsed or 0)+elapsed
    if U.window:IsShown() and U.tab=="Objects" and G.objectElapsed>=G.DB.refreshSeconds then
        G.objectElapsed=0;G.Objects.Refresh()
    end
    if G.elapsed>=0.25 then G.elapsed=0;if U.window:IsShown() then U.Update() end end
end
function G.Initialize()
    if G.ready then return end
    G.InitializeDB();U.Initialize();G.Drawing.Initialize();G.ready=true
    SLASH_GEMINI1,SLASH_GEMINI2="/gemini","/gmni"
    SlashCmdList.GEMINI=function(command)
        command=string.lower(string.gsub(command or "","^%s*(.-)%s*$","%1"))
        if command=="stop" then G.CancelPick();S.Stop("Stopped by /gemini stop")
        elseif command=="pick" then local ok,err=G.BeginPick();if not ok then G.Log("error",err) end
        elseif command=="objects" then U.Show();U.ShowTab("Objects")
        elseif command=="nav" then U.Show();U.ShowTab("Navigation")
        else G.CancelPick();U.Toggle() end
    end
    if WorldFrame and WorldFrame.HookScript then
        WorldFrame:HookScript("OnMouseDown",function(_,button)
            if button~="LeftButton" or not G.DB.ctrlClick or not IsControlKeyDown() or IsAltKeyDown() then return end
            if G.pickDeadline then G.CancelPick() end
            local ok,err=N.Pick()
            if not ok then N.message="Terrain pick failed: " .. tostring(err) end
            U.Update()
        end)
    end
    G.driver:SetScript("OnUpdate",function(_,elapsed)
        local ok,err=pcall(G.Tick,elapsed)
        if not ok then S.Stop("Update error","blocked");G.Log("error",err) end
    end)
    G.Log("info","Gemini " .. G.version .. " loaded. /gemini opens the manager.")
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff38e8baGemini|r ready. /gemini  |  Ctrl+click terrain  |  Ctrl+Alt stops") end
end
G.driver:RegisterEvent("ADDON_LOADED")
G.driver:RegisterEvent("PLAYER_LEAVING_WORLD")
G.driver:RegisterEvent("PLAYER_LOGOUT")
G.driver:RegisterEvent("PLAYER_DEAD")
G.driver:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name=="Gemini" then G.Initialize()
    elseif G.ready and (event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" or event=="PLAYER_DEAD") then
        G.CancelPick();S.Stop(event,"paused");N.ClearPath("World state changed; find a fresh route")
    end
end)
