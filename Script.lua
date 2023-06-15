local ReplicatedStorage = game:GetService(`ReplicatedStorage`);
local Players = game:GetService(`Players`);
local UserInputService = game:GetService(`UserInputService`);
local StarterGui = game:GetService(`StarterGui`);
local TweenService = game:GetService(`TweenService`);
local Library = require(ReplicatedStorage.Library);
local GUI = Players.LocalPlayer.PlayerGui.Chat;
local switch, case, default = unpack(require(ReplicatedStorage.Switch));

local visible = false;
local tab = Players.LocalPlayer.PlayerGui.Tab.background;
local refPosition : UDim2 = tab.Position;
local hiddenPos = UDim2.fromScale(1 + tab.Size.X.Scale, refPosition.Y.Scale);
tab.Position = hiddenPos;
tab.Parent.Enabled = true;

UserInputService.InputBegan:Connect(function(input)
	if (input.KeyCode ~= Enum.KeyCode.Tab) then
		return;
	end
	visible = not visible;
	game:GetService(`TweenService`):Create(tab, TweenInfo.new(.2),
	{Position = if (visible) then refPosition else hiddenPos}):Play();
end);

tab:GetPropertyChangedSignal(`Position`):Connect(function()
	tab.Visible = tab.Position ~= UDim2.fromScale(0, 0);
end);

ReplicatedStorage.events.chat.OnClientEvent:Connect(function(plr : Player, text : string)
	local frame = ReplicatedStorage.chatPlayer:Clone();
	frame.Parent = GUI.window.messages.scroll;
	frame.avatar.Image = Players:GetUserThumbnailAsync(plr.UserId,
		Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420);
	frame.message.Text = `{plr.Name}: {text}`;
end);

UserInputService.InputBegan:Connect(function(input)
	if (input.KeyCode ~= Enum.KeyCode.Slash) then
		return;
	end
	GUI.window.chat:CaptureFocus();
end);

GUI.window.chat.FocusLost:Connect(function(enterPressed)
	if (not enterPressed) then
		return;
	end
	ReplicatedStorage.events.chat:FireServer(GUI.window.chat.Text);
	GUI.window.chat.Text = ``;
end);

GUI.window.chat:GetPropertyChangedSignal(`Text`):Connect(function()
	if (#GUI.window.chat.Text < 30) then
		return;
	end
	GUI.window.chat.Text = string.sub(GUI.window.chat.Text, 1, 30);
end);

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false);
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false);

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait();
local humanoid = character:WaitForChild(`Humanoid`);
local switch, case, default = unpack(require(ReplicatedStorage.Switch));
local speed : number;
local maxSpeed : number;
local cameraConnector;
local inputBeganConnector;
local handBrakeConnectorEnd;

humanoid.CameraOffset = Vector3.new(0, 0, 0);
Players.LocalPlayer.CameraMaxZoomDistance = 128;
Players.LocalPlayer.CameraMinZoomDistance = .5;

ReplicatedStorage.events.shakeCamera.OnClientEvent:Connect(function(_speed, _maxSpeed)
	speed = _speed;
	maxSpeed = _maxSpeed;
end);

ReplicatedStorage.events.newOccupant.OnClientEvent:Connect(function(seat, exitKey)
	workspace.CurrentCamera.CameraSubject = humanoid;

	coroutine.wrap(function()
		while (task.wait(.1)) do
			seat.Parent.sounds[`idle`].PlaybackSpeed = 1 + speed / 100;
		end
	end) ();

	local exitConnector;
	exitConnector = UserInputService.InputBegan:Connect(function(input, chatting)
		if (input.KeyCode ~= exitKey or chatting) then
			return;
		end
		ReplicatedStorage.events.leaveOccupant:FireServer();
		exitConnector:Disconnect();
	end);

	inputBeganConnector = UserInputService.InputBegan:Connect(function(input, chatting)
		if (chatting) then
			return;
		end
		switch (input.KeyCode)
		{
			case (Enum.KeyCode.H) (function()
				ReplicatedStorage.events.coupCar:FireServer();
			end),

			case (Enum.KeyCode.G) (function()
				ReplicatedStorage.events.engine:FireServer();
			end),

			case (Enum.KeyCode.Space) (function()
				ReplicatedStorage.events.handbrakeStart:FireServer();
			end),

			case (Enum.KeyCode.E) (function()
				ReplicatedStorage.events.transmissionChanged:FireServer(true);
			end),

			case (Enum.KeyCode.Q) (function()
				ReplicatedStorage.events.transmissionChanged:FireServer(false);
			end)
		}
	end);

	handBrakeConnectorEnd = UserInputService.InputEnded:Connect(function(input)
		if (input.KeyCode ~= Enum.KeyCode.Space) then
			return;
		end
		ReplicatedStorage.events.handbreakEnd:FireServer();
	end);

	cameraConnector = game:GetService(`RunService`).Heartbeat:Connect(function()
		if (not speed) then
			return;
		end

		if (speed <= 14 and seat.Throttle > 0) then
			local CT = tick();
			local x = math.cos(CT * 9) / 100 * maxSpeed * .25;
			local y = math.abs(math.sin(CT * 12) / 100) * maxSpeed * .25;
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(x, y, 0), .25);
		end

		if (speed < maxSpeed - 20) then
			Players.LocalPlayer.CameraMinZoomDistance = 20;
			Players.LocalPlayer.CameraMaxZoomDistance = Players.LocalPlayer.CameraMinZoomDistance;					
		elseif (Players.LocalPlayer.CameraMaxZoomDistance < 20 + (speed - maxSpeed + 20) / 2) then

			Players.LocalPlayer.CameraMaxZoomDistance = 20 + (speed - maxSpeed + 20) / 2;
			Players.LocalPlayer.CameraMinZoomDistance = Players.LocalPlayer.CameraMaxZoomDistance;
		else
			Players.LocalPlayer.CameraMinZoomDistance = 20 + (speed - maxSpeed + 20) / 2;
			Players.LocalPlayer.CameraMaxZoomDistance = Players.LocalPlayer.CameraMinZoomDistance;
		end

		if speed <= maxSpeed - 20 and speed > 14 then
			TweenService:Create(humanoid, TweenInfo.new(.1), {CameraOffset = Vector3.new(0, 0, 0)}):Play();
			return;
		end

		local CT = tick();
		local x = math.cos(CT * 9) / 100 * speed * .5;
		local y = math.abs(math.sin(CT * 12) / 100) + math.random(-100, 100) / 20000 * speed * .5;
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(x, y, 0), .25);
	end);
end);

ReplicatedStorage.events.leaveOccupant.OnClientEvent:Connect(function()
	inputBeganConnector:Disconnect();
	handBrakeConnectorEnd:Disconnect();
	cameraConnector:Disconnect();
	humanoid.CameraOffset = Vector3.new(0, 0, 0);
	Players.LocalPlayer.CameraMaxZoomDistance = 128;
	Players.LocalPlayer.CameraMinZoomDistance = .5;
end);

ReplicatedStorage.events.carSoundPlay.OnClientEvent:Connect(function(car, name : string)
	coroutine.wrap(function()
		while (speed < 10) do
			task.wait(.1);
		end
		car.sounds[`idle`]:Resume();
		while (speed > 10) do
			task.wait(.1);
		end
		car.sounds[`idle`]:Pause();
	end) ();

	local function play()
		car.sounds[name]:Play();
	end

	switch (name)
	{
		case (`engineOn`) (play),
		case (`engineOff`) (play),
		case (`default`) (play),
		case (2) (play),
		default () (function()
			local toN = tonumber(name);
			if (not toN) then
				return;
			end
			while (speed < 1) do
				task.wait(.1);
			end
			car.sounds[toN]:Play();
		end)
	}
end);

ReplicatedStorage.events.carSoundStop.OnClientEvent:Connect(function(car)
	local sounds = Library:FindAllInTableBy(car.sounds:GetChildren(), `Playing`, true);
	if (not sounds) then
		return;
	end
	for _, sound in sounds do
		sound:Pause();
	end

	if (not Library:FindInTableBy(sounds, `Name`, `idle`)) then
		return;
	end
	while (speed < .5) do
		task.wait(.1);
	end
	car.sounds[`idle`]:Resume();
	while (speed > 1) do
		task.wait(.1);
	end
	car.sounds[`idle`]:Pause();
end);