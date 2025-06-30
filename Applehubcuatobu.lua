local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
local angle = 0

local rounds = 0
local isFirstSpawn = true

local bodyVelocity = nil

local function showNotification(txt, color)
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
	frame.BackgroundColor3 = color or Color3.fromRGB(50, 50, 50)
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
	label.Text = txt
	label.Parent = frame

	TweenService:Create(
		frame,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, -20, 0, 20)}
	):Play()

	task.delay(3, function()
		TweenService:Create(
			frame,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{Position = UDim2.new(1.2, 0, 0, 20)}
		):Play()
		task.wait(0.4)
		gui:Destroy()
	end)
end

local function showStartNotice(callback)
	local playerGui = player:WaitForChild("PlayerGui")

	if playerGui:FindFirstChild("StartNoticeGui") then
		playerGui.StartNoticeGui:Destroy()
	end

	local startGui = Instance.new("ScreenGui")
	startGui.Name = "StartNoticeGui"
	startGui.IgnoreGuiInset = true
	startGui.ResetOnSpawn = false
	startGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	startGui.Parent = playerGui

	local noticeFrame = Instance.new("Frame")
	noticeFrame.AnchorPoint = Vector2.new(1, 0)
	noticeFrame.Position = UDim2.new(1.2, 0, 0, 20)
	noticeFrame.Size = UDim2.new(0.4, 0, 0.15, 0)
	noticeFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	noticeFrame.BackgroundTransparency = 0.3
	noticeFrame.BorderSizePixel = 0
	noticeFrame.Parent = startGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = noticeFrame

	local noticeLabel = Instance.new("TextLabel")
	noticeLabel.Size = UDim2.new(1, -20, 1, -20)
	noticeLabel.Position = UDim2.new(0, 10, 0, 10)
	noticeLabel.BackgroundTransparency = 1
	noticeLabel.TextColor3 = Color3.new(1, 1, 1)
	noticeLabel.TextScaled = true
	noticeLabel.Font = Enum.Font.GothamBold
	noticeLabel.TextWrapped = true
	noticeLabel.Text = "‼️ Sử Dụng Badge Và Briefcase để cày được tối ưu hơn , Vui Lòng Bấm Nút Join Game\nChe Màn Hình Sẽ Kích Hoạt Sau 10 Giây."
	noticeLabel.Parent = noticeFrame

	TweenService:Create(
		noticeFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, -20, 0, 20)}
	):Play()

	task.spawn(function()
		for i = 10, 1, -1 do
			noticeLabel.Text = "‼️ VUI LÒNG BẤM NÚT JOIN GAME\nCHE MÀN HÌNH SẼ ĐƯỢC KÍCH HOẠT SAU "..i.." GIÂY."
			task.wait(1)
		end
		startGui:Destroy()
		if callback then
			callback()
		end
	end)
end

local function teleportToSafePosition()
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = CFrame.new(safePosition)
		showNotification("✅ Đã dịch chuyển đến vị trí an toàn.", Color3.fromRGB(0, 200, 0))
	else
		showNotification("❌ Không tìm thấy HumanoidRootPart.", Color3.fromRGB(255, 0, 0))
	end
end

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

-- Bay mượt bằng BodyVelocity
RunService.RenderStepped:Connect(function(dt)
	if autoFly then
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local hrp = char.HumanoidRootPart
			hrp.Anchored = false

			if not bodyVelocity or not bodyVelocity.Parent then
				bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
				bodyVelocity.P = 5000
				bodyVelocity.Parent = hrp
			end

			angle += dt * speed
			local offset = Vector3.new(
				math.cos(angle) * radius,
				0,
				math.sin(angle) * radius
			)
			local targetPos = Vector3.new(safePosition.X, safePosition.Y, safePosition.Z) + offset
			local direction = (targetPos - hrp.Position)
			bodyVelocity.Velocity = direction * 3
		end
	else
		if bodyVelocity then
			bodyVelocity:Destroy()
			bodyVelocity = nil
		end
	end
end)

-- Noclip
RunService.Stepped:Connect(function()
	if autoFly then
		local char = player.Character
		if char then
			for _,v in pairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
		end
	end
end)

player.CharacterAdded:Connect(function()
	if isFirstSpawn then
		isFirstSpawn = false
	else
		rounds += 1
		showNotification("🎉 Đã hoàn thành 1 trận mới!", Color3.fromRGB(0, 200, 255))
		task.wait(1)
		teleportToSafePosition()
		createCoverGui()
		task.delay(1, function()
			autoFly = true
			showNotification("✅ Hệ thống bay đã hoạt động.", Color3.fromRGB(0, 200, 0))
		end)
	end
end)

showStartNotice(function()
	teleportToSafePosition()
	createCoverGui()
	task.delay(1, function()
		autoFly = true
		showNotification("✅ Hệ thống bay đã hoạt động.", Color3.fromRGB(0, 200, 0))
	end)
end)
