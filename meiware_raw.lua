/*
	[Header]
*/
local Meiware = {
	build_info = "2022-08-18 @ 17:02 UTC",

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
		autostrafe = {"auto strafe", true},
		healthhack = {"health hack", false}
	},

	playerlist = {},
	entitylist = {},

	menu = false,

	localplayer = LocalPlayer(),

	false_ang = LocalPlayer():EyeAngles(),
	false_vec = LocalPlayer():EyePos(),

	target = nil,

	curtime = 0,

	HITBOX_HEAD = 0,
	HITBOX_L_ARM = 1,
	HITBOX_L_FOREARM = 2,
	HITBOX_L_HAND = 3,
	HITBOX_R_ARM = 4,
	HITBOX_R_FOREARM = 5,
	HITBOX_R_HAND = 6,
	HITBOX_L_THIGH = 7,
	HITBOX_L_CALF = 8,
	HITBOX_L_FOOT = 9,
	HITBOX_L_TOE = 10,
	HITBOX_R_THIGH = 11,
	HITBOX_R_CALF = 12,
	HITBOX_R_FOOT = 13,
	HITBOX_R_TOE = 14,
	HITBOX_PELVIS = 15,
	HITBOX_SPINE = 16
}

surface.SetFont("Default")

/*
	[aim]
*/
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

	return ent != Meiware.localplayer and ent:IsPlayer() and ent:Alive() and ent:Team() != TEAM_SPECTATOR and !ent:IsDormant() and (Meiware.aim.ignoreteam[2] or ent:Team() != Meiware.localplayer:Team()) and table.HasValue(Meiware.playerlist, ent)
end

function Meiware.IsEntVisibleFromVec(ent, vec)
	local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = Meiware.localplayer, start = Meiware.localplayer:EyePos(), endpos = vec})

	return trace.Entity == ent
end

function Meiware.CanFire()
	local wep = Meiware.localplayer:GetActiveWeapon()

	if !IsValid(wep) then return false end

	return wep:Clip1() > 0 and wep:GetActivity() != ACT_RELOAD and wep:GetNextPrimaryFire() < Meiware.curtime
end

function Meiware.HitboxPriority(tbl)
	return table.HasValue(tbl, Meiware.HITBOX_HEAD) and Meiware.HITBOX_HEAD or table.HasValue(tbl, Meiware.HITBOX_SPINE) and Meiware.HITBOX_SPINE or table.HasValue(tbl, Meiware.HITBOX_PELVIS) and Meiware.HITBOX_PELVIS or table.HasValue(tbl, Meiware.HITBOX_L_THIGH) and Meiware.HITBOX_L_THIGH or table.HasValue(tbl, Meiware.HITBOX_R_THIGH) and Meiware.HITBOX_R_THIGH or table.HasValue(tbl, Meiware.HITBOX_L_ARM) and Meiware.HITBOX_L_ARM or table.HasValue(tbl, Meiware.HITBOX_R_ARM) and Meiware.HITBOX_R_ARM  or table.HasValue(tbl, Meiware.HITBOX_L_CALF) and Meiware.HITBOX_L_CALF or table.HasValue(tbl, Meiware.HITBOX_R_CALF) and Meiware.HITBOX_R_CALF or table.HasValue(tbl, Meiware.HITBOX_L_FOREARM) and Meiware.HITBOX_L_FOREARM or table.HasValue(tbl, Meiware.HITBOX_R_FOREARM) and Meiware.HITBOX_R_FOREARM or table.HasValue(tbl, Meiware.HITBOX_L_FOOT) and Meiware.HITBOX_L_FOOT or table.HasValue(tbl, Meiware.HITBOX_R_FOOT) and Meiware.HITBOX_R_FOOT or table.HasValue(tbl, Meiware.HITBOX_L_HAND) and Meiware.HITBOX_L_HAND or table.HasValue(tbl, Meiware.HITBOX_R_HAND) and Meiware.HITBOX_R_HAND or table.HasValue(tbl, Meiware.HITBOX_L_TOE) and Meiware.HITBOX_L_TOE or table.HasValue(tbl, Meiware.HITBOX_R_TOE) and Meiware.HITBOX_R_TOE or table.Random(tbl)
end

function Meiware.MultiPoint(ent)
	local visible_hitboxes = {}
	local visible_vecs = {}

	local hitbox_sets = ent:GetHitboxSetCount()

	for hitbox_set = 0, hitbox_sets - 1 do
		local hitboxes = ent:GetHitBoxCount(hitbox_set)

		for hitbox = 0, hitboxes - 1 do
			local vec, ang = ent:GetBonePosition(ent:GetHitBoxBone(hitbox, hitbox_set))
			local min, max = ent:GetHitBoxBounds(hitbox, hitbox_set)
			local offset = Vector(math.Rand(min.x, max.x), math.Rand(min.y, max.y), math.Rand(min.z, max.z))

			offset:Rotate(ang)

			if Meiware.IsEntVisibleFromVec(ent, vec + offset) then
				table.insert(visible_hitboxes, hitbox)
				table.insert(visible_vecs, hitbox, vec + offset)
			end
		end
	end

	return !table.IsEmpty(visible_vecs) and visible_vecs[Meiware.HitboxPriority(visible_hitboxes)] or nil
end

function Meiware.InvertColor(col)
	return Color(255 - col.r, 255 - col.g, 255 - col.b)
end

function Meiware.CurTimeFix()
	if !IsFirstTimePredicted() then return end

	Meiware.curtime = CurTime() + engine.TickInterval()
end

function Meiware.TargetFinder()
	if !Meiware.aim.aimbot[2] then return end

	local closest_target = {}
	closest_target.fov = 360

	for k, v in pairs(Meiware.playerlist) do
		if Meiware.IsValidTarget(v) then
			local ang = (v:WorldSpaceCenter() - Meiware.localplayer:EyePos()):Angle()
			local fov = math.abs(math.NormalizeAngle(Meiware.false_ang.y - ang.y)) + math.abs(math.NormalizeAngle(Meiware.false_ang.p - ang.p))

			if fov < closest_target.fov then
				local vec = Meiware.MultiPoint(v)

				if vec then
					local ang = (vec - Meiware.localplayer:EyePos()):Angle()

					ang:Normalize()
					Meiware.Clamp(ang)

					closest_target = v
					closest_target.fov = fov
					closest_target.ang = ang
				end
			end
		end
	end

	Meiware.target = closest_target
end

function Meiware.Aimbot(cmd)
	if !Meiware.aim.aimbot[2] then return end

	if Meiware.IsValidTarget(Meiware.target) and Meiware.CanFire() and !input.IsMouseDown(MOUSE_LEFT) and (Meiware.aim.ignorefov[2] or (input.IsButtonDown(Meiware.aimtrig_key) and Meiware.target.fov <= Meiware.aimbot_fov)) then
		cmd:SetViewAngles(Meiware.target.ang)
		cmd:AddKey(IN_ATTACK)
	else
		cmd:SetViewAngles(Meiware.false_ang)
	end
end

function Meiware.Triggerbot(cmd)
	if !Meiware.aim.triggerbot[2] then return end

	local trace = util.TraceLine({mask = MASK_SHOT, start = Meiware.localplayer:EyePos(), endpos = Meiware.localplayer:EyePos() + cmd:GetViewAngles():Forward() * 32768, filter = Meiware.localplayer})

	if Meiware.IsValidTarget(trace.Entity) and Meiware.CanFire() and (Meiware.aim.ignorefov[2] or input.IsButtonDown(Meiware.aimtrig_key)) then
		cmd:AddKey(IN_ATTACK)
	end
end

function Meiware.MovementFix(cmd)
	if Meiware.aim.aimbot[2] then
		local temp_false_ang = Meiware.false_ang + Angle(cmd:GetMouseY() * GetConVar("m_pitch"):GetFloat(), -cmd:GetMouseX() * GetConVar("m_yaw"):GetFloat(), 0)

		temp_false_ang:Normalize()
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
		Meiware.false_ang = Meiware.localplayer:EyeAngles()
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
			Meiware.false_vec = Meiware.false_vec + Meiware.localplayer:EyeAngles():Forward() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_BACK) then
			Meiware.false_vec = Meiware.false_vec + Meiware.localplayer:EyeAngles():Forward() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVELEFT) then
			Meiware.false_vec = Meiware.false_vec + Meiware.localplayer:EyeAngles():Right() * (-Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_MOVERIGHT) then
			Meiware.false_vec = Meiware.false_vec + Meiware.localplayer:EyeAngles():Right() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_JUMP) then
			Meiware.false_vec = Meiware.false_vec + Angle(0, 0, 0):Up() * (Meiware.freecamspeed * multiplier)
		end

		if cmd:KeyDown(IN_DUCK) then
			Meiware.false_vec = Meiware.false_vec + Angle(0, 0, 0):Up() * (-Meiware.freecamspeed * multiplier)
		end
	else
		Meiware.false_vec = Meiware.localplayer:EyePos()
	end
end

function Meiware.AutoReload(cmd)
	local wep = Meiware.localplayer:GetActiveWeapon()

	if Meiware.aim.autoreload[2] and IsValid(wep) then
		if wep.Primary then
			if wep:Clip1() == 0 and wep:GetMaxClip1() > 0 and Meiware.localplayer:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0 then
				cmd:AddKey(IN_RELOAD)
			end
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

	for k, v in pairs(Meiware.playerlist) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			local wep = v:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
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

	for k, v in pairs(Meiware.playerlist) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			local wep = v:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
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
		if Meiware.IsValidTarget(v) then
			local length = 6 + select(1, surface.GetTextSize(v:Name())) + 6
			local height = 24
			local x = v:GetPos():ToScreen().x - (length / 2)
			local y = (v:EyePos() + Vector(0, 0, 8)):ToScreen().y - height

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

	if !Meiware.localplayer:IsOnGround() and Meiware.localplayer:GetMoveType() != MOVETYPE_LADDER and Meiware.localplayer:GetMoveType() != MOVETYPE_NOCLIP then
		cmd:SetForwardMove(5850 / Meiware.localplayer:GetVelocity():Length2D())

		if cmd:CommandNumber() % 2 == 0 then
			cmd:SetSideMove(-Meiware.localplayer:GetVelocity():Length2D())
		elseif cmd:CommandNumber() % 2 != 0 then
			cmd:SetSideMove(Meiware.localplayer:GetVelocity():Length2D())
		end
	end
end

function Meiware.Autohop(cmd)
	if !Meiware.movement.autohop[2] then return end

	if cmd:KeyDown(IN_JUMP) and !Meiware.localplayer:IsOnGround() and Meiware.localplayer:GetMoveType() != MOVETYPE_LADDER and Meiware.localplayer:GetMoveType() != MOVETYPE_NOCLIP then
		cmd:RemoveKey(IN_JUMP)
	end
end

function Meiware.HealthHack(cmd)
	if !Meiware.movement.healthhack[2] then return end

	if Meiware.localplayer:Alive() and Meiware.localplayer:Health() < 100 then
		cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
		cmd:AddKey(IN_USE)

		RunConsoleCommand("gm_spawnsent", "item_healthkit")

		timer.Simple(engine.TickInterval(), function() RunConsoleCommand("gmod_cleanup", "sents") end)
	end

	/*if Meiware.localplayer:Alive() and Meiware.localplayer:Health() < 1000 then
		cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
		cmd:AddKey(IN_USE)

		RunConsoleCommand("gm_spawnsent", "sent_ball")

		timer.Simple(engine.TickInterval(), function() RunConsoleCommand("gmod_cleanup", "sents") end)
	end*/
end

/*
	[menu]
*/
function Meiware.Menu()
	Meiware.menu = true

	surface.SetFont("Default")

	frame = vgui.Create("DFrame")
	frame.size = Vector(600, 400, 0)
	frame.index = 36
	frame:SetVisible(true)
	frame:SetTitle("Meiware " .. Meiware.build_info)
	frame:SetPos(ScrW() / 2 - (frame.size.x / 2), ScrH() / 2 - (frame.size.y / 2))
	frame:SetSize(frame.size.x, frame.size.y)
	frame:SetDraggable(true)
	frame:ShowCloseButton(false)
	frame:MakePopup()

	function frame:Paint(w, h)
		surface.SetDrawColor(Color(36, 36, 36, 225))
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	frame.lblTitle.UpdateColours = function(label, skin)
		label:SetTextStyleColor(Meiware.color)
	end

	frame.exit = vgui.Create("DButton", frame)
	frame.exit:SetPos(frame.size.x - 30, 6)
	frame.exit:SetSize(24, 24)
	frame.exit:SetText("")
	frame.exit:SetColor(Meiware.color)

	frame.exit.DoClick = function()
		frame:Close()
		Meiware.menu = false

		surface.PlaySound("ambient/levels/canals/drip4.wav")
	end

	function frame.exit:Paint(w, h)
		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.DrawLine(8, 8, 15, 15)
		surface.DrawLine(15, 8, 8, 15)
	end

	frame.scrollpanels = {}

	frame.AddTab = function(text)
		local scrollpanel = vgui.Create("DScrollPanel", frame)
		scrollpanel.index = 6
		scrollpanel:SetSize(frame.size.x - 6 - 72 - 6 - 6, frame.size.y - 6 - 24 - 6 - 6)
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

		table.insert(frame.scrollpanels, scrollpanel)

		local button = vgui.Create("DButton", frame)
		button:SetText(text)
		button:SetSize(72, 48)
		button:SetPos(6, frame.index)
		button:SetTextColor(Meiware.color)

		button.DoClick = function()
			for k, v in pairs(frame.scrollpanels) do
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

		frame.index = frame.index + 54

		return scrollpanel
	end

	local tab_aim = frame.AddTab("aim")
	local tab_visuals = frame.AddTab("visuals")
	local tab_movement = frame.AddTab("movement")
	local tab_playerlist = frame.AddTab("players")
	local tab_entitylist = frame.AddTab("entities")

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

	for k, v in pairs(player.GetAll()) do
		if v != Meiware.localplayer then
			local button = vgui.Create("DButton", tab_playerlist)
			button:SetPos(6, tab_playerlist.index)
			button:SetSize(frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
			button:SetText("[" .. v:SteamID() .. "] " .. v:Name())

			button.DoClick = function()
				if table.HasValue(Meiware.playerlist, v) then
					table.RemoveByValue(Meiware.playerlist, v)
				else
					table.insert(Meiware.playerlist, v)
				end
			end

			function button:Paint(w, h)
				if table.HasValue(Meiware.playerlist, v) then
					surface.SetDrawColor(Meiware.color)
					surface.DrawOutlinedRect(0, 0, w, h)
					button:SetColor(Meiware.color)
				else
					surface.SetDrawColor(Meiware.InvertColor(Meiware.color))
					surface.DrawOutlinedRect(0, 0, w, h)
					button:SetColor(Meiware.InvertColor(Meiware.color))
				end
			end

			tab_playerlist.index = tab_playerlist.index + 30
		end
	end

	local entitylist = {}

	for k, v in pairs(ents.GetAll()) do
		if IsValid(v) and !table.HasValue(entitylist, v:GetClass()) then
			table.insert(entitylist, v:GetClass())

			local button = vgui.Create("DButton", tab_entitylist)
			button:SetPos(6, tab_entitylist.index)
			button:SetSize(frame.size.x - 6 - 72 - 6 - 6 - 6 - 18, 24)
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
end

function Meiware.MenuKeyListener()
	if input.IsButtonDown(Meiware.menu_key) and !Meiware.menu then
		Meiware.Menu()
	end
end

/*
	[hooks]
*/
function Meiware.CreateMove(cmd)
	Meiware.Aimbot(cmd)
	Meiware.MovementFix(cmd)
	Meiware.Freecam(cmd)
	Meiware.Triggerbot(cmd)
	Meiware.Autostrafe(cmd)
	Meiware.Autohop(cmd)
	Meiware.AutoReload(cmd)
	Meiware.HealthHack(cmd)
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
	Meiware.TargetFinder()
	Meiware.MenuKeyListener()
end

function Meiware.Move()
	Meiware.CurTimeFix()
end

hook.Add("CreateMove", "MeiwareCreateMove", Meiware.CreateMove)
hook.Add("CalcView", "MeiwareCalcView", Meiware.CalcView)
hook.Add("CalcViewModelView", "MeiwareCalcViewModelView", Meiware.CalcViewModelView)
hook.Add("PostDrawOpaqueRenderables", "MeiwarePostDrawOpaqueRenderables", Meiware.PostDrawOpaqueRenderables)
hook.Add("HUDPaint", "MeiwareHUDPaint", Meiware.HUDPaint)
hook.Add("Think", "MeiwareThink", Meiware.Think)
hook.Add("Move", "MeiwareMove", Meiware.Move)
