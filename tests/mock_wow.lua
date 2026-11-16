Mock={frames={},time=0,ctrl=false,alt=false,moves={},clearCount=0,calls={},cursor={400,300},facing=0}
local M=Mock
local methods={}
local function object(kind,parent,name)
    local f=setmetatable({kind=kind,parent=parent,name=name,shown=true,scripts={},hooks={},text="",width=100,height=30,scale=1,left=0,bottom=0}, {__index=methods})
    table.insert(M.frames,f)
    if name then _G[name]=f end
    return f
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(s) self.scale=s end
function methods:GetEffectiveScale() return self.scale end
function methods:GetLeft() return self.left end
function methods:GetBottom() return self.bottom end
function methods:GetFrameLevel() return 2 end
function methods:SetPoint(...) self.point={...} end
function methods:SetAllPoints(parent) if parent then self.width,self.height=parent.width,parent.height end end
function methods:ClearAllPoints() self.point=nil end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:HookScript(name,fn) self.hooks[name]=self.hooks[name] or {};table.insert(self.hooks[name],fn) end
function methods:Fire(name,...)
    if self.scripts[name] then self.scripts[name](self,...) end
    for _,fn in ipairs(self.hooks[name] or {}) do fn(self,...) end
end
function methods:Show() local old=self.shown;self.shown=true;if not old then self:Fire("OnShow") end end
function methods:Hide() local old=self.shown;self.shown=false;if old then self:Fire("OnHide") end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:SetText(value) self.text=tostring(value or "");self:Fire("OnTextChanged") end
function methods:GetText() return self.text end
function methods:GetStringHeight() local _,count=string.gsub(self.text,"\n","");return 14*(count+1) end
function methods:CreateTexture() return object("Texture",self) end
function methods:CreateFontString() return object("FontString",self) end
function methods:SetScrollChild(child) self.child=child end
function methods:SetValue(value) self.value=value end
function methods:ClearFocus() self.focus=false end
for _,method in ipairs({"SetTexture","SetVertexColor","SetTextColor","SetJustifyH","SetWordWrap","SetRotation","SetFrameStrata","SetFrameLevel","SetMovable","SetClampedToScreen","EnableMouse","RegisterForDrag","StartMoving","StopMovingOrSizing","SetAutoFocus","SetMaxLetters","SetMinMaxValues","SetStatusBarTexture","SetStatusBarColor","RegisterEvent"}) do methods[method]=function() end end
function CreateFrame(kind,name,parent) return object(kind,parent,name) end
UIParent=object("Frame");UIParent:SetSize(1920,1080)
WorldFrame=object("Frame");WorldFrame:SetSize(1920,1080)
UISpecialFrames={};SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function GetTime() return M.time end
function IsControlKeyDown() return M.ctrl end
function IsAltKeyDown() return M.alt end
function GetCursorPosition() return unpack(M.cursor) end
function GetPlayerFacing() return M.facing end
function GetCameraZoom() return 12 end
function UnitIsDeadOrGhost() return false end
function date() return "12:00:00" end
M.status={loaded=true,loadingPercent=100,playerAvailable=true,map=1,position={x=0,y=0,z=0},mesh="kalimdor_28_16.wnav",error="",index="C:/meshes/world.wnavindex"}
M.path={{x=0,y=0,z=0},{x=20,y=0,z=0}}
C={}
function C.NavStatus() return M.status end
function C.ClearTaint() M.clearCount=M.clearCount+1;return M.clearSuccess~=false end
function C.NavConfigure(path) M.configured=path;return true end
function C.NavPath(x,y,z,flags)
    M.calls.path={x,y,z,flags}
    if M.pathError then return nil,M.pathError end
    return M.path
end
function C.NavScreenToWorld(...)
    M.calls.pick={...}
    if M.pickError then return nil,M.pickError end
    return 20,0,0
end
function C.WorldToScreen(x,y) return 0.5+x/100,0.5+y/100,true end
function C.Objects() return M.objects or {} end
for _,name in ipairs({"MoveForwardStart","MoveForwardStop","TurnLeftStart","TurnLeftStop","TurnRightStart","TurnRightStop"}) do
    local label=name
    _G[label]=function()
        assert(M.clearCount>#M.moves,"ClearTaint must run before every movement call")
        table.insert(M.moves,label)
        if M.failMove==label then error("movement denied") end
    end
end
function M.Advance(seconds)
    M.time=M.time+seconds
    Gemini.Tick(seconds)
end
function M.Button(label)
    for _,frame in ipairs(M.frames) do
        if frame.kind=="Button" and frame.caption and frame.caption:GetText()==label then return frame end
    end
    error("Missing button: " .. label)
end
