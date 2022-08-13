/*
	[Header]
*/
local Meiware = {
	build_info = "2022-08-13 @ 17:18 UTC",

	color = Color(0, 255, 0),
	menu_key = KEY_INSERT,
	aimtrig_key = MOUSE_5,
	aimbot_fov = 6,
	fov = 100,
	freecamspeed = 4,

	aim = {
		aimbot = {"aimbot", true},
		ignoreteam = {"ignore team check?", true},
		ignorefov = {"ignore fov check?", false},
		ignorenpc = {"ignore NPC check?", false},
		triggerbot = {"triggerbot", true},
		autoreload = {"auto reload", true}
	},
	visuals = {
		wallhack = {"wallhack", true},
		esp = {"ESP", true},
		crosshair = {"crosshair", true},
		freecam = {"freecam", false},
		fovoverride = {"FOV override", true}
	},
	movement = {
		autohop = {"auto hop", true},
		autostrafe = {"auto strafe", true}
	},

	hitboxlist = {"head"},
	entitylist = {},

	hitboxes = {
		["head"] = 0,	
		["L arm"] = 1,
		["L forearm"] = 2,
		["L hand"] = 3,
		["R arm"] = 4,
		["R forearm"] = 5,
		["R hand"] = 6,
		["L thigh"] = 7,
		["L calf"] = 8,
		["L foot"] = 9,
		["L toe"] = 10,
		["R thigh"] = 11,
		["R calf"] = 12,
		["R foot"] = 13,
		["R toe"] = 14,
		["pelvis"] = 15,
		["spine"] = 16
	},

	frame = nil,

	false_ang = EyeAngles(),
	false_vec = EyePos(),

	target = nil,
	target_vec = Vector(0, 0, 0),
	target_ang = Angle(0, 0, 0),
	target_fov = 360,

	firing = false,
	attack_override = false,
	reloading = false,

	curtime = 0,

	["old render.Capture"] = render.Capture,
	["old render.CapturePixels"] = render.CapturePixels
}

surface.SetFont("Default")

render.Capture = function(captureData)
	Meiware.frame:SetVisible(false)
	Meiware.Terminate()

	timer.Simple(1, function() Meiware.Initiate() end)

	return Meiware["old render.Capture"](captureData)
end

render.CapturePixels = function()
	Meiware.frame:SetVisible(false)
	Meiware.Terminate()

	timer.Simple(1, function() Meiware.Initiate() end)

	return Meiware["old render.CapturePixels"]
end

function Meiware.Normalize(ang)
	while ang.p > 180 do
		ang.p = ang.p - 360
	end

	while ang.p < -180 do
		ang.p = ang.p + 360
	end

	while ang.y > 180 do
		ang.y = ang.y - 360
	end

	while ang.y < -180 do
		ang.y = ang.y + 360
	end

	while ang.r > 180 do
		ang.r = ang.r - 360
	end

	while ang.r < -180 do
		ang.r = ang.r + 360
	end
end

function Meiware.Clamp(ang)
	if ang.p > 89 then
		ang.p = 89
	elseif ang.p < -89 then
		ang.p = -89
	end
end

function Meiware.IsValidTarget(ent)
	if !IsValid(ent) then return false end
	if ent:IsEffectActive(EF_NODRAW) or ent:GetRenderMode() == RENDERMODE_NONE or ent:GetRenderMode() == RENDERMODE_TRANSCOLOR or ent:GetColor().a == 0 then return false end
	if Meiware.aim.ignorenpc[2] and ent:IsNPC() then return true end

	return ent != LocalPlayer() and ent:IsPlayer() and ent:Alive() and ent:Team() != TEAM_SPECTATOR and !ent:IsDormant() and (Meiware.aim.ignoreteam[2] or ent:Team() != LocalPlayer():Team())
end

/*
	[aim]
*/
function Meiware.IsEntVisibleFromVec(ent, vec)
	local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = LocalPlayer(), start = LocalPlayer():EyePos(), endpos = vec})

	return trace.Entity == ent
end

function Meiware.CanFire()
	if !IsValid(LocalPlayer():GetActiveWeapon()) then return false end

	return LocalPlayer():GetActiveWeapon():Clip1() > 0 and LocalPlayer():GetActiveWeapon():GetActivity() != ACT_RELOAD and LocalPlayer():GetActiveWeapon():GetNextPrimaryFire() < Meiware.curtime
end

function Meiware.MultiPoint(ent, hitbox)
	if !isnumber(ent:GetHitBoxBone(hitbox, 0)) then return ent:WorldSpaceCenter() + Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-1, 1)) end

	local vec, ang = ent:GetBonePosition(ent:GetHitBoxBone(hitbox, 0))
	local min, max = ent:GetHitBoxBounds(hitbox, 0)
	local offset = Vector(math.Rand(min.x, max.x), math.Rand(min.y, max.y), math.Rand(min.z, max.z))

	offset:Rotate(ang)

	return vec + offset
end

function Meiware.Attack(cmd, bool, caller)
	if bool and caller == "aimbot" then
		Meiware.attack_override = true
	end

	if !bool and caller == "aimbot" then
		Meiware.attack_override = false
	end

	if caller == "triggerbot" and Meiware.attack_override then return end

	if bool then
		if Meiware.firing then
			cmd:AddKey(IN_ATTACK)
		else
			cmd:RemoveKey(IN_ATTACK)
		end

		Meiware.firing = !Meiware.firing
	else
		if Meiware.firing then
			cmd:RemoveKey(IN_ATTACK)

			Meiware.firing = false
		end
	end
end

function Meiware.InvertColor(col)
	return Color(255 - col.r, 255 - col.g, 255 - col.b)
end

function Meiware.CurTimeFix()
	if !IsFirstTimePredicted() then return end

	Meiware.curtime = CurTime() + engine.TickInterval()
end

function Meiware.TargetFinder(cmd)
	if !Meiware.aim.aimbot[2] then return end

	local closest_target = nil
	local closest_target_vec = Vector(0, 0, 0)
	local closest_target_ang = Angle(0, 0, 0)
	local closest_target_fov = 360

	for k, v in pairs(ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			local hitbox = Meiware.hitboxes[table.Random(Meiware.hitboxlist)]
			local vec = Meiware.MultiPoint(v, hitbox)

			if Meiware.IsEntVisibleFromVec(v, vec) then
				local ang = (vec - LocalPlayer():EyePos()):Angle()

				Meiware.Normalize(ang)
				Meiware.Clamp(ang)

				local fov = math.abs(math.NormalizeAngle(Meiware.false_ang.y - ang.y)) + math.abs(math.NormalizeAngle(Meiware.false_ang.p - ang.p))

				if fov < closest_target_fov then
					closest_target = v
					closest_target_vec = vec
					closest_target_ang = ang
					closest_target_fov = fov
				end
			end
		end
	end

	Meiware.target = closest_target
	Meiware.target_vec = closest_target_vec
	Meiware.target_ang = closest_target_ang
	Meiware.target_fov = closest_target_fov
end

function Meiware.Aimbot(cmd)
	if !Meiware.aim.aimbot[2] then return end

	if Meiware.IsValidTarget(Meiware.target) and Meiware.CanFire() and !input.IsMouseDown(MOUSE_LEFT) and (Meiware.aim.ignorefov[2] or (input.IsButtonDown(Meiware.aimtrig_key) and Meiware.target_fov <= Meiware.aimbot_fov)) then
		cmd:SetViewAngles(Meiware.target_ang)

		Meiware.Attack(cmd, true, "aimbot")
	else
		cmd:SetViewAngles(Meiware.false_ang)

		Meiware.Attack(cmd, false, "aimbot")
	end
end

function Meiware.Triggerbot(cmd)
	if !Meiware.aim.triggerbot[2] then return end

	local trace = util.TraceLine({mask = MASK_SHOT, start = LocalPlayer():EyePos(), endpos = LocalPlayer():EyePos() + cmd:GetViewAngles():Forward() * 32768, filter = LocalPlayer()})

	if Meiware.IsValidTarget(trace.Entity) and Meiware.CanFire() and (Meiware.aim.ignorefov[2] or input.IsButtonDown(Meiware.aimtrig_key)) then
		Meiware.Attack(cmd, true, "triggerbot")
	else
		Meiware.Attack(cmd, false, "triggerbot")
	end
end

function Meiware.MovementFix(cmd)
	if Meiware.aim.aimbot[2] then
		local temp_false_ang = Meiware.false_ang + Angle(cmd:GetMouseY() * GetConVar("m_pitch"):GetFloat(), -cmd:GetMouseX() * GetConVar("m_yaw"):GetFloat(), 0)

		Meiware.Normalize(temp_false_ang)
		Meiware.Clamp(temp_false_ang)

		Meiware.false_ang = temp_false_ang

		local vec = Vector(cmd:GetForwardMove(), cmd:GetSideMove(), 0)
		local vel = math.sqrt(vec.x * vec.x + vec.y * vec.y)
		local mang = vec:Angle()
		local yaw = cmd:GetViewAngles().y - Meiware.false_ang.y + mang.y

		if ((cmd:GetViewAngles().p + 90) % 360) > 180 then
			yaw = 180 - yaw
		end

		yaw = ((yaw + 180) % 360) - 180

		cmd:SetForwardMove(math.cos(math.rad(yaw)) * vel)
		cmd:SetSideMove(math.sin(math.rad(yaw)) * vel)
	else
		Meiware.false_ang = EyeAngles()
	end
end

function Meiware.Freecam(cmd)
	if Meiware.visuals.freecam[2] then
		cmd:ClearMovement()

		local multiplier = 1

		if cmd:KeyDown(IN_SPEED) then
			multiplier = 2
		end

		if cmd:KeyDown(IN_FORWARD) then
			Meiware.false_vec = Meiware.false_vec + EyeAngles():Forward() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_BACK) then
			Meiware.false_vec = Meiware.false_vec + EyeAngles():Forward() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVELEFT) then
			Meiware.false_vec = Meiware.false_vec + EyeAngles():Right() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVERIGHT) then
			Meiware.false_vec = Meiware.false_vec + EyeAngles():Right() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_JUMP) then
			Meiware.false_vec = Meiware.false_vec + Angle(0, 0, 0):Up() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_DUCK) then
			Meiware.false_vec = Meiware.false_vec + Angle(0, 0, 0):Up() * (-Meiware.freecamspeed * multiplier)
		end
	else
		Meiware.false_vec = EyePos()
	end
end

function Meiware.AutoReload(cmd)
	if Meiware.aim.autoreload[2] and IsValid(LocalPlayer():GetActiveWeapon()) then
		if LocalPlayer():GetActiveWeapon().Primary then
			if LocalPlayer():GetActiveWeapon():Clip1() == 0 and LocalPlayer():GetActiveWeapon():GetMaxClip1() > 0 then
				cmd:AddKey(IN_RELOAD)

				Meiware.reloading = true
			else
				if Meiware.reloading then
					cmd:RemoveKey(IN_RELOAD)

					Meiware.reloading = false
				end
			end
		else
			if Meiware.reloading then
				cmd:RemoveKey(IN_RELOAD)

				Meiware.reloading = false
			end
		end
	else
		if Meiware.reloading then
			cmd:RemoveKey(IN_RELOAD)

			Meiware.reloading = false
		end
	end
end

/*
	[visuals]
*/
function Meiware.Wallhack()
	if !Meiware.visuals.wallhack[2] then return end

	cam.Start3D()
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.ClearStencil()

	render.SetStencilEnable(true)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilZFailOperation(STENCIL_REPLACE)

	for k, v in pairs(ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			if IsValid(v:GetActiveWeapon()) then
				v:GetActiveWeapon():DrawModel()
			end
		end
	end

	local invertedcol = Meiware.InvertColor(Meiware.color)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ClearBuffersObeyStencil(invertedcol.r, invertedcol.g, invertedcol.b, 255, false)
	render.SetStencilEnable(false)

	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.ClearStencil()

	render.SetStencilEnable(true)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilZFailOperation(STENCILOPERATION_INCR)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilReferenceValue(2)
	render.SetStencilWriteMask(2)

	for k, v in pairs(ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			if IsValid(v:GetActiveWeapon()) then
				v:GetActiveWeapon():DrawModel()
			end
		end
	end

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ClearBuffersObeyStencil(Meiware.color.r, Meiware.color.g, Meiware.color.b, 255, false)
	render.SetStencilEnable(false)
	cam.End3D()
end

function Meiware.ESP()
	if !Meiware.visuals.esp[2] then return end

	surface.SetFont("Default")

	for k, v in pairs(ents.GetAll()) do
		if Meiware.IsValidTarget(v) and !v:IsNPC() then
			local length = 6 + select(1, surface.GetTextSize(v:Name())) + 6
			local height = 24
			local x = v:EyePos():ToScreen().x - (length / 2)
			local y = v:EyePos():ToScreen().y - height - 6

			surface.SetDrawColor(36, 36, 36, 225)
			surface.DrawRect(x, y, length, height)

			surface.SetDrawColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			surface.DrawOutlinedRect(x, y, length, height, 1)

			surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			surface.SetTextPos(x + 6, y + 6)
			surface.DrawText(v:Name())
		end

		if table.HasValue(Meiware.entitylist, v:GetClass()) then
			local length = 6 + select(1, surface.GetTextSize(v:GetClass())) + 6
			local height = 24
			local x = v:WorldSpaceCenter():ToScreen().x - (length / 2)
			local y = v:WorldSpaceCenter():ToScreen().y - (height / 2)

			surface.SetDrawColor(36, 36, 36, 225)
			surface.DrawRect(x, y, length, height)

			surface.SetDrawColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			surface.DrawOutlinedRect(x, y, length, height, 1)

			surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			surface.SetTextPos(x + 6, y + 6)
			surface.DrawText(v:GetClass())
		end
	end
end

function Meiware.Crosshair()
	if !Meiware.visuals.crosshair[2] then return end

	local xhair_length = 16
	local xhair_thickness = 2
	surface.SetDrawColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
	surface.DrawRect((ScrW() / 2) - (xhair_length / 2), (ScrH() / 2) - (xhair_thickness / 2), xhair_length, xhair_thickness)
	surface.DrawRect((ScrW() / 2) - (xhair_thickness / 2), (ScrH() / 2) - (xhair_length / 2), xhair_thickness, xhair_length)
end

/*
	[movement]
*/
function Meiware.Autostrafe(cmd)
	if !Meiware.movement.autostrafe[2] then return end

	if !LocalPlayer():IsOnGround() and LocalPlayer():GetMoveType() != MOVETYPE_LADDER and LocalPlayer():GetMoveType() != MOVETYPE_NOCLIP then
		cmd:SetForwardMove(5850 / LocalPlayer():GetVelocity():Length2D())

		if cmd:CommandNumber() % 2 == 0 then
			cmd:SetSideMove(-LocalPlayer():GetVelocity():Length2D())
		elseif cmd:CommandNumber() % 2 != 0 then
			cmd:SetSideMove(LocalPlayer():GetVelocity():Length2D())
		end
	end
end

function Meiware.Autohop(cmd)
	if !Meiware.movement.autohop[2] then return end

	if cmd:KeyDown(IN_JUMP) and !LocalPlayer():IsOnGround() and LocalPlayer():GetMoveType() != MOVETYPE_LADDER and LocalPlayer():GetMoveType() != MOVETYPE_NOCLIP then
		cmd:RemoveKey(IN_JUMP)
	end
end

/*
	[menu]
*/
Meiware.frame = vgui.Create("DFrame")
Meiware.frame.size = Vector(600, 400, 0)
Meiware.frame.index = 36
Meiware.frame:SetVisible(false)
Meiware.frame:SetTitle("Meiware " .. Meiware.build_info)
Meiware.frame:SetPos(ScrW() / 2 - (Meiware.frame.size.x / 2), ScrH() / 2 - (Meiware.frame.size.y / 2))
Meiware.frame:SetSize(Meiware.frame.size.x, Meiware.frame.size.y)
Meiware.frame:SetDraggable(true)
Meiware.frame:ShowCloseButton(false)
Meiware.frame:MakePopup()

function Meiware.frame:Paint(w, h)
	surface.SetDrawColor(Color(36, 36, 36, 225))
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(Meiware.color)
	surface.DrawOutlinedRect(0, 0, w, h)
end

Meiware.frame.lblTitle.UpdateColours = function(label, skin)
	label:SetTextStyleColor(Meiware.color)
end

Meiware.frame.exit = vgui.Create("DButton", Meiware.frame)
Meiware.frame.exit:SetPos(Meiware.frame.size.x - 30, 6)
Meiware.frame.exit:SetSize(24, 24)
Meiware.frame.exit:SetText("")
Meiware.frame.exit:SetColor(Meiware.color)

Meiware.frame.exit.DoClick = function()
	Meiware.frame:SetVisible(false)

	surface.PlaySound("ambient/levels/canals/drip4.wav")
end

function Meiware.frame.exit:Paint(w, h)
	surface.SetDrawColor(Meiware.color)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawLine(8, 8, 15, 15)
	surface.DrawLine(15, 8, 8, 15)
end

Meiware.frame.scrollpanels = {}

Meiware.frame.AddTab = function(text)
	local scrollpanel = vgui.Create("DScrollPanel", Meiware.frame)
	scrollpanel.index = 6
	scrollpanel:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6, Meiware.frame.size.y - 6 - 24 - 6)
	scrollpanel:SetPos(6 + 72 + 6, 6 + 24 + 6)
	scrollpanel:SetVisible(false)

	function scrollpanel:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local vbar = scrollpanel:GetVBar()

	function vbar:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	function vbar.btnUp:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	function vbar.btnDown:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	function vbar.btnGrip:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	scrollpanel.AddToggle = function(var)
		local label = vgui.Create("DLabel", scrollpanel)
		label:SetText(var[1])
		label:SetWide(select(1, surface.GetTextSize(var[1])))
		label:SetPos(6, scrollpanel.index)
		label:SetTextColor(Meiware.color)

		local button = vgui.Create("DButton", scrollpanel)
		button:SetText("")
		button:SetSize(24, 24)
		button:SetPos(6 + select(1, surface.GetTextSize(var[1])) + 6, scrollpanel.index)

		button.DoClick = function()
			var[2] = !var[2]

			surface.PlaySound("ambient/levels/canals/drip4.wav")
		end

		function button:Paint(w, h)
			if var[2] then
				surface.SetDrawColor(Meiware.color)
				surface.DrawRect(0, 0, w, h)
			else
				surface.SetDrawColor(Meiware.color)
				surface.DrawOutlinedRect(0, 0, w, h)
			end
		end

		scrollpanel.index = scrollpanel.index + 30
	end

	table.insert(Meiware.frame.scrollpanels, scrollpanel)

	local button = vgui.Create("DButton", Meiware.frame)
	button:SetText(text)
	button:SetSize(72, 48)
	button:SetPos(6, Meiware.frame.index)
	button:SetTextColor(Meiware.color)

	button.DoClick = function()
		for k, v in pairs(Meiware.frame.scrollpanels) do
			v:SetVisible(false)
		end

		scrollpanel:SetVisible(true)

		surface.PlaySound("ambient/levels/canals/drip4.wav")
	end

	function button:Paint(w, h)
		if scrollpanel:IsVisible() then
			surface.SetDrawColor(Meiware.color)
			surface.DrawRect(0, 0, w, h)

			button:SetTextColor(Meiware.InvertColor(Meiware.color))
		else
			surface.SetDrawColor(Meiware.color)
			surface.DrawOutlinedRect(0, 0, w, h)

			button:SetTextColor(Meiware.color)
		end
	end

	Meiware.frame.index = Meiware.frame.index + 54

	return scrollpanel
end

local tab_aim = Meiware.frame.AddTab("aim")
local tab_visuals = Meiware.frame.AddTab("visuals")
local tab_movement = Meiware.frame.AddTab("movement")
local tab_hitboxlist = Meiware.frame.AddTab("hitboxes")
local tab_entitylist = Meiware.frame.AddTab("entities")

tab_aim:SetVisible(true)

for k, v in pairs(Meiware.aim) do
	tab_aim.AddToggle(v)
end

for k, v in pairs(Meiware.visuals) do
	tab_visuals.AddToggle(v)
end

for k, v in pairs(Meiware.movement) do
	tab_movement.AddToggle(v)
end

for k, v in pairs({"head", "L arm", "L forearm", "L hand", "R arm", "R forearm", "R hand", "L thigh", "L calf", "L foot", "L toe", "R thigh", "R calf", "R foot", "R toe", "pelvis", "spine"}) do
	local button = vgui.Create("DButton", tab_hitboxlist)
	button:SetPos(6, tab_hitboxlist.index)
	button:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
	button:SetText(v)

	button.DoClick = function()
		if table.HasValue(Meiware.hitboxlist, v) then
			table.RemoveByValue(Meiware.hitboxlist, v)
		else
			table.insert(Meiware.hitboxlist, v)
		end
	end

	function button:Paint(w, h)
		if table.HasValue(Meiware.hitboxlist, v) then
			surface.SetDrawColor(Meiware.color)
			surface.DrawOutlinedRect(0, 0, w, h)
			button:SetColor(Meiware.color)
		else
			surface.SetDrawColor(Meiware.InvertColor(Meiware.color))
			surface.DrawOutlinedRect(0, 0, w, h)
			button:SetColor(Meiware.InvertColor(Meiware.color))
		end
	end

	tab_hitboxlist.index = tab_hitboxlist.index + 30
end

local entitylist = {}

for k, v in pairs(ents.GetAll()) do
	if IsValid(v) and !table.HasValue(entitylist, v:GetClass()) then
		table.insert(entitylist, v:GetClass())

		local button = vgui.Create("DButton", tab_entitylist)
		button:SetPos(6, tab_entitylist.index)
		button:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
		button:SetText(v:GetClass())

		button.DoClick = function()
			if table.HasValue(Meiware.entitylist, button:GetText()) then
				table.RemoveByValue(Meiware.entitylist, button:GetText())
			else
				table.insert(Meiware.entitylist, button:GetText())
			end
		end

		function button:Paint(w, h)
			if table.HasValue(Meiware.entitylist, button:GetText()) then
				surface.SetDrawColor(Meiware.color)
				surface.DrawOutlinedRect(0, 0, w, h)
				button:SetColor(Meiware.color)
			else
				surface.SetDrawColor(Meiware.InvertColor(Meiware.color))
				surface.DrawOutlinedRect(0, 0, w, h)
				button:SetColor(Meiware.InvertColor(Meiware.color))
			end
		end

		tab_entitylist.index = tab_entitylist.index + 30
	end
end

function Meiware.MenuKeyListener()
	if input.IsButtonDown(Meiware.menu_key) then
		Meiware.frame:SetVisible(true)
	end
end

/*
	[hooks]
*/
function Meiware.CreateMove(cmd)
	Meiware.TargetFinder(cmd)
	Meiware.Aimbot(cmd)
	Meiware.MovementFix(cmd)
	Meiware.Freecam(cmd)
	Meiware.Triggerbot(cmd)
	Meiware.Autostrafe(cmd)
	Meiware.Autohop(cmd)
	Meiware.AutoReload(cmd)
end

function Meiware.CalcView(ply, origin, angles, fov, znear, zfar)
	local view = {}

	view.origin = origin
	view.angles = angles
	view.fov = fov

	if Meiware.aim.aimbot[2] then
		view.angles = Meiware.false_ang
	end

	if Meiware.visuals.freecam[2] then
		view.origin = Meiware.false_vec
		view.drawviewer = true
	end

	if Meiware.visuals.fovoverride[2] then
		view.fov = Meiware.fov
	end

	return view
end

function Meiware.CalcViewModelView(wep, vm, oldPos, oldAng, pos, ang)
	local tempang = ang

	if Meiware.aim.aimbot[2] then
		tempang = Meiware.false_ang
	end

	return pos, tempang
end

function Meiware.PostDrawOpaqueRenderables()
	Meiware.Wallhack()
end

function Meiware.HUDPaint()
	Meiware.ESP()
	Meiware.Crosshair()
end

function Meiware.Think()
	Meiware.MenuKeyListener()
end

function Meiware.Move()
	Meiware.CurTimeFix()
end

function Meiware.Initiate()
	print("[Meiware] initiating...")

	hook.Add("CreateMove", "MeiwareCreateMove", Meiware.CreateMove)
	hook.Add("CalcView", "MeiwareCalcView", Meiware.CalcView)
	hook.Add("CalcViewModelView", "MeiwareCalcViewModelView", Meiware.CalcViewModelView)
	hook.Add("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables", Meiware.PostDrawOpaqueRenderables)
	hook.Add("HUDPaint", "MeiwareHUDPaint", Meiware.HUDPaint)
	hook.Add("Think", "MeiwareThink", Meiware.Think)
	hook.Add("Move", "MeiwareMove", Meiware.Move)

	print("[Meiware] initiated.")
end

function Meiware.Terminate()
	print("[Meiware] terminating...")

	hook.Remove("CreateMove", "MeiwareCreateMove")
	hook.Remove("CalcView", "MeiwareCalcView")
	hook.Remove("CalcViewModelView", "MeiwareCalcViewModelView")
	hook.Remove("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables")
	hook.Remove("HUDPaint", "MeiwareHUDPaint")
	hook.Remove("Think", "MeiwareThink")
	hook.Remove("Move", "MeiwareMove")

	print("[Meiware] terminated.")
end

Meiware.Initiate()
