/*
	[Header]
*/
local build_info = "2023-07-02 @ 17:20 UTC"

local color = Color(0, 255, 0)
local aimtrig_key = MOUSE_5
local aim_fov = 6

local aim = {
	aimbot = {"aimbot", true},
	ignoreteam = {"ignore team check?", true},
	ragemode = {"rage mode", false},
	triggerbot = {"triggerbot", true},
	autoreload = {"auto reload", true}
}
local visuals = {
	wallhack = {"wallhack", true},
	esp = {"ESP", true},
	crosshair = {"crosshair", true},
	freecam = {"freecam", false}
}
local movement = {
	autohop = {"auto hop", true},
	autostrafe = {"auto strafe", true},
	autohealthkit = {"auto health kit", false},
	autosuitbattery = {"auto suit battery", false},
	autohealthball = {"auto health ball", false}
}

local HITBOX_HEAD = 0
local HITBOX_L_ARM = 1
local HITBOX_L_FOREARM = 2
local HITBOX_L_HAND = 3
local HITBOX_R_ARM = 4
local HITBOX_R_FOREARM = 5
local HITBOX_R_HAND = 6
local HITBOX_L_THIGH = 7
local HITBOX_L_CALF = 8
local HITBOX_L_FOOT = 9
local HITBOX_L_TOE = 10
local HITBOX_R_THIGH = 11
local HITBOX_R_CALF = 12
local HITBOX_R_FOOT = 13
local HITBOX_R_TOE = 14
local HITBOX_PELVIS = 15
local HITBOX_SPINE = 16

local chars = string.ToTable("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

local menu = false
local menu_activetab = "aim"
local menu_delay = 0

local localplayer = LocalPlayer()
local target = nil

local false_ang = LocalPlayer():EyeAngles()
local false_vec = LocalPlayer():EyePos()

local curtime = 0

local spawned_ents = 0
local spawn_delay = 0

local PostRender_old = GAMEMODE.PostRender

math.randomseed(os.time())

local function GenerateID()
	local ID = {}

	for i = 0, 16 - 1, 1 do
		ID[i] = chars[math.random(1, table.Count(chars))]
	end

	return table.concat(ID)
end

local function InvertColor(col)
	return Color(255 - col.r, 255 - col.g, 255 - col.b)
end

local function Clamp(ang)
	if ang.p > 89 then
		ang.p = 89
	elseif ang.p < -89 then
		ang.p = -89
	end

	ang.r = 0
end

local function IsValidTarget(ent)
	if !IsValid(ent) then return false end
	if ent:IsEffectActive(EF_NODRAW) or ent:GetRenderMode() == RENDERMODE_NONE or ent:GetRenderMode() == RENDERMODE_TRANSCOLOR or ent:GetColor().a == 0 then return false end

	return ent != localplayer and ent:Alive() and ent:Team() != TEAM_SPECTATOR and !ent:IsDormant() and (aim.ignoreteam[2] or ent:Team() != localplayer:Team())
end

local function IsEntVisibleFromVec(ent, vec)
	local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = localplayer, start = localplayer:EyePos(), endpos = vec})

	return trace.Entity == ent
end

local function CanFire()
	local wep = localplayer:GetActiveWeapon()

	if !IsValid(wep) then return false end

	return wep:Clip1() > 0 and wep:GetActivity() != ACT_RELOAD and wep:GetNextPrimaryFire() < curtime
end

local function HitboxPriority(tbl)
	return tbl[HITBOX_HEAD] or tbl[HITBOX_SPINE] or tbl[HITBOX_PELVIS] or tbl[HITBOX_L_THIGH] or tbl[HITBOX_R_THIGH] or tbl[HITBOX_L_ARM] or tbl[HITBOX_R_ARM] or tbl[HITBOX_L_CALF] or tbl[HITBOX_R_CALF] or tbl[HITBOX_L_FOREARM] or tbl[HITBOX_R_FOREARM] or tbl[HITBOX_L_FOOT] or tbl[HITBOX_R_FOOT] or tbl[HITBOX_L_HAND] or tbl[HITBOX_R_HAND] or tbl[HITBOX_L_TOE] or tbl[HITBOX_R_TOE] or table.Random(tbl) or nil
end

local function MultiPoint(ent)
	local visible_vecs = {}
	local hitbox_sets = ent:GetHitboxSetCount()

	for hitbox_set = 0, hitbox_sets - 1 do
		local hitboxes = ent:GetHitBoxCount(hitbox_set)

		for hitbox = 0, hitboxes - 1 do
			local vec, ang = ent:GetBonePosition(ent:GetHitBoxBone(hitbox, hitbox_set))
			local min, max = ent:GetHitBoxBounds(hitbox, hitbox_set)
			local offset = Vector(math.Rand(min.x, max.x), math.Rand(min.y, max.y), math.Rand(min.z, max.z))

			offset:Rotate(ang)

			vec = vec + offset

			if IsEntVisibleFromVec(ent, vec) then
				visible_vecs[hitbox] = vec
			end
		end
	end

	return HitboxPriority(visible_vecs)
end

/*
	[aim]
*/
local function TargetFinder()
	if !aim.aimbot[2] then return end

	local closest_target = {}
	closest_target.fov = 360

	for k, v in pairs(player.GetAll()) do
		if IsValidTarget(v) then
			local ang = (v:WorldSpaceCenter() - localplayer:EyePos()):Angle()
			local fov = math.abs(math.NormalizeAngle(false_ang.y - ang.y)) + math.abs(math.NormalizeAngle(false_ang.p - ang.p))

			if fov < closest_target.fov then
				local vec = MultiPoint(v)

				if vec then
					local ang = (vec - localplayer:EyePos()):Angle()

					ang:Normalize()
					Clamp(ang)

					closest_target = v
					closest_target.fov = fov
					closest_target.ang = ang
				end
			end
		end
	end

	target = closest_target
end

local function Aimbot(cmd)
	if !aim.aimbot[2] then return end

	if IsValidTarget(target) and CanFire() and !input.IsMouseDown(MOUSE_LEFT) and (aim.ragemode[2] or (input.IsButtonDown(aimtrig_key) and target.fov <= aim_fov)) then
		cmd:SetViewAngles(target.ang)
		cmd:AddKey(IN_ATTACK)
	else
		cmd:SetViewAngles(false_ang)
	end
end

local function Triggerbot(cmd)
	if !aim.triggerbot[2] then return end

	local trace = util.TraceLine({mask = MASK_SHOT, start = localplayer:EyePos(), endpos = localplayer:EyePos() + cmd:GetViewAngles():Forward() * 32768, filter = localplayer})

	if IsValidTarget(trace.Entity) and CanFire() and (aim.ragemode[2] or input.IsButtonDown(aimtrig_key)) then
		cmd:AddKey(IN_ATTACK)
	end
end

local function MovementFix(cmd)
	if aim.aimbot[2] then
		local temp_false_ang = false_ang + Angle(cmd:GetMouseY() * GetConVar("m_pitch"):GetFloat(), -cmd:GetMouseX() * GetConVar("m_yaw"):GetFloat(), 0)

		temp_false_ang:Normalize()
		Clamp(temp_false_ang)

		false_ang = temp_false_ang

		local vec = Vector(cmd:GetForwardMove(), cmd:GetSideMove(), 0)
		local vel = math.sqrt(vec.x * vec.x + vec.y * vec.y)
		local mang = vec:Angle()
		local yaw = cmd:GetViewAngles().y - false_ang.y + mang.y

		if ((cmd:GetViewAngles().p + 90) % 360) > 180 then
			yaw = 180 - yaw
		end

		yaw = ((yaw + 180) % 360) - 180

		cmd:SetForwardMove(math.cos(math.rad(yaw)) * vel)
		cmd:SetSideMove(math.sin(math.rad(yaw)) * vel)
	else
		false_ang = localplayer:EyeAngles()
	end
end

local function Freecam(cmd)
	if visuals.freecam[2] then
		cmd:ClearMovement()

		local speed = 4

		if cmd:KeyDown(IN_SPEED) then
			speed = speed * 2
		end

		if cmd:KeyDown(IN_FORWARD) then
			false_vec = false_vec + false_ang:Forward() * speed
		end

		if cmd:KeyDown(IN_BACK) then
			false_vec = false_vec + false_ang:Forward() * -speed
		end

		if cmd:KeyDown(IN_MOVELEFT) then
			false_vec = false_vec + false_ang:Right() * -speed
		end

		if cmd:KeyDown(IN_MOVERIGHT) then
			false_vec = false_vec + false_ang:Right() * speed
		end

		if cmd:KeyDown(IN_JUMP) then
			false_vec = false_vec + Angle(0, 0, 0):Up() * speed
		end

		if cmd:KeyDown(IN_DUCK) then
			false_vec = false_vec + Angle(0, 0, 0):Up() * -speed
		end
	else
		false_vec = localplayer:EyePos()
	end
end

local function AutoReload(cmd)
	local wep = localplayer:GetActiveWeapon()

	if aim.autoreload[2] and IsValid(wep) then
		if wep.Primary then
			if wep:Clip1() == 0 and wep:GetMaxClip1() > 0 and localplayer:GetAmmoCount(wep:GetPrimaryAmmoType()) > 0 then
				cmd:AddKey(IN_RELOAD)
			end
		end
	end
end

/*
	[movement]
*/
local function Autostrafe(cmd)
	if !movement.autostrafe[2] then return end

	if !localplayer:IsOnGround() and localplayer:GetMoveType() != MOVETYPE_LADDER and localplayer:GetMoveType() != MOVETYPE_NOCLIP then
		cmd:SetForwardMove(5850 / localplayer:GetVelocity():Length2D())

		if cmd:CommandNumber() % 2 == 0 then
			cmd:SetSideMove(-localplayer:GetVelocity():Length2D())
		elseif cmd:CommandNumber() % 2 != 0 then
			cmd:SetSideMove(localplayer:GetVelocity():Length2D())
		end
	end
end

local function Autohop(cmd)
	if !movement.autohop[2] then return end

	if cmd:KeyDown(IN_JUMP) and !localplayer:IsOnGround() and localplayer:GetMoveType() != MOVETYPE_LADDER and localplayer:GetMoveType() != MOVETYPE_NOCLIP then
		cmd:RemoveKey(IN_JUMP)
	end
end

local function HealthHack(cmd)
	if !localplayer:Alive() or CanFire() then return end

	if spawned_ents > 0 then
		RunConsoleCommand("gmod_cleanup", "sents")

		spawned_ents = 0
	end

	if movement.autohealthkit[2] then
		if localplayer:Health() < 100 then
			cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
			cmd:AddKey(IN_USE)

			if cmd:GetViewAngles().p == 89 and CurTime() > spawn_delay then
				RunConsoleCommand("gm_spawnsent", "item_healthkit")

				spawned_ents = spawned_ents + 1
				spawn_delay = CurTime() + 0.25
			end
		end
	end

	if movement.autosuitbattery[2] then
		if localplayer:Armor() < 100 then
			cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
			cmd:AddKey(IN_USE)

			if cmd:GetViewAngles().p == 89 and CurTime() > spawn_delay then
				RunConsoleCommand("gm_spawnsent", "item_battery")

				spawned_ents = spawned_ents + 1
				spawn_delay = CurTime() + 0.25
			end
		end
	end

	if movement.autohealthball[2] then
		if localplayer:Health() < 1000 and localplayer:Health() >= 100 then
			cmd:SetViewAngles(Angle(89, cmd:GetViewAngles().y, 0))
			cmd:AddKey(IN_USE)

			if cmd:GetViewAngles().p == 89 and CurTime() > spawn_delay then
				RunConsoleCommand("gm_spawnsent", "sent_ball")

				spawned_ents = spawned_ents + 1
				spawn_delay = CurTime() + 0.25
			end
		end
	end
end

/*
	[visuals]
*/
local function Wallhack()
	if !visuals.wallhack[2] then return end

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
		if IsValidTarget(v) then
			v:DrawModel()

			local wep = v:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
			end
		end
	end

	local col = InvertColor(color)

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
		if IsValidTarget(v) then
			v:DrawModel()

			local wep = v:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
			end
		end
	end

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ClearBuffersObeyStencil(color.r, color.g, color.b, 255, false)
	render.SetStencilEnable(false)
end

local function ESP()
	if !visuals.esp[2] then return end

	surface.SetFont("Default")

	for k, v in pairs(player.GetAll()) do
		if IsValidTarget(v) then
			local length = 6 + select(1, surface.GetTextSize(v:Name())) + 6
			local height = 6 + select(2, surface.GetTextSize(v:Name())) + 6
			local x = v:GetPos():ToScreen().x - (length / 2)
			local y = (v:EyePos() + Vector(0, 0, 8)):ToScreen().y - height

			surface.SetDrawColor(36, 36, 36, 225)
			surface.DrawRect(x, y, length, height)

			surface.SetDrawColor(color.r, color.g, color.b)
			surface.DrawOutlinedRect(x, y, length, height, 1)

			surface.SetTextColor(color.r, color.g, color.b)
			surface.SetTextPos(x + 6, y + 6)
			surface.DrawText(v:Name())
		end
	end
end

local function Crosshair()
	if !visuals.crosshair[2] then return end

	local xhair_length = 16
	local xhair_thickness = 2
	surface.SetDrawColor(color.r, color.g, color.b)
	surface.DrawRect((ScrW() / 2) - (xhair_length / 2), (ScrH() / 2) - (xhair_thickness / 2), xhair_length, xhair_thickness)
	surface.DrawRect((ScrW() / 2) - (xhair_thickness / 2), (ScrH() / 2) - (xhair_length / 2), xhair_thickness, xhair_length)
end

/*
	[menu]
*/
local function Menu()
	if !menu then return end

	surface.SetFont("Default")

	local mousex, mousey = input.GetCursorPos()
	local window_title = "Meiware " .. build_info
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
	surface.SetDrawColor(color)
	surface.DrawOutlinedRect(window_pos.x, window_pos.y, window_size.x, window_size.y)

	surface.SetTextColor(color.r, color.g, color.b)
	surface.SetTextPos(window_pos.x + (window_size.x / 2) - (select(1, surface.GetTextSize(window_title)) / 2), window_pos.y + 6)
	surface.DrawText(window_title)

	surface.DrawOutlinedRect(window_pos.x + 6 + 72 + 6, window_pos.y + 6 + select(2, surface.GetTextSize(window_title)) + 6, window_size.x - 6 - 72 - 6 - 6, window_size.y - 6 - select(2, surface.GetTextSize(window_title)) - 6 - 6)

	local function AddTab(name)
		local x = window_pos.x + 6
		local y = window_index["window"]
		local w = 72
		local h = 48

		surface.SetDrawColor(color)
		surface.SetTextColor(color.r, color.g, color.b)

		if menu_activetab == name then
			local col = InvertColor(color)

			surface.DrawRect(x, y, w, h)
			surface.SetTextColor(col.r, col.g, col.b)
		else
			surface.DrawOutlinedRect(x, y, w, h)
		end

		surface.SetTextPos(x + (w / 2) - (select(1, surface.GetTextSize(name)) / 2), y + (h / 2) - (select(2, surface.GetTextSize(name)) / 2))
		surface.DrawText(name)

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and input.IsMouseDown(MOUSE_LEFT) and CurTime() > menu_delay then
			menu_activetab = name

			menu_delay = CurTime() + 1
		end

		window_index["window"] = window_index["window"] + 48 + 6
	end

	local function AddToggle(var, tab)
		if tab != menu_activetab then return end

		local x = window_pos.x + 6 + 72 + 6 + 6
		local y = window_index[tab]
		local w = 24
		local h = 24

		surface.SetTextColor(color.r, color.g, color.b)
		surface.SetTextPos(x, y + (select(2, surface.GetTextSize(var[1])) / 2))
		surface.DrawText(var[1])

		x = x + select(1, surface.GetTextSize(var[1])) + 6

		surface.SetDrawColor(color)
		surface.DrawOutlinedRect(x, y, w, h)

		if var[2] then
			surface.SetDrawColor(color)
			surface.DrawRect(x, y, w, h)
		end

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and input.IsMouseDown(MOUSE_LEFT) and CurTime() > menu_delay then
			var[2] = !var[2]

			menu_delay = CurTime() + 0.25
		end

		window_index[tab] = window_index[tab] + 24 + 6
	end

	AddTab("aim")
	AddTab("visuals")
	AddTab("movement")

	for k, v in pairs(aim) do
		AddToggle(v, "aim")
	end

	for k, v in pairs(visuals) do
		AddToggle(v, "visuals")
	end

	for k, v in pairs(movement) do
		AddToggle(v, "movement")
	end
end

/*
	[hooks]
*/
hook.Add("Think", GenerateID(), function()
	TargetFinder()
end)

hook.Add("CreateMove", GenerateID(), function(cmd)
	Aimbot(cmd)
	MovementFix(cmd)
	Freecam(cmd)
	Triggerbot(cmd)
	Autostrafe(cmd)
	Autohop(cmd)
	AutoReload(cmd)
	HealthHack(cmd)
end)

hook.Add("CalcView", GenerateID(), function(ply, origin, angles, fov, znear, zfar)
	local view = {}

	view.origin = origin
	view.angles = angles
	view.fov = fov

	if aim.aimbot[2] then
		view.angles = false_ang
	end

	if visuals.freecam[2] then
		view.origin = false_vec
		view.drawviewer = true
	end

	if aim.ragemode[2] then
		view.fov = 100
	end

	return view
end)

hook.Add("CalcViewModelView", GenerateID(), function(wep, vm, oldPos, oldAng, pos, ang)
	if aim.aimbot[2] then
		ang = false_ang
	end

	return pos, ang
end)

hook.Add("Move", GenerateID(), function(ply, mv)
	if !IsFirstTimePredicted() then return end

	curtime = CurTime() + engine.TickInterval()
end)

hook.Add("OnContextMenuOpen", GenerateID(), function()
	menu = true
end)

hook.Add("OnContextMenuClose", GenerateID(), function()
	menu = false
end)

function GAMEMODE:PostRender()
	PostRender_old()

	cam.Start3D()
	Wallhack() //no depth, TODO: fix depth
	cam.End3D()

	cam.Start2D()
	ESP()
	Crosshair()
	Menu()
	cam.End2D()
end

print("[Meiware] menu key: " .. input.LookupBinding("+menu_context", true) .. ", aim/trigger key: " .. input.GetKeyName(aimtrig_key))
