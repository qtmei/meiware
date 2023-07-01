local _G = globals_old
local _R = registry_old

/*
	[Header]
*/
local build_info = "2022-08-27 @ 19:16 UTC"

local color = _G.Color(0, 255, 0)
local aimtrig_key = _G.MOUSE_5
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

local chars = _G.string.ToTable("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

local menu = false
local menu_activetab = "aim"
local menu_delay = 0

local localplayer = _G.LocalPlayer()
local target = nil

local false_ang = _R.Entity.EyeAngles(localplayer)
local false_vec = _R.Entity.EyePos(localplayer)

local curtime = 0

local spawned_ents = 0
local spawn_delay = 0

local PostRender_old = GAMEMODE.PostRender

_G.math.randomseed(_G.os.time())

local function GenerateID()
	local ID = {}

	for i = 0, 16 - 1, 1 do
		ID[i] = chars[_G.math.random(1, _G.table.Count(chars))]
	end

	return _G.table.concat(ID)
end

local function InvertColor(col)
	return _G.Color(255 - col.r, 255 - col.g, 255 - col.b)
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
	if !_G.IsValid(ent) then return false end
	if _R.Entity.IsEffectActive(ent, _G.EF_NODRAW) or _R.Entity.GetRenderMode(ent) == _G.RENDERMODE_NONE or _R.Entity.GetRenderMode(ent) == _G.RENDERMODE_TRANSCOLOR or _R.Entity.GetColor(ent).a == 0 then return false end

	return ent != localplayer and _R.Player.Alive(ent) and _R.Player.Team(ent) != _G.TEAM_SPECTATOR and !_R.Entity.IsDormant(ent) and (aim.ignoreteam[2] or _R.Player.Team(ent) != _R.Player.Team(localplayer))
end

local function IsEntVisibleFromVec(ent, vec)
	local trace = _G.util.TraceLine({mask = _G.MASK_SHOT, ignoreworld = false, filter = localplayer, start = _R.Entity.EyePos(localplayer), endpos = vec})

	return trace.Entity == ent
end

local function CanFire()
	local wep = _R.Player.GetActiveWeapon(localplayer)

	if !_G.IsValid(wep) then return false end

	return _R.Weapon.Clip1(wep) > 0 and _R.Weapon.GetActivity(wep) != _G.ACT_RELOAD and _R.Weapon.GetNextPrimaryFire(wep) < curtime
end

local function HitboxPriority(tbl)
	return tbl[HITBOX_HEAD] or tbl[HITBOX_SPINE] or tbl[HITBOX_PELVIS] or tbl[HITBOX_L_THIGH] or tbl[HITBOX_R_THIGH] or tbl[HITBOX_L_ARM] or tbl[HITBOX_R_ARM] or tbl[HITBOX_L_CALF] or tbl[HITBOX_R_CALF] or tbl[HITBOX_L_FOREARM] or tbl[HITBOX_R_FOREARM] or tbl[HITBOX_L_FOOT] or tbl[HITBOX_R_FOOT] or tbl[HITBOX_L_HAND] or tbl[HITBOX_R_HAND] or tbl[HITBOX_L_TOE] or tbl[HITBOX_R_TOE] or _G.table.Random(tbl) or nil
end

local function MultiPoint(ent)
	local visible_vecs = {}
	local hitbox_sets = _R.Entity.GetHitboxSetCount(ent)

	for hitbox_set = 0, hitbox_sets - 1 do
		local hitboxes = _R.Entity.GetHitBoxCount(ent, hitbox_set)

		for hitbox = 0, hitboxes - 1 do
			local vec, ang = _R.Entity.GetBonePosition(ent, _R.Entity.GetHitBoxBone(ent, hitbox, hitbox_set))
			local min, max = _R.Entity.GetHitBoxBounds(ent, hitbox, hitbox_set)
			local offset = _G.Vector(_G.math.Rand(min.x, max.x), _G.math.Rand(min.y, max.y), _G.math.Rand(min.z, max.z))

			_R.Vector.Rotate(offset, ang)

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

	for k, v in _G.pairs(_G.player.GetAll()) do
		if IsValidTarget(v) then
			local ang = _R.Vector.Angle(_R.Entity.WorldSpaceCenter(v) - _R.Entity.EyePos(localplayer))
			local fov = _G.math.abs(_G.math.NormalizeAngle(false_ang.y - ang.y)) + _G.math.abs(_G.math.NormalizeAngle(false_ang.p - ang.p))

			if fov < closest_target.fov then
				local vec = MultiPoint(v)

				if vec then
					local ang = _R.Vector.Angle(vec - _R.Entity.EyePos(localplayer))

					_R.Angle.Normalize(ang)
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

	if IsValidTarget(target) and CanFire() and !_G.input.IsMouseDown(_G.MOUSE_LEFT) and (aim.ragemode[2] or (_G.input.IsButtonDown(aimtrig_key) and target.fov <= aim_fov)) then
		_R.CUserCmd.SetViewAngles(cmd, target.ang)
		_R.CUserCmd.AddKey(cmd, _G.IN_ATTACK)
	else
		_R.CUserCmd.SetViewAngles(cmd, false_ang)
	end
end

local function Triggerbot(cmd)
	if !aim.triggerbot[2] then return end

	local trace = _G.util.TraceLine({mask = _G.MASK_SHOT, start = _R.Entity.EyePos(localplayer), endpos = _R.Entity.EyePos(localplayer) + _R.Angle.Forward(_R.CUserCmd.GetViewAngles(cmd)) * 32768, filter = localplayer})

	if IsValidTarget(trace.Entity) and CanFire() and (aim.ragemode[2] or _G.input.IsButtonDown(aimtrig_key)) then
		_R.CUserCmd.AddKey(cmd, IN_ATTACK)
	end
end

local function MovementFix(cmd)
	if aim.aimbot[2] then
		local temp_false_ang = false_ang + _G.Angle(_R.CUserCmd.GetMouseY(cmd) * _R.ConVar.GetFloat(_G.GetConVar("m_pitch")), -_R.CUserCmd.GetMouseX(cmd) * _R.ConVar.GetFloat(_G.GetConVar("m_yaw")), 0)

		_R.Angle.Normalize(temp_false_ang)
		Clamp(temp_false_ang)

		false_ang = temp_false_ang

		local vec = _G.Vector(_R.CUserCmd.GetForwardMove(cmd), _R.CUserCmd.GetSideMove(cmd), 0)
		local vel = _G.math.sqrt(vec.x * vec.x + vec.y * vec.y)
		local mang = _R.Vector.Angle(vec)
		local yaw = _R.CUserCmd.GetViewAngles(cmd).y - false_ang.y + mang.y

		if ((_R.CUserCmd.GetViewAngles(cmd).p + 90) % 360) > 180 then
			yaw = 180 - yaw
		end

		yaw = ((yaw + 180) % 360) - 180

		_R.CUserCmd.SetForwardMove(cmd, _G.math.cos(_G.math.rad(yaw)) * vel)
		_R.CUserCmd.SetSideMove(cmd, _G.math.sin(_G.math.rad(yaw)) * vel)
	else
		false_ang = _R.Entity.EyeAngles(localplayer)
	end
end

local function Freecam(cmd)
	if visuals.freecam[2] then
		_R.CUserCmd.ClearMovement(cmd)

		local speed = 4

		if _R.CUserCmd.KeyDown(cmd, _G.IN_SPEED) then
			speed = speed * 2
		end

		if _R.CUserCmd.KeyDown(cmd, _G.IN_FORWARD) then
			false_vec = false_vec + _R.Angle.Forward(false_ang) * speed
		end

		if _R.CUserCmd.KeyDown(cmd, _G.IN_BACK) then
			false_vec = false_vec + _R.Angle.Forward(false_ang) * -speed
		end

		if _R.CUserCmd.KeyDown(cmd, _G.IN_MOVELEFT) then
			false_vec = false_vec + _R.Angle.Right(false_ang) * -speed
		end

		if _R.CUserCmd.KeyDown(cmd, _G.IN_MOVERIGHT) then
			false_vec = false_vec + _R.Angle.Right(false_ang) * speed
		end
	else
		false_vec = _R.Entity.EyePos(localplayer)
	end
end

local function AutoReload(cmd)
	local wep = _R.Player.GetActiveWeapon(localplayer)

	if aim.autoreload[2] and _G.IsValid(wep) then
		if wep.Primary then
			if _R.Weapon.Clip1(wep) == 0 and _R.Weapon.GetMaxClip1(wep) > 0 and _R.Player.GetAmmoCount(localplayer, _R.Weapon.GetPrimaryAmmoType(wep)) > 0 then
				_R.CUserCmd.AddKey(cmd, _G.IN_RELOAD)
			end
		end
	end
end

/*
	[movement]
*/
local function Autostrafe(cmd)
	if !movement.autostrafe[2] then return end

	if !_R.Entity.IsOnGround(localplayer) and _R.Entity.GetMoveType(localplayer) != _G.MOVETYPE_LADDER and _R.Entity.GetMoveType(localplayer) != _G.MOVETYPE_NOCLIP then
		_R.CUserCmd.SetForwardMove(cmd, 5850 / _R.Vector.Length2D(_R.Entity.GetVelocity(localplayer)))

		if _R.CUserCmd.CommandNumber(cmd) % 2 == 0 then
			_R.CUserCmd.SetSideMove(cmd, -_R.Vector.Length2D(_R.Entity.GetVelocity(localplayer)))
		elseif _R.CUserCmd.CommandNumber(cmd) % 2 != 0 then
			_R.CUserCmd.SetSideMove(cmd, _R.Vector.Length2D(_R.Entity.GetVelocity(localplayer)))
		end
	end
end

local function Autohop(cmd)
	if !movement.autohop[2] then return end

	if _R.CUserCmd.KeyDown(cmd, _G.IN_JUMP) and !_R.Entity.IsOnGround(localplayer) and _R.Entity.GetMoveType(localplayer) != _G.MOVETYPE_LADDER and _R.Entity.GetMoveType(localplayer) != _G.MOVETYPE_NOCLIP then
		_R.CUserCmd.RemoveKey(cmd, _G.IN_JUMP)
	end
end

local function HealthHack(cmd)
	if !_R.Player.Alive(localplayer) or CanFire() then return end

	if spawned_ents > 0 then
		_G.RunConsoleCommand("gmod_cleanup", "sents")

		spawned_ents = 0
	end

	if movement.autohealthkit[2] then
		if _R.Entity.Health(localplayer) < 100 then
			_R.CUserCmd.SetViewAngles(cmd, _G.Angle(89, _R.CUserCmd.GetViewAngles(cmd).y, 0))
			_R.CUserCmd.AddKey(cmd, _G.IN_USE)

			if _R.CUserCmd.GetViewAngles(cmd).p == 89 and _G.CurTime() > spawn_delay then
				_G.RunConsoleCommand("gm_spawnsent", "item_healthkit")

				spawned_ents = spawned_ents + 1
				spawn_delay = _G.CurTime() + 0.25
			end
		end
	end

	if movement.autosuitbattery[2] then
		if _R.Player.Armor(localplayer) < 100 then
			_R.CUserCmd.SetViewAngles(cmd, _G.Angle(89, _R.CUserCmd.GetViewAngles(cmd).y, 0))
			_R.CUserCmd.AddKey(cmd, _G.IN_USE)

			if _R.CUserCmd.GetViewAngles(cmd).p == 89 and _G.CurTime() > spawn_delay then
				_G.RunConsoleCommand("gm_spawnsent", "item_battery")

				spawned_ents = spawned_ents + 1
				spawn_delay = _G.CurTime() + 0.25
			end
		end
	end

	if movement.autohealthball[2] then
		if _R.Entity.Health(localplayer) < 1000 and _R.Entity.Health(localplayer) >= 100 then
			_R.CUserCmd.SetViewAngles(cmd, _G.Angle(89, _R.CUserCmd.GetViewAngles(cmd).y, 0))
			_R.CUserCmd.AddKey(cmd, _G.IN_USE)

			if _R.CUserCmd.GetViewAngles(cmd).p == 89 and _G.CurTime() > spawn_delay then
				_G.RunConsoleCommand("gm_spawnsent", "sent_ball")

				spawned_ents = spawned_ents + 1
				spawn_delay = _G.CurTime() + 0.25
			end
		end
	end
end

/*
	[visuals]
*/
local function Wallhack()
	if !visuals.wallhack[2] then return end

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

	for k, v in _G.pairs(_G.player.GetAll()) do
		if IsValidTarget(v) then
			_R.Entity.DrawModel(v)

			local wep = _R.Player.GetActiveWeapon(v)

			if _G.IsValid(wep) then
				_R.Entity.DrawModel(wep)
			end
		end
	end

	local col = InvertColor(color)

	_G.render.SetStencilCompareFunction(_G.STENCIL_EQUAL)
	_G.render.ClearBuffersObeyStencil(col.r, col.g, col.b, 255, false)
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

	for k, v in _G.pairs(_G.player.GetAll()) do
		if IsValidTarget(v) then
			_R.Entity.DrawModel(v)

			local wep = _R.Player.GetActiveWeapon(v)

			if _G.IsValid(wep) then
				_R.Entity.DrawModel(wep)
			end
		end
	end

	_G.render.SetStencilCompareFunction(_G.STENCIL_EQUAL)
	_G.render.ClearBuffersObeyStencil(color.r, color.g, color.b, 255, false)
	_G.render.SetStencilEnable(false)
end

local function ESP()
	if !visuals.esp[2] then return end

	_G.surface.SetFont("Default")

	for k, v in _G.pairs(_G.player.GetAll()) do
		if IsValidTarget(v) then
			local length = 6 + _G.select(1, _G.surface.GetTextSize(_R.Player.Name(v))) + 6
			local height = 6 + _G.select(2, _G.surface.GetTextSize(_R.Player.Name(v))) + 6
			local x = _R.Vector.ToScreen(_R.Entity.GetPos(v)).x - (length / 2)
			local y = _R.Vector.ToScreen(_R.Entity.EyePos(v) + _G.Vector(0, 0, 8)).y - height

			_G.surface.SetDrawColor(36, 36, 36, 225)
			_G.surface.DrawRect(x, y, length, height)

			_G.surface.SetDrawColor(color.r, color.g, color.b)
			_G.surface.DrawOutlinedRect(x, y, length, height, 1)

			_G.surface.SetTextColor(color.r, color.g, color.b)
			_G.surface.SetTextPos(x + 6, y + 6)
			_G.surface.DrawText(_R.Player.Name(v))
		end
	end
end

local function Crosshair()
	if !visuals.crosshair[2] then return end

	local xhair_length = 16
	local xhair_thickness = 2
	_G.surface.SetDrawColor(color.r, color.g, color.b)
	_G.surface.DrawRect((_G.ScrW() / 2) - (xhair_length / 2), (_G.ScrH() / 2) - (xhair_thickness / 2), xhair_length, xhair_thickness)
	_G.surface.DrawRect((_G.ScrW() / 2) - (xhair_thickness / 2), (_G.ScrH() / 2) - (xhair_length / 2), xhair_thickness, xhair_length)
end

/*
	[menu]
*/
local function Menu()
	if !menu then return end

	_G.surface.SetFont("Default")

	local mousex, mousey = _G.input.GetCursorPos()
	local window_title = "Meiware " .. build_info
	local window_size = _G.Vector(600, 400, 0)
	local window_pos = _G.Vector((_G.ScrW() / 2) - (window_size.x / 2), (_G.ScrH() / 2) - (window_size.y / 2), 0)
	local window_index = {
		["window"] = window_pos.y + 6 + _G.select(2, _G.surface.GetTextSize(window_title)) + 6,
		["aim"] = window_pos.y + 6 + _G.select(2, _G.surface.GetTextSize(window_title)) + 6 + 6,
		["visuals"] = window_pos.y + 6 + _G.select(2, _G.surface.GetTextSize(window_title)) + 6 + 6,
		["movement"] = window_pos.y + 6 + _G.select(2, _G.surface.GetTextSize(window_title)) + 6 + 6
	}

	_G.surface.SetDrawColor(_G.Color(36, 36, 36, 225))
	_G.surface.DrawRect(window_pos.x, window_pos.y, window_size.x, window_size.y)
	_G.surface.SetDrawColor(color)
	_G.surface.DrawOutlinedRect(window_pos.x, window_pos.y, window_size.x, window_size.y)

	_G.surface.SetTextColor(color.r, color.g, color.b)
	_G.surface.SetTextPos(window_pos.x + (window_size.x / 2) - (_G.select(1, _G.surface.GetTextSize(window_title)) / 2), window_pos.y + 6)
	_G.surface.DrawText(window_title)

	_G.surface.DrawOutlinedRect(window_pos.x + 6 + 72 + 6, window_pos.y + 6 + _G.select(2, _G.surface.GetTextSize(window_title)) + 6, window_size.x - 6 - 72 - 6 - 6, window_size.y - 6 - _G.select(2, _G.surface.GetTextSize(window_title)) - 6 - 6)

	local function AddTab(name)
		local x = window_pos.x + 6
		local y = window_index["window"]
		local w = 72
		local h = 48

		_G.surface.SetDrawColor(color)
		_G.surface.SetTextColor(color.r, color.g, color.b)

		if menu_activetab == name then
			local col = InvertColor(color)

			_G.surface.DrawRect(x, y, w, h)
			_G.surface.SetTextColor(col.r, col.g, col.b)
		else
			_G.surface.DrawOutlinedRect(x, y, w, h)
		end

		_G.surface.SetTextPos(x + (w / 2) - (_G.select(1, _G.surface.GetTextSize(name)) / 2), y + (h / 2) - (_G.select(2, _G.surface.GetTextSize(name)) / 2))
		_G.surface.DrawText(name)

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and _G.input.IsMouseDown(_G.MOUSE_LEFT) and _G.CurTime() > menu_delay then
			menu_activetab = name

			menu_delay = _G.CurTime() + 1
		end

		window_index["window"] = window_index["window"] + 48 + 6
	end

	local function AddToggle(var, tab)
		if tab != menu_activetab then return end

		local x = window_pos.x + 6 + 72 + 6 + 6
		local y = window_index[tab]
		local w = 24
		local h = 24

		_G.surface.SetTextColor(color.r, color.g, color.b)
		_G.surface.SetTextPos(x, y + (_G.select(2, _G.surface.GetTextSize(var[1])) / 2))
		_G.surface.DrawText(var[1])

		x = x + _G.select(1, _G.surface.GetTextSize(var[1])) + 6

		_G.surface.SetDrawColor(color)
		_G.surface.DrawOutlinedRect(x, y, w, h)

		if var[2] then
			_G.surface.SetDrawColor(color)
			_G.surface.DrawRect(x, y, w, h)
		end

		if mousex >= x and mousey >= y and mousex <= x + w and mousey <= y + h and _G.input.IsMouseDown(_G.MOUSE_LEFT) and _G.CurTime() > menu_delay then
			var[2] = !var[2]

			menu_delay = _G.CurTime() + 0.25
		end

		window_index[tab] = window_index[tab] + 24 + 6
	end

	AddTab("aim")
	AddTab("visuals")
	AddTab("movement")

	for k, v in _G.pairs(aim) do
		AddToggle(v, "aim")
	end

	for k, v in _G.pairs(visuals) do
		AddToggle(v, "visuals")
	end

	for k, v in _G.pairs(movement) do
		AddToggle(v, "movement")
	end
end

/*
	[hooks]
*/
_G.hook.Add("Think", GenerateID(), function()
	TargetFinder()
end)

_G.hook.Add("CreateMove", GenerateID(), function(cmd)
	Aimbot(cmd)
	MovementFix(cmd)
	Freecam(cmd)
	Triggerbot(cmd)
	Autostrafe(cmd)
	Autohop(cmd)
	AutoReload(cmd)
	HealthHack(cmd)
end)

_G.hook.Add("CalcView", GenerateID(), function(ply, origin, angles, fov, znear, zfar)
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

_G.hook.Add("CalcViewModelView", GenerateID(), function(wep, vm, oldPos, oldAng, pos, ang)
	if aim.aimbot[2] then
		ang = false_ang
	end

	return pos, ang
end)

_G.hook.Add("Move", GenerateID(), function(ply, mv)
	if !_G.IsFirstTimePredicted() then return end

	curtime = _G.CurTime() + _G.engine.TickInterval()
end)

_G.hook.Add("OnContextMenuOpen", GenerateID(), function()
	menu = true
end)

_G.hook.Add("OnContextMenuClose", GenerateID(), function()
	menu = false
end)

function GAMEMODE:PostRender()
	PostRender_old()

	_G.cam.Start3D()
	Wallhack() //no depth, TODO: fix depth
	_G.cam.End3D()

	_G.cam.Start2D()
	ESP()
	Crosshair()
	Menu()
	_G.cam.End2D()
end

_G.print("[Meiware] menu key: " .. _G.input.LookupBinding("+menu_context", true) .. ", aim/trigger key: " .. _G.input.GetKeyName(aimtrig_key))