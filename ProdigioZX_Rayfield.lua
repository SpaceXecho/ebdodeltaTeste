--[[
	PRODIGIOZX - Convertido para Rayfield
	Todas as funções originais separadas e organizadas em abas
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- =====================================================
-- SERVIÇOS E VARIÁVEIS GLOBAIS
-- =====================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

local SavedRoutes = {}
local SaveFileNameFolder = "ProdigioZX_Parkour"
local SaveFileNameFile = "SavedRoutes.json"

-- =====================================================
-- FUNÇÕES AUXILIARES (globais)
-- =====================================================
local function SaveRoutesToFile()
	local success, encoded = pcall(function()
		return HttpService:JSONEncode(SavedRoutes)
	end)
	if success then
		if not isfolder(SaveFileNameFolder) then
			makefolder(SaveFileNameFolder)
		end
		writefile(SaveFileNameFolder .. "/" .. SaveFileNameFile, encoded)
	end
end

local function LoadRoutesFromFile()
	if readfile and isfile and isfile(SaveFileNameFolder .. "/" .. SaveFileNameFile) then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(SaveFileNameFolder .. "/" .. SaveFileNameFile))
		end)
		if success and type(decoded) == "table" then
			SavedRoutes = decoded
		end
	end
end
LoadRoutesFromFile()

local function GetChar()
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChild("Humanoid")
		return char, root, hum
	end
	return nil, nil, nil
end

local function formatTime(seconds)
	if not seconds then return "0s" end
	if seconds < 60 then
		return math.floor(seconds) .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	else
		return string.format("%.1fh", seconds / 3600)
	end
end

local function EquipToolByName(toolNameKeyword)
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not char then return end
	local equipped = char:FindFirstChildOfClass("Tool")
	if equipped and string.find(string.lower(equipped.Name), string.lower(toolNameKeyword)) then
		return
	end
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(toolNameKeyword)) then
				char.Humanoid:EquipTool(tool)
				break
			end
		end
	end
end

-- =====================================================
-- JANELA RAYFIELD
-- =====================================================
local Window = Rayfield:CreateWindow({
	Name = "⚡ PRODIGIOZX",
	Icon = 0,
	LoadingTitle = "PRODIGIOZX",
	LoadingSubtitle = "by prodigiozx",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "ProdigioZX",
		FileName = "ProdigioZX_Config"
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true
	},
	KeySystem = false
})

-- =====================================================
-- ABA 1: GRAVADOR (Macro / Mini-Hub)
-- =====================================================
local MacroTab = Window:CreateTab("🎬 Gravador", nil)
local MacroSection = MacroTab:CreateSection("Painel Flutuante & Gravador Pro")

-- Variáveis do Mini-Hub
local MiniHubEnabled = false
local miniReplaying, miniRecording = false, false
local miniReplayConn, miniRecordConn = nil, nil
local miniRecordedPath = {}
local miniRecordStartTime = 0
local miniActiveVisualParts = {}
local miniRecordingCounter = 0
local miniShowPathLines = true
local miniSelectedFileName = nil
local controls = nil

pcall(function()
	local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	controls = PlayerModule:GetControls()
end)

local function clearVisualElements()
	for _, obj in ipairs(miniActiveVisualParts) do
		if obj and obj.Parent then obj:Destroy() end
	end
	miniActiveVisualParts = {}
end

local function renderVisualPath(pathData)
	clearVisualElements()
	if not miniShowPathLines or not pathData or #pathData == 0 then return end
	local firstPoint = pathData[1]
	if firstPoint and firstPoint.CF then
		local startPart = Instance.new("Part")
		startPart.Size = Vector3.new(0.8, 0.8, 0.8)
		startPart.Shape = Enum.PartType.Ball
		startPart.Color = Color3.fromRGB(255, 165, 0)
		startPart.Material = Enum.Material.Neon
		startPart.Anchored = true
		startPart.CanCollide = false
		startPart.Position = CFrame.new(unpack(firstPoint.CF)).Position + Vector3.new(0, 0.5, 0)
		startPart.Parent = workspace
		table.insert(miniActiveVisualParts, startPart)
	end
	for i = 1, #pathData - 1 do
		local p1, p2 = pathData[i], pathData[i + 1]
		if p1 and p2 and p1.CF and p2.CF then
			local cf1, cf2 = CFrame.new(unpack(p1.CF)), CFrame.new(unpack(p2.CF))
			local part = Instance.new("Part")
			local distance = (cf1.Position - cf2.Position).Magnitude
			part.Size = Vector3.new(0.2, 0.2, distance)
			part.Color = Color3.fromRGB(255, 120, 0)
			part.Material = Enum.Material.Neon
			part.Anchored = true
			part.CanCollide = false
			part.CFrame = CFrame.new(cf1.Position:Lerp(cf2.Position, 0.5), cf2.Position)
			part.Parent = workspace
			table.insert(miniActiveVisualParts, part)
		end
	end
end

local function stopReplay(msg)
	miniReplaying = false
	if controls then pcall(function() controls:Enable() end) end
	if miniReplayConn then miniReplayConn:Disconnect(); miniReplayConn = nil end
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if rootPart then rootPart.AssemblyLinearVelocity = Vector3.zero end
	if hum then hum.AutoRotate = true; hum.PlatformStand = false; hum:Move(Vector3.zero) end
	Rayfield:Notify({Title = "Replay", Content = msg or "Parado", Duration = 3})
end

local function playRecordedPath()
	if not miniReplaying then return end
	local char = player.Character
	local humanoid = char and char:FindFirstChild("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then stopReplay("ERRO!"); return end
	local totalPoints = #miniRecordedPath
	if totalPoints < 2 then stopReplay("Rota muito curta!"); return end

	local targetStartPos = CFrame.new(unpack(miniRecordedPath[1].CF)).Position
	while (rootPart.Position - targetStartPos).Magnitude > 1 and miniReplaying do
		local c = player.Character
		local hm = c and c:FindFirstChild("Humanoid")
		local rp = c and c:FindFirstChild("HumanoidRootPart")
		if not hm or not rp then break end
		hm:MoveTo(targetStartPos)
		RunService.Heartbeat:Wait()
	end
	if not miniReplaying then return end

	humanoid.AutoRotate = false
	local startTime = tick()
	local currentIndex = 1
	local lastPos = rootPart.Position
	local lastTime = tick()
	local isFirstFrame = true

	miniReplayConn = RunService.Heartbeat:Connect(function()
		if not miniReplaying then
			if miniReplayConn then miniReplayConn:Disconnect(); miniReplayConn = nil end
			return
		end
		local c = player.Character
		humanoid = c and c:FindFirstChild("Humanoid")
		rootPart = c and c:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then stopReplay("ERRO!"); return end

		local elapsed = tick() - startTime
		if elapsed >= miniRecordedPath[totalPoints].Time then
			stopReplay("CONCLUÍDO!")
			return
		end

		while currentIndex < totalPoints and elapsed > miniRecordedPath[currentIndex + 1].Time do
			currentIndex = currentIndex + 1
		end

		local p1 = miniRecordedPath[currentIndex]
		local p2 = miniRecordedPath[math.min(currentIndex + 1, totalPoints)]
		if p1 and p2 and p1.CF and p2.CF then
			local cf1, cf2 = CFrame.new(unpack(p1.CF)), CFrame.new(unpack(p2.CF))
			local timeDiff = p2.Time - p1.Time
			local t = timeDiff > 0 and math.clamp((elapsed - p1.Time) / timeDiff, 0, 1) or 1
			local targetCFrame = cf1:Lerp(cf2, t)
			local now = tick()
			local dt = math.max(0.001, now - lastTime)
			if isFirstFrame then lastPos = targetCFrame.Position; lastTime = now; isFirstFrame = false end

			local moveVector = targetCFrame.Position - lastPos
			local horizDist = Vector3.new(moveVector.X, 0, moveVector.Z).Magnitude
			lastPos = targetCFrame.Position
			lastTime = now

			rootPart.CFrame = targetCFrame
			if horizDist > 0.05 or math.abs(moveVector.Y) > 0.1 then
				rootPart.AssemblyLinearVelocity = moveVector / dt
				humanoid.Jump = (moveVector.Y > 0.25)
				humanoid:Move(Vector3.new(0, 0, -1), true)
			else
				rootPart.AssemblyLinearVelocity = Vector3.zero
				humanoid.Jump = false
				humanoid:Move(Vector3.zero, true)
			end
		end
	end)
end

-- Toggle: Ativar Mini-Hub
MacroTab:CreateToggle({
	Name = "📱 Ativar Mini-Hub na Tela",
	CurrentValue = false,
	Flag = "MiniHubToggle",
	Callback = function(Value)
		MiniHubEnabled = Value
		if _G.ProdigizxMiniHub then
			_G.ProdigizxMiniHub.Enabled = Value
		end
		Rayfield:Notify({Title = "Mini-Hub", Content = Value and "Ativado" or "Desativado", Duration = 2})
	end
})

-- Botão: Gravar Rota
MacroTab:CreateButton({
	Name = "🔴 Iniciar / Parar Gravação",
	Callback = function()
		if miniRecording then
			miniRecording = false
			if miniRecordConn then miniRecordConn:Disconnect(); miniRecordConn = nil end
			if #miniRecordedPath > 0 then
				miniRecordingCounter = miniRecordingCounter + 1
				local autoName = "Gravação " .. miniRecordingCounter
				local copy = {}
				for i, p in ipairs(miniRecordedPath) do
					copy[i] = { CF = p.CF, Time = p.Time, Jumping = p.Jumping }
				end
				SavedRoutes[autoName] = copy
				miniSelectedFileName = autoName
				SaveRoutesToFile()
				renderVisualPath(copy)
				Rayfield:Notify({Title = "Gravação", Content = "Salva: " .. autoName, Duration = 3})
			end
		else
			if miniReplaying then stopReplay() end
			local char = player.Character
			if not char then return end
			miniRecordedPath = {}
			miniRecording = true
			miniRecordStartTime = tick()
			Rayfield:Notify({Title = "Gravação", Content = "GRAVANDO...", Duration = 2})
			miniRecordConn = RunService.Heartbeat:Connect(function()
				if not miniRecording then
					if miniRecordConn then miniRecordConn:Disconnect(); miniRecordConn = nil end
					return
				end
				local rp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local hm = player.Character and player.Character:FindFirstChild("Humanoid")
				if rp and hm then
					local isJumping = hm:GetState() == Enum.HumanoidStateType.Jumping or hm:GetState() == Enum.HumanoidStateType.Freefall
					table.insert(miniRecordedPath, {
						Time = tick() - miniRecordStartTime,
						CF = { rp.CFrame:GetComponents() },
						Jumping = isJumping
					})
				end
			end)
		end
	end
})

-- Botão: Reproduzir Rota
MacroTab:CreateButton({
	Name = "▶ Reproduzir Rota Selecionada",
	Callback = function()
		if miniReplaying then
			stopReplay("CANCELADO")
			return
		end
		if miniSelectedFileName and SavedRoutes[miniSelectedFileName] then
			miniRecordedPath = SavedRoutes[miniSelectedFileName]
		end
		if #miniRecordedPath < 2 then
			Rayfield:Notify({Title = "Erro", Content = "Selecione uma rota válida!", Duration = 3})
			return
		end
		if controls then pcall(function() controls:Disable() end) end
		miniReplaying = true
		Rayfield:Notify({Title = "Replay", Content = "Reproduzindo...", Duration = 2})
		task.wait(0.05)
		playRecordedPath()
	end
})

-- Botão: Salvar Rotas
MacroTab:CreateButton({
	Name = "💾 Salvar Todas as Rotas",
	Callback = function()
		SaveRoutesToFile()
		Rayfield:Notify({Title = "Salvo", Content = "Rotas salvas com sucesso!", Duration = 2})
	end
})

-- Botão: Limpar Rota Atual
MacroTab:CreateButton({
	Name = "🗑️ Limpar Rota Atual",
	Callback = function()
		if miniRecording or miniReplaying then stopReplay() end
		miniRecordedPath = {}
		clearVisualElements()
		Rayfield:Notify({Title = "Limpo", Content = "Rota limpa!", Duration = 2})
	end
})

-- Toggle: Mostrar Linhas de Rota
MacroTab:CreateToggle({
	Name = "Mostrar Linhas de Rota",
	CurrentValue = true,
	Flag = "ShowPathLines",
	Callback = function(Value)
		miniShowPathLines = Value
		if Value and miniSelectedFileName and SavedRoutes[miniSelectedFileName] then
			renderVisualPath(SavedRoutes[miniSelectedFileName])
		else
			clearVisualElements()
		end
	end
})

-- =====================================================
-- ABA 2: FAZENDA (Auto Farm)
-- =====================================================
local FarmTab = Window:CreateTab("🌾 Fazenda", nil)
local FarmSection = FarmTab:CreateSection("Gerenciador de Missões")

local FarmConfig = { Enabled = false, SelectedMission = "Lixo" }
local collectedTrash = {}
local hasBoughtScythe = false
local ignoredGrass = {}
local activeVisualHighlights = {}

local function ClearActiveHighlights()
	for _, hl in pairs(activeVisualHighlights) do
		if hl and hl.Parent then hl:Destroy() end
	end
	activeVisualHighlights = {}
end

local function GetClosestPromptByAction(actionText, ignoreTable)
	local char, root, hum = GetChar()
	if not root then return nil end
	local closestPrompt, shortestDist = nil, math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.ActionText == actionText then
			local parentPart = obj.Parent
			if parentPart and parentPart:IsA("BasePart") then
				local skip = false
				if ignoreTable then
					for _, oldPart in pairs(ignoreTable) do
						if oldPart == parentPart then skip = true; break end
					end
				end
				if not skip then
					local dist = (root.Position - parentPart.Position).Magnitude
					if dist < shortestDist then
						shortestDist = dist
						closestPrompt = obj
					end
				end
			end
		end
	end
	return closestPrompt
end

-- Dropdown: Escolher Missão
FarmTab:CreateDropdown({
	Name = "Escolher Missão",
	Options = {"Lixo", "Grama"},
	CurrentOption = {"Lixo"},
	MultipleOptions = false,
	Flag = "FarmMission",
	Callback = function(Options)
		FarmConfig.SelectedMission = Options[1]
		Rayfield:Notify({Title = "Missão", Content = "Selecionado: " .. Options[1], Duration = 2})
	end
})

-- Toggle: Ativar Auto Missões
FarmTab:CreateToggle({
	Name = "Ativar Auto Missões",
	CurrentValue = false,
	Flag = "AutoFarmToggle",
	Callback = function(Value)
		FarmConfig.Enabled = Value
		Rayfield:Notify({Title = "Auto Farm", Content = Value and "Ligado" or "Desligado", Duration = 2})
	end
})

-- Loop do Farm
task.spawn(function()
	while true do
		task.wait(0.2)
		ClearActiveHighlights()
		if FarmConfig.Enabled then
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then
					local isTarget = false
					if FarmConfig.SelectedMission == "Lixo" and (obj.ActionText == "Recolher" or obj.ActionText == "Jogar Lixo") then
						isTarget = true
					elseif FarmConfig.SelectedMission == "Grama" and (obj.ActionText == "Comprar [2500$]" or obj.ActionText == "Cortar [Requer Foice]") then
						isTarget = true
					end
					if isTarget and obj.Parent and obj.Parent:IsA("BasePart") then
						local part = obj.Parent
						local highlight = Instance.new("Highlight")
						highlight.Name = "ProdigizxGreenESP"
						highlight.Adornee = part
						highlight.FillColor = Color3.fromRGB(0, 255, 0)
						highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
						highlight.FillTransparency = 0.4
						highlight.OutlineTransparency = 0
						highlight.Parent = part
						table.insert(activeVisualHighlights, highlight)
					end
				end
			end

			local char, root, hum = GetChar()
			if root and hum then
				if FarmConfig.SelectedMission == "Lixo" then
					local collectPrompt = GetClosestPromptByAction("Recolher", collectedTrash)
					if collectPrompt and collectPrompt.Parent and FarmConfig.Enabled then
						local part = collectPrompt.Parent
						if part:IsA("BasePart") then
							table.insert(collectedTrash, part)
							if #collectedTrash > 20 then table.remove(collectedTrash, 1) end
							root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
							task.wait(0.3)
							pcall(function() fireproximityprompt(collectPrompt) end)
						end
					end
					task.wait(0.3)
					local dropPrompt = GetClosestPromptByAction("Jogar Lixo", nil)
					if dropPrompt and dropPrompt.Parent and FarmConfig.Enabled then
						local part = dropPrompt.Parent
						if part:IsA("BasePart") then
							root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
							task.wait(0.3)
							pcall(function() fireproximityprompt(dropPrompt) end)
						end
					end
				elseif FarmConfig.SelectedMission == "Grama" then
					EquipToolByName("Foice")
					if not hasBoughtScythe then
						local buyPrompt = GetClosestPromptByAction("Comprar [2500$]", nil)
						if buyPrompt and buyPrompt.Parent and FarmConfig.Enabled then
							local part = buyPrompt.Parent
							if part:IsA("BasePart") then
								root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
								task.wait(0.4)
								pcall(function() fireproximityprompt(buyPrompt) end)
								task.wait(1)
								hasBoughtScythe = true
							end
						end
					else
						local cutPrompt = GetClosestPromptByAction("Cortar [Requer Foice]", ignoredGrass)
						if cutPrompt and cutPrompt.Parent and FarmConfig.Enabled then
							local part = cutPrompt.Parent
							if part:IsA("BasePart") then
								table.insert(ignoredGrass, part)
								if #ignoredGrass > 15 then table.remove(ignoredGrass, 1) end
								root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
								task.wait(0.3)
								pcall(function() fireproximityprompt(cutPrompt) end)
							end
						end
					end
				end
			end
		end
	end
end)

-- =====================================================
-- ABA 3: ESP
-- =====================================================
local EspTab = Window:CreateTab("👁️ ESP", nil)
local EspSection = EspTab:CreateSection("Configurações do ESP")

local ESP = {
	Enabled = false,
	Boxes = false,
	Lines = false,
	Names = false,
	Distance = false,
	Ranks = false,
	MaxDistance = 1000,
	MaxPlayers = 10,
	Color = Color3.fromRGB(255, 140, 0)
}

local ESP_LinesPool = {}
local function GetOrCreateLine(index)
	if not ESP_LinesPool[index] then
		local line = Drawing.new("Line")
		line.Visible = false
		line.Color = ESP.Color
		line.Thickness = 1
		line.Transparency = 1
		ESP_LinesPool[index] = line
	end
	return ESP_LinesPool[index]
end

local function CleanESP(char)
	if not char then return end
	local hl = char:FindFirstChild("PRDG_Highlight")
	local bb = char:FindFirstChild("PRDG_Billboard")
	if hl then hl:Destroy() end
	if bb then bb:Destroy() end
end

local function ApplyESP(targetPlayer)
	if targetPlayer == player then return end
	local function SetupCharacter(char)
		if not char then return end
		CleanESP(char)
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if not root then return end
		local hl = Instance.new("Highlight")
		hl.Name = "PRDG_Highlight"
		hl.FillColor = ESP.Color
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.Enabled = false
		hl.Parent = char
		local bb = Instance.new("BillboardGui")
		bb.Name = "PRDG_Billboard"
		bb.Adornee = root
		bb.Size = UDim2.new(0, 200, 0, 50)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		bb.Enabled = false
		local txt = Instance.new("TextLabel")
		txt.Name = "InfoText"
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.TextColor3 = ESP.Color
		txt.TextSize = 13
		txt.Font = Enum.Font.SourceSansBold
		txt.Parent = bb
		bb.Parent = char
	end
	if targetPlayer.Character then SetupCharacter(targetPlayer.Character) end
	targetPlayer.CharacterAdded:Connect(SetupCharacter)
end

for _, p in ipairs(Players:GetPlayers()) do ApplyESP(p) end
Players.PlayerAdded:Connect(ApplyESP)

RunService.RenderStepped:Connect(function()
	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local sortedPlayers = {}
	for _, line in pairs(ESP_LinesPool) do line.Visible = false end
	if myRoot then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local root = p.Character.HumanoidRootPart
					local dist = (myRoot.Position - root.Position).Magnitude
					if dist <= ESP.MaxDistance then
						table.insert(sortedPlayers, {player = p, Distance = dist})
					end
				end
			end
		end
		table.sort(sortedPlayers, function(a, b) return a.Distance < b.Distance end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local char = p.Character
			local hl = char:FindFirstChild("PRDG_Highlight")
			local bb = char:FindFirstChild("PRDG_Billboard")
			if hl then hl.Enabled = false end
			if bb then bb.Enabled = false end
		end
	end

	if ESP.Enabled and #sortedPlayers > 0 then
		local limit = math.min(ESP.MaxPlayers, #sortedPlayers)
		for i = 1, limit do
			local entry = sortedPlayers[i]
			local p = entry.player
			if p and p.Character then
				local char = p.Character
				local hl = char:FindFirstChild("PRDG_Highlight")
				local bb = char:FindFirstChild("PRDG_Billboard")
				if hl then hl.Enabled = ESP.Boxes end
				if bb then bb.Enabled = (ESP.Names or ESP.Distance or ESP.Ranks) end
				if ESP.Lines then
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						local screenPos, onScreen = cam:WorldToViewportPoint(root.Position)
						if onScreen then
							local line = GetOrCreateLine(i)
							line.Visible = true
							line.Color = ESP.Color
							line.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
							line.To = Vector2.new(screenPos.X, screenPos.Y)
						end
					end
				end
				if myRoot then
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						local dist = entry.Distance
						local txt = bb and bb:FindFirstChild("InfoText")
						if txt then
							local str = ""
							if ESP.Names then str = str .. p.Name end
							if ESP.Ranks then
								local leaderstats = p:FindFirstChild("leaderstats")
								local rankVal = leaderstats and (leaderstats:FindFirstChild("Patente") or leaderstats:FindFirstChild("Rank") or leaderstats:FindFirstChild("Level"))
								local rankText = rankVal and tostring(rankVal.Value) or "Sem Patente"
								str = str .. " [" .. rankText .. "]"
							end
							if ESP.Distance then str = str .. " (" .. math.floor(dist) .. "m)" end
							txt.Text = str
						end
					end
				end
			end
		end
	end
end)

EspTab:CreateInput({
	Name = "Qtd de Jogadores no ESP",
	PlaceholderText = "Ex: 10",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text)
		ESP.MaxPlayers = tonumber(Text) or 10
	end
})

EspTab:CreateToggle({
	Name = "Ativar ESP Geral",
	CurrentValue = false,
	Flag = "ESPEnabled",
	Callback = function(Value) ESP.Enabled = Value end
})

EspTab:CreateToggle({
	Name = "Caixas / Highlight",
	CurrentValue = false,
	Flag = "ESPBoxes",
	Callback = function(Value) ESP.Boxes = Value end
})

EspTab:CreateToggle({
	Name = "Linhas (ESP Lines)",
	CurrentValue = false,
	Flag = "ESPLines",
	Callback = function(Value) ESP.Lines = Value end
})

EspTab:CreateToggle({
	Name = "Mostrar Nomes",
	CurrentValue = false,
	Flag = "ESPNames",
	Callback = function(Value) ESP.Names = Value end
})

EspTab:CreateToggle({
	Name = "Mostrar Distância",
	CurrentValue = false,
	Flag = "ESPDistance",
	Callback = function(Value) ESP.Distance = Value end
})

EspTab:CreateToggle({
	Name = "Ver Patentes / Ranks",
	CurrentValue = false,
	Flag = "ESPRanks",
	Callback = function(Value) ESP.Ranks = Value end
})

-- =====================================================
-- ABA 4: RÁDIO
-- =====================================================
local MusicTab = Window:CreateTab("🎵 Rádio", nil)
local MusicSection = MusicTab:CreateSection("Tocador de Música")

local Music_System = { SoundId = "9043887091", Volume = 1, Instance = nil }

MusicTab:CreateInput({
	Name = "ID do Áudio",
	PlaceholderText = "Cole o ID aqui",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text)
		if Text ~= "" then Music_System.SoundId = Text end
	end
})

MusicTab:CreateButton({
	Name = "▶ Tocar Música",
	Callback = function()
		if Music_System.Instance then Music_System.Instance:Destroy() end
		local cleanID = string.match(tostring(Music_System.SoundId), "%d+")
		if cleanID then
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. cleanID
			sound.Volume = Music_System.Volume
			sound.Looped = true
			sound.Parent = SoundService
			sound:Play()
			Music_System.Instance = sound
			Rayfield:Notify({Title = "Rádio", Content = "Tocando!", Duration = 2})
		end
	end
})

MusicTab:CreateButton({
	Name = "⏹ Parar Música",
	Callback = function()
		if Music_System.Instance then
			Music_System.Instance:Destroy()
			Music_System.Instance = nil
			Rayfield:Notify({Title = "Rádio", Content = "Parado", Duration = 2})
		end
	end
})

-- =====================================================
-- ABA 5: AUTO JJS
-- =====================================================
local AutoJJSTab = Window:CreateTab("⚙️ Auto JJS", nil)
local AutoJJSSection = AutoJJSTab:CreateSection("Função Automática")

AutoJJSTab:CreateButton({
	Name = "Executar Auto JJS",
	Callback = function()
		loadstring(game:HttpGet("https://rawscripts.net/raw/Brazilian-Army-Auto-JJs-EB-do-Delta-sem-key-224236"))()
		Rayfield:Notify({Title = "Auto JJS", Content = "Script executado!", Duration = 3})
	end
})

-- =====================================================
-- ABA 6: PARKOUR
-- =====================================================
local ParkourTab = Window:CreateTab("Parkour", nil)
local ParkourSection = ParkourTab:CreateSection("PRODIGIZX MINI HUB 🥷")

local ParkourEnabled = false
local Hitboxes = {}

local data = {
	{pos = Vector3.new(185.03, 5.04, -661.62), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.39, 13.26, -661.39), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.11, 21.28, -661.68), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.30, 29.29, -661.72), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(186.08, 37.36, -661.76), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(186.08, 45.36, -661.76), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(186.25, 53.36, -661.86), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.82, 61.36, -662.00), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.60, 69.40, -661.98), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.71, 77.42, -661.90), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(185.28, 85.44, -662.14), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.42, 93.48, -662.05), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.08, 5.26, -618.66), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.36, 13.28, -618.65), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(185.32, 21.29, -618.70), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.65, 29.34, -618.67), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(186.12, 37.36, -618.43), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(186.30, 45.34, -617.87), size = Vector3.new(5.00, 0.50, 16.00)},
	{pos = Vector3.new(185.41, 53.36, -618.05), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(185.62, 61.40, -617.79), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.58, 69.40, -617.79), size = Vector3.new(4.00, 0.50, 17.00)},
	{pos = Vector3.new(185.87, 77.42, -618.33), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(185.73, 85.44, -618.62), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(185.68, 93.48, -618.49), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(270.22, 4.24, -661.72), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(277.86, 4.24, -655.56), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(269.80, 4.24, -649.96), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(284.45, 4.24, -660.72), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(284.59, 4.24, -650.23), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(267.14, 5.04, -627.94), size = Vector3.new(4.00, 0.50, 32.00)},
	{pos = Vector3.new(288.33, 5.04, -627.86), size = Vector3.new(4.00, 0.50, 31.00)},
	{pos = Vector3.new(277.48, 7.63, -591.97), size = Vector3.new(4.00, 0.50, 27.00)},
	{pos = Vector3.new(271.76, 7.64, -569.98), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(279.08, 7.64, -567.95), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(265.48, 7.64, -564.93), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(271.34, 7.64, -559.70), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(259.46, 7.64, -561.92), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(260.50, 7.64, -554.72), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(250.93, 7.64, -561.91), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(248.66, 7.64, -554.60), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(243.06, 7.64, -565.74), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(235.96, 7.64, -560.93), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(240.08, 7.64, -592.47), size = Vector3.new(4.00, 0.50, 27.00)},
	{pos = Vector3.new(394.19, 5.06, -850.78), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(389.19, 7.45, -855.82), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(392.91, 5.06, -861.09), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(384.07, 10.15, -855.95), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(377.51, 12.94, -855.73), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(370.87, 14.68, -855.83), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(365.12, 16.20, -856.03), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(358.50, 17.61, -855.96), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(351.76, 19.27, -856.05), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(345.37, 20.53, -855.83), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(339.00, 21.54, -855.95), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(334.51, 21.54, -850.11), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(328.83, 21.54, -855.97), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(335.00, 21.54, -861.70), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(324.43, 21.54, -861.35), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(324.69, 21.54, -850.36), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(318.73, 21.54, -855.70), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(313.47, 21.54, -861.90), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(308.27, 21.54, -855.88), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(314.49, 21.54, -850.04), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(303.58, 21.54, -861.59), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(303.61, 21.54, -850.61), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(298.50, 21.54, -856.16), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(393.87, 2.87, -892.93), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(394.65, 2.87, -902.16), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(389.37, 5.04, -892.40), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(389.57, 5.04, -903.24), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(383.37, 7.79, -892.63), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(383.64, 7.79, -903.27), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(378.64, 9.35, -892.48), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(378.64, 9.35, -903.24), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(373.27, 11.53, -892.90), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(372.82, 11.53, -903.33), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(368.47, 11.53, -892.69), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(367.91, 11.53, -903.02), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(362.88, 11.53, -894.04), size = Vector3.new(4.00, 0.50, 7.00)},
	{pos = Vector3.new(358.03, 11.53, -901.74), size = Vector3.new(4.00, 0.50, 6.00)},
	{pos = Vector3.new(352.36, 11.53, -894.75), size = Vector3.new(4.00, 0.50, 6.00)},
	{pos = Vector3.new(347.47, 11.53, -899.21), size = Vector3.new(4.00, 0.50, 6.00)},
	{pos = Vector3.new(333.21, 11.53, -897.81), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(325.73, 11.53, -898.53), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(318.25, 11.53, -897.79), size = Vector3.new(5.00, 0.50, 11.00)},
	{pos = Vector3.new(310.71, 11.53, -898.95), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(303.10, 11.53, -898.29), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(295.54, 11.53, -898.01), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(288.21, 11.53, -898.79), size = Vector3.new(5.00, 0.50, 12.00)},
	{pos = Vector3.new(149.54, 1.04, -856.00), size = Vector3.new(3.00, 0.50, 13.00)},
	{pos = Vector3.new(148.21, 7.50, -855.93), size = Vector3.new(4.00, 0.50, 13.00)},
	{pos = Vector3.new(148.27, 13.38, -856.27), size = Vector3.new(4.00, 0.50, 13.00)},
	{pos = Vector3.new(162.71, 13.70, -859.82), size = Vector3.new(8.00, 0.50, 5.00)},
	{pos = Vector3.new(170.73, 13.70, -852.89), size = Vector3.new(8.00, 0.50, 5.00)},
	{pos = Vector3.new(181.41, 13.70, -859.17), size = Vector3.new(8.00, 0.50, 5.00)},
	{pos = Vector3.new(190.97, 13.70, -853.25), size = Vector3.new(8.00, 0.50, 5.00)},
	{pos = Vector3.new(217.92, 12.53, -848.28), size = Vector3.new(32.00, 0.50, 4.00)},
	{pos = Vector3.new(217.99, 13.04, -863.62), size = Vector3.new(29.00, 0.50, 4.00)},
	{pos = Vector3.new(243.52, 12.04, -855.57), size = Vector3.new(14.00, 0.50, 3.00)},
	{pos = Vector3.new(150.43, 5.27, -897.87), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(150.71, 13.28, -898.27), size = Vector3.new(4.00, 0.50, 17.00)},
	{pos = Vector3.new(150.28, 21.29, -898.42), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(150.45, 29.30, -898.11), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(150.52, 37.31, -898.44), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(150.56, 45.32, -897.73), size = Vector3.new(4.00, 0.50, 15.00)},
	{pos = Vector3.new(150.95, 53.33, -898.02), size = Vector3.new(4.00, 0.50, 16.00)},
	{pos = Vector3.new(167.23, 53.26, -903.84), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(172.90, 53.26, -900.06), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(167.09, 53.26, -890.73), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(181.65, 53.26, -902.00), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(180.48, 53.26, -893.06), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(201.10, 53.33, -897.28), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(212.50, 53.33, -897.85), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(225.52, 53.33, -898.25), size = Vector3.new(5.00, 0.50, 5.00)},
	{pos = Vector3.new(237.61, 53.33, -897.82), size = Vector3.new(5.00, 0.50, 5.00)},
}

local function CreateHitboxes()
	for _, v in ipairs(data) do
		local p = Instance.new("Part", workspace)
		p.Name = "VAKHA_Hitbox"
		p.Size = v.size
		p.Position = v.pos
		p.Anchored = true
		p.Transparency = 1

		local Box = Instance.new("SelectionBox", p)
		Box.Adornee = p
		Box.Color3 = Color3.fromRGB(150, 60, 0)
		Box.SurfaceColor3 = Color3.fromRGB(255, 140, 0)
		Box.SurfaceTransparency = 0.5
		Box.LineThickness = 0.08

		table.insert(Hitboxes, p)
	end
end

ParkourTab:CreateToggle({
	Name = "PRODIGIZX MINI HUB 🥷 (Parkours)",
	CurrentValue = false,
	Flag = "ParkourToggle",
	Callback = function(Value)
		ParkourEnabled = Value
		if ParkourEnabled then
			CreateHitboxes()
			Rayfield:Notify({Title = "Parkour", Content = "Hitboxes ativados!", Duration = 2})
		else
			for _, v in ipairs(Hitboxes) do
				if v and v.Parent then v:Destroy() end
			end
			Hitboxes = {}
			Rayfield:Notify({Title = "Parkour", Content = "Hitboxes removidos!", Duration = 2})
		end
	end
})

RunService.Heartbeat:Connect(function()
	if not ParkourEnabled then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local velY = hrp.AssemblyLinearVelocity.Y
	for _, part in ipairs(Hitboxes) do
		if part and part.Parent then
			part.CanCollide = (velY <= 0.5 and hrp.Position.Y > (part.Position.Y + part.Size.Y / 2 - 1))
		end
	end
end)

-- =====================================================
-- ABA 7: CRÉDITOS
-- =====================================================
local CreditTab = Window:CreateTab("ℹ️ Créditos", nil)
local CreditSection = CreditTab:CreateSection("Desenvolvedor")

CreditTab:CreateButton({
	Name = "TikTok: @prdgzx071",
	Callback = function()
		Rayfield:Notify({Title = "Créditos", Content = "TikTok: @prdgzx071", Duration = 3})
	end
})

CreditTab:CreateButton({
	Name = "Dev: prodigiozx",
	Callback = function()
		Rayfield:Notify({Title = "Créditos", Content = "Desenvolvido por prodigiozx", Duration = 3})
	end
})

Rayfield:Notify({
	Title = "PRODIGIOZX",
	Content = "Script carregado com sucesso!",
	Duration = 5
})
