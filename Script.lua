-- ============================================================
-- 1. 加载 WindUI 库
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ============================================================
-- 2. 原有功能逻辑（基本保持不变）
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
local flingEnabled = false
local spinSpeed = 180
local spinGyro = nil
local spinConnection = nil
local invisibleParts = {}
local nameTagsHidden = {}
local clonedTools = {}
local teleportGui = nil
local flingConnections = {}
local flingCooldowns = {}

-- ---- 颜色常量 ----
local PURPLE_BTN = Color3.fromRGB(90, 45, 140)
local INDICATOR_OFF = Color3.fromRGB(100, 100, 100)
local INDICATOR_INVISIBLE = Color3.fromRGB(0, 200, 100)
local INDICATOR_SPEED = Color3.fromRGB(200, 200, 0)
local INDICATOR_GETITEMS = Color3.fromRGB(255, 150, 0)
local INDICATOR_ESP = Color3.fromRGB(0, 150, 200)
local INDICATOR_SPIN = Color3.fromRGB(255, 100, 255)
local INDICATOR_FLING = Color3.fromRGB(255, 80, 80)

-- ---- 公告内容 ----
local ANNOUNCE_TEXT = [[
欢迎BALL HUB！ 脚本仍属于测试阶段
制作人Roblox名字：hhhkk6224
QQ群：687742398
b站：阿轲欣妍

功能一览：
🔘 功能一：隐身 / 附近道具 / 加速 / 透视 / 传送 / 旋转 / 甩飞
🔘 功能二：飞 / 炉管r15 / 炉管r6 / VR脚本FE / 飞踢 / 祖国人 / 全能侠 / 火车头 / 重新加入此服务器
🔘 服务器脚本：恶魔学 / 墨水游戏 / 画我脚本 / 最强战场 / 自然灾害 / 活到7天 / 河北唐县 / 门
🔘 最新公告：脚本于6月28日更新

点击左上角「脚本」打开控制面板
]]

-- ---- 核心功能函数 ----
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

local function clearFlingConnections()
    for _, conn in ipairs(flingConnections) do conn:Disconnect() end
    table.clear(flingConnections)
    table.clear(flingCooldowns)
end

local function enableFling()
    local char = p.Character
    if not char then return end
    clearFlingConnections()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanTouch then
            local conn = part.Touched:Connect(function(otherPart)
                if not flingEnabled then return end
                local otherChar = otherPart.Parent
                while otherChar and not otherChar:IsA("Model") do otherChar = otherChar.Parent end
                if not otherChar or not otherChar:FindFirstChild("Humanoid") then return end
                if otherChar == char then return end
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
                if not otherRoot then return end
                local now = tick()
                if flingCooldowns[otherChar] and now - flingCooldowns[otherChar] < 1.5 then return end
                flingCooldowns[otherChar] = now
                local dir = (otherRoot.Position - part.Position).Unit + Vector3.new(0, 2, 0)
                local flingVelocity = Instance.new("BodyVelocity")
                flingVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                flingVelocity.Velocity = dir * 200
                flingVelocity.Parent = otherRoot
                game.Debris:AddItem(flingVelocity, 0.5)
            end)
            table.insert(flingConnections, conn)
        end
    end
end

local function toggleFling()
    flingEnabled = not flingEnabled
    if flingEnabled then enableFling() else clearFlingConnections() end
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

-- ---- 角色重生重置 ----
p.CharacterAdded:Connect(function(newChar)
    c = newChar
    h = c:WaitForChild("Humanoid")
    r = c:WaitForChild("HumanoidRootPart")
    invisible = false
    getItemsEnabled = false
    speedToggle = false
    espEnabled = false
    spinning = false
    flingEnabled = false
    if invisible then toggleInvisible() end
    if getItemsEnabled then toggleGetItems() end
    if espEnabled then toggleESP() end
    if spinning then toggleSpin() end
    if flingEnabled then clearFlingConnections() end
    speedToggle = false
    h.WalkSpeed = 16
    for _, toggle in ipairs(toggleRefs) do
        toggle:SetValue(false)
    end
end)

-- ---- 存储所有 Toggle 引用 ----
local toggleRefs = {}

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

Tabs.Func1 = Window:Tab({
    Title = "功能一",
    Icon = "zap",
    ShowTabTitle = true,
})

Tabs.Func2 = Window:Tab({
    Title = "功能二",
    Icon = "settings",
    ShowTabTitle = true,
})

Tabs.ServerScripts = Window:Tab({
    Title = "服务器脚本",
    Icon = "cloud-lightning",
    ShowTabTitle = true,
})

-- ---- 公告标签页 ----
Tabs.Announce:Paragraph({
    Title = "📢 BALL HUB 公告",
    Desc = ANNOUNCE_TEXT,
    Image = "info",
    ImageSize = 30,
    Color = "Blue",
})

-- ---- 功能一标签页（原有开关 + 传送） ----
local toggleInvis = Tabs.Func1:Toggle({
    Title = "隐身",
    Icon = "eye-off",
    Value = false,
    Callback = function(state)
        if state ~= invisible then toggleInvisible() end
    end
})
table.insert(toggleRefs, toggleInvis)

local toggleItems = Tabs.Func1:Toggle({
    Title = "附近道具",
    Icon = "package",
    Value = false,
    Callback = function(state)
        if state ~= getItemsEnabled then toggleGetItems() end
    end
})
table.insert(toggleRefs, toggleItems)

local toggleSpeedBtn = Tabs.Func1:Toggle({
    Title = "加速",
    Icon = "gauge",
    Value = false,
    Callback = function(state)
        if state ~= speedToggle then toggleSpeed() end
    end
})
table.insert(toggleRefs, toggleSpeedBtn)

local toggleESPBtn = Tabs.Func1:Toggle({
    Title = "透视",
    Icon = "eye",
    Value = false,
    Callback = function(state)
        if state ~= espEnabled then toggleESP() end
    end
})
table.insert(toggleRefs, toggleESPBtn)

local toggleSpinBtn = Tabs.Func1:Toggle({
    Title = "旋转",
    Icon = "refresh-cw",
    Value = false,
    Callback = function(state)
        if state ~= spinning then toggleSpin() end
    end
})
table.insert(toggleRefs, toggleSpinBtn)

local toggleFlingBtn = Tabs.Func1:Toggle({
    Title = "甩飞",
    Icon = "wind",
    Value = false,
    Callback = function(state)
        if state ~= flingEnabled then toggleFling() end
    end
})
table.insert(toggleRefs, toggleFlingBtn)

Tabs.Func1:Button({
    Title = "传送",
    Desc = "点击选择玩家传送",
    Icon = "send",
    Callback = toggleTeleport,
})

-- ---- 功能二标签页（飞 + 炉管 + 其他脚本 + 退出） ----
Tabs.Func2:Button({
    Title = "✈️ 飞",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Fly.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "飞加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🔥 炉管r15",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/YZoglOyJ/raw"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "炉管r15加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🔥 炉管r6",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/wa3v2Vgm/raw"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "炉管r6加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🥽 VR脚本FE",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/MvKHpycG/raw"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "VR脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🦵 飞踢脚本",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Fe-DropKick-Script-165813"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "飞踢脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🇺🇸 祖国人脚本",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/giobolqvi1/homelander-by-GioBolqv1/refs/heads/main/homelander.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "祖国人脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🦸 全能侠",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/giobolqvi1/Omni-man-fly-by-GioBolqv1/refs/heads/main/omniman.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "全能侠脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🚂 火车头脚本",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastebin.com/raw/F0j8zqeX"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "火车头脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.Func2:Button({
    Title = "🔄 重新加入此服务器",
    Callback = rejoinServer,
})

-- ---- 退出按钮 ----
Tabs.Func2:Button({
    Title = "🚪 退出脚本",
    Callback = function()
        if invisible then toggleInvisible() end
        if getItemsEnabled then toggleGetItems() end
        if espEnabled then toggleESP() end
        if spinning then toggleSpin() end
        if flingEnabled then toggleFling() end
        h.WalkSpeed = 16
        Window:Close()
        local byeGui = Instance.new("ScreenGui")
        byeGui.Name = "ByeGUI"
        byeGui.Parent = p:WaitForChild("PlayerGui")
        local byeFrame = Instance.new("Frame")
        byeFrame.Size = UDim2.new(0, 300, 0, 80)
        byeFrame.Position = UDim2.new(0.5, -150, 0.5, -40)
        byeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        byeFrame.BackgroundTransparency = 0.3
        byeFrame.BorderSizePixel = 0
        local byeCorner = Instance.new("UICorner")
        byeCorner.CornerRadius = UDim.new(0, 12)
        byeCorner.Parent = byeFrame
        byeFrame.Parent = byeGui
        local byeText = Instance.new("TextLabel")
        byeText.Size = UDim2.new(0.9, 0, 0.6, 0)
        byeText.Position = UDim2.new(0.05, 0, 0.2, 0)
        byeText.BackgroundTransparency = 1
        byeText.Text = "BALL HUB"
        byeText.TextColor3 = Color3.fromRGB(255, 200, 200)
        byeText.TextScaled = true
        byeText.Font = Enum.Font.GothamBold
        byeText.Parent = byeFrame
        task.wait(3)
        byeGui:Destroy()
    end
})

-- ============================================================
-- 4. 服务器脚本标签页
-- ============================================================
Tabs.ServerScripts:Button({
    Title = "👹 恶魔学",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/nainshu/no/main/Demonology.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "恶魔学加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "🖋️ 墨水游戏",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ke9460394-dot/ugik/refs/heads/main/%E6%B1%89%E5%8C%96%E5%A2%A8%E6%B0%B4Ringta.txt"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "墨水游戏加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "🎨 画我脚本",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ke9460394-dot/ugik/refs/heads/main/KENNY%E7%94%BB%E6%88%91.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "画我脚本加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "⚔️ 最强战场",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Something478/MainScripts/refs/heads/main/BreezeHub.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "最强战场加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "🌪️ 自然灾害",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/9NLK7/93qjoadnlaknwldk/main/main"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "自然灾害加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "📅 活到7天",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/rndmq/Serverlist/refs/heads/main/Server87"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "活到7天加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "🌾 河北唐县",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Sw1ndlerScripts/RobloxScripts/main/Tang%20Country.lua"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "河北唐县加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

Tabs.ServerScripts:Button({
    Title = "🚪 门",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastebin.com/raw/65TwT8ja"))()
        end)
        if not success then
            WindUI:Notify({ Title = "错误", Content = "门加载失败: " .. tostring(err), Duration = 3 })
        end
    end,
})

-- ---- 显示启动通知 ----
WindUI:Notify({
    Title = "BALL HUB 已加载",
    Content = "点击左上角「BALL HUB」打开控制面板",
    Icon = "rocket",
    Duration = 4,
})

Window:SelectTab(1)  -- 默认显示公告标签页
