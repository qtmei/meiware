/*
	[Header]
*/
local Meiware = {
	build_info = "2022-08-10 @ 00:26 UTC",

	//////////
	//CONFIG//
	//////////
	color = _G.Color(0, 255, 0),
	menu_key = _G.KEY_INSERT,
	aimbot_key = _G.MOUSE_5,
	aimbot_fov = 6,
	fov = 100,
	freecamspeed = 4,
	//////////
	//CONFIG//
	//////////

	menu = false,
	frame = nil,

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
		overridefov = {"override FOV", true}
	},
	movement = {
		autohop = {"auto hop", true},
		autostrafe = {"auto strafe", true}
	},

	whitelist = {},
	entitylist = {},
	hitboxlist = {"Head"},

	hitboxes = {
		["Head"] = 0,	
		["L Upperarm"] = 1,
		["L Forearm"] = 2,
		["L Hand"] = 3,
		["R Upperarm"] = 4,
		["R Forearm"] = 5,
		["R Hand"] = 6,
		["L Thigh"] = 7,
		["L Calf"] = 8,
		["L Foot"] = 9,
		["L Toe"] = 10,
		["R Thigh"] = 11,
		["R Calf"] = 12,
		["R Foot"] = 13,
		["R Toe"] = 14,
		["Pelvis"] = 15,
		["Spine"] = 16
	},

	false_ang = _G.EyeAngles(),
	false_vec = _G.EyePos(),

	target = nil,
	target_vec = _G.Vector(0, 0, 0),
	target_ang = _G.Angle(0, 0, 0),
	target_fov = 360,

	firing = false,
	attack_override = false,
	reloading = false,

	curtime = 0,

	["old render.Capture"] = _G.render.Capture,
	["old render.CapturePixels"] = _G.render.CapturePixels
}

/*_G.render.Capture = function(captureData)
	_G.hook.Remove("CreateMove", "MeiwareCreateMove")
	_G.hook.Remove("CalcView", "MeiwareCalcView")
	_G.hook.Remove("CalcViewModelView", "MeiwareCalcViewModelView")
	_G.hook.Remove("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables")
	_G.hook.Remove("HUDPaint", "MeiwareHUDPaint")
	_G.hook.Remove("Think", "MeiwareThink")
	_G.hook.Remove("Move", "MeiwareMove")

	if Meiware.menu then
		Meiware.frame:Close()
	end

	return Meiware["old render.Capture"](captureData)
end

_G.render.CapturePixels = function()
	_G.hook.Remove("CreateMove", "MeiwareCreateMove")
	_G.hook.Remove("CalcView", "MeiwareCalcView")
	_G.hook.Remove("CalcViewModelView", "MeiwareCalcViewModelView")
	_G.hook.Remove("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables")
	_G.hook.Remove("HUDPaint", "MeiwareHUDPaint")
	_G.hook.Remove("Think", "MeiwareThink")
	_G.hook.Remove("Move", "MeiwareMove")

	if Meiware.menu then
		Meiware.frame:Close()
	end

	return Meiware["old render.CapturePixels"]
end*/

local _G = _G.table.Copy(_G)
local _R = _G.debug.getregistry()

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
	if !_G.IsValid(ent) then return false end
	if ent:IsEffectActive(_G.EF_NODRAW) or ent:GetRenderMode() == _G.RENDERMODE_NONE or ent:GetRenderMode() == _G.RENDERMODE_TRANSCOLOR or ent:GetColor().a == 0 then return false end
	if Meiware.aim.ignorenpc[2] and ent:IsNPC() then return true end

	return ent:IsPlayer() and ent != _G.LocalPlayer() and ent:Alive() and ent:Team() != _G.TEAM_SPECTATOR and !ent:IsDormant() and !_G.table.HasValue(Meiware.whitelist, ent:SteamID()) and (Meiware.aim.ignoreteam[2] or ent:Team() != _G.LocalPlayer():Team())
end

/*
	[aim]
*/
function Meiware.IsEntVisibleFromVec(ent, vec)
	local trace = _G.util.TraceLine({mask = _G.MASK_SHOT, ignoreworld = false, filter = _G.LocalPlayer(), start = _G.LocalPlayer():EyePos(), endpos = vec})

	return trace.Entity == ent
end

function Meiware.CanFire()
	if !_G.IsValid(LocalPlayer():GetActiveWeapon()) then return false end

	return _G.LocalPlayer():GetActiveWeapon():Clip1() > 0 and _G.LocalPlayer():GetActiveWeapon():GetActivity() != _G.ACT_RELOAD and _G.LocalPlayer():GetActiveWeapon():GetNextPrimaryFire() < Meiware.curtime
end

function Meiware.MultiPoint(ent, hitbox)
	if !_G.isnumber(ent:GetHitBoxBone(hitbox, 0)) then return ent:WorldSpaceCenter() + _G.Vector(_G.math.Rand(-1, 1), _G.math.Rand(-1, 1), _G.math.Rand(-1, 1)) end

	local vec, ang = ent:GetBonePosition(ent:GetHitBoxBone(hitbox, 0))
	local min, max = ent:GetHitBoxBounds(hitbox, 0)
	local offset = _G.Vector(_G.math.Rand(min.x, max.x), _G.math.Rand(min.y, max.y), _G.math.Rand(min.z, max.z))

	offset:Rotate(ang)

	return vec + offset
end

function Meiware.CurTimeFix()
	if !_G.IsFirstTimePredicted() then return end

	Meiware.curtime = _G.CurTime() + _G.engine.TickInterval()
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
			cmd:AddKey(_G.IN_ATTACK)
		else
			cmd:RemoveKey(_G.IN_ATTACK)
		end

		Meiware.firing = !Meiware.firing
	else
		if Meiware.firing then
			cmd:RemoveKey(_G.IN_ATTACK)

			Meiware.firing = false
		end
	end
end

function Meiware.TargetFinder(cmd)
	if !Meiware.aim.aimbot[2] then return end

	local closest_target = nil
	local closest_target_vec = _G.Vector(0, 0, 0)
	local closest_target_ang = _G.Angle(0, 0, 0)
	local closest_target_fov = 360

	for k, v in _G.pairs(_G.ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			local hitbox = Meiware.hitboxes[_G.table.Random(Meiware.hitboxlist)]
			local vec = Meiware.MultiPoint(v, hitbox)

			if Meiware.IsEntVisibleFromVec(v, vec) then
				local ang = (vec - _G.LocalPlayer():EyePos()):Angle()

				Meiware.Normalize(ang)
				Meiware.Clamp(ang)

				local fov = _G.math.abs(_G.math.NormalizeAngle(Meiware.false_ang.y - ang.y)) + _G.math.abs(_G.math.NormalizeAngle(Meiware.false_ang.p - ang.p))

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

	if Meiware.IsValidTarget(Meiware.target) and Meiware.CanFire() and !_G.input.IsMouseDown(_G.MOUSE_LEFT) and (Meiware.aim.ignorefov[2] or (_G.input.IsMouseDown(Meiware.aimbot_key) and Meiware.target_fov <= Meiware.aimbot_fov)) then
		cmd:SetViewAngles(Meiware.target_ang)

		if Meiware.aim.aimbot[2] then
			Meiware.Attack(cmd, true, "aimbot")
		end
	else
		cmd:SetViewAngles(Meiware.false_ang)

		if Meiware.aim.aimbot[2] then
			Meiware.Attack(cmd, false, "aimbot")
		end
	end
end

function Meiware.Triggerbot(cmd)
	if !Meiware.aim.triggerbot[2] then return end

	local trace = _G.util.TraceLine({mask = _G.MASK_SHOT, start = _G.LocalPlayer():EyePos(), endpos = _G.LocalPlayer():EyePos() + cmd:GetViewAngles():Forward() * 32768, filter = _G.LocalPlayer()})

	if Meiware.IsValidTarget(trace.Entity) and Meiware.CanFire() and (Meiware.aim.ignorefov[2] or _G.input.IsMouseDown(Meiware.aimbot_key)) then
		Meiware.Attack(cmd, true, "triggerbot")
	else
		Meiware.Attack(cmd, false, "triggerbot")
	end
end

function Meiware.MovementFix(cmd)
	if Meiware.aim.aimbot[2] then
		local temp_false_ang = Meiware.false_ang + _G.Angle(cmd:GetMouseY() * _G.GetConVar("m_pitch"):GetFloat(), -cmd:GetMouseX() * _G.GetConVar("m_yaw"):GetFloat(), 0)

		Meiware.Normalize(temp_false_ang)
		Meiware.Clamp(temp_false_ang)

		Meiware.false_ang = temp_false_ang

		local vec = _G.Vector(cmd:GetForwardMove(), cmd:GetSideMove(), 0)
		local vel = _G.math.sqrt(vec.x * vec.x + vec.y * vec.y)
		local mang = vec:Angle()
		local yaw = cmd:GetViewAngles().y - Meiware.false_ang.y + mang.y

		if ((cmd:GetViewAngles().p + 90) % 360) > 180 then
			yaw = 180 - yaw
		end

		yaw = ((yaw + 180) % 360) - 180

		cmd:SetForwardMove(_G.math.cos(_G.math.rad(yaw)) * vel)
		cmd:SetSideMove(_G.math.sin(_G.math.rad(yaw)) * vel)
	else
		Meiware.false_ang = _G.EyeAngles()
	end
end

function Meiware.Freecam(cmd)
	if Meiware.visuals.freecam[2] then
		cmd:ClearMovement()

		local multiplier = 1

		if cmd:KeyDown(IN_SPEED) then
			multiplier = multiplier * 2
		end

		if cmd:KeyDown(IN_FORWARD) then
			Meiware.false_vec = Meiware.false_vec + _G.EyeAngles():Forward() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_BACK) then
			Meiware.false_vec = Meiware.false_vec + _G.EyeAngles():Forward() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVELEFT) then
			Meiware.false_vec = Meiware.false_vec + _G.EyeAngles():Right() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVERIGHT) then
			Meiware.false_vec = Meiware.false_vec + _G.EyeAngles():Right() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_JUMP) then
			Meiware.false_vec = Meiware.false_vec + _G.Angle(0, 0, 0):Up() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_DUCK) then
			Meiware.false_vec = Meiware.false_vec + _G.Angle(0, 0, 0):Up() * (-Meiware.freecamspeed * multiplier)
		end
	else
		Meiware.false_vec = _G.EyePos()
	end
end

function Meiware.AutoReload(cmd)
	if Meiware.aim.autoreload[2] and _G.IsValid(_G.LocalPlayer():GetActiveWeapon()) then
		if _G.LocalPlayer():GetActiveWeapon().Primary then
			if _G.LocalPlayer():GetActiveWeapon():Clip1() == 0 and _G.LocalPlayer():GetActiveWeapon():GetMaxClip1() > 0 then
				cmd:AddKey(_G.IN_RELOAD)

				Meiware.reloading = true
			else
				if Meiware.reloading then
					cmd:RemoveKey(_G.IN_RELOAD)

					Meiware.reloading = false
				end
			end
		else
			if Meiware.reloading then
				cmd:RemoveKey(_G.IN_RELOAD)

				Meiware.reloading = false
			end
		end
	else
		if Meiware.reloading then
			cmd:RemoveKey(_G.IN_RELOAD)

			Meiware.reloading = false
		end
	end
end

/*
	[visuals]
*/
function Meiware.Wallhack()
	if !Meiware.visuals.wallhack[2] then return end

	_G.cam.Start3D()
	_G.render.SetStencilWriteMask(0xFF)
	_G.render.SetStencilTestMask(0xFF)
	_G.render.SetStencilReferenceValue(0)
	_G.render.SetStencilCompareFunction(_G.STENCIL_ALWAYS)
	_G.render.SetStencilPassOperation(_G.STENCIL_KEEP)
	_G.render.SetStencilFailOperation(_G.STENCIL_KEEP)
	_G.render.SetStencilZFailOperation(_G.STENCIL_KEEP)
	_G.render.ClearStencil()

	_G.render.SetStencilEnable(true)
	_G.render.SetStencilReferenceValue(1)
	_G.render.SetStencilCompareFunction(_G.STENCIL_ALWAYS)
	_G.render.SetStencilZFailOperation(_G.STENCIL_REPLACE)

	for k, v in _G.pairs(_G.ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			if _G.IsValid(v:GetActiveWeapon()) then
				v:GetActiveWeapon():DrawModel()
			end
		end

		if _G.table.HasValue(Meiware.entitylist, v:GetClass()) then
			v:DrawModel()
		end
	end

	_G.render.SetStencilCompareFunction(_G.STENCIL_EQUAL)
	_G.render.ClearBuffersObeyStencil(255, 0, 0, 255, false)
	_G.render.SetStencilEnable(false)

	_G.render.SetStencilWriteMask(0xFF)
	_G.render.SetStencilTestMask(0xFF)
	_G.render.SetStencilReferenceValue(0)
	_G.render.SetStencilCompareFunction(_G.STENCIL_ALWAYS)
	_G.render.SetStencilPassOperation(_G.STENCIL_KEEP)
	_G.render.SetStencilFailOperation(_G.STENCIL_KEEP)
	_G.render.SetStencilZFailOperation(_G.STENCIL_KEEP)
	_G.render.ClearStencil()

	_G.render.SetStencilEnable(true)
	_G.render.SetStencilCompareFunction(_G.STENCIL_ALWAYS)
	_G.render.SetStencilPassOperation(_G.STENCIL_REPLACE)
	_G.render.SetStencilZFailOperation(_G.STENCILOPERATION_INCR)
	_G.render.SetStencilFailOperation(_G.STENCIL_KEEP)
	_G.render.SetStencilReferenceValue(2)
	_G.render.SetStencilWriteMask(2)

	for k, v in _G.pairs(_G.ents.GetAll()) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			if _G.IsValid(v:GetActiveWeapon()) then
				v:GetActiveWeapon():DrawModel()
			end
		end

		if _G.table.HasValue(Meiware.entitylist, v:GetClass()) then
			v:DrawModel()
		end
	end

	_G.render.SetStencilCompareFunction(_G.STENCIL_EQUAL)
	_G.render.ClearBuffersObeyStencil(0, 255, 0, 255, false)
	_G.render.SetStencilEnable(false)
	_G.cam.End3D()
end

function Meiware.ESP()
	if !Meiware.visuals.esp[2] then return end

	for k, v in _G.pairs(_G.player.GetAll()) do
		if Meiware.IsValidTarget(v) then
			_G.surface.SetFont("Default")

			local length = 6 + _G.math.max(_G.select(1, _G.surface.GetTextSize(v:Name())), _G.select(1, _G.surface.GetTextSize(v:Health()))) + 6
			local height = 24
			local x = v:EyePos():ToScreen().x - (length / 2)
			local y = v:EyePos():ToScreen().y - height - 6

			_G.surface.SetDrawColor(36, 36, 36, 225)
			_G.surface.DrawRect(x, y, length, height)

			_G.surface.SetDrawColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			_G.surface.DrawOutlinedRect(x, y, length, height, 1)

			_G.surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
			_G.surface.SetTextPos(x + 6, y + 6)
			_G.surface.DrawText(v:Name())
		end
	end
end

function Meiware.Crosshair()
	if !Meiware.visuals.crosshair[2] then return end

	local xhair_length = 16
	local xhair_thickness = 2
	_G.surface.SetDrawColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
	_G.surface.DrawRect((_G.ScrW() / 2) - (xhair_length / 2), (_G.ScrH() / 2) - (xhair_thickness / 2), xhair_length, xhair_thickness)
	_G.surface.DrawRect((_G.ScrW() / 2) - (xhair_thickness / 2), (_G.ScrH() / 2) - (xhair_length / 2), xhair_thickness, xhair_length)
end

/*
	[movement]
*/
function Meiware.Autostrafe(cmd)
	if !Meiware.movement.autostrafe[2] then return end

	if !_G.LocalPlayer():IsOnGround() and _G.LocalPlayer():GetMoveType() != _G.MOVETYPE_LADDER and _G.LocalPlayer():GetMoveType() != _G.MOVETYPE_NOCLIP then
		cmd:SetForwardMove(5850 / _G.LocalPlayer():GetVelocity():Length2D())

		if cmd:CommandNumber() % 2 == 0 then
			cmd:SetSideMove(-_G.LocalPlayer():GetVelocity():Length2D())
		elseif cmd:CommandNumber() % 2 != 0 then
			cmd:SetSideMove(_G.LocalPlayer():GetVelocity():Length2D())
		end
	end
end

function Meiware.Autohop(cmd)
	if !Meiware.movement.autohop[2] then return end

	if cmd:KeyDown(_G.IN_JUMP) and !_G.LocalPlayer():IsOnGround() and _G.LocalPlayer():GetMoveType() != _G.MOVETYPE_LADDER and _G.LocalPlayer():GetMoveType() != _G.MOVETYPE_NOCLIP then
		cmd:RemoveKey(_G.IN_JUMP)
	end
end

/*
	[menu]
*/
function Meiware.Menu()
	Meiware.menu = true

	Meiware.frame = _G.vgui.Create("DFrame")
	Meiware.frame.title = "Meiware " .. Meiware.build_info
	Meiware.frame.size = _G.Vector(600, 400, 0)
	Meiware.frame.index = 36
	local scrollpanels = {}
	local exit = _G.vgui.Create("DButton")

	local addtab = function(text)
		local scrollpanel = _G.vgui.Create("DScrollPanel")
		scrollpanel.index = 6

		scrollpanel:SetParent(Meiware.frame)
		scrollpanel:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6, Meiware.frame.size.y - 36 - 6)
		scrollpanel:SetPos(6 + 72 + 6, 36)
		scrollpanel:SetVisible(false)

		function scrollpanel:Paint(w, h)
			_G.surface.SetDrawColor(Meiware.color)
			_G.surface.DrawOutlinedRect(0, 0, w, h)
		end

		local vbar = scrollpanel:GetVBar()

		function vbar:Paint(w, h)
			_G.surface.SetDrawColor(Meiware.color)
			_G.surface.DrawOutlinedRect(0, 0, w, h)
		end

		function vbar.btnUp:Paint(w, h)
			_G.surface.SetDrawColor(Meiware.color)
			_G.surface.DrawOutlinedRect(0, 0, w, h)
		end

		function vbar.btnDown:Paint(w, h)
			_G.surface.SetDrawColor(Meiware.color)
			_G.surface.DrawOutlinedRect(0, 0, w, h)
		end

		function vbar.btnGrip:Paint(w, h)
			_G.surface.SetDrawColor(Meiware.color)
			_G.surface.DrawOutlinedRect(0, 0, w, h)
		end

		local button = _G.vgui.Create("DButton")

		button:SetParent(Meiware.frame)
		button:SetText(text)
		button:SetSize(72, 48)
		button:SetPos(6, Meiware.frame.index)
		button:SetVisible(true)
		button:SetTextColor(Meiware.color)
		button.DoClick = function()
			for k, v in _G.pairs(scrollpanels) do
				v:SetVisible(false)
			end

			scrollpanel:SetVisible(true)

			_G.surface.PlaySound("ambient/levels/canals/drip4.wav")
		end

		function button:Paint(w, h)
			if scrollpanel:IsVisible() then
				_G.surface.SetDrawColor(Meiware.color)
				_G.surface.DrawRect(0, 0, w, h)

				button:SetTextColor(Color(255, 255, 255))
			else
				_G.surface.SetDrawColor(Meiware.color)
				_G.surface.DrawOutlinedRect(0, 0, w, h)

				button:SetTextColor(Meiware.color)
			end
		end

		Meiware.frame.index = Meiware.frame.index + 54

		_G.table.insert(scrollpanels, scrollpanel)

		return scrollpanel
	end

	local addtoggle = function(var, panel)
		local label = _G.vgui.Create("DLabel")
		local button = _G.vgui.Create("DButton")

		_G.surface.SetFont("Default")

		label:SetParent(panel)
		label:SetText(var[1])
		label:SetWide(_G.surface.GetTextSize(var[1]))
		label:SetPos(6, panel.index)
		label:SetVisible(true)
		label:SetTextColor(Meiware.color)

		button:SetParent(panel)
		button:SetText("")
		button:SetVisible(true)
		button:SetSize(24, 24)
		button:SetPos(6 + _G.surface.GetTextSize(var[1]) + 6, panel.index)
		button.DoClick = function()
			var[2] = !var[2]

			_G.surface.PlaySound("ambient/levels/canals/drip4.wav")
		end

		function button:Paint(w, h)
			if var[2] then
				_G.surface.SetDrawColor(Meiware.color)
				_G.surface.DrawRect(0, 0, w, h)
			else
				_G.surface.SetDrawColor(Meiware.color)
				_G.surface.DrawOutlinedRect(0, 0, w, h)
			end
		end

		panel.index = panel.index + 30
	end

	Meiware.frame.lblTitle.UpdateColours = function(label, skin)
		label:SetTextStyleColor(Meiware.color)
	end

	Meiware.frame:SetPos(_G.ScrW() / 2 - (Meiware.frame.size.x / 2), _G.ScrH() / 2 - (Meiware.frame.size.y / 2))
	Meiware.frame:SetSize(Meiware.frame.size.x, Meiware.frame.size.y)
	Meiware.frame:SetVisible(true)
	Meiware.frame:SetTitle(Meiware.frame.title)
	Meiware.frame:SetDraggable(true)
	Meiware.frame:ShowCloseButton(false)
	Meiware.frame:MakePopup()

	function Meiware.frame:Paint(w, h)
		_G.surface.SetDrawColor(_G.Color(36, 36, 36, 225))
		_G.surface.DrawRect(0, 0, w, h)
		_G.surface.SetDrawColor(Meiware.color)
		_G.surface.DrawOutlinedRect(0, 0, w, h)
	end

	exit:SetParent(Meiware.frame)
	exit:SetPos(Meiware.frame.size.x - 30, 6)
	exit:SetSize(24, 24)
	exit:SetText("")
	exit:SetColor(Meiware.color)
	exit.DoClick = function()
		Meiware.frame:Close()

		Meiware.menu = false

		_G.surface.PlaySound("ambient/levels/canals/drip4.wav")
	end

	function exit:Paint(w, h)
		_G.surface.SetDrawColor(Meiware.color)
		_G.surface.DrawOutlinedRect(0, 0, w, h)
		_G.surface.DrawLine(8, 8, 15, 15)
		_G.surface.DrawLine(15, 8, 8, 15)
	end

	local tab_aim = addtab("aim")
	local tab_visuals = addtab("visuals")
	local tab_movement = addtab("movement")
	local tab_hitboxlist = addtab("hitboxes")
	local tab_whitelist = addtab("whitelist")
	local tab_entitylist = addtab("entities")

	tab_aim:SetVisible(true)

	for k, v in _G.pairs(Meiware.aim) do
		addtoggle(v, tab_aim)
	end

	for k, v in _G.pairs(Meiware.visuals) do
		addtoggle(v, tab_visuals)
	end

	for k, v in _G.pairs(Meiware.movement) do
		addtoggle(v, tab_movement)
	end

	for k, v in _G.pairs(_G.player.GetAll()) do
		if _G.IsValid(v) then
			local button = _G.vgui.Create("DButton")

			button:SetParent(tab_whitelist)
			button:SetColor(Meiware.color)
			button:SetPos(6, tab_whitelist.index)
			button:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
			button:SetText(v:Name() .. " " .. v:SteamID())
			button.DoClick = function()
				if !_G.table.HasValue(Meiware.whitelist, v:SteamID()) then
					_G.table.insert(Meiware.whitelist, v:SteamID())
				else
					_G.table.RemoveByValue(Meiware.whitelist, v:SteamID())
				end
			end

			function button:Paint(w, h)
				if _G.table.HasValue(Meiware.whitelist, v:SteamID()) then
					_G.surface.SetDrawColor(Color(0, 255, 255))
					_G.surface.DrawOutlinedRect(0, 0, w, h)
				else
					_G.surface.SetDrawColor(Color(255, 0, 0))
					_G.surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			tab_whitelist.index = tab_whitelist.index + 30
		end
	end

	local entitylist = {}

	for k, v in _G.pairs(_G.ents.GetAll()) do
		if _G.IsValid(v) and !_G.table.HasValue(entitylist, v:GetClass()) then
			_G.table.insert(entitylist, v:GetClass())

			local button = _G.vgui.Create("DButton")

			button:SetParent(tab_entitylist)
			button:SetColor(Meiware.color)
			button:SetPos(6, tab_entitylist.index)
			button:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
			button:SetText(v:GetClass())
			button.DoClick = function()
				if _G.table.HasValue(Meiware.entitylist, v:GetClass()) then
					_G.table.RemoveByValue(Meiware.entitylist, v:GetClass())
				else
					_G.table.insert(Meiware.entitylist, v:GetClass())
				end
			end

			function button:Paint(w, h)
				if _G.table.HasValue(Meiware.entitylist, v:GetClass()) then
					_G.surface.SetDrawColor(Color(0, 255, 255))
					_G.surface.DrawOutlinedRect(0, 0, w, h)
				else
					_G.surface.SetDrawColor(Color(255, 0, 0))
					_G.surface.DrawOutlinedRect(0, 0, w, h)
				end
			end

			tab_entitylist.index = tab_entitylist.index + 30
		end
	end

	for k, v in _G.pairs({"Head", "L Upperarm", "L Forearm", "L Hand", "R Upperarm", "R Forearm", "R Hand", "L Thigh", "L Calf", "L Foot", "L Toe", "R Thigh", "R Calf", "R Foot", "R Toe", "Pelvis", "Spine"}) do
		local button = _G.vgui.Create("DButton")

		button:SetParent(tab_hitboxlist)
		button:SetColor(Meiware.color)
		button:SetPos(6, tab_hitboxlist.index)
		button:SetSize(Meiware.frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
		button:SetText(v)
		button.DoClick = function()
			if _G.table.HasValue(Meiware.hitboxlist, v) then
				_G.table.RemoveByValue(Meiware.hitboxlist, v)
			else
				_G.table.insert(Meiware.hitboxlist, v)
			end
		end

		function button:Paint(w, h)
			if _G.table.HasValue(Meiware.hitboxlist, v) then
				_G.surface.SetDrawColor(Color(0, 255, 255))
				_G.surface.DrawOutlinedRect(0, 0, w, h)
			else
				_G.surface.SetDrawColor(Color(255, 0, 0))
				_G.surface.DrawOutlinedRect(0, 0, w, h)
			end
		end

		tab_hitboxlist.index = tab_hitboxlist.index + 30
	end
end

function Meiware.MenuKeyListener()
	if _G.input.IsKeyDown(Meiware.menu_key) and !Meiware.menu then
		Meiware.Menu()
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

	if Meiware.visuals.overridefov[2] then
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
	_G.print("[Meiware] loading...")

	_G.hook.Add("CreateMove", "MeiwareCreateMove", Meiware.CreateMove)
	_G.hook.Add("CalcView", "MeiwareCalcView", Meiware.CalcView)
	_G.hook.Add("CalcViewModelView", "MeiwareCalcViewModelView", Meiware.CalcViewModelView)
	_G.hook.Add("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables", Meiware.PostDrawOpaqueRenderables)
	_G.hook.Add("HUDPaint", "MeiwareHUDPaint", Meiware.HUDPaint)
	_G.hook.Add("Think", "MeiwareThink", Meiware.Think)
	_G.hook.Add("Move", "MeiwareMove", Meiware.Move)

	_G.print("[Meiware] loaded.")
end

function Meiware.Terminate()
	_G.print("[Meiware] terminating...")

	_G.hook.Remove("CreateMove", "MeiwareCreateMove")
	_G.hook.Remove("CalcView", "MeiwareCalcView")
	_G.hook.Remove("CalcViewModelView", "MeiwareCalcViewModelView")
	_G.hook.Remove("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables")
	_G.hook.Remove("HUDPaint", "MeiwareHUDPaint")
	_G.hook.Remove("Think", "MeiwareThink")
	_G.hook.Remove("Move", "MeiwareMove")

	_G.print("[Meiware] terminated.")
end

Meiware.Initiate()