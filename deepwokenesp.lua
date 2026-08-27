--[[
    SPECTRE — Deepwoken ESP | Matcha Liquid Glass (External Fix)
    Полностью самодостаточный, без Instance.new и loadstring.
]]

-- ============================================================
--  SERVICES & UTILS
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

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
        writefile(ConfigFile, HttpService:JSONEncode(safeConfig))
    end
end

local function LoadConfig()
    if isfile and isfile(ConfigFile) and readfile then
        local data = HttpService:JSONDecode(readfile(ConfigFile))
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
--  ESP RENDERING
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

    d.nameText = newDraw("Text", {Color = Config.NameColor, Transparency = Config.TextOpacity, Center = true, Font = 0, Size = 14})
    d.nameShadow = newDraw("Text", {Color = Config.ShadowColor, Transparency = Config.ShadowOpacity, Center = true, Font = 0, Size = 14})
    d.surnameText = newDraw("Text", {Color = Config.NameColor, Transparency = Config.TextOpacity, Center = true, Font = 0, Size = 13})
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

    if Config.ShowBox then
        if Config.BoxStyle == "Corner" then
            d.boxBg.Visible = false; d.boxBorder.Visible = false; d.accentLine.Visible = false; d.accentGlow.Visible = false
            local cl = math.clamp(boxW * 0.25, 4, 12)
            d.corners[1].From = Vector2.new(boxX, boxY); d.corners[1].To = Vector2.new(boxX + cl, boxY); d.corners[1].Visible = true
            d.corners[2].From = Vector2.new(boxX, boxY); d.corners[2].To = Vector2.new(boxX, boxY + cl); d.corners[2].Visible = true
            d.corners[3].From = Vector2.new(boxX + boxW - cl, boxY); d.corners[3].To = Vector2.new(boxX + boxW, boxY); d.corners[3].Visible = true
            d.corners[4].From = Vector2.new(boxX + boxW, boxY); d.corners[4].To = Vector2.new(boxX + boxW, boxY + cl); d.corners[4].Visible = true
            d.corners[5].From = Vector2.new(boxX, boxY + boxH); d.corners[5].To = Vector2.new(boxX + cl, boxY + boxH); d.corners[5].Visible = true
            d.corners[6].From = Vector2.new(boxX, boxY + boxH - cl); d.corners[6].To = Vector2.new(boxX, boxY + boxH); d.corners[6].Visible = true
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

    if Config.ShowHPBar then
        local barW = 2.5
        local fillH = boxH * hpRatio
        d.hpBarBg.Size = Vector2.new(barW, boxH); d.hpBarBg.Position = Vector2.new(boxX - barW - 3, boxY); d.hpBarBg.Visible = true
        d.hpBarFill.Size = Vector2.new(barW, fillH); d.hpBarFill.Position = Vector2.new(boxX - barW - 3, boxY + (boxH - fillH)); d.hpBarFill.Color = hpColor; d.hpBarFill.Visible = true
    else
        d.hpBarBg.Visible = false; d.hpBarFill.Visible = false
    end

    if Config.ShowPostureBar and data.maxPosture > 0 then
        local barW = 2.5
        local fillH = boxH * postureRatio
        d.postureBarBg.Size = Vector2.new(barW, boxH); d.postureBarBg.Position = Vector2.new(boxX + boxW + 3, boxY); d.postureBarBg.Visible = true
        d.postureBarFill.Size = Vector2.new(barW, fillH); d.postureBarFill.Position = Vector2.new(boxX + boxW + 3, boxY + (boxH - fillH)); d.postureBarFill.Color = postureColor; d.postureBarFill.Visible = true
    else
        d.postureBarBg.Visible = false; d.postureBarFill.Visible = false
    end

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

    if Config.ShowHP then
        local hpStr = string.format("%d/%d", math.floor(data.health), math.floor(data.maxHealth))
        local hpX = boxX - 3 - 2.5 - 4
        local hpY = boxY + boxH / 2 - 6
        d.hpShadow.Text = hpStr; d.hpShadow.Position = Vector2.new(hpX + 1, hpY + 1); d.hpShadow.Visible = true
        d.hpText.Text = hpStr; d.hpText.Position = Vector2.new(hpX, hpY); d.hpText.Color = hpColor; d.hpText.Visible = true
    else
        d.hpShadow.Visible = false; d.hpText.Visible = false
    end

    if Config.ShowPosture and data.maxPosture > 0 then
        local postStr = string.format("%d/%d", math.floor(data.posture), math.floor(data.maxPosture))
        local postX = boxX + boxW + 3 + 2.5 + 4
        local postY = boxY + boxH / 2 - 6
        d.postureShadow.Text = postStr; d.postureShadow.Position = Vector2.new(postX + 1, postY + 1); d.postureShadow.Visible = true
        d.postureText.Text = postStr; d.postureText.Position = Vector2.new(postX, postY); d.postureText.Color = postureColor; d.postureText.Visible = true
    else
        d.postureShadow.Visible = false; d.postureText.Visible = false
    end

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
--  CUSTOM MATCHA LIQUID GLASS UI (Drawing Based)
-- ============================================================

local Menu = {
    Open = true,
    X = 100,
    Y = 100,
    W = 260,
    H = 40,
    Items = {},
    Dragging = false,
    DragOffset = Vector2.new(0,0)
}

function Menu:AddToggle(text, configKey)
    table.insert(Menu.Items, {Text = text, Key = configKey, Clicked = false})
    Menu.H = 45 + #Menu.Items * 22
end

Menu:AddToggle("Enable ESP", "Enabled")
Menu:AddToggle("Show Box", "ShowBox")
Menu:AddToggle("Show Name", "ShowName")
Menu:AddToggle("Show Level", "ShowLevel")
Menu:AddToggle("Show HP Bar", "ShowHPBar")
Menu:AddToggle("Show HP Text", "ShowHP")
Menu:AddToggle("Show Posture Bar", "ShowPostureBar")
Menu:AddToggle("Show Posture Text", "ShowPosture")
Menu:AddToggle("Show Food", "ShowFood")
Menu:AddToggle("Show Water", "ShowWater")
Menu:AddToggle("Show Tempo", "ShowTempo")
Menu:AddToggle("Show Distance", "ShowDistance")

local mBg = Drawing.new("Square")
mBg.Filled = true
mBg.Color = Color3.fromRGB(18, 20, 24)
mBg.Transparency = 0.95
mBg.Visible = false

local mBorder = Drawing.new("Square")
mBorder.Filled = false
mBorder.Color = Config.MatchaAccent
mBorder.Thickness = 1
mBorder.Visible = false

local mAccent = Drawing.new("Line")
mAccent.Color = Config.MatchaAccent
mAccent.Thickness = 2
mAccent.Visible = false

local mHeader = Drawing.new("Text")
mHeader.Text = "SPECTRE | DEEPWOKEN"
mHeader.Color = Config.MatchaLight
mHeader.Size = 15
mHeader.Font = 0
mHeader.Center = false
mHeader.Visible = false

local mWater = Drawing.new("Text")
mWater.Text = "Matcha External"
mWater.Color = Color3.fromRGB(100, 100, 110)
mWater.Size = 11
mWater.Font = 3
mWater.Center = false
mWater.Visible = false

local mItems = {}
for i = 1, #Menu.Items do
    local txt = Drawing.new("Text")
    txt.Size = 14
    txt.Font = 0
    txt.Center = false
    txt.Visible = false
    table.insert(mItems, txt)
end

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        Menu.Open = not Menu.Open
    end
end)

-- ============================================================
--  MAIN LOOP
-- ============================================================

RunService.RenderStepped:Connect(function()
    -- === RENDER MENU ===
    if Menu.Open then
        local mousePos = UserInputService:GetMouseLocation()
        local mousePressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        
        mBg.Size = Vector2.new(Menu.W, Menu.H)
        mBg.Position = Vector2.new(Menu.X, Menu.Y)
        mBg.Visible = true
        
        mBorder.Size = Vector2.new(Menu.W, Menu.H)
        mBorder.Position = Vector2.new(Menu.X, Menu.Y)
        mBorder.Visible = true
        
        mAccent.From = Vector2.new(Menu.X, Menu.Y + 25)
        mAccent.To = Vector2.new(Menu.X + Menu.W, Menu.Y + 25)
        mAccent.Visible = true
        
        mHeader.Position = Vector2.new(Menu.X + 10, Menu.Y + 5)
        mHeader.Visible = true
        
        mWater.Position = Vector2.new(Menu.X + Menu.W - 90, Menu.Y + 8)
        mWater.Visible = true
        
        if mousePressed and mousePos.X >= Menu.X and mousePos.X <= Menu.X + Menu.W and mousePos.Y >= Menu.Y and mousePos.Y <= Menu.Y + 25 then
            if not Menu.Dragging then
                Menu.Dragging = true
                Menu.DragOffset = Vector2.new(mousePos.X - Menu.X, mousePos.Y - Menu.Y)
            end
        elseif not mousePressed then
            Menu.Dragging = false
        end
        
        if Menu.Dragging then
            Menu.X = mousePos.X - Menu.DragOffset.X
            Menu.Y = mousePos.Y - Menu.DragOffset.X
            Menu.Y = mousePos.Y - Menu.DragOffset.Y
        end
        
        for i, item in ipairs(Menu.Items) do
            local txt = mItems[i]
            local itemY = Menu.Y + 35 + (i - 1) * 22
            local itemX = Menu.X + 15
            
            local state = Config[item.Key]
            local prefix = state and "[ON]  " or "[OFF]  "
            local color = state and Config.MatchaAccent or Color3.fromRGB(150, 150, 150)
            
            txt.Text = prefix .. item.Text
            txt.Color = color
            txt.Position = Vector2.new(itemX, itemY)
            txt.Visible = true
            
            if mousePressed then
                if mousePos.X >= itemX and mousePos.X <= itemX + Menu.W and
                   mousePos.Y >= itemY and mousePos.Y <= itemY + 20 then
                    if not item.Clicked then
                        Config[item.Key] = not Config[item.Key]
                        SaveConfig()
                        item.Clicked = true
                    end
                else
                    item.Clicked = false
                end
            else
                item.Clicked = false
            end
        end
    else
        mBg.Visible = false
        mBorder.Visible = false
        mAccent.Visible = false
        mHeader.Visible = false
        mWater.Visible = false
        for _, txt in ipairs(mItems) do
            txt.Visible = false
        end
    end

    -- === RENDER ESP ===
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

print("[Spectre] Deepwoken ESP loaded. Press RightShift to open menu.")