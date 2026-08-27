--[[
    SPECTRE — Deepwoken ESP | Matcha Integration
    Конфиг система, UI через Matcha, Liquid Glass aesthetic.
]]

-- ============================================================
--  SERVICES & UTILS
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function clamp(val, min, max) return math.max(min, math.min(max, val)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpColor(c1, c2, t)
    return Color3.fromRGB(
        clamp(lerp(c1.R * 255, c2.R * 255, t), 0, 255),
        clamp(lerp(c1.G * 255, c2.G * 255, t), 0, 255),
        clamp(lerp(c1.B * 255, c2.B * 255, t), 0, 255)
    )
end

-- ============================================================
--  CONFIG SYSTEM
-- ============================================================

local Config = {
    Enabled = true,
    MaxDistance = 4000,
    
    ShowBox = true,
    BoxStyle = "Corner", -- "Corner" or "Full"
    ShowName = true,
    ShowLevel = true,
    ShowHP = true,
    ShowHPBar = true,
    ShowPosture = true,
    ShowPostureBar = true,
    ShowFood = true,
    ShowWater = true,
    ShowTempo = true,
    ShowDistance = true,
    
    -- Colors (Matcha Liquid Glass)
    MatchaAccent = Color3.fromRGB(118, 161, 75),
    MatchaLight = Color3.fromRGB(150, 190, 100),
    
    HPColor = Color3.fromRGB(80, 220, 100),
    HPLowColor = Color3.fromRGB(220, 60, 60),
    HPMidColor = Color3.fromRGB(220, 200, 60),
    
    PostureColor = Color3.fromRGB(160, 110, 230),
    PostureLowColor = Color3.fromRGB(200, 80, 200),
    
    FoodColor = Color3.fromRGB(255, 180, 80),
    WaterColor = Color3.fromRGB(80, 180, 255),
    TempoColor = Color3.fromRGB(220, 220, 240),
    
    LevelColor = Color3.fromRGB(255, 215, 100),
    NameColor = Color3.fromRGB(240, 240, 245),
    DistanceColor = Color3.fromRGB(160, 160, 170),
    
    BoxBg = Color3.fromRGB(12, 14, 18),
    BoxBorder = Color3.fromRGB(50, 55, 65),
    BarBg = Color3.fromRGB(20, 22, 28),
    ShadowColor = Color3.fromRGB(0, 0, 0),
    
    BoxBgOpacity = 0.35,
    BoxBorderOpacity = 0.5,
    BarBgOpacity = 0.4,
    TextOpacity = 1.0,
    ShadowOpacity = 0.5,
}

local ConfigFile = "SpectreDeepwokenConfig.json"

local function SaveConfig()
    local safeConfig = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then
            safeConfig[k] = {v.R, v.G, v.B}
        elseif typeof(v) ~= "function" then
            safeConfig[k] = v
        end
    end
    if writefile then
        writefile(ConfigFile, game:GetService("HttpService"):JSONEncode(safeConfig))
    end
end

local function LoadConfig()
    if isfile and isfile(ConfigFile) and readfile then
        local data = game:GetService("HttpService"):JSONDecode(readfile(ConfigFile))
        for k, v in pairs(data) do
            if type(v) == "table" and #v == 3 then
                Config[k] = Color3.fromRGB(v[1] * 255, v[2] * 255, v[3] * 255)
            else
                Config[k] = v
            end
        end
    end
end

LoadConfig()

-- ============================================================
--  DEEPWOKEN DATA EXTRACTION
-- ============================================================

local function getHealthColor(ratio)
    if ratio > 0.5 then return lerpColor(Config.HPMidColor, Config.HPColor, (ratio - 0.5) * 2) end
    return lerpColor(Config.HPLowColor, Config.HPMidColor, ratio * 2)
end

local function getPostureColor(ratio)
    if ratio > 0.3 then return Config.PostureColor end
    return lerpColor(Config.PostureLowColor, Config.PostureColor, ratio / 0.3)
end

local function getLevelColor(level, localLevel)
    if not localLevel or localLevel == 0 then return Config.LevelColor end
    local diff = level - localLevel
    if diff > 10 then return Color3.fromRGB(255, 80, 80) end
    if diff > 3 then return Color3.fromRGB(255, 180, 80) end
    if diff < -10 then return Color3.fromRGB(80, 255, 120) end
    return Config.LevelColor
end

local function extractDeepwokenData(player)
    local character = player.Character
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local head = character:FindFirstChild("Head")
    if not head then return nil end

    local data = {}
    data.headPos = head.Position
    data.feetPos = rootPart.Position - Vector3.new(0, 3, 0)
    data.rootPos = rootPart.Position

    data.health = humanoid.Health
    data.maxHealth = humanoid.MaxHealth
    if data.maxHealth <= 0 then data.maxHealth = 100 end

    data.posture = character:GetAttribute("Posture") or (character:FindFirstChild("Posture") and character.Posture.Value) or 0
    data.maxPosture = character:GetAttribute("MaxPosture") or 100

    data.food = character:GetAttribute("Hunger") or character:GetAttribute("Food") or (character:FindFirstChild("Hunger") and character.Hunger.Value) or 0
    data.water = character:GetAttribute("Thirst") or character:GetAttribute("Water") or (character:FindFirstChild("Thirst") and character.Thirst.Value) or 0
    data.tempo = character:GetAttribute("Tempo") or (character:FindFirstChild("Tempo") and character.Tempo.Value) or 0

    data.level = player:GetAttribute("Level") or 0
    if data.level == 0 then
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local lvlObj = ls:FindFirstChild("Level") or ls:FindFirstChild("Power")
            if lvlObj then data.level = tonumber(lvlObj.Value) or 0 end
        end
    end

    data.name = humanoid.DisplayName or player.Name
    data.surname = character:GetAttribute("Surname") or ""
    if data.surname == "" and data.name:find(" ") then
        local parts = {}
        for part in data.name:gmatch("%S+") do table.insert(parts, part) end
        if #parts >= 2 then data.name, data.surname = parts[1], parts[2] end
    end

    local localChar = LocalPlayer.Character
    if localChar and localChar:FindFirstChild("HumanoidRootPart") then
        data.distance = (localChar.HumanoidRootPart.Position - rootPart.Position).Magnitude
    else data.distance = 0 end

    data.alive = humanoid.Health > 0
    data.smoothHealth = data.health
    data.smoothPosture = data.posture

    return data
end

-- ============================================================
--  RENDERING
-- ============================================================

local drawingCache = {}

local function createDrawings()
    local d = {}
    local drawTypes = {"Square", "Line", "Text"}
    
    -- Helper to create standard drawings
    local function newDraw(type, props)
        local obj = Drawing.new(type)
        for k, v in pairs(props) do obj[k] = v end
        obj.Visible = false
        return obj
    end

    d.boxBg = newDraw("Square", {Filled = true, Color = Config.BoxBg, Transparency = Config.BoxBgOpacity})
    d.boxBorder = newDraw("Square", {Filled = false, Color = Config.BoxBorder, Thickness = 1, Transparency = Config.BoxBorderOpacity})
    d.accentLine = newDraw("Line", {Color = Config.MatchaAccent, Thickness = 1.5, Transparency = 1.0})
    d.accentGlow = newDraw("Line", {Color = Config.MatchaLight, Thickness = 3, Transparency = 0.3})

    d.corners = {}
    for i=1, 8 do
        d.corners[i] = newDraw("Line", {Color = Config.MatchaAccent, Thickness = 1.5, Transparency = 0.8})
    end

    d.hpBarBg = newDraw("Square", {Filled = true, Color = Config.BarBg, Transparency = Config.BarBgOpacity})
    d.hpBarFill = newDraw("Square", {Filled = true, Color = Config.HPColor, Transparency = 1.0})
    d.postureBarBg = newDraw("Square", {Filled = true, Color = Config.BarBg, Transparency = Config.BarBgOpacity})
    d.postureBarFill = newDraw("Square", {Filled = true, Color = Config.PostureColor, Transparency = 1.0})

    local textDefaults = {Color = Config.NameColor, Transparency = Config.TextOpacity, Center = true, Outline = false, Font = 0, Size = 14}
    d.nameText = newDraw("Text", textDefaults)
    d.nameShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 0, Size = 14})
    d.surnameText = newDraw("Text", textDefaults)
    d.surnameShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 0, Size = 13})
    
    d.levelText = newDraw("Text", {Color = Config.LevelColor, Transparency = Config.TextOpacity, Center = true, Font = 4, Size = 13})
    d.levelShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 4, Size = 13})
    
    d.hpText = newDraw("Text", {Color = Config.HPColor, Transparency = Config.TextOpacity, Center = true, Font = 2, Size = 12})
    d.hpShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 2, Size = 12})
    
    d.postureText = newDraw("Text", {Color = Config.PostureColor, Transparency = Config.TextOpacity, Center = true, Font = 2, Size = 12})
    d.postureShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 2, Size = 12})
    
    d.statsText = newDraw("Text", {Color = Color3.fromRGB(220, 220, 230), Transparency = Config.TextOpacity, Center = true, Font = 3, Size = 11})
    d.statsShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 3, Size = 11})
    
    d.distText = newDraw("Text", {Color = Config.DistanceColor, Transparency = 0.7, Center = true, Font = 3, Size = 11})
    d.distShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 3, Size = 11})

    return d
end

local function hideDrawings(d)
    for _, obj in pairs(d) do
        if typeof(obj) == "table" and obj.Visible ~= nil then
            obj.Visible = false
        elseif typeof(obj) == "table" then
            for _, subObj in pairs(obj) do
                if typeof(subObj) == "table" and subObj.Visible ~= nil then
                    subObj.Visible = false
                end
            end
        end
    end
end

local function cleanupDrawings(player)
    if drawingCache[player] then
        local d = drawingCache[player]
        for _, obj in pairs(d) do
            if typeof(obj) == "table" then
                if obj.Remove then obj:Remove() end
                for _, subObj in pairs(obj) do
                    if typeof(subObj) == "table" and subObj.Remove then
                        subObj:Remove()
                    end
                end
            end
        end
        drawingCache[player] = nil
    end
end

local function renderESP(player, data)
    if not drawingCache[player] then drawingCache[player] = createDrawings() end
    local d = drawingCache[player]

    if not Config.Enabled or not data or not data.alive or data.distance > Config.MaxDistance then
        hideDrawings(d)
        return
    end

    local headScreen, headOnScreen = Camera:WorldToViewportPoint(data.headPos)
    local feetScreen, feetOnScreen = Camera:WorldToViewportPoint(data.feetPos)

    if not headOnScreen or not feetOnScreen then
        hideDrawings(d)
        return
    end

    local boxH = math.abs(feetScreen.Y - headScreen.Y)
    local boxW = boxH * 0.42
    if boxH < 10 or boxW < 5 then hideDrawings(d) return end

    local boxX = headScreen.X - boxW / 2
    local boxY = headScreen.Y

    data.smoothHealth = lerp(data.smoothHealth, data.health, 0.15)
    data.smoothPosture = lerp(data.smoothPosture, data.posture, 0.15)

    local hpRatio = clamp(data.smoothHealth / data.maxHealth, 0, 1)
    local postureRatio = clamp(data.smoothPosture / data.maxPosture, 0, 1)
    local hpColor = getHealthColor(hpRatio)
    local postureColor = getPostureColor(postureRatio)

    -- === BOX ===
    if Config.ShowBox then
        if Config.BoxStyle == "Corner" then
            d.boxBg.Visible = false
            d.boxBorder.Visible = false
            d.accentLine.Visible = false
            d.accentGlow.Visible = false

            local cl = math.clamp(boxW * 0.25, 4, 12)
            -- Top-Left
            d.corners[1].From = Vector2.new(boxX, boxY); d.corners[1].To = Vector2.new(boxX + cl, boxY); d.corners[1].Visible = true
            d.corners[2].From = Vector2.new(boxX, boxY); d.corners[2].To = Vector2.new(boxX, boxY + cl); d.corners[2].Visible = true
            -- Top-Right
            d.corners[3].From = Vector2.new(boxX + boxW - cl, boxY); d.corners[3].To = Vector2.new(boxX + boxW, boxY); d.corners[3].Visible = true
            d.corners[4].From = Vector2.new(boxX + boxW, boxY); d.corners[4].To = Vector2.new(boxX + boxW, boxY + cl); d.corners[4].Visible = true
            -- Bottom-Left
            d.corners[5].From = Vector2.new(boxX, boxY + boxH); d.corners[5].To = Vector2.new(boxX + cl, boxY + boxH); d.corners[5].Visible = true
            d.corners[6].From = Vector2.new(boxX, boxY + boxH - cl); d.corners[6].To = Vector2.new(boxX, boxY + boxH); d.corners[6].Visible = true
            -- Bottom-Right
            d.corners[7].From = Vector2.new(boxX + boxW - cl, boxY + boxH); d.corners[7].To = Vector2.new(boxX + boxW, boxY + boxH); d.corners[7].Visible = true
            d.corners[8].From = Vector2.new(boxX + boxW, boxY + boxH - cl); d.corners[8].To = Vector2.new(boxX + boxW, boxY + boxH); d.corners[8].Visible = true
        else
            for i=1, 8 do d.corners[i].Visible = false end
            d.boxBg.Size = Vector2.new(boxW, boxH); d.boxBg.Position = Vector2.new(boxX, boxY); d.boxBg.Visible = true
            d.boxBorder.Size = Vector2.new(boxW, boxH); d.boxBorder.Position = Vector2.new(boxX, boxY); d.boxBorder.Visible = true
            d.accentGlow.From = Vector2.new(boxX, boxY); d.accentGlow.To = Vector2.new(boxX + boxW, boxY); d.accentGlow.Visible = true
            d.accentLine.From = Vector2.new(boxX, boxY); d.accentLine.To = Vector2.new(boxX + boxW, boxY); d.accentLine.Visible = true
        end
    else
        d.boxBg.Visible = false; d.boxBorder.Visible = false; d.accentLine.Visible = false; d.accentGlow.Visible = false
        for i=1, 8 do d.corners[i].Visible = false end
    end

    -- === HP BAR ===
    if Config.ShowHPBar then
        local barW = 2.5
        local fillH = boxH * hpRatio
        d.hpBarBg.Size = Vector2.new(barW, boxH); d.hpBarBg.Position = Vector2.new(boxX - barW - 3, boxY); d.hpBarBg.Visible = true
        d.hpBarFill.Size = Vector2.new(barW, fillH); d.hpBarFill.Position = Vector2.new(boxX - barW - 3, boxY + (boxH - fillH)); d.hpBarFill.Color = hpColor; d.hpBarFill.Visible = true
    else
        d.hpBarBg.Visible = false; d.hpBarFill.Visible = false
    end

    -- === POSTURE BAR ===
    if Config.ShowPostureBar and data.maxPosture > 0 then
        local barW = 2.5
        local fillH = boxH * postureRatio
        d.postureBarBg.Size = Vector2.new(barW, boxH); d.postureBarBg.Position = Vector2.new(boxX + boxW + 3, boxY); d.postureBarBg.Visible = true
        d.postureBarFill.Size = Vector2.new(barW, fillH); d.postureBarFill.Position = Vector2.new(boxX + boxW + 3, boxY + (boxH - fillH)); d.postureBarFill.Color = postureColor; d.postureBarFill.Visible = true
    else
        d.postureBarBg.Visible = false; d.postureBarFill.Visible = false
    end

    -- === NAME ===
    if Config.ShowName then
        local nameY = boxY - 18
        local nameX = boxX + boxW / 2
        d.nameShadow.Text = data.name; d.nameShadow.Position = Vector2.new(nameX + 1, nameY + 1); d.nameShadow.Visible = true
        d.nameText.Text = data.name; d.nameText.Position = Vector2.new(nameX, nameY); d.nameText.Visible = true

        if data.surname ~= "" then
            d.surnameShadow.Text = data.surname; d.surnameShadow.Position = Vector2.new(nameX + 1, nameY - 14 + 1); d.surnameShadow.Visible = true
            d.surnameText.Text = data.surname; d.surnameText.Position = Vector2.new(nameX, nameY - 14); d.surnameText.Visible = true
        else
            d.surnameShadow.Visible = false; d.surnameText.Visible = false
        end
    else
        d.nameShadow.Visible = false; d.nameText.Visible = false; d.surnameShadow.Visible = false; d.surnameText.Visible = false
    end

    -- === LEVEL ===
    if Config.ShowLevel and data.level > 0 then
        local levelStr = "[" .. data.level .. "]"
        local nameWidth = #data.name * 8
        local levelX = boxX + boxW / 2 + nameWidth / 2 + 8
        local levelY = boxY - 18
        
        local lpData = extractDeepwokenData(LocalPlayer)
        d.levelText.Color = getLevelColor(data.level, lpData and lpData.level or 0)
        
        d.levelShadow.Text = levelStr; d.levelShadow.Position = Vector2.new(levelX + 1, levelY + 1); d.levelShadow.Visible = true
        d.levelText.Text = levelStr; d.levelText.Position = Vector2.new(levelX, levelY); d.levelText.Visible = true
    else
        d.levelShadow.Visible = false; d.levelText.Visible = false
    end

    -- === HP TEXT ===
    if Config.ShowHP then
        local hpStr = string.format("%d/%d", math.floor(data.health), math.floor(data.maxHealth))
        local hpX = boxX - 3 - 2.5 - 4
        local hpY = boxY + boxH / 2 - 6
        d.hpShadow.Text = hpStr; d.hpShadow.Position = Vector2.new(hpX + 1, hpY + 1); d.hpShadow.Visible = true
        d.hpText.Text = hpStr; d.hpText.Position = Vector2.new(hpX, hpY); d.hpText.Color = hpColor; d.hpText.Visible = true
    else
        d.hpShadow.Visible = false; d.hpText.Visible = false
    end

    -- === POSTURE TEXT ===
    if Config.ShowPosture and data.maxPosture > 0 then
        local postStr = string.format("%d/%d", math.floor(data.posture), math.floor(data.maxPosture))
        local postX = boxX + boxW + 3 + 2.5 + 4
        local postY = boxY + boxH / 2 - 6
        d.postureShadow.Text = postStr; d.postureShadow.Position = Vector2.new(postX + 1, postY + 1); d.postureShadow.Visible = true
        d.postureText.Text = postStr; d.postureText.Position = Vector2.new(postX, postY); d.postureText.Color = postureColor; d.postureText.Visible = true
    else
        d.postureShadow.Visible = false; d.postureText.Visible = false
    end

    -- === STATS ===
    local statsParts = {}
    if Config.ShowFood and data.food > 0 then table.insert(statsParts, "F:" .. math.floor(data.food)) end
    if Config.ShowWater and data.water > 0 then table.insert(statsParts, "W:" .. math.floor(data.water)) end
    if Config.ShowTempo and data.tempo > 0 then table.insert(statsParts, "T:" .. math.floor(data.tempo)) end

    if #statsParts > 0 then
        local statsStr = table.concat(statsParts, "  ")
        local statsX = boxX + boxW / 2
        local statsY = boxY + boxH + 3
        d.statsShadow.Text = statsStr; d.statsShadow.Position = Vector2.new(statsX + 1, statsY + 1); d.statsShadow.Visible = true
        d.statsText.Text = statsStr; d.statsText.Position = Vector2.new(statsX, statsY); d.statsText.Visible = true
    else
        d.statsShadow.Visible = false; d.statsText.Visible = false
    end

    -- === DISTANCE ===
    if Config.ShowDistance and data.distance > 0 then
        local distStr = math.floor(data.distance) .. "m"
        local distX = boxX + boxW / 2
        local distY = boxY + boxH + 16
        d.distShadow.Text = distStr; d.distShadow.Position = Vector2.new(distX + 1, distY + 1); d.distShadow.Visible = true
        d.distText.Text = distStr; d.distText.Position = Vector2.new(distX, distY); d.distText.Visible = true
    else
        d.distShadow.Visible = false; d.distText.Visible = false
    end
end

-- ============================================================
--  MATCHA UI INTEGRATION
-- ============================================================
-- Используем стандартный загрузчик Matcha UI
local success, Matcha = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/matcha.lua"))()
end)

if not success or not Matcha then
    warn("[Spectre] Matcha UI library not found. Loading fallback.")
    -- Fallback: if not executed via Matcha executor, create a simple GUI
    local CoreGui = game:GetService("CoreGui")
    local oldGui = CoreGui:FindFirstChild("SpectreFallback")
    if oldGui then oldGui:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpectreFallback"
    gui.Parent = CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 100)
    frame.Position = UDim2.new(0, 50, 0, 50)
    frame.BackgroundColor3 = Config.MatchaAccent
    frame.Parent = gui
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Text = "Spectre Loaded\nMatcha UI not found\nESP Active with default config"
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Parent = frame
else
    local Window = Matcha:CreateWindow({
        Title = "Spectre | Deepwoken",
        SubTitle = "Liquid Glass ESP"
    })

    local TabMain = Window:CreateTab("Main")
    local TabVisuals = Window:CreateTab("Visuals")
    local TabColors = Window:CreateTab("Colors")

    -- Main Tab
    TabMain:CreateToggle("Enable ESP", Config.Enabled, function(state)
        Config.Enabled = state
        SaveConfig()
    end)

    TabMain:CreateSlider("Max Distance", 100, 6000, Config.MaxDistance, function(val)
        Config.MaxDistance = val
        SaveConfig()
    end)

    -- Visuals Tab
    TabVisuals:CreateToggle("Show Box", Config.ShowBox, function(state) Config.ShowBox = state; SaveConfig() end)
    TabVisuals:CreateDropdown("Box Style", {"Corner", "Full"}, Config.BoxStyle, function(val) Config.BoxStyle = val; SaveConfig() end)
    TabVisuals:CreateToggle("Show Name", Config.ShowName, function(state) Config.ShowName = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Level", Config.ShowLevel, function(state) Config.ShowLevel = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show HP Text", Config.ShowHP, function(state) Config.ShowHP = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show HP Bar", Config.ShowHPBar, function(state) Config.ShowHPBar = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Posture Text", Config.ShowPosture, function(state) Config.ShowPosture = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Posture Bar", Config.ShowPostureBar, function(state) Config.ShowPostureBar = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Food", Config.ShowFood, function(state) Config.ShowFood = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Water", Config.ShowWater, function(state) Config.ShowWater = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Tempo", Config.ShowTempo, function(state) Config.ShowTempo = state; SaveConfig() end)
    TabVisuals:CreateToggle("Show Distance", Config.ShowDistance, function(state) Config.ShowDistance = state; SaveConfig() end)

    -- Colors Tab
    local function addColorPicker(tab, name, defaultColor, configKey)
        tab:CreateColorPicker(name, defaultColor, function(color)
            Config[configKey] = color
            SaveConfig()
        end)
    end

    addColorPicker(TabColors, "Matcha Accent", Config.MatchaAccent, "MatchaAccent")
    addColorPicker(TabColors, "Name Color", Config.NameColor, "NameColor")
    addColorPicker(TabColors, "Level Color", Config.LevelColor, "LevelColor")
    addColorPicker(TabColors, "HP Color", Config.HPColor, "HPColor")
    addColorPicker(TabColors, "Posture Color", Config.PostureColor, "PostureColor")
    addColorPicker(TabColors, "Food Color", Config.FoodColor, "FoodColor")
    addColorPicker(TabColors, "Water Color", Config.WaterColor, "WaterColor")
    addColorPicker(TabColors, "Tempo Color", Config.TempoColor, "TempoColor")
end

-- ============================================================
--  MAIN LOOP
-- ============================================================

RunService.RenderStepped:Connect(function()
    if not Config.Enabled then
        for player, d in pairs(drawingCache) do
            hideDrawings(d)
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local data = extractDeepwokenData(player)
            if data then
                renderESP(player, data)
            else
                if drawingCache[player] then hideDrawings(drawingCache[player]) end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(cleanupDrawings)

print("[Spectre] Deepwoken ESP loaded successfully.")