--[[
	
	
 	##   TEKNIKK LIFTS - POLAR V2 ENGINE   ##
	## CODED BY OVERLOADDETECTED (6623575) ##
	THIS CODE IS LICENSED UNDER THE GNU General Public License v3.0
	https://www.gnu.org/licenses/gpl-3.0.en.html
	
--]]
--script.Parent = nil
--script.Archivable = false
RunService = game:GetService("RunService")
HttpService = game:GetService("HttpService")
TweenService = game:GetService("TweenService")
DataStoreService = game:GetService("DataStoreService")
ASSETID = 558028873
local _M = {}
_M.Script = nil
_M.ElevatorCopy = nil
_M.FloorCopy = nil
_M.LastFloor = 0

-- REPLACEMENT FOR DATA FOLDER

_M.Floor = 0
_M.Direction = 0
_M.Moving = false

-- END --

_M.FireRecall = false
_M.FireRecallProgress = false
_M.FireRecallColor = nil
_M.ForceStop = false

_M.DoorPosition = 0
_M.DoorLength = 0
_M.DoorState = 0
_M.RearDoorPosition = 0
_M.RearDoorLength = 0
_M.RearDoorState = 0
_M.NudgeTimerRun = false
_M.RearNudgeTimerRun = false
_M.NudgeClosing = false
_M.RearNudgeClosing = false
_M.DoorReopen = false
_M.DoorTimerReset = false
_M.RearDoorTimerReset = false

FrontSensorRun = false


_M.LockedFloor = {}


_M.RunInstance = 0

TempDirection = 0

_M.MoveTime = 0
_M.SelfTest = false
_M.ETOPFloor = 0
_M.EBOTTOMFloor  = 9999
_M.ECallQuene = {}
_M.EFloors = {}
_M.EWaiting = false
_M.EAlarm = false
_M.DoorSensorBars = {}
_M.RearDoorSensorBars = {}
_M.DoorSensorNoobs = {}
_M.RearDoorSensorNoobs = {}
_M.SCC = false
_M.EWatchRunning = false


_M.IndependentMode = false
_M.BlacklistedImages = {1244643565}

_M.ElevatorButtons = {
	["CAR"] = {},
	["FLOORS"] = {},
	}

---------------------------------------------------------------
DebugMessage = nil
DebugTimeout = 30
DebugCurrentPos = 0
DebugCleanMessages = {
	"Successfull start with no errors",
	"Sending API call: ELEVATORSTATE",
	"Returning to IDLE",
	"Received API call: REGISTERCALL",
}

function SafeExecute(func,a,b,c,d,e,f,g)
	
	local S,M = pcall(func,a,b,c,d,e,f,g)
	if not S then
		local POSTDATA = {
		["MESSAGE"] = M,
		["MESSAGETYPE"] = "PCALL",
		["PLACEID"] = game.PlaceId		
		}	
	print(M)	
	pcall(function()
	HttpService:GetAsync("https://nte.cloud/PolarAPI/LogErrors/"..HttpService:UrlEncode(HttpService:JSONEncode(POSTDATA)))	
	end)
	end
end



spawn(function()
	local DBM = nil
	local Clear = false
	repeat
		repeat wait(1) until DBM ~= DebugMessage
		DBM = DebugMessage
		
		for _,x in pairs(DebugCleanMessages) do 
			if x == DBM then 
			Clear = true 
			end 
		end
		
		if not Clear then
			
		repeat
			DebugCurrentPos = DebugCurrentPos + 1
				if DBM ~= DebugMessage then
					Clear = true
				end
			wait(1)
			until DebugCurrentPos > DebugTimeout or Clear
		
		end
		DebugCurrentPos = 0	

		if Clear  == false then
		local POSTDATA = {
			["MESSAGE"] = DBM,
			["MESSAGETYPE"] = "TEKBUG",
			["PLACEID"] = game.PlaceId
			
		}		
		HttpService:GetAsync("https://nte.cloud/PolarAPI/LogErrors/"..HttpService:UrlEncode(HttpService:JSONEncode(POSTDATA)))	
		end
		
		
		Clear = false
	until nil
end)




		
---------------------------------------------------------------


function TekBug(d)
	DebugMessage = d
	if _M.Config["DEBUG"] then
		print("TL Polar: ".._M.MData.ElevatorID.Value.." / "..d)
	end
end
function _M.ReceiveAPI(CMD)
	if type(CMD) == "string" then
		TekBug("Received legacy API call: "..CMD)
		if CMD == "REQUESTFLOORUPDATE" then
			_M.SendAPI("EFLR".._M.Floor)
		end
		if CMD == "REQUESTDIRECTIONUPDATE" then
			_M.SendAPI("EDIR".._M.Direction)
		end	
		if CMD:sub(1,9) == "ISSUECALL" then
			local AFloor = tonumber(CMD:sub(10))
			if _M.MFloor:FindFirstChild(AFloor) then
				_M.SendAPI("RESPONSEISSUECALLOK")
				_M.RegisterCall(AFloor,0)
			else
				_M.SendAPI("RESPONSEISSUECALLERROR")
			end
		end
		if CMD == "ISSUEDOOROPEN" then
			_M.DoorOpen()
		end
		if CMD == "ISSUEDOORCLOSE" then
			_M.DoorClose()
		end
		if CMD == "ISSUEALARM" then
			_M.DoAlarm()
		end
	end
	if type(CMD) == "table" and CMD["REQUEST"] then
		TekBug("Received API call: "..CMD["REQUEST"])
		if CMD["REQUEST"] == "ELEVATORSTATE" then
			_M.SendAPI(
				{
					["RESPONSE"] = "ELEVATORSTATE",
					["DATA"] = {
						["FLOOR"] = _M.Floor,
						["DIRECTION"] = _M.Direction,
						["MOTORSTATE"] = _M.Moving,
						["DOORSTATE"] = _M.DoorState,
						["DOORSTATEREAR"] = _M.DoorStateRear,
						["CALLQUEUE"] = _M.ECallQuene,
						["ELEVATORID"] = _M.MData.ElevatorID.Value,
						["FIRERECALL"] = _M.FireRecall,
						["INDEPENDENTMODE"] = _M.IndependentMode,
						["VALID"] = true,
						["TIMESTAMP"] = os.time(),
					} 
				})
		end
		if CMD["REQUEST"] == "REGISTERCALL" then
			if _M.MFloor:FindFirstChild(CMD["DATA"]["FLOOR"]) then
				_M.RegisterCall(CMD["DATA"]["FLOOR"],CMD["DATA"]["TYPE"])
			end		
		end
		if CMD["REQUEST"] == "DOOROPEN" then
			_M.DoorOpen()
		end
		if CMD["REQUEST"] == "DOORCLOSE" then
			_M.DoorClose()
		end
		if CMD["REQUEST"] == "STARTFIRERECALL" then
			_M.StartFireRecall()
		end
		if CMD["REQUEST"] == "STOPFIRERECALL" then
			if _M.FireRecallProgress == false then
				_M.FireRecall = false
			end
		end
		if CMD["REQUEST"] == "ENABLEINDEPENDENTMODE" then
			_M.IndependentMode = true
		end
		if CMD["REQUEST"] == "DISABLEINDEPENDENTMODE" then
			_M.IndependentMode = false
			_M.DoorClose()
		end
		
		if CMD["REQUEST"] == "EMERGENCYSTOP" then	
			_M.StopElevator()
		end

	end
end
function _M.SendAPI(CMD)
	if type(CMD) == "string" then
		TekBug("Sending legacy API call: "..CMD)
	end
	if type(CMD) == "table" then
		TekBug("Sending API call: "..(CMD["RESPONSE"] or CMD["REQUEST"]))
	end
	_M.API:Fire(CMD)
end


function _M.StartFireRecall()
	if _M.FireRecall == false and _M.FireRecallProgress == false then
		_M.FireRecall = true
		_M.FireRecallProgress = true
		for _,CONTROL in pairs(_M.MCar.CONTROL:GetChildren()) do
			if CONTROL.Name == "FSERV" then
				for _,X in pairs(CONTROL:GetChildren()) do
					if X.Name == "LED" then
						_M.FireRecallColor = X.BrickColor
						X.BrickColor = BrickColor.new("Really red")
						X.Material = "Neon"
					end
				end
			end
		end		
		
		
		_M.MPlatform.FireRecall.Looped = true
		_M.MPlatform.FireRecall:Play()
		
		if _M.DoorState ~= 0 or _M.DoorStateRear ~= 0 then
			repeat 
				_M.FrontDoorClose(true)
				wait(1)
			until _M.DoorState == 0
		end
		
		if _M.Moving then
			local TempDir = _M.Direction
			_M.ForceStop = true
			for E,R in pairs(_M.ECallQuene) do
				if R ~= nil then
					local FlrNbr = tostring(R)
					_M.SetButton(tonumber(FlrNbr:sub(2)),4,0)
					_M.SetButton(tonumber(FlrNbr:sub(2)),tostring(FlrNbr:sub(1,1)),0)
					table.remove(_M.ECallQuene,E)
				end
			end
			repeat wait() until _M.ForceStop == false
			if _M.Floor == 1 then _M.Floor = (TempDir == 2 and 0 or 2 ) end
		end
		if _M.Floor ~= 1 then
			table.insert(_M.ECallQuene,"3".._M.Config["ENGINE"]["FIRERECALLFLOOR"])
			SafeExecute(_M.Elevator)
		end

		repeat
			if _M.Floor == 1 and _M.DoorState ~= 1 then
				_M.FrontDoorOpen()
			end
			wait()
		until _M.DoorState == 1
		repeat wait() until _M.Floor == 1 and _M.DoorState == 1
		_M.MPlatform.FireRecall:Stop()
		
		_M.FireRecallProgress = false
	
		repeat wait(1) until _M.FireRecall == false
		
		for _,CONTROL in pairs(_M.MCar.CONTROL:GetChildren()) do
			if CONTROL.Name == "FSERV" then
				for _,X in pairs(CONTROL:GetChildren()) do
					if X.Name == "LED" then
						X.BrickColor = _M.FireRecallColor
						X.Material = "SmoothPlastic"
					end
				end
			end
		end		
				
		_M.FrontDoorClose()
		
	end	
end


local SE = false
function _M.StopElevator(t)
	if not SE and _M.Moving then
		SE = true
		_M.MPlatform.FireRecall.Looped = true
		_M.MPlatform.FireRecall:Play()
		for E,R in pairs(_M.ECallQuene) do
			if R ~= nil then
				local FlrNbr = tostring(R)
				_M.SetButton(tonumber(FlrNbr:sub(2)),4,0)
				_M.SetButton(tonumber(FlrNbr:sub(2)),tostring(FlrNbr:sub(1,1)),0)
				table.remove(_M.ECallQuene,E)
			end
		end
		_M.ForceStop = true
		repeat wait() until not _M.ForceStop
		_M.MPlatform.FireRecall:Stop()
		SE = false
	end
end


WeldedPlayers = {}
function _M.PlayerWeld(T)
	if _M.EnablePlayerWeld == false and T == true then return end
	
	if T == true then
		
		-- PLAYER WELD SYSTEM V2 --

		local S,M = pcall(function()
		local ElevatorCab = Region3.new(
			Vector3.new(
				_M.MPlatform.Position.X - _M.MPlatform.Size.X/2,
				_M.MPlatform.Position.Y - _M.MPlatform.Size.Y/2,
				_M.MPlatform.Position.Z - _M.MPlatform.Size.Z/2		
			),
			Vector3.new(
				_M.MPlatform.Position.X + _M.MPlatform.Size.X/2,
				_M.MPlatform.Position.Y + 8,
				_M.MPlatform.Position.Z + _M.MPlatform.Size.Z/2				
			)
		)

	
			for _,Part in pairs(game.Workspace:FindPartsInRegion3(ElevatorCab,nil,math.huge)) do
			
					if Part ~= nil and Part.ClassName == "Part" and Part.Name == "HumanoidRootPart" then
					
						if Part.Parent:FindFirstChild("Humanoid") then
							local Exists = false
							for _,P in pairs(WeldedPlayers) do
								if P == Part.Parent then
									Exists = true
									break
								end
							end
							if not Exists then
								
								Part.Parent.Humanoid.PlatformStand = true
								local WeldyPendy = _M.DoWeld(_M.MPlatform, Part.Parent.HumanoidRootPart)
								WeldyPendy.Parent = Part.Parent.HumanoidRootPart
								WeldyPendy.Name = "TL_WELD"
								table.insert(WeldedPlayers, Part.Parent)
								local WV = Instance.new("BoolValue")
								WV.Name = "TL_PLAYERWELD"
								WV.Parent = Part.Parent
								TekBug("Player "..Part.Parent.Name.." was found inside elevator, Welded to platform")
							end				
						end
					end			
	
			end
			
			end)
		

	end	
	
	
	
	if T == false then
		if #WeldedPlayers > 0 then
			for _,Player in pairs(WeldedPlayers) do
				
				if Player:FindFirstChild("TL_PLAYERWELD") then
					Player["TL_PLAYERWELD"]:Destroy()
				end	
						
				Player.Humanoid.PlatformStand = false
				if Player.HumanoidRootPart:FindFirstChild("TL_WELD") then
					Player.HumanoidRootPart.TL_WELD:Destroy()
				end

			end
			WeldedPlayers = nil
			WeldedPlayers = {}

			TekBug("Player welds has been removed")
		else
			TekBug("No Players was was welded on this run")		
		end
	end
	
	
end

-- Maybe, but not used "yet" --
function _M.PlaySound(T)
	if T["SoundID"]~= nil and T["Pitch"] ~= nil then
		return spawn(function()
			local Sound = Instance.new("Sound")
			Sound.Parent = _M.MPlatform
			Sound.SoundId = "rbxassetid://"..T["SoundID"]
			Sound.Pitch = T["Pitch"]
			Sound.Looped = false
			Sound.Volume = 0.5
			Sound:Play()
			repeat wait() until Sound.IsPlaying == false
			Sound:Destroy()
		end)
	end
end

-- Voice Module V2 --
function _M.Voice(t)
	if _M.EVoice then
	spawn(function()
		TekBug("Starting Voice Module")
		local Speaker = Instance.new("Sound")
		local Pitch = Instance.new("PitchShiftSoundEffect",Speaker)
		Speaker.MaxDistance = 10
		Speaker.Parent = _M.MPlatform
		Speaker.SoundId = "rbxassetid://".._M.Voices["SOUNDID"]
		Pitch.Octave = _M.Voices["PITCH"] or 1.1
		Speaker.Name = "VoiceAnnouncment"
		if 	_M.Voices[t] then
			if _M.Voices[t]["ID"] ~= nil then
				Speaker.SoundId = "rbxassetid://".._M.Voices[t]["ID"]
				TekBug(Speaker.SoundId)
				Speaker:Play()
				repeat wait(1) until Speaker.IsPaused
				Speaker:Stop()
				Speaker:Destroy()
				return
			end
		end
		if t:sub(1,1) == "F" then
			
			if _M.EFloorVoices[tonumber(t:sub(2))] then
				for _,x in pairs(_M.EFloorVoices[tonumber(t:sub(2))]) do
					if _M.Voices[x] then
						Speaker.TimePosition = _M.Voices[x][1]
						Speaker:Play()
						repeat wait() until Speaker.TimePosition > _M.Voices[x][2]
						Speaker:Stop()			
					end				
				end	
				Speaker:Destroy()	
				return		
			end
			if string.len(t:sub(2)) < 2 then
				Speaker.TimePosition = _M.Voices["Level"][1]
				Speaker:Play()
				repeat wait() until Speaker.TimePosition > _M.Voices["Level"][2]
				Speaker:Stop()
				Speaker.TimePosition = _M.Voices[t:sub(2,2)][1]
				Speaker:Play()
				repeat wait() until Speaker.TimePosition > _M.Voices[t:sub(2,2)][2]
				Speaker:Stop()				
			end	
			Speaker:Destroy()
			return		
		end
		
		if _M.Voices[t] then
			Speaker.TimePosition = _M.Voices[t][1]
			Speaker:Play()
			repeat wait() until Speaker.TimePosition > _M.Voices[t][2]
			Speaker:Stop()			
			Speaker:Destroy()			
			return
		end
	end)
	end
end

-- WELD SYSTEM START --
-- WELD SYSTEM START --
function _M.DoWeld(a, b)
    local w = Instance.new("ManualWeld")
    w.Part0 = a
    w.Part1 = b
    w.C0 = CFrame.new()
    w.C1 = b.CFrame:inverse() * a.CFrame
	b.Anchored = false
    return w;
end
function _M.WeldCar(a)
	if _M.MCar:FindFirstChild("WELDS") == nil then Instance.new("Model",_M.MCar).Name = "WELDS" end
	for _,l in pairs(a) do
		if l:IsA("Part") or l:IsA("WedgePart") or l:IsA("CornerWedgePart") or l:IsA("Seat") or l:IsA("UnionOperation") or l:IsA("MeshPart") then
			local w = _M.DoWeld(_M.MPlatform,l)
			w.Parent = _M.MCar.WELDS
			w.Name = l.Name.."WELD"
			if l:IsA("BasePart") then
			local physicalProp = PhysicalProperties.new(1,0,0.5,0,1)
			l.CustomPhysicalProperties = physicalProp
			end
		end
		if l:IsA("Model") and l.Name ~= "DOORS" and l.Name ~= "DOORWELDS" and l.Name ~= "DOORSREAR" and l.Name ~= "DOORWELDSREAR" and l.Name ~= "WELDS" then
			_M.WeldCar(l:GetChildren())
		end	
	end
end
function _M.WeldDoors()
	if _M.MCar:FindFirstChild("DOORWELDS") == nil then Instance.new("Model",_M.MCar).Name = "DOORWELDS" end
	if _M.MCar:FindFirstChild("DOORWELDSREAR") == nil then Instance.new("Model",_M.MCar).Name = "DOORWELDSREAR" end
	local D = {"DR","DL","DU","DD","RDR","RDL"}
	for _,x in pairs(D) do
		for i=1,_M.DoorAmount do
			local GetDoor = _M.MCar.DOORS:FindFirstChild(x..i)
			if GetDoor then
				Instance.new("Model",_M.MCar.DOORWELDS).Name = GetDoor.Name
				local CarDoor = _M.MCar.DOORWELDS[x..i]
				Instance.new("NumberValue",CarDoor).Name = "Size"
				Instance.new("NumberValue",CarDoor).Name = "Speed"
				CarDoor.Size.Value = (
					GetDoor.Name:sub(1,2) == "DL" and GetDoor.ENGINE.Size.X or 
					GetDoor.Name:sub(1,2) == "DR" and GetDoor.ENGINE.Size.X or 
					GetDoor.Name:sub(1,2) == "DU" and GetDoor.ENGINE.Size.Y or 
					GetDoor.Name:sub(1,2) == "DD" and GetDoor.ENGINE.Size.Y
				)
				CarDoor.Speed.Value = (_M.DoorStandardSpeed*i)
			
				local W = _M.DoWeld(_M.MPlatform,GetDoor.ENGINE)
				W.Parent = CarDoor
				W.Name = "DOORENGINE"
				

				for _,l in pairs(GetDoor:GetDescendants()) do
					if l:IsA("Part") or l:IsA("WedgePart") or l:IsA("CornerWedgePart") or l:IsA("Seat") or l:IsA("UnionOperation") or l:IsA("MeshPart") then
						if l.Name ~= "ENGINE" then
							local W = _M.DoWeld(GetDoor.ENGINE,l)
							W.Parent = CarDoor
							W.Name = l.Name
						end
					end
					--if l:IsA("Model") then
					--	for _,x in pairs(l:GetChildren()) do
					--		_M.DoWeld(GetDoor.ENGINE,x).Parent = CarDoor
					--	end
					--end
				end
			end
		end
	end

	if _M.MCar:FindFirstChild("DOORSREAR") then
		
	for _,x in pairs(D) do
		for i=1,_M.DoorAmount do
			local GetRearDoor = _M.MCar.DOORSREAR:FindFirstChild(x..i)
			if GetRearDoor then
				Instance.new("Model",_M.MCar.DOORWELDSREAR).Name = GetRearDoor.Name
				local CarDoorRear = _M.MCar.DOORWELDSREAR[x..i]
				Instance.new("NumberValue",CarDoorRear).Name = "Size"
				Instance.new("NumberValue",CarDoorRear).Name = "Speed"
				CarDoorRear.Size.Value = (
					GetRearDoor.Name:sub(1,2) == "DL" and GetRearDoor.ENGINE.Size.X or 
					GetRearDoor.Name:sub(1,2) == "DR" and GetRearDoor.ENGINE.Size.X or 
					GetRearDoor.Name:sub(1,2) == "DU" and GetRearDoor.ENGINE.Size.Y or 
					GetRearDoor.Name:sub(1,2) == "DD" and GetRearDoor.ENGINE.Size.Y
				)
				CarDoorRear.Speed.Value = (_M.DoorStandardSpeed*i)
			
				local W = _M.DoWeld(_M.MCar.MISC.LEVEL,GetRearDoor.ENGINE)
				W.Parent = CarDoorRear
				W.Name = "DOORENGINE"
				

				for _,l in pairs(GetRearDoor:GetDescendants()) do
					if l:IsA("Part") or l:IsA("WedgePart") or l:IsA("CornerWedgePart") or l:IsA("Seat") or l:IsA("UnionOperation") or l:IsA("MeshPart") then
						if l.Name ~= "ENGINE" then
							local W = _M.DoWeld(GetRearDoor.ENGINE,l)
							W.Parent = CarDoorRear
							W.Name = l.Name
						end
					end
					--if l:IsA("Model") then
					--	for _,x in pairs(l:GetChildren()) do
					--		_M.DoWeld(GetRearDoor.ENGINE,x).Parent = CarDoorRear
					--	end
					--end
				end
			end
		end
	end

	end

	for _,x in pairs(D) do
		for _,Floorx in pairs(_M.MElevator.FLOORS:GetChildren()) do
			local FloorLevel = Floorx:FindFirstChild("LEVEL") or (Floorx:FindFirstChild("MISC") and Floorx.MISC.LEVEL)
			if Floorx:FindFirstChild("DOORS") then
			if Floorx:FindFirstChild("DOORWELDS") == nil then Instance.new("Model",Floorx).Name = "DOORWELDS" end
			for i=1,_M.DoorAmount do
				local Door = Floorx.DOORS:FindFirstChild(x..i)
				if Door then
					Instance.new("Model",Floorx.DOORWELDS).Name = Door.Name
					Instance.new("NumberValue",Floorx.DOORWELDS[Door.Name]).Name = "Size"
					Instance.new("NumberValue",Floorx.DOORWELDS[Door.Name]).Name = "Speed"
					Floorx.DOORWELDS[Door.Name].Size.Value = (
						Door.Name:sub(1,2) == "DL" and Door.ENGINE.Size.X or
						Door.Name:sub(1,2) == "DR" and Door.ENGINE.Size.X or
						Door.Name:sub(1,2) == "DU" and Door.ENGINE.Size.Y or
						Door.Name:sub(1,2) == "DD" and Door.ENGINE.Size.Y
					)
					Floorx.DOORWELDS[Door.Name].Speed.Value = (_M.DoorStandardSpeed*i)
					local W = _M.DoWeld(FloorLevel,Door.ENGINE)
					W.Parent = Floorx.DOORWELDS[Door.Name]
					W.Name = "DOORENGINE"
					for i,l in pairs(Door:GetDescendants()) do
						if l:IsA("Part") or l:IsA("WedgePart") or l:IsA("CornerWedgePart") or l:IsA("Seat") or l:IsA("UnionOperation") then
							if l.Name ~= "ENGINE" then
								local W = _M.DoWeld(Door.ENGINE,l)
								W.Parent = Floorx.DOORWELDS[Door.Name]
								W.Name = l.Name
							end
						end
						--if l:IsA("Model") then
						--	for _,x in pairs(l:GetChildren()) do
						--		_M.DoWeld(Door.ENGINE,x).Parent = Floorx.DOORWELDS[Door.Name]
						--	end
						--end
					end
				end
			end
			end
		end	
	end
	
	
	for _,x in pairs(D) do
		for _,Floorx in pairs(_M.MElevator.FLOORS:GetChildren()) do
			if Floorx:FindFirstChild("DOORSREAR") then
			local FloorLevel = Floorx:FindFirstChild("LEVEL") or (Floorx:FindFirstChild("MISC") and Floorx.MISC.LEVEL)
			if Floorx:FindFirstChild("DOORWELDSREAR") == nil then Instance.new("Model",Floorx).Name = "DOORWELDSREAR" end
				for i=1,_M.DoorAmount do
					local Door = Floorx.DOORSREAR:FindFirstChild(x..i)
					if Door then
						Instance.new("Model",Floorx.DOORWELDSREAR).Name = Door.Name
						Instance.new("NumberValue",Floorx.DOORWELDSREAR[Door.Name]).Name = "Size"
						Instance.new("NumberValue",Floorx.DOORWELDSREAR[Door.Name]).Name = "Speed"
						Floorx.DOORWELDSREAR[Door.Name].Size.Value = (
							Door.Name:sub(1,2) == "DL" and Door.ENGINE.Size.X or
							Door.Name:sub(1,2) == "DR" and Door.ENGINE.Size.X or
							Door.Name:sub(1,2) == "DU" and Door.ENGINE.Size.Y or
							Door.Name:sub(1,2) == "DD" and Door.ENGINE.Size.Y
						)
						Floorx.DOORWELDSREAR[Door.Name].Speed.Value = (_M.DoorStandardSpeed*i)
						local W = _M.DoWeld(FloorLevel,Door.ENGINE)
						W.Parent = Floorx.DOORWELDSREAR[Door.Name]
						W.Name = "DOORENGINE"
						for i,l in pairs(Door:GetDescendants()) do
							if l:IsA("Part") or l:IsA("WedgePart") or l:IsA("CornerWedgePart") or l:IsA("Seat") or l:IsA("UnionOperation") then
								if l.Name ~= "ENGINE" then
									local W = _M.DoWeld(Door.ENGINE,l)
									W.Parent = Floorx.DOORWELDSREAR[Door.Name]
									W.Name = l.Name
								end
							end
							--if l:IsA("Model") then
							--	for _,x in pairs(l:GetChildren()) do
							--		_M.DoWeld(Door.ENGINE,x).Parent = Floorx.DOORWELDSREAR[Door.Name]
							--	end
							--end
						end
					end
				end
			end
		end	
	end
		
		
end

-- WELD SYSTEM END --

-- DOOR SYSTEM START --
function CheckDoorIfOpened()
	local IsOpen = false
	if _M.DoorState ~= 0 then IsOpen = true end
	if _M.RearDoorState ~= 0 then IsOpen = true end	
	return IsOpen
end
function _M.DoorWatch()
	if not _M.NudgeTimerRun and not _M.IndependentMode then
		spawn(function()
			_M.NudgeTimerRun = true
			local CurTime = 0
			while CurTime < _M.NudgeTimer do
				if #_M.ECallQuene == 0 then CurTime = 0 end
				if not CheckDoorIfOpened() then break end
				CurTime = CurTime + 0.1
				wait(0.1)
			end
			if CheckDoorIfOpened() then		
				for i,x in pairs(_M.DoorSensorNoobs) do
					if x ~= nil then
						table.remove(_M.DoorSensorNoobs,i)
					end
				end				
				for i,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						table.remove(_M.RearDoorSensorNoobs,i)
					end
				end		
				_M.MPlatform.Nudge.Looped = true
				_M.MPlatform.Nudge:Play()
				
				
				while CheckDoorIfOpened() do
					_M.DoorClose(true)
					wait()
				end	
				_M.MPlatform.Nudge.Looped = false
				_M.MPlatform.Nudge:Stop()
			end
			_M.NudgeTimerRun = false			
		end)
	end
end

function _M.DoorOpen(r)
	if _M.FireRecall then TekBug("Fire recall enabled, can not open doors") return end
	SafeExecute(_M.FrontDoorOpen,r)
	SafeExecute(_M.RearDoorOpen,r)
end
function _M.DoorClose(n,u)
	if _M.FireRecall then TekBug("Fire recall enabled, can not open doors") return end
	SafeExecute(_M.FrontDoorClose,n,u)
	SafeExecute(_M.RearDoorClose,n,u)
end


function _M.GenerateCFrameData(CarDoor)
	
	local Val1,Val2,Val3 = 0
	
	Val1 = (CarDoor.Name:sub(2,2) == "R" and (-(CarDoor.Size.Value * tonumber(CarDoor.Name:sub(3))) )or CarDoor.Name:sub(2,2) == "L" and (CarDoor.Size.Value * tonumber(CarDoor.Name:sub(3))) or 0 )
	Val2 = (CarDoor.Name:sub(2,2) == "U" and ((CarDoor.Size.Value * tonumber(CarDoor.Name:sub(3))) )or CarDoor.Name:sub(2,2) == "D" and -(CarDoor.Size.Value * tonumber(CarDoor.Name:sub(3))) or 0 )
	Val3 = 0

	return CFrame.new(Val1,Val2,Val3)
end
function _M.FrontDoorOpen(r)	
	if _M.DoorState ~= 0 and _M.DoorState ~= 2  or _M.SelfTest or _M.NudgeClosing then return end
	local FloorLevel = _M.MFloor[_M.Floor]:FindFirstChild("LEVEL") or (_M.MFloor[_M.Floor]:FindFirstChild("MISC") and _M.MFloor[_M.Floor].MISC.LEVEL)
	if math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) > 2 then return end
	spawn(function()
		local GetFloor = _M.MFloor:FindFirstChild(_M.Floor)
		local HasDoors = false
		for _,x in pairs(GetFloor.DOORWELDS:GetChildren()) do
			if x.Name:sub(1,2) == "DR" or x.Name:sub(1,2) == "DL" or x.Name:sub(1,2) == "DU" or x.Name:sub(1,2) == "DD" then
				HasDoors = true
			end
		end
		if not HasDoors then return end
		if _M.DoorState == 2  then 
			_M.DoorReopen = true 
			_M.DoorState = 4
			wait(0.5)
		else 
			_M.DoorState = 3 
			wait(_M.DoorOpenDelay)
			_M.SetButton(_M.Floor,4,0)
		end
		if _M.DoorReopen == false or _M.Config["SIGNAL"]["SIGNALONREOPEN"] == true then
			if _M.ChimeBeforeDoor then
				_M.DoChime()
			end
			if _M.LanternBeforeDoor then
				_M.SetLantern(_M.Floor,_M.Direction,1)
			end
			_M.Voice("DO")
		end
		
		_M.SendAPI("EDO")
		_M.SendAPI({["RESPONSE"] = "DOOROPEN", ["DATA"] = nil})
		
		-- DOOR SENSOR BAR BLINKER --
		spawn(function()
			while _M.DoorState == 4 or _M.DoorState == 3  do
				for _,x in pairs(_M.DoorSensorBars) do
					x.BrickColor = BrickColor.new("Lime green")
					x.Material = "Neon"
				end
				wait(0.2)
				for _,x in pairs(_M.DoorSensorBars) do
					x.BrickColor = BrickColor.new("Black")
					x.Material = "SmoothPlastic"
				end
				wait(0.2)
			end
			for _,x in pairs(_M.DoorSensorBars) do
				x.BrickColor = BrickColor.new("Lime green")
				x.Material = "Neon"
			end			
		end)
		
		_M.SetDoorButton(1)

		TekBug("Try open the doors")
		
		if _M.DoorSound then
			_M.MPlatform.DoorMotor:Play()
		end
		_M.MPlatform.DoorMotor.Pitch = 0.25

		for i = 0, _M.Config["DOOR"]["LERPLENGTH"] , _M.DoorOpenSpeed do 

			local DSD = (	
				_M.MCar.DOORWELDS:FindFirstChild("DL1") and _M.MCar.DOORWELDS.DL1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DR1") and _M.MCar.DOORWELDS.DR1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DU1") and _M.MCar.DOORWELDS.DU1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DD1") and _M.MCar.DOORWELDS.DD1
			)
			if DSD.DOORENGINE.C0.x < DSD.Size.Value/2 then
				_M.MPlatform.DoorMotor.Pitch = _M.MPlatform.DoorMotor.Pitch+0.0025
			elseif DSD.DOORENGINE.C0.x > DSD.Size.Value/2 then
				_M.MPlatform.DoorMotor.Pitch = _M.MPlatform.DoorMotor.Pitch-0.0025
			end
			for _,CarDoor in pairs(_M.MCar.DOORWELDS:GetChildren()) do	

				CarDoor.DOORENGINE.C0 = CarDoor.DOORENGINE.C0:lerp( _M.GenerateCFrameData(CarDoor), i)

			end
			for _,ShaftDoor in pairs(GetFloor.DOORWELDS:GetChildren()) do
				ShaftDoor.DOORENGINE.C0 = ShaftDoor.DOORENGINE.C0:lerp( _M.GenerateCFrameData(ShaftDoor), i)
			end
			RunService.Heartbeat:wait()
		end
		_M.MPlatform.DoorMotor:Stop()
	

		_M.DoorState = 1
		if _M.DoorReopen == false  or _M.Config["SIGNAL"]["SIGNALONREOPEN"] == true then
		if not _M.ChimeBeforeDoor and not _M.ChimeBeforeDoor then
			_M.DoChime()
		end
		if not _M.LanternBeforeDoor and not _M.LanternBeforeDoor  then
				_M.SetLantern(_M.Floor,_M.Direction,1)
		end

			_M.Voice("D".._M.Direction)

		end
		_M.DoorReopen = false
		_M.SetDoorButton(0)
		_M.DoorWatch()
		
		-- START MONITORING THE DOOR SENSOR FIELD --
	local DoorSensorPart = (_M.MCar:FindFirstChild("MISC") and _M.MCar.MISC:FindFirstChild("DOORSENSOR")) or _M.MCar:FindFirstChild("DOORSENSOR") 
		spawn(function() 
			if _M.FireRecall then TekBug("Fire Recall enabled, Do not close doors") return end
			if _M.IndependentMode then TekBug("Independent Mode enabled, do not run doortimer") return end
			local CTime = 0
			local Blocked = false
			local DS
			
			if _M.Config["DOOR"]["SENSORHOLD"] then
			coroutine.wrap(function()
				if FrontSensorRun  then return end
				FrontSensorRun = true
				repeat
				if _M.MCar.MISC:FindFirstChild("DOORSENSOR") then
				
					Blocked = false
					
					
				local DoorSensor = Region3.new(
					Vector3.new(
						_M.MCar.MISC.DOORSENSOR.Position.X - _M.MCar.MISC.DOORSENSOR.Size.X/2,
						_M.MCar.MISC.DOORSENSOR.Position.Y - _M.MCar.MISC.DOORSENSOR.Size.Y/2,
						_M.MCar.MISC.DOORSENSOR.Position.Z - _M.MCar.MISC.DOORSENSOR.Size.Z/2		
					),
					Vector3.new(
						_M.MCar.MISC.DOORSENSOR.Position.X + _M.MCar.MISC.DOORSENSOR.Size.X/2,
						_M.MCar.MISC.DOORSENSOR.Position.Y + _M.MCar.MISC.DOORSENSOR.Size.Y/2,
						_M.MCar.MISC.DOORSENSOR.Position.Z + _M.MCar.MISC.DOORSENSOR.Size.Z/2			
					)
				)
		
		
				for _,Part in pairs(game.Workspace:FindPartsInRegion3(DoorSensor,nil,math.huge)) do
					
						if Part then
						
							if Part.Parent:FindFirstChild("Humanoid") then
								Blocked = true
								if _M.DoorState == 1 then
									for _,x in pairs(_M.DoorSensorBars) do
										x.BrickColor = BrickColor.new("New Yeller")
										x.Material = "Neon"
									end
								end
							end
						end			
		
				end					
					
					
					
					
					
	
					if not Blocked and _M.DoorState ==  1 then
						for _,x in pairs(_M.DoorSensorBars) do
							x.BrickColor = BrickColor.new("Lime green")
							x.Material = "Neon"
						end	
					elseif Blocked and _M.DoorState == 2 then
						_M.DoorOpen()
						break
					else
						
						CTime = 0			
					end
				
				end	
				wait()
				until _M.DoorState == 0 or _M.NudgeClosing
				FrontSensorRun = false
			end)()
			
				
			end
			
			
			
			
			
			repeat
								

				wait(0.1)
				CTime = CTime + 0.1
				if _M.DoorTimerReset == true then
					CTime = 0
					_M.DoorTimerReset = false
				end
				
			until CTime > _M.DoorTimer or _M.DoorState ~= 1
			if CTime > _M.DoorTimer then
				_M.DoorClose()
			end
		end)

		
	end)
end
function _M.FrontDoorClose(Nudge,UserIsset)
	if _M.DoorState ~= 1 or _M.DoorReopen or _M.SelfTest or _M.NudgeClosing then return end
	spawn(function()
		local GetFloor = _M.MFloor:FindFirstChild(_M.Floor)
		local HasDoors = false
		for _,x in pairs(GetFloor.DOORWELDS:GetChildren()) do
			if x.Name:sub(1,2) == "DR" or x.Name:sub(1,2) == "DL" or x.Name:sub(1,2) == "DU" or x.Name:sub(1,2) == "DD" then
				HasDoors = true
			end
		end
		if not HasDoors then return end
		if Nudge then _M.NudgeClosing = true end
		_M.DoorState = 2
		_M.SetLantern(_M.Floor,0,0)
		_M.SendAPI("EDC")
		_M.SendAPI({["RESPONSE"] = "DOORCLOSE", ["DATA"] = nil})

		spawn(function()
			while _M.DoorState == 2 do
				for _,x in pairs(_M.DoorSensorBars) do
					x.BrickColor = BrickColor.new("Really red")
					x.Material = "Neon"
				end
				wait(0.2)
				for _,x in pairs(_M.DoorSensorBars) do
					x.BrickColor = BrickColor.new("Black")
					x.Material = "SmoothPlastic"
				end
				wait(0.2)
			end
			for _,x in pairs(_M.DoorSensorBars) do
				x.BrickColor = BrickColor.new("Black")
				x.Material = "SmoothPlastic"
			end			
		end)

		if not UserIsset then
			_M.Voice("DC")
			wait(2)
			if _M.DoorReopen or _M.DoorState ~= 2 then return end
		end
		_M.SetDoorButton(2)
		if Nudge then wait(3) end
	
		if _M.DoorSound then
			_M.MPlatform.DoorMotor:Play()
		end
		_M.MPlatform.DoorMotor.Pitch = .25

		for i = 0, (_M.NudgeClosing and 0.05 or _M.Config["DOOR"]["LERPLENGTH"]), (_M.NudgeClosing and .0002 or _M.DoorCloseSpeed) do 
			local DSD = (	
				_M.MCar.DOORWELDS:FindFirstChild("DL1") and _M.MCar.DOORWELDS.DL1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DR1") and _M.MCar.DOORWELDS.DR1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DU1") and _M.MCar.DOORWELDS.DU1 or 
				_M.MCar.DOORWELDS:FindFirstChild("DD1") and _M.MCar.DOORWELDS.DD1
			)
			for _,CarDoor in pairs(_M.MCar.DOORWELDS:GetChildren()) do	

				CarDoor.DOORENGINE.C0 = CarDoor.DOORENGINE.C0:lerp( (CFrame.new(0,0,0)), i)

			end
			for _,ShaftDoor in pairs(GetFloor.DOORWELDS:GetChildren()) do
				ShaftDoor.DOORENGINE.C0 = ShaftDoor.DOORENGINE.C0:lerp( (CFrame.new(0,0,0)), i)
			end
			RunService.Heartbeat:wait()
			if _M.DoorReopen or _M.DoorState ~= 2 then break end
		end
		_M.MPlatform.DoorMotor:Stop()		
		_M.SetDoorButton(0)
		if _M.DoorState == 2 or _M.DoorState == 5 then
			_M.DoorState =  0
			 if Nudge then spawn(function() wait(1) _M.NudgeClosing = false end) end
			SafeExecute(_M.Elevator)
		end
	end)
end
function _M.RearDoorOpen(r)	

	if _M.RearDoorState ~= 0 and _M.RearDoorState ~= 2  or _M.SelfTest or _M.RearNudgeClosing then return end
	local FloorLevel = _M.MFloor[_M.Floor]:FindFirstChild("LEVEL") or (_M.MFloor[_M.Floor]:FindFirstChild("MISC") and _M.MFloor[_M.Floor].MISC.LEVEL)
	if math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) > 2 then return end
	spawn(function()
		local GetFloor = _M.MFloor:FindFirstChild(_M.Floor)
		local HasDoors = false
		if GetFloor:FindFirstChild("DOORWELDSREAR") == nil then return end
		for _,x in pairs(GetFloor.DOORWELDSREAR:GetChildren()) do
			if x.Name:sub(1,2) == "DR" or x.Name:sub(1,2) == "DL" or x.Name:sub(1,2) == "DU" or x.Name:sub(1,2) == "DD" then
				HasDoors = true
			end
		end
		if not HasDoors then return end
		if _M.RearDoorState == 2 then 
			_M.RearDoorReopen = true 
			_M.RearDoorState = 4
			wait(0.5)
		else 
			_M.RearDoorState = 3 
			wait(_M.DoorOpenDelay)
			_M.SetButton(_M.Floor,4,0)
			if _M.ChimeBeforeDoor then
				_M.DoChime()
			end
			if _M.LanternBeforeDoor and _M.Direction ~= 0 then
				_M.SetLantern(_M.Floor,_M.Direction,1,1)
			end
			_M.Voice("DO")
		end

		_M.SendAPI("ERDO")
		_M.SendAPI({["RESPONSE"] = "REARDOOROPEN", ["DATA"] = nil})
		
		-- DOOR SENSOR BAR BLINKER --
		spawn(function()
			while _M.RearDoorState == 4 or _M.RearDoorState == 3  do
				for _,x in pairs(_M.RearDoorSensorBars) do
					x.BrickColor = BrickColor.new("Lime green")
					x.Material = "Neon"
				end
				wait(0.2)
				for _,x in pairs(_M.RearDoorSensorBars) do
					x.BrickColor = BrickColor.new("Black")
					x.Material = "SmoothPlastic"
				end
				wait(0.2)
			end
			for _,x in pairs(_M.RearDoorSensorBars) do
				x.BrickColor = BrickColor.new("Lime green")
				x.Material = "Neon"
			end			
		end)
		
		_M.SetDoorButton(1,1)

		TekBug("Try open the doors")
		
		if _M.DoorSound then
			_M.MPlatform.DoorMotor:Play()
		end
		_M.MPlatform.DoorMotor.Pitch = 0.25
		for i = 0, _M.Config["DOOR"]["LERPLENGTH"], _M.DoorOpenSpeed do 
			local DSD = (	
				_M.MCar.DOORWELDSREAR:FindFirstChild("DL1") and _M.MCar.DOORWELDSREAR.DL1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DR1") and _M.MCar.DOORWELDSREAR.DR1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DU1") and _M.MCar.DOORWELDSREAR.DU1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DD1") and _M.MCar.DOORWELDSREAR.DD1
			)
			if DSD.DOORENGINE.C0.x < DSD.Size.Value/2 then
				_M.MPlatform.DoorMotor.Pitch = _M.MPlatform.DoorMotor.Pitch+0.0025
			elseif DSD.DOORENGINE.C0.x > DSD.Size.Value/2 then
				_M.MPlatform.DoorMotor.Pitch = _M.MPlatform.DoorMotor.Pitch-0.0025
			end
			for _,CarDoor in pairs(_M.MCar.DOORWELDSREAR:GetChildren()) do	
				CarDoor.DOORENGINE.C0 = CarDoor.DOORENGINE.C0:lerp( _M.GenerateCFrameData(CarDoor), i)
			end
			for _,ShaftDoor in pairs(GetFloor.DOORWELDSREAR:GetChildren()) do
				ShaftDoor.DOORENGINE.C0 = ShaftDoor.DOORENGINE.C0:lerp( _M.GenerateCFrameData(ShaftDoor), i)
			end
			RunService.Heartbeat:wait()
		end

		_M.MPlatform.DoorMotor:Stop()
	

		_M.RearDoorState = 1
		if not _M.ChimeBeforeDoor and not r and not _M.ChimeBeforeDoor and not _M.DoorReopen then
			_M.DoChime()
		end
		if not _M.LanternBeforeDoor and not r and not _M.LanternBeforeDoor and not _M.DoorReopen then
				_M.SetLantern(_M.Floor,_M.Direction,1,1)
		end
		if not _M.DoorReopen then
			_M.Voice("D".._M.Direction)
		end
		_M.RearDoorReopen = false
		_M.SetDoorButton(0,1)
		_M.DoorWatch()
		
		-- START MONITORING THE DOOR SENSOR FIELD --
		spawn(function() 
			if _M.FireRecall then TekBug("Fire Recall enabled, Do not close doors") return end
			if _M.IndependentMode then TekBug("Independent Mode enabled, do not run doortimer") return end
			local CTime = 0
			repeat
				local Obstacle = false
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						for _,x in pairs(_M.RearDoorSensorBars) do
							x.BrickColor = BrickColor.new("New Yeller")
							x.Material = "Neon"
						end
						Obstacle = true
						CTime = 0
					end
				end
				if not Obstacle  then
					for _,x in pairs(_M.RearDoorSensorBars) do
						x.BrickColor = BrickColor.new("Lime green")
						x.Material = "Neon"
					end
				end
				wait(0.1)
				CTime = CTime + 0.1
				if _M.DoorTimerReset == true then
					CTime = 0
					_M.DoorTimerReset = false
				end
			until CTime > _M.DoorTimer or _M.RearDoorState ~= 1
			if CTime > _M.DoorTimer then
				_M.RearDoorClose()
			end
		end)

		
	end)
end
function _M.RearDoorClose(Nudge,UserIsset)
	if _M.RearDoorState ~= 1 or _M.RearDoorReopen or _M.SelfTest or _M.RearNudgeClosing then return end
	spawn(function()
		local GetFloor = _M.MFloor:FindFirstChild(_M.Floor)
		local HasDoors = false
		if GetFloor:FindFirstChild("DOORWELDSREAR") == nil then return end
		for _,x in pairs(GetFloor.DOORWELDSREAR:GetChildren()) do
			if x.Name:sub(1,2) == "DR" or x.Name:sub(1,2) == "DL" or x.Name:sub(1,2) == "DU" or x.Name:sub(1,2) == "DD" then
				HasDoors = true
			end
		end
		if not HasDoors then return end
		if Nudge then _M.RearNudgeClosing = true end
		_M.RearDoorState = 2
		_M.SetLantern(_M.Floor,0,0,1)
		_M.SendAPI("ERDC")
		_M.SendAPI({["RESPONSE"] = "REARDOORCLOSE", ["DATA"] = nil})

		spawn(function()
			while _M.RearDoorState == 2 do
				for _,x in pairs(_M.RearDoorSensorBars) do
					x.BrickColor = BrickColor.new("Really red")
					x.Material = "Neon"
				end
				wait(0.2)
				for _,x in pairs(_M.RearDoorSensorBars) do
					x.BrickColor = BrickColor.new("Black")
					x.Material = "SmoothPlastic"
				end
				wait(0.2)
			end
			for _,x in pairs(_M.RearDoorSensorBars) do
				x.BrickColor = BrickColor.new("Black")
				x.Material = "SmoothPlastic"
			end			
		end)

		if not UserIsset then
			_M.Voice("DC")
			wait(2)
			if _M.RearDoorReopen or _M.RearDoorState ~= 2 then return end
		end
		_M.SetDoorButton(2,1)
		if Nudge then wait(3) end
	
		if _M.DoorSound then
			_M.MPlatform.DoorMotor:Play()
		end
		_M.MPlatform.DoorMotor.Pitch = .25
		for i = 0, (_M.NudgeClosing and 0.05 or _M.Config["DOOR"]["LERPLENGTH"]), (_M.NudgeClosing and .0002 or _M.DoorCloseSpeed) do 
			local DSD = (	
				_M.MCar.DOORWELDSREAR:FindFirstChild("DL1") and _M.MCar.DOORWELDSREAR.DL1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DR1") and _M.MCar.DOORWELDSREAR.DR1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DU1") and _M.MCar.DOORWELDSREAR.DU1 or 
				_M.MCar.DOORWELDSREAR:FindFirstChild("DD1") and _M.MCar.DOORWELDSREAR.DD1
			)
			for _,CarDoor in pairs(_M.MCar.DOORWELDSREAR:GetChildren()) do	
				CarDoor.DOORENGINE.C0 = CarDoor.DOORENGINE.C0:lerp( (CFrame.new(0,0,0)), i)
			end
			for _,ShaftDoor in pairs(GetFloor.DOORWELDSREAR:GetChildren()) do
				ShaftDoor.DOORENGINE.C0 = ShaftDoor.DOORENGINE.C0:lerp( (CFrame.new(0,0,0)), i)
			end
			RunService.Heartbeat:wait()
			if _M.RearDoorReopen or _M.RearDoorState ~= 2 then break end
		end
		_M.MPlatform.DoorMotor:Stop()		
		_M.SetDoorButton(0,1)
		if _M.RearDoorState == 2 or _M.RearDoorState == 5 then
			_M.RearDoorState =  0
			 if Nudge then spawn(function() wait(1) _M.RearNudgeClosing = false end) end
			SafeExecute(_M.Elevator)
		end
	end)
end
function _M.ClassicOpen()
	spawn(function()
	local FloorLevel = _M.MFloor[_M.Floor]:FindFirstChild("LEVEL") or (_M.MFloor[_M.Floor]:FindFirstChild("MISC") and _M.MFloor[_M.Floor].MISC.LEVEL)
	repeat wait() until math.abs(FloorLevel.Position.Y - _M.MPlatform.Position.Y) < _M.ClassicLevel
	SafeExecute(_M.DoorOpen)
	end)
end	
-- DOOR SYSTEM END --

-- ELEVATOR CORE START --
function _M.Elevator()

	TekBug("Start acting like a elevator")
	local RI = math.random(1000,9999)
	if _M.Moving and _M.EWaiting and _M.Moving then TekBug("But I am already running :(") return end
	if _M.RunInstance ~= 0 then TekBug("ALREADY RUNNIN AN INSTANCE!") return end
	if _M.RunInstance == 0 then
		_M.RunInstance = RI
	end
	TekBug("No existing instance was running, we can start one")
	_M.EWaiting = true
	TekBug("Waiting for doors to close")
	repeat wait() until _M.DoorState == 0 and _M.RearDoorState == 0
	TekBug("Doors closed, Finding calls")
	local CallExist = false
	local CallOnDirection = false

	for _,l in pairs(_M.ECallQuene) do
		if tonumber(l:sub(1,1)) == 3 or tonumber(l:sub(1,1)) == _M.Direction then
		local cn = tostring(l)
		local QueuFloor= tonumber(cn:sub(2))
			if (_M.Direction == 1 and QueuFloor> _M.Floor or _M.Direction == 2 and QueuFloor< _M.Floor) then
				CallExist = true
				CallOnDirection = true
				TekBug("On Direction call found / F "..l)
				break -- out of the loop :D
			end
		end
	end	
	
	
	
	if not CallOnDirection then
	for i=1,2 do
	
		-- Call Checker V1 --
		
			for _,l in pairs(_M.ECallQuene) do
				if tonumber(l:sub(1,1)) == 3 then
					local cn = tostring(l)
					local QueuFloor= tonumber(cn:sub(2))
						if 
							_M.Direction == tonumber(l:sub(1,1)) and (_M.Direction == 1 and QueuFloor> _M.Floor or _M.Direction == 2 and QueuFloor< _M.Floor) 
						or 
							(i == 1 and QueuFloor> _M.Floor or i == 2 and QueuFloor< _M.Floor) 
						then
						_M.Direction = i
						CallExist = true
						TekBug("Normal Call found / F "..l)
						break -- out of the loop :D
					end
				end
			end
			
			-- No normal calls? Let's check Up/Down on weird floors --
			if not CallExist then
				for _,l in pairs(_M.ECallQuene) do
					if tonumber(l:sub(1,1)) == 1 or tonumber(l:sub(1,1)) == 2 then
						local cn = tostring(l)
						local QueuFloor= tonumber(cn:sub(2))
						if (i == 1 and QueuFloor< _M.Floor or i == 2 and QueuFloor> _M.Floor) then
							_M.Direction = (i == 1 and 2 or i == 2 and 1)
							CallExist = true
							TekBug("Up/Down Call found / F "..l)
							break -- out of the loop :D
						
						end 
					end
				end			
			end
		end
	end
	

	if not CallExist then 

		
		local StillNothing = true
		TekBug("No calls found, lets double check if there is a call on this floor")
		for i,l in pairs(_M.ECallQuene) do
			if tonumber(l:sub(2)) == _M.Floor then
				local NewDir = tonumber(l:sub(1,1))
				_M.SendAPI("EDIR"..NewDir)
				_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = NewDir})
				_M.Direction = NewDir
				_M.DoorOpen()
				_M.SetButton(_M.Floor,NewDir,0)
				table.remove(_M.ECallQuene,i)
				StillNothing = false
				
			end
		end		
			
		if StillNothing then
			_M.SendAPI("EDIR0")
			_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = 0})
			_M.Direction = 0
			TekBug("No remaining call stuck, resting... :)")
		else
			TekBug("Returning to IDLE") 
			_M.RunInstance = 0
			_M.ForceStop = false
			return 
		end
		
	end
	-- End --

		
	_M.EWaiting = false
	if _M.RunInstance ~= RI then TekBug("Instance was run twice, Terminating extra instance") return end
	if _M.Direction == 0 or _M.ForceStop or _M.Moving then 
		TekBug("Returning to IDLE") 
		_M.RunInstance = 0
		_M.ForceStop = false
		return 
	end

	_M.Moving = true
	_M.SendAPI("EMVT")
	_M.SendAPI({["RESPONSE"] = "MOTORSTATE", ["DATA"] = true})
	_M.SendAPI("EDIR".._M.Direction)
	_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = _M.Direction})
	SafeExecute(_M.PlayerWeld,true)
	local EngineSpeed = 0
	TempDirection = 0
	wait(_M.MotorStartDelay)
	TekBug("Starting the Engine")
	spawn(function()
		TekBug("Engine Started")
		if _M.EngineType == 4 then
			repeat 
				_M.MPlatform.Engine.Position = Vector3.new(
					_M.MPlatform.Position.X,
					_M.MPlatform.Position.Y + EngineSpeed/50,
					_M.MPlatform.Position.Z
					)
				RunService.Heartbeat:wait()
			until _M.Moving == false
		end
		if _M.EngineType == 3 then
			if _M.MotorSound then
				_M.MPlatform.Motor:Play()
				
			end
			_M.MPlatform.Motor.Pitch = 0
			local CWDir = _M.Direction
			local CFrameRUN = game:GetService('RunService').Stepped:Connect(function()
				
																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																			 
				
				_M.MPlatform.Motor.Pitch = math.abs(EngineSpeed)/25+0.25
				_M.MPlatform.CFrame = _M.MPlatform.CFrame * CFrame.new(0, EngineSpeed/65, 0)	
				if _M.CWE then 
					_M.CWE.CFrame = _M.CWE.CFrame * CFrame.new(0, (CWDir == 1 and -math.abs(EngineSpeed)/65 or CWDir == 2 and math.abs(EngineSpeed)/65 ), 0)

				end
			end)
			
			--[[
			repeat
				_M.MPlatform.Motor.Pitch = math.abs(EngineSpeed)/25+0.25
				_M.MPlatform.CFrame = _M.MPlatform.CFrame * CFrame.new(0, EngineSpeed/65, 0)
				if _M.CWE then
					_M.CWE.CFrame = _M.CWE.CFrame * CFrame.new(0, 
						(_M.Direction == 1 and TempDirection ~= 2 and -(math.abs(EngineSpeed/65)) or 
							_M.Direction == 2 and TempDirection ~= 1 and(math.abs(EngineSpeed/65)) or
							_M.Direction == 2 and TempDirection == 1 and -(math.abs(EngineSpeed/65)) or 
							_M.Direction == 1 and TempDirection  == 2 and(math.abs(EngineSpeed/65))
							
							), 0)
				end
				RunService.Heartbeat:wait()
			until _M.Moving == false
			
			--]]
			repeat wait() until _M.Moving == false
			CFrameRUN:Disconnect()
			_M.MPlatform.Motor.Pitch = 0
			_M.MPlatform.Motor:Stop()
		end
		if _M.EngineType == 2 then
			repeat 
				_M.MPlatform.Engine.Velocity = EngineSpeed
				RunService.Heartbeat:wait()
			until _M.Moving == false
		end
		if _M.EngineType == 1 then
			repeat 
				_M.MPlatform.Engine.Velocity = Vector3.new(0,EngineSpeed,0)
				RunService.Heartbeat:wait()
			until _M.Moving == false
		end
	
		TekBug("Engine Stopped")
	end)
	

	local StopFloor = false
	local UpDownCall = nil
	
	spawn(function()
	_M.SendAPI({["RESPONSE"] = "ELEVATORMOVEMENT", ["DATA"] = "STARTING"})
	if _M.EngineType == 1 then
		TekBug("Releasing brakes for VELOCITY mode")
		_M.MLevel.Anchored = false
		_M.MPlatform.BodyPosition.MaxForce =  Vector3.new(1000000, 0, 1000000)
		_M.MPlatform.Engine.MaxForce = Vector3.new(0, 1000000, 0)
	end
	if _M.EngineType == 2 then
		TekBug("Releasing brakes for CONSTRAINT mode")
		_M.MPlatform.Servo.Enabled = false
		_M.MPlatform.Engine.Enabled = true
	end
	if _M.MotorSound then _M.MPlatform.Motor:Play() _M.MPlatform.Motor.Pitch = 0 end
	TekBug("Engine Acceleration")
	TekBug("Going... ".._M.Direction)
	if _M.Direction == 1 or _M.Direction == 2 then
		for i=0, _M.EMotorSpeed, _M.EStartIncrementalValue do
			if StopFloor then break end
			EngineSpeed = (_M.Direction == 1 and i or -i )
			if _M.MotorSound then _M.MPlatform.Motor.Pitch = i/5 end
			RunService.Heartbeat:wait()
		end
	else
		_M.Moving = false
		return
	end
	local sf = false
	TekBug("Engine Run")
	_M.SendAPI({["RESPONSE"] = "ELEVATORMOVEMENT", ["DATA"] = "RUNNING"})
	end)

	repeat
		local LastFloor = _M.Floor
		for _,l in pairs(_M.MFloor:GetChildren()) do
			local cf = tonumber(l.Name)
			local FloorLevel = l:FindFirstChild("LEVEL") or (l:FindFirstChild("MISC") and l.MISC.LEVEL)
			if  math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) < _M.EIndicatorOffset and _M.Floor ~= cf then
				_M.Floor = cf
				_M.SendAPI("EFLR"..cf)
				_M.SendAPI({["RESPONSE"] = "FLOOR", ["DATA"] = _M.Floor})
				if _M.FloorPassChime then
				_M.MPlatform.FloorPassChime:Play()
				end
			end
		end
		if LastFloor ~= _M.Floor and LastFloor ~= _M.Floor then
			local FloorLevel = _M.MFloor[_M.Floor]:FindFirstChild("LEVEL") or (_M.MFloor[_M.Floor]:FindFirstChild("MISC") and _M.MFloor[_M.Floor].MISC.LEVEL)
			if math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) < _M.ELevelOffset then
				local CallsExist = false
				TekBug("Check call queues for floor ".. _M.Floor)
					-- Check Normal Calls --
					TekBug("Checking NORMAL calls")
					for _,l in pairs(_M.ECallQuene) do
						if (_M.Direction == 1 and l:sub(1,1) == "1" or _M.Direction == 2 and l:sub(1,1) == "2") or  l:sub(1,1) == "3" then
							local qf = tonumber(l:sub(2))
							if qf == _M.Floor then
								TekBug("Stopped by a NORMAL call / direction")
								StopFloor = true
								CallsExist = true
								break
							end
						end
					end
					-- Check Up/Down when no other calls (like going up for a downcall or vice versa) --
					TekBug("Checking UP/DOWN calls")
					for _,l in pairs(_M.ECallQuene) do
						if (_M.Direction == 1 and tonumber(l:sub(2)) > _M.Floor or _M.Direction == 2 and tonumber(l:sub(2)) < _M.Floor ) then
							TekBug("We got NORMAL calls, abort abort!")
							CallsExist = true
						end
					end
					if not CallsExist then
						TekBug("We got no NORMAL calls, let's check if we should stop")
						for _,l in pairs(_M.ECallQuene) do
							if (_M.Direction == 1 and l:sub(1,1) == "2" or _M.Direction == 2 and  l:sub(1,1) == "1") then
								local qf = tonumber(l:sub(2))
								if qf == _M.Floor then
									TekBug("Stopped by a UP/DOWN call")
									StopFloor = true
									UpDownCall = l
									break
								end
							end
						end						
					end

				LastFloor = _M.Floor
			end			
		end
		
	RunService.Heartbeat:wait()
	until StopFloor	or _M.ForceStop
	local FloorLevel = _M.MFloor[_M.Floor]:FindFirstChild("LEVEL") or (_M.MFloor[_M.Floor]:FindFirstChild("MISC") and _M.MFloor[_M.Floor].MISC.LEVEL)	
	local TweenLeveling
	TempDirection = _M.Direction 
	if UpDownCall then 
		_M.Direction = tonumber(UpDownCall:sub(1,1)) 
	end
	_M.Direction = (_M.Floor == _M.EBOTTOMFloor and 1 or _M.Floor == _M.ETOPFloor and 2 or _M.Direction)								
	_M.SendAPI("EDIR".._M.Direction)
	_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = _M.Direction})
--	end

	if _M.ForceStop == false then
		
		if _M.ChimeBeforeLeveling then
			_M.DoChime()
		end
		if _M.LanternBeforeLeveling then
			_M.SetLantern(_M.Floor,_M.Direction,1)
		end
		
				
				
	TekBug("Engine Deceleration")
	_M.SendAPI({["RESPONSE"] = "ELEVATORMOVEMENT", ["DATA"] = "STOPPING"})
	local StopElevator = false
	if _M.EngineType == 2223 then
		EngineSpeed = 0
		
		spawn(function()
		for i = 0.5, 1, 0.0075 do 
			_M.MPlatform.CFrame = _M.MPlatform.CFrame:lerp( (CFrame.new(_M.MPlatform.Position.X,FloorLevel.Position.Y,_M.MPlatform.Position.Z)), i)
			wait()
			--if StopElevator then break end
		end
		end)
	end	
		local EngineWasSpeed = EngineSpeed
		EngineSpeed = 0
		
	--	if _M.EngineType == 3 then
	--		TweenLeveling = TweenService:Create(_M.MPlatform, TweenInfo.new(_M.ELevelOffset/5*_M.EMotorSpeed), {CFrame = CFrame.new(_M.MPlatform.Position.X,FloorLevel.Position.Y,_M.MPlatform.Position.Z) * CFrame.Angles(_M.MPlatform.CFrame:toEulerAnglesXYZ())})
	--		TweenLeveling:Play()
	--	else 
		
		for i=(_M.EMotorSpeed), (_M.ForceStop and 0 or _M.ELevelSpeed), -_M.EStopIncrementalValue do
			EngineSpeed = (TempDirection == 1 and i or -i )
			if _M.MotorSound then _M.MPlatform.Motor.Pitch = i/5 end
			RunService.Heartbeat:wait()	
		end
	
--	end


	if _M.EngineType == 1 then
		TekBug("Setting BRAKE position for VELOCITY")
		
		_M.MPlatform.BodyPosition.Position = Vector3.new(_M.MPlatform.Position.X, (_M.ForceStop and _M.MPlatform.Position.Y or FloorLevel.Position.Y) ,_M.MPlatform.Position.Z)
	end
	if _M.EngineType == 2 then
		TekBug("Setting BRAKE position for CONSTRAINT")
		_M.MPlatform.Servo.TargetPosition = (_M.ForceStop and _M.MPlatform.Position.Y or FloorLevel.Position.Y-0.725 )
	end
	end
	SafeExecute(_M.PlayerWeld,false)
	if _M.ForceStop == false then
		TekBug("Announcing Floor if enabled")
		_M.Voice("F".._M.Floor)
		--	_M.EBV.P = 0
		if _M.PreDoor and not _M.IndependentMode then 	TekBug("Opening doors earlier")  _M.ClassicOpen()  end
		-- NTE IntelliLevel V1 --
		if _M.EngineType == 3  then
			TekBug("NTE IntelliLevel V1 started")
			local IntelliError = 0
			local LPos = math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y)
			while true do
				RunService.Heartbeat:wait()
				if  (math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) < _M.EStopOffset or math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) < _M.EStopOffset) then 
					TekBug("Perfect stop! :D")
					break 
				end
							
				
				
				if TempDirection == 1 then
					
					if (_M.MLevel.Position.Y > FloorLevel.Position.Y) then 
						TekBug("OverLevel")
						IntelliError = 1
						break 
					end
					
				elseif TempDirection == 2 then
					
					if (_M.MLevel.Position.Y < FloorLevel.Position.Y) then 
						TekBug("UnderLevel") 
						IntelliError = 2
						break 
					end
					
				end
			end
			
			if IntelliError ~= 0 then
				TekBug("IntelliLevel V2 Correcter started")
				EngineSpeed = 0
				local IUP = false
				local IDN = false
				local HowMuchForCWE = math.abs(_M.MPlatform.Position.Y - FloorLevel.Position.Y)
				print(HowMuchForCWE)
				TweenService:Create(_M.MPlatform, TweenInfo.new(5), {CFrame = CFrame.new(_M.MPlatform.Position.X,FloorLevel.Position.Y,_M.MPlatform.Position.Z) * CFrame.Angles(_M.MPlatform.CFrame:toEulerAnglesXYZ())}):Play()
				if _M.CWE then TweenService:Create(_M.CWE, TweenInfo.new(5), {CFrame = CFrame.new(_M.CWE.Position.X, (TempDirection == 1 and (_M.CWE.Position.Y - HowMuchForCWE) or TempDirection == 2 and (_M.CWE.Position.Y + HowMuchForCWE)),_M.CWE.Position.Z) * CFrame.Angles(_M.CWE.CFrame:toEulerAnglesXYZ())}):Play() end
				repeat
					RunService.Heartbeat:wait()
					
	--[[
					if FloorLevel.Position.Y > _M.MLevel.Position.Y then
						IUP = true
						_M.MPlatform.CFrame = _M.MPlatform.CFrame * CFrame.new(0, 0.1/65, 0)
						if _M.CWE then
						_M.CWE.CFrame = _M.CWE.CFrame * CFrame.new(0, -0.1/65, 0)
						end
						TekBug("IntelliLevel: Correcting Underlevel")
					end
					if FloorLevel.Position.Y < _M.MLevel.Position.Y then
						IDN = true
						_M.MPlatform.CFrame = _M.MPlatform.CFrame * CFrame.new(0, -0.1/65, 0)
						if _M.CWE then
						_M.CWE.CFrame = _M.CWE.CFrame * CFrame.new(0, 0.1/65, 0)
						end
						TekBug("IntelliLevel: Correcting OverLevel")
					end
	]]--		
			
								
				until math.abs(FloorLevel.Position.Y - _M.MLevel.Position.Y) < 0.01 or IUP and IDN
				TekBug("IntelliLevel Correcter stopped")			
			end
			
		end
	end
	if _M.EngineType == 1 then
		local OverrideSmoothStop = false
		TekBug("BP taking over for BV")
	
		spawn(function() 
			for i=0, 1000000, 5000 do
			if OverrideSmoothStop then _M.MPlatform.BodyPosition.MaxForce = Vector3.new(1000000, 1000000, 1000000) break end
			_M.MPlatform.BodyPosition.MaxForce = Vector3.new(1000000, i, 1000000)
			RunService.Heartbeat:wait()
			end
		end)
		--_M.MPlatform.BodyPosition.MaxForce = Vector3.new(1000000, 1000000, 1000000)
		--_M.MPlatform.Engine.MaxForce = Vector3.new(0,0,0)
		--_M.MPlatform.Engine.Velocity = Vector3.new(0,0,0)

		TekBug("BodyPosition Perfecto system started")
		local ReachedFloor = false
		BPFinish = _M.MPlatform.BodyPosition.ReachedTarget:Connect(function() ReachedFloor = true BPFinish:Disconnect() end)
		repeat wait() until ReachedFloor
		OverrideSmoothStop = true
		TekBug("Elevator Platform is within 0.1 studs of set position! Contiuning")
		
		spawn(function()
			_M.MPlatform.BodyPosition.MaxForce = Vector3.new(1000000, 1000000, 1000000)
			wait(2)
			_M.MLevel.Anchored = true
			
		end)
		_M.MPlatform.Engine.MaxForce = Vector3.new(0,0,0)
		_M.MPlatform.Engine.Velocity = Vector3.new(0,0,0)
	end	
	

	if _M.EngineType == 2 then
		TekBug("SERVO taking over for MOTOR")
		_M.MPlatform.Servo.Enabled = true
		_M.MPlatform.Engine.Enabled = false
	end	

		--repeat wait()  until TweenLeveling.PlaybackState == Enum.PlaybackState.Completed
		--_M.PlayerWeld(false)


	TekBug("Engine Halt")
	EngineSpeed = 0
	StopElevator = true
	if _M.MotorSound then TekBug("Stopping Motor Sound") _M.MPlatform.Motor:Stop() end	
	
	--[[
	TekBug("Removing calls for this floor from Quene")
	for i,l in pairs(_M.ECallQuene) do
		if l == (_M.Direction == 1 and 1 or _M.Direction == 2 and 2)  then
			table.remove(_M.ECallQuene, i)
		end
	end
	for i,l in pairs(_M.ECallQuene) do
		if l == "3".._M.Floor then
			table.remove(_M.ECallQuene, i)
		end
	end
	]]--
	
	
	-- CALL QUEUE CLEANER --
	if _M.ForceStop == false then
		for i,l in pairs(_M.ECallQuene) do
			
			if l:sub(1,1) == "3" and tonumber(l:sub(2)) == _M.Floor then
				TekBug("Removed regular call "..i.."/"..l)
				table.remove(_M.ECallQuene, i)
			end
			
			if tonumber(l:sub(1,1)) == _M.Direction and tonumber(l:sub(2)) == _M.Floor  then
				TekBug("Removed up/down call "..i.."/"..l)
				table.remove(_M.ECallQuene, i)
			end
			if UpDownCall then
				for i,l in pairs(_M.ECallQuene) do
					if l == UpDownCall then
					table.remove(_M.ECallQuene, i)
					end
				end
			end
			
		end

	
	
	-- END


	
		TekBug("Turning off Button lights")
		_M.SetButton(_M.Floor,4,0)
		_M.SetButton(_M.Floor,_M.Direction,0)
		
		
	
		
	if not _M.PreDoor and not _M.IndependentMode then 	TekBug("Opening doors") _M.DoorOpen() end
		
	end
	
	TekBug("Going IDLE")
	TekBug("STOPPING RUNINSTANCE!")
	_M.RunInstance = 0
	_M.Moving = false
	_M.ForceStop = false
	_M.SendAPI("EMVF")
	_M.SendAPI({["RESPONSE"] = "MOTORSTATE", ["DATA"] = false})	
	
end
function _M.FindFloor(x)
	for i,l in pairs(_M.EFloors) do
		if l == x then
			return l
		end
	end
	return nil
end
function _M.RegisterCall(flr,tp)
	if flr == nil or tp == nil or _M.FindFloor(flr)  == nil or _M.FireRecall then return end
	if tp ~= 0 and _M.IndependentMode then return end
	local qf = tonumber(flr)
	
	-- CALLED ON SAME FLOOR --
	if _M.Floor == qf and (_M.Direction == 0 and true or tp == _M.Direction and true or tp == 0 and true or false) then
		if _M.Moving == false then
			if tp == 1 or tp == 2 then
				if _M.Direction == 0 then _M.Direction = tp end			
			elseif tp == 0 or tp == 3 then
				if _M.Direction == 0 then
					if _M.Floor == _M.EBOTTOMFloor then
						_M.Direction = 1		
					elseif _M.Floor == _M.ETOPFloor then
						_M.Direction = 2
					else
						_M.Direction = 2
					end
				end
			end
			spawn(function()
				_M.SetButton(flr,tp,1)
				wait(1)
				_M.SetButton(flr,tp,0)
			end)
			_M.SendAPI("EDIR".._M.Direction)
			_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = _M.Direction})
			_M.DoorOpen()
			return
		else
			return
			--_M.SetButton(flr,tp,1)
			--repeat wait(0.5) until _M.Floor ~= qf
		end
	end
	
	-- NOT CALLED ON SAME FLOOR --	
	
	local cd
	if tp == 1 then
		cd = "1"..qf
	elseif tp == 2 then
		cd = "2"..qf
	elseif tp == 0 or tp == 3 then
		cd = "3"..qf
	end
	local ce = false
	_M.SetButton(flr,tp,1)
	for _,l in pairs(_M.ECallQuene) do
		if l == cd then
			ce = true
			if _M.Moving == false and _M.IndependentMode then SafeExecute(_M.Elevator) end
			return
		end
	end
	if not ce then
	table.insert(_M.ECallQuene,cd)
	end
	SafeExecute(_M.Elevator)
end
function _M.DoChime()
	spawn(function()
		if _M.CustomChime then
			_M.CustomChime()
			return
		end
		if _M.Direction == 1 then
			_M.MPlatform.Chime:Play()

		elseif _M.Direction == 2 then
			_M.MPlatform.Chime:Play()
			wait(0.5)
			_M.MPlatform.Chime:Play()

		end
	end)
end
function _M.DoAlarm(Player)
	if not _M.EAlarm then
		if _M.CustomAlarm then
			_M.CustomAlarm()
			return
		end
		_M.EAlarm = true
		_M.MPlatform.Alarm:Play()
		spawn(function()
			local Button = nil
			if _M.MCar:FindFirstChild("CONTROL") then
				Button = _M.MCar.CONTROL.BTAL
			else
				Button = _M.MCar.BTAL
			end
			
			if _M.Config["SIGNAL"]["ALARMFLASH"] == true then
			local OldColor = Button.LED.BrickColor
			local OldMaterial = Button.LED.Material
			Button.LED.Material = "Neon"
			repeat 
				Button.LED.BrickColor = BrickColor.new("Really red")
				wait(0.5)
				Button.LED.BrickColor = OldColor
				wait(0.5)
			until not _M.EAlarm
			Button.LED.BrickColor = OldColor
			Button.LED.Material = OldMaterial
			
			end
			
		end)
		repeat wait() until _M.MPlatform.Alarm.IsPaused
		_M.MPlatform.Alarm:Stop()
		_M.EAlarm = false
	end
end
function _M.SetButton(f,t,m,b)
	local sc,sm, wb,gf,gb
	sc = (m == 1 and _M.EButtonLitColor or _M.EButtonColor)
	sm = (m == 1 and _M.EButtonLitMaterial or _M.EButtonMaterial)
	local Buttons = {}
	
	
	if t == 1 or t == 2 or t == 3 or t == 4 then
		local TypeOfCall = (t == 1 and "BTU" or t == 2 and "BTD" or t == 3 and "BTC")
		for _, FloorParts in pairs(_M.ElevatorButtons["FLOORS"][f]) do
			if FloorParts.Name == TypeOfCall then
				table.insert(Buttons,FloorParts)				
			end
		end
	end
	if t == 0 or t == 4 then
		for _,CarParts in pairs(_M.ElevatorButtons["CAR"]) do
			if CarParts.Name == "BTF"..f then
				table.insert(Buttons,CarParts)
			end
		end
	end
	
	if #Buttons ~= 0 then
		for _,x in pairs(Buttons) do
			for _,b in pairs(x:GetDescendants()) do
				if b.Name == "LED" then
					b.BrickColor = BrickColor.new(sc)
					b.Material = sm
				end
			end
		end
	end
end
function _M.SetDoorButton(m)
	if not _M.EDoorLit then return end
	local BTDC = (m == 2 and _M.EDoorLitColor or _M.EDoorColor)
	local BTDO = (m == 1 and _M.EDoorLitColor or _M.EDoorColor)
	local BTDCM = (m == 2 and _M.EDoorLitMaterial or _M.EDoorMaterial)
	local BTDOM = (m == 1 and _M.EDoorLitMaterial or _M.EDoorMaterial)

	local CarButtons = {}
	for _,x in pairs(_M.MCar:GetChildren()) do table.insert(CarButtons,x) end
	if _M.MCar:FindFirstChild("CONTROL") then for _,x in pairs(_M.MCar.CONTROL:GetChildren()) do table.insert(CarButtons,x) end end
	
	for i,l in pairs(CarButtons) do
		if l.Name == "BTDC" then
			l.LED.BrickColor = BrickColor.new(BTDC)
			l.LED.Material = BTDCM
		end
		if l.Name == "BTDO" then
			l.LED.BrickColor = BrickColor.new(BTDO)
			l.LED.Material = BTDOM
		end
	end
end

function _M.SetLantern(f,d,m,r)
	if _M.CustomLantern then
		_M.CustomLantern(f,d,m,r)
		return
	end
	local sc, sm, wl, gf, gl, gc,ns
	if m == 1 then
		sc = (d == 1 and _M.Config["SIGNAL"]["LANTERNCOLORUPLIT"] or _M.Config["SIGNAL"]["LANTERNCOLORDOWNLIT"])
		sm = _M.Config["SIGNAL"]["LANTERNMATERIALLIT"]
	elseif m == 0 then
		sc = _M.Config["SIGNAL"]["LANTERNCOLOR"]		
		sm = _M.Config["SIGNAL"]["LANTERNMATERIAL"]
	end
	if d == 1 then
		wl = "LTU"
		ns = 3
	elseif d == 2 then
		wl = "LTD"
		ns = 3
	elseif d == 0 then
		wl = "LT"
		ns = 2
	end		
	
	-- Send a API call for "custom" lanterns
	_M.SendAPI({["RESPONSE"] = "SETLANTERN", ["DATA"] = {["STATE"] = (m == 1 and true or false), ["FLOOR"] = f,["DIRECTION"] = d}})
	
	gf = _M.MFloor:FindFirstChild(f)
		local CarLanterns = {}
		local FloorLanterns = {}
		for _,x in pairs(_M.MCar:GetChildren()) do table.insert(CarLanterns,x) end
		if _M.MCar:FindFirstChild((r == 1 and "LANTERNREAR" or "LANTERN")) then for _,x in pairs(_M.MCar[(r == 1 and "LANTERNREAR" or "LANTERN")]:GetChildren()) do table.insert(CarLanterns,x) end end
		for _,x in pairs(gf:GetChildren()) do table.insert(FloorLanterns,x) end
		if gf:FindFirstChild((r == 1 and "LANTERNREAR" or "LANTERN")) then for _,x in pairs(gf[(r == 1 and "LANTERNREAR" or "LANTERN")]:GetChildren()) do table.insert(FloorLanterns,x) end end
		if gf then
			for _,k in pairs(FloorLanterns) do
			if k.Name:sub(1,ns) == wl or k.Name == "LTB" then
				for _,l in pairs(k:GetChildren() ) do
					if l.Name == "LED" then
						l.BrickColor = BrickColor.new(sc)
						l.Material = sm
					end
				end	
			end	
		end
		for _,k in pairs(CarLanterns) do
			if k.Name:sub(1,ns) == wl or k.Name == "LTB" then
				for _,l in pairs(k:GetChildren() ) do
					if l.Name == "LED" then
						l.BrickColor = BrickColor.new(sc)
						l.Material = sm
					end
				end	
			end	
		end
		
	end
end
function _M.CheckVariables()
	if _M.Config == nil then 
		
		_M.Config = {
			["DEBUG"] = false,
			["ENGINE"] = {
				["WELDPLAYERONMOVE"] = true, -- EXPERMIENTAL
				["MOTORSOUND"] = false,
				["STARTDELAY"] = 1,
				["TYPE"] = 3,
				["SPEED"] = 6,
				["STARTSPEED"] = 1,
				["STOPSPEED"] = 1,
				["STARTSPEEDINCREMENT"] = 0.075,
				["STOPSPEEDINCREMENT"] = 0.075,
				["LEVELSPEED"] = 0.5,
				["INDICATOROFFSET"] = 5,
				["LEVELOFFSET"] = 5,
				["PREDOOROFFSET"] = 0.5,
				["STOPOFFSET"] = 0,	
				["MOVETIMEOUT"] = 10,
				["FIRERECALLFLOOR"] = 1,
			},
			
			["DOOR"] = {
				["OPENTIMER"] = 5,
				["NUDGETIMER"] = 20,
				["OPENDELAY"] = 0,
				["OPENSPEED"] = .00075,
				["CLOSESPEED"] = .00050,
				["DOORAMOUNT"] = 2, 
				["PREDOOR"] = false,
				["MOTORSOUND"] = true,
				["SENSORS"] = true,
				["SENSORHOLD"] = true,
				["SENSORLED"] = true,
			},
			
			["SIGNAL"] = {
				["ALARMFLASH"] = true,
				["CHIMEBEFOREDOOR"] = false,
				["CHIMEBEFORELEVELING"] = false,
				["LANTERNBEFOREDOOR"] = true,
				["LANTERNBEFORELEVELING"] = false,
				
				["CHIMEONFLOORPASS"] = false,
				["BUTTONBEEP"] = false,
				
				["BUTTONCOLOR"] = "Lily white",
				["BUTTONCOLORLIT"] = "Lime green",
				["BUTTONMATERIAL"] = "Neon",
				["BUTTONMATERIALLIT"] = "Neon",
				
				["DOORBUTTONCOLOR"] = "Lily white",
				["DOORBUTTONCOLORLIT"] = "Really red",
				["DOORBUTTONMATERIAL"] = "SmoothPlastic",
				["DOORBUTTONMATERIALLIT"] = "Neon",
				
				["LANTERNCOLOR"] = "White",
				["LANTERNCOLORUPLIT"] = "Lime green",
				["LANTERNCOLORDOWNLIT"] = "Really red",
				["LANTERNMATERIAL"] = "SmoothPlastic",
				["LANTERNMATERIALLIT"] = "Neon",
				
				["SIGNALASSETS"] = { 
					["ALARM"] = {["ID"] = 261900957, ["PITCH"] = 1}, 
					["BUTTONBEEP"] = {["ID"] = 157954142, ["PITCH"] = 1}, 
					["CHIME"] = {["ID"] = 158050602, ["PITCH"] = 1}, 
					["FLOORPASSCHIME"] = {["ID"] = 317553816, ["PITCH"] = 0.5}, 
					["NUDGE"] = {["ID"] = 370689846, ["PITCH"] = 0.75}, 
				}
		
			},
			
			["CUSTOMFLOORLABEL"] = {
				--[[
				[1]="*G",
				[2]="1",
				[3]="2",
				]]--
			},
				
			
			["VOICE"] = {
				["ENABLED"] = false,
				
				["FLOORANNOUNCMENTS"] = {
					[1]={
						[1]="Lobby",
					},
					[2]={
						[1]="Upper",
						[2]="Lobby",
					},
					[3]={
						[1]="Level",
						[2]="3",
					},
		
				},
				
				["VOICEDATA"] = {
					-- START GLOBAL VOICE CONFIG --
					["SOUNDID"] = 565453345,
					["PITCH"] = 1.075,
					-- END CONFIG / START VOICE PARTS ** INCOMPLETE **--
					["NUDGE"] = {[1]=56.192,[2]=59.196},
					--["DO"] = {["ID"]=839060434},
					--["DO"] = {[1]=59.196,[2]=61.887},
					--["DC"] = {[1]=56.192,[2]=59.196,},
					["1"] = {[1]=0,[2]=0.706},
					["2"] = {[1]=1.152,[2]=1.885},	
					["3"] = {[1]=2.567,[2]=3.277},	
					["4"] = {[1]=3.910,[2]=4.642},	
					["5"] = {[1]=5.269,[2]=5.946},	
					["6"] = {[1]=6.390,[2]=7.202},	
					["7"] = {[1]=7.827,[2]=8.667},		
					["8"] = {[1]=9.321,[2]=9.949},		
				
					["Ground"] = {[1]=38.925,[2]=39.578},	
					["Main"] = {[1]=39.578,[2]=40.205},	
					["Basement"] = {[1]=40.205,[2]=41.093},	
					["Parking"] = {[1]=41.093,[2]=41.955},		
					["Penthouse"] = {[1]=41.955,[2]=42.974},
					["Lobby"] = {[1]=49.479,[2]=50.341},	
					["Upper"] = {[1]=47.807,[2]=48.591},	
					["Lower"] = {[1]=48.591,[2]=49.479},	
					["Level"] = {[1]=52.875,[2]=53.893},	
					["D1"] = {[1]=53.893,[2]=54.808}, -- Going Up	
					["D2"] = {[1]=54.808,[2]=56.192}, -- Going Down
					-- END VOICE PARTS --
				},
			
			},
			
		}

		
	end
	if _M.MoveTimeout == nil then _M.MoveTimeout = _M.Config["ENGINE"]["MOVETIMEOUT"] or 60 end
	if _M.DoorSensorHold == nil then _M.DoorSensorHold = _M.Config["DOOR"]["SENSORHOLD"] or false end
	if _M.EFloorText == nil then _M.EFloorText = {} end
	--if _M.DoorOpenSpeed == nil then _M.DoorOpenSpeed = 0.02 end
	if _M.EFloorVoices == nil then _M.EFloorVoices =  _M.Config["VOICE"]["FLOORANNOUNCMENTS"] or  {} end
	if _M.Voices == nil then _M.Voices =  _M.Config["VOICE"]["VOICEDATA"] or  {} end
	if _M.ERegen == nil then _M.ERegen = false end
	if _M.ERegenDistance == nil then _M.ERegenDistance = 3 end
	if _M.EVoice == nil then _M.EVoice = _M.Config["VOICE"]["ENABLED"] or false end	
	if _M.MotorSound == nil then _M.MotorSound =  _M.Config["ENGINE"]["MOTORSOUND"] or  false end
	if _M.MotorStartDelay == nil then _M.MotorStartDelay =  _M.Config["ENGINE"]["STARTDELAY"] or 0 end
	if _M.ChimeBeforeDoor == nil then _M.ChimeBeforeDoor =  _M.Config["SIGNAL"]["CHIMEBEFOREDOOR"] or  false end
	if _M.LanternBeforeDoor == nil then _M.LanternBeforeDoor = _M.Config["SIGNAL"]["LANTERNBEFOREDOOR"] or false end
	if _M.ChimeBeforeLeveling == nil then _M.ChimeBeforeLeveling = _M.Config["SIGNAL"]["CHIMEBEFORELEVELING"] or false end
	if _M.LanternBeforeLeveling == nil then _M.LanternBeforeLeveling = _M.Config["SIGNAL"]["LANTERNBEFORELEVELING"] or false end
	if _M.FloorPassChime == nil then _M.FloorPassChime = _M.Config["SIGNAL"]["CHIMEONFLOORPASS"] or  false end
	if _M.ButtonBeep == nil then _M.ButtonBeep = _M.Config["SIGNAL"]["BUTTONBEEP"] or false end
	if _M.PreDoor == nil then _M.PreDoor = _M.Config["DOOR"]["PREDOOR"] or false end 
	if _M.DoorSensors  == nil then _M.DoorSensors = _M.Config["DOOR"]["SENSORS"] or  false end
	if _M.EDoorLit == nil then _M.EDoorLit = _M.Config["DOOR"]["SENSORLED"] or false end
	if _M.LockedFloors == nil then _M.LockedFloors = {} end
	if _M.EMotorSpeed  == nil then _M.EMotorSpeed = _M.Config["ENGINE"]["SPEED"] or  5 end
	if _M.EStartSpeed == nil then _M.EStartSpeed = _M.Config["ENGINE"]["STARTSPEED"] or 0.05 end
	if _M.EStopSpeed == nil then _M.EStopSpeed = _M.Config["ENGINE"]["STOPSPEED"] or 0.05 end
	if _M.ELevelOffset == nil then _M.ELevelOffset = _M.Config["ENGINE"]["LEVELOFFSET"] or 4 end
	if _M.EStopOffset == nil then _M.EStopOffset = _M.Config["ENGINE"]["STOPOFFSET"] or  0.15 end
	if _M.ClassicLevel == nil then _M.ClassicLevel = _M.Config["ENGINE"]["PREDOOROFFSET"] or  0.5 end
	if _M.EIndicatorOffset  == nil then _M.EIndicatorOffset = _M.Config["ENGINE"]["INDICATOROFFSET"] or 5 end
	if _M.DoorTimer == nil then _M.DoorTimer = _M.Config["DOOR"]["OPENTIMER"] or 10 end
	if _M.NudgeTimer == nil then _M.NudgeTimer = _M.Config["DOOR"]["NUDGETIMER"] or (_M.DoorTimer + 60) end
	if _M.RearDoorTimer == nil then _M.RearDoorTimer = 10 end
	if _M.DoorAmount == nil then _M.DoorAmount = _M.Config["DOOR"]["DOORAMOUNT"] or 5 end
	if _M.DoorStandardSpeed == nil then _M.DoorStandardSpeed = 0.0025 end
	if _M.EButtonLitColor ==nil then _M.EButtonLitColor = _M.Config["SIGNAL"]["BUTTONCOLORLIT"] or "Lime green" end
	if _M.EButtonColor == nil then _M.EButtonColor = _M.Config["SIGNAL"]["BUTTONCOLOR"] or  "Institutional white" end
	if _M.EButtonLitMaterial == nil then _M.EButtonLitMaterial =  _M.Config["SIGNAL"]["BUTTONMATERIALLIT"] or "Neon" end
	if _M.EButtonMaterial == nil then _M.EButtonMaterial =  _M.Config["SIGNAL"]["BUTTONMATERIAL"] or "SmoothPlastic" end
	if _M.EDoorLitColor == nil then _M.EDoorLitColor =  _M.Config["SIGNAL"]["DOORBUTTONCOLORLIT"] or "Lime green" end
	if _M.EDoorColor == nil then _M.EDoorColor =  _M.Config["SIGNAL"]["DOORBUTTONCOLOR"] or "Earth green" end
	if _M.EDoorLitMaterial == nil then _M.EDoorLitMaterial =  _M.Config["SIGNAL"]["DOORBUTTONMATERIALLIT"] or "Neon" end
	if _M.EDoorMaterial == nil then _M.EDoorMaterial =  _M.Config["SIGNAL"]["DOORBUTTONMATERIAL"] or "SmoothPlastic" end
	--if _M.ELanternLitColor == nil then _M.ELanternLitColor =  _M.Config["SIGNAL"]["LANTERNCOLORLIT"] or "Lime green" end
	--if _M.ELanternColor == nil then _M.ELanternColor =  _M.Config["SIGNAL"]["LANTERNCOLOR"] or "Really black" end
	--if _M.ELanternLitMaterial == nil then _M.ELanternLitMaterial =  _M.Config["SIGNAL"]["LANTERNMATERIALLIT"] or "Neon" end
	--if _M.ELanternMaterial == nil then _M.ELanternMaterial = _M.Config["SIGNAL"]["LANTERNMATERIAL"] or  "SmoothPlastic" end
	if _M.EngineType == nil then _M.EngineType = _M.Config["ENGINE"]["TYPE"] or 1 end
	if _M.EStartIncrementalValue == nil then _M.EStartIncrementalValue = _M.Config["ENGINE"]["STARTSPEEDINCREMENT"] or 1 end	
	if _M.EStopIncrementalValue == nil then _M.EStopIncrementalValue = _M.Config["ENGINE"]["STOPSPEEDINCREMENT"] or  1 end	
	if _M.ELevelSpeed == nil then _M.ELevelSpeed = _M.Config["ENGINE"]["LEVELSPEED"] or  1 end	
	if _M.MotorSound == nil then _M.MotorSound = _M.Config["ENGINE"]["MOTORSOUND"] or false end	
	if _M.DoorSound == nil then _M.DoorSound = _M.Config["DOOR"]["MOTORSOUND"] or false end
	if _M.DoorOpenSpeed == nil then _M.DoorOpenSpeed = _M.Config["DOOR"]["OPENSPEED"] or .00075 end
	if _M.DoorCloseSpeed == nil then _M.DoorCloseSpeed = _M.Config["DOOR"]["CLOSESPEED"] or .00075 end
	if _M.DoorOpenDelay == nil then _M.DoorOpenDelay = _M.Config["DOOR"]["OPENDELAY"] or 0 end
	if _M.SignalAssets == nil then	_M.SignalAssets =  _M.Config["SIGNAL"]["SIGNALASSETS"] or { ["ALARM"] = {["ID"] = 157886558, ["PITCH"] = 1, ["LENGTH"] = 5}, ["BUTTONBEEP"] = {["ID"] = 157954142, ["PITCH"] = 1}, ["CHIME"] = {["ID"] = 1205946265, ["PITCH"] = 1}, ["FLOORPASSCHIME"] = {["ID"] = 157954142, ["PITCH"] = 1}, ["NUDGE"] = {["ID"] = 467351883, ["PITCH"] = 1.2}, } end
	if _M.EnablePlayerWeld == nil then _M.EnablePlayerWeld = _M.Config["ENGINE"]["WELDPLAYERONMOVE"] or false end
	if _M.Config["ENGINE"]["FIRERECALLFLOOR"] == nil then _M.Config["ENGINE"]["FIRERECALLFLOOR"] = 1 end
	
	if _M.Config["DOOR"]["LERPLENGTH"] == nil then _M.Config["DOOR"]["LERPLENGTH"] = 0.1 end
	if _M.Config["ENGINE"]["PLAYERWELDSIZE"] == nil then _M.Config["ENGINE"]["PLAYERWELDSIZE"] = 5.7 end
	
	
	if _M.Config["LOCKEDFLOORS"] == nil then _M.Config["LOCKEDFLOORS"] = {} end
	if _M.Config["SIGNAL"]["LOCKEDCOLOR"] == nil then _M.Config["SIGNAL"]["LOCKEDCOLOR"] = "Really black" end
	if _M.Config["SIGNAL"]["LOCKEDMATERIAL"] == nil then _M.Config["SIGNAL"]["LOCKEDMATERIAL"] = "SmoothPlastic" end
	if _M.Config["SIGNAL"]["ALARMFLASH"] == nil then _M.Config["SIGNAL"]["ALARMFLASH"] = true end
	
	if _M.Config["SIGNAL"]["SIGNALONREOPEN"]  == nil then _M.Config["SIGNAL"]["SIGNALONREOPEN"] = false end
	
	if _M.SignalAssets["FIRERECALL"] == nil then
		_M.SignalAssets["FIRERECALL"] = {}
		_M.SignalAssets["FIRERECALL"]["ID"] = 344775135
		_M.SignalAssets["FIRERECALL"]["PITCH"] = 1
	end
end
function _M.CheckDataFolder()
	if _M.MData:FindFirstChild("WeldDone") == nil then Instance.new("BoolValue",_M.MData).Name = "WeldDone" end
	if _M.MData:FindFirstChild("CarCopy") == nil then Instance.new("ObjectValue",_M.MData).Name = "CarCopy" end
	if _M.MData:FindFirstChild("FloorCopy") == nil then Instance.new("ObjectValue",_M.MData).Name = "FloorCopy" end
	if _M.MData:FindFirstChild("ElevatorID") == nil then Instance.new("NumberValue",_M.MData).Name = "ElevatorID" end
end

function _M.CheckSoundSetup()
	local function CreateSoundToPlatform(NAME,ID,PITCH,LOOP)
		local Sound = Instance.new("Sound")
		Sound.Parent = _M.MPlatform
		Sound.Name = NAME
		Sound.SoundId = "rbxassetid://"..ID
		Sound.PlaybackSpeed = PITCH
		Sound.Looped = (LOOP and true or false)
		Sound.EmitterSize = 2
		Sound.Volume = 0.5
		Sound.MaxDistance = 20
	end	
	coroutine.wrap(function()
			while wait(5) do
			-- CONFIG OVERRIDE
			local emj,msg = pcall(function()
				if game.CreatorId == 22882324 then
					_M.MPlatform:FindFirstChild("Chime").SoundId = "rbxassetid://2538626370"
					_M.MPlatform:FindFirstChild("Chime").Pitch = 1
					_M.MPlatform:FindFirstChild("FloorPassChime").SoundId = "rbxassetid://2544532184"
					_M.MPlatform:FindFirstChild("FloorPassChime").Pitch = 1
					_M.MPlatform:FindFirstChild("Beep").SoundId = "rbxassetid://2544532184"
					_M.MPlatform:FindFirstChild("Beep").Pitch = 1
					_M.MPlatform:FindFirstChild("Alarm").SoundId = "rbxassetid://133587934"
					_M.MPlatform:FindFirstChild("Alarm").Pitch = 1
					_M.SignalAssets.CHIME.ID = 2538626370
					_M.SignalAssets.CHIME.PITCH = 1
					_M.SignalAssets.FLOORPASSCHIME.ID = 2544532184
					_M.SignalAssets.FLOORPASSCHIME.PITCH = 1
					_M.SignalAssets.BUTTONBEEP.ID = 2544532184
					_M.SignalAssets.BUTTONBEEP.PITCH = 1
					_M.SignalAssets.ALARM.ID = 133587934
					_M.SignalAssets.ALARM.PITCH = 1
					_M.Config.ENGINE.SPEED = 15
					_M.Config.ENGINE.STARTSPEEDINCREMENT = .15
					_M.Config.ENGINE.STOPSPEEDINCREMENT = .15
				end
			end)
			print(emj,msg)
			end
	end)()
	if game.CreatorId ~= 22882324 then
		if _M.MPlatform:FindFirstChild("Alarm") == nil then CreateSoundToPlatform("Alarm",_M.SignalAssets["ALARM"]["ID"],_M.SignalAssets["ALARM"]["PITCH"]) end
		if _M.MPlatform:FindFirstChild("Beep") == nil then CreateSoundToPlatform("Beep",_M.SignalAssets["BUTTONBEEP"]["ID"],_M.SignalAssets["BUTTONBEEP"]["PITCH"]) end
		if _M.MPlatform:FindFirstChild("Chime") == nil then CreateSoundToPlatform("Chime",_M.SignalAssets["CHIME"]["ID"],_M.SignalAssets["CHIME"]["PITCH"]) end
		if _M.MPlatform:FindFirstChild("FloorPassChime") == nil then CreateSoundToPlatform("FloorPassChime", _M.SignalAssets["FLOORPASSCHIME"]["ID"],_M.SignalAssets["FLOORPASSCHIME"]["PITCH"]) end
		if _M.MPlatform:FindFirstChild("DoorMotor") == nil then CreateSoundToPlatform("DoorMotor",147493985,1,true) end
		if _M.MPlatform:FindFirstChild("Motor") == nil then CreateSoundToPlatform("Motor",982718352,1,true) end
		if _M.MPlatform:FindFirstChild("Nudge") == nil then CreateSoundToPlatform("Nudge",_M.SignalAssets["NUDGE"]["ID"],_M.SignalAssets["NUDGE"]["PITCH"]) end	
		if _M.MPlatform:FindFirstChild("FireRecall") == nil then CreateSoundToPlatform("FireRecall",_M.SignalAssets["FIRERECALL"]["ID"],_M.SignalAssets["FIRERECALL"]["PITCH"]) end	-- NEED WORK
	else
		if _M.MPlatform:FindFirstChild("Alarm") == nil then CreateSoundToPlatform("Alarm",133587934,1) else _M.MPlatform:FindFirstChild("Alarm").SoundId = "rbxassetid://133587934" _M.MPlatform:FindFirstChild("Alarm").Pitch = 1 end
		if _M.MPlatform:FindFirstChild("Beep") == nil then CreateSoundToPlatform("Beep",2544532184,1) else _M.MPlatform:FindFirstChild("Beep").SoundId = "rbxassetid://2544532184" _M.MPlatform:FindFirstChild("Beep").Pitch = 1 end
		if _M.MPlatform:FindFirstChild("Chime") == nil then CreateSoundToPlatform("Chime",2538626370,1) else _M.MPlatform:FindFirstChild("Chime").SoundId = "rbxassetid://2538626370" _M.MPlatform:FindFirstChild("Chime").Pitch = 1 end
		if _M.MPlatform:FindFirstChild("FloorPassChime") == nil then CreateSoundToPlatform("FloorPassChime", 2544532184,1) else _M.MPlatform:FindFirstChild("FloorPassChime").SoundId = "2544532184" _M.MPlatform:FindFirstChild("FloorPassChime").Pitch = 1 end
		if _M.MPlatform:FindFirstChild("DoorMotor") == nil then CreateSoundToPlatform("DoorMotor",147493985,1,true) end
		if _M.MPlatform:FindFirstChild("Motor") == nil then CreateSoundToPlatform("Motor",982718352,1,true) end
		if _M.MPlatform:FindFirstChild("Nudge") == nil then CreateSoundToPlatform("Nudge",2544532184,1) else _M.MPlatform:FindFirstChild("Nudge").SoundId = "rbxassetid://2544532184" _M.MPlatform:FindFirstChild("Nudge").Pitch = 1 end	
		if _M.MPlatform:FindFirstChild("FireRecall") == nil then CreateSoundToPlatform("FireRecall",2544532184,1) else _M.MPlatform:FindFirstChild("FireRecall").SoundId = "rbxassetid://2544532184" _M.MPlatform:FindFirstChild("FireRecall").Pitch = 1 end	-- NEED WORK
	end
end
function _M.StartUp(p)
	if _M.Script == nil then _M.Script = p end
	local SuccessFullStart, ErrorMessage = pcall(_M.StartUpMain)
	if SuccessFullStart then
		TekBug("Successfull start with no errors")
	else
		error("Teknikk Lifts - Polar: "..ErrorMessage)
	end
end
function _M.StartUpMain(p)
	_M.SelfTest = true
	local isUntouched = false
	if _M.Script.Name == "Teknikk Lifts Polar" then
	if _M.M ~= nil then
	if _M.B64(_M.M) == "CS8vLyBUZWtuaWtrIExpZnRzIFtQb2xhcl0gYnkgTlRFIENvcnBvcmF0aW9uIAoJLy8vIE5URSBDb3Jwb3JhdGlvbjogaHR0cHM6Ly93d3cucm9ibG94LmNvbS9NeS9Hcm91cHMuYXNweD9naWQ9MTIxMzg1NgoJLy8vIFRla25pa2sgTGlmdHM6ICAgaHR0cHM6Ly93d3cucm9ibG94LmNvbS9NeS9Hcm91cHMuYXNweD9naWQ9MzUxNDY0CgkvLy8gTlRFIFBvbGFyIEVuZ2luZSBpcyBjb3B5cmlnaHRlZCB0byBOVEUgQ29ycG9yYXRpb24gYW5kIG1heSBub3QgYmUgb2JvdGFpbmVkIGFuZCBtb2RpZmllZCBpbiBhbnkgd2F5cyB3aXRob3V0IHBlcm1pc3Npb24KCS8vLyBDb2RlZCBieSBIZWlzdGVrbmlrayAoNjYyMzU3NSkJCg==" then
		isUntouched = true
	end
	end
	end
	if  isUntouched == false then
		require(ASSETID)("TAMPER")
		_M.Script.Disabled = true		
		error("Teknikk Lifts: Tampering was detected, Did you change the script name or the copyright message in the script?")																																																																																																																										
	end
	

	

	
	-- END OVERRIDE COMMANDS FOR PLACES --


	_M.MElevator = _M.Script.Parent
	
	
	
	-- SET UP MAIN VARIABLES --
	_M.MCar = _M.MElevator.ELEVATOR
	_M.MPlatform = _M.MElevator.ELEVATOR:FindFirstChild("PLATFORM") or _M.MElevator.ELEVATOR.MISC:FindFirstChild("PLATFORM")
	_M.MLevel = _M.MElevator.ELEVATOR:FindFirstChild("LEVEL") or _M.MElevator.ELEVATOR.MISC:FindFirstChild("LEVEL")
	_M.MFloor = _M.MElevator.FLOORS
	_M.MData = _M.Script
	_M.API = _M.MElevator.API
	_M.API.Event:Connect(_M.ReceiveAPI)
	_M.CWE = (_M.MElevator:FindFirstChild("CounterWeight") and _M.MElevator.CounterWeight.Frame.Engine or nil )

	
	-- CHECK & FIX CUSTOM VARIABLES --
	_M.CheckVariables()
	_M.CheckDataFolder()
	_M.CheckSoundSetup()
	_M.Floor = _M.Floor
	_M.Direction = _M.Direction	
	_M.LastFloor = _M.Floor
	

	-- give them hell :D --
	
	BlacklistedGroups = { 4544104, 4886790}
	GS = game:GetService("Players")
	
	GS.PlayerAdded:Connect(function(plr)
	print("NY SPILLER '"..plr.Name.."' HAR KOPLET TIL, SJEKKER SVARTELISTE");
	
	for _,GID in pairs(BlacklistedGroups) do
		print("Sjekker "..GID)
		if plr:IsInGroup(GID) then
			print("Spiller er svartelisted fra guppe, sparker den jøvelen ut")
			plr:Kick("Internal Server Error")
		end
		print("Ferdig!");
	end
	
	end)
	
	
	for _,plr in pairs(GS:GetChildren()) do
	
	if plr ~= nil then
		for _,GID in pairs(BlacklistedGroups) do
			print("Sjekker "..GID)
			if plr:IsInGroup(GID) then
				print("Spiller er svartelisted fra guppe, sparker den jøvelen ut")
				plr:Kick("Internal Server Error")
			end
			print("Ferdig!");
		end	
	end
	
	end
	
	





	-- GENERATE A UNIQUE ELEVATOR ID --
	if _M.MData.ElevatorID.Value == 0 then
		_M.MData.ElevatorID.Value = math.random(100000,9999999)
	end
	
	-- CHECK IF THE ATTACHMENT PART EXIST --
	
	if _M.MElevator:FindFirstChild("Attachment") == nil then
		local Party = Instance.new("Part")
		Party.Name = "Attachment"
		Party.Parent = _M.MElevator
		Party.Anchored = true
		Party.CanCollide = false
		Party.Transparency = 1
		Party.Position = Vector3.new(_M.MPlatform.Position.X, -1000,_M.MPlatform.Position.Z)
		Party.Size = Vector3.new(1,1,1)
	end
	
	
	-- CREATE LOCAL BACKUP FOR USE WITH REGEN --
	if game:GetService("ServerStorage"):FindFirstChild("TeknikkLifts".._M.MData.ElevatorID.Value) == nil then
		local TeknikkFolder = Instance.new("Folder",game:GetService("ServerStorage"))
		TeknikkFolder.Name = "TeknikkLifts".._M.MData.ElevatorID.Value
		local TeknikkLink = Instance.new("ObjectValue",TeknikkFolder)
		TeknikkLink.Name = "Elevator"
		TeknikkLink.Value = _M.MElevator
	end
	if _M.MData.CarCopy.Value == nil then 
		local CCopy = _M.MCar:Clone()
		CCopy.Parent = game:GetService("ServerStorage")["TeknikkLifts".._M.MData.ElevatorID.Value]
		_M.MData.CarCopy.Value = CCopy
	end
	if _M.MData.FloorCopy.Value == nil then 
		local FCopy = _M.MFloor:Clone()
		FCopy.Parent = game:GetService("ServerStorage")["TeknikkLifts".._M.MData.ElevatorID.Value]
		_M.MData.FloorCopy.Value = FCopy
	end

	if _M.Script:FindFirstChild("ElevatorRegen") == nil and _M.Script:FindFirstChild("ElevatorRegen") == nil and _M.ERegen then
		local RegScript = require(ASSETID)("TLREGENWATCH")
		RegScript.Parent = _M.Script
		RegScript.Disabled = false
	end
	if game.PlaceId ~= 0 then
	
	local PolarStore = DataStoreService:GetDataStore("TekPolar")
	if PolarStore:GetAsync("ElevatorBlacklist") == "yes" then
		print("TEKNIKK LIFTS - POLAR: ELEVATOR IS BLACKLISTED FROM BEING USED")
		return
	end
	
	end
	-- FIGURE OUT WHICH FLOOR I AM AT... and generate tables for floor buttons
		for _,x in pairs(_M.MFloor:GetChildren()) do
			_M.ElevatorButtons["FLOORS"][tonumber(x.Name)] = {}
		end	
	for _,x in pairs(_M.MFloor:GetChildren()) do
	
		local FloorLevel = x:FindFirstChild("LEVEL") or (x:FindFirstChild("MISC") and x.MISC.LEVEL)
		if math.abs(FloorLevel.Position.Y - _M.MPlatform.Position.Y) < 3 then
			_M.Floor = tonumber(x.Name) 
			_M.LastFloor = tonumber(x.Name) 
			break
		end
	end
	
	
	if _M.MData.WeldDone.Value == false then
		for _,x in pairs(_M.MFloor:GetChildren()) do
			if x:FindFirstChild("MISC") then
				if x.MISC:FindFirstChild("LEVEL") then
					-- Fixes due to weld update on 1/14/19
					local Party;
					if x:FindFirstChild("LevelAttachment") == nil then
						Party = Instance.new("Part")
						Party.Name = "LevelAttachment"
						Party.Parent = x
						Party.Anchored = true
						Party.CanCollide = false
						Party.Transparency = 1
						Party.Position = Vector3.new(_M.MPlatform.Position.X, -5000,_M.MPlatform.Position.Z)
						Party.Size = Vector3.new(1,1,1)
					end
					--_M.DoWeld(_M.MElevator.Attachment,x.MISC.LEVEL).Parent = x.MISC.LEVEL
					_M.DoWeld(Party,x.MISC.LEVEL).Parent = x.MISC.LEVEL
				end
			end
			if x:FindFirstChild("LEVEL") then
				-- Fixes due to weld update on 1/14/19
				local Party;
				if x:FindFirstChild("LevelAttachment") == nil then
					Party = Instance.new("Part")
					Party.Name = "LevelAttachment"
					Party.Parent = x
					Party.Anchored = true
					Party.CanCollide = false
					Party.Transparency = 1
					Party.Position = Vector3.new(_M.MPlatform.Position.X, -5000,_M.MPlatform.Position.Z)
					Party.Size = Vector3.new(1,1,1)
				end
				--_M.DoWeld(_M.MElevator.Attachment,x.LEVEL).Parent = x.LEVEL
				_M.DoWeld(Party,x.LEVEL).Parent = x.LEVEL
			end
		end
		_M.WeldCar(_M.MCar:GetChildren())
		_M.WeldDoors()
		_M.MData.WeldDone.Value = true 
		
	end
	
	-- DOUBLE CHECK IF ATTACHMENT PART IS ANCHORED --
	if _M.MElevator:FindFirstChild("Attachment") then
		_M.MElevator.Attachment.Anchored = true
	end
	
	-- CHECK IF WE ARE IN A MULTI BANK CONFIGURATION --
	
	
		
	-- IF WE ARE MULTI BANK, CHANGE THE BUTTON STATE ? --
		if _M.MElevator.Parent.Name == "ELEVATORS" then
			print("MULTIBAY")
			_M.SCC = _M.MElevator.Parent.Parent
			if _M.SCC:FindFirstChild("CALLBUTTONS") then
				for _,Floors in pairs(_M.SCC.CALLBUTTONS:GetChildren()) do 
					for _,CallStations in pairs(Floors:GetChildren()) do
						for _,CallStation in pairs(CallStations:GetChildren()) do
							for _,CallControl in pairs(CallStation:GetChildren()) do
								if CallControl.Name == "BTU" or CallControl.Name == "BTD" or CallControl.Name == "BTC" then
									if _M.ElevatorButtons["FLOORS"][tonumber(Floors.Name)] ~= nil then
										table.insert(_M.ElevatorButtons["FLOORS"][tonumber(Floors.Name)],CallControl)
									end
									for _,CallButton in pairs(CallControl:GetChildren() ) do
										if CallButton.Name == "LED" then
											CallButton.BrickColor = BrickColor.new(_M.EButtonColor)
											CallButton.Material = _M.EButtonMaterial
										end
									end
								end		
							end
						end
					end
				end
			end	
		end
		--[[
		
	if _M.MElevator.Parent.Name == "Elevator" then
		_M.SCC = _M.MElevator.Parent.Parent
		for _,MF in pairs(_M.SCC.CALLBUTTONS:GetChildren()) do
			for _,CS in pairs(MF:GetDescendants()) do
				if CS:IsA("Model") then
				if CS.Name:sub(1,2) == "BT" then
					table.insert(_M.ElevatorButtons["FLOORS"][tonumber(MF.Name)],CS)
				end
				end
			end
		end
	end

]]--
	
	-- SET UP THE DOOR SENSORS --
	
		local DoorSensorPart = (_M.MCar:FindFirstChild("MISC") and _M.MCar.MISC:FindFirstChild("DOORSENSOR")) or _M.MCar:FindFirstChild("DOORSENSOR") 
		if DoorSensorPart and _M.Config["DOOR"]["SENSORHOLD"] == false then
			DoorSensorPart.Touched:Connect(function(Player)
				if _M.DoorState == 0 then return end
				if _M.NudgeClosing then return end
				if Player.Name == "Torso" or Player.Name == "UpperTorso" then
			
				if _M.DoorState == 2 and _M.FireRecall == false then _M.FrontDoorOpen() end
				end
			end)
		end	
	
	
	--[[
	if _M.DoorSensors then
		local DoorSensorPart = (_M.MCar:FindFirstChild("MISC") and _M.MCar.MISC:FindFirstChild("DOORSENSOR")) or _M.MCar:FindFirstChild("DOORSENSOR") 
		if DoorSensorPart then
			DoorSensorPart.Touched:Connect(function(Player)
				if _M.DoorState == 0 then return end
				if _M.NudgeClosing then return end
				if Player.Name == "Torso" or Player.Name == "UpperTorso" then
				if _M.DoorSensorHold then
				for _,x in pairs(_M.DoorSensorNoobs) do
					if x == Player.Parent.Name then
						return
					end
				end
				table.insert(_M.DoorSensorNoobs,Player.Parent.Name)
				end
				if _M.DoorState == 2 and _M.FireRecall == false then _M.FrontDoorOpen() end
				end
			end)
			DoorSensorPart.TouchEnded:Connect(function(Player)
				if Player.Name == "Torso" or Player.Name == "UpperTorso" then
					for i,x in pairs(_M.DoorSensorNoobs) do
						if x == Player.Parent.Name then
							table.remove(_M.DoorSensorNoobs,i)
						end
					end
				end
			end)
			game:GetService('Players').PlayerAdded:Connect(function(Plr)
				Plr.CharacterAdded:Connect(function(PlrChr)
					PlrChr:WaitForChild("Humanoid").Died:Connect(function()
					for i,x in pairs(_M.DoorSensorNoobs) do
						if x == Plr.Name then
							table.remove(_M.DoorSensorNoobs,i)
						end
					end
					end)
				end)
			end)
		end
		local DoorSensorPartRear = (_M.MCar:FindFirstChild("MISC") and _M.MCar.MISC:FindFirstChild("DOORSENSORREAR")) or _M.MCar:FindFirstChild("DOORSENSORREAR") 
		if DoorSensorPartRear then
			DoorSensorPartRear.Touched:Connect(function(Player)
				if _M.NudgeClosing then return end
				if Player.Name == "Torso" or Player.Name == "UpperTorso" then
				if _M.DoorSensorHold then
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x == Player.Parent.Name then
						return
					end
				end
				table.insert(_M.RearDoorSensorNoobs,Player.Parent.Name)
				end
				if _M.RearDoorState == 2 then _M.RearDoorOpen() end
				end
			end)
			DoorSensorPartRear.TouchEnded:Connect(function(Player)
				if Player.Name == "Torso" or Player.Name == "UpperTorso" then
					for i,x in pairs(_M.RearDoorSensorNoobs) do
						if x == Player.Parent.Name then
							table.remove(_M.RearDoorSensorNoobs,i)
						end
					end
				end
			end)
			game:GetService('Players').PlayerAdded:Connect(function(Plr)
				Plr.CharacterAdded:Connect(function(PlrChr)
					PlrChr:WaitForChild("Humanoid").Died:Connect(function()
					for i,x in pairs(_M.RearDoorSensorNoobs) do
						if x == Plr.Name then
							table.remove(_M.RearDoorSensorNoobs,i)
						end
					end
					end)
				end)
			end)
		end		
	
	end	
	]]

	-- MAP CAR BUTTONS --
	--local CarButtons = {}
	--for _,x in pairs(_M.MCar:GetChildren()) do table.insert(CarButtons,x) end
	--if _M.MCar:FindFirstChild("CONTROL") then for _,x in pairs(_M.MCar.CONTROL:GetChildren()) do table.insert(CarButtons,x) end end
	
	for _,b in pairs(_M.MCar:GetDescendants()) do
		if b:IsA("Model") then
		if b.Name:sub(1,2) == "BT" and b.Name ~= "BTN" then
			assert(b:FindFirstChild("BTN"),"Missing `BTN` in car button `"..b.Name.."`")
			assert(b.BTN:FindFirstChild("ClickDetector"),"Missing `ClickDetector` in car button `"..b.Name.."`")
			table.insert(_M.ElevatorButtons["CAR"],b)
		
		
		if _M.ButtonBeep and b.Name:sub(1,2) == "BT" and not b:IsA("Part") then
			b.BTN.ClickDetector.MouseClick:Connect(function() _M.MPlatform.Beep:Play() end)
		end
		if b.Name:sub(1,3) == "BTF" then
			b.BTN.ClickDetector.MouseClick:Connect(function() _M.RegisterCall(tonumber(b.Name:sub(4)),0) end)
			for _,x in pairs(b:GetChildren()) do
				if x.Name == "LED" then
					x.BrickColor = BrickColor.new(_M.EButtonColor)
					x.Material = _M.EButtonMaterial
				end
			end
		end
		
		
		if b.Name:sub(1,4) == "BTAL" and string.len(b.Name) == 4 then
				b.BTN.ClickDetector.MouseClick:Connect(_M.DoAlarm)
		end
		if b.Name:sub(1,8) == "BTESTOPI" and string.len(b.Name) == 6 then
				b.BTN.ClickDetector.MouseClick:Connect(_M.StopElevator)
		end
		if b.Name:sub(1,4) == "BTDO" and string.len(b.Name) == 4 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then _M.FrontDoorOpen() end end) 
		end
		if b.Name:sub(1,5) == "BTDOF" and string.len(b.Name) == 5 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then _M.FrontDoorOpen() end end) 
		end
		if b.Name:sub(1,5) == "BTDOR" and string.len(b.Name) == 5  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then _M.RearDoorOpen() end end) 
		end
		if b.Name:sub(1,4) == "BTDC" and string.len(b.Name) == 4  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then 				
				for _,x in pairs(_M.DoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end
				_M.DoorClose(false,true) 
				end 
			end) 
		end
		if b.Name:sub(1,5) == "BTDCF" and string.len(b.Name) == 5  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then 				
				for _,x in pairs(_M.DoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				_M.FrontDoorClose() 
				end 
			end) 
		end
		if b.Name:sub(1,5) == "BTDCR" and string.len(b.Name) == 5 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving then 	
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				_M.RearDoorClose() 
				end 
			end) 
		end		
		if b.Name:sub(1,4) == "BTCC" and string.len(b.Name) == 4 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() 
				if _M.IndependentMode then
					if _M.Moving then
					_M.StopElevator()
					else
						for Index,Data in pairs(_M.ECallQuene) do
							if Data ~= nil then
								_M.SetButton(tonumber(Data:sub(2)),4,0)
							end
						end						
						_M.ECallQuene = {}
					end
				end	
				
			end) 
			end
			
		end
		end
	end
	
	-- SET UP FLOOR CALL BUTTONS --
	
	for _,bf in pairs(_M.MFloor:GetChildren()) do
		--local FloorButtons = {}
		--for _,x in pairs(bf:GetChildren()) do table.insert(FloorButtons,x) end
		--if bf:FindFirstChild("CONTROL") then for _,x in pairs(bf.CONTROL:GetChildren()) do table.insert(FloorButtons,x) end end
		--if bf:FindFirstChild("CONTROLREAR") then for _,x in pairs(bf.CONTROLREAR:GetChildren()) do table.insert(FloorButtons,x) end end
		
		local Flr = tonumber(bf.Name)
		if Flr > _M.ETOPFloor  then _M.ETOPFloor = Flr end
		if Flr < _M.EBOTTOMFloor then _M.EBOTTOMFloor = Flr end
		table.insert(_M.EFloors,Flr)
		for _,b in pairs(bf:GetDescendants()) do
			
			local bf = b.Parent.Name
			if b.Name:sub(1,2) == "BT" and b.Name ~= "BTN" then
				assert(b:FindFirstChild("BTN"),"Missing `BTN` in floor `"..Flr.."` button `"..b.Name.."`")
				assert(b.BTN:FindFirstChild("ClickDetector"),"Missing `ClickDetector` in floor `"..Flr.."` button `"..b.Name.."`")
				table.insert(_M.ElevatorButtons["FLOORS"][Flr], b)
			
			
			
		if b.Name:sub(1,3) == "BTF" then
			b.BTN.ClickDetector.MouseClick:Connect(function() _M.RegisterCall(tonumber(b.Name:sub(4)),0) end)
		end	
		if b.Name:sub(1,4) == "BTAL" and string.len(b.Name) == 4 then
				b.BTN.ClickDetector.MouseClick:Connect(_M.DoAlarm)
		end
		if b.Name:sub(1,6) == "ESTOPI" and string.len(b.Name) == 6 then
				b.BTN.ClickDetector.MouseClick:Connect(_M.StopElevator)
		end
		if b.Name:sub(1,4) == "BTDO" and string.len(b.Name) == 4 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then _M.FrontDoorOpen() end return end)
		end
		if b.Name:sub(1,5) == "BTDOF" and string.len(b.Name) == 5 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then _M.FrontDoorOpen() end return end) 
		end
		if b.Name:sub(1,5) == "BTDOR" and string.len(b.Name) == 5  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then _M.RearDoorOpen() end return end) 
		end
		if b.Name:sub(1,4) == "BTDC" and string.len(b.Name) == 4  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then 				
				for _,x in pairs(_M.DoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end
				_M.DoorClose(false,true) 
			end 
			return
			end) 
		end
		if b.Name:sub(1,5) == "BTDCF" and string.len(b.Name) == 5  then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then 				
				for _,x in pairs(_M.DoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				_M.FrontDoorClose() 
			end 
			return
			end) 
		end
		if b.Name:sub(1,5) == "BTDCR" and string.len(b.Name) == 5 then
			 b.BTN.ClickDetector.MouseClick:Connect(function() if not _M.Moving and _M.Floor == Flr then 	
				for _,x in pairs(_M.RearDoorSensorNoobs) do
					if x ~= nil then
						return
					end
				end 
				_M.RearDoorClose() 
			end 
			return
			end) 
		end		
			
			
			
			
			if b.Name:sub(1,3) == "BTC" and string.len(b.Name) == 3 then
					local DB = false
				b.BTN.ClickDetector.MouseClick:Connect(function()
					if DB then return end
					DB = true
					local Locked = false
					if b.Parent:FindFirstChild("CARDREADER") then 
						if b.Parent.CARDREADER.Trigger.Value == false then
							Locked = true
						end
					end
					if not Locked then
						_M.RegisterCall(Flr,3)
					else
						local IsCalled = false
						for _,Calls in pairs(_M.ECallQuene) do
							if Calls == tostring(Flr.."3") then
								IsCalled = true
							end
						end
						
						if not IsCalled then
							_M.SetButton(Flr,3,1)
							wait(1)
							_M.SetButton(Flr,3,0)
						end
					end
					DB = false
				end)
			end
			if b.Name:sub(1,3) == "BTU" and string.len(b.Name) == 3 then
					local DB = false
				b.BTN.ClickDetector.MouseClick:Connect(function() 
					if DB then return end
					DB = true
					local Locked = false
					if b.Parent:FindFirstChild("CARDREADER") then 
						if b.Parent.CARDREADER.Trigger.Value == false then
							Locked = true
						end
					end
					if not Locked then
						_M.RegisterCall(Flr,1)

					else
						local IsCalled = false
						for _,Calls in pairs(_M.ECallQuene) do
							if Calls == tostring(Flr.."1") then
								IsCalled = true
							end
						end
						
						if not IsCalled then
							_M.SetButton(Flr,1,1)
							wait(1)
							_M.SetButton(Flr,1,0)
						end
					end
					DB = false
				end)
			end
			if b.Name:sub(1,3) == "BTD" and  string.len(b.Name) == 3 then
					local DB = false
				b.BTN.ClickDetector.MouseClick:Connect(function() 
					if DB then return end
					DB = true
					local Locked = false
					if b.Parent:FindFirstChild("CARDREADER") then 
						if b.Parent.CARDREADER.Trigger.Value == false then
							Locked = true
						end
					end					
					if not Locked then
						_M.RegisterCall(Flr,2)
					else
						local IsCalled = false
						for _,Calls in pairs(_M.ECallQuene) do
							if Calls == tostring(Flr.."2") then
								IsCalled = true
							end
						end
						
						if not IsCalled then
							_M.SetButton(Flr,2,1)
							wait(1)
							_M.SetButton(Flr,2,0)
						end
					end
					DB = false
				end)
			end

				for _,x in pairs(b:GetChildren()) do
					if x.Name == "LED" then
						x.BrickColor = BrickColor.new(_M.EButtonColor)
						x.Material = _M.EButtonMaterial
					end
				end
			end			
			
			
			
		end
	end	
	
	
	
	
	-- SENSORBAR FIX --
	for _,E in pairs(_M.MCar.DOORS:GetChildren()) do
		if E:FindFirstChild("SENSORBAR") then
			for _,x in pairs(E.SENSORBAR:GetChildren()) do
				if x.Name == "LED" then
					if E.Name:sub(1,1) == "R" then
						table.insert(_M.RearDoorSensorBars,x)
					else
						table.insert(_M.DoorSensorBars,x)
					end
				end
			end
		end
	end
	

			
	-- ERRORMODULE V2 --		
			
	--[[		
	-- REGEN SYSTEM --
	if _M.ERegen then
	-- Start clean, Not dirty --
		local ETDB = false
		local LFLR = tonumber( _M.Floor)
		_M.Moving.Changed:Connect(function() 
			if _M.Moving == true and ETDB == false then
				TekBug("ErrorModule started")
				_M.MoveTime = 0
				while _M.Moving do
					if LFLR == _M.Floor then
						TekBug("Still at Floor "..LFLR.." Timer is ".._M.MoveTime)
						_M.MoveTime = _M.MoveTime + 1
					else
						TekBug("Reached floor without problems, Resetting timer")
						LFLR = tonumber( _M.Floor)
						_M.MoveTime = 0
					end
					wait(1)
				end
				TekBug("ErrorModule stopped as we have arrived the floor.")
			end
		end)
	end
	local Partz = {"Attachment0","BodyPosition","BodyGyro","BodyVelocity","MotorRun","MotorStart","MotorStop","Start","Stop","Run","Engine","Attachment","DoorMotor"}
	for _,x in pairs(Partz) do
		print(x)
		if _M.MPlatform:FindFirstChild(x) then 
			_M.MPlatform[x]:Destroy() 
		end
		if _M.MElevator:FindFirstChild("Attachment") then
			if _M.MElevator.Attachment:FindFirstChild(x) then
				_M.MElevator.Attachment[x]:Destroy()
			end
		end
	end
	--]]
	


	
	
	-- CHECK IF LOGO IS GONE OR DECALS THAT ARE BLACKLISTED AND REQUIRES CREDIT --
	
	local function GetPart(n)
		for _,PX in pairs(_M.MCar:GetDescendants()) do
			if PX.Name == n then
				return PX
			end
		end
	end
	
	
	local RequireCredits = true
	
	for _,x in pairs(_M.MCar:GetDescendants()) do
		
		if x.ClassName == "Decal" then	
			for _,Blocked in pairs(_M.BlacklistedImages) do
				if x.Texture == "rbxassetid://"..Blocked or x.Texture == "https://www.roblox.com/asset/?id="..Blocked then
					RequireCredits = true
					break
				end 
			end	


			if 			
				x.Texture == "rbxassetid://1202864746" or 
				x.Texture == "https://www.roblox.com/asset/?id=1202864746" or
				x.Texture == "rbxassetid://509795355" or
				x.Texture == "https://www.roblox.com/asset/?id=509795355" or
				x.Texture == "rbxassetid://1894250210" or
				x.Texture == "https://www.roblox.com/asset/?id=1894250210"
			then
			
				if x.Parent.ClassName == "Part" then
					x.Parent.Material = "SmoothPlastic"
					x.Parent.BrickColor = BrickColor.new("Storm blue")
				end
				x.Texture = "rbxassetid://2803765369"
				RequireCredits = false
				--break
			end
		end
		if x.ClassName == "ImageButton" or  x.ClassName == "ImageLabel" then
			if x.Image == "rbxassetid://1202864746" or x.Image == "https://www.roblox.com/asset/?id=1202864746" then
				x.Image = "rbxassetid://2803765369"
				RequireCredits = false
				--break
			end
		end
		if x.ClassName == "TextLabel" then
			local Text = string.lower(x.Text)
			if string.find(Text,"teknikk lifts") or string.find(Text,"teknikk") then
				RequireCredits = false
				--break
			end
		end
		

	end
	
	local LB = GetPart("LOGO")
	
	if LB then
		for _,x in pairs(LB:GetChildren()) do
			if x then
				x:Destroy()
			end
		end
		local LDC = Instance.new("Decal")
		LDC.Texture = "rbxassetid://2803765369"
		LDC.Face = "Back"
		LDC.Parent = LB
		LDC.Transparency = 0.4
		LB.Material = Enum.Material.Neon
		LB.BrickColor = BrickColor.new("Storm blue")
		
		--[[
		-- CHECK IF PART IS HIDDEN !!!!
		local RayCheck = Ray.new(
			Vector3.new(LB.Position.X,LB.Position.Y,LB.Position.Z),
			Vector3.new(0,0,1))
	
		if workspace:FindPartOnRay(RayCheck) ~= nil then
			RequireCredits = true
			print("LOGO OBSTRUCTED")
		end
		--]]
	end
	

	
	
	if RequireCredits then
		require(ASSETID)("CREDITS")
	end	
	
	
	
	

	
	TekBug("Fixing move engines")
	if _M.EngineType == 4 then
		local BP =  Instance.new("BodyPosition")
		local BG =  Instance.new("BodyGyro")
		BP.Parent = _M.MPlatform
		BP.Position = _M.MPlatform.Position
		BP.D = 250
		BP.P = 5000
		BP.MaxForce = Vector3.new(4000, 500000, 4000)
		BG.Parent = _M.MPlatform
		BG.D = 500
		BG.P = 3000
		BG.MaxTorque = Vector3.new(5000000,0,5000000)
		BP.Name = "Engine"
	end

	if _M.EngineType == 3  then
		if _M.MElevator:FindFirstChild("Attachment") == nil then error("Teknikk Lifts - Polar / Can not use CFrame mode without Attachment part") end
		if _M.MPlatform:FindFirstChild("Engine") == nil then
			local ElevatorEngine = _M.DoWeld(_M.MElevator.Attachment,_M.MPlatform)
			ElevatorEngine.Name = "Engine"
			ElevatorEngine.Parent = _M.MPlatform
		end
	end
	if _M.EngineType == 2 then
		if _M.MElevator:FindFirstChild("Attachment") == nil then error("Teknikk Lifts - Polar / Can not use Prismatic mode without Attachment part") end
		if _M.MPlatform:FindFirstChild("Engine") == nil then
			_M.MPlatform.Anchored = true
			local A0 = _M.MPlatform:FindFirstChild("Attachment") or Instance.new("Attachment")
			local A1 = _M.MElevator.Attachment:FindFirstChild("Attachment") or Instance.new("Attachment")
			local PC = _M.MPlatform:FindFirstChild("Engine") or Instance.new("PrismaticConstraint")			
			local PS = _M.MPlatform:FindFirstChild("Servo") or Instance.new("PrismaticConstraint")
			A0.Parent = _M.MPlatform
			A0.Position = Vector3.new(0,-0.5,0)
			A0.Rotation = Vector3.new(0,0,-90)
			A0.Axis = Vector3.new(0,-1,0)
			A0.SecondaryAxis = Vector3.new(1,0,0)
			A1.Parent = _M.MElevator.Attachment
			A1.Position = Vector3.new(0,0.1,0)
			A1.Rotation = Vector3.new(0,0,-90)
			A1.Axis = Vector3.new(0,-1,0)
			A1.SecondaryAxis = Vector3.new(1,0,0)
			PC.Parent = _M.MPlatform
			PC.ActuatorType = "Motor"
			PC.MotorMaxForce = 999999
			PC.Enabled = false
			PC.Attachment0 = A0
			PC.Attachment1 = A1	
			PC.Visible = false
			PC.Name = "Engine"
			PS.Parent = _M.MPlatform
			PS.ActuatorType = "Servo"
			PS.ServoMaxForce = 999999
			PS.Enabled = true
			PS.Attachment0 = A0
			PS.Attachment1 = A1	
			PS.Visible = false
			PS.Speed = 1
			PS.TargetPosition = _M.MPlatform.Position.Y-0.725
			PS.Name = "Servo"
			_M.MPlatform.Anchored = false
		end
	end
	if _M.EngineType == 1 then

		local BP = _M.MPlatform:FindFirstChild("BodyPosition") or Instance.new("BodyPosition")
		local BG = _M.MPlatform:FindFirstChild("BodyGyro") or Instance.new("BodyGyro")
		local BV = _M.MPlatform:FindFirstChild("Engine")or Instance.new("BodyVelocity")
		BP.Parent = _M.MPlatform
		BP.Position = _M.MPlatform.Position
		BP.D = 500
		BP.P = 100000
		BP.MaxForce = Vector3.new(10000000, 1000000, 10000000)
		BG.Parent = _M.MPlatform
		BG.D = 500
		BG.P = 100000
		BG.MaxTorque = Vector3.new(5000000,0,5000000)
		BV.Parent = _M.MPlatform
		BV.MaxForce = Vector3.new(0, 0, 0)
		BV.P = 100000
		BV.Velocity = Vector3.new(0,0,0)		
		BV.Name = "Engine"
		_M.MLevel.Anchored = true
	end
	
	-- SEND SOME API CALLS FOR INDICATORS/SCRIPTS TO UPDATE --

	_M.SendAPI("EDIR".._M.Direction)
	_M.SendAPI({["RESPONSE"] = "DIRECTION", ["DATA"] = _M.Direction})
	_M.SendAPI("EFLR".._M.Floor)
	_M.SendAPI({["RESPONSE"] = "FLOOR", ["DATA"] = _M.Floor})
	_M.SendAPI("EMVF")
	_M.SendAPI({["RESPONSE"] = "MOTORSTATE", ["DATA"] = false})



	-- END THE STARTUP SEQUENCE --
	_M.SelfTest = false
	
	
	wait(2)
	-- CHECK FOR GUI --
	
	local SSS = game:GetService("ServerScriptService")
	if SSS:FindFirstChild("PControl") then
		SSS.PControl.Event:Fire({["REQUEST"] = "PCONTROLADD", ["DATA"] = {["ELEVATOR"] = _M.MElevator, ["ID"] = _M.MData.ElevatorID.Value,} })
	end
	
	_M.ReceiveAPI({["REQUEST"]="ELEVATORSTATE"})
	
	-- BEGIN ELEVATORWATCHER / REGEN SYSTEM --
	_M.ElevatorWatch()
end
function _M.B64(data)
	b ='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r, b ='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end
function IsFoot(z)
	local Partz = {"Left Leg","Right Leg", "LeftFoot", "RightFoot" }
	for _,x in pairs(Partz) do
		if x == z.Name then return true end
	end
	return false
end
function _M.ElevatorWatch()

	if not _M.EWatchRunning and _M.ERegen and not _M.EngineTyoe == 4 then
		if _M.MCar:FindFirstChild("TopRoof") then
			_M.MCar.TopRoof.Touched:Connect(function(x)
				print("Tocuhed :D")
				if x.Parent:FindFirstChild("Humanoid") then
					if IsFoot(x) then
						x.Parent.HumanoidRootPart.CFrame = CFrame.new(_M.MPlatform.Position)
					end
				end
			end)
		end
		print("Starting Teknikk Lifts - Elevator Watch V1")
		_M.EWatchRunning = true
	
		local SPX = _M.MPlatform.Position.X
		local SPZ = _M.MPlatform.Position.Z
		
		local SRX = _M.MPlatform.Rotation.X
		local SRZ = _M.MPlatform.Rotation.Z
		local SRY = _M.MPlatform.Rotation.Y
	--	coroutine.resume(coroutine.create(function()
			while true do
				wait(2)
				if _M.MoveTime > _M.MoveTimeout then break end
				if _M.MElevator:FindFirstChild("Car") == nil then break end	
				if _M.MElevator.Car:FindFirstChild("Platform") == nil then break end
				if 
					math.abs(_M.MPlatform.Position.X - SPX) > _M.ERegenDistance or 
					math.abs(_M.MPlatform.Position.Z - SPZ) > _M.ERegenDistance or 
					math.abs(_M.MPlatform.Rotation.X - SRX) > _M.ERegenDistance or
					math.abs(_M.MPlatform.Rotation.Z - SRZ) > _M.ERegenDistance or
					math.abs(_M.MPlatform.Rotation.Y - SRY) > _M.ERegenDistance
					then  break end
			end
			print(" !! ELEVATOR HAS LEFT THE SAFE SPOT, REGENERATING !!")
			local Msg = Instance.new("Hint",game.workspace)
			Msg.Text = "Teknikk Lifts - Polar | Regenerating Cab"
			if _M.MElevator:FindFirstChild("Car") then _M.MElevator.Car:Destroy() end
			_M.MElevator.Floors:Destroy()
			local NewElev = _M.MData.CarCopy.Value:Clone()
			local NewFlr = _M.MData.FloorCopy.Value:Clone()
			NewFlr.Parent = _M.MElevator
			NewFlr:MakeJoints()
			NewElev.Parent = _M.MElevator
			NewElev:MakeJoints()
			_M.EWatchRunning = false
			_M.MData.WeldDone.Value = false
			wait(1)
			Msg:Destroy()
			_M.Moving = false
			_M.Script.Disabled = true
	--	end))
		
	end
end

return _M
