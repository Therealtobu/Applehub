-- Auto kick nếu không phải game Evade (trừ Pro mode)
local allowedPlaceId = 9872472334 -- Evade
local ProModeKeyword = "Pro"

if game.PlaceId == allowedPlaceId then
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder then
        local mapName = mapFolder.Name
        if not string.find(mapName, ProModeKeyword) then
            -- Không ở Pro mode, vẫn cho phép
        else
            -- Ở Pro mode, không kick
            return
        end
    end
else
    game.Players.LocalPlayer:Kick("Game này không hỗ trợ!")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local fps = 0
local lastTick = tick()
local frameCount = 0

-- FPS tracker
RunService.RenderStepped:Connect(function()
	frameCount += 1
	if tick() - lastTick >= 1 then
		fps = frameCount
		frameCount = 0
		lastTick = tick()
	end
end)

local startTime = tick()
local safePosition = Vector3.new(1000, 350, 1000)
local center = safePosition

local autoFly = false
local radius = 200
local speed = 2
local height = 350
local angle = 0

local bodyPosition = nil
local rounds = 0
local isFirstSpawn = true

------------------------------------------
-- Notification Queue
------------------------------------------

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

				if playerGui:FindFirstChild(guiName) then
					playerGui[guiName]:Destroy()
				end

				local gui = Instance.new("ScreenGui")
				gui.Name = guiName
				gui.Parent = playerGui
				gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				gui.DisplayOrder = 999999

				local frame = Instance.new("Frame")
				frame.AnchorPoint = Vector2.new(1, 0)
				frame.Position = UDim2.new(1.2, 0, 0, 20)
				frame.Size = UDim2.new(0, 250, 0, 50)
				frame.BackgroundColor3 = data.Color or Color3.fromRGB(50, 50, 50)
				frame.BackgroundTransparency = 0.2
				frame.BorderSizePixel = 0
				frame.Parent = gui

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = frame

				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, -20, 1, -20)
				label.Position = UDim2.new(0, 10, 0, 10)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextSize = 14
				label.Font = Enum.Font.SourceSansBold
				label.TextWrapped = true
				label.Text = data.Text
				label.Parent = frame

				-- Slide in
				TweenService:Create(
					frame,
					TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{Position = UDim2.new(1, -20, 0, 20)}
				):Play()

				task.wait(3)

				-- Slide out
				TweenService:Create(
					frame,
					TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
					{Position = UDim2.new(1.2, 0, 0, 20)}
				):Play()

				task.wait(0.5)
				gui:Destroy()
			end

			NotificationBusy = false
		end)
	end
end

------------------------------------------
-- Startup Notice (trượt vào, ở yên)
------------------------------------------

local startupGui = nil

local function showStartupNotice()
	local playerGui = player:WaitForChild("PlayerGui")

	if playerGui:FindFirstChild("StartupNoticeGui") then
		playerGui.StartupNoticeGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "StartupNoticeGui"
	gui.Parent = playerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999999

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1.2, 0, 0, 20)
	frame.Size = UDim2.new(0, 300, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -20)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Font = Enum.Font.SourceSansBold
	label.TextWrapped = true
	label.Text = "Dùng Badge Và Briefcase Để Cày được Tối Ưu Hơn\nVui Lòng Bấm Nút Join Game\nscript làm bởi Tobu"
	label.Parent = frame

	-- Slide in
	TweenService:Create(
		frame,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, -20, 0, 20)}
	):Play()

	startupGui = gui
end

local function hideStartupNotice()
	if startupGui then
		local frame = startupGui:FindFirstChildOfClass("Frame")
		if frame then
			TweenService:Create(
				frame,
				TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{Position = UDim2.new(1.2, 0, 0, 20)}
			):Play()
			task.wait(0.5)
		end
		startupGui:Destroy()
		startupGui = nil
	end
end

------------------------------------------
-- Cover GUI
------------------------------------------

local function createCoverGui()
	local playerGui = player:WaitForChild("PlayerGui")

	if playerGui:FindFirstChild("CoverGui") then
		playerGui.CoverGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoverGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 10000
	gui.Parent = playerGui

	local overlayFrame = Instance.new("Frame")
	overlayFrame.Size = UDim2.new(1, 0, 1, 0)
	overlayFrame.Position = UDim2.new(0, 0, 0, 0)
	overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	overlayFrame.BackgroundTransparency = 0.4
	overlayFrame.Parent = gui

	local centerFrame = Instance.new("Frame")
	centerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	centerFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerFrame.Size = UDim2.new(0.45, 0, 0.3, 0)
	centerFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	centerFrame.BackgroundTransparency = 0.3
	centerFrame.BorderSizePixel = 0
	centerFrame.Parent = overlayFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = centerFrame

	local centerLabel = Instance.new("TextLabel")
	centerLabel.Size = UDim2.new(1, -20, 1, -20)
	centerLabel.Position = UDim2.new(0, 10, 0, 10)
	centerLabel.BackgroundTransparency = 1
	centerLabel.TextColor3 = Color3.new(1, 1, 1)
	centerLabel.Font = Enum.Font.GothamBold
	centerLabel.TextSize = 16
	centerLabel.TextWrapped = true
	centerLabel.TextYAlignment = Enum.TextYAlignment.Top
	centerLabel.RichText = true
	centerLabel.Text = "🍎 Apple Hub 🍎\nĐang tải dữ liệu..."
	centerLabel.Parent = centerFrame

	task.spawn(function()
		while true do
			local elapsed = math.floor(tick() - startTime)
			local hours = math.floor(elapsed / 3600)
			local minutes = math.floor((elapsed % 3600) / 60)
			local seconds = elapsed % 60

			centerLabel.Text =
				"🍎 <b>Apple Hub</b> 🍎\n\n" ..
				"🎯 FPS: <b>".. tostring(fps) .."</b>\n" ..
				"⏳ Thời gian chạy: <b>".. string.format("%02d:%02d:%02d", hours, minutes, seconds) .. "</b>\n" ..
				"🎮 Số trận hoàn thành: <b>" .. tostring(rounds) .. "</b>"

			task.wait(1)
		end
	end)
end

------------------------------------------
-- Fly System
------------------------------------------

local function startFlying()
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hrp.CFrame = CFrame.new(safePosition)

	if bodyPosition then
		bodyPosition:Destroy()
		bodyPosition = nil
	end

	bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bodyPosition.D = 1000
	bodyPosition.P = 30000
	bodyPosition.Position = safePosition + Vector3.new(0, height, 0)
	bodyPosition.Parent = hrp
	autoFly = true
end

RunService.RenderStepped:Connect(function(dt)
	if autoFly and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		angle += dt * speed
		local offset = Vector3.new(
			math.cos(angle) * radius,
			0,
			math.sin(angle) * radius
		)
		local pos = center + offset + Vector3.new(0, height, 0)
		bodyPosition.Position = pos
	end
end)

RunService.Stepped:Connect(function()
	if autoFly and player.Character then
		for _, v in pairs(player.Character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
	end
end)

------------------------------------------
-- Spawn Handler
------------------------------------------

player.CharacterAdded:Connect(function()
	hideStartupNotice()

	if isFirstSpawn then
		isFirstSpawn = false
	else
		rounds += 1
		showNotificationQueue("🎉 Đã hoàn thành 1 trận mới!", Color3.fromRGB(0, 200, 255))
	end

	task.delay(1, function()
		createCoverGui()
		startFlying()
		showNotificationQueue("✅ Hệ thống bay đã hoạt động.", Color3.fromRGB(0, 200, 0))
	end)
end)

------------------------------------------
-- Anti AFK
------------------------------------------

player.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

------------------------------------------
-- Anti Ban (giả lập)
------------------------------------------

task.spawn(function()
	while task.wait(10) do
		-- fake logic
	end
end)

------------------------------------------
-- Show Startup Notice
------------------------------------------

showStartupNotice()
