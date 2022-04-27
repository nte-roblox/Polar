script.Parent = nil 
script.Archivable = false
local _M = {}

_M.Script = nil
_M.Model = nil
_M.Elevators = {}
_M.API = nil
_M.SelfTest = false
function _M.StartUp(scriptsource)
	local timer = 5000
	for i=timer, 0, -1 do
	wait(0.1)
	end
	
	print(scriptsource)
	if _M.Script == nil then _M.Script = scriptsource end
	local isUntouched = true
	if _M.Script.Name == "Teknikk Lifts MultiBay Controller" then
		isUntouched = true
	end
	if isUntouched == false then
		require(558028873)("TAMPER")
		_M.Script.Disabled = true		
		error("Teknikk Lifts: Tampering was detected, Did you change the script name or the copyright message in the script?")	
	end
	_M.Model = _M.Script.Parent
	print( _M.Script.Parent)
	wait(2)
	_M.SelfTest = true
	
	
	if _M.Model:FindFirstChild("API") == nil then
		_M.API = Instance.new("BindableEvent",_M.Model)
		_M.API.Name = "API"
	else
		_M.API = _M.Model.API
	end
	
	_M.API.Event:Connect(function(CMD) 
		if type(CMD) == "table" and CMD["REQUEST"] then
			if CMD["REQUEST"] == "MULTIBAYREGISTERCALL" then
				_M.CallRequest(tonumber(CMD["DATA"]["TYPE"]),tonumber(CMD["DATA"]["FLOOR"]))
			end
		end
	end)
	
	
	-- GET ELEVATORS AND REGISTER API --
	for _,Elevator in pairs(_M.Model.ELEVATORS:GetChildren()) do
		_M.Elevators[Elevator] = {}
		Elevator.API.Event:Connect(function(APIResponse) 
			if type(APIResponse) == "table" then
				if APIResponse["RESPONSE"] == "ELEVATORSTATE" then
					_M.Elevators[Elevator] = APIResponse["DATA"]
				end
			end
		end)
		Elevator.API:Fire({["REQUEST"] = "ELEVATORSTATE"})
	end
	
	-- GET CALLBUTTONS --
	for _,Floors in pairs(_M.Model.CALLBUTTONS:GetChildren()) do
		for _,CallStations in pairs(Floors:GetChildren()) do
			for _,CallButton in pairs(CallStations.CONTROL:GetChildren()) do
				CallButton.BTN.ClickDetector.MouseClick:Connect(function()
					_M.CallRequest((CallButton.Name == "BTU" and 1 or CallButton.Name == "BTD" and 2 or CallButton.Name == "BTN" and 0), tonumber(Floors.Name))
				end)
			end
		end
	end
		
	_M.SelfTest = false
end


function _M.CallRequest(Type, Floor)
	-- UPDATE ALL DATA FOR ALL ELEVATORS AND CHECK IF IT'S UP TO DATE AND WITHIN THE TIMELIMIT --
	
	
	for Elevator,_ in pairs(_M.Elevators) do
		local CurrentTimestamp = os.time()
		local OldTimestamp = _M.Elevators[Elevator]["TIMESTAMP"]
		local Timer = 0
		Elevator.API:Fire({["REQUEST"] = "ELEVATORSTATE"})
		repeat wait() Timer = Timer + 0.1 until math.abs(_M.Elevators[Elevator]["TIMESTAMP"] - CurrentTimestamp) < 3 or Timer > 3
		if Timer > 3 then
			_M.Elevators[Elevator]["VALID"] = false
		end
		
		print(_M.Elevators[Elevator]["VALID"])
		--print("Took "..math.abs(_M.Elevators[Elevator]["TIMESTAMP"] - CurrentTimestamp).." seconds to get new data, Old data was "..math.abs(_M.Elevators[Elevator]["TIMESTAMP"] - OldTimestamp).." seconds old")
		
	end	
	--print("Cleared Timestamp check")

	-- CHECK FOR ELEVATORS AT CURRENT FLOOR AND STATE --
	-- 1 == DOOR OPEN AND CORRECT DIRECTION, 2 = DOOR CLOSED BUT IDLE --
	print("CHECKING FOR ELEVATORS IDLE AT FLOOR")
	for i=1,2 do
		for Elevator,Data in pairs(_M.Elevators) do
			if Data["INDEPENDENTMODE"] == false and Data["FIRERECALL"] == false and Data["VALID"] then
			if Data["FLOOR"] == Floor and Data["MOTORSTATE"] == false then
				if Data["DIRECTION"] == (i == 1 and (Type == 0 and Data["DIRECTION"] or Type) or i == 2 and 0) and (i==1 and Data["DOORSTATE"] ~= 0 or  i==2 and Data["DOORSTATE"] == 0) then
					if i == 1 then
						Elevator.API:Fire({["REQUEST"] = "REGISTERCALL",["DATA"] = {["TYPE"] = 0, ["FLOOR"] = Floor,}})
						_M.API:Fire({["RESPONSE"] = "MULTIBAYACCEPT",["DATA"] = {["LOCATION"] = "CURRENTFLOOR", ["ELEVATOR"] = Elevator}})
						return
					end
					if i == 2 then
						Elevator.API:Fire({["REQUEST"] = "REGISTERCALL",["DATA"] = {["TYPE"] = Type, ["FLOOR"] = Floor,}})
						_M.API:Fire({["RESPONSE"] = "MULTIBAYACCEPT",["DATA"] = {["LOCATION"] = "CURRENTFLOOR", ["ELEVATOR"] = Elevator}})
						return
					end
				end
			end
			end
		end
	end

	
	
	

	
	
	
	-- CHECK IF THERE IS NEARBY ELEVATORS GOING TO X DIRECTION 
	
	--  IF THERE IS A ELEVATOR GOING X DIRECTION AND THE CALL EXIST, IGNORE THE NEW CALL
	print("CHECKING FOR ELEVATORS GOING TO THE DIRECTION TO FLOOR")	
	local AppropriateElevators = {}
	
	for Elevator,Data in pairs(_M.Elevators) do
		print(Data["VALID"])
		if Data["INDEPENDENTMODE"] == false and Data["FIRERECALL"] == false and Data["VALID"]  then
		if Data["FLOOR"] ~= Floor and Data["DIRECTION"] == (Type == 0 and Data["DIRECTION"] or Type) then
			table.insert(AppropriateElevators, {["ELEVATOR"] = Elevator, ["DATA"] = Data})
		end
		end
	end
	local ClosestElevator = {}
	if #AppropriateElevators ~= 0 then
		for _,Data in pairs(AppropriateElevators) do
			if (Type == 0 and Data["DATA"]["DIRECTION"] or Type) == 1 then
				if Data["DATA"]["FLOOR"] < Floor and (#ClosestElevator == 1 and ClosestElevator[1]["DATA"]["FLOOR"] < Data["DATA"]["FLOOR"] or true) then
					ClosestElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				end
			end
			if (Type == 0 and Data["DATA"]["DIRECTION"] or Type) == 2 then
				if Data["DATA"]["FLOOR"] > Floor and (#ClosestElevator == 1 and ClosestElevator[1]["DATA"]["FLOOR"] > Data["DATA"]["FLOOR"] or true) then
					ClosestElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				end
			end
		end
		if ClosestElevator[1] ~= nil then
			ClosestElevator[1]["ELEVATOR"].API:Fire({["REQUEST"] = "REGISTERCALL",["DATA"] = {["TYPE"] = Type, ["FLOOR"] = Floor,}})
			_M.API:Fire({["RESPONSE"] = "MULTIBAYACCEPT",["DATA"] = {["LOCATION"] = "DIFFERENTFLOOR", ["ELEVATOR"] = ClosestElevator[1]["ELEVATOR"]}})
			return
		end
	end
	
		
	-- NO ELEVATOR GOING THAT DIRECTION, LETS CHECK FOR IDLE ELEVATORS --
	print("CHECKING FOR ELEVATORS IDLE AT OTHER FLOOR")
	local IdleAppropriateElevators = {}
	local AlternativeAppropriateElevators = {}	
	
	for Elevator,Data in pairs(_M.Elevators) do
		if Data["INDEPENDENTMODE"] == false and Data["FIRERECALL"] == false and Data["VALID"] then
		if Data["DIRECTION"] == 0  then
			Data["DISTANCE"] = math.abs(Data["FLOOR"] - Floor)
			print(Data["DISTANCE"])
			table.insert(IdleAppropriateElevators, {["ELEVATOR"] = Elevator, ["DATA"] = Data})
			print("IDLE: "..Elevator.Name)
		end
		--if Data["DIRECTION"] ~= 0 then
			Data["DISTANCE"] = math.abs(Data["FLOOR"] - Floor)
			table.insert(AlternativeAppropriateElevators, {["ELEVATOR"] = Elevator, ["DATA"] = Data})
			print("ALTERNATIVE: "..Elevator.Name)
		--end
		end
	end	


	-- LETS SEE IF WE CAN GET A ELEVATOR THAT IS LAZY... --
	local ClosestIdleElevator = {}
	print("CHECKING FOR ANY IDLE ELEVATORS")
	print(#IdleAppropriateElevators)

	if #IdleAppropriateElevators ~= 0 then
	print("WE GOT IDLE ELEVATORS")
		for _,Data in pairs(IdleAppropriateElevators) do
			if #ClosestIdleElevator == 0 then
				ClosestIdleElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				print( "USING DEFAULT THE FIRST ONE")
			end
			if math.abs(Data["DATA"]["FLOOR"] - Floor) < ClosestIdleElevator[1]["DATA"]["DISTANCE"] then
				ClosestIdleElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				print("FOUND A BETTER ONE")
			end
		end
		print("DONE CHECKING")
		if #ClosestIdleElevator ~= 0 then
			print("WE GOT A ELEVATOR WE CAN USE, CALLING")
			print("SELECTED: "..ClosestIdleElevator[1]["ELEVATOR"].Name)
			ClosestIdleElevator[1]["ELEVATOR"].API:Fire({["REQUEST"] = "REGISTERCALL",["DATA"] = {["TYPE"] = Type, ["FLOOR"] = Floor,}})
			_M.API:Fire({["RESPONSE"] = "MULTIBAYACCEPT",["DATA"] = { ["LOCATION"] = "DIFFERENTFLOOR", ["ELEVATOR"] = ClosestIdleElevator[1]["ELEVATOR"]}})
			return			
		end
	end
	local ClosestAltElevator = {}
	if #AlternativeAppropriateElevators ~= 0 then
	print("WE GOT IDLE ELEVATORS")
		for _,Data in pairs(AlternativeAppropriateElevators) do
			if #ClosestAltElevator == 0 then
				ClosestAltElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				print( "USING DEFAULT THE FIRST ONE")
			end
			if math.abs(Data["DATA"]["FLOOR"] - Floor) < ClosestAltElevator[1]["DATA"]["DISTANCE"] then
				ClosestAltElevator[1] = {["ELEVATOR"] = Data["ELEVATOR"], ["DATA"] = Data["DATA"]}
				print("FOUND A BETTER ONE")
			end
		end
		print("DONE CHECKING")
		if #ClosestAltElevator ~= 0 then
			print("WE GOT A ELEVATOR WE CAN USE, CALLING")
			print("SELECTED: "..ClosestAltElevator[1]["ELEVATOR"].Name)
			ClosestAltElevator[1]["ELEVATOR"].API:Fire({["REQUEST"] = "REGISTERCALL",["DATA"] = {["TYPE"] = Type, ["FLOOR"] = Floor,}})
			_M.API:Fire({["RESPONSE"] = "MULTIBAYACCEPT",["DATA"] = {["LOCATION"] = "DIFFERENTFLOOR", ["ELEVATOR"] = ClosestAltElevator[1]}})
			return			
		end
	end
	
	print("If I see this text, I'll hate myself forever")
	_M.API:Fire({["RESPONSE"] = "MULTIBAYERROR"})
	

end

return _M
