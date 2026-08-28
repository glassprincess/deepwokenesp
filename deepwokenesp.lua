--[[
    Deepwoken / Matcha External ESP (Optimized Production)
    High-performance, minimal-draw, mathematically perfect projection.
]]

local old = rawget(_G, "__DW_MATCHA_ESP_OPTIMIZED")
if old and old.Unload then pcall(old.Unload) end

assert(type(UI) == "table", "MatchaScripts UI binding is required")
assert(Drawing ~= nil, "Matcha Drawing API is required")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[Deep ESP] Initializing optimized build...")

local STATE = {
    alive = true,
    conn = nil,
    slots = {},
    configCache = nil,
    lastConfigUpdate = 0,
}
_G.__DW_MATCHA_ESP_OPTIMIZED = STATE

local EXEC_NAME, EXEC_VERSION = identifyexecutor()
local TAB_MAIN = "Deep ESP"
local TAB_CFG  = "Deep Theme"

-- Minimal theme for performance
local Theme = {
    accent = Color3.fromRGB(142, 188, 214),
    glass = Color3.fromRGB(12, 16, 24),
    text = Color3.fromRGB(235, 241, 247),
    subtext = Color3.fromRGB(164, 178, 193),
    hpHigh = Color3.fromRGB(116, 225, 165),
    hpMid = Color3.fromRGB(232, 188, 108),
    hpLow = Color3.fromRGB(224, 100, 100),
    posture = Color3.fromRGB(124, 221, 235),
    tracer = Color3.fromRGB(112, 162, 205),
}

local function getValue(id, fallback)
    local ok, value = pcall(UI.GetValue, id)
    if not ok or value == nil then return fallback end
    return value
end

local function setValue(id, value)
    pcall(UI.SetValue, id, value)
end

local function updateConfigCache()
    STATE.configCache = {
        enabled = getValue("deep_enabled", true),
        maxDist = getValue("deep_max_dist", 4000),
        showBox = getValue("deep_show_box", true),
        showName = getValue("deep_show_name", true),
        showStats = getValue("deep_show_stats", true),
        showBars = getValue("deep_show_bars", true),
        showTracer = getValue("deep_show_tracer", true),
    }
end

-- ==================== MATH & PROJECTION ====================
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpColor(c1, c2, t)
    return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

local function projectToScreen(worldPos, camCFrame, fov, viewport)
    local rel = camCFrame:PointToObjectSpace(worldPos)
    if rel.Z >= 0 then return nil, false end -- Behind camera
    
    local yScale = math.tan(math.rad(fov / 2))
    local xScale = yScale * (viewport.X / viewport.Y)
    
    local x = (rel.X / -rel.Z) / xScale
    local y = (rel.Y / -rel.Z) / yScale
    
    return Vector2.new(
        (1 + x) * 0.5 * viewport.X, 
        (1 - y) * 0.5 * viewport.Y
    ), true
end

local function getHealthColor(ratio)
    if ratio >= 0.5 then
        return lerpColor(Theme.hpMid, Theme.hpHigh, (ratio - 0.5) / 0.5)
    end
    return lerpColor(Theme.hpLow, Theme.hpMid, ratio / 0.5)
end

-- ==================== MINIMAL DRAWING SLOT ====================
local function createSlot()
    local s = {}
    
    -- Box (1 background, 1 outline)
    s.boxBg = Drawing.new("Square")
    s.boxBg.Filled = true
    s.boxBg.Color = Theme.glass
    s.boxBg.Transparency = 0.4
    s.boxBg.Visible = false
    
    s.boxOutline = Drawing.new("Square")
    s.boxOutline.Filled = false
    s.boxOutline.Color = Theme.accent
    s.boxOutline.Thickness = 1
    s.boxOutline.Transparency = 1
    s.boxOutline.Visible = false
    
    -- Bars (2 backgrounds, 2 fills)
    s.hpBg = Drawing.new("Square")
    s.hpBg.Filled = true
    s.hpBg.Color = Color3.new(0, 0, 0)
    s.hpBg.Transparency = 0.6
    s.hpBg.Visible = false
    
    s.hpFill = Drawing.new("Square")
    s.hpFill.Filled = true
    s.hpFill.Visible = false
    
    s.poBg = Drawing.new("Square")
    s.poBg.Filled = true
    s.poBg.Color = Color3.new(0, 0, 0)
    s.poBg.Transparency = 0.6
    s.poBg.Visible = false
    
    s.poFill = Drawing.new("Square")
    s.poFill.Filled = true
    s.poFill.Visible = false
    
    -- Text (1 name, 1 stats) - using Outline instead of separate shadow objects
    s.nameText = Drawing.new("Text")
    s.nameText.Center = true
    s.nameText.Outline = true
    s.nameText.Size = 14
    s.nameText.Font = 1 -- System
    s.nameText.Visible = false
    
    s.statText = Drawing.new("Text")
    s.statText.Center = true
    s.statText.Outline = true
    s.statText.Size = 12
    s.statText.Font = 2 -- Monospace
    s.statText.Visible = false
    
    -- Tracer
    s.tracer = Drawing.new("Line")
    s.tracer.Thickness = 1
    s.tracer.Transparency = 0.7
    s.tracer.Visible = false
    
    return s
end

local function hideSlot(s)
    if not s then return end
    s.boxBg.Visible = false
    s.boxOutline.Visible = false
    s.hpBg.Visible = false
    s.hpFill.Visible = false
    s.poBg.Visible = false
    s.poFill.Visible = false
    s.nameText.Visible = false
    s.statText.Visible = false
    s.tracer.Visible = false
end

local function destroySlot(s)
    if not s then return end
    pcall(function() s.boxBg:Remove() end)
    pcall(function() s.boxOutline:Remove() end)
    pcall(function() s.hpBg:Remove() end)
    pcall(function() s.hpFill:Remove() end)
    pcall(function() s.poBg:Remove() end)
    pcall(function() s.poFill:Remove() end)
    pcall(function() s.nameText:Remove() end)
    pcall(function() s.statText:Remove() end)
    pcall(function() s.tracer:Remove() end)
end

-- ==================== DATA EXTRACTION ====================
local function getStat(char, ply, name, fallback)
    local v = char:GetAttribute(name) or (ply and ply:GetAttribute(name))
    if v then return v end
    local obj = char:FindFirstChild(name)
    if obj and obj:IsA("NumberValue") then return obj.Value end
    return fallback
end

local function extractData(ply)
    local char = ply.Character
    if not char then return nil end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not root or not head then return nil end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local dist = localRoot and (localRoot.Position - root.Position).Magnitude or 0

    local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
    local maxPo = getStat(char, ply, "MaxPosture", 100)
    local po = getStat(char, ply, "Posture", 0)
    
    local level = ply:GetAttribute("Level") or 0
    if level == 0 then
        local ls = ply:FindFirstChild("leaderstats")
        if ls then
            local l = ls:FindFirstChild("Level") or ls:FindFirstChild("Power")
            if l then level = tonumber(l.Value) or 0 end
        end
    end

    return {
        headPos = head.Position,
        rootPos = root.Position,
        dist = dist,
        hpRatio = hum.Health / maxHp,
        hpCur = math.floor(hum.Health),
        hpMax = math.floor(maxHp),
        poRatio = maxPo > 0 and (po / maxPo) or 0,
        poCur = math.floor(po),
        level = level,
        name = hum.DisplayName ~= "" and hum.DisplayName or ply.Name,
    }
end

-- ==================== RENDER LOGIC ====================
local function renderPlayer(slot, data, cfg, camCFrame, camFov, viewport)
    local headPos = data.headPos
    local feetPos = data.rootPos - Vector3.new(0, 3, 0)
    
    local headScreen, headOn = projectToScreen(headPos, camCFrame, camFov, viewport)
    local feetScreen, feetOn = projectToScreen(feetPos, camCFrame, camFov, viewport)
    
    if not headOn or not feetOn then
        hideSlot(slot)
        return
    end
    
    local boxH = math.abs(feetScreen.Y - headScreen.Y)
    local boxW = boxH * 0.42
    if boxH < 10 or boxW < 5 then
        hideSlot(slot)
        return
    end
    
    local x1 = headScreen.X - boxW / 2
    local x2 = headScreen.X + boxW / 2
    local y1 = headScreen.Y
    local y2 = headScreen.Y + boxH
    
    local hpColor = getHealthColor(data.hpRatio)
    local poColor = Theme.posture
    
    -- Box
    if cfg.showBox then
        slot.boxBg.Position = Vector2.new(x1, y1)
        slot.boxBg.Size = Vector2.new(boxW, boxH)
        slot.boxBg.Visible = true
        
        slot.boxOutline.Position = Vector2.new(x1, y1)
        slot.boxOutline.Size = Vector2.new(boxW, boxH)
        slot.boxOutline.Visible = true
    else
        slot.boxBg.Visible = false
        slot.boxOutline.Visible = false
    end
    
    -- Bars
    if cfg.showBars then
        local barW = 2.5
        local gap = 4
        
        -- HP (Left)
        slot.hpBg.Position = Vector2.new(x1 - gap - barW, y1)
        slot.hpBg.Size = Vector2.new(barW, boxH)
        slot.hpBg.Visible = true
        
        local hpH = math.floor(boxH * data.hpRatio)
        slot.hpFill.Position = Vector2.new(x1 - gap - barW, y2 - hpH)
        slot.hpFill.Size = Vector2.new(barW, hpH)
        slot.hpFill.Color = hpColor
        slot.hpFill.Visible = true
        
        -- Posture (Right)
        slot.poBg.Position = Vector2.new(x2 + gap, y1)
        slot.poBg.Size = Vector2.new(barW, boxH)
        slot.poBg.Visible = true
        
        local poH = math.floor(boxH * data.poRatio)
        slot.poFill.Position = Vector2.new(x2 + gap, y2 - poH)
        slot.poFill.Size = Vector2.new(barW, poH)
        slot.poFill.Color = poColor
        slot.poFill.Visible = true
    else
        slot.hpBg.Visible = false
        slot.hpFill.Visible = false
        slot.poBg.Visible = false
        slot.poFill.Visible = false
    end
    
    -- Text
    if cfg.showName then
        slot.nameText.Text = data.name
        slot.nameText.Position = Vector2.new(x1 + boxW / 2, y1 - 18)
        slot.nameText.Color = Theme.text
        slot.nameText.Visible = true
    else
        slot.nameText.Visible = false
    end
    
    if cfg.showStats then
        local statStr = string.format("HP %d/%d · PO %d · %dst", data.hpCur, data.hpMax, data.poCur, math.floor(data.dist))
        if data.level > 0 then
            statStr = string.format("LVL %d · %s", data.level, statStr)
        end
        slot.statText.Text = statStr
        slot.statText.Position = Vector2.new(x1 + boxW / 2, y2 + 4)
        slot.statText.Color = Theme.subtext
        slot.statText.Visible = true
    else
        slot.statText.Visible = false
    end
    
    -- Tracer
    if cfg.showTracer then
        slot.tracer.From = Vector2.new(viewport.X / 2, viewport.Y / 2)
        slot.tracer.To = Vector2.new(x1 + boxW / 2, y2)
        slot.tracer.Color = Theme.tracer
        slot.tracer.Visible = true
    else
        slot.tracer.Visible = false
    end
end

-- ==================== MATCHA UI ====================
pcall(function() UI.RemoveTab(TAB_MAIN) end)
pcall(function() UI.RemoveTab(TAB_CFG) end)

UI.AddTab(TAB_MAIN, function(tab)
    local sec = tab:Section("Overlay", "Left", {"General", "Elements"}, 460)
    
    if sec.page == 0 then
        sec:Toggle("deep_enabled", "Enable ESP", true)
        sec:SliderInt("deep_max_dist", "Max Distance", 100, 6000, 4000)
        sec:Button("Notify Loaded", 160, 26, function()
            notify("Deepwoken ESP optimized is running", TAB_MAIN, 3)
        end)
        sec:Button("Unload ESP", 160, 26, function()
            if STATE.Unload then STATE.Unload() end
        end)
    elseif sec.page == 1 then
        sec:Toggle("deep_show_box", "Show Box", true)
        sec:Toggle("deep_show_name", "Show Name", true)
        sec:Toggle("deep_show_stats", "Show Stats Text", true)
        sec:Toggle("deep_show_bars", "Show HP/Posture Bars", true)
        sec:Toggle("deep_show_tracer", "Show Tracers", true)
    end
end)

UI.AddTab(TAB_CFG, function(tab)
    local sec = tab:Section("Colors", "Left", {"Main", "Stats"}, 460)
    
    if sec.page == 0 then
        sec:ColorPicker("deep_color_accent", Theme.accent.R * 255, Theme.accent.G * 255, Theme.accent.B * 255, 255, function(c)
            Theme.accent = c
        end)
        sec:ColorPicker("deep_color_glass", Theme.glass.R * 255, Theme.glass.G * 255, Theme.glass.B * 255, 100, function(c)
            Theme.glass = c
        end)
        sec:ColorPicker("deep_color_text", Theme.text.R * 255, Theme.text.G * 255, Theme.text.B * 255, 255, function(c)
            Theme.text = c
        end)
    elseif sec.page == 1 then
        sec:ColorPicker("deep_color_hp", Theme.hpHigh.R * 255, Theme.hpHigh.G * 255, Theme.hpHigh.B * 255, 255, function(c)
            Theme.hpHigh = c
        end)
        sec:ColorPicker("deep_color_po", Theme.posture.R * 255, Theme.posture.G * 255, Theme.posture.B * 255, 255, function(c)
            Theme.posture = c
        end)
        sec:ColorPicker("deep_color_tracer", Theme.tracer.R * 255, Theme.tracer.G * 255, Theme.tracer.B * 255, 180, function(c)
            Theme.tracer = c
        end)
    end
end)

-- ==================== UNLOAD ====================
function STATE.Unload()
    print("[Deep ESP] Unloading...")
    STATE.alive = false
    if STATE.conn then
        pcall(function() STATE.conn:Disconnect() end)
        STATE.conn = nil
    end
    for _, s in pairs(STATE.slots) do
        destroySlot(s)
    end
    STATE.slots = {}
    pcall(function() UI.RemoveTab(TAB_MAIN) end)
    pcall(function() UI.RemoveTab(TAB_CFG) end)
    _G.__DW_MATCHA_ESP_OPTIMIZED = nil
    print("[Deep ESP] Unloaded successfully.")
end

-- ==================== MAIN LOOP ====================
STATE.conn = RunService.RenderStepped:Connect(function()
    if not STATE.alive then return end
    
    local now = tick()
    if now - STATE.lastConfigUpdate > 0.5 then
        updateConfigCache()
        STATE.lastConfigUpdate = now
    end
    
    local cfg = STATE.configCache
    if not cfg or not cfg.enabled then
        for _, s in pairs(STATE.slots) do hideSlot(s) end
        return
    end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local camCFrame = cam.CFrame
    local camFov = cam.FieldOfView
    local viewport = cam.ViewportSize
    
    local players = Players:GetPlayers()
    local activeSlots = 0
    
    for _, ply in ipairs(players) do
        if ply ~= LocalPlayer then
            local data = extractData(ply)
            if data and data.dist <= cfg.maxDist then
                activeSlots = activeSlots + 1
                if not STATE.slots[activeSlots] then
                    STATE.slots[activeSlots] = createSlot()
                end
                renderPlayer(STATE.slots[activeSlots], data, cfg, camCFrame, camFov, viewport)
            end
        end
    end
    
    -- Hide unused slots
    for i = activeSlots + 1, #STATE.slots do
        if STATE.slots[i] then hideSlot(STATE.slots[i]) end
    end
end)

updateConfigCache()
print(string.format("[Deep ESP] Loaded. Executor: %s %s", EXEC_NAME, EXEC_VERSION))
print("[Deep ESP] Render loop attached. Waiting for players...")
notify("Deepwoken ESP Loaded", TAB_MAIN, 3)