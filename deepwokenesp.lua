--[[
    Deepwoken Matcha Visuals (NoFog / FullBright / NoFallDamage)
    Pure world & state manipulation. No ESP, zero drawing overhead.
    Strictly follows Matcha UI API and Luau standards.
]]

local old = rawget(_G, "__DW_MATCHA_VISUALS_PRODUCTION")
if old and old.Unload then pcall(old.Unload) end

assert(type(UI) == "table", "MatchaScripts UI binding is required")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

print("[Deep Visuals] Initializing production build (No ESP mode)...")

local STATE = {
    alive = true,
    connHeartbeat = nil,
    configCache = nil,
    lastConfigUpdate = 0,
    originalLighting = {},
    noFallEnabled = false,
}
_G.__DW_MATCHA_VISUALS_PRODUCTION = STATE

local EXEC_NAME, EXEC_VERSION = identifyexecutor()
local TAB_VIS = "Deep Visuals"

local function getValue(id, fallback)
    local ok, value = pcall(UI.GetValue, id)
    if not ok or value == nil then return fallback end
    return value
end

local function updateConfigCache()
    STATE.configCache = {
        noFog = getValue("deep_nofog", false),
        fullBright = getValue("deep_fullbright", false),
        noFall = getValue("deep_nofall", false),
    }
end

-- ==================== VISUALS LOGIC (NoFog, FullBright, NoFall) ====================
local function applyVisuals(cfg)
    -- NoFall Logic
    if cfg.noFall and not STATE.noFallEnabled then
        STATE.noFallEnabled = true
        STATE.connHeartbeat = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        hum:SetStateEnabled(Enum.HumanoidStateType.Falling, false)
                        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
                    end)
                end
            end
        end)
        print("[Deep Visuals] NoFall enabled.")
    elseif not cfg.noFall and STATE.noFallEnabled then
        STATE.noFallEnabled = false
        if STATE.connHeartbeat then
            STATE.connHeartbeat:Disconnect()
            STATE.connHeartbeat = nil
        end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.Falling, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
                end)
            end
        end
        print("[Deep Visuals] NoFall disabled.")
    end

    -- Lighting Logic
    if cfg.noFog or cfg.fullBright then
        if not STATE.originalLighting.saved then
            STATE.originalLighting.saved = true
            STATE.originalLighting.FogEnd = Lighting.FogEnd
            STATE.originalLighting.Brightness = Lighting.Brightness
            STATE.originalLighting.Ambient = Lighting.Ambient
            STATE.originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            STATE.originalLighting.ClockTime = Lighting.ClockTime
            STATE.originalLighting.GlobalShadows = Lighting.GlobalShadows
            
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then
                STATE.originalLighting.atmDensity = atm.Density
                STATE.originalLighting.atmHaze = atm.Haze
                STATE.originalLighting.atmGlare = atm.Glare
            end
        end
        
        pcall(function()
            if cfg.noFog then
                Lighting.FogEnd = 1e9
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm then
                    atm.Density = 0
                    atm.Haze = 0
                    atm.Glare = 0
                end
            end
            if cfg.fullBright then
                Lighting.Brightness = 2
                Lighting.Ambient = Color3.new(1, 1, 1)
                Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
            end
        end)
    else
        if STATE.originalLighting.saved then
            pcall(function()
                Lighting.FogEnd = STATE.originalLighting.FogEnd
                Lighting.Brightness = STATE.originalLighting.Brightness
                Lighting.Ambient = STATE.originalLighting.Ambient
                Lighting.OutdoorAmbient = STATE.originalLighting.OutdoorAmbient
                Lighting.ClockTime = STATE.originalLighting.ClockTime
                Lighting.GlobalShadows = STATE.originalLighting.GlobalShadows
                
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm and STATE.originalLighting.atmDensity then
                    atm.Density = STATE.originalLighting.atmDensity
                    atm.Haze = STATE.originalLighting.atmHaze
                    atm.Glare = STATE.originalLighting.atmGlare
                end
            end)
            STATE.originalLighting.saved = false
        end
    end
end

-- ==================== MATCHA UI ====================
pcall(function() UI.RemoveTab(TAB_VIS) end)

UI.AddTab(TAB_VIS, function(tab)
    local sec = tab:Section("World & Player", "Left", {"Visuals"}, 460)
    
    if sec.page == 0 then
        sec:Toggle("deep_nofog", "No Fog", false)
        sec:Toggle("deep_fullbright", "Full Bright", false)
        sec:Toggle("deep_nofall", "No Fall Damage", false)
        sec:Button("Unload Script", 160, 26, function()
            if STATE.Unload then STATE.Unload() end
        end)
    end
end)

-- ==================== UNLOAD ====================
function STATE.Unload()
    print("[Deep Visuals] Unloading...")
    STATE.alive = false
    if STATE.connHeartbeat then pcall(function() STATE.connHeartbeat:Disconnect() end) end
    
    -- Restore Lighting
    if STATE.originalLighting.saved then
        pcall(function()
            Lighting.FogEnd = STATE.originalLighting.FogEnd
            Lighting.Brightness = STATE.originalLighting.Brightness
            Lighting.Ambient = STATE.originalLighting.Ambient
            Lighting.OutdoorAmbient = STATE.originalLighting.OutdoorAmbient
            Lighting.ClockTime = STATE.originalLighting.ClockTime
            Lighting.GlobalShadows = STATE.originalLighting.GlobalShadows
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm and STATE.originalLighting.atmDensity then
                atm.Density = STATE.originalLighting.atmDensity
                atm.Haze = STATE.originalLighting.atmHaze
                atm.Glare = STATE.originalLighting.atmGlare
            end
        end)
    end
    
    -- Restore Humanoid States
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Falling, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            end)
        end
    end
    
    pcall(function() UI.RemoveTab(TAB_VIS) end)
    _G.__DW_MATCHA_VISUALS_PRODUCTION = nil
    print("[Deep Visuals] Unloaded successfully.")
end

-- ==================== MAIN LOOP ====================
RunService.RenderStepped:Connect(function()
    if not STATE.alive then return end
    
    local now = tick()
    if now - STATE.lastConfigUpdate > 0.5 then
        updateConfigCache()
        STATE.lastConfigUpdate = now
    end
    
    if STATE.configCache then
        applyVisuals(STATE.configCache)
    end
end)

updateConfigCache()
print(string.format("[Deep Visuals] Loaded. Executor: %s %s", EXEC_NAME, EXEC_VERSION))
notify("Deepwoken Visuals Loaded", TAB_VIS, 3)
