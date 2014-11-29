--[[

  Zombie outbreak mode: you get chaingun to stop a horde of bots with rockets and grenades, in slow motion.
  Mode needs to be efficteam or tacteam.

]]--

local fp, lambda, iterators, playermsg, putf = require"utils.fp", require"utils.lambda", require"std.iterators", require"std.playermsg", require"std.putf"
local map, range, breakk, L, Lr = fp.map, fp.range, fp.breakk, lambda.L, lambda.Lr

local module = {}
local hooks, active, oldbalance = {}

local function spawnzombie()
  local added = server.aiman.addai(0, -1)
  if not added then return end
  map.nf(L"_.name = 'zombie' _.team = 'evil'", iterators.bots())
end

local function blockteams(info)
  if not active or info.skip or info.ci.privilege >= server.PRIV_ADMIN then return end
  info.skip = true
  playermsg("Only admins can set teams in zombie mode", info.ci)
end

local function changeteam(ci, team)
  ci.team = engine.filtertext(team, false):sub(1, server.MAXTEAMLEN)
  server.addteaminfo(ci.team)
  server.aiman.changeteam(ci)
  engine.sendpacket(-1 ,1, putf({ 10, engine.ENET_PACKET_FLAG_RELIABLE }, server.N_SETTEAM, ci.clientnum, ci.team, -1):finalize(), -1)
end

function module.on(speed, spawninterval)
  map.np(L"spaghetti.removehook(_2)", hooks)
  hooks = {}
  if not speed then cs.serverbotbalance, oldbalance = oldbalance or cs.serverbotbalance return end

  hooks.changemap = spaghetti.addhook("changemap", function()
    active = server.m_teammode and (server.m_efficiency or server.m_tactics)
    if not active then cs.serverbotbalance, oldbalance = oldbalance or cs.serverbotbalance return end
    oldbalance = cs.serverbotbalance
    cs.serverbotbalance = 0
    spaghetti.latergame(3000, L"server.sendservmsg('\f3ZOMBIE OUTBREAK IN 10 SECONDS\f7! Take cover!\\n\f0Chainsaw is instakill\f7!')")
    spaghetti.latergame(10000, L"server.sendservmsg('\f3Zombies in \f23...')")
    spaghetti.latergame(11000, L"server.sendservmsg('\f22...')")
    spaghetti.latergame(12000, L"server.sendservmsg('\f21...')")
    spaghetti.latergame(13000, function()
      server.changegamespeed(speed, nil)
      server.sendservmsg('\f3Kill the zombies!')
      spawnzombie()
      spaghetti.latergame(spawninterval, spawnzombie, true)
    end)
    server.addteaminfo("good") server.addteaminfo("evil")
    map.nf(function(ci) changeteam(ci, "good") server.sendspawn(ci) end, iterators.clients())
  end)

  hooks.setteam = spaghetti.addhook(server.N_SETTEAM, blockteams)
  hooks.switchteam = spaghetti.addhook(server.N_SWITCHTEAM, blockteams)
  hooks.delbot = spaghetti.addhook(server.N_DELBOT, function(info)
    if not active or info.skip or info.ci.privilege >= server.PRIV_ADMIN then return end
    info.skip = true
    playermsg("Only admins can delete zombies", info.ci)
  end)
  hooks.addbot = spaghetti.addhook(server.N_ADDBOT, function(info)
    if not active or info.skip then return end
    info.skip = true
    if info.ci.privilege < server.PRIV_ADMIN then playermsg("Only admins can add zombies", info.ci) end
    server.aiman.reqadd(info.ci, info.skill)
    map.nf(L"_.name = 'zombie' _.team = 'evil'", iterators.bots())
  end)
  hooks.botbalance = spaghetti.addhook(server.N_BOTBALANCE, function(info)
    if not active or info.skip then return end
    info.skip = true
    playermsg("Bot balance cannot be set in zombie mode", info.ci)
  end)

  hooks.damaged = spaghetti.addhook("notalive", function(info)
    local ci = info.ci
    if not active or ci.team ~= "good" or ci.state.state ~= engine.CS_DEAD then return end
    changeteam(ci, "evil")
    local hasgoods
    map.nf(function(ci) if ci.team == "good" then hasgoods = true breakk() end end, iterators.players())
    if hasgoods then server.sendservmsg(server.colorname(ci, nil) .. " is now \f3zombie\f7!")
    else
      engine.sendpacket(-1, 1, putf({ 10, engine.ENET_PACKET_FLAG_RELIABLE }, server.N_TEAMINFO, "evil", 666, "good", 0, ""):finalize(), -1)
      server.startintermission()
      server.sendservmsg("\f3" .. server.colorname(ci, nil) .. " died\f7, all hope is lost!")
    end
  end)
  hooks.spawnstate = spaghetti.addhook("spawnstate", function(info)
    if not active or info.skip then return end
    info.skip = true
    local st = info.ci.state
    for i = 0, server.NUMGUNS - 1 do st.ammo[i] = 0 end
    if info.ci.team == "good" then st.ammo[server.GUN_CG], st.gunselect, st.health = 9999, server.GUN_CG, 200
    else st.ammo[server.GUN_RL], st.ammo[server.GUN_GL], st.gunselect, st.health = 9999, 9999, server.GUN_RL, 90 end
    st.ammo[server.GUN_FIST], st.lifesequence, st.armourtype, st.armour = 1, (st.lifesequence + 1) % 0x80, server.A_BLUE, 0
  end)
  hooks.dodamage = spaghetti.addhook("dodamage", function(info)
    if not active or info.skip or info.actor.team ~= "good" or info.target.team ~= "evil" or info.gun ~= server.GUN_FIST then return end
    info.damage = 90
  end)

  hooks.connected = spaghetti.addhook("connected", function(info)
    if not active then return end
    changeteam(info.ci, "good")
    server.sendspawn(info.ci)
  end)
  hooks.spectator = spaghetti.addhook(server.N_SPECTATOR, function(info)
    if not active or info.skip or info.ci.privilege >= server.PRIV_ADMIN or not info.val then return end
    info.skip = true
    playermsg("There is no hiding!", info.ci)
  end)
  hooks.disconnect = spaghetti.addhook("clientdisconnect", function() return active and server.numclients(-1, true, true, false) == 1 and server.checkvotes(true) end)

end

return module