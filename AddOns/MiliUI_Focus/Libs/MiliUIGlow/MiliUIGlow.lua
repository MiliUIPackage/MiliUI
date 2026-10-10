--[[
MiliUIGlow -- MiliUI 套組的發光引擎

    ⚠ 這是 vendor 複製，不是 LibStub 函式庫。唯一 source 在
      AddOns/MiliUI/Libs/MiliUIGlow/。要改就改 source 再同步全部 copy，
      複製契約看同目錄的 README.md。

來源：LibCustomGlow-1.0 v25（Hendrick "nevcairiel" Leppkes 的 LibButtonGlow-1.0 之後續）
      https://www.wowace.com/projects/libcustomglow

API 與 LibCustomGlow **完全相同**，所以抽換只要改綁定那一行：
    local LCG = LibStub("LibCustomGlow-1.0")   -->   local LCG = <ns>.MiliUIGlow

跟上游的差別只有三處，其餘逐字不動（動畫長相因此必然一致）：

 1. 不註冊到 LibStub，改掛在插件自己的私有表上。
    LibStub 只留版本最高的那一份，而「哪一份贏」取決於全部插件載入完之後的結果 ——
    也就是說改自己內附的那份，很可能根本不是實際在跑的那份。單體發佈更禁不起這種
    不確定性：玩家只裝一支插件時，那支必須自己就是完整的。

 2. 三個各自的 OnUpdate 收成一支共用 driver，並且閘在 60fps。
    上游對**每一個**發光各掛一個沒有節流的 OnUpdate，所以成本跟玩家的幀數成正比 ——
    144fps 的機器付 60fps 機器的 2.4 倍，換到的畫面一模一樣。

    driver 沒有訂閱者就自己隱藏（沒有發光時零成本），
    **把累積的 dt 整份傳給原本的更新函式**，所以動畫速度跟逐幀版完全一致。

 3. 多一組 Attach API（檔尾），給 12.1 引擎光環按鈕（AuraButton）的子樹用：
    caller 自備框、這裡只建全新貼圖、尺寸由 caller 給、動畫全是宣告式 AnimationGroup
    （不經過上面的 driver，副本／戰鬥中秘密狀態下照樣動）。Start 系列的池化框 reparent
    ＋ driver 推座標在那個子樹裡一條規矩都過不了。
]]

local _, ns = ...
if not ns then return end

local lib = {}
lib.glowList = {}
lib.startList = {}
lib.stopList = {}
ns.MiliUIGlow = lib

local Masque = _G.LibStub and _G.LibStub("Masque", true)
local AnimateTexCoords = (TextureUtil and TextureUtil.AnimateTexCoords) or _G.AnimateTexCoords

-------------------------------------------------------------------------------
--  共用動畫 driver
--
--  一支 OnUpdate 跑全部發光，整個派送閘在 ~60fps。發光是「一圈點在跑」，60fps 以上
--  肉眼分不出來，以下才會看得出在跳。
--
--  ⚠ 累積的 dt 整份往下傳，而且累積器歸零（不是減掉 GATE）—— 傳出去的 dt 總和等於
--    真實經過時間，動畫速度才會跟逐幀呼叫完全一樣。
--
--  ⚠ 可見度閘是**還原**上游行為，不是新增的最佳化：原本一個發光各自掛 OnUpdate，
--    frame 或它任何一層祖先被隱藏時就自動不跑了。共用 driver 沒有這個性質，要自己補。
--    註冊留著不動，所以重新顯示時會自己接回去。
--
--  ⚠ 可見度探測包 pcall：12.1 之後，位於引擎光環按鈕子樹裡的 frame 其可見度是秘密值，
--    對它做布林測試會直接拋錯 —— 而一個會拋錯的訂閱者會讓**整輪派送**中斷，
--    排在它後面的發光全部凍住。拋錯就永久踢掉（那個分割區不會恢復）。
-------------------------------------------------------------------------------
local GATE = 1 / 60

local _reg, _regFn, _regIndex, _regCount = {}, {}, {}, 0
local _driver, _accum = nil, 0

local function VisProbe(f) return f:IsVisible() end

local function DriverRemove(f)
    local i = _regIndex[f]
    if not i then return end
    local last = _reg[_regCount]
    _reg[i], _regFn[i] = last, _regFn[_regCount]
    _regIndex[last] = i
    _reg[_regCount], _regFn[_regCount] = nil, nil
    _regCount = _regCount - 1
    _regIndex[f] = nil
    if _regCount == 0 and _driver then _driver:Hide() end
end

local function DriverOnUpdate(self, elapsed)
    local dt = _accum + elapsed
    if dt < GATE then
        _accum = dt
        return
    end
    _accum = 0
    -- 走密集陣列。訂閱者可能在自己的更新裡把自己（或別人）移除，那是 swap-remove，
    -- 會讓 _regCount 縮小並把別的項目搬進當前這格 —— 所以每一步重讀 _regCount，
    -- 而且當前格被換掉時要重測同一格，不能往前進。
    local i = 1
    while i <= _regCount do
        local f = _reg[i]
        if f._glowBlind then
            -- Attach 系列（引擎光環按鈕子樹）：可見度是秘密值，問都不能問，照推。
            -- 隱藏時多算幾組座標而已；更新本身包 pcall，拋錯就踢掉，不讓整輪派送斷掉。
            local fn = _regFn[i]
            if fn and not pcall(fn, f, dt) then
                DriverRemove(f)
            end
            if _reg[i] == f then i = i + 1 end
        else
        local ok, vis = pcall(VisProbe, f)
        if not ok then
            DriverRemove(f)
        else
            -- ⚠ issecretvalue 一定要問在前面。IsVisible 對身分受限單位的子樹可能回
            -- **秘密布林**，而把秘密布林放進 if 判斷本身就是硬錯誤 —— 先用 vis 當條件
            -- 再檢查它是不是秘密，等於錯誤已經發生了。秘密一律當作隱藏。
            if issecretvalue and issecretvalue(vis) then
                -- 隱藏處理：跳過，註冊留著
            elseif vis then
                local fn = _regFn[i]
                if fn then fn(f, dt) end
            end
            if _reg[i] == f then i = i + 1 end
        end
        end
    end
    if _regCount == 0 then self:Hide() end
end

local function DriverAdd(f, fn)
    local i = _regIndex[f]
    if i then
        _regFn[i] = fn
        return
    end
    _regCount = _regCount + 1
    _reg[_regCount], _regFn[_regCount] = f, fn
    _regIndex[f] = _regCount
    if _regCount == 1 then
        if not _driver then
            _driver = CreateFrame("Frame")
            _driver:Hide()
            _driver:SetScript("OnUpdate", DriverOnUpdate)
        end
        _accum = 0          -- 閒置一段時間之後不要吃到一發過大的 dt
        _driver:Show()
    end
end

-- luacheck: globals CreateFromMixins ObjectPoolMixin CreateTexturePool CreateFramePool

local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local textureList = {
    empty = [[Interface\AdventureMap\BrokenIsles\AM_29]],
    white = [[Interface\BUTTONS\WHITE8X8]],
    shine = [[Interface\ItemSocketingFrame\UI-ItemSockets]]
}

local shineCoords = {0.3984375, 0.4453125, 0.40234375, 0.44921875}
if isRetail then
    textureList.shine = [[Interface\Artifacts\Artifacts]]
    shineCoords = {0.8115234375,0.9169921875,0.8798828125,0.9853515625}
end

function lib.RegisterTextures(texture,id)
    textureList[id] = texture
end

local GlowParent = UIParent
local GlowMaskPool = {
    createFunc = function(self)
        return self.parent:CreateMaskTexture()
    end,
    resetFunc = function(self, mask)
        mask:Hide()
        mask:ClearAllPoints()
    end,
    AddObject = function(self, object)
        local dummy = true
        self.activeObjects[object] = dummy
        self.activeObjectCount = self.activeObjectCount + 1
    end,
    ReclaimObject = function(self, object)
        tinsert(self.inactiveObjects, object)
        self.activeObjects[object] = nil
        self.activeObjectCount = self.activeObjectCount - 1
    end,
    Release = function(self, object)
        local active = self.activeObjects[object] ~= nil
        if active then
            self:resetFunc(object)
            self:ReclaimObject(object)
        end
        return active
    end,
    Acquire = function(self)
        local object = tremove(self.inactiveObjects)
        local new = object == nil
        if new then
            object = self:createFunc()
            self:resetFunc(object, new)
        end
        self:AddObject(object)
        return object, new
    end,
    Init = function(self, parent)
        self.activeObjects = {}
        self.inactiveObjects = {}
        self.activeObjectCount = 0
        self.parent = parent
    end
}
GlowMaskPool:Init(GlowParent)

local TexPoolResetter = function(pool,tex)
    local maskNum = tex:GetNumMaskTextures()
    for i = maskNum , 1, -1 do
        tex:RemoveMaskTexture(tex:GetMaskTexture(i))
    end
    tex:Hide()
    tex:ClearAllPoints()
end
local GlowTexPool = CreateTexturePool(GlowParent ,"ARTWORK",7,nil,TexPoolResetter)
lib.GlowTexPool = GlowTexPool

local FramePoolResetter = function(framePool,frame)
    DriverRemove(frame)
    local parent = frame:GetParent()
    if parent[frame.name] then
        parent[frame.name] = nil
    end
    if frame.textures then
        for _, texture in pairs(frame.textures) do
            GlowTexPool:Release(texture)
        end
    end
    if frame.bg then
        GlowTexPool:Release(frame.bg)
        frame.bg = nil
    end
    if frame.masks then
        for _,mask in pairs(frame.masks) do
            GlowMaskPool:Release(mask)
        end
        frame.masks = nil
    end
    frame.textures = {}
    frame.info = {}
    frame.name = nil
    frame.timer = nil
    frame:Hide()
    frame:ClearAllPoints()
end
local GlowFramePool = CreateFramePool("Frame",GlowParent,nil,FramePoolResetter)
lib.GlowFramePool = GlowFramePool

local function addFrameAndTex(r,color,name,key,N,xOffset,yOffset,texture,texCoord,desaturated,frameLevel)
    key = key or ""
	frameLevel = frameLevel or 8
    if not r[name..key] then
        r[name..key] = GlowFramePool:Acquire()
        r[name..key]:SetParent(r)
        r[name..key].name = name..key
    end
    local f = r[name..key]
	f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
    f:SetPoint("TOPLEFT",r,"TOPLEFT",-xOffset+0.05,yOffset+0.05)
    f:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",xOffset,-yOffset+0.05)
    f:Show()

    if not f.textures then
        f.textures = {}
    end

    for i=1,N do
        if not f.textures[i] then
            f.textures[i] = GlowTexPool:Acquire()
            f.textures[i]:SetTexture(texture)
            f.textures[i]:SetTexCoord(texCoord[1],texCoord[2],texCoord[3],texCoord[4])
            f.textures[i]:SetDesaturated(desaturated)
            f.textures[i]:SetParent(f)
            f.textures[i]:SetDrawLayer("ARTWORK",7)
            if not isRetail and name == "_AutoCastGlow" then
                f.textures[i]:SetBlendMode("ADD")
            end
        end
        -- Handle both array format {r,g,b,a} and Color objects (for WoW 12.0 secret values)
        if type(color) == "table" and color.GetRGBA then
            f.textures[i]:SetVertexColor(color:GetRGBA())
        else
            f.textures[i]:SetVertexColor(color[1],color[2],color[3],color[4])
        end
        f.textures[i]:Show()
    end
    while #f.textures>N do
        GlowTexPool:Release(f.textures[#f.textures])
        table.remove(f.textures)
    end
end


--Pixel Glow Functions--
local pCalc1 = function(progress,s,th,p)
    local c
    if progress>p[3] or progress<p[0] then
        c = 0
    elseif progress>p[2] then
        c =s-th-(progress-p[2])/(p[3]-p[2])*(s-th)
    elseif progress>p[1] then
        c =s-th
    else
        c = (progress-p[0])/(p[1]-p[0])*(s-th)
    end
    return math.floor(c+0.5)
end

local pCalc2 = function(progress,s,th,p)
    local c
    if progress>p[3] then
        c = s-th-(progress-p[3])/(p[0]+1-p[3])*(s-th)
    elseif progress>p[2] then
        c = s-th
    elseif progress>p[1] then
        c = (progress-p[1])/(p[2]-p[1])*(s-th)
    elseif progress>p[0] then
        c = 0
    else
        c = s-th-(progress+1-p[3])/(p[0]+1-p[3])*(s-th)
    end
    return math.floor(c+0.5)
end

local  pUpdate = function(self,elapsed)
    self.timer = self.timer+elapsed/self.info.period
    if self.timer>1 or self.timer <-1 then
        self.timer = self.timer%1
    end
    local progress = self.timer
    local width,height
    if self.info.fixedW then
        width,height = self.info.fixedW,self.info.fixedH   -- Attach：尺寸是 caller 給的
    else
        width,height = self:GetSize()
    end
    if width ~= self.info.width or height ~= self.info.height then
        local perimeter = 2*(width+height)
        if not (perimeter>0) then
            return
        end
        self.info.width = width
        self.info.height = height
        self.info.pTLx = {
            [0] = (height+self.info.length/2)/perimeter,
            [1] = (height+width+self.info.length/2)/perimeter,
            [2] = (2*height+width-self.info.length/2)/perimeter,
            [3] = 1-self.info.length/2/perimeter
        }
        self.info.pTLy ={
            [0] = (height-self.info.length/2)/perimeter,
            [1] = (height+width+self.info.length/2)/perimeter,
            [2] = (height*2+width+self.info.length/2)/perimeter,
            [3] = 1-self.info.length/2/perimeter
        }
        self.info.pBRx ={
            [0] = self.info.length/2/perimeter,
            [1] = (height-self.info.length/2)/perimeter,
            [2] = (height+width-self.info.length/2)/perimeter,
            [3] = (height*2+width+self.info.length/2)/perimeter
        }
        self.info.pBRy ={
            [0] = self.info.length/2/perimeter,
            [1] = (height+self.info.length/2)/perimeter,
            [2] = (height+width-self.info.length/2)/perimeter,
            [3] = (height*2+width-self.info.length/2)/perimeter
        }
    end
    if self._glowBlind or self:IsShown() then
        if not self._glowBlind then   -- Attach：遮罩與底在掛上時就 Show 好，IsShown 不能問
        if not (self.masks[1]:IsShown()) then
            self.masks[1]:Show()
            self.masks[1]:SetPoint("TOPLEFT",self,"TOPLEFT",self.info.th,-self.info.th)
            self.masks[1]:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-self.info.th,self.info.th)
        end
        if self.masks[2] and not(self.masks[2]:IsShown()) then
            self.masks[2]:Show()
            self.masks[2]:SetPoint("TOPLEFT",self,"TOPLEFT",self.info.th+1,-self.info.th-1)
            self.masks[2]:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-self.info.th-1,self.info.th+1)
        end
        if self.bg and not(self.bg:IsShown()) then
            self.bg:Show()
        end
        end
        for k,line  in pairs(self.textures) do
            line:SetPoint("TOPLEFT",self,"TOPLEFT",pCalc1((progress+self.info.step*(k-1))%1,width,self.info.th,self.info.pTLx),-pCalc2((progress+self.info.step*(k-1))%1,height,self.info.th,self.info.pTLy))
            line:SetPoint("BOTTOMRIGHT",self,"TOPLEFT",self.info.th+pCalc2((progress+self.info.step*(k-1))%1,width,self.info.th,self.info.pBRx),-height+pCalc1((progress+self.info.step*(k-1))%1,height,self.info.th,self.info.pBRy))
        end
    end
end

function lib.PixelGlow_Start(r,color,N,frequency,length,th,xOffset,yOffset,border,key,frameLevel)
    if not r then
        return
    end
    if not color then
        color = {0.95,0.95,0.32,1}
    end

    if not(N and N>0) then
        N = 8
    end

    local period
    if frequency then
        if not(frequency>0 or frequency<0) then
            period = 4
        else
            period = 1/frequency
        end
    else
        period = 4
    end
    local width,height = r:GetSize()
    length = length or math.floor((width+height)*(2/N-0.1))
    length = min(length,min(width,height))
    th = th or 1
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    key = key or ""

    addFrameAndTex(r,color,"_PixelGlow",key,N,xOffset,yOffset,textureList.white,{0,1,0,1},nil,frameLevel)
    local f = r["_PixelGlow"..key]
    if not f.masks then
        f.masks = {}
    end
    if not f.masks[1] then
        f.masks[1] = GlowMaskPool:Acquire()
        f.masks[1]:SetTexture(textureList.empty, "CLAMPTOWHITE","CLAMPTOWHITE")
        f.masks[1]:Show()
    end
    f.masks[1]:SetPoint("TOPLEFT",f,"TOPLEFT",th,-th)
    f.masks[1]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-th,th)

    if not(border==false) then
        if not f.masks[2] then
            f.masks[2] = GlowMaskPool:Acquire()
            f.masks[2]:SetTexture(textureList.empty, "CLAMPTOWHITE","CLAMPTOWHITE")
        end
        f.masks[2]:SetPoint("TOPLEFT",f,"TOPLEFT",th+1,-th-1)
        f.masks[2]:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-th-1,th+1)

        if not f.bg then
            f.bg = GlowTexPool:Acquire()
            f.bg:SetColorTexture(0.1,0.1,0.1,0.8)
            f.bg:SetParent(f)
            f.bg:SetAllPoints(f)
            f.bg:SetDrawLayer("ARTWORK",6)
            f.bg:AddMaskTexture(f.masks[2])
        end
    else
        if f.bg then
            GlowTexPool:Release(f.bg)
            f.bg = nil
        end
        if f.masks[2] then
            GlowMaskPool:Release(f.masks[2])
            f.masks[2] = nil
        end
    end
    for _,tex in pairs(f.textures) do
        if tex:GetNumMaskTextures() < 1 then
            tex:AddMaskTexture(f.masks[1])
        end
    end
    f.timer = f.timer or 0
    f.info = f.info or {}
    f.info.step = 1/N
    f.info.period = period
    f.info.th = th
    if f.info.length ~= length then
        f.info.width = nil
        f.info.length = length
    end
    pUpdate(f, 0)
    DriverAdd(f, pUpdate)
end

function lib.PixelGlow_Stop(r,key)
    if not r then
        return
    end
    key = key or ""
    if not r["_PixelGlow"..key] then
        return false
    else
        GlowFramePool:Release(r["_PixelGlow"..key])
    end
end

table.insert(lib.glowList, "Pixel Glow")
lib.startList["Pixel Glow"] = lib.PixelGlow_Start
lib.stopList["Pixel Glow"] = lib.PixelGlow_Stop


--Autocast Glow Functions--
local function acUpdate(self,elapsed)
    local width,height
    if self.info.fixedW then
        width,height = self.info.fixedW,self.info.fixedH   -- Attach：尺寸是 caller 給的
    else
        width,height = self:GetSize()
    end
    if width ~= self.info.width or height ~= self.info.height then
        if width*height == 0 then return end -- Avoid division by zero
        self.info.width = width
        self.info.height = height
        self.info.perimeter = 2*(width+height)
        self.info.bottomlim = height*2+width
        self.info.rightlim = height+width
        self.info.space = self.info.perimeter/self.info.N
    end

    local texIndex = 0;
    for k=1,4 do
        self.timer[k] = self.timer[k]+elapsed/(self.info.period*k)
        if self.timer[k] > 1 or self.timer[k] <-1 then
            self.timer[k] = self.timer[k]%1
        end
        for i = 1,self.info.N do
            texIndex = texIndex+1
            local position = (self.info.space*i+self.info.perimeter*self.timer[k])%self.info.perimeter
            if position>self.info.bottomlim then
                self.textures[texIndex]: SetPoint("CENTER",self,"BOTTOMRIGHT",-position+self.info.bottomlim,0)
            elseif position>self.info.rightlim then
                self.textures[texIndex]: SetPoint("CENTER",self,"TOPRIGHT",0,-position+self.info.rightlim)
            elseif position>self.info.height then
                self.textures[texIndex]: SetPoint("CENTER",self,"TOPLEFT",position-self.info.height,0)
            else
                self.textures[texIndex]: SetPoint("CENTER",self,"BOTTOMLEFT",0,position)
            end
        end
    end
end

function lib.AutoCastGlow_Start(r,color,N,frequency,scale,xOffset,yOffset,key,frameLevel)
    if not r then
        return
    end

    if not color then
        color = {0.95,0.95,0.32,1}
    end

    if not(N and N>0) then
        N = 4
    end

    local period
    if frequency then
        if not(frequency>0 or frequency<0) then
            period = 8
        else
            period = 1/frequency
        end
    else
        period = 8
    end
    scale = scale or 1
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    key = key or ""

    addFrameAndTex(r,color,"_AutoCastGlow",key,N*4,xOffset,yOffset,textureList.shine,shineCoords, true, frameLevel)
    local f = r["_AutoCastGlow"..key]
    local sizes = {7,6,5,4}
    for k,size in pairs(sizes) do
        for i = 1,N do
            f.textures[i+N*(k-1)]:SetSize(size*scale,size*scale)
        end
    end
    f.timer = f.timer or {0,0,0,0}
    f.info = f.info or {}
    f.info.N = N
    f.info.period = period
    DriverAdd(f, acUpdate)
    acUpdate(f, 0)
end

function lib.AutoCastGlow_Stop(r,key)
    if not r then
        return
    end

    key = key or ""
    if not r["_AutoCastGlow"..key] then
        return false
    else
        GlowFramePool:Release(r["_AutoCastGlow"..key])
    end
end

table.insert(lib.glowList, "Autocast Shine")
lib.startList["Autocast Shine"] = lib.AutoCastGlow_Start
lib.stopList["Autocast Shine"] = lib.AutoCastGlow_Stop

--Action Button Glow--
local function ButtonGlowResetter(framePool,frame)
    DriverRemove(frame)
    local parent = frame:GetParent()
    if parent._ButtonGlow then
        parent._ButtonGlow = nil
    end
    frame:Hide()
    frame:ClearAllPoints()
end
local ButtonGlowPool = CreateFramePool("Frame",GlowParent,nil,ButtonGlowResetter)
lib.ButtonGlowPool = ButtonGlowPool

local function CreateScaleAnim(group, target, order, duration, x, y, delay)
    local scale = group:CreateAnimation("Scale")
    scale:SetChildKey(target)
    scale:SetOrder(order)
    scale:SetDuration(duration)
    scale:SetScale(x, y)

    if delay then
        scale:SetStartDelay(delay)
    end
end

local function CreateAlphaAnim(group, target, order, duration, fromAlpha, toAlpha, delay, appear)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetChildKey(target)
    alpha:SetOrder(order)
    alpha:SetDuration(duration)
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    if delay then
        alpha:SetStartDelay(delay)
    end
    if appear then
        table.insert(group.appear, alpha)
    else
        table.insert(group.fade, alpha)
    end
end

local function AnimIn_OnPlay(group)
    local frame = group:GetParent()
    local frameWidth, frameHeight = frame:GetSize()
    frame.spark:SetSize(frameWidth, frameHeight)
    frame.spark:SetAlpha(not(frame.color) and 1.0 or 0.3*frame.color[4])
    frame.innerGlow:SetSize(frameWidth / 2, frameHeight / 2)
    frame.innerGlow:SetAlpha(not(frame.color) and 1.0 or frame.color[4])
    frame.innerGlowOver:SetAlpha(not(frame.color) and 1.0 or frame.color[4])
    frame.outerGlow:SetSize(frameWidth * 2, frameHeight * 2)
    frame.outerGlow:SetAlpha(not(frame.color) and 1.0 or frame.color[4])
    frame.outerGlowOver:SetAlpha(not(frame.color) and 1.0 or frame.color[4])
    frame.ants:SetSize(frameWidth * 0.85, frameHeight * 0.85)
    frame.ants:SetAlpha(0)
    frame:Show()
end

local function AnimIn_OnFinished(group)
    local frame = group:GetParent()
    local frameWidth, frameHeight = frame:GetSize()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlow:SetSize(frameWidth, frameHeight)
    frame.innerGlowOver:SetAlpha(0.0)
    frame.outerGlow:SetSize(frameWidth, frameHeight)
    frame.outerGlowOver:SetAlpha(0.0)
    frame.outerGlowOver:SetSize(frameWidth, frameHeight)
    frame.ants:SetAlpha(not(frame.color) and 1.0 or frame.color[4])
end

local function AnimIn_OnStop(group)
    local frame = group:GetParent()
    local frameWidth, frameHeight = frame:GetSize()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlowOver:SetAlpha(0.0)
    frame.outerGlowOver:SetAlpha(0.0)
end

local function bgHide(self)
    if self.animOut:IsPlaying() then
        self.animOut:Stop()
        ButtonGlowPool:Release(self)
    end
end

local function bgUpdate(self, elapsed)
    AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, self.throttle);
    local cooldown = self:GetParent().cooldown;
    local duration = cooldown and cooldown:IsShown() and cooldown:GetCooldownDuration()
    if((not issecretvalue or not issecretvalue(duration)) and duration and duration > 3000) then
        self:SetAlpha(0.5);
    else
        self:SetAlpha(1.0);
    end
end

local function configureButtonGlow(f,alpha)
    f.spark = f:CreateTexture(nil, "BACKGROUND")
    f.spark:SetPoint("CENTER")
    f.spark:SetAlpha(0)
    f.spark:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

    -- inner glow
    f.innerGlow = f:CreateTexture(nil, "ARTWORK")
    f.innerGlow:SetPoint("CENTER")
    f.innerGlow:SetAlpha(0)
    f.innerGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    -- inner glow over
    f.innerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.innerGlowOver:SetPoint("TOPLEFT", f.innerGlow, "TOPLEFT")
    f.innerGlowOver:SetPoint("BOTTOMRIGHT", f.innerGlow, "BOTTOMRIGHT")
    f.innerGlowOver:SetAlpha(0)
    f.innerGlowOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    -- outer glow
    f.outerGlow = f:CreateTexture(nil, "ARTWORK")
    f.outerGlow:SetPoint("CENTER")
    f.outerGlow:SetAlpha(0)
    f.outerGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

    -- outer glow over
    f.outerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.outerGlowOver:SetPoint("TOPLEFT", f.outerGlow, "TOPLEFT")
    f.outerGlowOver:SetPoint("BOTTOMRIGHT", f.outerGlow, "BOTTOMRIGHT")
    f.outerGlowOver:SetAlpha(0)
    f.outerGlowOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

    -- ants
    f.ants = f:CreateTexture(nil, "OVERLAY")
    f.ants:SetPoint("CENTER")
    f.ants:SetAlpha(0)
    f.ants:SetTexture([[Interface\SpellActivationOverlay\IconAlertAnts]])

    f.animIn = f:CreateAnimationGroup()
    f.animIn.appear = {}
    f.animIn.fade = {}
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 1.5, 1.5)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, 0, alpha, nil, true)
    CreateScaleAnim(f.animIn, "innerGlow",      1, 0.3, 2, 2)
    CreateScaleAnim(f.animIn, "innerGlowOver",  1, 0.3, 2, 2)
    CreateAlphaAnim(f.animIn, "innerGlowOver",  1, 0.3, alpha, 0, nil, false)
    CreateScaleAnim(f.animIn, "outerGlow",      1, 0.3, 0.5, 0.5)
    CreateScaleAnim(f.animIn, "outerGlowOver",  1, 0.3, 0.5, 0.5)
    CreateAlphaAnim(f.animIn, "outerGlowOver",  1, 0.3, alpha, 0, nil, false)
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 2/3, 2/3, 0.2)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, alpha, 0, 0.2, false)
    CreateAlphaAnim(f.animIn, "innerGlow",      1, 0.2, alpha, 0, 0.3, false)
    CreateAlphaAnim(f.animIn, "ants",           1, 0.2, 0, alpha, 0.3, true)
    f.animIn:SetScript("OnPlay", AnimIn_OnPlay)
    f.animIn:SetScript("OnStop", AnimIn_OnStop)
    f.animIn:SetScript("OnFinished", AnimIn_OnFinished)

    f.animOut = f:CreateAnimationGroup()
    f.animOut.appear = {}
    f.animOut.fade = {}
    CreateAlphaAnim(f.animOut, "outerGlowOver", 1, 0.2, 0, alpha, nil, true)
    CreateAlphaAnim(f.animOut, "ants",          1, 0.2, alpha, 0, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlowOver", 2, 0.2, alpha, 0, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlow",     2, 0.2, alpha, 0, nil, false)
    f.animOut:SetScript("OnFinished", function(self) ButtonGlowPool:Release(self:GetParent())  end)

    f:SetScript("OnHide", bgHide)
end

local function updateAlphaAnim(f,alpha)
    for _,anim in pairs(f.animIn.appear) do
        anim:SetToAlpha(alpha)
    end
    for _,anim in pairs(f.animIn.fade) do
        anim:SetFromAlpha(alpha)
    end
    for _,anim in pairs(f.animOut.appear) do
        anim:SetToAlpha(alpha)
    end
    for _,anim in pairs(f.animOut.fade) do
        anim:SetFromAlpha(alpha)
    end
end

local ButtonGlowTextures = {["spark"] = true,["innerGlow"] = true,["innerGlowOver"] = true,["outerGlow"] = true,["outerGlowOver"] = true,["ants"] = true}

local function noZero(num)
    if num == 0 then
        return 0.001
    else
        return num
    end
end

function lib.ButtonGlow_Start(r,color,frequency,frameLevel)
    if not r then
        return
    end
	frameLevel = frameLevel or 8;
    local throttle
    if frequency and frequency > 0 then
        throttle = 0.25/frequency*0.01
    else
        throttle = 0.01
    end
    if r._ButtonGlow then
        local f = r._ButtonGlow
        local width,height = r:GetSize()
        f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
        f:SetSize(width*1.4 , height*1.4)
        f:SetPoint("TOPLEFT", r, "TOPLEFT", -width * 0.2, height * 0.2)
        f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", width * 0.2, -height * 0.2)
        f.ants:SetSize(width*1.4*0.85, height*1.4*0.85)
        -- 換色重啟：不讀回貼圖的 GetAlpha 再換算——宿主（例如 Cell 的光環圖示）祖先鏈上有
        -- 秘密 alpha 時，讀回來是秘密值、一做算術就炸。各貼圖在這個時間點的 alpha 本來就是
        -- 已知的（OnFinished／OnPlay 照 f.color 寫死），所以先換 f.color 再讓它們重寫一次。
        f.color = color or false
        local alpha = color and color[4] or 1
        updateAlphaAnim(f, alpha)
        for texture in pairs(ButtonGlowTextures) do
            if not color then
                f[texture]:SetDesaturated(nil)
                f[texture]:SetVertexColor(1,1,1)
            else
                f[texture]:SetDesaturated(1)
                if type(color) == "table" and color.GetRGBA then
                    local r, g, b = color:GetRGBA()
                    f[texture]:SetVertexColor(r, g, b)
                else
                    f[texture]:SetVertexColor(color[1],color[2],color[3])
                end
            end
        end
		AnimIn_OnFinished(f.animIn)
        f.outerGlow:SetAlpha(alpha)
        if f.animOut:IsPlaying() then
            f.animOut:Stop()
            f.animIn:Play()
        end
        f.throttle = throttle
    else
        local f, new = ButtonGlowPool:Acquire()
        if new then
            configureButtonGlow(f,color and color[4] or 1)
        else
            updateAlphaAnim(f,color and color[4] or 1)
        end
        r._ButtonGlow = f
        local width,height = r:GetSize()
        f:SetParent(r)
        f:SetFrameLevel(r:GetFrameLevel()+frameLevel)
        f:SetSize(width * 1.4, height * 1.4)
        f:SetPoint("TOPLEFT", r, "TOPLEFT", -width * 0.2, height * 0.2)
        f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", width * 0.2, -height * 0.2)
        if not(color) then
            f.color = false
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(nil)
                f[texture]:SetVertexColor(1,1,1)
            end
        else
            f.color = color
            for texture in pairs(ButtonGlowTextures) do
                f[texture]:SetDesaturated(1)
                if type(color) == "table" and color.GetRGBA then
                    local r, g, b = color:GetRGBA()
                    f[texture]:SetVertexColor(r, g, b)
                else
                    f[texture]:SetVertexColor(color[1],color[2],color[3])
                end
            end
        end
        f.throttle = throttle
        DriverAdd(f, bgUpdate)

        f.animIn:Play()

        if Masque and Masque.UpdateSpellAlert then
            Masque:UpdateSpellAlert(r, f)
        end
    end
end

function lib.ButtonGlow_Stop(r)
    if r._ButtonGlow then
        if r._ButtonGlow.animOut:IsPlaying() then
            -- Do nothing the animOut finishing will release
        elseif r._ButtonGlow.animIn:IsPlaying() then
            r._ButtonGlow.animIn:Stop()
            ButtonGlowPool:Release(r._ButtonGlow)
        elseif r:IsVisible() then
            r._ButtonGlow.animOut:Play()
        else
            ButtonGlowPool:Release(r._ButtonGlow)
        end
    end
end

table.insert(lib.glowList, "Action Button Glow")
lib.startList["Action Button Glow"] = lib.ButtonGlow_Start
lib.stopList["Action Button Glow"] = lib.ButtonGlow_Stop


-- ProcGlow

local function ProcGlowResetter(framePool, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    local parent = frame:GetParent()
    if frame.key and parent[frame.key] then
        parent[frame.key] = nil
    end
end

local ProcGlowPool = CreateFramePool("Frame", GlowParent, nil, ProcGlowResetter)
lib.ProcGlowPool = ProcGlowPool

local function InitProcGlow(f)
    f.ProcStart = f:CreateTexture(nil, "ARTWORK")
    f.ProcStart:SetBlendMode("ADD")
    f.ProcStart:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
    f.ProcStart:SetAlpha(1)
    f.ProcStart:SetSize(150, 150)
    f.ProcStart:SetPoint("CENTER")

    f.ProcLoop = f:CreateTexture(nil, "ARTWORK")
    f.ProcLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    f.ProcLoop:SetAlpha(0)
    f.ProcLoop:SetAllPoints()

    f.ProcLoopAnim = f:CreateAnimationGroup()
    f.ProcLoopAnim:SetLooping("REPEAT")
    f.ProcLoopAnim:SetToFinalAlpha(true)

    local alphaRepeat = f.ProcLoopAnim:CreateAnimation("Alpha")
    alphaRepeat:SetChildKey("ProcLoop")
    alphaRepeat:SetFromAlpha(1)
    alphaRepeat:SetToAlpha(1)
    alphaRepeat:SetDuration(.001)
    alphaRepeat:SetOrder(0)
    f.ProcLoopAnim.alphaRepeat = alphaRepeat

    local flipbookRepeat = f.ProcLoopAnim:CreateAnimation("FlipBook")
    flipbookRepeat:SetChildKey("ProcLoop")
    flipbookRepeat:SetDuration(1)
    flipbookRepeat:SetOrder(0)
    flipbookRepeat:SetFlipBookRows(6)
    flipbookRepeat:SetFlipBookColumns(5)
    flipbookRepeat:SetFlipBookFrames(30)
    flipbookRepeat:SetFlipBookFrameWidth(0)
    flipbookRepeat:SetFlipBookFrameHeight(0)
    f.ProcLoopAnim.flipbookRepeat = flipbookRepeat

    f.ProcStartAnim = f:CreateAnimationGroup()
    f.ProcStartAnim:SetToFinalAlpha(true)

    local flipbookStartAlphaIn = f.ProcStartAnim:CreateAnimation("Alpha")
    flipbookStartAlphaIn:SetChildKey("ProcStart")
    flipbookStartAlphaIn:SetDuration(.001)
    flipbookStartAlphaIn:SetOrder(0)
    flipbookStartAlphaIn:SetFromAlpha(1)
    flipbookStartAlphaIn:SetToAlpha(1)

    local flipbookStart = f.ProcStartAnim:CreateAnimation("FlipBook")
    flipbookStart:SetChildKey("ProcStart")
    flipbookStart:SetDuration(0.7)
    flipbookStart:SetOrder(1)
    flipbookStart:SetFlipBookRows(6)
    flipbookStart:SetFlipBookColumns(5)
    flipbookStart:SetFlipBookFrames(30)
    flipbookStart:SetFlipBookFrameWidth(0)
    flipbookStart:SetFlipBookFrameHeight(0)

    local flipbookStartAlphaOut = f.ProcStartAnim:CreateAnimation("Alpha")
    flipbookStartAlphaOut:SetChildKey("ProcStart")
    flipbookStartAlphaOut:SetDuration(.001)
    flipbookStartAlphaOut:SetOrder(2)
    flipbookStartAlphaOut:SetFromAlpha(1)
    flipbookStartAlphaOut:SetToAlpha(0)

    f.ProcStartAnim.flipbookStart = flipbookStart
    f.ProcStartAnim:SetScript("OnFinished", function(self)
        self:GetParent().ProcLoopAnim:Play()
        self:GetParent().ProcLoop:Show()
    end)

end

local function SetupProcGlow(f, options)
    f.key = "_ProcGlow" .. options.key -- for resetter
    f:SetScript("OnHide", function(self)
        if self.ProcStartAnim:IsPlaying() then
            self.ProcStartAnim:Stop()
        end
        if self.ProcLoopAnim:IsPlaying() then
            self.ProcLoopAnim:Stop()
        end
    end)
    f:SetScript("OnShow", function(self)
        if self.startAnim then
            if not self.ProcStartAnim:IsPlaying() and not self.ProcLoopAnim:IsPlaying() then
                --[[
to future me:
i wish you'r ok, if you wonder where are this constants coming from, check:
https://github.com/Gethe/wow-ui-source/blob/eb4459c679a1bd8919cad92934ea83c4f5e77e8b/Interface/FrameXML/ActionButton.lua#L816
https://github.com/Gethe/wow-ui-source/blob/d8e8ebf572c3b28237cf83e8fc5c0583b5453a2b/Interface/FrameXML/ActionButtonTemplate.xml#L5-L14
                ]]
                local width, height = self:GetSize()
                self.ProcStart:SetSize((width / 42 * 150) / 1.4, (height / 42 * 150) / 1.4)
                self.ProcStart:Show()
                self.ProcLoop:Hide()
                self.ProcStartAnim:Play()
            end
        else
            if not self.ProcLoopAnim:IsPlaying() then
                self.ProcStart:Hide()
                self.ProcLoop:Show()
                self.ProcLoopAnim:Play()
            end
        end
    end)
    if not options.color then
        f.ProcStart:SetDesaturated(nil)
        f.ProcStart:SetVertexColor(1, 1, 1, 1)
        f.ProcLoop:SetDesaturated(nil)
        f.ProcLoop:SetVertexColor(1, 1, 1, 1)
    else
        f.ProcStart:SetDesaturated(1)
        f.ProcStart:SetVertexColor(options.color[1], options.color[2], options.color[3], options.color[4])
        f.ProcLoop:SetDesaturated(1)
        f.ProcLoop:SetVertexColor(options.color[1], options.color[2], options.color[3], options.color[4])
    end
    f.ProcLoopAnim.flipbookRepeat:SetDuration(options.duration)
    f.startAnim = options.startAnim
end

local ProcGlowDefaults = {
    frameLevel = 8,
    color = nil,
    startAnim = true,
    xOffset = 0,
    yOffset = 0,
    duration = 1,
    key = ""
}

function lib.ProcGlow_Start(r, options)
    if not r then
        return
    end
    options = options or {}
    setmetatable(options, { __index = ProcGlowDefaults })
    local key = "_ProcGlow" .. options.key
    local f, new
    if r[key] then
        f = r[key]
    else
        f, new = ProcGlowPool:Acquire()
        if new then
            InitProcGlow(f)
        end
        r[key] = f
    end
    f:SetParent(r)
    f:SetFrameLevel(r:GetFrameLevel() + options.frameLevel)

    local width, height = r:GetSize()
    local xOffset = options.xOffset + width * 0.2
    local yOffset = options.yOffset + height * 0.2
    f:SetPoint("TOPLEFT", r, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", xOffset, -yOffset)

    SetupProcGlow(f, options)
    f:Show()
end

function lib.ProcGlow_Stop(r, key)
    key = key or ""
    local f = r["_ProcGlow" .. key]
    if f then
        ProcGlowPool:Release(f)
    end
end

table.insert(lib.glowList, "Proc Glow")
lib.startList["Proc Glow"] = lib.ProcGlow_Start
lib.stopList["Proc Glow"] = lib.ProcGlow_Stop


-------------------------------------------------------------------------------
--  Attach API：caller 自備框（第三處差別，2026-09-29；同日改成宣告式動畫組）
--
--  12.1 引擎光環按鈕（AuraButton）的子樹規矩：region 只能在 initializeFrame 視窗內建；
--  不能把既有的 widget reparent 進去；光環是秘密值時（副本／首領戰）子樹拒絕腳本——
--  子樹裡的 OnUpdate 不跑，外部 driver 對子樹貼圖的 SetPoint／SetTexCoord 第一次就被拒。
--  Start 系列全靠池化框 reparent ＋ driver 推座標，一條都過不了。Attach 系列反過來：
--
--    - caller 在視窗內建好一個乾淨的子框 f（錨好、Show 好）交進來，這裡只在 f 底下建
--      **全新**貼圖／遮罩／子框／動畫組，永遠不 reparent 任何東西，也不用池。
--    - 尺寸由 caller 給（width／height ＝ f 自己的大小）。子樹裡 GetSize 讀回來可能是
--      秘密值，秘密值進了座標算式就炸，所以一律不讀。
--    - **會動的東西全是宣告式 AnimationGroup，沒有 driver。** 動畫組不是腳本：在視窗內
--      建好、Play 一次、之後不再碰，引擎在 C 端一直播，秘密狀態下照樣動（DandersFrames
--      v5.3.3 AuraContainer.lua 檔頭第 6 條；Border.lua 的 orbit／march／flipbook 同一招）。
--        像素線、閃耀點：每顆貼圖一個 REPEAT 動畫組，Translation 分段繞周長（BuildLegLoop）
--        一般的螞蟻線：REPEAT 的 FlipBook（取代 AnimateTexCoords）
--        Proc 的循環：REPEAT 的 FlipBook，同樣自己播
--        一般的入場閃光：一次性，回傳給 caller 交給引擎播（AddAuraShownAnimation 等），
--        這裡不 Play
--
--  重複呼叫（改顏色的 restyle）只改顏色；週期變了才 Stop→改 Duration→Play；幾何（尺寸、
--  數量、線長、粗細、方向）變了才建新的動畫組（舊的 Stop 掉留在原處——動畫組刪不掉）。
--  貼圖／子框／動畫組只在缺的時候建（視窗外建不了，會被 caller 的 pcall 吃掉）。
--  Glow_Suspend／Resume 對 Attach 型是 no-op：停放的宿主底下動畫組照播，成本可忽略。
--
--  f._glowEngineShown（caller 在 Attach **之前**設）：f 底下的貼圖**可能**被逐顆交給引擎
--  控顯示（AddPandemicRegion 的退路；首選是整個 f 交出去，那樣貼圖的 Shown 仍歸這裡）。
--  交出去的貼圖 Shown 是 secret aspect，所以旗標開著時一律不再 Show／Hide 貼圖，要「藏」
--  改寫 alpha。要交哪些貼圖用 Glow_Regions(f) 取。
-------------------------------------------------------------------------------
local LOOP_EPS = 0.0001

local function AttachColor(t, color)
    if type(color) == "table" and color.GetRGBA then
        t:SetVertexColor(color:GetRGBA())
    else
        t:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

-- parents：nil ＝ 全部建在 f 上；給陣列就依序輪流（像素線的橫／直兩個裁切框）
local function AttachTextures(f, N, texture, texCoord, desaturated, color, parents)
    f.textures = f.textures or {}
    for i = 1, N do
        local t = f.textures[i]
        if not t then
            local p = parents and parents[(i - 1) % #parents + 1] or f
            t = p:CreateTexture(nil, "ARTWORK", nil, 7)
            t:SetTexture(texture)
            t:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
            t:SetDesaturated(desaturated)
            if not isRetail and texture == textureList.shine then
                t:SetBlendMode("ADD")
            end
            f.textures[i] = t
        end
        AttachColor(t, color)
        if f._glowEngineShown then
            t:SetAlpha(1)   -- 顯示歸引擎管（見上），這裡只收回 Detach 的 alpha 0
        else
            t:Show()
        end
    end
    for i = N + 1, #f.textures do
        if f._glowEngineShown then
            f.textures[i]:SetAlpha(0)
        else
            f.textures[i]:Hide()
        end
    end
end

local function AttachMask(f, idx, inset)
    f.masks = f.masks or {}
    if not f.masks[idx] then
        f.masks[idx] = f:CreateMaskTexture()
        f.masks[idx]:SetTexture(textureList.empty, "CLAMPTOWHITE", "CLAMPTOWHITE")
    end
    f.masks[idx]:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.masks[idx]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    f.masks[idx]:Show()
    return f.masks[idx]
end

-- f._glowAnims：這裡自己 Play 的動畫組（交給引擎播的不在裡面）
-- f._glowTimed：{ anim, share, anim, share, ... }，Duration ＝ 週期 × share
local function StopAnims(f)
    if f._glowAnims then
        for _, ag in ipairs(f._glowAnims) do ag:Stop() end
    end
    f._glowAnimOn = nil
end

local function PlayAnims(f)
    if f._glowAnimOn then return end   -- 播著就不碰：restyle 不該讓動畫跳回起點
    if f._glowAnims then
        for _, ag in ipairs(f._glowAnims) do ag:Play() end
    end
    f._glowAnimOn = true
end

-- 播放中改 Duration 何時生效沒把握，所以一律 Stop→改→（caller）Play。全部一起從起點
-- 重來，同一條線的橫／直兩顆與各條線之間的相位都不會錯開。
local function RetimeAnims(f, period)
    if f._glowPeriod == period then return end
    StopAnims(f)
    local t = f._glowTimed
    if t then
        for i = 1, #t, 2 do t[i]:SetDuration(period * t[i + 1]) end
    end
    f._glowPeriod = period
end

-- 同一顆 f 換類型（Cell 不會：類型是結構鍵、換了就是新按鈕；這裡只求不殘留）
local function AttachKind(f, kind)
    if f._glowKind == kind then return end
    if f._glowKind then
        lib.Glow_Detach(f)
        f.textures = nil   -- 舊類型的貼圖已藏好，留在原處不再管
    end
    f._glowKind = kind
    f._glowAnims, f._glowTimed, f._glowGeo, f._glowPeriod = nil, nil, nil, nil
end

-- 一圈「腿」的 REPEAT 動畫組，DandersFrames Border.lua buildOrbitLoop 的推廣：
--   legs[i] ＝ { 弧長, dx, dy, alpha（nil ＝ 不動 alpha） }，弧長合計 ＝ perimeter、
--   位移合計 ＝ 0，所以 REPEAT 每圈回到錨點、永不漂移，不需要任何 Lua 重新對位。
--   into ＝ t=0 時這顆貼圖在第一條腿起點之後多遠（弧長）。
--   period < 0 ＝ 反方向繞（上游 frequency 可以是負的）：腿倒過來、位移取負。
--   mult：這組的週期倍數（閃耀第 k 層是 k）。
-- 從 into 所在那條腿的剩餘段開始、繞一整圈、收在同一條腿的前段。每段一個 Translation
-- （等速，轉角不抽動）＋ 需要時同 order 的 Alpha 保持（from＝to，DF playStrobe 的方波）。
-- 回傳 into 那一點相對第一條腿起點的位移，caller 拿來錨貼圖。
local function BuildLegLoop(ag, legs, perimeter, period, into, timed, mult)
    mult = mult or 1
    if period < 0 then
        local rev = {}
        for i = #legs, 1, -1 do
            local L = legs[i]
            rev[#rev + 1] = { L[1], -L[2], -L[3], L[4] }
        end
        legs, into, period = rev, perimeter - into, -period
    end
    into = into % perimeter
    local n, leg, ox, oy = #legs, 1, 0, 0
    while leg < n and into >= legs[leg][1] do
        into = into - legs[leg][1]
        ox, oy = ox + legs[leg][2], oy + legs[leg][3]
        leg = leg + 1
    end
    local cur = legs[leg]
    local frac = into / cur[1]
    if frac > 1 then frac = 1 end   -- 浮點誤差
    ox, oy = ox + cur[2] * frac, oy + cur[3] * frac

    ag:SetLooping("REPEAT")
    local order = 0
    local function piece(L, f0, f1)
        local part = (f1 - f0) * L[1]
        if part <= LOOP_EPS then return end
        order = order + 1
        local share = part / perimeter * mult
        local tr = ag:CreateAnimation("Translation")
        tr:SetOffset(L[2] * (f1 - f0), L[3] * (f1 - f0))
        tr:SetDuration(period * share)
        tr:SetOrder(order)
        tr:SetSmoothing("NONE")
        timed[#timed + 1] = tr
        timed[#timed + 1] = share
        if L[4] then
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(L[4])
            a:SetToAlpha(L[4])
            a:SetDuration(period * share)
            a:SetOrder(order)
            timed[#timed + 1] = a
            timed[#timed + 1] = share
        end
    end
    piece(cur, frac, 1)
    for i = leg + 1, n do piece(legs[i], 0, 1) end
    for i = 1, leg - 1 do piece(legs[i], 0, 1) end
    piece(cur, 0, frac)
    return ox, oy
end

-- 上游的 frequency → period：0／nil 用預設，負的保留符號（反方向繞）
local function PeriodOf(frequency, default)
    if frequency and (frequency > 0 or frequency < 0) then return 1 / frequency end
    return default
end

-- 跟 PixelGlow_Start 同一組參數（少了 offset／key／frameLevel，多了尺寸）；border 固定畫。
--
-- 每條線 ＝ 一橫一直兩顆貼圖，各一個動畫組（週期相同、同一次呼叫裡 Play，所以永遠同相）：
--   直的（th × L）在左邊往上、右邊往下走，整條離開框時 alpha 0、在框外橫移到對邊；
--   橫的（L × th）在上邊往右、下邊往左走，整條離開框時 alpha 0、在框外直移到對邊。
-- 超出框的部分由兩個裁切子框切掉：直的切在整框、橫的切在左右各內縮 th —— 轉角那一格
-- 只歸直的畫，半透明的顏色不會疊兩次。轉過角時兩顆各露一截，合起來就是上游用遮罩切出
-- 來的 L 形。
function lib.PixelGlow_Attach(f, color, N, frequency, length, th, width, height)
    if not f then return end
    color = color or {0.95, 0.95, 0.32, 1}
    if not (N and N > 0) then N = 8 end
    local period = PeriodOf(frequency, 4)
    length = length or math.floor((width + height) * (2 / N - 0.1))
    length = min(length, min(width, height))
    th = th or 1
    -- 藏著移到對邊的那條腿長 ＝ 短邊 − 線長，必須 > 0，所以線長嚴格小於短邊
    local short = min(width, height)
    if length >= short then length = short - 1 end
    if not (length > 0 and short > th) then return end

    AttachKind(f, "pixel")
    if not f._pxClipV then
        f._pxClipV = CreateFrame("Frame", nil, f)
        f._pxClipV:SetAllPoints(f)
        f._pxClipV:SetClipsChildren(true)
        f._pxClipH = CreateFrame("Frame", nil, f)
        f._pxClipH:SetClipsChildren(true)
    end
    f._pxClipH:ClearAllPoints()
    f._pxClipH:SetPoint("TOPLEFT", f, "TOPLEFT", th, 0)
    f._pxClipH:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -th, 0)

    -- 奇數號＝橫（建在 _pxClipH）、偶數號＝直（建在 _pxClipV）
    AttachTextures(f, 2 * N, textureList.white, {0, 1, 0, 1}, nil, color, {f._pxClipH, f._pxClipV})
    local bgMask = AttachMask(f, 2, th + 1)
    if not f.bg then
        f.bg = f:CreateTexture(nil, "ARTWORK", nil, 6)
        f.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        f.bg:SetAllPoints(f)
        f.bg:AddMaskTexture(bgMask)
    end
    if f._glowEngineShown then
        f.bg:SetAlpha(1)   -- 顯示歸引擎管（見 Attach 開頭）
    else
        f.bg:Show()
    end

    local w, h, L = width, height, length
    local geo = w .. ":" .. h .. ":" .. N .. ":" .. L .. ":" .. th .. ":" .. (period < 0 and "-" or "+")
    if f._glowGeo ~= geo then
        StopAnims(f)
        local P = 2 * (w + h)
        -- 弧長從左下角往上量、順時針（跟上游 pUpdate 的 progress 同原點同方向）
        -- 直的：第一條腿的起點 ＝ 中心在弧長 −L/2（左邊、整條還在框下）
        local legsV = {
            { h + L, 0, h + L, 1 },          -- 左邊往上，整條穿過
            { w - L, w - th, 0, 0 },         -- 藏著，在框上方橫移到右邊
            { h + L, 0, -(h + L), 1 },       -- 右邊往下
            { w - L, -(w - th), 0, 0 },      -- 藏著，在框下方橫移回左邊
        }
        -- 橫的：第一條腿的起點 ＝ 中心在弧長 h − L/2（上邊、整條還在框左）
        local legsH = {
            { w + L, w + L, 0, 1 },          -- 上邊往右
            { h - L, 0, -(h - th), 0 },      -- 藏著，在框右方直移到下邊
            { w + L, -(w + L), 0, 1 },       -- 下邊往左
            { h - L, 0, h - th, 0 },         -- 藏著，在框左方直移回上邊
        }
        local anims, timed = {}, {}
        for k = 1, N do
            local s = P * (k - 1) / N   -- 第 k 條線 t=0 時中心的弧長（上游的 step*(k-1)）
            local H, V = f.textures[2 * k - 1], f.textures[2 * k]

            local ag = H:CreateAnimationGroup()
            local ox, oy = BuildLegLoop(ag, legsH, P, period, s - (h - L / 2), timed)
            H:ClearAllPoints()
            H:SetSize(L, th)
            H:SetPoint("TOPLEFT", f, "TOPLEFT", -L + ox, oy)
            anims[#anims + 1] = ag

            ag = V:CreateAnimationGroup()
            ox, oy = BuildLegLoop(ag, legsV, P, period, s + L / 2, timed)
            V:ClearAllPoints()
            V:SetSize(th, L)
            V:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ox, -L + oy)
            anims[#anims + 1] = ag
        end
        f._glowAnims, f._glowTimed = anims, timed
        f._glowGeo, f._glowPeriod = geo, math.abs(period)
    else
        RetimeAnims(f, math.abs(period))
    end
    PlayAnims(f)
end

-- 跟 AutoCastGlow_Start 同一組參數（少了 offset／key／frameLevel，多了尺寸）。
-- 每顆粒子一個動畫組繞周長（DF 的 orbit）：起點與方向照上游 acUpdate（左下角往上、
-- 第 i 顆在 space*i，四層同起點），第 k 層一圈 period*k 秒。
function lib.AutoCastGlow_Attach(f, color, N, frequency, scale, width, height)
    if not f then return end
    color = color or {0.95, 0.95, 0.32, 1}
    if not (N and N > 0) then N = 4 end
    local period = PeriodOf(frequency, 8)
    scale = scale or 1
    local w, h = width, height
    if not (w > 0 and h > 0) then return end

    AttachKind(f, "shine")
    AttachTextures(f, N * 4, textureList.shine, shineCoords, true, color)
    local sizes = {7, 6, 5, 4}
    for k, size in pairs(sizes) do
        for i = 1, N do
            f.textures[i + N * (k - 1)]:SetSize(size * scale, size * scale)
        end
    end

    local geo = w .. ":" .. h .. ":" .. N .. ":" .. (period < 0 and "-" or "+")
    if f._glowGeo ~= geo then
        StopAnims(f)
        local P = 2 * (w + h)
        local legs = { { h, 0, h }, { w, w, 0 }, { h, 0, -h }, { w, -w, 0 } }
        local space = P / N
        local anims, timed = {}, {}
        for k = 1, 4 do
            for i = 1, N do
                local t = f.textures[i + N * (k - 1)]
                local ag = t:CreateAnimationGroup()
                local ox, oy = BuildLegLoop(ag, legs, P, period, space * i, timed, k)
                t:ClearAllPoints()
                t:SetPoint("CENTER", f, "BOTTOMLEFT", ox, oy)
                anims[#anims + 1] = ag
            end
        end
        f._glowAnims, f._glowTimed = anims, timed
        f._glowGeo, f._glowPeriod = geo, math.abs(period)
    else
        RetimeAnims(f, math.abs(period))
    end
    PlayAnims(f)
end

-- ButtonGlow 的穩態（AnimIn_OnFinished 之後的長相）：outerGlow 整框、螞蟻線 0.85 框。
-- 螞蟻線是 IconAlertAnts（256² 的檔案，48² 一格、5×5 用 22 格）上的 REPEAT FlipBook，
-- 一圈 22 × throttle 秒，跟上游 AnimateTexCoords 同速；貼圖不先 SetTexCoord（FlipBook
-- 自己切格，這張是檔案不是 atlas，所以格寬高給 48）。入場閃光另做成一個**沒有 script**
-- 的動畫組回傳：spark 脹到 1.5 倍淡入、再縮回淡出，alpha 起點終點都是 0，所以不管引擎
-- 播完有沒有回呼，畫面都收在穩態。width／height ＝ f 自己的大小（caller 照上游把 f 開成
-- 按鈕的 1.4 倍）。
function lib.ButtonGlow_Attach(f, color, frequency, width, height)
    if not f then return end
    local alpha = color and color[4] or 1
    local throttle = 0.01
    if frequency and frequency > 0 then throttle = 0.25 / frequency * 0.01 end

    AttachKind(f, "normal")
    if not f.ants then
        f.spark = f:CreateTexture(nil, "BACKGROUND")
        f.spark:SetPoint("CENTER")
        f.spark:SetAlpha(0)
        f.spark:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
        f.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

        f.outerGlow = f:CreateTexture(nil, "ARTWORK")
        f.outerGlow:SetPoint("CENTER")
        f.outerGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
        f.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

        f.ants = f:CreateTexture(nil, "OVERLAY")
        f.ants:SetPoint("CENTER")
        f.ants:SetTexture([[Interface\SpellActivationOverlay\IconAlertAnts]])

        f.animIn = f:CreateAnimationGroup()
        f.animIn.appear = {}
        f.animIn.fade = {}
        CreateScaleAnim(f.animIn, "spark", 1, 0.2, 1.5, 1.5)
        CreateAlphaAnim(f.animIn, "spark", 1, 0.2, 0, alpha, nil, true)
        CreateScaleAnim(f.animIn, "spark", 2, 0.2, 2 / 3, 2 / 3)
        CreateAlphaAnim(f.animIn, "spark", 2, 0.2, alpha, 0, nil, false)
    end
    if not f._antsAnims then
        local ag = f.ants:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local fb = ag:CreateAnimation("FlipBook")
        fb:SetOrder(1)
        fb:SetFlipBookRows(5)
        fb:SetFlipBookColumns(5)
        fb:SetFlipBookFrames(22)
        fb:SetFlipBookFrameWidth(48)
        fb:SetFlipBookFrameHeight(48)
        f._antsAnims, f._antsTimed = { ag }, { fb, 22 }   -- Duration 由下面的 RetimeAnims 設
    end
    f.spark:SetSize(width, height)
    f.outerGlow:SetSize(width, height)
    f.ants:SetSize(width * 0.85, height * 0.85)
    for _, tex in pairs({f.spark, f.outerGlow, f.ants}) do
        if color then
            tex:SetDesaturated(1)
            if type(color) == "table" and color.GetRGBA then
                local r, g, b = color:GetRGBA()
                tex:SetVertexColor(r, g, b)
            else
                tex:SetVertexColor(color[1], color[2], color[3])
            end
        else
            tex:SetDesaturated(nil)
            tex:SetVertexColor(1, 1, 1)
        end
    end
    f.outerGlow:SetAlpha(alpha)
    f.ants:SetAlpha(alpha)
    for _, anim in pairs(f.animIn.appear) do anim:SetToAlpha(alpha) end
    for _, anim in pairs(f.animIn.fade) do anim:SetFromAlpha(alpha) end

    f._glowAnims, f._glowTimed = f._antsAnims, f._antsTimed
    RetimeAnims(f, throttle)
    PlayAnims(f)
    return f.animIn
end

-- ProcGlow 的循環段（Cell 只用循環，startAnim=false）：REPEAT 的翻頁動畫組，這裡自己播
-- （見函式尾）。ProcLoop 的 alpha 起點 0，動畫組第一步把它拉到 1 且 SetToFinalAlpha ——
-- 沒播就什麼都看不到（失效方向是「沒有發光」，不是「卡一張定格」）。
function lib.ProcGlow_Attach(f, color, duration, width, height)
    if not f then return end
    AttachKind(f, "proc")
    if not f.ProcLoop then
        f.ProcLoop = f:CreateTexture(nil, "ARTWORK")
        f.ProcLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
        f.ProcLoop:SetAlpha(0)
        f.ProcLoop:SetAllPoints(f)

        f.ProcLoopAnim = f:CreateAnimationGroup()
        f.ProcLoopAnim:SetLooping("REPEAT")
        f.ProcLoopAnim:SetToFinalAlpha(true)

        local alphaRepeat = f.ProcLoopAnim:CreateAnimation("Alpha")
        alphaRepeat:SetChildKey("ProcLoop")
        alphaRepeat:SetFromAlpha(1)
        alphaRepeat:SetToAlpha(1)
        alphaRepeat:SetDuration(.001)
        alphaRepeat:SetOrder(0)

        local flipbookRepeat = f.ProcLoopAnim:CreateAnimation("FlipBook")
        flipbookRepeat:SetChildKey("ProcLoop")
        flipbookRepeat:SetOrder(0)
        flipbookRepeat:SetFlipBookRows(6)
        flipbookRepeat:SetFlipBookColumns(5)
        flipbookRepeat:SetFlipBookFrames(30)
        flipbookRepeat:SetFlipBookFrameWidth(0)
        flipbookRepeat:SetFlipBookFrameHeight(0)
        f.ProcLoopAnim.flipbookRepeat = flipbookRepeat
    end
    if color then
        f.ProcLoop:SetDesaturated(1)
        f.ProcLoop:SetVertexColor(color[1], color[2], color[3], color[4])
    else
        f.ProcLoop:SetDesaturated(nil)
        f.ProcLoop:SetVertexColor(1, 1, 1, 1)
    end
    -- 自己播，跟像素／閃耀／螞蟻線同一套（2026-09-29 之前交給引擎的 AddAuraShownAnimation
    -- 播：引擎一 Stop，SetToFinalAlpha 把 alpha 留在 1、FlipBook 退回第一格 ⇒ 整張 5×6 圖集攤開
    -- 畫成一格格的小點）。REPEAT 動畫組自己播就不會被停；顯不顯示交給按鈕／f 的可見度。
    f._glowAnims, f._glowTimed = { f.ProcLoopAnim }, { f.ProcLoopAnim.flipbookRepeat, 1 }
    RetimeAnims(f, duration or 1)
    PlayAnims(f)
    return nil   -- 沒有東西要交給引擎
end

-- 宿主停放／取回：Attach 型沒有 driver 可退訂，停放的宿主底下動畫組照播（引擎在 C 端
-- 播，成本可忽略）。留成 no-op 是為了既有呼叫端；Start 系列從來不經過這兩支。
function lib.Glow_Suspend() end

function lib.Glow_Resume() end

-- 這顆 f 上所有會畫東西的貼圖（MaskTexture、裁切子框不算），給 caller 逐顆交給引擎控
-- 顯示（AuraButton:AddPandemicRegion 的退路；首選是整個 f 交出去）。只列已經建好的；
-- 在 Attach 之後呼叫。
function lib.Glow_Regions(f)
    local out = {}
    if not f then return out end
    if f.textures then
        for i = 1, #f.textures do out[#out + 1] = f.textures[i] end
    end
    if f.bg then out[#out + 1] = f.bg end
    if f.spark then out[#out + 1] = f.spark end
    if f.outerGlow then out[#out + 1] = f.outerGlow end
    if f.ants then out[#out + 1] = f.ants end
    if f.ProcLoop then out[#out + 1] = f.ProcLoop end
    return out
end

-- 這顆按鈕不再發光（設定改成 None 之後的重套）：自己播的動畫組停掉（Alpha 保持動畫
-- 播著時 alpha 寫不進去）、貼圖藏起來；框由 caller 管。交給引擎播的（入場閃光、Proc
-- 循環）不碰。_glowEngineShown 的框：顯示歸引擎，藏改寫 alpha（跟 outerGlow／ants／
-- ProcLoop 同法）。
function lib.Glow_Detach(f)
    if not f then return end
    StopAnims(f)
    local engine = f._glowEngineShown
    if f.textures then
        for _, t in pairs(f.textures) do
            if engine then t:SetAlpha(0) else t:Hide() end
        end
    end
    if f.bg then
        if engine then f.bg:SetAlpha(0) else f.bg:Hide() end
    end
    if f.outerGlow then f.outerGlow:SetAlpha(0) end
    if f.ants then f.ants:SetAlpha(0) end
    if f.ProcLoop then f.ProcLoop:SetAlpha(0) end
end
