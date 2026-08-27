--[[
    SPECTRE — Deepwoken ESP | Matcha Liquid Glass
    External executor compatible. Matcha native UI.
    Drawing.new rendering. Auto-save config.
]]

-- ============================================================
--  SERVICES
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
--  UTILITIES
-- ============================================================

local function clamp(v, min, max) return math.max(min, math.min(max, v)) end
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
    BoxStyle = "Corner",
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

    MatchaAccent = Color3.fromRGB(118, 161, 75),
    MatchaLight = Color3.fromRGB(150, 190, 100),
    MatchaDark = Color3.fromRGB(80, 120, 50),

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

    FontName = 0,
    FontStats = 2,
    FontLevel = 4,
    FontSmall = 3,

    NameSize = 14,
    LevelSize = 13,
    StatSize = 12,
    SmallSize = 11,
}

local ConfigFile = "SpectreDeepwokenConfig.json"

local function SaveConfig()
    local safe = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then
            safe[k] = {v.R, v.G, v.B}
        elseif typeof(v) ~= "function" then
            safe[k] = v
        end
    end
    if writefile then
        writefile(ConfigFile, HttpService:JSONEncode(safe))
    end
end

local function LoadConfig()
    if isfile and isfile(ConfigFile) and readfile then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if type(v) == "table" and #v == 3 then
                    Config[k] = Color3.fromRGB(
                        clamp(v[1] * 255, 0, 255),
                        clamp(v[2] * 255, 0, 255),
                        clamp(v[3] * 255, 0, 255)
                    )
                else
                    Config[k] = v
                end
            end
        end
    end
end

LoadConfig()

-- ============================================================
--  MATCHA UI LOADER
-- ============================================================

local Matcha

-- Проверяем глобальные переменные
if typeof(getgenv) == "function" then
    Matcha = getgenv().Matcha or getgenv().matcha
end
if not Matcha and typeof(matcha) == "table" then
    Matcha = matcha
end
if not Matcha and typeof(Matcha) == "table" then
    Matcha = Matcha
end

-- Если глобал нет, пробуем загрузить с GitHub
if not Matcha then
    local function tryFetch(url)
        local ok, response = pcall(function()
            return game:HttpGet(url, true)
        end)
        if not ok or not response then return nil end
        if #response < 20 then return nil end
        if response:sub(1, 1) == "<" then return nil end
        if response:find("404: Not Found", 1, true) then return nil end
        if response:find("404", 1, true) and #response < 10 then return nil end
        return response
    end

    local urls = {
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/matcha.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/matcha.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/loader.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/loader.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/ui.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/ui.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/library.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/library.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/Main.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/Main.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/refs/heads/main/UIBinding.lua",
        "https://raw.githubusercontent.com/cconstellation/MatchaScripts/main/UIBinding.lua",
        "https://github.com/cconstellation/MatchaScripts/raw/main/matcha.lua",
        "https://github.com/cconstellation/MatchaScripts/raw/main/loader.lua",
        "https://github.com/cconstellation/MatchaScripts/raw/main/ui.lua",
    }

    for _, url in ipairs(urls) do
        local code = tryFetch(url)
        if code then
            local ok, result = pcall(function()
                return loadstring(code)()
            end)
            if ok and result and typeof(result) == "table" then
                Matcha = result
                break
            end
        end
    end
end

-- ============================================================
--  DEEPWOKEN DATA EXTRACTION
-- ============================================================

local function getHealthColor(ratio)
    if ratio > 0.5 then
        return lerpColor(Config.HPMidColor, Config.HPColor, (ratio - 0.5) * 2)
    end
    return lerpColor(Config.HPLowColor, Config.HPMidColor, ratio * 2)
end

local function getPostureColor(ratio)
    if ratio > 0.3 then
        return Config.PostureColor
    end
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

    -- HP
    data.health = humanoid.Health
    data.maxHealth = humanoid.MaxHealth
    if data.maxHealth <= 0 then data.maxHealth = 100 end

    -- Posture
    data.posture = 0
    data.maxPosture = 100
    local p = character:GetAttribute("Posture")
    if p then data.posture = p end
    local mp = character:GetAttribute("MaxPosture")
    if mp then data.maxPosture = mp end
    if not p then
        local obj = character:FindFirstChild("Posture")
        if obj and obj:IsA("NumberValue") then data.posture = obj.Value end
    end
    if not p then
        local pp = player:GetAttribute("Posture")
        if pp then data.posture = pp end
    end

    -- Food/Hunger
    data.food = 0
    local food = character:GetAttribute("Hunger") or character:GetAttribute("Food")
    if food then
        data.food = food
    else
        local obj = character:FindFirstChild("Hunger") or character:FindFirstChild("Food")
        if obj and obj:IsA("NumberValue") then
            data.food = obj.Value
        else
            local pf = player:GetAttribute("Hunger") or player:GetAttribute("Food")
            if pf then data.food = pf end
        end
    end

    -- Water/Thirst
    data.water = 0
    local water = character:GetAttribute("Thirst") or character:GetAttribute("Water")
    if water then
        data.water = water
    else
        local obj = character:FindFirstChild("Thirst") or character:FindFirstChild("Water")
        if obj and obj:IsA("NumberValue") then
            data.water = obj.Value
        else
            local pw = player:GetAttribute("Thirst") or player:GetAttribute("Water")
            if pw then data.water = pw end
        end
    end

    -- Tempo
    data.tempo = 0
    local tempo = character:GetAttribute("Tempo")
    if tempo then
        data.tempo = tempo
    else
        local obj = character:FindFirstChild("Tempo")
        if obj and obj:IsA("NumberValue") then
            data.tempo = obj.Value
        else
            local pt = player:GetAttribute("Tempo")
            if pt then data.tempo = pt end
        end
    end

    -- Level
    data.level = 0
    local lvl = player:GetAttribute("Level")
    if lvl then data.level = lvl end
    if data.level == 0 then
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local lvlObj = ls:FindFirstChild("Level") or ls:FindFirstChild("Power")
            if lvlObj then
                if lvlObj:IsA("NumberValue") or lvlObj:IsA("IntValue") then
                    data.level = lvlObj.Value
                elseif lvlObj:IsA("StringValue") then
                    data.level = tonumber(lvlObj.Value) or 0
                end
            end
        end
    end
    if data.level == 0 then
        local pData = player:FindFirstChild("Data")
        if pData then
            local lvlObj = pData:FindFirstChild("Level") or pData:FindFirstChild("Power")
            if lvlObj and lvlObj:IsA("NumberValue") then
                data.level = lvlObj.Value
            end
        end
    end
    if data.level == 0 then
        local cl = character:GetAttribute("Level") or character:GetAttribute("Power")
        if cl then data.level = cl end
    end

    -- Name & Surname
    data.name = humanoid.DisplayName or player.Name
    data.surname = ""

    local charName = character:GetAttribute("CharacterName") or character:GetAttribute("Name")
    if charName then data.name = charName end

    local surname = character:GetAttribute("Surname") or character:GetAttribute("LastName")
    if surname then data.surname = surname end

    if data.surname == "" and data.name:find(" ") then
        local parts = {}
        for part in data.name:gmatch("%S+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            data.name = parts[1]
            data.surname = parts[2]
        end
    end

    if data.surname == "" then
        local obj = character:FindFirstChild("Surname") or character:FindFirstChild("LastName")
        if obj and obj:IsA("StringValue") then
            data.surname = obj.Value
        end
    end

    -- Distance
    local localChar = LocalPlayer.Character
    if localChar and localChar:FindFirstChild("HumanoidRootPart") then
        data.distance = (localChar.HumanoidRootPart.Position - rootPart.Position).Magnitude
    else
        data.distance = 0
    end

    data.alive = humanoid.Health > 0
    data.smoothHealth = data.health
    data.smoothPosture = data.posture

    return data
end

-- ============================================================
--  ESP DRAWING CACHE
-- ============================================================

local drawingCache = {}

local function createDrawings()
    local d = {}
    local function newDraw(type, props)
        local obj = Drawing.new(type)
        for k, v in pairs(props) do obj[k] = v end
        obj.Visible = false
        return obj
    end

    -- Box elements
    d.boxBg = newDraw("Square", {Filled = true, Color = Config.BoxBg, Transparency = Config.BoxBgOpacity})
    d.boxBorder = newDraw("Square", {Filled = false, Color = Config.BoxBorder, Thickness = 1, Transparency = Config.BoxBorderOpacity})
    d.accentLine = newDraw("Line", {Color = Config.MatchaAccent, Thickness = 1.5, Transparency = 1.0})
    d.accentGlow = newDraw("Line", {Color = Config.MatchaLight, Thickness = 3, Transparency = 0.3})

    -- Corner box (8 lines)
    d.corners = {}
    for i = 1, 8 do
        d.corners[i] = newDraw("Line", {Color = Config.MatchaAccent, Thickness = 1.5, Transparency = 0.8})
    end

    -- HP bar (left)
    d.hpBarBg = newDraw("Square", {Filled = true, Color = Config.BarBg, Transparency = Config.BarBgOpacity})
    d.hpBarFill = newDraw("Square", {Filled = true, Color = Config.HPColor, Transparency = 1.0})

    -- Posture bar (right)
    d.postureBarBg = newDraw("Square", {Filled = true, Color = Config.BarBg, Transparency = Config.BarBgOpacity})
    d.postureBarFill = newDraw("Square", {Filled = true, Color = Config.PostureColor, Transparency = 1.0})

    -- Name
    d.nameText = newDraw("Text", {Color = Config.NameColor, Transparency = Config.TextOpacity, Center = true, Font = Config.FontName, Size = Config.NameSize})
    d.nameShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontName, Size = Config.NameSize})

    -- Surname
    d.surnameText = newDraw("Text", {Color = Color3.fromRGB(200, 200, 210), Transparency = 0.85, Center = true, Font = Config.FontName, Size = Config.NameSize - 1})
    d.surnameShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontName, Size = Config.NameSize - 1})

    -- Level
    d.levelText = newDraw("Text", {Color = Config.LevelColor, Transparency = Config.TextOpacity, Center = true, Font = Config.FontLevel, Size = Config.LevelSize})
    d.levelShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontLevel, Size = Config.LevelSize})

    -- HP text
    d.hpText = newDraw("Text", {Color = Config.HPColor, Transparency = Config.TextOpacity, Center = true, Font = Config.FontStats, Size = Config.StatSize})
    d.hpShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontStats, Size = Config.StatSize})

    -- Posture text
    d.postureText = newDraw("Text", {Color = Config.PostureColor, Transparency = Config.TextOpacity, Center = true, Font = Config.FontStats, Size = Config.StatSize})
    d.postureShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontStats, Size = Config.StatSize})

    -- Stats (food/water/tempo)
    d.statsText = newDraw("Text", {Color = Color3.fromRGB(220, 220, 230), Transparency = Config.TextOpacity, Center = true, Font = Config.FontSmall, Size = Config.SmallSize})
    d.statsShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontSmall, Size = Config.SmallSize})

    -- Distance
    d.distText = newDraw("Text", {Color = Config.DistanceColor, Transparency = 0.7, Center = true, Font = Config.FontSmall, Size = Config.SmallSize})
    d.distShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = Config.FontSmall, Size = Config.SmallSize})

    return d
end

local function hideDrawings(d)
    if not d then return end
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

-- ============================================================
--  ESP RENDERING
-- ============================================================

local localLevelCache = 0
local localLevelTimer = 0

local function getLocalLevel()
    if tick() - localLevelTimer > 2 then
        localLevelTimer = tick()
        local lpData = extractDeepwokenData(LocalPlayer)
        if lpData then localLevelCache = lpData.level end
    end
    return localLevelCache
end

local function renderESP(player, data)
    if not drawingCache[player] then
        drawingCache[player] = createDrawings()
    end
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
    if boxH < 10 or boxW < 5 then
        hideDrawings(d)
        return
    end

    local boxX = headScreen.X - boxW / 2
    local boxY = headScreen.Y

    -- Smooth bars
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

            d.corners[1].From = Vector2.new(boxX, boxY)
            d.corners[1].To = Vector2.new(boxX + cl, boxY)
            d.corners[1].Color = Config.MatchaAccent
            d.corners[1].Visible = true

            d.corners[2].From = Vector2.new(boxX, boxY)
            d.corners[2].To = Vector2.new(boxX, boxY + cl)
            d.corners[2].Color = Config.MatchaAccent
            d.corners[2].Visible = true

            d.corners[3].From = Vector2.new(boxX + boxW - cl, boxY)
            d.corners[3].To = Vector2.new(boxX + boxW, boxY)
            d.corners[3].Color = Config.MatchaAccent
            d.corners[3].Visible = true

            d.corners[4].From = Vector2.new(boxX + boxW, boxY)
            d.corners[4].To = Vector2.new(boxX + boxW, boxY + cl)
            d.corners[4].Color = Config.MatchaAccent
            d.corners[4].Visible = true

            d.corners[5].From = Vector2.new(boxX, boxY + boxH)
            d.corners[5].To = Vector2.new(boxX + cl, boxY + boxH)
            d.corners[5].Color = Config.MatchaAccent
            d.corners[5].Visible = true

            d.corners[6].From = Vector2.new(boxX, boxY + boxH - cl)
            d.corners[6].To = Vector2.new(boxX, boxY + boxH)
            d.corners[6].Color = Config.MatchaAccent
            d.corners[6].Visible = true

            d.corners[7].From = Vector2.new(boxX + boxW - cl, boxY + boxH)
            d.corners[7].To = Vector2.new(boxX + boxW, boxY + boxH)
            d.corners[7].Color = Config.MatchaAccent
            d.corners[7].Visible = true

            d.corners[8].From = Vector2.new(boxX + boxW, boxY + boxH - cl)
            d.corners[8].To = Vector2.new(boxX + boxW, boxY + boxH)
            d.corners[8].Color = Config.MatchaAccent
            d.corners[8].Visible = true
        else
            for i = 1, 8 do d.corners[i].Visible = false end

            d.boxBg.Size = Vector2.new(boxW, boxH)
            d.boxBg.Position = Vector2.new(boxX, boxY)
            d.boxBg.Color = Config.BoxBg
            d.boxBg.Transparency = Config.BoxBgOpacity
            d.boxBg.Visible = true

            d.boxBorder.Size = Vector2.new(boxW, boxH)
            d.boxBorder.Position = Vector2.new(boxX, boxY)
            d.boxBorder.Color = Config.BoxBorder
            d.boxBorder.Thickness = 1
            d.boxBorder.Transparency = Config.BoxBorderOpacity
            d.boxBorder.Visible = true

            d.accentGlow.From = Vector2.new(boxX, boxY)
            d.accentGlow.To = Vector2.new(boxX + boxW, boxY)
            d.accentGlow.Color = Config.MatchaLight
            d.accentGlow.Visible = true

            d.accentLine.From = Vector2.new(boxX, boxY)
            d.accentLine.To = Vector2.new(boxX + boxW, boxY)
            d.accentLine.Color = Config.MatchaAccent
            d.accentLine.Visible = true
        end
    else
        d.boxBg.Visible = false
        d.boxBorder.Visible = false
        d.accentLine.Visible = false
        d.accentGlow.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
    end

    -- === HP BAR (Left) ===
    if Config.ShowHPBar then
        local barW = 2.5
        local fillH = boxH * hpRatio
        local barX = boxX - barW - 3

        d.hpBarBg.Size = Vector2.new(barW, boxH)
        d.hpBarBg.Position = Vector2.new(barX, boxY)
        d.hpBarBg.Color = Config.BarBg
        d.hpBarBg.Transparency = Config.BarBgOpacity
        d.hpBarBg.Visible = true

        d.hpBarFill.Size = Vector2.new(barW, fillH)
        d.hpBarFill.Position = Vector2.new(barX, boxY + (boxH - fillH))
        d.hpBarFill.Color = hpColor
        d.hpBarFill.Transparency = 1.0
        d.hpBarFill.Visible = true
    else
        d.hpBarBg.Visible = false
        d.hpBarFill.Visible = false
    end

    -- === POSTURE BAR (Right) ===
    if Config.ShowPostureBar and data.maxPosture > 0 then
        local barW = 2.5
        local fillH = boxH * postureRatio
        local barX = boxX + boxW + 3

        d.postureBarBg.Size = Vector2.new(barW, boxH)
        d.postureBarBg.Position = Vector2.new(barX, boxY)
        d.postureBarBg.Color = Config.BarBg
        d.postureBarBg.Transparency = Config.BarBgOpacity
        d.postureBarBg.Visible = true

        d.postureBarFill.Size = Vector2.new(barW, fillH)
        d.postureBarFill.Position = Vector2.new(barX, boxY + (boxH - fillH))
        d.postureBarFill.Color = postureColor
        d.postureBarFill.Transparency = 1.0
        d.postureBarFill.Visible = true
    else
        d.postureBarBg.Visible = false
        d.postureBarFill.Visible = false
    end

    -- === NAME ===
    if Config.ShowName then
        local nameY = boxY - Config.NameSize - 4
        local nameX = boxX + boxW / 2

        d.nameShadow.Text = data.name
        d.nameShadow.Position = Vector2.new(nameX + 1, nameY + 1)
        d.nameShadow.Color = Config.ShadowColor
        d.nameShadow.Font = Config.FontName
        d.nameShadow.Size = Config.NameSize
        d.nameShadow.Visible = true

        d.nameText.Text = data.name
        d.nameText.Position = Vector2.new(nameX, nameY)
        d.nameText.Color = Config.NameColor
        d.nameText.Font = Config.FontName
        d.nameText.Size = Config.NameSize
        d.nameText.Visible = true

        if data.surname and data.surname ~= "" then
            local surnameY = nameY - Config.NameSize

            d.surnameShadow.Text = data.surname
            d.surnameShadow.Position = Vector2.new(nameX + 1, surnameY + 1)
            d.surnameShadow.Font = Config.FontName
            d.surnameShadow.Size = Config.NameSize - 1
            d.surnameShadow.Visible = true

            d.surnameText.Text = data.surname
            d.surnameText.Position = Vector2.new(nameX, surnameY)
            d.surnameText.Font = Config.FontName
            d.surnameText.Size = Config.NameSize - 1
            d.surnameText.Visible = true
        else
            d.surnameShadow.Visible = false
            d.surnameText.Visible = false
        end
    else
        d.nameShadow.Visible = false
        d.nameText.Visible = false
        d.surnameShadow.Visible = false
        d.surnameText.Visible = false
    end

    -- === LEVEL ===
    if Config.ShowLevel and data.level > 0 then
        local levelStr = "[" .. data.level .. "]"
        local nameWidth = #data.name * (Config.NameSize * 0.55)
        local levelX = boxX + boxW / 2 + nameWidth / 2 + 8
        local levelY = boxY - Config.NameSize - 4

        local localLevel = getLocalLevel()
        local lvlColor = getLevelColor(data.level, localLevel)

        d.levelShadow.Text = levelStr
        d.levelShadow.Position = Vector2.new(levelX + 1, levelY + 1)
        d.levelShadow.Font = Config.FontLevel
        d.levelShadow.Size = Config.LevelSize
        d.levelShadow.Visible = true

        d.levelText.Text = levelStr
        d.levelText.Position = Vector2.new(levelX, levelY)
        d.levelText.Font = Config.FontLevel
        d.levelText.Size = Config.LevelSize
        d.levelText.Color = lvlColor
        d.levelText.Visible = true
    else
        d.levelShadow.Visible = false
        d.levelText.Visible = false
    end

    -- === HP TEXT ===
    if Config.ShowHP then
        local hpStr = string.format("%d/%d", math.floor(data.health), math.floor(data.maxHealth))
        local hpX = boxX - 3 - 2.5 - 4
        local hpY = boxY + boxH / 2 - Config.StatSize / 2

        d.hpShadow.Text = hpStr
        d.hpShadow.Position = Vector2.new(hpX + 1, hpY + 1)
        d.hpShadow.Font = Config.FontStats
        d.hpShadow.Size = Config.StatSize
        d.hpShadow.Visible = true

        d.hpText.Text = hpStr
        d.hpText.Position = Vector2.new(hpX, hpY)
        d.hpText.Font = Config.FontStats
        d.hpText.Size = Config.StatSize
        d.hpText.Color = hpColor
        d.hpText.Visible = true
    else
        d.hpShadow.Visible = false
        d.hpText.Visible = false
    end

    -- === POSTURE TEXT ===
    if Config.ShowPosture and data.maxPosture > 0 then
        local postStr = string.format("%d/%d", math.floor(data.posture), math.floor(data.maxPosture))
        local postX = boxX + boxW + 3 + 2.5 + 4
        local postY = boxY + boxH / 2 - Config.StatSize / 2

        d.postureShadow.Text = postStr
        d.postureShadow.Position = Vector2.new(postX + 1, postY + 1)
        d.postureShadow.Font = Config.FontStats
        d.postureShadow.Size = Config.StatSize
        d.postureShadow.Visible = true

        d.postureText.Text = postStr
        d.postureText.Position = Vector2.new(postX, postY)
        d.postureText.Font = Config.FontStats
        d.postureText.Size = Config.StatSize
        d.postureText.Color = postureColor
        d.postureText.Visible = true
    else
        d.postureShadow.Visible = false
        d.postureText.Visible = false
    end

    -- === STATS (Food, Water, Tempo) ===
    local statsParts = {}
    if Config.ShowFood and data.food > 0 then
        table.insert(statsParts, "F:" .. math.floor(data.food))
    end
    if Config.ShowWater and data.water > 0 then
        table.insert(statsParts, "W:" .. math.floor(data.water))
    end
    if Config.ShowTempo and data.tempo > 0 then
        table.insert(statsParts, "T:" .. math.floor(data.tempo))
    end

    if #statsParts > 0 then
        local statsStr = table.concat(statsParts, "  ")
        local statsX = boxX + boxW / 2
        local statsY = boxY + boxH + 3

        d.statsShadow.Text = statsStr
        d.statsShadow.Position = Vector2.new(statsX + 1, statsY + 1)
        d.statsShadow.Font = Config.FontSmall
        d.statsShadow.Size = Config.SmallSize
        d.statsShadow.Visible = true

        d.statsText.Text = statsStr
        d.statsText.Position = Vector2.new(statsX, statsY)
        d.statsText.Font = Config.FontSmall
        d.statsText.Size = Config.SmallSize
        d.statsText.Visible = true
    else
        d.statsShadow.Visible = false
        d.statsText.Visible = false
    end

    -- === DISTANCE ===
    if Config.ShowDistance and data.distance > 0 then
        local distStr = math.floor(data.distance) .. "m"
        local distX = boxX + boxW / 2
        local distY = boxY + boxH + Config.SmallSize + 5

        d.distShadow.Text = distStr
        d.distShadow.Position = Vector2.new(distX + 1, distY + 1)
        d.distShadow.Font = Config.FontSmall
        d.distShadow.Size = Config.SmallSize
        d.distShadow.Visible = true

        d.distText.Text = distStr
        d.distText.Position = Vector2.new(distX, distY)
        d.distText.Font = Config.FontSmall
        d.distText.Size = Config.SmallSize
        d.distText.Visible = true
    else
        d.distShadow.Visible = false
        d.distText.Visible = false
    end
end

-- ============================================================
--  MATCHA UI BUILD
-- ============================================================

local UI built = false

if Matcha then
    local ok, err = pcall(function()
        -- Пробуем CreateWindow — самый частый паттерн
        local Window
        local windowOk = pcall(function()
            Window = Matcha:CreateWindow({
                Title = "Spectre | Deepwoken",
                SubTitle = "Liquid Glass ESP",
                Animation = true
            })
        end)

        if not Window then
            pcall(function()
                Window = Matcha:Window({
                    Title = "Spectre | Deepwoken",
                    SubTitle = "Liquid Glass ESP"
                })
            end)
        end

        if not Window then
            pcall(function()
                Window = Matcha.new({
                    Title = "Spectre | Deepwoken"
                })
            end)
        end

        if not Window then
            error("Could not create window")
        end

        -- Функция-обёртка для создания табов
        local function makeTab(name)
            local tab
            pcall(function() tab = Window:CreateTab(name) end)
            if not tab then pcall(function() tab = Window:Tab(name) end) end
            if not tab then pcall(function() tab = Window:AddTab(name) end) end
            if not tab then pcall(function() tab = Window:NewTab(name) end) end
            return tab
        end

        -- Функция-обёртка для toggle
        local function makeToggle(tab, name, default, callback)
            local ok = pcall(function() tab:CreateToggle(name, default, callback) end)
            if not ok then pcall(function() tab:Toggle(name, default, callback) end) end
            if not ok then pcall(function() tab:AddToggle(name, default, callback) end) end
        end

        -- Функция-обёртка для slider
        local function makeSlider(tab, name, min, max, default, callback)
            local ok = pcall(function() tab:CreateSlider(name, min, max, default, callback) end)
            if not ok then pcall(function() tab:Slider(name, min, max, default, callback) end) end
            if not ok then pcall(function() tab:AddSlider(name, min, max, default, callback) end) end
        end

        -- Функция-обёртка для dropdown
        local function makeDropdown(tab, name, options, default, callback)
            local ok = pcall(function() tab:CreateDropdown(name, options, default, callback) end)
            if not ok then pcall(function() tab:Dropdown(name, options, default, callback) end) end
            if not ok then pcall(function() tab:AddDropdown(name, options, default, callback) end) end
        end

        -- Функция-обёртка для color picker
        local function makeColorPicker(tab, name, default, callback)
            local ok = pcall(function() tab:CreateColorPicker(name, default, callback) end)
            if not ok then pcall(function() tab:ColorPicker(name, default, callback) end) end
            if not ok then pcall(function() tab:AddColorPicker(name, default, callback) end) end
        end

        -- === TAB: MAIN ===
        local TabMain = makeTab("Main")

        makeToggle(TabMain, "Enable ESP", Config.Enabled, function(state)
            Config.Enabled = state
            SaveConfig()
        end)

        makeSlider(TabMain, "Max Distance", 100, 6000, Config.MaxDistance, function(val)
            Config.MaxDistance = val
            SaveConfig()
        end)

        -- === TAB: VISUALS ===
        local TabVis = makeTab("Visuals")

        makeToggle(TabVis, "Show Box", Config.ShowBox, function(s) Config.ShowBox = s; SaveConfig() end)
        makeDropdown(TabVis, "Box Style", {"Corner", "Full"}, Config.BoxStyle, function(v) Config.BoxStyle = v; SaveConfig() end)
        makeToggle(TabVis, "Show Name", Config.ShowName, function(s) Config.ShowName = s; SaveConfig() end)
        makeToggle(TabVis, "Show Surname (if available)", Config.ShowName, function(s) Config.ShowName = s; SaveConfig() end)
        makeToggle(TabVis, "Show Level", Config.ShowLevel, function(s) Config.ShowLevel = s; SaveConfig() end)
        makeToggle(TabVis, "Show HP Text", Config.ShowHP, function(s) Config.ShowHP = s; SaveConfig() end)
        makeToggle(TabVis, "Show HP Bar", Config.ShowHPBar, function(s) Config.ShowHPBar = s; SaveConfig() end)
        makeToggle(TabVis, "Show Posture Text", Config.ShowPosture, function(s) Config.ShowPosture = s; SaveConfig() end)
        makeToggle(TabVis, "Show Posture Bar", Config.ShowPostureBar, function(s) Config.ShowPostureBar = s; SaveConfig() end)
        makeToggle(TabVis, "Show Food", Config.ShowFood, function(s) Config.ShowFood = s; SaveConfig() end)
        makeToggle(TabVis, "Show Water", Config.ShowWater, function(s) Config.ShowWater = s; SaveConfig() end)
        makeToggle(TabVis, "Show Tempo", Config.ShowTempo, function(s) Config.ShowTempo = s; SaveConfig() end)
        makeToggle(TabVis, "Show Distance", Config.ShowDistance, function(s) Config.ShowDistance = s; SaveConfig() end)

        -- === TAB: COLORS ===
        local TabColors = makeTab("Colors")

        makeColorPicker(TabColors, "Matcha Accent", Config.MatchaAccent, function(c) Config.MatchaAccent = c; SaveConfig() end)
        makeColorPicker(TabColors, "Matcha Light", Config.MatchaLight, function(c) Config.MatchaLight = c; SaveConfig() end)
        makeColorPicker(TabColors, "Name Color", Config.NameColor, function(c) Config.NameColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Level Color", Config.LevelColor, function(c) Config.LevelColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "HP Color", Config.HPColor, function(c) Config.HPColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "HP Low Color", Config.HPLowColor, function(c) Config.HPLowColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Posture Color", Config.PostureColor, function(c) Config.PostureColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Food Color", Config.FoodColor, function(c) Config.FoodColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Water Color", Config.WaterColor, function(c) Config.WaterColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Tempo Color", Config.TempoColor, function(c) Config.TempoColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Distance Color", Config.DistanceColor, function(c) Config.DistanceColor = c; SaveConfig() end)
        makeColorPicker(TabColors, "Box Background", Config.BoxBg, function(c) Config.BoxBg = c; SaveConfig() end)
        makeColorPicker(TabColors, "Box Border", Config.BoxBorder, function(c) Config.BoxBorder = c; SaveConfig() end)

        -- === TAB: SETTINGS ===
        local TabSettings = makeTab("Settings")

        makeSlider(TabSettings, "Box BG Opacity", 0, 1, Config.BoxBgOpacity, function(v) Config.BoxBgOpacity = v; SaveConfig() end)
        makeSlider(TabSettings, "Box Border Opacity", 0, 1, Config.BoxBorderOpacity, function(v) Config.BoxBorderOpacity = v; SaveConfig() end)
        makeSlider(TabSettings, "Bar BG Opacity", 0, 1, Config.BarBgOpacity, function(v) Config.BarBgOpacity = v; SaveConfig() end)
        makeSlider(TabSettings, "Name Size", 10, 20, Config.NameSize, function(v) Config.NameSize = v; SaveConfig() end)
        makeSlider(TabSettings, "Level Size", 10, 18, Config.LevelSize, function(v) Config.LevelSize = v; SaveConfig() end)
        makeSlider(TabSettings, "Stat Size", 8, 16, Config.StatSize, function(v) Config.StatSize = v; SaveConfig() end)

        UIBuilt = true
    end)

    if not ok then
        print("[Spectre] Matcha UI error: " .. tostring(err))
    end
end

if not UIBuilt then
    print("[Spectre] WARNING: Matcha UI could not be initialized. ESP will run with default config.")
    print("[Spectre] ESP is active. Edit config file to change settings.")
end

-- ============================================================
--  WATERMARK
-- ============================================================

local watermark = Drawing.new("Text")
watermark.Text = "SPECTRE | DEEPWOKEN ESP"
watermark.Color = Config.MatchaAccent
watermark.Transparency = 0.6
watermark.Font = 0
watermark.Size = 13
watermark.Position = Vector2.new(10, 10)
watermark.Center = false
watermark.Visible = true

local watermarkShadow = Drawing.new("Text")
watermarkShadow.Text = "SPECTRE | DEEPWOKEN ESP"
watermarkShadow.Color = Config.ShadowColor
watermarkShadow.Transparency = Config.ShadowOpacity
watermarkShadow.Font = 0
watermarkShadow.Size = 13
watermarkShadow.Position = Vector2.new(11, 11)
watermarkShadow.Center = false
watermarkShadow.Visible = true

-- ============================================================
--  MAIN RENDER LOOP
-- ============================================================

RunService.RenderStepped:Connect(function()
    -- Update watermark visibility
    watermark.Visible = Config.Enabled
    watermarkShadow.Visible = Config.Enabled
    watermark.Color = Config.MatchaAccent

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
                if drawingCache[player] then
                    hideDrawings(drawingCache[player])
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    cleanupDrawings(player)
end)

print("[Spectre] Deepwoken ESP loaded successfully.")
if UIBuilt then
    print("[Spectre] Matcha UI initialized. Open Matcha menu to configure.")
else
    print("[Spectre] Running with default config (UI not available).")
end