local ReplicatedStorage = game:GetService(`ReplicatedStorage`);
local Players = game:GetService(`Players`); -- players service
local UserInputService = game:GetService(`UserInputService`);
local StarterGui = game:GetService(`StarterGui`); -- starter player gui service
local TweenService = game:GetService(`TweenService`);
local Library = require(ReplicatedStorage.Library); -- connect my library
local GUI = Players.LocalPlayer.PlayerGui.Chat;
local switch, case, default = unpack(require(ReplicatedStorage.Switch)); -- case statements

local visible = false;
local tab = Players.LocalPlayer.PlayerGui.Tab.background; -- tab gui
local refPosition : UDim2 = tab.Position; -- get current pos in var
local hiddenPos = UDim2.fromScale(1 + tab.Size.X.Scale, refPosition.Y.Scale); -- position to close
tab.Position = hiddenPos; -- hide gui
tab.Parent.Enabled = true; -- enable gui

UserInputService.InputBegan:Connect(function(input) -- open / close tab gui
	if (input.KeyCode ~= Enum.KeyCode.Tab) then -- check tab button
		return;
	end
	visible = not visible;
	game:GetService(`TweenService`):Create(tab, TweenInfo.new(.2),
	{Position = if (visible) then refPosition else hiddenPos}):Play(); -- enable tab
end);

tab:GetPropertyChangedSignal(`Position`):Connect(function() -- visible changer
	tab.Visible = tab.Position ~= hiddenPos;
end);

ReplicatedStorage.events.chat.OnClientEvent:Connect(function(plr : Player, text : string) -- create message gui
	local frame = ReplicatedStorage.chatPlayer:Clone(); -- clone gui
	frame.Parent = GUI.window.messages.scroll;
	frame.avatar.Image = Players:GetUserThumbnailAsync(plr.UserId,
		Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420); -- set player image
	frame.message.Text = `{plr.Name}: {text}`;
end);

UserInputService.InputBegan:Connect(function(input) -- focus if pressed /
	if (input.KeyCode ~= Enum.KeyCode.Slash) then -- slash check
		return;
	end
	GUI.window.chat:CaptureFocus(); -- start typing
end);

GUI.window.chat.FocusLost:Connect(function(enterPressed) -- send by enter
	if (not enterPressed) then -- enter check
		return;
	end
	ReplicatedStorage.events.chat:FireServer(GUI.window.chat.Text); -- message send
	GUI.window.chat.Text = ``;
end);

GUI.window.chat:GetPropertyChangedSignal(`Text`):Connect(function() -- message limit 30
	if (#GUI.window.chat.Text < 30) then -- check symbol index > 30
		return;
	end
	GUI.window.chat.Text = string.sub(GUI.window.chat.Text, 1, 30); -- cut text
end);

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false); -- disable core roblox gui elements
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false);

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait(); 
local humanoid = character:WaitForChild(`Humanoid`);
local speed : number;
local maxSpeed : number;
local cameraConnector;
local inputBeganConnector;
local handBrakeConnectorEnd;

humanoid.CameraOffset = Vector3.new(0, 0, 0);
Players.LocalPlayer.CameraMaxZoomDistance = 128;
Players.LocalPlayer.CameraMinZoomDistance = .5; -- standart camera

ReplicatedStorage.events.shakeCamera.OnClientEvent:Connect(function(_speed, _maxSpeed) -- update speed & max speed
	speed = _speed;
	maxSpeed = _maxSpeed;
end);

ReplicatedStorage.events.newOccupant.OnClientEvent:Connect(function(seat, exitKey) -- new occupant event
	workspace.CurrentCamera.CameraSubject = humanoid;

	coroutine.wrap(function()
		while (task.wait(.1)) do
			seat.Parent.sounds[`idle`].PlaybackSpeed = 1 + speed / 100; -- update speed sound by car speed
		end
	end) ();

	local exitConnector;
	exitConnector = UserInputService.InputBegan:Connect(function(input, chatting) -- exit from car
		if (input.KeyCode ~= exitKey or chatting) then -- check f in chat
			return;
		end
		ReplicatedStorage.events.leaveOccupant:FireServer(); -- leave from car
		exitConnector:Disconnect();
	end);

	inputBeganConnector = UserInputService.InputBegan:Connect(function(input, chatting)
		if (chatting) then -- check in chat
			return;
		end
		switch (input.KeyCode)
		{
			case (Enum.KeyCode.H) (function() -- coup car button
				ReplicatedStorage.events.coupCar:FireServer();
			end),

			case (Enum.KeyCode.G) (function() -- engine on/off button
				ReplicatedStorage.events.engine:FireServer();
			end),

			case (Enum.KeyCode.Space) (function() -- handbrake button
				ReplicatedStorage.events.handbrakeStart:FireServer();
			end),

			case (Enum.KeyCode.E) (function() -- transmission--
				ReplicatedStorage.events.transmissionChanged:FireServer(true);
			end),

			case (Enum.KeyCode.Q) (function() -- transmission++
				ReplicatedStorage.events.transmissionChanged:FireServer(false);
			end)
		}
	end);

	handBrakeConnectorEnd = UserInputService.InputEnded:Connect(function(input) -- handbrake ended
		if (input.KeyCode ~= Enum.KeyCode.Space) then -- check space button
			return;
		end
		ReplicatedStorage.events.handbreakEnd:FireServer(); -- handbrake
	end);

	cameraConnector = game:GetService(`RunService`).Heartbeat:Connect(function() -- update camera position
		if (not speed) then -- check speed not assigment
			return;
		end

		if (speed <= 14 and seat.Throttle > 0) then -- shake by bux
			local CT = tick();
			local x = math.cos(CT * 9) / 100 * maxSpeed * .25;
			local y = math.abs(math.sin(CT * 12) / 100) * maxSpeed * .25;
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(x, y, 0), .25);
		end

		if (speed < maxSpeed - 20) then -- zoom changer
			Players.LocalPlayer.CameraMinZoomDistance = 20;
			Players.LocalPlayer.CameraMaxZoomDistance = Players.LocalPlayer.CameraMinZoomDistance; -- high speed			
		elseif (Players.LocalPlayer.CameraMaxZoomDistance < 20 + (speed - maxSpeed + 20) / 2) then

			Players.LocalPlayer.CameraMaxZoomDistance = 20 + (speed - maxSpeed + 20) / 2;
			Players.LocalPlayer.CameraMinZoomDistance = Players.LocalPlayer.CameraMaxZoomDistance; -- min > max
		else
			Players.LocalPlayer.CameraMinZoomDistance = 20 + (speed - maxSpeed + 20) / 2;
			Players.LocalPlayer.CameraMaxZoomDistance = Players.LocalPlayer.CameraMinZoomDistance; --max < min
		end

		if speed <= maxSpeed - 20 and speed > 14 then -- reset camera pos
			TweenService:Create(humanoid, TweenInfo.new(.1), {CameraOffset = Vector3.new(0, 0, 0)}):Play();
			return;
		end

		local CT = tick();
		local x = math.cos(CT * 9) / 100 * speed * .5;
		local y = math.abs(math.sin(CT * 12) / 100) + math.random(-100, 100) / 20000 * speed * .5;
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(x, y, 0), .25); -- shake by high speed
	end);
end);

ReplicatedStorage.events.leaveOccupant.OnClientEvent:Connect(function() -- leave disconnectors
	inputBeganConnector:Disconnect();
	handBrakeConnectorEnd:Disconnect();
	cameraConnector:Disconnect(); -- disconnect connectors
	humanoid.CameraOffset = Vector3.new(0, 0, 0); -- reset camera
	Players.LocalPlayer.CameraMaxZoomDistance = 128;
	Players.LocalPlayer.CameraMinZoomDistance = .5;
end);

ReplicatedStorage.events.carSoundPlay.OnClientEvent:Connect(function(car, name : string) -- play sounds on client
	coroutine.wrap(function()
		while (speed < 10) do -- wait when speed > 10
			task.wait(.1);
		end
		car.sounds[`idle`]:Resume(); -- play background sound of gas
		while (speed > 10) do -- wait when speed < 10
			task.wait(.1);
		end
		car.sounds[`idle`]:Pause(); -- pause background sound of gas
	end) ();

	local function play() -- play func
		car.sounds[name]:Play();
	end

	switch (name)
	{
		case (`engineOn`) (play), -- engine on sound
		case (`engineOff`) (play),
		case (`default`) (play), -- 2 transmission idle sound
		case (2) (play), -- 2 transmission gas sound
		default () (function()
			local toN = tonumber(name);
			if (not toN) then -- check existence
				return;
			end
			while (speed < 1) do -- wait when speed > 1
				task.wait(.1);
			end
			car.sounds[toN]:Play(); -- play transmission sound
		end)
	}
end);

ReplicatedStorage.events.carSoundStop.OnClientEvent:Connect(function(car) -- stop sounds on client
	local sounds = Library:FindAllInTableBy(car.sounds:GetChildren(), `Playing`, true);
	if (not sounds) then -- check have active sounds
		return;
	end
	for _, sound in sounds do
		sound:Pause(); -- pause all active sounds
	end

	if (not Library:FindInTableBy(sounds, `Name`, `idle`)) then -- check idle gas sound
		return;
	end
	while (speed < .5) do -- wait when speed > 0.5
		task.wait(.1);
	end
	car.sounds[`idle`]:Resume(); -- play
	while (speed > 1) do -- wait when speed < 1
		task.wait(.1);
	end
	car.sounds[`idle`]:Pause(); -- pause
end);
