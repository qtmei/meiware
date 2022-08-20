/*
	[Header]
*/
local Meiware = {
	build_info = "2022-08-20 @ 22:44 UTC",

	color = Color(0, 255, 0),
	menu_key = KEY_C,
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

	chars = string.ToTable("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),

	menu = false,
	menu_activetab = "aim",
	menu_delay = 0,

	localplayer = LocalPlayer(),
	target = nil,

	false_ang = LocalPlayer():EyeAngles(),
	false_vec = LocalPlayer():EyePos(),

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
	HITBOX_SPINE = 16,

	["PostRender"] = GAMEMODE.PostRender
}

surface.SetFont("Default")

function Meiware.GenerateID()
	math.randomseed(os.time())

	local ID = {}

	for i = 1, 16, 1 do
		table.insert(ID, Meiware.chars[math.random(1, table.Count(Meiware.chars))])
	end

	for i = 5, 15, 5 do
		table.insert(ID, i, "-")
	end

	return table.concat(ID)
end

function Meiware.InvertColor(col)
	return Color(255 - col.r, 255 - col.g, 255 - col.b)
end

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

	return ent != Meiware.localplayer and ent:IsPlayer() and ent:Alive() and ent:Team() != TEAM_SPECTATOR and !ent:IsDormant() and (Meiware.aim.ignoreteam[2] or ent:Team() != Meiware.localplayer:Team())
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
	math.randomseed(os.time())

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

function Meiware.TargetFinder()
	if !Meiware.aim.aimbot[2] then return end

	local closest_target = {}
	closest_target.fov = 360

	for k, v in pairs(player.GetAll()) do
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

	/*if Meiware.localplayer:Alive() and Meiware.localplayer:Health() < 1000 and Meiware.localplayer:Health() >= 100 then
		cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
		cmd:AddKey(IN_USE)

		RunConsoleCommand("gm_spawnsent", "sent_ball")

		timer.Simple(engine.TickInterval(), function() RunConsoleCommand("gmod_cleanup", "sents") end)
	end*/
end

/*
	[visuals]
*/
function Meiware.Wallhack()
	if !Meiware.visuals.wallhack[2] then return end

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

	for k, v in pairs(player.GetAll()) do
		if Meiware.IsValidTarget(v) then
			v:DrawModel()

			local wep = v:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
			end
		end
	end

	local col = Meiware.InvertColor(Meiware.color)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ClearBuffersObeyStencil(col.r, col.g, col.b, 255, false)
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

	for k, v in pairs(player.GetAll()) do
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
end

function Meiware.ESP()
	if !Meiware.visuals.esp[2] then return end

	surface.SetFont("Default")

	for k, v in pairs(player.GetAll()) do
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
	[menu]
*/
function Meiware.Menu()
	if !Meiware.menu then return end

	surface.SetFont("Default")

	local mousex, mousey = input.GetCursorPos()
	local window_title = "Meiware " .. Meiware.build_info
	local window_size = Vector(600, 400, 0)
	local window_pos = Vector((ScrW() / 2) - (window_size.x / 2), (ScrH() / 2) - (window_size.y / 2), 0)
	local window_index = {
		["window"] = window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6,
		["aim"] = window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6 + 6,
		["visuals"] = window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6 + 6,
		["movement"] = window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6 + 6
	}

	surface.SetDrawColor(Color(36, 36, 36, 225))
	surface.DrawRect(window_pos.x, window_pos.y, window_size.x, window_size.y)
	surface.SetDrawColor(Meiware.color)
	surface.DrawOutlinedRect(window_pos.x, window_pos.y, window_size.x, window_size.y)

	surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
	surface.SetTextPos(window_pos.x + (window_size.x / 2) - (select(1, surface.GetTextSize(window_title)) / 2), window_pos.y + 6)
	surface.DrawText(window_title)

	surface.DrawOutlinedRect(window_pos.x + 6 + 72 + 6, window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6, window_size.x - 6 - 72 - 6 - 6, window_size.y - 6 - select(2, surface.GetTextSize(window_title)) - 6 - 6)

	function AddTab(name)
		local x = window_pos.x + 6
		local y = window_index["window"]
		local w = 72
		local h = 48

		surface.SetDrawColor(Meiware.color)
		surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)

		if Meiware.menu_activetab == name then
			local col = Meiware.InvertColor(Meiware.color)

			surface.DrawRect(x, y, w, h)
			surface.SetTextColor(col.r, col.g, col.b)
		else
			surface.DrawOutlinedRect(x, y, w, h)
		end

		surface.SetTextPos(x + (w / 2) - (select(1, surface.GetTextSize(name)) / 2), y + (h / 2) - (select(2, surface.GetTextSize(name)) / 2))
		surface.DrawText(name)

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and input.IsMouseDown(MOUSE_LEFT) and CurTime() > Meiware.menu_delay then
			Meiware.menu_activetab = name

			Meiware.menu_delay = CurTime() + 1
		end

		window_index["window"] = window_index["window"] + 48 + 6
	end

	function AddToggle(var, tab)
		if tab != Meiware.menu_activetab then return end

		local x = window_pos.x + 6 + 72 + 6 + 6
		local y = window_index[tab]
		local w = 24
		local h = 24

		surface.SetTextColor(Meiware.color.r, Meiware.color.g, Meiware.color.b)
		surface.SetTextPos(x, y + (select(2, surface.GetTextSize(var[1])) / 2))
		surface.DrawText(var[1])

		x = x + select(1, surface.GetTextSize(var[1])) + 6

		surface.SetDrawColor(Meiware.color)
		surface.DrawOutlinedRect(x, y, w, h)

		if var[2] then
			surface.SetDrawColor(Meiware.color)
			surface.DrawRect(x, y, w, h)
		end

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and input.IsMouseDown(MOUSE_LEFT) and CurTime() > Meiware.menu_delay then
			var[2] = !var[2]

			Meiware.menu_delay = CurTime() + 1
		end

		window_index[tab] = window_index[tab] + 24 + 6
	end

	AddTab("aim")
	AddTab("visuals")
	AddTab("movement")

	for k, v in pairs(Meiware.aim) do
		AddToggle(v, "aim")
	end

	for k, v in pairs(Meiware.visuals) do
		AddToggle(v, "visuals")
	end

	for k, v in pairs(Meiware.movement) do
		AddToggle(v, "movement")
	end
end

function Meiware.MenuKeyListener()
	if input.IsButtonDown(Meiware.menu_key) then
		Meiware.menu = true
	else
		Meiware.menu = false
	end
end

/*
	[hooks]
*/
hook.Add("CreateMove", Meiware.GenerateID(), function(cmd)
	Meiware.Aimbot(cmd)
	Meiware.MovementFix(cmd)
	Meiware.Freecam(cmd)
	Meiware.Triggerbot(cmd)
	Meiware.Autostrafe(cmd)
	Meiware.Autohop(cmd)
	Meiware.AutoReload(cmd)
	Meiware.HealthHack(cmd)
end)

hook.Add("CalcView", Meiware.GenerateID(), function(ply, origin, angles, fov, znear, zfar)
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
end)

hook.Add("CalcViewModelView", Meiware.GenerateID(), function(wep, vm, oldPos, oldAng, pos, ang)
	if Meiware.aim.aimbot[2] then
		ang = Meiware.false_ang
	end

	return pos, ang
end)

hook.Add("Think", Meiware.GenerateID(), function()
	Meiware.TargetFinder()
	Meiware.MenuKeyListener()
end)

hook.Add("Move", Meiware.GenerateID(), function(ply, mv)
	if !IsFirstTimePredicted() then return end

	Meiware.curtime = CurTime() + engine.TickInterval()
end)

function GAMEMODE:PostRender()
	Meiware["PostRender"]()

	cam.Start3D()
	Meiware.Wallhack() //no depth, TODO: fix depth
	cam.End3D()

	cam.Start2D()
	Meiware.ESP()
	Meiware.Crosshair()
	Meiware.Menu()
	cam.End2D()
end

print("[Meiware] menu key: " .. input.GetKeyName(Meiware.menu_key) .. ", aim/trigger key: " .. input.GetKeyName(Meiware.aimtrig_key))
