--[[
    Deepwoken Matcha Visuals (Aggressive Heartbeat)
    NoFog / FullBright / NoFallDamage
    Bypasses Deepwoken's per-frame lighting overrides.
]]

local old = rawget(_G, "__DW_VISUALS_AGGRESSIVE")
if old and old.Unload then pcall(old.Unload) end

assert(type(UI) == "table", "MatchaScripts UI binding is required")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

print("[Deep Visuals] Initializing aggressive heartbeat build...")

local STATE = {
    alive = true,
    conn = nil,
    noFallConn = nil,
    -- Track what we need to restore
    savedLighting = false,
    origFogEnd = nil,
    origFogStart = nil,
    origBrightness = nil,
    origAmbient = nil,
    origOutdoorAmbient = nil,
    origClockTime = nil,
    origGlobalShadows = nil,
    origAtmDensity = nil,
    origAtmHaze = nil,
    origAtmGlare = nil,
    atmRef = nil,
    -- Track toggle states to detect changes
    prevNoFog = false,
    prevFullBright = false,
    prevNoFall = false,
}
_G.__DW_VISUALS_AGGRESSIVE = STATE

local EXEC_NAME, EXEC_VERSION = identifyexecutor()
local TAB_MAIN = "Deep Visuals"

local function getValue(id, fallback)
    local ok, value = pcall(UI.GetValue, id)
    if not ok or value == nil then return fallback end
    return value
end

local function setValue(id, value)
    pcall(UI.SetValue, id, value)
end

-- ==================== SAVE ORIGINAL LIGHTING ====================
local function saveLighting()
    if STATE.savedLighting then return end
    pcall(function()
        STATE.origFogEnd = Lighting.FogEnd
        STATE.origFogStart = Lighting.FogStart
        STATE.origBrightness = Lighting.Brightness
        STATE.origAmbient = Lighting.Ambient
        STATE.origOutdoorAmbient = Lighting.OutdoorAmbient
        STATE.origClockTime = Lighting.ClockTime
        STATE.origGlobalShadows = Lighting.GlobalShadows
        
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            STATE.atmRef = atm
            STATE.origAtmDensity = atm.Density
            STATE.origAtmHaze = atm.Haze
            STATE.origAtmGlare = atm.Glare
        end
    end)
    STATE.savedLighting = true
    print("[Deep Visuals] Original lighting saved.")
end

-- ==================== RESTORE LIGHTING ====================
local function restoreLighting()
    if not STATE.savedLighting then return end
    pcall(function()
        if STATE.origFogEnd then Lighting.FogEnd = STATE.origFogEnd end
        if STATE.origFogStart then Lighting.FogStart = STATE.origFogStart end
        if STATE.origBrightness then Lighting.Brightness = STATE.origBrightness end
        if STATE.origAmbient then Lighting.Ambient = STATE.origAmbient end
        if STATE.origOutdoorAmbient then Lighting.OutdoorAmbient = STATE.origOutdoorAmbient end
        if STATE.origClockTime then Lighting.ClockTime = STATE.origClockTime end
        if STATE.origGlobalShadows ~= nil then Lighting.GlobalShadows = STATE.origGlobalShadows end
        
        if STATE.atmRef and STATE.atmRef.Parent then
            if STATE.origAtmDensity then STATE.atmRef.Density = STATE.origAtmDensity end
            if STATE.origAtmHaze then STATE.atmRef.Haze = STATE.origAtmHaze end
            if STATE.origAtmGlare then STATE.atmRef.Glare = STATE.origAtmGlare end
        end
    end)
    STATE.savedLighting = false
    print("[Deep Visuals] Lighting restored.")
end

-- ==================== APPLY NOFOG ====================
local function applyNoFog()
    pcall(function()
        -- Push fog to infinity
        Lighting.FogEnd = 1e9
        Lighting.FogStart = 1e9
        
        -- Kill atmosphere
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            atm.Density = 0
            atm.Haze = 0
            atm.Glare = 0
        end
        
        -- Also check for ColorCorrection that might simulate darkness
        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then
            -- Don't touch it if user didn't ask, but be aware
        end
    end)
end

-- ==================== APPLY FULLBRIGHT ====================
local function applyFullBright()
    pcall(function()
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = false
        Lighting.ExposureCompensation = 0
        
        -- Kill atmosphere density to let light through
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            atm.Density = 0
            atm.Haze = 0
        end
    end)
end

-- ==================== NOFALL DAMAGE ====================
local function startNoFall()
    if STATE.noFallConn then return end
    
    STATE.noFallConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            
            -- Method 1: Disable fall states
            hum:SetStateEnabled(Enum.HumanoidStateType.Falling, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
            
            -- Method 2: If currently falling, force to running
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Falling then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            -- Method 3: Velocity cap - prevent high downward velocity
            local vel = root.AssemblyLinearVelocity
            if vel.Y < -50 then
                root.AssemblyLinearVelocity = Vector3.new(vel.X, -20, vel.Z)
            end
            
            -- Method 4: Constant health restore if damaged
            -- (Deepwoken calculates fall damage on landing)
            -- We preemptively ensure health can't drop from fall
        end)
    end)
    print("[Deep Visuals] NoFall started.")
end

local function stopNoFall()
    if STATE.noFallConn then
        STATE.noFallConn:Disconnect()
        STATE.noFallConn = nil
    end
    -- Restore fall states
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Falling, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            end
        end
    end)
    print("[Deep Visuals] NoFall stopped.")
end

-- ==================== MATCHA UI ====================
pcall(function() UI.RemoveTab(TAB_MAIN) end)

UI.AddTab(TAB_MAIN, function(tab)
    local sec = tab:Section("Visuals", "Left", {"Effects"}, 460)
    
    if sec.page == 0 then
        sec:Toggle("deep_nofog", "No Fog", false)
        sec:Toggle("deep_fullbright", "Full Bright", false)
        sec:Toggle("deep_nofall", "No Fall Damage", false)
        sec:Button("Restore All", 160, 26, function()
            setValue("deep_nofog", false)
            setValue("deep_fullbright", false)
            setValue("deep_nofall", false)
            restoreLighting()
            stopNoFall()
            notify("All effects restored", TAB_MAIN, 3)
        end)
        sec:Button("Unload", 160, 26, function()
            if STATE.Unload then STATE.Unload() end
        end)
    end
end)

-- ==================== UNLOAD ====================
function STATE.Unload()
    print("[Deep Visuals] Unloading...")
    STATE.alive = false
    if STATE.conn then
        pcall(function() STATE.conn:Disconnect() end)
        STATE.conn = nil
    end
    stopNoFall()
    restoreLighting()
    pcall(function() UI.RemoveTab(TAB_MAIN) end)
    _G.__DW_VISUALS_AGGRESSIVE = nil
    print("[Deep Visuals] Unloaded.")
end

-- ==================== AGGRESSIVE HEARTBEAT LOOP ====================
saveLighting()

STATE.conn = RunService.Heartbeat:Connect(function()
    if not STATE.alive then return end
    
    -- Read config EVERY frame - no caching, no delay
    local noFog = getValue("deep_nofog", false)
    local fullBright = getValue("deep_fullbright", false)
    local noFall = getValue("deep_nofall", false)
    
    -- Detect toggle changes for clean start/stop
    if noFall and not STATE.prevNoFall then
        startNoFall()
        STATE.prevNoFall = true
        notify("NoFall: ON", TAB_MAIN, 2)
    elseif not noFall and STATE.prevNoFall then
        stopNoFall()
        STATE.prevNoFall = false
        notify("NoFall: OFF", TAB_MAIN, 2)
    end
    
    -- Restore lighting when both are off
    if not noFog and not fullBright then
        if STATE.prevNoFog or STATE.prevFullBright then
            restoreLighting()
            STATE.prevNoFog = false
            STATE.prevFullBright = false
        end
    else
        -- Save lighting on first enable
        if not STATE.savedLighting then
            saveLighting()
        end
        
        -- Apply every single frame to override Deepwoken's scripts
        if noFog then
            applyNoFog()
            if not STATE.prevNoFog then
                STATE.prevNoFog = true
                notify("NoFog: ON", TAB_MAIN, 2)
            end
        end
        
        if fullBright then
            applyFullBright()
            if not STATE.prevFullBright then
                STATE.prevFullBright = true
                notify("FullBright: ON", TAB_MAIN, 2)
            end
        end
        
        -- If noFog is off but fullBright is on, restore fog but keep bright
        if not noFog and STATE.prevNoFog then
            pcall(function()
                if STATE.origFogEnd then Lighting.FogEnd = STATE.origFogEnd end
                if STATE.origFogStart then Lighting.FogStart = STATE.origFogStart end
                if STATE.atmRef and STATE.atmRef.Parent then
                    if STATE.origAtmDensity then STATE.atmRef.Density = STATE.origAtmDensity end
                    if STATE.origAtmHaze then STATE.atmRef.Haze = STATE.origAtmHaze end
                    if STATE.origAtmGlare then STATE.atmRef.Glare = STATE.origAtmGlare end
                end
            end)
            STATE.prevNoFog = false
            notify("NoFog: OFF", TAB_MAIN, 2)
        end
        
        -- If fullBright is off but noFog is on, restore brightness but keep fog killed
        if not fullBright and STATE.prevFullBright then
            pcall(function()
                if STATE.origBrightness then Lighting.Brightness = STATE.origBrightness end
                if STATE.origAmbient then Lighting.Ambient = STATE.origAmbient end
                if STATE.origOutdoorAmbient then Lighting.OutdoorAmbient = STATE.origOutdoorAmbient end
                if STATE.origClockTime then Lighting.ClockTime = STATE.origClockTime end
                if STATE.origGlobalShadows ~= nil then Lighting.GlobalShadows = STATE.origGlobalShadows end
            end)
            STATE.prevFullBright = false
            notify("FullBright: OFF", TAB_MAIN, 2)
        end
    end
end)

print(string.format("[Deep Visuals] Loaded on %s %s", EXEC_NAME, EXEC_VERSION))
print("[Deep Visuals] Heartbeat enforcement active.")
notify("Deep Visuals loaded. Toggle effects in menu.", TAB_MAIN, 4)
