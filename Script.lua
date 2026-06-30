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
local spectating = false
local spectateTarget = nil
local spinSpeed = 180
local spinGyro = nil
local spinConnection = nil
local invisibleParts = {}
local nameTagsHidden = {}
local clonedTools = {}
local teleportGui = nil
local infoGui = nil
local spectateGui = nil
local flingConnections = {}
local flingCooldowns = {}

-- ---- 颜色常量（用于 WindUI 组件） ----
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
🔘 功能二：玩家信息 / 观战 / 自然灾害 / 黑洞 / 重新加入此服务器
🔘 新增脚本：飞 / 炉管r15 / 炉管r6 / VR脚本FE / 飞踢 / 祖国人 / 全能侠 / 火车头
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

-- ---- 自然灾害 ----
local function floodDisaster()
    local char = p.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local center = root.Position
    local floodParts = {}
    for x = -20, 20, 4 do
        for z = -20, 20, 4 do
            local part = Instance.new("Part")
            part.Size = Vector3.new(4, 0.5, 4)
            part.CFrame = CFrame.new(center + Vector3.new(x, -5, z))
            part.Anchored = true
            part.BrickColor = BrickColor.new("Cyan")
            part.Transparency = 0.6
            part.Material = Enum.Material.Neon
            part.Parent = workspace
            table.insert(floodParts, part)
        end
    end
    task.spawn(function()
        for _ = 1, 50 do
            for _, part in ipairs(floodParts) do
                if part and part.Parent then
                    part.CFrame = part.CFrame + Vector3.new(0, 0.3, 0)
                end
            end
            task.wait(0.05)
        end
        task.wait(2)
        for _, part in ipairs(floodParts) do
            if part and part.Parent then part:Destroy() end
        end
    end)
end

local function meteorDisaster()
    local char = p.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local center = root.Position
    for i = 1, 10 do
        local spawnX = center.X + math.random(-30, 30)
        local spawnZ = center.Z + math.random(-30, 30)
        local meteor = Instance.new("Part")
        meteor.Shape = Enum.PartType.Ball
        meteor.Size = Vector3.new(3, 3, 3)
        meteor.CFrame = CFrame.new(Vector3.new(spawnX, center.Y + 50, spawnZ))
        meteor.Anchored = false
        meteor.BrickColor = BrickColor.new("Really red")
        meteor.Material = Enum.Material.Neon
        meteor.Parent = workspace
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity = Vector3.new(math.random(-10, 10), -100, math.random(-10, 10))
        bv.Parent = meteor
        game.Debris:AddItem(meteor, 5)
    end
end

local function earthquakeDisaster()
    local char = p.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = 0
    end
    task.spawn(function()
        for _ = 1, 30 do
            Cam.CFrame = Cam.CFrame * CFrame.Angles(math.rad(math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
            task.wait(0.05)
        end
        if hum then hum.WalkSpeed = 16 end
    end)
end

local function startNaturalDisaster()
    local disasters = {floodDisaster, meteorDisaster, earthquakeDisaster}
    local f = disasters[math.random(#disasters)]
    f()
end

local function spawnBlackHole()
    local char = p.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local pos = root.Position + root.CFrame.LookVector * 20

    local hole = Instance.new("Part")
    hole.Shape = Enum.PartType.Ball
    hole.Size = Vector3.new(8, 8, 8)
    hole.CFrame = CFrame.new(pos)
    hole.BrickColor = BrickColor.new("Black")
    hole.Material = Enum.Material.Neon
    hole.Anchored = true
    hole.CanCollide = false
    hole.Parent = workspace

    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(100, 0, 150)
    glow.Range = 30
    glow.Brightness = 2
    glow.Parent = hole

    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < 5 do
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored and obj ~= hole and (obj.Position - pos).Magnitude < 40 then
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    bv.Velocity = (pos - obj.Position).Unit * (40 - (obj.Position - pos).Magnitude) * 1.5
                    bv.Parent = obj
                    game.Debris:AddItem(bv, 0.2)
                end
            end
            task.wait(0.1)
        end
        hole:Destroy()
    end)
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

-- ---- 玩家信息弹窗 ----
function showPlayerInfo()
    if infoGui then infoGui:Destroy() end
    infoGui = Instance.new("ScreenGui")
    infoGui.Name = "InfoGUI"
    infoGui.Parent = p:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 300)
    frame.Position = UDim2.new(0.5, -140, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 30
    local fcorner = Instance.new("UICorner")
    fcorner.CornerRadius = UDim.new(0, 10)
    fcorner.Parent = frame
    frame.Parent = infoGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "本服务器玩家信息"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 31
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(0.92, 0, 0, 255)
    scroll.Position = UDim2.new(0.04, 0, 0.1, 0)
    scroll.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    scroll.BackgroundTransparency = 0.5
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 31
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.Name
    layout.Padding = UDim.new(0, 3)
    layout.Parent = scroll

    local players = game.Players:GetPlayers()
    local totalHeight = 0
    for _, player in ipairs(players) do
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -8, 0, 50)
        container.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        container.BackgroundTransparency = 0.3
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 4)
        cc.Parent = container
        container.Parent = scroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Position = UDim2.new(0, 5, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Text = player.Name
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = container

        local char = player.Character
        local healthStr = "❌ 未出生"
        if char and char:FindFirstChild("Humanoid") then
            local hum = char.Humanoid
            healthStr = "❤️ " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
        end
        local healthLabel = Instance.new("TextLabel")
        healthLabel.Size = UDim2.new(1, -10, 0, 18)
        healthLabel.Position = UDim2.new(0, 5, 0, 20)
        healthLabel.BackgroundTransparency = 1
        healthLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        healthLabel.Text = healthStr
        healthLabel.TextScaled = true
        healthLabel.Font = Enum.Font.Gotham
        healthLabel.TextXAlignment = Enum.TextXAlignment.Left
        healthLabel.Parent = container

        local toolsStr = ""
        if char then
            local tools = {}
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Tool") then table.insert(tools, obj.Name) end
            end
            toolsStr = #tools > 0 and "🎒 " .. table.concat(tools, ", ") or "🎒 无道具"
        else
            toolsStr = "🎒 无"
        end
        local toolsLabel = Instance.new("TextLabel")
        toolsLabel.Size = UDim2.new(1, -10, 0, 14)
        toolsLabel.Position = UDim2.new(0, 5, 0, 36)
        toolsLabel.BackgroundTransparency = 1
        toolsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
        toolsLabel.Text = toolsStr
        toolsLabel.TextScaled = true
        toolsLabel.Font = Enum.Font.Gotham
        toolsLabel.TextXAlignment = Enum.TextXAlignment.Left
        toolsLabel.Parent = container

        totalHeight = totalHeight + 53
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

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
        infoGui:Destroy()
        infoGui = nil
    end)
end

-- ---- 观战功能 ----
local function stopSpectate()
    if spectating then
        spectating = false
        spectateTarget = nil
        Cam.CameraSubject = p.Character and p.Character:FindFirstChild("Humanoid") or p.Character
        Cam.CameraType = Enum.CameraType.Custom
    end
end

local function showSpectateList()
    if spectateGui then spectateGui:Destroy() end
    spectateGui = Instance.new("ScreenGui")
    spectateGui.Name = "SpectateGUI"
    spectateGui.Parent = p:WaitForChild("PlayerGui")

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
    frame.Parent = spectateGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "选择观战玩家"
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
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    spectating = true
                    spectateTarget = player
                    Cam.CameraSubject = player.Character:FindFirstChild("Humanoid")
                    Cam.CameraType = Enum.CameraType.Custom
                end
                spectateGui:Destroy()
                spectateGui = nil
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
        spectateGui:Destroy()
        spectateGui = nil
    end)
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
    if spectating then stopSpectate() end
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

-- ---- 公告标签页 ----
Tabs.Announce:Paragraph({
    Title = "📢 BALL HUB 公告",
    Desc = ANNOUNCE_TEXT,
    Image = "info",
    ImageSize = 30,
    Color = "Blue",
})

-- ---- 功能一标签页（原有开关 + 传送，无新增） ----
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

-- ---- 功能二标签页（原有按钮 + 飞/炉管 + 新增五个按钮） ----
Tabs.Func2:Button({
    Title = "📋 本服务器玩家信息",
    Callback = showPlayerInfo,
})

local spectateButton = Tabs.Func2:Button({
    Title = "👀 观战玩家",
    Callback = showSpectateList,
})

local stopSpectateButton = Tabs.Func2:Button({
    Title = "🔴 停止观战",
    Callback = function()
        stopSpectate()
        spectateButton:SetLocked(false)
        stopSpectateButton:SetLocked(true)
    end,
    Locked = true,
})

-- 重写观战相关函数以更新按钮锁定状态
local originalShowSpectate = showSpectateList
showSpectateList = function()
    originalShowSpectate()
    spectateButton:SetLocked(true)
    stopSpectateButton:SetLocked(false)
end

local originalStopSpectate = stopSpectate
stopSpectate = function()
    originalStopSpectate()
    spectateButton:SetLocked(false)
    stopSpectateButton:SetLocked(true)
end

Tabs.Func2:Button({
    Title = "🌪️ 自然灾害",
    Callback = startNaturalDisaster,
})

Tabs.Func2:Button({
    Title = "🕳️ 黑洞",
    Callback = spawnBlackHole,
})

Tabs.Func2:Button({
    Title = "🔄 重新加入此服务器",
    Callback = rejoinServer,
})

-- 第一次新增的按钮（飞、炉管r15、炉管r6）
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

-- ====== 新增的五个按钮（VR、飞踢、祖国人、全能侠、火车头） ======
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

-- ---- 退出按钮 ----
Tabs.Func2:Button({
    Title = "🚪 退出脚本",
    Callback = function()
        if invisible then toggleInvisible() end
        if getItemsEnabled then toggleGetItems() end
        if espEnabled then toggleESP() end
        if spinning then toggleSpin() end
        if flingEnabled then toggleFling() end
        if spectating then stopSpectate() end
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

-- ---- 显示启动通知 ----
WindUI:Notify({
    Title = "BALL HUB 已加载",
    Content = "点击左上角「BALL HUB」打开控制面板",
    Icon = "rocket",
    Duration = 4,
})

Window:SelectTab(1)  -- 默认显示公告标签页
