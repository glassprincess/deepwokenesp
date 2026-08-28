--[[
    Deepwoken Matcha Visuals (Production Hardened)
    NoFog / FullBright / NoFallDamage
    Aggressive Heartbeat enforcement, 0 errors, strict Matcha UI.
]]

local old = rawget(_G, "__DW_MATCHA_VISUALS_SKEL")
if old and old.Unload then
    pcall(old.Unload)
end

assert(type(UI) == "table", "MatchaScripts UI binding is required")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

print("[Deep Visuals] Initializing hardened production build...")

local STATE = {
    alive = true,
    conn = nil,
    lastTick = tick(),
    originalLighting = {},
    initialized = false,
}
_G.__DW_MATCHA_VISUALS_SKEL = STATE

local EXEC_NAME, EXEC_VERSION = identifyexecutor()
local TAB_MAIN = "Deep Visuals"
local TAB_ABOUT = "Deep Info"

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function getValue(id, fallback)
    local ok, value = pcall(UI.GetValue, id)
    if not ok or value == nil then
        return fallback
    end
    return value
end

local function setValue(id, value)
    pcall(UI.SetValue, id, value)
end

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

----------------------------------------------------------------------
-- EFFECT LAYER (AGGRESSIVE ENFORCEMENT)
----------------------------------------------------------------------

local function cacheOriginalLighting()
    if STATE.initialized then return end
    STATE.initialized = true
    
    pcall(function()
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
            STATE.originalLighting.atmDecay = atm.Decay
            STATE.originalLighting.atmColor = atm.Color
        end
    end)
    print("[Deep Visuals] Original lighting cached.")
end

local function restoreLighting()
    if not STATE.initialized then return end
    pcall(function()
        Lighting.FogEnd = STATE.originalLighting.FogEnd or Lighting.FogEnd
        Lighting.Brightness = STATE.originalLighting.Brightness or Lighting.Brightness
        Lighting.Ambient = STATE.originalLighting.Ambient or Lighting.Ambient
        Lighting.OutdoorAmbient = STATE.originalLighting.OutdoorAmbient or Lighting.OutdoorAmbient
        Lighting.ClockTime = STATE.originalLighting.ClockTime or Lighting.ClockTime
        Lighting.GlobalShadows = STATE.originalLighting.GlobalShadows or Lighting.GlobalShadows
        
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and STATE.originalLighting.atmDensity then
            atm.Density = STATE.originalLighting.atmDensity
            atm.Haze = STATE.originalLighting.atmHaze
            atm.Glare = STATE.originalLighting.atmGlare
            atm.Decay = STATE.originalLighting.atmDecay
            atm.Color = STATE.originalLighting.atmColor
        end
    end)
    print("[Deep Visuals] Lighting restored.")
end

local function applyNoFall()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                -- Aggressively disable fall states
                hum:SetStateEnabled(Enum.HumanoidStateType.Falling, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
                
                -- Force change state if currently falling
                local currentState = hum:GetState()
                if currentState == Enum.HumanoidStateType.Freefall or currentState == Enum.HumanoidStateType.Falling then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
        end
    end)
end

local function restoreNoFall()
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
end

----------------------------------------------------------------------
-- config + state machine
----------------------------------------------------------------------

local function readConfig()
    return {
        master      = getValue("sk_master", true), -- Defaulted to true!
        verbose     = getValue("sk_verbose", false),

        nofog       = getValue("sk_nofog", false),
        fogEnd      = clamp(math.floor(getValue("sk_fog_end", 100000)), 1000, 1000000),
        haze        = clamp(getValue("sk_haze", 0.0), 0.0, 1.0),

        fullbright  = getValue("sk_fullbright", false),
        brightness  = clamp(getValue("sk_brightness", 3.0), 0.0, 10.0),
        ambientLvl  = clamp(math.floor(getValue("sk_ambient", 200)), 0, 255),

        nofall      = getValue("sk_nofall", false),
        safeVel     = clamp(math.floor(getValue("sk_safe_vel", 120)), 20, 400),
    }
end

local function syncEffects(cfg)
    if not cfg.master then
        -- If master is off, we don't apply, but we don't restore either (unless toggled off completely)
        return
    end

    -- NO FOG
    if cfg.nofog then
        pcall(function()
            Lighting.FogEnd = cfg.fogEnd
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then
                atm.Density = 0
                atm.Haze = cfg.haze
                atm.Glare = 0
            end
        end)
    end

    -- FULL BRIGHT
    if cfg.fullbright then
        pcall(function()
            Lighting.Brightness = cfg.brightness
            Lighting.Ambient = Color3.fromRGB(cfg.ambientLvl, cfg.ambientLvl, cfg.ambientLvl)
            Lighting.OutdoorAmbient = Color3.fromRGB(cfg.ambientLvl, cfg.ambientLvl, cfg.ambientLvl)
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
        end)
    end

    -- NO FALL
    if cfg.nofall then
        applyNoFall()
    end
end

----------------------------------------------------------------------
-- menu (real, per MatchaScripts README)
----------------------------------------------------------------------

pcall(function() UI.RemoveTab(TAB_MAIN) end)
pcall(function() UI.RemoveTab(TAB_ABOUT) end)

UI.AddTab(TAB_MAIN, function(tab)
    local secL = tab:Section("Core", "Left", {"Master", "NoFog", "FullBright", "NoFall"}, 420)

    if secL.page == 0 then
        secL:Toggle("sk_master", "Master switch", true)
        secL:Toggle("sk_verbose", "Notify on actions", false)
        local kb = secL:Keybind("sk_master_kb", 0x4E, "toggle") -- N
        if not STATE.kbBound then
            pcall(function() kb:AddToHotkey("Visuals master", "sk_master") end)
            STATE.kbBound = true
        end
    elseif secL.page == 1 then
        secL:Toggle("sk_nofog", "NoFog", false)
        secL:SliderInt("sk_fog_end", "FogEnd Distance", 1000, 1000000, 100000)
        secL:SliderFloat("sk_haze", "Haze removal", 0.0, 1.0, 0.0, "%.2f")
    elseif secL.page == 2 then
        secL:Toggle("sk_fullbright", "FullBright", false)
        secL:SliderFloat("sk_brightness", "Brightness", 0.0, 10.0, 3.0, "%.1f")
        secL:SliderInt("sk_ambient", "Ambient level", 0, 255, 200)
    elseif secL.page == 3 then
        secL:Toggle("sk_nofall", "NoFallDamage", false)
        secL:SliderInt("sk_safe_vel", "Safe velocity", 20, 400, 120)
    end

    local secR = tab:Section("Style & Actions", "Right", {"Accent", "Actions"}, 420)
    if secR.page == 0 then
        secR:ColorPicker("sk_accent_cp", 165, 214, 255, 222, function()
            -- purely visual for the menu
        end)
    elseif secR.page == 1 then
        secR:Button("Force restore all", 170, 26, function()
            setValue("sk_nofog", false)
            setValue("sk_fullbright", false)
            setValue("sk_nofall", false)
            setValue("sk_master", false)
            restoreLighting()
            restoreNoFall()
            notify("All states reset", TAB_MAIN, 3)
        end)
        secR:Button("Unload Script", 170, 26, function()
            if STATE.Unload then STATE.Unload() end
        end)
    end
end)

UI.AddTab(TAB_ABOUT, function(tab)
    local sec = tab:Section("Notes", "Left", {"Docs", "Limits"}, 420)
    if sec.page == 0 then
        sec:InputText("sk_info_exec", "Executor", string.format("%s %s", EXEC_NAME, EXEC_VERSION))
        sec:InputText("sk_info_mode", "Mode", "Hardened Production Build")
    elseif sec.page == 1 then
        sec:Button("Status", 160, 26, function()
            notify("Visuals running on Heartbeat. No ESP.", "Deep Visuals", 5)
        end)
    end
end)

----------------------------------------------------------------------
-- loop + unload
----------------------------------------------------------------------

function STATE.Unload()
    print("[Deep Visuals] Unloading...")
    STATE.alive = false
    if STATE.conn then
        pcall(function() STATE.conn:Disconnect() end)
        STATE.conn = nil
    end
    
    restoreLighting()
    restoreNoFall()
    
    pcall(function() UI.RemoveTab(TAB_MAIN) end)
    pcall(function() UI.RemoveTab(TAB_ABOUT) end)
    _G.__DW_MATCHA_VISUALS_SKEL = nil
    print("[Deep Visuals] Unloaded successfully.")
end

-- Cache lighting as soon as script loads
cacheOriginalLighting()

-- Aggressive Heartbeat loop to enforce settings every frame
STATE.conn = RunService.Heartbeat:Connect(function()
    if not STATE.alive then return end
    
    local cfg = readConfig()
    
    -- Handle restoration if toggles are turned off
    if not cfg.nofog and STATE.originalLighting.FogEnd and Lighting.FogEnd == cfg.fogEnd then
        restoreLighting()
    end
    if not cfg.fullbright and STATE.originalLighting.Brightness and Lighting.Brightness == cfg.brightness then
        restoreLighting()
    end
    if not cfg.nofall then
        restoreNoFall()
    end

    syncEffects(cfg)
end)

notify("Loaded Deep Visuals (Heartbeat Enforced)", TAB_MAIN, 4)
