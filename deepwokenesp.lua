--[[
    Deepwoken / Matcha External ESP (Production)
    ------------------------------------------------
    Based on LO's v2 mockup. Real data extraction, 
    3D to 2D camera projection, and live Deepwoken stat parsing.
    Matcha native UI, Drawing API, zero-instance footprint.
]]

local old = rawget(_G, "__DW_MATCHA_MOCK_ESP_V2") or rawget(_G, "__DW_MATCHA_MOCK_ESP")
if old and old.Unload then
    pcall(old.Unload)
end

assert(type(UI) == "table", "MatchaScripts UI binding is required")
assert(Drawing ~= nil, "Matcha Drawing API is required")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local STATE = {
    alive = true,
    conn = nil,
    lastTick = tick(),
    slots = {},
    hotkeys = {},
    theme = {},
    hud = {},
}
_G.__DW_MATCHA_MOCK_ESP_V2 = STATE

local EXEC_NAME, EXEC_VERSION = identifyexecutor()
local TAB_MAIN = "DW ESP v2"
local TAB_CFG  = "DW ESP Theme"

local FONT_ITEMS = {
    { name = "UI",         value = Drawing.Fonts.UI },
    { name = "System",     value = Drawing.Fonts.System },
    { name = "SystemBold", value = Drawing.Fonts.SystemBold },
    { name = "Monospace",  value = Drawing.Fonts.Monospace },
    { name = "Pixel",      value = Drawing.Fonts.Pixel },
    { name = "Fortnite",   value = Drawing.Fonts.Fortnite },
    { name = "Minecraft",  value = Drawing.Fonts.Minecraft },
}

local FONT_NAMES = {}
for i = 1, #FONT_ITEMS do
    FONT_NAMES[i] = FONT_ITEMS[i].name
end

local PALETTES = {
    {
        name = "Deep Mist",
        accent      = Color3.fromRGB(142, 188, 214),
        accentAlpha = 228,
        glass       = Color3.fromRGB(90, 110, 132),
        glassAlpha  = 56,
        shadow      = Color3.fromRGB(10, 16, 24),
        shadowAlpha = 164,
        text        = Color3.fromRGB(235, 241, 247),
        subtext     = Color3.fromRGB(164, 178, 193),
        hpHigh      = Color3.fromRGB(116, 225, 165),
        hpMid       = Color3.fromRGB(232, 188, 108),
        hpLow       = Color3.fromRGB(224, 100, 100),
        posture     = Color3.fromRGB(124, 221, 235),
        tempo       = Color3.fromRGB(183, 143, 236),
        food        = Color3.fromRGB(223, 184, 102),
        water       = Color3.fromRGB(110, 197, 235),
        tracer      = Color3.fromRGB(112, 162, 205),
        edge        = Color3.fromRGB(214, 231, 245),
        danger      = Color3.fromRGB(255, 123, 123),
    },
    {
        name = "Sea Glass",
        accent      = Color3.fromRGB(129, 220, 213),
        accentAlpha = 226,
        glass       = Color3.fromRGB(70, 102, 112),
        glassAlpha  = 52,
        shadow      = Color3.fromRGB(7, 14, 18),
        shadowAlpha = 160,
        text        = Color3.fromRGB(233, 248, 244),
        subtext     = Color3.fromRGB(161, 188, 183),
        hpHigh      = Color3.fromRGB(123, 243, 171),
        hpMid       = Color3.fromRGB(236, 199, 113),
        hpLow       = Color3.fromRGB(232, 109, 117),
        posture     = Color3.fromRGB(129, 232, 255),
        tempo       = Color3.fromRGB(178, 159, 244),
        food        = Color3.fromRGB(244, 196, 118),
        water       = Color3.fromRGB(107, 213, 245),
        tracer      = Color3.fromRGB(109, 185, 190),
        edge        = Color3.fromRGB(227, 244, 242),
        danger      = Color3.fromRGB(255, 132, 132),
    },
    {
        name = "Trial Ember",
        accent      = Color3.fromRGB(214, 173, 138),
        accentAlpha = 224,
        glass       = Color3.fromRGB(103, 84, 74),
        glassAlpha  = 48,
        shadow      = Color3.fromRGB(18, 12, 10),
        shadowAlpha = 168,
        text        = Color3.fromRGB(247, 236, 226),
        subtext     = Color3.fromRGB(197, 175, 158),
        hpHigh      = Color3.fromRGB(123, 232, 151),
        hpMid       = Color3.fromRGB(236, 194, 110),
        hpLow       = Color3.fromRGB(243, 113, 96),
        posture     = Color3.fromRGB(138, 214, 239),
        tempo       = Color3.fromRGB(201, 156, 241),
        food        = Color3.fromRGB(241, 188, 106),
        water       = Color3.fromRGB(122, 206, 245),
        tracer      = Color3.fromRGB(197, 142, 109),
        edge        = Color3.fromRGB(246, 225, 211),
        danger      = Color3.fromRGB(255, 124, 109),
    },
}

-- ==================== UTILITIES ====================
local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smooth(current, target, rate, dt)
    if current == nil then return target end
    local alpha = 1 - math.exp(-rate * dt)
    return current + (target - current) * alpha
end

local function colorLerp(a, b, t)
    return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end

local function alpha255(a)
    return clamp((a or 255) / 255, 0, 1)
end

local function safeCorner(obj, radius)
    pcall(function() obj.Corner = radius end)
end

local function getValue(id, fallback)
    local ok, value = pcall(UI.GetValue, id)
    if not ok or value == nil then return fallback end
    return value
end

local function setValue(id, value)
    pcall(UI.SetValue, id, value)
end

local function getFont(index, fallback)
    local idx = math.floor(tonumber(index) or fallback or 0) + 1
    local item = FONT_ITEMS[idx]
    if item then return item.value end
    return FONT_ITEMS[(fallback or 0) + 1].value
end

local function copyPalette(index)
    local p = PALETTES[index + 1] or PALETTES[1]
    STATE.theme.paletteIndex = index
    STATE.theme.paletteName  = p.name
    STATE.theme.accent       = p.accent
    STATE.theme.accentAlpha  = p.accentAlpha
    STATE.theme.glass        = p.glass
    STATE.theme.glassAlpha   = p.glassAlpha
    STATE.theme.shadow       = p.shadow
    STATE.theme.shadowAlpha  = p.shadowAlpha
    STATE.theme.text         = p.text
    STATE.theme.subtext      = p.subtext
    STATE.theme.hpHigh       = p.hpHigh
    STATE.theme.hpMid        = p.hpMid
    STATE.theme.hpLow        = p.hpLow
    STATE.theme.posture      = p.posture
    STATE.theme.tempo        = p.tempo
    STATE.theme.food         = p.food
    STATE.theme.water        = p.water
    STATE.theme.tracer       = p.tracer
    STATE.theme.edge         = p.edge
    STATE.theme.danger       = p.danger
end
copyPalette(0)

-- ==================== DRAWING WRAPPERS ====================
local function makeSquare(z)
    local sq = Drawing.new("Square")
    sq.Visible = false
    sq.Filled = true
    sq.ZIndex = z or 1
    safeCorner(sq, 10)
    return sq
end

local function makeLine(z, thickness)
    local ln = Drawing.new("Line")
    ln.Visible = false
    ln.ZIndex = z or 1
    ln.Thickness = thickness or 1
    return ln
end

local function makeText(z, size, font, center)
    local tx = Drawing.new("Text")
    tx.Visible = false
    tx.ZIndex = z or 1
    tx.Center = center ~= false
    tx.Outline = true
    tx.FontSize = size or 12
    tx.Font = font or Drawing.Fonts.System
    return tx
end

local function applySquare(sq, x, y, w, h, color, alpha, z, corner)
    sq.Position = Vector2.new(x, y)
    sq.Size = Vector2.new(math.max(1, w), math.max(1, h))
    sq.Color = color
    sq.Transparency = alpha
    sq.ZIndex = z or sq.ZIndex
    sq.Visible = true
    if corner then safeCorner(sq, corner) end
end

local function applyLine(ln, x1, y1, x2, y2, color, alpha, thickness, z)
    ln.From = Vector2.new(x1, y1)
    ln.To = Vector2.new(x2, y2)
    ln.Color = color
    ln.Transparency = alpha
    ln.Thickness = thickness or ln.Thickness
    ln.ZIndex = z or ln.ZIndex
    ln.Visible = true
end

local function applyText(tx, text, x, y, color, alpha, size, font, z, center)
    tx.Text = text
    tx.Position = Vector2.new(x, y)
    tx.Color = color
    tx.Transparency = alpha
    tx.FontSize = size or tx.FontSize
    tx.Font = font or tx.Font
    tx.ZIndex = z or tx.ZIndex
    tx.Center = center ~= false
    tx.Visible = true
end

local function hideObject(obj) obj.Visible = false end

local function makeSlot()
    return {
        anim = {},
        shadow       = makeSquare(1),
        shadow2      = makeSquare(1),
        panel        = makeSquare(2),
        panelEdge    = makeSquare(3),
        shine        = makeSquare(4),
        nameShadow   = makeSquare(4),
        namePanel    = makeSquare(5),
        nameEdge     = makeSquare(6),
        subline      = makeSquare(6),

        hpBg         = makeSquare(3),
        hpFill       = makeSquare(4),
        hpGlow       = makeSquare(3),
        poBg         = makeSquare(3),
        poFill       = makeSquare(4),
        poGlow       = makeSquare(3),

        tempoBg      = makeSquare(5),
        foodBg       = makeSquare(5),
        waterBg      = makeSquare(5),

        tracer       = makeLine(2, 1),
        tracerGlow   = makeLine(1, 2),

        name         = makeText(7, 15, Drawing.Fonts.SystemBold),
        tag          = makeText(7, 10, Drawing.Fonts.UI),
        level        = makeText(7, 11, Drawing.Fonts.Monospace),
        stats        = makeText(7, 11, Drawing.Fonts.Monospace),
        distance     = makeText(7, 11, Drawing.Fonts.Monospace),
        tempo        = makeText(7, 11, Drawing.Fonts.UI),
        food         = makeText(7, 11, Drawing.Fonts.UI),
        water        = makeText(7, 11, Drawing.Fonts.UI),

        offPanel     = makeSquare(6),
        offText      = makeText(7, 12, Drawing.Fonts.SystemBold),
        offStats     = makeText(7, 10, Drawing.Fonts.Monospace),
        off1         = makeLine(6, 2),
        off2         = makeLine(6, 2),
        off3         = makeLine(5, 4),

        br1          = makeLine(5, 1),
        br2          = makeLine(5, 1),
        br3          = makeLine(5, 1),
        br4          = makeLine(5, 1),
        br5          = makeLine(5, 1),
        br6          = makeLine(5, 1),
        br7          = makeLine(5, 1),
        br8          = makeLine(5, 1),
    }
end

local function hideSlot(slot)
    for k, obj in pairs(slot) do
        if k ~= "anim" then hideObject(obj) end
    end
end

local function destroySlot(slot)
    for k, obj in pairs(slot) do
        if k ~= "anim" then pcall(function() obj:Remove() end) end
    end
end

-- Pre-allocate 64 slots for performance
local MAX_PLAYERS = 64
for i = 1, MAX_PLAYERS do
    STATE.slots[i] = makeSlot()
end

STATE.hud = {
    shadow   = makeSquare(20),
    panel    = makeSquare(21),
    title    = makeText(22, 14, Drawing.Fonts.SystemBold, false),
    sub      = makeText(22, 11, Drawing.Fonts.Monospace, false),
    state    = makeText(22, 11, Drawing.Fonts.UI, false),
}

local function hideHud()
    for _, obj in pairs(STATE.hud) do hideObject(obj) end
end

local function destroyHud()
    for _, obj in pairs(STATE.hud) do pcall(function() obj:Remove() end) end
end

-- ==================== DEEPWOKEN DATA EXTRACTION ====================
local function getStat(character, player, name, fallback)
    local v = character:GetAttribute(name) or (player and player:GetAttribute(name))
    if v then return v end
    local obj = character:FindFirstChild(name)
    if obj and obj:IsA("NumberValue") then return obj.Value end
    return fallback
end

local function extractData(player)
    local char = player.Character
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
    local hpRatio = hum.Health / maxHp
    
    local maxPosture = getStat(char, player, "MaxPosture", 100)
    local posture = getStat(char, player, "Posture", 0)
    local poRatio = maxPosture > 0 and (posture / maxPosture) or 0

    local level = player:GetAttribute("Level") or 0
    if level == 0 then
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local l = ls:FindFirstChild("Level") or ls:FindFirstChild("Power")
            if l then level = tonumber(l.Value) or 0 end
        end
    end

    local name = hum.DisplayName ~= "" and hum.DisplayName or player.Name

    return {
        headPos = head.Position,
        rootPos = root.Position,
        dist = dist,
        hpRatio = hpRatio,
        hpCur = hum.Health,
        hpMax = maxHp,
        poRatio = poRatio,
        poCur = posture,
        tempo = getStat(char, player, "Tempo", 0),
        food = getStat(char, player, "Hunger", getStat(char, player, "Food", 0)),
        water = getStat(char, player, "Thirst", getStat(char, player, "Water", 0)),
        level = level,
        name = name,
    }
end

local function healthColor(ratio)
    if ratio >= 0.5 then
        return colorLerp(STATE.theme.hpMid, STATE.theme.hpHigh, (ratio - 0.5) / 0.5)
    end
    return colorLerp(STATE.theme.hpLow, STATE.theme.hpMid, ratio / 0.5)
end

-- ==================== CONFIG & THEME ====================
local function readConfig()
    local compact = getValue("dw_v2_compact", false)
    local cfg = {
        enabled         = getValue("dw_v2_enabled", true),
        animate         = getValue("dw_v2_animate", true),
        compact         = compact,
        scale           = clamp(getValue("dw_v2_scale", 1.00), 0.75, 1.55),
        boxHeight       = clamp(math.floor(getValue("dw_v2_height", compact and 150 or 176)), 115, 270),
        widthFactor     = clamp(getValue("dw_v2_width", compact and 0.38 or 0.43), 0.30, 0.62),
        barWidth        = clamp(math.floor(getValue("dw_v2_bar_width", compact and 4 or 5)), 2, 12),
        barGap          = clamp(math.floor(getValue("dw_v2_bar_gap", compact and 7 or 9)), 3, 18),
        bodyPad         = clamp(math.floor(getValue("dw_v2_body_pad", compact and 5 or 7)), 2, 16),
        nameOffset      = clamp(math.floor(getValue("dw_v2_name_offset", compact and 30 or 37)), 18, 64),
        footOffset      = clamp(math.floor(getValue("dw_v2_foot_offset", compact and 15 or 19)), 8, 40),
        showBody        = getValue("dw_v2_show_body", true),
        showShine       = getValue("dw_v2_show_shine", true),
        showBrackets    = getValue("dw_v2_show_brackets", true),
        showNames       = getValue("dw_v2_show_names", true),
        showLevel       = getValue("dw_v2_show_level", true),
        showStats       = getValue("dw_v2_show_stats", true),
        showResources   = getValue("dw_v2_show_resources", true),
        showHpBar       = getValue("dw_v2_show_hp_bar", true),
        showPosture     = getValue("dw_v2_show_posture", true),
        showShadow      = getValue("dw_v2_show_shadow", true),
        tracer          = getValue("dw_v2_tracer", true),
        tracerFrom      = getValue("dw_v2_tracer_from", 0),
        offscreen       = getValue("dw_v2_offscreen", true),
        offscreenNames  = getValue("dw_v2_offscreen_names", true),
        titleFont       = getFont(getValue("dw_v2_font_title", 2), 2),
        statFont        = getFont(getValue("dw_v2_font_stat", 3), 3),
        resourceFont    = getFont(getValue("dw_v2_font_resource", 0), 0),
        watermark       = getValue("dw_v2_watermark", true),
        focusPulse      = getValue("dw_v2_focus_hold", false),
        sectionTag      = tostring(getValue("dw_v2_tag", "DEEPWOKEN") or "DEEPWOKEN"),
    }
    return cfg
end

local function applyPresetDefaults(index)
    copyPalette(index)
    setValue("dw_v2_palette", index)
end

local function resetDefaults()
    setValue("dw_v2_enabled", true)
    setValue("dw_v2_animate", true)
    setValue("dw_v2_compact", false)
    setValue("dw_v2_scale", 1.00)
    setValue("dw_v2_height", 176)
    setValue("dw_v2_width", 0.43)
    setValue("dw_v2_bar_width", 5)
    setValue("dw_v2_bar_gap", 9)
    setValue("dw_v2_body_pad", 7)
    setValue("dw_v2_name_offset", 37)
    setValue("dw_v2_foot_offset", 19)
    setValue("dw_v2_show_body", true)
    setValue("dw_v2_show_shine", true)
    setValue("dw_v2_show_brackets", true)
    setValue("dw_v2_show_names", true)
    setValue("dw_v2_show_level", true)
    setValue("dw_v2_show_stats", true)
    setValue("dw_v2_show_resources", true)
    setValue("dw_v2_show_hp_bar", true)
    setValue("dw_v2_show_posture", true)
    setValue("dw_v2_show_shadow", true)
    setValue("dw_v2_tracer", true)
    setValue("dw_v2_tracer_from", 0)
    setValue("dw_v2_offscreen", true)
    setValue("dw_v2_offscreen_names", true)
    setValue("dw_v2_font_title", 2)
    setValue("dw_v2_font_stat", 3)
    setValue("dw_v2_font_resource", 0)
    setValue("dw_v2_watermark", true)
    setValue("dw_v2_tag", "DEEPWOKEN")
    applyPresetDefaults(0)
end

local function drawBrackets(slot, x1, y1, x2, y2, color, alpha, thickness, len)
    applyLine(slot.br1, x1, y1, x1 + len, y1, color, alpha, thickness, 5)
    applyLine(slot.br2, x1, y1, x1, y1 + len, color, alpha, thickness, 5)
    applyLine(slot.br3, x2, y1, x2 - len, y1, color, alpha, thickness, 5)
    applyLine(slot.br4, x2, y1, x2, y1 + len, color, alpha, thickness, 5)
    applyLine(slot.br5, x1, y2, x1 + len, y2, color, alpha, thickness, 5)
    applyLine(slot.br6, x1, y2, x1, y2 - len, color, alpha, thickness, 5)
    applyLine(slot.br7, x2, y2, x2 - len, y2, color, alpha, thickness, 5)
    applyLine(slot.br8, x2, y2, x2, y2 - len, color, alpha, thickness, 5)
end

-- ==================== RENDER LOGIC ====================
local function renderOffscreen(slot, cfg, viewport, cx, cy, name, level, dist, hpRatio)
    if not cfg.offscreen then return end

    local centerX = viewport.X * 0.5
    local centerY = viewport.Y * 0.5
    local dx = cx - centerX
    local dy = cy - centerY
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag < 0.001 then mag = 1 end
    dx = dx / mag
    dy = dy / mag

    local margin = cfg.compact and 36 or 48
    local edgeX = clamp(centerX + dx * (centerX - margin), margin, viewport.X - margin)
    local edgeY = clamp(centerY + dy * (centerY - margin), margin, viewport.Y - margin)

    local perpX = -dy
    local perpY = dx
    local tipX = edgeX
    local tipY = edgeY
    local baseX = tipX - dx * 20
    local baseY = tipY - dy * 20
    local wing = cfg.compact and 7 or 9

    local hpColor = healthColor(hpRatio)
    local arrowColor = colorLerp(STATE.theme.accent, hpColor, 0.30)

    applyLine(slot.off3, baseX, baseY, tipX, tipY, arrowColor, 0.28, 5, 5)
    applyLine(slot.off1, baseX + perpX * wing, baseY + perpY * wing, tipX, tipY, arrowColor, 0.98, 2, 6)
    applyLine(slot.off2, baseX - perpX * wing, baseY - perpY * wing, tipX, tipY, arrowColor, 0.98, 2, 6)

    if cfg.offscreenNames then
        local labelW = cfg.compact and 108 or 126
        local labelH = cfg.compact and 28 or 34
        local labelX = baseX - labelW * 0.5 - dx * 4
        local labelY = baseY - labelH * 0.5 - dy * 4
        applySquare(slot.offPanel, labelX, labelY, labelW, labelH, STATE.theme.shadow, 0.48, 6, 11)
        applyText(slot.offText, name, labelX + labelW * 0.5, labelY + (cfg.compact and 8 or 10), STATE.theme.text, 1, cfg.compact and 11 or 12, cfg.titleFont, 7)
        applyText(slot.offStats, string.format("LVL %d · %dst", level, dist), labelX + labelW * 0.5, labelY + (cfg.compact and 18 or 22), STATE.theme.subtext, 1, 10, cfg.statFont, 7)
    end
end

local function renderOnscreen(slot, data, cfg, viewport, dt, t, index)
    -- Real 3D to 2D projection
    local headScreen, headOnScreen = Camera:WorldToViewportPoint(data.headPos)
    local feetScreen, feetScreenOn = Camera:WorldToViewportPoint(data.rootPos - Vector3.new(0, 3, 0))

    -- Calculate target X, Y, H, W
    local targetX = (headScreen.X + feetScreen.X) * 0.5
    local targetY = headScreen.Y
    local targetH = math.abs(feetScreen.Y - headScreen.Y)
    if targetH < 10 then targetH = 10 end
    local targetW = targetH * cfg.widthFactor
    local targetDist = data.dist

    local anim = slot.anim
    anim.x = smooth(anim.x, targetX, 10, dt)
    anim.y = smooth(anim.y, targetY, 10, dt)
    anim.h = smooth(anim.h, targetH, 12, dt)
    anim.w = smooth(anim.w, targetW, 12, dt)
    anim.hp = smooth(anim.hp, data.hpRatio, 8, dt)
    anim.po = smooth(anim.po, data.poRatio, 8, dt)
    anim.dist = smooth(anim.dist, targetDist, 7, dt)
    anim.tempo = smooth(anim.tempo, data.tempo, 8, dt)
    anim.food = smooth(anim.food, data.food, 8, dt)
    anim.water = smooth(anim.water, data.water, 8, dt)
    anim.hpCur = smooth(anim.hpCur, data.hpCur, 10, dt)
    anim.hpMax = smooth(anim.hpMax, data.hpMax, 10, dt)
    anim.poCur = smooth(anim.poCur, data.poCur, 10, dt)

    local cx = anim.x
    local cy = anim.y
    local h = anim.h * cfg.scale
    local w = anim.w * cfg.scale
    local x1 = cx - w * 0.5
    local x2 = cx + w * 0.5
    local y1 = cy - h * 0.52
    local y2 = cy + h * 0.48
    local onScreen = headOnScreen and feetScreenOn

    -- Offscreen logic
    if not onScreen then
        if cfg.offscreen then
            renderOffscreen(slot, cfg, viewport, cx, cy, data.name, data.level, math.floor(anim.dist + 0.5), anim.hp)
        else
            hideSlot(slot)
        end
        return
    end

    -- Unhide and render onscreen
    hideSlot(slot)

    local accent = STATE.theme.accent
    local accentA = alpha255(STATE.theme.accentAlpha)
    local glass = STATE.theme.glass
    local glassA = alpha255(STATE.theme.glassAlpha)
    local shadow = STATE.theme.shadow
    local shadowA = alpha255(STATE.theme.shadowAlpha)
    local text = STATE.theme.text
    local subtext = STATE.theme.subtext
    local edge = STATE.theme.edge

    if cfg.focusPulse then
        local pulse = 0.5 + 0.5 * math.sin(t * 3.2 + index * 0.7)
        accent = colorLerp(accent, edge, pulse * 0.22)
        accentA = clamp(accentA + pulse * 0.08, 0, 1)
        glassA = clamp(glassA + pulse * 0.03, 0, 1)
    end

    local pad = cfg.bodyPad
    local compactShrink = cfg.compact and 0.92 or 1.0
    local nameW = math.max(cfg.compact and 134 or 152, w + (cfg.compact and 22 or 30))
    local nameH = cfg.compact and 34 or 40
    local nameX = cx - nameW * 0.5
    local nameY = y1 - cfg.nameOffset
    local lineW = nameW - (cfg.compact and 20 or 24)
    local brLen = math.floor(math.min(cfg.compact and 14 or 18, w * 0.25))

    local hpColor = healthColor(anim.hp)
    local poColor = colorLerp(STATE.theme.posture, edge, anim.po * 0.12)

    if cfg.showShadow then
        applySquare(slot.shadow, x1 - pad - 8, y1 - 5, w + (pad + 8) * 2, h + 10, shadow, shadowA * 0.30, 1, 16)
        applySquare(slot.shadow2, x1 - pad - 3, y1 - 1, w + (pad + 3) * 2, h + 2, shadow, shadowA * 0.52, 1, 14)
        applySquare(slot.nameShadow, nameX - 3, nameY - 3, nameW + 6, nameH + 6, shadow, shadowA * 0.46, 4, 16)
    end

    if cfg.tracer then
        local fromX, fromY
        if cfg.tracerFrom == 0 then
            fromX, fromY = viewport.X * 0.5, viewport.Y - 28
        elseif cfg.tracerFrom == 1 then
            fromX, fromY = viewport.X * 0.5, viewport.Y * 0.5
        else
            fromX, fromY = viewport.X * 0.5, 24
        end
        applyLine(slot.tracerGlow, fromX, fromY, cx, y2 + 6, STATE.theme.tracer, 0.18, 3, 1)
        applyLine(slot.tracer, fromX, fromY, cx, y2 + 6, STATE.theme.tracer, 0.74, 1, 2)
    end

    if cfg.showBody then
        applySquare(slot.panel, x1 - pad, y1, w + pad * 2, h, glass, glassA, 2, 14)
        applySquare(slot.panelEdge, x1 - pad, y1, w + pad * 2, 1, accent, accentA * 0.90, 3, 4)
    end

    if cfg.showShine then
        local shineW = math.max(24, (w + pad * 2) * 0.54 * compactShrink)
        applySquare(slot.shine, x1 - pad + 8, y1 + 5, shineW, 2, edge, 0.38, 4, 4)
    end

    applySquare(slot.namePanel, nameX, nameY, nameW, nameH, glass, clamp(glassA + 0.05, 0, 1), 5, 15)
    applySquare(slot.nameEdge, nameX + 10, nameY + 6, lineW, 1, accent, accentA * 0.95, 6, 2)
    applySquare(slot.subline, nameX + 10, nameY + nameH - 7, lineW * 0.78, 1, edge, 0.12, 6, 2)

    if cfg.showHpBar then
        local bx = x1 - cfg.barGap - cfg.barWidth
        applySquare(slot.hpBg, bx, y1, cfg.barWidth, h, shadow, 0.60, 3, 5)
        local fh = math.max(1, math.floor(h * anim.hp))
        applySquare(slot.hpGlow, bx - 1, y2 - fh, cfg.barWidth + 2, fh, hpColor, 0.18, 3, 5)
        applySquare(slot.hpFill, bx, y2 - fh, cfg.barWidth, fh, hpColor, 0.98, 4, 5)
    end

    if cfg.showPosture then
        local bx = x2 + cfg.barGap
        applySquare(slot.poBg, bx, y1, cfg.barWidth, h, shadow, 0.60, 3, 5)
        local fh = math.max(1, math.floor(h * anim.po))
        applySquare(slot.poGlow, bx - 1, y2 - fh, cfg.barWidth + 2, fh, poColor, 0.17, 3, 5)
        applySquare(slot.poFill, bx, y2 - fh, cfg.barWidth, fh, poColor, 0.96, 4, 5)
    end

    if cfg.showBrackets then
        drawBrackets(slot, x1, y1, x2, y2, accent, cfg.compact and 0.70 or 0.84, cfg.compact and 1 or 2, brLen)
    end

    if cfg.showNames then
        applyText(slot.tag, cfg.sectionTag, nameX + 34, nameY + 9, accent, accentA, 10, Drawing.Fonts.UI, 7)
        applyText(slot.name, data.name, cx, nameY + (cfg.compact and 10 or 12), text, 1, cfg.compact and 13 or 15, cfg.titleFont, 7)
    end

    if cfg.showLevel and data.level > 0 then
        applyText(slot.level, string.format("LVL %d", data.level), nameX + nameW - 28, nameY + 9, subtext, 1, 11, cfg.statFont, 7)
    end

    if cfg.showStats then
        applyText(
            slot.stats,
            string.format("HP %d/%d  ·  POST %d  ·  %dst", math.floor(anim.hpCur + 0.5), math.floor(anim.hpMax + 0.5), math.floor(anim.poCur + 0.5), math.floor(anim.dist + 0.5)),
            cx,
            nameY + (cfg.compact and 24 or 28),
            subtext,
            1,
            11,
            cfg.statFont,
            7
        )
    end

    applyText(slot.distance, string.format("%dst", math.floor(anim.dist + 0.5)), cx, y2 + 7, STATE.theme.tracer, 0.92, 10, cfg.statFont, 7)

    if cfg.showResources then
        local py = y2 + cfg.footOffset
        local pillW = cfg.compact and 58 or 64
        local pillH = cfg.compact and 16 or 18
        local gap = cfg.compact and 6 or 8
        local leftX = cx - pillW * 1.5 - gap
        local midX  = cx - pillW * 0.5
        local rightX = cx + pillW * 0.5 + gap

        applySquare(slot.tempoBg, leftX, py, pillW, pillH, shadow, 0.36, 5, 9)
        applySquare(slot.foodBg, midX, py, pillW, pillH, shadow, 0.36, 5, 9)
        applySquare(slot.waterBg, rightX, py, pillW, pillH, shadow, 0.36, 5, 9)

        applyText(slot.tempo, string.format("TP %d", math.floor(anim.tempo + 0.5)), leftX + pillW * 0.5, py + 4, STATE.theme.tempo, 1, 10, cfg.resourceFont, 7)
        applyText(slot.food,  string.format("FD %d", math.floor(anim.food + 0.5)),  midX + pillW * 0.5, py + 4, STATE.theme.food, 1, 10, cfg.resourceFont, 7)
        applyText(slot.water, string.format("WT %d", math.floor(anim.water + 0.5)), rightX + pillW * 0.5, py + 4, STATE.theme.water, 1, 10, cfg.resourceFont, 7)
    end
end

local function renderHud(cfg, viewport)
    if not cfg.watermark then
        hideHud()
        return
    end

    local x = 22
    local y = 22
    applySquare(STATE.hud.shadow, x - 4, y - 4, 250, 54, STATE.theme.shadow, 0.50, 20, 14)
    applySquare(STATE.hud.panel, x, y, 242, 46, STATE.theme.glass, clamp(alpha255(STATE.theme.glassAlpha) + 0.04, 0, 1), 21, 14)
    applyText(STATE.hud.title, "Deepwoken Matcha ESP v2", x + 12, y + 8, STATE.theme.text, 1, 14, Drawing.Fonts.SystemBold, 22, false)
    applyText(STATE.hud.sub, string.format("%s • %s • %dx%d", STATE.theme.paletteName or "Deep Mist", cfg.compact and "compact" or "glass", viewport.X, viewport.Y), x + 12, y + 24, STATE.theme.subtext, 1, 11, Drawing.Fonts.Monospace, 22, false)
    applyText(STATE.hud.state, string.format("%s %s", EXEC_NAME, EXEC_VERSION), x + 168, y + 8, STATE.theme.accent, alpha255(STATE.theme.accentAlpha), 10, Drawing.Fonts.UI, 22, false)
end

-- ==================== MATCHA UI ====================
pcall(function() UI.RemoveTab(TAB_MAIN) end)
pcall(function() UI.RemoveTab(TAB_CFG) end)

UI.AddTab(TAB_MAIN, function(tab)
    local secL = tab:Section("Overlay", "Left", {"General", "Layout", "Elements", "Offscreen"}, 460)

    if secL.page == 0 then
        secL:Toggle("dw_v2_enabled", "Enabled", true)
        secL:Toggle("dw_v2_animate", "Smooth animation", true)
        secL:Toggle("dw_v2_compact", "Compact mode", false)
        secL:Toggle("dw_v2_watermark", "Watermark", true)
        secL:SliderFloat("dw_v2_scale", "Global scale", 0.75, 1.55, 1.00, "%.2f")
        local kb = secL:Keybind("dw_v2_focus_hold", 0x46, "hold")
        if not STATE.hotkeys.focus then
            pcall(function() kb:AddToHotkey("Glass focus", "dw_v2_enabled") end)
            STATE.hotkeys.focus = true
        end
    elseif secL.page == 1 then
        secL:SliderInt("dw_v2_height", "Base height", 115, 270, 176)
        secL:SliderFloat("dw_v2_width", "Width factor", 0.30, 0.62, 0.43, "%.2f")
        secL:SliderInt("dw_v2_body_pad", "Body padding", 2, 16, 7)
        secL:SliderInt("dw_v2_name_offset", "Name offset", 18, 64, 37)
        secL:SliderInt("dw_v2_foot_offset", "Foot text offset", 8, 40, 19)
        secL:SliderInt("dw_v2_bar_width", "Bar width", 2, 12, 5)
        secL:SliderInt("dw_v2_bar_gap", "Bar gap", 3, 18, 9)
    elseif secL.page == 2 then
        secL:Toggle("dw_v2_show_body", "Glass body panel", true)
        secL:Toggle("dw_v2_show_shine", "Top shine", true)
        secL:Toggle("dw_v2_show_shadow", "Soft shadows", true)
        secL:Toggle("dw_v2_show_brackets", "Corner brackets", true)
        secL:Toggle("dw_v2_show_names", "Names", true)
        secL:Toggle("dw_v2_show_level", "Levels", true)
        secL:Toggle("dw_v2_show_stats", "HP posture distance text", true)
        secL:Toggle("dw_v2_show_resources", "Tempo food water pills", true)
        secL:Toggle("dw_v2_show_hp_bar", "HP bar", true)
        secL:Toggle("dw_v2_show_posture", "Posture bar", true)
    elseif secL.page == 3 then
        secL:Toggle("dw_v2_tracer", "Distance tracer line", true)
        secL:Combo("dw_v2_tracer_from", "Tracer origin", {"Bottom", "Center", "Top"}, 0)
        secL:Toggle("dw_v2_offscreen", "Offscreen arrows", true)
        secL:Toggle("dw_v2_offscreen_names", "Offscreen labels", true)
        secL:InputText("dw_v2_tag", "Tag", "DEEPWOKEN")
    end

    local secR = tab:Section("Typography", "Right", {"Fonts", "Preset", "Actions"}, 460)
    if secR.page == 0 then
        secR:Combo("dw_v2_font_title", "Title font", FONT_NAMES, 2)
        secR:Combo("dw_v2_font_stat", "Stat font", FONT_NAMES, 3)
        secR:Combo("dw_v2_font_resource", "Resource font", FONT_NAMES, 0)
    elseif secR.page == 1 then
        secR:Combo("dw_v2_palette", "Palette", {PALETTES[1].name, PALETTES[2].name, PALETTES[3].name}, 0, function(index)
            applyPresetDefaults(index)
            notify("Palette applied", TAB_CFG, 2)
        end)
    elseif secR.page == 2 then
        secR:Button("Reset all defaults", 156, 26, function()
            resetDefaults()
            notify("v2 defaults restored", TAB_MAIN, 3)
        end)
        secR:Button("Hide overlay", 156, 26, function()
            setValue("dw_v2_enabled", false)
        end)
        secR:Button("Show overlay", 156, 26, function()
            setValue("dw_v2_enabled", true)
        end)
    end
end)

UI.AddTab(TAB_CFG, function(tab)
    local secL = tab:Section("Theme", "Left", {"Glass", "Accent", "Shadow"}, 460)

    if secL.page == 0 then
        secL:ColorPicker("dw_v2_glass", STATE.theme.glass.R * 255, STATE.theme.glass.G * 255, STATE.theme.glass.B * 255, STATE.theme.glassAlpha, function(color, alpha)
            STATE.theme.glass = color
            STATE.theme.glassAlpha = alpha
        end)
        secL:Button("Reset glass", 140, 24, function()
            local p = PALETTES[(STATE.theme.paletteIndex or 0) + 1] or PALETTES[1]
            STATE.theme.glass = p.glass
            STATE.theme.glassAlpha = p.glassAlpha
            notify("Glass tint reset", TAB_CFG, 2)
        end)
    elseif secL.page == 1 then
        secL:ColorPicker("dw_v2_accent", STATE.theme.accent.R * 255, STATE.theme.accent.G * 255, STATE.theme.accent.B * 255, STATE.theme.accentAlpha, function(color, alpha)
            STATE.theme.accent = color
            STATE.theme.accentAlpha = alpha
        end)
        secL:Button("Reset accent", 140, 24, function()
            local p = PALETTES[(STATE.theme.paletteIndex or 0) + 1] or PALETTES[1]
            STATE.theme.accent = p.accent
            STATE.theme.accentAlpha = p.accentAlpha
            notify("Accent tint reset", TAB_CFG, 2)
        end)
    elseif secL.page == 2 then
        secL:ColorPicker("dw_v2_shadow", STATE.theme.shadow.R * 255, STATE.theme.shadow.G * 255, STATE.theme.shadow.B * 255, STATE.theme.shadowAlpha, function(color, alpha)
            STATE.theme.shadow = color
            STATE.theme.shadowAlpha = alpha
        end)
        secL:Button("Reset shadow", 140, 24, function()
            local p = PALETTES[(STATE.theme.paletteIndex or 0) + 1] or PALETTES[1]
            STATE.theme.shadow = p.shadow
            STATE.theme.shadowAlpha = p.shadowAlpha
            notify("Shadow tint reset", TAB_CFG, 2)
        end)
    end

    local secR = tab:Section("Session", "Right", {"Info", "Helpers"}, 460)
    if secR.page == 0 then
        secR:InputText("dw_v2_info_mode", "Mode", "External Live ESP")
        secR:InputText("dw_v2_info_exec", "Executor", string.format("%s %s", EXEC_NAME, EXEC_VERSION))
    elseif secR.page == 1 then
        secR:Button("Notify loaded", 160, 26, function()
            notify("Deepwoken Matcha ESP v2 active", TAB_MAIN, 3)
        end)
        secR:Button("Preset Deep Mist", 160, 26, function()
            applyPresetDefaults(0)
            notify("Deep Mist preset applied", TAB_CFG, 2)
        end)
        secR:Button("Preset Sea Glass", 160, 26, function()
            applyPresetDefaults(1)
            notify("Sea Glass preset applied", TAB_CFG, 2)
        end)
        secR:Button("Preset Trial Ember", 160, 26, function()
            applyPresetDefaults(2)
            notify("Trial Ember preset applied", TAB_CFG, 2)
        end)
    end
end)

function STATE.Unload()
    STATE.alive = false
    if STATE.conn then
        pcall(function() STATE.conn:Disconnect() end)
        STATE.conn = nil
    end
    for i = 1, #STATE.slots do
        destroySlot(STATE.slots[i])
    end
    destroyHud()
    pcall(function() UI.RemoveTab(TAB_MAIN) end)
    pcall(function() UI.RemoveTab(TAB_CFG) end)
    _G.__DW_MATCHA_MOCK_ESP_V2 = nil
end

-- ==================== MAIN LOOP ====================
STATE.conn = RunService.RenderStepped:Connect(function()
    if not STATE.alive then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local now = tick()
    local dt = clamp(now - (STATE.lastTick or now), 0.001, 0.05)
    STATE.lastTick = now

    local viewport = camera.ViewportSize
    local cfg = readConfig()

    if not cfg.enabled then
        for i = 1, #STATE.slots do
            hideSlot(STATE.slots[i])
        end
        hideHud()
        return
    end

    renderHud(cfg, viewport)

    local players = Players:GetPlayers()
    local slotIdx = 1

    for _, player in ipairs(players) do
        if player ~= LocalPlayer then
            local data = extractData(player)
            if data and slotIdx <= MAX_PLAYERS then
                renderOnscreen(STATE.slots[slotIdx], data, cfg, viewport, dt, now, slotIdx)
                slotIdx = slotIdx + 1
            end
        end
    end

    -- Hide unused slots
    for i = slotIdx, MAX_PLAYERS do
        hideSlot(STATE.slots[i])
    end
end)

notify("Loaded Deepwoken Matcha ESP v2", TAB_MAIN, 4)