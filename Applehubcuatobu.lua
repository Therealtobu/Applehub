-- ============================================
-- APPLE HUB - FIXED VERSION WITH SAVE SYSTEM
-- Version: 2.1
-- ============================================

local SCRIPT_VERSION = "2.1"
local VERSION_CHECK_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.txt"
local SCRIPT_UPDATE_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/script.lua"
local CHECK_UPDATE_INTERVAL = 300 -- Check every 5 minutes

local latestVersion = SCRIPT_VERSION
local updateAvailable = false
local hasNotifiedUpdate = false

local allowedPlaceIds = {
    [9872472334] = true,
    [11353528705] = true,
}

if not allowedPlaceIds[game.PlaceId] then
    game.Players.LocalPlayer:Kick("This game doesn't support!")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local isFirstSpawn = true
local fps = 0
local lastTick = tick()
local frameCount = 0
local startTime = tick()
local savedTime = 0
local rounds = 0
local respawnCount = 0
local longFarmMode = false
local coverGuiVisible = false
local coverGuiInstance = nil
local toggleButton = nil

local riskGuiVisible = false
local riskGuiInstance = nil
local AutoTicketEnabled = false
local FixLagEnabled = false
local AutoMoneyFarmEnabled = false
local idleTime = 0
local screensaverVisible = false
local screensaverGui = nil

local PLACEID = game.PlaceId
local HOP_FLAG_FILE = "applehub_hop.flag"
local DATA_FILE = "applehub_data.json"
local SETTINGS_FILE = "applehub_settings.json"
local hopCount = 0

local WEBHOOK_URL = "https://discord.com/api/webhooks/1405081236661080214/LU-UfBkQBZXT0dYd4HNUd3XdF_Oovit3gHXhZkLiYIc-CAZrGjOVm15cGKjVPucoTKBn"

local AutoMoneyFarmConnection = nil
local AutoReviveModule = nil

-- ============================================
-- SAVE/LOAD SYSTEM
-- ============================================

local function saveSettings()
    local settings = {
        AutoTicket = AutoTicketEnabled,
        FixLag = FixLagEnabled,
        AutoMoneyFarm = AutoMoneyFarmEnabled
    }
    local success = pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode(settings))
    end)
    return success
end

local function loadSettings()
    if isfile(SETTINGS_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(SETTINGS_FILE))
        end)
        if success and data then
            AutoTicketEnabled = data.AutoTicket or false
            FixLagEnabled = data.FixLag or false
            AutoMoneyFarmEnabled = data.AutoMoneyFarm or false
            return true
        end
    end
    return false
end

local function saveData()
    local totalTime = savedTime + math.floor(tick() - startTime)
    local data = {
        TotalWins = rounds, 
        TotalSeconds = totalTime, 
        LastExitTime = os.time(), 
        HopCount = hopCount
    }
    pcall(function()
        writefile(DATA_FILE, HttpService:JSONEncode(data))
        saveSettings()
    end)
end

-- Kiểm tra xem có phải đang hop không
local isHopping = isfile(HOP_FLAG_FILE)

if isHopping then
    -- Nếu đang hop, load settings và data
    loadSettings()
    if isfile(DATA_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(DATA_FILE))
        end)
        if success and data then
            savedTime = data.TotalSeconds or 0
            rounds = data.TotalWins or 0
            hopCount = data.HopCount or 0
        end
    end
    delfile(HOP_FLAG_FILE)
else
    -- Nếu chạy script mới (không phải hop), xóa data cũ
    if isfile(DATA_FILE) then
        delfile(DATA_FILE)
    end
    if isfile(SETTINGS_FILE) then
        delfile(SETTINGS_FILE)
    end
    savedTime = 0
    rounds = 0
    hopCount = 0
    AutoTicketEnabled = false
    FixLagEnabled = false
    AutoMoneyFarmEnabled = false
end

-- ============================================
-- VERSION CHECK SYSTEM
-- ============================================

local function checkForUpdates()
    local success, response = pcall(function()
        return game:HttpGet(VERSION_CHECK_URL)
    end)
    
    if success and response then
        local version = response:match("^%s*(.-)%s*$") -- Trim whitespace
        if version and version ~= SCRIPT_VERSION then
            latestVersion = version
            updateAvailable = true
            
            if not hasNotifiedUpdate then
                hasNotifiedUpdate = true
                showNotificationQueue("🎉 New version " .. version .. " available!", Color3.fromRGB(52, 199, 89))
                showNotificationQueue("📦 Open Dashboard to update", Color3.fromRGB(100, 150, 255))
            end
            
            return true
        end
    end
    
    return false
end

local function performUpdate(progressCallback)
    if progressCallback then progressCallback(0, "Downloading update...") end
    task.wait(0.3)
    
    local success, newScript = pcall(function()
        return game:HttpGet(SCRIPT_UPDATE_URL)
    end)
    
    if not success or not newScript then
        if progressCallback then progressCallback(100, "Download failed!") end
        return false, "Failed to download update"
    end
    
    if progressCallback then progressCallback(30, "Preparing update...") end
    task.wait(0.3)
    
    -- Save current state
    saveData()
    saveSettings()
    
    if progressCallback then progressCallback(50, "Backing up settings...") end
    task.wait(0.3)
    
    -- Extract only the core logic update (hot-reload)
    if progressCallback then progressCallback(70, "Applying changes...") end
    task.wait(0.3)
    
    -- Execute new script with preserved state
    local updateSuccess, err = pcall(function()
        local func, loadErr = loadstring(newScript)
        if not func then
            error("Failed to load new script: " .. tostring(loadErr))
        end
        
        if progressCallback then progressCallback(90, "Finalizing...") end
        task.wait(0.2)
        
        -- Execute update
        func()
    end)
    
    if updateSuccess then
        if progressCallback then progressCallback(100, "Update complete!") end
        task.wait(0.5)
        return true, "Successfully updated to version " .. latestVersion
    else
        if progressCallback then progressCallback(100, "Update failed!") end
        return false, "Update error: " .. tostring(err)
    end
end

-- Start periodic version checking
task.spawn(function()
    while true do
        task.wait(CHECK_UPDATE_INTERVAL)
        if player.Parent then
            checkForUpdates()
        end
    end
end)

-- Initial check after 10 seconds
task.delay(10, function()
    checkForUpdates()
end)

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastTick >= 1 then
        fps = frameCount
        frameCount = 0
        lastTick = tick()
    end
end)

-- ============================================
-- NOTIFICATION SYSTEM
-- ============================================

local NotificationQueue = {}
local NotificationBusy = false

function showNotificationQueue(txt, color)
    table.insert(NotificationQueue, {Text = txt, Color = color})
    if not NotificationBusy then
        NotificationBusy = true
        task.spawn(function()
            while #NotificationQueue > 0 do
                local data = table.remove(NotificationQueue, 1)
                local playerGui = player:WaitForChild("PlayerGui")
                local guiName = "CustomNotification"
                if playerGui:FindFirstChild(guiName) then playerGui[guiName]:Destroy() end
                local gui = Instance.new("ScreenGui")
                gui.Name = guiName
                gui.Parent = playerGui
                gui.DisplayOrder = 999999
                local frame = Instance.new("Frame")
                frame.AnchorPoint = Vector2.new(1, 0)
                frame.Position = UDim2.new(1.2, 0, 0, 20)
                frame.Size = UDim2.new(0, 250, 0, 50)
                frame.BackgroundColor3 = data.Color or Color3.fromRGB(50, 50, 50)
                frame.BackgroundTransparency = 0.2
                frame.Parent = gui
                local corner = Instance.new("UICorner", frame)
                corner.CornerRadius = UDim.new(0, 12)
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -20, 1, -20)
                label.Position = UDim2.new(0, 10, 0, 10)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.new(1,1,1)
                label.TextSize = 14
                label.Font = Enum.Font.GothamMedium
                label.TextWrapped = true
                label.Text = data.Text
                label.Parent = frame
                TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0, 20)}):Play()
                task.wait(3)
                TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = UDim2.new(1.2, 0, 0, 20)}):Play()
                task.wait(0.5)
                gui:Destroy()
            end
            NotificationBusy = false
        end)
    end
end

-- ============================================
-- iOS TOGGLE BUTTON
-- ============================================

local function createiOSToggle(parent, pos, initialState, callback)
    local toggleContainer = Instance.new("Frame")
    toggleContainer.Size = UDim2.new(0, 51, 0, 31)
    toggleContainer.Position = pos
    toggleContainer.BackgroundColor3 = initialState and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(120, 120, 128)
    toggleContainer.BorderSizePixel = 0
    toggleContainer.Parent = parent
    
    local corner = Instance.new("UICorner", toggleContainer)
    corner.CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 27, 0, 27)
    knob.Position = initialState and UDim2.new(1, -29, 0.5, -13.5) or UDim2.new(0, 2, 0.5, -13.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = toggleContainer
    
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    local isOn = initialState
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = toggleContainer
    
    button.MouseButton1Click:Connect(function()
        isOn = not isOn
        
        if isOn then
            TweenService:Create(toggleContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(52, 199, 89)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -29, 0.5, -13.5)}):Play()
        else
            TweenService:Create(toggleContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(120, 120, 128)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 2, 0.5, -13.5)}):Play()
        end
        
        if callback then callback(isOn) end
    end)
    
    return toggleContainer, isOn
end

-- ============================================
-- SERVER HOP SYSTEM (HOÀN TOÀN MỚI)
-- ============================================

local function findServer()
    local allServers = {}
    local cursor = ""
    local attempts = 0
    local maxAttempts = 10
    
    showNotificationQueue("🔍 Đang quét tất cả server...", Color3.fromRGB(100, 150, 255))
    
    -- Thu thập tất cả server
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s"):format(PLACEID, cursor)
        local success, res = pcall(function() 
            return game:HttpGet(url) 
        end)
        
        if not success then
            warn("HTTP request failed:", res)
            task.wait(3)
            break
        end
        
        local decodeSuccess, data = pcall(function()
            return HttpService:JSONDecode(res)
        end)
        
        if not decodeSuccess then
            warn("JSON decode failed:", data)
            task.wait(3)
            break
        end
        
        if data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId then
                    if server.playing >= 1 and server.playing <= 10 and server.playing < server.maxPlayers then
                        table.insert(allServers, {
                            id = server.id,
                            playing = server.playing,
                            maxPlayers = server.maxPlayers
                        })
                    end
                end
            end
        end
        
        if data.nextPageCursor and data.nextPageCursor ~= "" then
            cursor = data.nextPageCursor
            task.wait(1)
        else
            break
        end
    end
    
    if #allServers == 0 then
        warn("Không tìm thấy server phù hợp")
        return nil
    end
    
    -- Chọn ngẫu nhiên một server từ danh sách
    local randomIndex = math.random(1, #allServers)
    local selectedServer = allServers[randomIndex]
    
    showNotificationQueue("✅ Tìm thấy " .. #allServers .. " server, chọn ngẫu nhiên!", Color3.fromRGB(0, 255, 0))
    return selectedServer.id
end

local function performServerHop()
    saveData()
    hopCount = hopCount + 1
    
    local totalTime = savedTime + math.floor(tick() - startTime)
    writefile(DATA_FILE, HttpService:JSONEncode({
        TotalWins = rounds, 
        TotalSeconds = totalTime, 
        LastExitTime = os.time(), 
        HopCount = hopCount
    }))
    
    saveSettings()
    writefile(HOP_FLAG_FILE, "true")
    
    showNotificationQueue("🚀 HOPPING! Lần hop thứ: " .. hopCount, Color3.fromRGB(255, 165, 0))
    
    respawnCount = 0
    
    task.spawn(function()
        local maxRetries = 15
        local retryCount = 0
        
        while retryCount < maxRetries do
            retryCount = retryCount + 1
            
            showNotificationQueue("🔄 Đang tìm server (Lần " .. retryCount .. "/" .. maxRetries .. ")", Color3.fromRGB(255, 200, 0))
            
            local success, serverId = pcall(findServer)
            
            if success and serverId then
                showNotificationQueue("✅ Tìm thấy server! Đang teleport...", Color3.fromRGB(0, 200, 0))
                
                task.wait(2)
                
                local teleportSuccess, teleportError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(PLACEID, serverId, player)
                end)
                
                if teleportSuccess then
                    return
                else
                    warn("Teleport failed:", teleportError)
                    showNotificationQueue("⚠️ Teleport thất bại, thử lại...", Color3.fromRGB(255, 165, 0))
                    task.wait(5)
                end
            else
                warn("Find server failed:", serverId)
                showNotificationQueue("⚠️ Không tìm thấy server, thử lại...", Color3.fromRGB(255, 165, 0))
                task.wait(5)
            end
        end
        
        showNotificationQueue("❌ Không thể hop sau " .. maxRetries .. " lần thử", Color3.fromRGB(255, 0, 0))
        showNotificationQueue("🔄 Đang reset respawn counter...", Color3.fromRGB(255, 165, 0))
        respawnCount = 0
    end)
end

-- ============================================
-- LAG FIX SYSTEM
-- ============================================

local function applyExtremeLagFix()
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 0
    Lighting.Brightness = 0
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
    Lighting.Ambient = Color3.new(0, 0, 0)
    
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") 
            or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") 
            or effect:IsA("DepthOfFieldEffect") then
            effect.Enabled = false
            task.spawn(function() pcall(function() effect:Destroy() end) end)
        end
    end
    
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
        Terrain.Decoration = false
        pcall(function() sethiddenproperty(Terrain, "Decoration", false) end)
    end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        pcall(function()
            if obj.Name == "SkyPlatform" or (obj.Parent and obj.Parent.Name == "SkyPlatform") then
                return
            end
            
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = false
                obj:Destroy()
            end
            
            if obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
                obj:Destroy()
            end
            
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
                obj.CastShadow = false
                
                if obj:IsA("MeshPart") then
                    obj.TextureID = ""
                end
            end
            
            if obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj:Destroy()
            end
            
            if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                obj.Enabled = false
                obj:Destroy()
            end
            
            if obj:IsA("Attachment") and #obj:GetChildren() == 0 then
                obj:Destroy()
            end
        end)
    end
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            task.spawn(function()
                pcall(function()
                    if plr.Character then
                        for _, part in pairs(plr.Character:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("ParticleEmitter") then
                                part.Transparency = 1
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end
                end)
            end)
        end
    end
    
    local camera = workspace.CurrentCamera
    if camera then
        camera.FieldOfView = 70
    end
    
    task.spawn(function()
        while FixLagEnabled do
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    pcall(function()
                        for _, part in pairs(plr.Character:GetDescendants()) do
                            if part:IsA("BasePart") and part.Transparency < 1 then
                                part.Transparency = 1
                            end
                        end
                    end)
                end
            end
            task.wait(2)
        end
    end)
    
    task.spawn(function()
        while FixLagEnabled do
            task.wait(15)
            if FixLagEnabled then
                for i = 1, 10 do
                    pcall(function()
                        collectgarbage("collect")
                    end)
                    task.wait(0.1)
                end
                
                pcall(function()
                    game:GetService("Debris"):ClearAllChildren()
                end)
            end
        end
    end)
    
    pcall(function()
        if Lighting:FindFirstChildOfClass("Sky") then
            Lighting:FindFirstChildOfClass("Sky"):Destroy()
        end
    end)
    
    task.spawn(function()
        while FixLagEnabled do
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    pcall(function()
                        local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                                track:Stop()
                            end
                        end
                    end)
                end
            end
            task.wait(1)
        end
    end)
    
    showNotificationQueue("⚡ Ultra Extreme Lag Fix Applied!", Color3.fromRGB(255, 165, 0))
end

-- ============================================
-- AUTO REVIVE MODULE
-- ============================================

function initAutoReviveModule()
    local reviveRange = 10
    local loopDelay = 0.15
    local autoReviveEnabled = false
    local reviveLoopHandle = nil
    local interactEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("Interact")

    local function isPlayerDowned(pl)
        if not pl or not pl.Character then return false end
        local char = pl.Character
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            return true
        end
        if char.GetAttribute and char:GetAttribute("Downed") == true then
            return true
        end
        return false
    end

    local function startAutoRevive()
        if reviveLoopHandle then return end
        reviveLoopHandle = task.spawn(function()
            while autoReviveEnabled do
                local currentPlayer = Players.LocalPlayer
                if currentPlayer and currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local myHRP = currentPlayer.Character.HumanoidRootPart
                    for _, pl in ipairs(Players:GetPlayers()) do
                        if pl ~= currentPlayer then
                            local char = pl.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                if isPlayerDowned(pl) then
                                    local hrp = char.HumanoidRootPart
                                    local success, dist = pcall(function()
                                        return (myHRP.Position - hrp.Position).Magnitude
                                    end)
                                    if success and dist and dist <= reviveRange then
                                        pcall(function()
                                            interactEvent:FireServer("Revive", true, pl.Name)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(loopDelay)
            end
            reviveLoopHandle = nil
        end)
    end

    local function stopAutoRevive()
        autoReviveEnabled = false
    end

    local function ToggleAutoRevive(state)
        if state == nil then
            autoReviveEnabled = not autoReviveEnabled
        else
            autoReviveEnabled = (state == true)
        end
        if autoReviveEnabled then
            startAutoRevive()
        else
            stopAutoRevive()
        end
    end

    local function SetReviveRange(range)
        if type(range) == "number" and range > 0 then
            reviveRange = range
        end
    end

    return {
        Toggle = ToggleAutoRevive,
        Start = function() ToggleAutoRevive(true) end,
        Stop = function() ToggleAutoRevive(false) end,
        SetRange = SetReviveRange,
        IsEnabled = function() return autoReviveEnabled end,
    }
end

-- ============================================
-- AUTO MONEY FARM
-- ============================================

function startAutoMoneyFarm()
    if AutoMoneyFarmConnection then return end
    
    if not AutoReviveModule then
        AutoReviveModule = initAutoReviveModule()
    end
    
    AutoReviveModule.Start()
    
    AutoMoneyFarmConnection = RunService.Heartbeat:Connect(function()
        local skyPlatform = workspace:FindFirstChild("SkyPlatform")
        if not skyPlatform then return end
        
        local currentCharacter = player.Character
        if not currentCharacter then return end
        
        local currentRootPart = currentCharacter:FindFirstChild("HumanoidRootPart")
        if not currentRootPart then return end
        
        local downedPlayerFound = false
        local playersInGame = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
        
        if playersInGame then
            for _, v in pairs(playersInGame:GetChildren()) do
                if v:IsA("Model") and v:GetAttribute("Downed") then
                    if v:FindFirstChild("RagdollConstraints") then
                        continue
                    end
                    
                    local vHrp = v:FindFirstChild("HumanoidRootPart")
                    if vHrp then
                        currentRootPart.CFrame = vHrp.CFrame + Vector3.new(0, 3, 0)
                        
                        pcall(function()
                            ReplicatedStorage.Events.Character.Interact:FireServer("Revive", true, v)
                        end)
                        
                        task.wait(0.5)
                        downedPlayerFound = true
                        break
                    end
                end
            end
        end
        
        if not downedPlayerFound then
            currentRootPart.CFrame = skyPlatform.CFrame + Vector3.new(0, PLATFORM_SIZE.Y / 2 + 5, 0)
        end
    end)
    
    showNotificationQueue("💰 Auto Money Farm Started!", Color3.fromRGB(0, 200, 0))
    saveSettings()
end

function stopAutoMoneyFarm()
    if AutoMoneyFarmConnection then
        AutoMoneyFarmConnection:Disconnect()
        AutoMoneyFarmConnection = nil
    end
    
    if AutoReviveModule then
        AutoReviveModule.Stop()
    end
    
    showNotificationQueue("❌ Auto Money Farm Stopped!", Color3.fromRGB(255, 0, 0))
    saveSettings()
end

-- ============================================
-- SCREENSAVER
-- ============================================

local function createScreensaver()
    if screensaverVisible or screensaverGui then return end
    
    local playerGui = player:WaitForChild("PlayerGui")
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "IdleScreensaver"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 9999
    gui.Parent = playerGui
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.Parent = gui
    
    local gradient = Instance.new("UIGradient", overlay)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 30)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 20, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 40))
    })
    gradient.Rotation = 45
    
    task.spawn(function()
        while gui.Parent do
            for i = 0, 360, 2 do
                if not gui.Parent then break end
                gradient.Rotation = i
                task.wait(0.05)
            end
        end
    end)
    
    local statsContainer = Instance.new("Frame")
    statsContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    statsContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    statsContainer.Size = UDim2.new(0, 0, 0, 0)
    statsContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    statsContainer.BackgroundTransparency = 0.3
    statsContainer.BorderSizePixel = 0
    statsContainer.Parent = overlay
    
    local containerCorner = Instance.new("UICorner", statsContainer)
    containerCorner.CornerRadius = UDim.new(0, 24)
    
    local containerStroke = Instance.new("UIStroke", statsContainer)
    containerStroke.Color = Color3.fromRGB(100, 100, 120)
    containerStroke.Thickness = 2
    containerStroke.Transparency = 0.7
    
    task.spawn(function()
        while gui.Parent do
            for i = 0, 100 do
                if not gui.Parent then break end
                containerStroke.Transparency = 0.3 + (math.sin(i / 15) * 0.4)
                task.wait(0.03)
            end
        end
    end)
    
    local titleContainer = Instance.new("Frame")
    titleContainer.Size = UDim2.new(1, 0, 0, 80)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = statsContainer
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0, 10)
    icon.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    icon.Text = "🍎"
    icon.TextSize = 32
    icon.Font = Enum.Font.GothamBold
    icon.Parent = titleContainer
    
    local iconCorner = Instance.new("UICorner", icon)
    iconCorner.CornerRadius = UDim.new(1, 0)
    
    local iconStroke = Instance.new("UIStroke", icon)
    iconStroke.Color = Color3.fromRGB(80, 80, 100)
    iconStroke.Thickness = 2
    iconStroke.Transparency = 0.5
    
    local statsGrid = Instance.new("Frame")
    statsGrid.Size = UDim2.new(1, -60, 0, 200)
    statsGrid.Position = UDim2.new(0, 30, 0, 90)
    statsGrid.BackgroundTransparency = 1
    statsGrid.Parent = statsContainer
    
    local function createStatCard(position, title, iconText, getValue)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.48, 0, 0, 90)
        card.Position = position
        card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        card.BackgroundTransparency = 0.5
        card.BorderSizePixel = 0
        card.Parent = statsGrid
        
        local cardCorner = Instance.new("UICorner", card)
        cardCorner.CornerRadius = UDim.new(0, 16)
        
        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Color3.fromRGB(60, 60, 80)
        cardStroke.Thickness = 1
        cardStroke.Transparency = 0.8
        
        local cardIcon = Instance.new("TextLabel")
        cardIcon.Size = UDim2.new(0, 35, 0, 35)
        cardIcon.Position = UDim2.new(0, 15, 0, 12)
        cardIcon.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        cardIcon.Text = iconText
        cardIcon.TextSize = 18
        cardIcon.Font = Enum.Font.GothamBold
        cardIcon.Parent = card
        
        local cardIconCorner = Instance.new("UICorner", cardIcon)
        cardIconCorner.CornerRadius = UDim.new(0, 10)
        
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -65, 0, 20)
        titleLabel.Position = UDim2.new(0, 55, 0, 15)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextSize = 13
        titleLabel.Font = Enum.Font.Gotham
        titleLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = card
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(1, -20, 0, 40)
        valueLabel.Position = UDim2.new(0, 15, 0, 45)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = getValue()
        valueLabel.TextSize = 26
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextColor3 = Color3.new(1, 1, 1)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Left
        valueLabel.Parent = card
        
        task.spawn(function()
            while gui.Parent do
                valueLabel.Text = getValue()
                task.wait(1)
            end
        end)
        
        return card
    end
    
    createStatCard(UDim2.new(0, 0, 0, 0), "FPS", "⚡", function()
        return tostring(fps)
    end)
    
    createStatCard(UDim2.new(0.52, 0, 0, 0), "Time", "⏱️", function()
        local elapsed = savedTime + math.floor(tick() - startTime)
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60
        return string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end)
    
    createStatCard(UDim2.new(0, 0, 0, 105), "Wins", "🏆", function()
        return tostring(rounds)
    end)
    
    createStatCard(UDim2.new(0.52, 0, 0, 105), "Hops", "🌐", function()
        return tostring(hopCount)
    end)
    
    local hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(1, 0, 0, 40)
    hintLabel.Position = UDim2.new(0, 0, 1, -50)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Tap anywhere to continue"
    hintLabel.TextSize = 14
    hintLabel.Font = Enum.Font.GothamMedium
    hintLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    hintLabel.Parent = statsContainer
    
    task.spawn(function()
        while gui.Parent do
            for i = 0, 100 do
                if not gui.Parent then break end
                hintLabel.TextTransparency = 0.3 + (math.sin(i / 10) * 0.3)
                task.wait(0.03)
            end
        end
    end)
    
    local dismissBtn = Instance.new("TextButton")
    dismissBtn.Size = UDim2.new(1, 0, 1, 0)
    dismissBtn.BackgroundTransparency = 1
    dismissBtn.Text = ""
    dismissBtn.Parent = overlay
    
    dismissBtn.MouseButton1Click:Connect(function()
        screensaverVisible = false
        idleTime = 0
        TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        TweenService:Create(statsContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        gui:Destroy()
        screensaverGui = nil
    end)
    
    screensaverGui = gui
    screensaverVisible = true
    
    TweenService:Create(overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.3}):Play()
    TweenService:Create(statsContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 460, 0, 320)}):Play()
end

-- ============================================
-- COVER GUI (DASHBOARD)
-- ============================================

local function createCoverGui()
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("CoverGui") then playerGui.CoverGui:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "CoverGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 10000
    gui.Parent = playerGui
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Parent = gui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = overlay
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 16)
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 30)
    title.Position = UDim2.new(0, 20, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "Dashboard"
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -45, 0, 15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    closeBtn.Text = "✕"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner", closeBtn)
    closeBtnCorner.CornerRadius = UDim.new(1, 0)
    
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -40, 1, -80)
    content.Position = UDim2.new(0, 20, 0, 70)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    local statsCard = Instance.new("Frame")
    statsCard.Size = UDim2.new(1, 0, 0, 100)
    statsCard.Position = UDim2.new(0, 0, 0, 0)
    statsCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    statsCard.BackgroundTransparency = 0.15
    statsCard.BorderSizePixel = 0
    statsCard.Parent = content
    
    local statsCorner = Instance.new("UICorner", statsCard)
    statsCorner.CornerRadius = UDim.new(0, 12)
    
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 40, 0, 40)
    iconFrame.Position = UDim2.new(0, 15, 0.5, -20)
    iconFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    iconFrame.Parent = statsCard
    
    local iconCorner = Instance.new("UICorner", iconFrame)
    iconCorner.CornerRadius = UDim.new(0, 10)
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "📊"
    icon.TextSize = 20
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = Color3.new(1, 1, 1)
    icon.Parent = iconFrame
    
    local statsInfo = Instance.new("TextLabel")
    statsInfo.Size = UDim2.new(1, -80, 1, -10)
    statsInfo.Position = UDim2.new(0, 65, 0, 5)
    statsInfo.BackgroundTransparency = 1
    statsInfo.TextSize = 16
    statsInfo.Font = Enum.Font.GothamMedium
    statsInfo.TextColor3 = Color3.new(1, 1, 1)
    statsInfo.TextXAlignment = Enum.TextXAlignment.Left
    statsInfo.TextYAlignment = Enum.TextYAlignment.Center
    statsInfo.RichText = true
    statsInfo.Parent = statsCard
    
    task.spawn(function()
        while gui.Parent do
            local elapsed = savedTime + math.floor(tick() - startTime)
            local hours = math.floor(elapsed / 3600)
            local minutes = math.floor((elapsed % 3600) / 60)
            local seconds = elapsed % 60
            statsInfo.Text = string.format("<b>Statistics</b>\n<font size='14'><font color='rgb(150,150,160)'>FPS:</font> <b>%d</b>  |  <font color='rgb(150,150,160)'>Time:</font> <b>%02d:%02d:%02d</b>  |  <font color='rgb(150,150,160)'>Wins:</font> <b>%d</b></font>", fps, hours, minutes, seconds, rounds)
            task.wait(1)
        end
    end)
    
    local creditCard = Instance.new("Frame")
    creditCard.Size = UDim2.new(1, 0, 0, 60)
    creditCard.Position = UDim2.new(0, 0, 0, 115)
    creditCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    creditCard.BackgroundTransparency = 0.15
    creditCard.BorderSizePixel = 0
    creditCard.Parent = content
    
    local creditCorner = Instance.new("UICorner", creditCard)
    creditCorner.CornerRadius = UDim.new(0, 12)
    
    local creditIcon = Instance.new("Frame")
    creditIcon.Size = UDim2.new(0, 40, 0, 40)
    creditIcon.Position = UDim2.new(0, 15, 0.5, -20)
    creditIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    creditIcon.Parent = creditCard
    
    local creditIconCorner = Instance.new("UICorner", creditIcon)
    creditIconCorner.CornerRadius = UDim.new(0, 10)
    
    local creditEmoji = Instance.new("TextLabel")
    creditEmoji.Size = UDim2.new(1, 0, 1, 0)
    creditEmoji.BackgroundTransparency = 1
    creditEmoji.Text = "👨‍💻"
    creditEmoji.TextSize = 20
    creditEmoji.Font = Enum.Font.GothamBold
    creditEmoji.TextColor3 = Color3.new(1, 1, 1)
    creditEmoji.Parent = creditIcon
    
    local creditTitle = Instance.new("TextLabel")
    creditTitle.Size = UDim2.new(1, -80, 0, 20)
    creditTitle.Position = UDim2.new(0, 65, 0, 12)
    creditTitle.BackgroundTransparency = 1
    creditTitle.Text = "Developer"
    creditTitle.TextSize = 15
    creditTitle.Font = Enum.Font.GothamBold
    creditTitle.TextColor3 = Color3.new(1, 1, 1)
    creditTitle.TextXAlignment = Enum.TextXAlignment.Left
    creditTitle.Parent = creditCard
    
    local creditName = Instance.new("TextLabel")
    creditName.Size = UDim2.new(1, -80, 0, 16)
    creditName.Position = UDim2.new(0, 65, 0, 32)
    creditName.BackgroundTransparency = 1
    creditName.Text = "__tobu"
    creditName.TextSize = 14
    creditName.Font = Enum.Font.GothamMedium
    creditName.TextColor3 = Color3.fromRGB(100, 200, 255)
    creditName.TextXAlignment = Enum.TextXAlignment.Left
    creditName.Parent = creditCard
    
    -- Version Card
    local versionCard = Instance.new("Frame")
    versionCard.Size = UDim2.new(1, 0, 0, 75)
    versionCard.Position = UDim2.new(0, 0, 0, 190)
    versionCard.BackgroundColor3 = updateAvailable and Color3.fromRGB(40, 35, 30) or Color3.fromRGB(30, 30, 35)
    versionCard.BackgroundTransparency = 0.15
    versionCard.BorderSizePixel = 0
    versionCard.Parent = content
    
    local versionCorner = Instance.new("UICorner", versionCard)
    versionCorner.CornerRadius = UDim.new(0, 12)
    
    if updateAvailable then
        local versionStroke = Instance.new("UIStroke", versionCard)
        versionStroke.Color = Color3.fromRGB(52, 199, 89)
        versionStroke.Thickness = 2
        versionStroke.Transparency = 0.5
        
        task.spawn(function()
            while gui.Parent and updateAvailable do
                for i = 0, 100 do
                    if not gui.Parent or not updateAvailable then break end
                    versionStroke.Transparency = 0.3 + (math.sin(i / 10) * 0.2)
                    task.wait(0.03)
                end
            end
        end)
    end
    
    local versionIcon = Instance.new("Frame")
    versionIcon.Size = UDim2.new(0, 40, 0, 40)
    versionIcon.Position = UDim2.new(0, 15, 0.5, -20)
    versionIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    versionIcon.Parent = versionCard
    
    local versionIconCorner = Instance.new("UICorner", versionIcon)
    versionIconCorner.CornerRadius = UDim.new(0, 10)
    
    local versionEmoji = Instance.new("TextLabel")
    versionEmoji.Size = UDim2.new(1, 0, 1, 0)
    versionEmoji.BackgroundTransparency = 1
    versionEmoji.Text = updateAvailable and "🎉" or "✅"
    versionEmoji.TextSize = 20
    versionEmoji.Font = Enum.Font.GothamBold
    versionEmoji.TextColor3 = Color3.new(1, 1, 1)
    versionEmoji.Parent = versionIcon
    
    local versionTitle = Instance.new("TextLabel")
    versionTitle.Size = UDim2.new(1, -150, 0, 20)
    versionTitle.Position = UDim2.new(0, 65, 0, 12)
    versionTitle.BackgroundTransparency = 1
    versionTitle.Text = "Version"
    versionTitle.TextSize = 15
    versionTitle.Font = Enum.Font.GothamBold
    versionTitle.TextColor3 = Color3.new(1, 1, 1)
    versionTitle.TextXAlignment = Enum.TextXAlignment.Left
    versionTitle.Parent = versionCard
    
    local versionInfo = Instance.new("TextLabel")
    versionInfo.Size = UDim2.new(1, -150, 0, 16)
    versionInfo.Position = UDim2.new(0, 65, 0, 34)
    versionInfo.BackgroundTransparency = 1
    versionInfo.RichText = true
    versionInfo.TextSize = 13
    versionInfo.Font = Enum.Font.GothamMedium
    versionInfo.TextColor3 = Color3.fromRGB(150, 150, 160)
    versionInfo.TextXAlignment = Enum.TextXAlignment.Left
    versionInfo.Parent = versionCard
    
    if updateAvailable then
        versionInfo.Text = string.format("<font color='rgb(255,100,100)'>v%s</font> → <font color='rgb(52,199,89)'>v%s</font>", SCRIPT_VERSION, latestVersion)
    else
        versionInfo.Text = string.format("v%s <font color='rgb(52,199,89)'>(Latest)</font>", SCRIPT_VERSION)
    end
    
    if updateAvailable then
        local updateBtn = Instance.new("TextButton")
        updateBtn.Size = UDim2.new(0, 70, 0, 32)
        updateBtn.Position = UDim2.new(1, -85, 0.5, -16)
        updateBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
        updateBtn.Text = "Update"
        updateBtn.TextColor3 = Color3.new(1, 1, 1)
        updateBtn.TextSize = 13
        updateBtn.Font = Enum.Font.GothamBold
        updateBtn.Parent = versionCard
        
        local updateBtnCorner = Instance.new("UICorner", updateBtn)
        updateBtnCorner.CornerRadius = UDim.new(0, 8)
        
        updateBtn.MouseButton1Click:Connect(function()
            -- Create update GUI
            local updateGui = Instance.new("ScreenGui")
            updateGui.Name = "UpdateProgress"
            updateGui.IgnoreGuiInset = true
            updateGui.ResetOnSpawn = false
            updateGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            updateGui.DisplayOrder = 10020
            updateGui.Parent = playerGui
            
            local updateOverlay = Instance.new("Frame")
            updateOverlay.Size = UDim2.new(1, 0, 1, 0)
            updateOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
            updateOverlay.BackgroundTransparency = 0.7
            updateOverlay.Parent = updateGui
            
            local updateFrame = Instance.new("Frame")
            updateFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            updateFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
            updateFrame.Size = UDim2.new(0, 400, 0, 180)
            updateFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            updateFrame.BorderSizePixel = 0
            updateFrame.Parent = updateOverlay
            
            local updateFrameCorner = Instance.new("UICorner", updateFrame)
            updateFrameCorner.CornerRadius = UDim.new(0, 16)
            
            local updateTitleLabel = Instance.new("TextLabel")
            updateTitleLabel.Size = UDim2.new(1, -40, 0, 30)
            updateTitleLabel.Position = UDim2.new(0, 20, 0, 20)
            updateTitleLabel.BackgroundTransparency = 1
            updateTitleLabel.Text = "🎉 Updating to v" .. latestVersion
            updateTitleLabel.TextSize = 18
            updateTitleLabel.Font = Enum.Font.GothamBold
            updateTitleLabel.TextColor3 = Color3.new(1, 1, 1)
            updateTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            updateTitleLabel.Parent = updateFrame
            
            local updateStatusLabel = Instance.new("TextLabel")
            updateStatusLabel.Size = UDim2.new(1, -40, 0, 20)
            updateStatusLabel.Position = UDim2.new(0, 20, 0, 60)
            updateStatusLabel.BackgroundTransparency = 1
            updateStatusLabel.Text = "Preparing..."
            updateStatusLabel.TextSize = 14
            updateStatusLabel.Font = Enum.Font.Gotham
            updateStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
            updateStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
            updateStatusLabel.Parent = updateFrame
            
            local progressBg = Instance.new("Frame")
            progressBg.Size = UDim2.new(1, -40, 0, 12)
            progressBg.Position = UDim2.new(0, 20, 0, 95)
            progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            progressBg.BorderSizePixel = 0
            progressBg.Parent = updateFrame
            
            local progressBgCorner = Instance.new("UICorner", progressBg)
            progressBgCorner.CornerRadius = UDim.new(1, 0)
            
            local progressBar = Instance.new("Frame")
            progressBar.Size = UDim2.new(0, 0, 1, 0)
            progressBar.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
            progressBar.BorderSizePixel = 0
            progressBar.Parent = progressBg
            
            local progressBarCorner = Instance.new("UICorner", progressBar)
            progressBarCorner.CornerRadius = UDim.new(1, 0)
            
            local progressGradient = Instance.new("UIGradient", progressBar)
            progressGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 199, 89)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70))
            })
            
            local progressPercent = Instance.new("TextLabel")
            progressPercent.Size = UDim2.new(1, -40, 0, 20)
            progressPercent.Position = UDim2.new(0, 20, 0, 120)
            progressPercent.BackgroundTransparency = 1
            progressPercent.Text = "0%"
            progressPercent.TextSize = 13
            progressPercent.Font = Enum.Font.GothamBold
            progressPercent.TextColor3 = Color3.fromRGB(150, 150, 160)
            progressPercent.TextXAlignment = Enum.TextXAlignment.Right
            progressPercent.Parent = updateFrame
            
            -- Perform update with progress callback
            task.spawn(function()
                local success, result = performUpdate(function(progress, status)
                    updateStatusLabel.Text = status
                    progressPercent.Text = math.floor(progress) .. "%"
                    
                    local targetSize = UDim2.new(progress / 100, 0, 1, 0)
                    TweenService:Create(progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
                end)
                
                task.wait(1)
                
                if success then
                    updateStatusLabel.Text = "✅ " .. result
                    updateStatusLabel.TextColor3 = Color3.fromRGB(52, 199, 89)
                    
                    task.wait(2)
                    updateGui:Destroy()
                    
                    -- Close dashboard and reopen to refresh
                    if coverGuiInstance then
                        coverGuiInstance:Destroy()
                        coverGuiInstance = nil
                        coverGuiVisible = false
                    end
                    
                    showNotificationQueue("✅ Update successful! Restarting...", Color3.fromRGB(52, 199, 89))
                else
                    updateStatusLabel.Text = "❌ " .. result
                    updateStatusLabel.TextColor3 = Color3.fromRGB(255, 69, 58)
                    
                    task.wait(3)
                    updateGui:Destroy()
                end
            end)
        end)
    end
    
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        coverGuiVisible = false
        gui:Destroy()
        coverGuiInstance = nil
    end)
    
    coverGuiInstance = gui
    
    TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 500, 0, updateAvailable and 420 or 330), BackgroundTransparency = 0.05}):Play()
end

-- ============================================
-- RISK GUI
-- ============================================

local function createRiskGui()
    local playerGui = player:WaitForChild("PlayerGui")
    if riskGuiInstance then return end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RiskGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 10010
    gui.Parent = playerGui
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Parent = gui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = overlay
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 16)
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 30)
    title.Position = UDim2.new(0, 20, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "Risk Features"
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -45, 0, 15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    closeBtn.Text = "✕"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner", closeBtn)
    closeBtnCorner.CornerRadius = UDim.new(1, 0)
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -40, 1, -80)
    scrollFrame.Position = UDim2.new(0, 20, 0, 70)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 340)
    scrollFrame.Parent = mainFrame
    
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 0, 410)
    content.BackgroundTransparency = 1
    content.Parent = scrollFrame
    
    local warningCard = Instance.new("Frame")
    warningCard.Size = UDim2.new(1, 0, 0, 85)
    warningCard.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    warningCard.BackgroundTransparency = 0.15
    warningCard.BorderSizePixel = 0
    warningCard.Parent = content
    
    local warningCorner = Instance.new("UICorner", warningCard)
    warningCorner.CornerRadius = UDim.new(0, 12)
    
    local ledStroke = Instance.new("UIStroke", warningCard)
    ledStroke.Color = Color3.new(1, 1, 1)
    ledStroke.Thickness = 3
    ledStroke.Transparency = 0
    
    local ledGradient = Instance.new("UIGradient", ledStroke)
    ledGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.45, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(0.55, 1),
        NumberSequenceKeypoint.new(1, 1)
    })
    ledGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50))
    })
    
    task.spawn(function()
        while gui.Parent do
            for i = 0, 360, 4 do
                if not gui.Parent then break end
                ledGradient.Rotation = i
                task.wait(0.02)
            end
        end
    end)
    
    local warningLabel = Instance.new("TextLabel")
    warningLabel.Size = UDim2.new(1, -30, 1, 0)
    warningLabel.Position = UDim2.new(0, 15, 0, 0)
    warningLabel.BackgroundTransparency = 1
    warningLabel.Text = "⚠️  RISKING\n\nUse under caution and supervision."
    warningLabel.TextSize = 16
    warningLabel.Font = Enum.Font.GothamBold
    warningLabel.TextColor3 = Color3.new(1, 1, 1)
    warningLabel.TextXAlignment = Enum.TextXAlignment.Left
    warningLabel.TextYAlignment = Enum.TextYAlignment.Center
    warningLabel.Parent = warningCard
    
    local toggleCard = Instance.new("Frame")
    toggleCard.Size = UDim2.new(1, 0, 0, 75)
    toggleCard.Position = UDim2.new(0, 0, 0, 100)
    toggleCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    toggleCard.BackgroundTransparency = 0.15
    toggleCard.BorderSizePixel = 0
    toggleCard.Parent = content
    
    local toggleCorner = Instance.new("UICorner", toggleCard)
    toggleCorner.CornerRadius = UDim.new(0, 12)
    
    local toggleTitle = Instance.new("TextLabel")
    toggleTitle.Size = UDim2.new(1, -90, 0, 24)
    toggleTitle.Position = UDim2.new(0, 15, 0, 12)
    toggleTitle.BackgroundTransparency = 1
    toggleTitle.Text = "Auto Event Ticket"
    toggleTitle.TextSize = 16
    toggleTitle.Font = Enum.Font.GothamBold
    toggleTitle.TextColor3 = Color3.new(1, 1, 1)
    toggleTitle.TextXAlignment = Enum.TextXAlignment.Left
    toggleTitle.Parent = toggleCard
    
    local toggleSubtitle = Instance.new("TextLabel")
    toggleSubtitle.Size = UDim2.new(1, -90, 0, 16)
    toggleSubtitle.Position = UDim2.new(0, 15, 0, 38)
    toggleSubtitle.BackgroundTransparency = 1
    toggleSubtitle.Text = "Automatically collect event tickets"
    toggleSubtitle.TextSize = 12
    toggleSubtitle.Font = Enum.Font.Gotham
    toggleSubtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
    toggleSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    toggleSubtitle.Parent = toggleCard
    
    createiOSToggle(toggleCard, UDim2.new(1, -66, 0.5, -15.5), AutoTicketEnabled, function(state)
        AutoTicketEnabled = state
        saveSettings()
        if state then
            showNotificationQueue("✅ Auto Event Ticket Enabled", Color3.fromRGB(52, 199, 89))
        else
            showNotificationQueue("⛔ Auto Event Ticket Disabled", Color3.fromRGB(255, 69, 58))
        end
    end)
    
    local fixLagCard = Instance.new("Frame")
    fixLagCard.Size = UDim2.new(1, 0, 0, 75)
    fixLagCard.Position = UDim2.new(0, 0, 0, 190)
    fixLagCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    fixLagCard.BackgroundTransparency = 0.15
    fixLagCard.BorderSizePixel = 0
    fixLagCard.Parent = content
    
    local fixLagCorner = Instance.new("UICorner", fixLagCard)
    fixLagCorner.CornerRadius = UDim.new(0, 12)
    
    local fixLagTitle = Instance.new("TextLabel")
    fixLagTitle.Size = UDim2.new(1, -90, 0, 24)
    fixLagTitle.Position = UDim2.new(0, 15, 0, 12)
    fixLagTitle.BackgroundTransparency = 1
    fixLagTitle.Text = "Fix Lag"
    fixLagTitle.TextSize = 16
    fixLagTitle.Font = Enum.Font.GothamBold
    fixLagTitle.TextColor3 = Color3.new(1, 1, 1)
    fixLagTitle.TextXAlignment = Enum.TextXAlignment.Left
    fixLagTitle.Parent = fixLagCard
    
    local fixLagSubtitle = Instance.new("TextLabel")
    fixLagSubtitle.Size = UDim2.new(1, -90, 0, 16)
    fixLagSubtitle.Position = UDim2.new(0, 15, 0, 38)
    fixLagSubtitle.BackgroundTransparency = 1
    fixLagSubtitle.Text = "The game may crash a few seconds after starting"
    fixLagSubtitle.TextSize = 11
    fixLagSubtitle.Font = Enum.Font.Gotham
    fixLagSubtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
    fixLagSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    fixLagSubtitle.Parent = fixLagCard
    
    createiOSToggle(fixLagCard, UDim2.new(1, -66, 0.5, -15.5), FixLagEnabled, function(state)
        FixLagEnabled = state
        saveSettings()
        if state then
            showNotificationQueue("⚡ Applying Extreme Lag Fix...", Color3.fromRGB(255, 165, 0))
            task.wait(0.5)
            applyExtremeLagFix()
        else
            showNotificationQueue("⛔ Fix Lag Disabled", Color3.fromRGB(255, 69, 58))
        end
    end)
    
    local moneyFarmCard = Instance.new("Frame")
    moneyFarmCard.Size = UDim2.new(1, 0, 0, 75)
    moneyFarmCard.Position = UDim2.new(0, 0, 0, 280)
    moneyFarmCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    moneyFarmCard.BackgroundTransparency = 0.15
    moneyFarmCard.BorderSizePixel = 0
    moneyFarmCard.Parent = content
    
    local moneyFarmCorner = Instance.new("UICorner", moneyFarmCard)
    moneyFarmCorner.CornerRadius = UDim.new(0, 12)
    
    local moneyFarmTitle = Instance.new("TextLabel")
    moneyFarmTitle.Size = UDim2.new(1, -90, 0, 24)
    moneyFarmTitle.Position = UDim2.new(0, 15, 0, 12)
    moneyFarmTitle.BackgroundTransparency = 1
    moneyFarmTitle.Text = "💰 Auto Money Farm"
    moneyFarmTitle.TextSize = 16
    moneyFarmTitle.Font = Enum.Font.GothamBold
    moneyFarmTitle.TextColor3 = Color3.new(1, 1, 1)
    moneyFarmTitle.TextXAlignment = Enum.TextXAlignment.Left
    moneyFarmTitle.Parent = moneyFarmCard
    
    local moneyFarmSubtitle = Instance.new("TextLabel")
    moneyFarmSubtitle.Size = UDim2.new(1, -90, 0, 16)
    moneyFarmSubtitle.Position = UDim2.new(0, 15, 0, 38)
    moneyFarmSubtitle.BackgroundTransparency = 1
    moneyFarmSubtitle.Text = "Auto revive players and earn money"
    moneyFarmSubtitle.TextSize = 12
    moneyFarmSubtitle.Font = Enum.Font.Gotham
    moneyFarmSubtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
    moneyFarmSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    moneyFarmSubtitle.Parent = moneyFarmCard
    
    createiOSToggle(moneyFarmCard, UDim2.new(1, -66, 0.5, -15.5), AutoMoneyFarmEnabled, function(state)
        AutoMoneyFarmEnabled = state
        if state then
            startAutoMoneyFarm()
        else
            stopAutoMoneyFarm()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        riskGuiVisible = false
        gui:Destroy()
        riskGuiInstance = nil
    end)
    
    riskGuiInstance = gui
    
    TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 400, 0, 370), BackgroundTransparency = 0.05}):Play()
end

-- ============================================
-- TOGGLE BUTTONS
-- ============================================

local function createToggleButtons()
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("ToggleButtons") then return end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "ToggleButtons"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10001
    gui.Parent = playerGui
    
    local dashboardBtn = Instance.new("TextButton")
    dashboardBtn.Size = UDim2.new(0, 110, 0, 36)
    dashboardBtn.Position = UDim2.new(0.5, -115, 0, 15)
    dashboardBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    dashboardBtn.BackgroundTransparency = 0.2
    dashboardBtn.Text = "Dashboard"
    dashboardBtn.TextColor3 = Color3.new(1, 1, 1)
    dashboardBtn.TextSize = 13
    dashboardBtn.Font = Enum.Font.GothamMedium
    dashboardBtn.Parent = gui
    
    local dashCorner = Instance.new("UICorner", dashboardBtn)
    dashCorner.CornerRadius = UDim.new(0, 10)
    
    local riskBtn = Instance.new("TextButton")
    riskBtn.Size = UDim2.new(0, 110, 0, 36)
    riskBtn.Position = UDim2.new(0.5, 5, 0, 15)
    riskBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
    riskBtn.BackgroundTransparency = 0.2
    riskBtn.Text = "⚠️ Risk"
    riskBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    riskBtn.TextSize = 13
    riskBtn.Font = Enum.Font.GothamMedium
    riskBtn.Parent = gui
    
    local riskCorner = Instance.new("UICorner", riskBtn)
    riskCorner.CornerRadius = UDim.new(0, 10)
    
    dashboardBtn.MouseButton1Click:Connect(function()
        if not coverGuiVisible then
            createCoverGui()
            coverGuiVisible = true
        end
    end)
    
    riskBtn.MouseButton1Click:Connect(function()
        if not riskGuiVisible then
            createRiskGui()
            riskGuiVisible = true
        end
    end)
    
    toggleButton = dashboardBtn
end

-- ============================================
-- SKY PLATFORM SYSTEM
-- ============================================

local PLATFORM_HEIGHT = 5000
local PLATFORM_SIZE = Vector3.new(20, 10, 20)
local platform = nil
local firstTouch = false

local function createSkyPlatform()
    if platform == nil or not platform.Parent then
        platform = Instance.new("Part")
        platform.Size = PLATFORM_SIZE
        platform.Anchored = true
        platform.CanCollide = true
        platform.Material = Enum.Material.Plastic
        platform.Color = Color3.fromRGB(255, 255, 255)
        platform.Name = "SkyPlatform"
        platform.Parent = workspace
        local faces = {Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}
        for _, face in ipairs(faces) do
            local texture = Instance.new("Texture")
            texture.Texture = "rbxassetid://93820988523572"
            texture.Face = face
            texture.StudsPerTileU = 4
            texture.StudsPerTileV = 4
            texture.Parent = platform
        end
    end
    platform.Position = Vector3.new(0, PLATFORM_HEIGHT, 0)
end

local function teleportToPlatform()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:MoveTo(platform.Position + Vector3.new(0, PLATFORM_SIZE.Y / 2 + 5, 0))
        if not firstTouch then
            firstTouch = true
            showNotificationQueue("✨ Flight System Activated!", Color3.fromRGB(0, 200, 0))
        end
    end
end

local function getClosestTicket()
    local ticketsFolder = workspace:FindFirstChild("Game") 
        and workspace.Game:FindFirstChild("Effects") 
        and workspace.Game.Effects:FindFirstChild("Tickets")
    
    if not ticketsFolder or #ticketsFolder:GetChildren() == 0 then
        return nil
    end
    
    local closestPart = nil
    local closestDist = math.huge
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    
    for _, ticket in ipairs(ticketsFolder:GetChildren()) do
        local ticketPart = ticket:FindFirstChild("HumanoidRootPart") or (ticket:IsA("BasePart") and ticket)
        if ticketPart then
            local dist = (ticketPart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPart = ticketPart
            end
        end
    end
    
    return closestPart
end

local function startSkyPlatform()
    task.spawn(function()
        while task.wait(0.2) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                createSkyPlatform()
                
                local ticketPart = getClosestTicket()
                
                if AutoTicketEnabled and ticketPart then
                    player.Character:MoveTo(ticketPart.Position)
                else
                    teleportToPlatform()
                end
            end
        end
    end)
end

-- ============================================
-- CHARACTER HANDLER
-- ============================================

local function setupCharacterHandler(char)
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        task.wait(1)
        local remote = game.ReplicatedStorage:FindFirstChild("Events")
            and game.ReplicatedStorage.Events:FindFirstChild("Player")
            and game.ReplicatedStorage.Events.Player:FindFirstChild("ChangePlayerMode")
        if remote then 
            remote:FireServer(true)
        end
    end)
end

player.CharacterAdded:Connect(function(char)
    setupCharacterHandler(char)
    
    if isFirstSpawn then 
        isFirstSpawn = false
        return
    end
    
    respawnCount = respawnCount + 1
    rounds = rounds + 1
    showNotificationQueue("🎉 Win #" .. rounds .. " (Respawns: " .. respawnCount .. "/5)", Color3.fromRGB(0, 200, 255))
    
    if longFarmMode then
        if respawnCount >= 5 then
            performServerHop()
        end
    end
end)

if player.Character then setupCharacterHandler(player.Character) end

-- ============================================
-- ANTI-AFK
-- ============================================

player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- ============================================
-- IDLE SCREENSAVER DETECTOR
-- ============================================

task.spawn(function()
    while true do
        task.wait(1)
        if not screensaverVisible then
            idleTime = idleTime + 1
            
            if idleTime >= 30 then
                createScreensaver()
                idleTime = 0
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not screensaverVisible then
        idleTime = 0
    end
end)

UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
    if not screensaverVisible then
        idleTime = 0
    end
end)

-- ============================================
-- DISCORD WEBHOOK
-- ============================================

local function sendDiscordUpdate(isInitial)
    local currentTotalTime = savedTime + math.floor(tick() - startTime)
    local hours = math.floor(currentTotalTime / 3600)
    local minutes = math.floor((currentTotalTime % 3600) / 60)
    local seconds = currentTotalTime % 60
    local totalTimeFormatted = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    local username = player.Name
    local jobId = game.JobId

    local embedData = {
        title = isInitial and "🚀 Apple Hub Started" or "🔄 Apple Hub Update",
        description = isInitial and ("Có 1 thiết bị đang chạy với **username**: `" .. username .. "`") or ("Cập nhật real-time cho **" .. username .. "**:"),
        color = isInitial and 65280 or 16776960,
        fields = {
            {name = "⏱️ Thời gian chạy tổng", value = "**" .. totalTimeFormatted .. "**", inline = true},
            {name = "🎮 Tổng wins", value = tostring(rounds), inline = true},
            {name = "🌐 Số server đã hop", value = tostring(hopCount), inline = true},
            {name = "🎯 FPS hiện tại", value = tostring(fps), inline = true},
            {name = "🆔 JobId server", value = "```\n" .. (jobId == "" and "Private Server" or jobId) .. "\n```", inline = false}
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local payload = HttpService:JSONEncode({embeds = {embedData}})
    
    local request_func = (syn and syn.request) or (http and http.request) or (request) or (fluxus and fluxus.request) or HttpService.RequestAsync
    
    if request_func then
        pcall(function()
            request_func({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
    end
end

task.spawn(function()
    task.wait(3)
    sendDiscordUpdate(true)
end)

task.spawn(function()
    while true do
        task.wait(60)
        if player.Parent then
            sendDiscordUpdate(false)
        end
    end
end)

-- ============================================
-- TELEPORT HANDLERS
-- ============================================

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn("Teleport failed:", errorMessage)
    showNotificationQueue("⚠️ Teleport failed: " .. tostring(teleportResult), Color3.fromRGB(255, 100, 0))
    respawnCount = 0
end)

player.OnTeleport:Connect(function()
    saveData()
end)

player.AncestryChanged:Connect(function()
    if not player:IsDescendantOf(game) then
        saveData()
        if AutoMoneyFarmConnection then
            stopAutoMoneyFarm()
        end
    end
end)

-- ============================================
-- LONG FARM ASK GUI
-- ============================================

local function askLongFarm()
    local playerGui = player:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "LongFarmAsk"
    gui.Parent = playerGui
    gui.DisplayOrder = 999999
    gui.IgnoreGuiInset = true
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Parent = gui
    
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, 320, 0, 140)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BackgroundTransparency = 0.05
    frame.Parent = overlay
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 16)
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 30)
    title.Position = UDim2.new(0, 20, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "Chế độ Kaitun"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 0, 30)
    label.Position = UDim2.new(0, 20, 0, 50)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(170, 170, 180)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.Text = "Bạn có muốn bật chế độ kaitun không?"
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local noBtn = Instance.new("TextButton")
    noBtn.Size = UDim2.new(0, 140, 0, 38)
    noBtn.Position = UDim2.new(0, 15, 1, -50)
    noBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    noBtn.Text = "Không"
    noBtn.TextColor3 = Color3.new(1, 1, 1)
    noBtn.TextSize = 14
    noBtn.Font = Enum.Font.GothamMedium
    noBtn.Parent = frame
    
    local noCorner = Instance.new("UICorner", noBtn)
    noCorner.CornerRadius = UDim.new(0, 10)
    
    local yesBtn = Instance.new("TextButton")
    yesBtn.Size = UDim2.new(0, 140, 0, 38)
    yesBtn.Position = UDim2.new(1, -155, 1, -50)
    yesBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
    yesBtn.Text = "Có"
    yesBtn.TextColor3 = Color3.new(1, 1, 1)
    yesBtn.TextSize = 14
    yesBtn.Font = Enum.Font.GothamMedium
    yesBtn.Parent = frame
    
    local yesCorner = Instance.new("UICorner", yesBtn)
    yesCorner.CornerRadius = UDim.new(0, 10)
    
    local function answer(selected)
        gui:Destroy()
        longFarmMode = selected
        showNotificationQueue(selected and "✅ Bật chế độ Kaitun" or "⛔ Không bật Kaitun", selected and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0))
        task.wait(1)
        createToggleButtons()
        startSkyPlatform()
        showNotificationQueue("✅ Flight System Activated!", Color3.fromRGB(0, 200, 0))
        
        -- Apply saved settings nếu đang hop
        if isHopping then
            if FixLagEnabled then
                showNotificationQueue("⚡ Restoring Fix Lag...", Color3.fromRGB(255, 165, 0))
                task.wait(0.5)
                applyExtremeLagFix()
            end
            
            if AutoMoneyFarmEnabled then
                startAutoMoneyFarm()
            end
            
            if AutoTicketEnabled then
                showNotificationQueue("✅ Auto Ticket restored from last session", Color3.fromRGB(0, 200, 0))
            end
        else
            showNotificationQueue("⚠️ Auto Ticket is OFF - Open Risk Features to enable", Color3.fromRGB(255, 165, 0))
        end
        
        local remote = game.ReplicatedStorage:FindFirstChild("Events")
            and game.ReplicatedStorage.Events:FindFirstChild("Player")
            and game.ReplicatedStorage.Events.Player:FindFirstChild("ChangePlayerMode")
        if remote then remote:FireServer(true) end
        showNotificationQueue("🍎 Apple Hub Ready!", Color3.fromRGB(0, 200, 0))
    end
    
    yesBtn.MouseButton1Click:Connect(function() answer(true) end)
    noBtn.MouseButton1Click:Connect(function() answer(false) end)
end

-- ============================================
-- INITIALIZATION
-- ============================================

if isHopping then
    longFarmMode = true
    createToggleButtons()
    startSkyPlatform()
    showNotificationQueue("✅ Flight System Activated!", Color3.fromRGB(0, 200, 0))
    
    -- Apply saved settings
    if FixLagEnabled then
        showNotificationQueue("⚡ Restoring Fix Lag...", Color3.fromRGB(255, 165, 0))
        task.wait(0.5)
        applyExtremeLagFix()
    end
    
    if AutoMoneyFarmEnabled then
        startAutoMoneyFarm()
    end
    
    if AutoTicketEnabled then
        showNotificationQueue("✅ Auto Ticket restored", Color3.fromRGB(0, 200, 0))
    end
    
    local remote = game.ReplicatedStorage:FindFirstChild("Events")
        and game.ReplicatedStorage.Events:FindFirstChild("Player")
        and game.ReplicatedStorage.Events.Player:FindFirstChild("ChangePlayerMode")
    if remote then remote:FireServer(true) end
    showNotificationQueue("🍎 Apple Hub Ready! (Hopped " .. hopCount .. " times)", Color3.fromRGB(0, 200, 0))
else
    askLongFarm()
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🍎 APPLE HUB - FULLY LOADED")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ All features ready!")
print("💰 Auto Money Farm available in Risk Features")
print("🔄 Settings save system enabled")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
