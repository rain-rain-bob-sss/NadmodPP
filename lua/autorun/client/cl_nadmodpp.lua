-- =================================
-- NADMOD PP - Prop Protection
-- By Nebual@nebtown.info 2012
-- Menus designed after SpaceTech's Simple Prop Protection
-- =================================
if !NADMOD then 
	NADMOD = {}
	NADMOD.PropOwners = {}
	NADMOD.PropNames = {}
	NADMOD.PPConfig = {}
	NADMOD.Friends = {}
end

local Props = NADMOD.PropOwners
local PropNames = NADMOD.PropNames
net.Receive("nadmod_propowners",function(len)
	local nameMap = {}
	for i=1, net.ReadUInt(8) do
		nameMap[i] = {SteamID = net.ReadString(), Name = net.ReadString()}
	end
	for i=1, net.ReadUInt(32) do
		local id, owner = net.ReadUInt(16), nameMap[net.ReadUInt(8)]
		if owner.SteamID == "-" then Props[id] = nil PropNames[id] = nil
		elseif owner.SteamID == "W" then PropNames[id] = "World"
		elseif owner.SteamID == "O" then PropNames[id] = "Ownerless"
		else
			Props[id] = owner.SteamID
			PropNames[id] = owner.Name
		end
	end
end)

function NADMOD.GetPropOwner(ent)
	local id = Props[ent:EntIndex()]
	return id and player.GetBySteamID(id)
end

function NADMOD.PlayerCanTouch(ply, ent)
	-- If PP is off or the ent is worldspawn, let them touch it
	if not tobool(NADMOD.PPConfig["toggle"]) then return true end
	if ent:IsWorld() then return ent:GetClass()=="worldspawn" end
	if !IsValid(ent) or !IsValid(ply) or ent:IsPlayer() or !ply:IsPlayer() then return false end

	local index = ent:EntIndex()
	if not Props[index] then
		return false
	end

	-- Ownerless props can be touched by all
	if PropNames[index] == "Ownerless" then return true end 
	-- Admins can touch anyones props + world
	CAMI.PlayerHasAccess(ply,"npp_cte",function(e) ply.CanTouchAll=e end)
	if NADMOD.PPConfig["adminall"] and NADMOD.IsPPAdmin(ply) or ply.CanTouchAll then return true end
	-- Players can touch their own props
	local plySteam = ply:SteamID()
	if Props[index] == plySteam then return true end
	-- Friends can touch LocalPlayer()'s props
	if Props[index] == LocalPlayer():SteamID() and NADMOD.Friends[plySteam] then return true end

	return false
end

-- Does your admin mod not seem to work with Nadmod PP? Try overriding this function!
function NADMOD.IsPPAdmin(ply)
	if NADMOD.HasPermission then
		return NADMOD.HasPermission(ply, "PP_All")
	else
		-- If the admin mod NADMOD isn't present, just default to using IsAdmin
		return ply:IsAdmin()
	end
end

local nadmod_overlay_convar = CreateConVar("nadmod_overlay", 2, {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "0 - Disables NPP Overlay. 1 - Minimal overlay of just owner info. 2 - Includes model, entityID, class.")
local font = "ChatFont"
hook.Add("HUDPaint", "NADMOD.HUDPaint", function()
	local nadmod_overlay_setting = nadmod_overlay_convar:GetInt()
	if nadmod_overlay_setting == 0 then return end
	local tr = LocalPlayer():GetEyeTrace()
	if !tr.HitNonWorld then return end
	local ent = tr.Entity
	if ent:IsValid() && !ent:IsPlayer() then
		local text = "Owner: " .. (PropNames[ent:EntIndex()] or "N/A")
		surface.SetFont(font)
		local Width, Height = surface.GetTextSize(text)
		local boxWidth = Width + 25
		local boxHeight = Height + 16
		if nadmod_overlay_setting > 1 then
			local text2 = "'"..string.sub(table.remove(string.Explode("/", ent:GetModel() or "?")), 1,-5).."' ["..ent:EntIndex().."]"
			local text3 = ent:GetClass()
			local w2,h2 = surface.GetTextSize(text2)
			local w3,h3 = surface.GetTextSize(text3)
			boxWidth = math.Max(Width,w2,w3) + 25
			boxHeight = boxHeight + h2 + h3
			draw.RoundedBox(4, ScrW() - (boxWidth + 4), (ScrH()/2 - 200) - 16, boxWidth, boxHeight, Color(0, 0, 0, 150))
			draw.SimpleText(text, font, ScrW() - (Width / 2) - 20, ScrH()/2 - 200, Color(255, 255, 255, 255), 1, 1)
			draw.SimpleText(text2, font, ScrW() - (w2 / 2) - 20, ScrH()/2 - 200 + Height, Color(255, 255, 255, 255), 1, 1)
			draw.SimpleText(text3, font, ScrW() - (w3 / 2) - 20, ScrH()/2 - 200 + Height + h2, Color(255, 255, 255, 255), 1, 1)
		else
			draw.RoundedBox(4, ScrW() - (boxWidth + 4), (ScrH()/2 - 200) - 16, boxWidth, boxHeight, Color(0, 0, 0, 150))
			draw.SimpleText(text, font, ScrW() - (Width / 2) - 20, ScrH()/2 - 200, Color(255, 255, 255, 255), 1, 1)
		end
	end
end)

function NADMOD.CleanCLRagdolls()
	for k,v in pairs(ents.FindByClass("class C_ClientRagdoll")) do v:SetNoDraw(true) end
	for k,v in pairs(ents.FindByClass("class C_BaseAnimating")) do v:SetNoDraw(true) end
end
net.Receive("nadmod_cleanclragdolls", NADMOD.CleanCLRagdolls)

-- =============================
-- NADMOD PP CPanels
-- =============================
net.Receive("nadmod_ppconfig",function(len)
	NADMOD.PPConfig = net.ReadTable()
	for k,v in pairs(NADMOD.PPConfig) do
		local val = v
		if isbool(v) then val = v and "1" or "0" end
		
		CreateClientConVar("npp_"..k,val, false, false)
		RunConsoleCommand("npp_"..k,val)
	end
	NADMOD.AdminPanel(NADMOD.AdminCPanel, true)
end)

concommand.Add("npp_apply",function(ply,cmd,args)
	for k,v in pairs(NADMOD.PPConfig) do
		if isbool(v) then NADMOD.PPConfig[k] = GetConVar("npp_"..k):GetBool()
		elseif isnumber(v) then NADMOD.PPConfig[k] = GetConVarNumber("npp_"..k)
		else NADMOD.PPConfig[k] = GetConVarString("npp_"..k)
		end
	end
	net.Start("nadmod_ppconfig")
		net.WriteTable(NADMOD.PPConfig)
	net.SendToServer()
end)

function NADMOD.AdminPanel(Panel, runByNetReceive)
	if(not IsValid(Panel))then return end 
	if !NADMOD.AdminCPanel then NADMOD.AdminCPanel = Panel end
	Panel:ClearControls()

	local nonadmin_help = Panel:Help("")
	nonadmin_help:SetAutoStretchVertical(false)
	if not runByNetReceive then 
		RunConsoleCommand("npp_refreshconfig")
		timer.Create("NADMOD.AdminPanelCheckFail",0.75,1,function()
			nonadmin_help:SetText("Waiting for the server to say you're an admin...")
		end)
		if not NADMOD.PPConfig then
			return
		end
	else
		timer.Remove("NADMOD.AdminPanelCheckFail")
	end
	Panel:SetName("NADMOD PP Admin Panel")
	
	Panel:CheckBox(	"Main PP Power Switch", "npp_toggle")
	Panel:CheckBox(	"Admins can touch anything", "npp_adminall")
	local use_protection = Panel:CheckBox(	"Use (E) Protection", "npp_use")
	use_protection:SetToolTip("Stop nonfriends from entering vehicles, pushing buttons/doors")
	
	local txt = Panel:Help("Autoclean Disconnected Players?")
	txt:SetAutoStretchVertical(false)
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	local autoclean_admins = Panel:CheckBox(	"Autoclean Admins", "npp_autocdpadmins")
	autoclean_admins:SetToolTip("Should Admin Props also be autocleaned?")
	local noownworld = Panel:CheckBox(	"Disallow owning world props", "npp_noownworld")
	local autoclean_timer = Panel:NumSlider("Autoclean Timer", "npp_autocdp", 0, 1200, 0 )
	autoclean_timer:SetToolTip("0 disables autocleaning")
	Panel:Button(	"Apply Settings", "npp_apply") 
	
	local txt = Panel:Help("                     Cleanup Panel")
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SetFont("DermaDefaultBold")
	txt:SetAutoStretchVertical(false)
	
	local counts = {}
	for k,v in pairs(NADMOD.PropOwners) do 
		counts[v] = (counts[v] or 0) + 1 
	end
	local dccount = 0
	for k,v in pairs(counts) do
		if k != "World" and k != "Ownerless" then dccount = dccount + v end
	end
	for k, ply in pairs(player.GetAll()) do
		if IsValid(ply) then
			local steamid = ply:SteamID()
			Panel:Button( ply:Nick().." ("..(counts[steamid] or 0)..")", "nadmod_cleanupprops", ply:EntIndex() ) 
			dccount = dccount - (counts[steamid] or 0)
		end
	end
	
	Panel:Help(""):SetAutoStretchVertical(false) -- Spacer
	Panel:Button("Cleanup Disconnected Players Props ("..dccount..")", "nadmod_cdp")
	Panel:Button("Cleanup All NPCs", 			"nadmod_cleanclass", "npc_*")
	Panel:Button("Cleanup All Ragdolls", 		"nadmod_cleanclass", "prop_ragdol*")
	Panel:Button("Cleanup Clientside Ragdolls", "nadmod_cleanclragdolls")
	Panel:Button("Cleanup World Ropes", "nadmod_cleanworldropes")
end

local metaply = FindMetaTable("Player")
local metaent = FindMetaTable("Entity")

-- Wrapper function as Bots return nothing clientside for their SteamID64
function metaply:SteamID64bot()
	if( not IsValid( self ) ) then return end
	if self:IsBot() then
		-- Calculate Bot's SteamID64 according to gmod wiki
		return  ( 90071996842377216 + tonumber( string.sub( self:Nick(), 4) )or 1 -1 )
	else
		return self:SteamID64()
	end
end

net.Receive("nadmod_ppfriends",function(len)
	NADMOD.Friends = net.ReadTable()
	for _,tar in pairs(player.GetAll()) do
		CreateClientConVar("npp_friend_"..tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0", false, false)
		RunConsoleCommand("npp_friend_"..tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0")
	end
end)

concommand.Add("npp_applyfriends",function(ply,cmd,args)
	for _,tar in pairs(player.GetAll()) do
		NADMOD.Friends[tar:SteamID()] = GetConVar("npp_friend_"..tar:SteamID64bot()):GetBool()
	end
	net.Start("nadmod_ppfriends")
		net.WriteTable(NADMOD.Friends)
	net.SendToServer()
end)

function NADMOD.ClientPanel(Panel)
	if(not IsValid(Panel))then return end 
	RunConsoleCommand("npp_refreshfriends")
	Panel:ClearControls()
	if !NADMOD.ClientCPanel then NADMOD.ClientCPanel = Panel end
	Panel:SetName("NADMOD - Client Panel")
	
	Panel:Button("Cleanup Props", "nadmod_cleanupprops")
	Panel:Button("Clear Clientside Ragdolls", "nadmod_cleanclragdolls")
	local overlay = Panel:NumSlider("Overlay", "nadmod_overlay", 0,2, 0 )
	
	local txt = Panel:Help("                     Friends Panel")
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SetFont("DermaDefaultBold")
	txt:SetAutoStretchVertical(false)
	
	local Players = player.GetAll()
	if(table.Count(Players) == 1) then
		Panel:Help("No Other Players Are Online")
	else
		for _, tar in pairs(Players) do
			if(IsValid(tar) and tar != LocalPlayer()) then
				Panel:CheckBox(tar:Nick(), "npp_friend_"..tar:SteamID64bot())
			end
		end
		Panel:Button("Apply Friends", "npp_applyfriends")
	end
end

function NADMOD.SpawnMenuOpen()
	if IsValid(NADMOD.AdminCPanel) then
		NADMOD.AdminPanel(NADMOD.AdminCPanel)
	end
	if IsValid(NADMOD.ClientCPanel) then
		NADMOD.ClientPanel(NADMOD.ClientCPanel)
	end
end
hook.Add("SpawnMenuOpen", "NADMOD.SpawnMenuOpen", NADMOD.SpawnMenuOpen)

function NADMOD.PopulateToolMenu()
	spawnmenu.AddToolMenuOption("Utilities", "NADMOD Prop Protection", "Admin", "Admin", "", "", NADMOD.AdminPanel)
	spawnmenu.AddToolMenuOption("Utilities", "NADMOD Prop Protection", "Client", "Client", "", "", NADMOD.ClientPanel)
end
hook.Add("PopulateToolMenu", "NADMOD.PopulateToolMenu", NADMOD.PopulateToolMenu)

net.Receive("nadmod_notify", function(len)
	local text = net.ReadString()
	notification.AddLegacy(text, NOTIFY_GENERIC, 5)
	surface.PlaySound("ambient/water/drip"..math.random(1, 4)..".wav")
	--print(text)
end)

CPPI = {}
CPPI_NOTIMPLEMENTED=-1
CPPI_DEFER=0
function CPPI:GetName() return "Nadmod Prop Protection" end
function CPPI:GetVersion() return "" end
function CPPI:InterfaceVersion() return 1.3 end
--function metaply:CPPIGetFriends() return CPPI_NOTIMPLEMENTED end
function metaply:CPPIGetFriends() return {} end
function metaent:CPPIGetOwner() return NADMOD.GetPropOwner(self) end
function metaent:CPPICanTool(ply,mode) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPhysgun(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPickup(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPunt(ply) return NADMOD.PlayerCanTouch(ply,self) end
hook.Add("Initialize","temp_NPP",function()
	hook.Remove("Initialize","temp_NPP")
	if(ULib)then return end
	if(CAMI)then
		if(CAMI.RegisterPrivilege)then
			CAMI.RegisterPrivilege({Name="npp_cte",Description="Can Touch Everything",MinAccess="superadmin"})
			CAMI.RegisterPrivilege({Name="npp_dcl",Description="Dont auto clean",MinAccess="superadmin"})
		end
	end
end)