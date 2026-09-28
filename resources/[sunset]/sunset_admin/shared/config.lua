SunsetAdmin = {}

SunsetAdmin.Levels = {
    [1] = 'Admin Level 1',
    [2] = 'Admin Level 2',
    [3] = 'Admin Level 3',
    [4] = 'Admin Level 4',
    [5] = 'Admin Level 5',
    [6] = 'Admin Level 6',
}

SunsetAdmin.HelperLevels = {
    [1] = 'Helper Level 1',
    [2] = 'Helper Level 2',
    [3] = 'Helper Level 3',
}

SunsetAdmin.Commands = {
    -- Admin rank 6
    setadmin = 6,
    sethelper = 6,

    -- Admin rank 5
    givemoney = 5,

    -- Admin rank 4+
    setleader = 4,
    giverpall = 4,
    setstat = 4,
    ahouseedit = 4,

    -- Admin rank 3+
    acreatehouse = 3,
    respawncars = 3,
    givegun = 3,
    unban = 3,
    dealershipadmin = 3,
    setjob = 3,
    setfaction = 3,
    setclan = 3,
    setjobstat = 3,
    givecar = 3,
    giveitem = 3,
    removeleader = 3,
    clearwarns = 3,
    sett = 3,
    setw = 3,
    ahealall = 3,
    fixall = 3,
    dvall = 3,

    -- Admin rank 2+
    ban = 2,
    banip = 2,
    tempban = 2,
    disarmarea = 2,
    sethparea = 2,
    ajail = 2,
    aunjail = 2,
    slap = 2,

    -- Admin rank 1+
    noclip = 1,
    aduty = 1,
    a = 1,
    cr = 1,
    kick = 1,
    mute = 1,
    warn = 1,
    spec = 1,
    spectate = 1,
    check = 1,
    astats = 1,
    anno = 1,
    freeze = 1,
    unfreeze = 1,
    ['goto'] = 1,
    mark = 1,
    gotomark = 1,
    disarm = 1,
    gethere = 1,
    gotocar = 1,
    getcar = 1,
    fixveh = 1,
    fix = 1,
    fixcar = 1,
    arepair = 1,
    arepaircar = 1,
    setvw = 1,
    sethp = 1,
    spawncar = 1,
    car = 1,
    entercar = 1,
    afklist = 1,
    togfind = 1,
    cc = 1,
    tp = 1,
    bring = 1,
    dv = 1,
    heal = 1,
    revive = 1,
    arespawn = 1,
    god = 1,
    coords = 1,
    dl = 1,
    reports = 1,
    history = 1,
    pullout = 1,
    tpcar = 1,
    bringcar = 1,
    tpback = 1,
    aclear = 1,
    gotoid = 1,
    givelicense = 1,
    agivelicense = 1,
    revokelicense = 1,
}

-- Commands accessible to helpers (level 1-3). Admins automatically pass.
-- hasPerm() checks this table when IsAdmin fails.
SunsetAdmin.HelperCommands = {
    -- Helper level 1+: player support tools
    reports  = 1,
    cr       = 1,
    heal     = 1,
    revive   = 1,
    afklist  = 1,
    aduty    = 1,
    coords   = 1,
    history  = 1,
    warn     = 1,
    mute     = 1,
    unmute   = 1,
    kick     = 1,
    -- Helper level 2+: advanced support
    check    = 2,
    astats   = 2,
    freeze   = 2,
    unfreeze = 2,
}

-- [SANCTIONS] Public/staff broadcast config (§3.5)
SunsetAdmin.Broadcast = {
    warn = true, kick = true, ban = true, unban = false, jail = true,
    showReason = { warn = true, kick = true, ban = true },
    cooldownSec = 2,
}
SunsetAdmin.WarnsBeforeStaffAlert = 3
SunsetAdmin.FreezeMaxSec = 600 -- auto-unfreeze failsafe

