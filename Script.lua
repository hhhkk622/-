-- ============================================================
-- 1. 加载 WindUI 库
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ============================================================
-- 2. 原有功能逻辑（保持不变）
-- ============================================================
local p = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Cam = workspace.CurrentCamera
local TeleportService = game:GetService("TeleportService")

-- ---- 获取角色 ----
local function getChar()
    local c = p.Character
    if c then
        return c, c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart")
    end
    return nil, nil, nil
end

local c, h, r = getChar()
if not h or not r then
    p.CharacterAdded:Wait()
    c, h, r = getChar()
end

-- ---- 状态变量 ----
local invisible = false
local getItemsEnabled = false
local speedToggle = false
local espEnabled = false
local spinning = false
local spinSpeed = 180
local spinGyro = nil
local spinConnection = nil
local invisibleParts = {}
local nameTagsHidden = {}
local clonedTools = {}
local teleportGui = nil

-- ---- 核心功能函数（所有Toggle的回调） ----
local function toggleInvisible()
    invisible = not invisible
    local char = p.Character
    if not char then return end
    if invisible then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part:SetAttribute("OriginalTransparency", part.Transparency)
                part.Transparency = 1
                table.insert(invisibleParts, part)
            end
        end
        local head = char:FindFirstChild("Head")
        if head then
            if head:FindFirstChild("face") then head.face.Transparency = 1 end
            for _, child in ipairs(head:GetChildren()) do
                if child:IsA("BillboardGui") then
                    child:SetAttribute("OriginalEnabled", child.Enabled)
                    child.Enabled = false
                    table.insert(nameTagsHidden, child)
                end
            end
        end
    else
        for _, part in ipairs(invisibleParts) do
            if part and part.Parent then
                local origTrans = part:GetAttribute("OriginalTransparency")
                if origTrans ~= nil then
                    part.Transparency = origTrans
                    part:SetAttribute("OriginalTransparency", nil)
                end
            end
        end
        table.clear(invisibleParts)
        local head = char:FindFirstChild("Head")
        if head then
            if head:FindFirstChild("face") then head.face.Transparency = 0 end
        end
        for _, tag in ipairs(nameTagsHidden) do
            if tag and tag.Parent then
                local origEnabled = tag:GetAttribute("OriginalEnabled")
                if origEnabled ~= nil then
                    tag.Enabled = origEnabled
                    tag:SetAttribute("OriginalEnabled", nil)
                end
            end
        end
        table.clear(nameTagsHidden)
    end
end

local function toggleSpeed()
    speedToggle = not speedToggle
    h.WalkSpeed = speedToggle and 50 or 16
end

local NEARBY_RANGE = 50
local function collectNearbyItems()
    for _, tool in ipairs(clonedTools) do
        if tool and tool.Parent then tool:Destroy() end
    end
    table.clear(clonedTools)
    local myRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= p and player.Character then
            local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot and (myRoot.Position - otherRoot.Position).Magnitude <= NEARBY_RANGE then
                for _, obj in ipairs(player.Character:GetDescendants()) do
                    if obj:IsA("Tool") then
                        local clone = obj:Clone()
                        clone.Parent = p.Backpack
                        table.insert(clonedTools, clone)
                    end
                end
            end
        end
    end
end

local function toggleGetItems()
    getItemsEnabled = not getItemsEnabled
    if getItemsEnabled then
        collectNearbyItems()
        task.spawn(function()
            while getItemsEnabled do
                collectNearbyItems()
                task.wait(1)
            end
        end)
    else
        for _, tool in ipairs(clonedTools) do
            if tool and tool.Parent then tool:Destroy() end
        end
        table.clear(clonedTools)
    end
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        local char = p.Character
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if char and obj:IsDescendantOf(char) then continue end
                if obj:GetAttribute("OriginalTransparency") == nil then
                    obj:SetAttribute("OriginalTransparency", obj.Transparency)
                end
                obj.Transparency = 0.7
            end
        end
    else
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local origTrans = obj:GetAttribute("OriginalTransparency")
                if origTrans ~= nil then
                    obj.Transparency = origTrans
                    obj:SetAttribute("OriginalTransparency", nil)
                end
            end
        end
    end
end

local function showTeleportList()
    if teleportGui then teleportGui:Destroy() end
    teleportGui = Instance.new("ScreenGui")
    teleportGui.Name = "TeleportGUI"
    teleportGui.Parent = p:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 250)
    frame.Position = UDim2.new(0.5, -100, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 30
    local fcorner = Instance.new("UICorner")
    fcorner.CornerRadius = UDim.new(0, 10)
    fcorner.Parent = frame
    frame.Parent = teleportGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "选择玩家传送"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 31
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(0.9, 0, 0, 200)
    scroll.Position = UDim2.new(0.05, 0, 0.15, 0)
    scroll.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    scroll.BackgroundTransparency = 0.5
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 31
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.Name
    layout.Parent = scroll

    local players = game.Players:GetPlayers()
    local yCount = 0
    for _, player in ipairs(players) do
        if player ~= p then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, 25)
            btn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = player.Name
            btn.TextScaled = true
            btn.Font = Enum.Font.Gotham
            btn.ZIndex = 32
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 4)
            bc.Parent = btn
            btn.Parent = scroll

            btn.MouseButton1Click:Connect(function()
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local myChar = p.Character
                    if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                        myChar:SetPrimaryPartCFrame(char.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
                    end
                end
                teleportGui:Destroy()
                teleportGui = nil
            end)
            yCount = yCount + 1
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, yCount * 30)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(0.88, 0, 0.02, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 33
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 4)
    cc.Parent = closeBtn
    closeBtn.Parent = frame

    closeBtn.MouseButton1Click:Connect(function()
        teleportGui:Destroy()
        teleportGui = nil
    end)
end

local function toggleTeleport()
    showTeleportList()
end

local function startSpin()
    if spinConnection then spinConnection:Disconnect() end
    if spinGyro then spinGyro:Destroy() end
    local root = r
    if not root then return end
    spinGyro = Instance.new("BodyGyro")
    spinGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    spinGyro.CFrame = root.CFrame
    spinGyro.Parent = root
    spinConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not spinning or not spinGyro or not spinGyro.Parent then
            spinConnection:Disconnect()
            spinConnection = nil
            return
        end
        local char, _, root = getChar()
        if root then
            spinGyro.Parent = root
            local rotation = deltaTime * math.rad(spinSpeed)
            spinGyro.CFrame = spinGyro.CFrame * CFrame.Angles(0, rotation, 0)
        end
    end)
end

local function stopSpin()
    if spinConnection then spinConnection:Disconnect(); spinConnection = nil end
    if spinGyro then spinGyro:Destroy(); spinGyro = nil end
end

local function toggleSpin()
    spinning = not spinning
    if spinning then startSpin() else stopSpin() end
end

local function rejoinServer()
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)
    if not success then
        pcall(function()
            TeleportService:Teleport(game.PlaceId)
        end)
    end
end

-- ---- 角色重生重置（重置所有状态和Toggle） ----
local toggleRefs = {}

p.CharacterAdded:Connect(function(newChar)
    c = newChar
    h = c:WaitForChild("Humanoid")
    r = c:WaitForChild("HumanoidRootPart")
    invisible = false
    getItemsEnabled = false
    speedToggle = false
    espEnabled = false
    spinning = false
    h.WalkSpeed = 16
    if teleportGui then teleportGui:Destroy(); teleportGui = nil end
    if spinConnection then spinConnection:Disconnect(); spinConnection = nil end
    if spinGyro then spinGyro:Destroy(); spinGyro = nil end
    for _, tool in ipairs(clonedTools) do
        if tool and tool.Parent then tool:Destroy() end
    end
    table.clear(clonedTools)
    table.clear(invisibleParts)
    table.clear(nameTagsHidden)
    for _, toggle in ipairs(toggleRefs) do
        toggle:SetValue(false)
    end
end)

-- ============================================================
-- 3. 使用 WindUI 创建主界面
-- ============================================================

local Window = WindUI:CreateWindow({
    Title = "BALL HUB",
    Icon = "gamepad-2",
    Author = "hhhkk6224",
    Folder = "BallHub",
    Size = UDim2.fromOffset(480, 420),
    Transparent = false,
    Theme = "Dark",
    SideBarWidth = 140,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "BALL HUB",
    Icon = "gamepad-2",
    CornerRadius = UDim.new(0, 12),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(180, 80, 255), Color3.fromRGB(120, 50, 200)),
    Draggable = true,
})

local Tabs = {}

Tabs.Announce = Window:Tab({
    Title = "最新公告",
    Icon = "megaphone",
    ShowTabTitle = true,
})

Tabs.General = Window:Tab({
    Title = "通用",
    Icon = "zap",
    ShowTabTitle = true,
})

Tabs.ServerScripts = Window:Tab({
    Title = "服务器脚本",
    Icon = "cloud-lightning",
    ShowTabTitle = true,
})

Tabs.Other = Window:Tab({
    Title = "其他脚本",
    Icon = "box",
    ShowTabTitle = true,
})

-- ---- 公告 ----
local ANNOUNCE_TEXT = [[
欢迎BALL HUB！ 脚本仍属于测试阶段
制作人Roblox名字：hhhkk6224
QQ群：687742398
b站：阿轲欣妍

功能分类：
通用：隐身 / 附近道具 / 加速 / 透视 / 传送 / 旋转 / 飞行 / 炉管r15 / 炉管r6 / VR脚本FE / 飞踢 / 火车头 / 重新加入 / 子弹追踪 / IY脚本 / 自瞄 / 操控物体 / FE动作脚本 / 延迟脚本 / 自动缓降 / 自动闪避 / 无敌少侠大全 / 动作脚本2 / Fe动作脚本3 / Fe巨人脚本
服务器脚本：恶魔学 / 墨水游戏 / 画我 / 最强战场 / 自然灾害 / 活到7天 / 唐县 / 门
其他脚本：Tailor-Hub / X脚本 / 名脚本 / YLQ / wx / 皮脚本 / 落叶中心 / 云脚本 / 情云脚本
最新公告：脚本于6月28日更新

点击左上角「BALL HUB」打开控制面板
]]

Tabs.Announce:Paragraph({
    Title = "BALL HUB 公告",
    Desc = ANNOUNCE_TEXT,
    Image = "info",
    ImageSize = 30,
    Color = "Blue",
})

-- ---- 通用标签页（包含功能一和功能二全部内容，字体扩大） ----
-- 功能一：Toggle开关
local toggleInvis = Tabs.General:Toggle({
    Title = "隐身",
    Icon = "eye-off",
    Value = false,
    TextSize = 18,
    Callback = function(state)
        if state ~= invisible then toggleInvisible() end
    end
})
table.insert(toggleRefs, toggleInvis)

local toggleItems = Tabs.General:Toggle({
    Title = "附近道具",
    Icon = "package",
    Value = false,
    TextSize = 18,
    Callback = function(state)
        if state ~= getItemsEnabled then toggleGetItems() end
    end
})
table.insert(toggleRefs, toggleItems)

local toggleSpeedBtn = Tabs.General:Toggle({
    Title = "加速",
    Icon = "gauge",
    Value = false,
    TextSize = 18,
    Callback = function(state)
        if state ~= speedToggle then toggleSpeed() end
    end
})
table.insert(toggleRefs, toggleSpeedBtn)

local toggleESPBtn = Tabs.General:Toggle({
    Title = "透视",
    Icon = "eye",
    Value = false,
    TextSize = 18,
    Callback = function(state)
        if state ~= espEnabled then toggleESP() end
    end
})
table.insert(toggleRefs, toggleESPBtn)

local toggleSpinBtn = Tabs.General:Toggle({
    Title = "旋转",
    Icon = "refresh-cw",
    Value = false,
    TextSize = 18,
    Callback = function(state)
        if state ~= spinning then toggleSpin() end
    end
})
table.insert(toggleRefs, toggleSpinBtn)

-- 功能一：按钮
Tabs.General:Button({
    Title = "传送",
    Desc = "点击选择玩家传送",
    Icon = "send",
    TextSize = 18,
    Callback = toggleTeleport,
})

Tabs.General:Button({
    Title = "飞行",
    Icon = "send",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Fly.lua"))() end)
    end,
})

Tabs.General:Button({
    Title = "炉管r15",
    Icon = "flame",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://pastefy.app/YZoglOyJ/raw"))() end)
    end,
})

Tabs.General:Button({
    Title = "炉管r6",
    Icon = "flame",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://pastefy.app/wa3v2Vgm/raw"))() end)
    end,
})

Tabs.General:Button({
    Title = "VR脚本FE",
    Icon = "vr",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://pastefy.app/MvKHpycG/raw"))() end)
    end,
})

Tabs.General:Button({
    Title = "飞踢脚本",
    Icon = "footprints",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Fe-DropKick-Script-165813"))() end)
    end,
})

Tabs.General:Button({
    Title = "火车头脚本",
    Icon = "train",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://pastebin.com/raw/F0j8zqeX"))() end)
    end,
})

Tabs.General:Button({
    Title = "重新加入此服务器",
    Icon = "rotate-ccw",
    TextSize = 18,
    Callback = rejoinServer,
})

Tabs.General:Button({
    Title = "子弹追踪",
    Icon = "crosshair",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/da263517b23cc095755015c582087b0a.lua"))() end)
    end,
})

Tabs.General:Button({
    Title = "IY脚本",
    Icon = "file-text",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Infinite-Yield-v64-90090"))() end)
    end,
})

Tabs.General:Button({
    Title = "自瞄",
    Icon = "target",
    TextSize = 18,
    Callback = function()
        pcall(function() loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Universal-Aimbot-esp-and-more-76976"))() end)
    end,
})

-- 功能二：9个脚本按钮
local func2Scripts = {
    {"操控物体", "https://raw.githubusercontent.com/axionscripts1/Move-Blocks-v20/refs/heads/main/README.md"},
    {"FE动作脚本", "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"},
    {"延迟脚本", "https://rawscripts.net/raw/Universal-Script-Roblox-Egor-Script-49040"},
    {"自动缓降", "https://pastebin.com/raw/DjQ77Lrt"},
    {"自动闪避", "https://pastebin.com/raw/kvgFKE1j"},
    {"无敌少侠大全", "https://raw.githubusercontent.com/giobolqv1/invincible-characters-animations-by-GioBolqv1-/refs/heads/main/universal.lua"},
    {"动作脚本2", "https://raw.githubusercontent.com/Gazer-Ha/Free-emote/refs/heads/main/Delta%20mad%20stuffs"},
    {"Fe动作脚本3", "https://raw.githubusercontent.com/sypcerr/scripts/refs/heads/main/c15.lua"},
    {"Fe巨人脚本", "https://rawscripts.net/raw/Universal-Script-Giant-80824"},
}

for _, data in ipairs(func2Scripts) do
    Tabs.General:Button({
        Title = data[1],
        Icon = "layers",
        TextSize = 18,
        Callback = function()
            pcall(function() loadstring(game:HttpGet(data[2]))() end)
        end,
    })
end

-- ---- 服务器脚本标签 ----
local serverScripts = {
    {"恶魔学", "https://raw.githubusercontent.com/nainshu/no/main/Demonology.lua"},
    {"墨水游戏", "https://raw.githubusercontent.com/ke9460394-dot/ugik/refs/heads/main/%E6%B1%89%E5%8C%96%E5%A2%A8%E6%B0%B4Ringta.txt"},
    {"画我脚本", "https://raw.githubusercontent.com/ke9460394-dot/ugik/refs/heads/main/KENNY%E7%94%BB%E6%88%91.lua"},
    {"最强战场", "https://raw.githubusercontent.com/Something478/MainScripts/refs/heads/main/BreezeHub.lua"},
    {"自然灾害", "https://raw.githubusercontent.com/9NLK7/93qjoadnlaknwldk/main/main"},
    {"活到7天", "https://raw.githubusercontent.com/rndmq/Serverlist/refs/heads/main/Server87"},
    {"河北唐县", "https://raw.githubusercontent.com/Sw1ndlerScripts/RobloxScripts/main/Tang%20Country.lua"},
    {"门", "https://pastebin.com/raw/65TwT8ja"},
}

for _, data in ipairs(serverScripts) do
    Tabs.ServerScripts:Button({
        Title = data[1],
        Icon = "cloud-lightning",
        TextSize = 18,
        Callback = function()
            pcall(function() loadstring(game:HttpGet(data[2]))() end)
        end,
    })
end

-- ---- 其他脚本标签 ----
local otherScripts = {
    {"Tailor-Hub", "https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Loader.lua"},
    {"X脚本", "https://raw.githubusercontent.com/xxh888888/21212/refs/heads/main/mimic.lua"},
    {"名脚本", "https://raw.githubusercontent.com/WuMing-YYDS/MingScript/refs/heads/main/名脚本.LUA"},
    {"YLQ脚本", "https://github.com/jiaozi666-sudo/YLQ4/releases/download/roblox/YLQ.2.lua"},
    {"wx脚本", "https://raw.githubusercontent.com/gthhgsh/WX-/refs/heads/main/WX%20Hub.LUA"},
    {"皮脚本", "https://raw.githubusercontent.com/xiaopi77/xiaopi77/main/QQ1002100032-Roblox-Pi-script.lua"},
    {"落叶中心", "https://raw.githubusercontent.com/krlpl/Deciduous-center-LS/main/%E8%90%BD%E5%8F%B6%E4%B8%AD%E5%BF%83%E6%B7%B7%E6%B7%86.txt"},
    {"云脚本", "https://raw.githubusercontent.com/XiaoYunUwU/UI/main/Branch.luau"},
}

for _, data in ipairs(otherScripts) do
    Tabs.Other:Button({
        Title = data[1],
        Icon = "box",
        TextSize = 18,
        Callback = function()
            pcall(function() loadstring(game:HttpGet(data[2]))() end)
        end,
    })
end

-- 情云脚本使用原始编码方式
Tabs.Other:Button({
    Title = "情云脚本",
    Icon = "box",
    TextSize = 18,
    Callback = function()
        pcall(function()
            loadstring(utf8.char((function() return table.unpack({108,111,97,100,115,116,114,105,110,103,40,103,97,109,101,58,72,116,116,112,71,101,116,40,34,104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,67,104,105,110,97,81,89,47,45,47,109,97,105,110,47,37,69,54,37,56,51,37,56,53,37,69,52,37,66,65,37,57,49,34,41,41,40,41})end)()))()
        end)
    end,
})

-- ---- 显示启动通知 ----
WindUI:Notify({
    Title = "BALL HUB 已加载",
    Content = "点击左上角「BALL HUB」打开控制面板",
    Icon = "rocket",
    Duration = 4,
})

Window:SelectTab(1)
