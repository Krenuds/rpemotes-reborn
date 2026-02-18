-- Console-only debug commands for ped emote system testing.
-- Loaded after PedEmoteManager.lua; consumes PedEmoteManagerAPI global.

local API = PedEmoteManagerAPI
local pedPlayEmote     = API.pedPlayEmote
local pedCancelEmote   = API.pedCancelEmote
local pedGetState      = API.pedGetState
local pedUntrack       = API.pedUntrack
local pedSetWalkstyle  = API.pedSetWalkstyle
local pedSetExpression = API.pedSetExpression

local EmoteDataLookup      = API.EmoteDataLookup
local WalkDataLookup       = API.WalkDataLookup
local ExpressionDataLookup = API.ExpressionDataLookup

local TestPeds = {}

RegisterCommand('ped_spawn', function(source, args)
    if source > 0 then return end
    local playerId = tonumber(args[1])
    if not playerId then print("^1Usage: ped_spawn <player_id>^0") return end

    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then print("^1Player not found^0") return end

    -- Clean up previous test peds
    for _, ped in ipairs(TestPeds) do
        if DoesEntityExist(ped) then
            pedUntrack(ped)
            DeleteEntity(ped)
        end
    end
    TestPeds = {}

    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local models = {
        { GetHashKey('mp_m_freemode_01'), 'Freemode M1' },
        { GetHashKey('mp_m_freemode_01'), 'Freemode M2' },
        { GetHashKey('mp_f_freemode_01'), 'Freemode F1' },
        { GetHashKey('mp_f_freemode_01'), 'Freemode F2' },
        { GetHashKey('a_m_y_hipster_01'), 'Male Hipster' },
        { GetHashKey('a_f_y_hipster_01'), 'Female Hipster' },
    }

    local offsets = {
        {2.0, 0.0}, {-2.0, 0.0}, {0.0, 2.0}, {0.0, -2.0}, {2.0, 2.0}, {-2.0, -2.0},
    }

    for i, m in ipairs(models) do
        local o = offsets[i]
        local ped = CreatePed(4, m[1], coords.x + o[1], coords.y + o[2], coords.z, heading, true, true)
        FreezeEntityPosition(ped, true)
        TestPeds[#TestPeds + 1] = ped
        print(("^2[test] [%d] Spawned %s — entity %d^0"):format(i, m[2], ped))
    end

    print(("^2[test] Spawned %d test peds^0"):format(#TestPeds))
end, true)

RegisterCommand('ped_emote', function(source, args)
    if source > 0 then return end
    local emoteName = args[1]
    if not emoteName then print("^1Usage: ped_emote <name> [index]^0") return end

    local idx = tonumber(args[2])
    if idx then
        local ped = TestPeds[idx]
        if not ped then print("^1No ped at index " .. idx .. "^0") return end
        print(("^2[test] pedPlayEmote(%d, '%s') = %s^0"):format(ped, emoteName, tostring(pedPlayEmote(ped, emoteName))))
    else
        for i, ped in ipairs(TestPeds) do
            print(("^2[test] [%d] pedPlayEmote(%d, '%s') = %s^0"):format(i, ped, emoteName, tostring(pedPlayEmote(ped, emoteName))))
        end
    end
end, true)

RegisterCommand('ped_cancel', function(source, args)
    if source > 0 then return end
    local idx = tonumber(args[1])
    if idx then
        local ped = TestPeds[idx]
        if not ped then print("^1No ped at index " .. idx .. "^0") return end
        pedCancelEmote(ped)
        print(("^2[test] Cancelled ped %d^0"):format(ped))
    else
        for _, ped in ipairs(TestPeds) do pedCancelEmote(ped) end
        print("^2[test] Cancelled all^0")
    end
end, true)

RegisterCommand('ped_walk', function(source, args)
    if source > 0 then return end
    local walkName = args[1]
    if not walkName then print("^1Usage: ped_walk <name> [index]^0") return end

    local idx = tonumber(args[2])
    if idx then
        local ped = TestPeds[idx]
        if not ped then print("^1No ped at index " .. idx .. "^0") return end
        print(("^2[test] pedSetWalkstyle(%d, '%s') = %s^0"):format(ped, walkName, tostring(pedSetWalkstyle(ped, walkName))))
    else
        for i, ped in ipairs(TestPeds) do
            print(("^2[test] [%d] pedSetWalkstyle(%d, '%s') = %s^0"):format(i, ped, walkName, tostring(pedSetWalkstyle(ped, walkName))))
        end
    end
end, true)

RegisterCommand('ped_expr', function(source, args)
    if source > 0 then return end
    local exprName = args[1]
    if not exprName then print("^1Usage: ped_expr <name> [index]^0") return end

    local idx = tonumber(args[2])
    if idx then
        local ped = TestPeds[idx]
        if not ped then print("^1No ped at index " .. idx .. "^0") return end
        print(("^2[test] pedSetExpression(%d, '%s') = %s^0"):format(ped, exprName, tostring(pedSetExpression(ped, exprName))))
    else
        for i, ped in ipairs(TestPeds) do
            print(("^2[test] [%d] pedSetExpression(%d, '%s') = %s^0"):format(i, ped, exprName, tostring(pedSetExpression(ped, exprName))))
        end
    end
end, true)

RegisterCommand('ped_list', function(source, args)
    if source > 0 then return end
    if #TestPeds == 0 then print("^3[test] No test peds^0") return end
    for i, ped in ipairs(TestPeds) do
        local exists = DoesEntityExist(ped)
        local st = pedGetState(ped)
        print(("^2[test] [%d] entity=%d exists=%s emote=%s walk=%s expr=%s^0"):format(
            i, ped, tostring(exists),
            st and st.emoteName or 'none',
            st and st.walk or 'none',
            st and st.expression or 'none'
        ))
    end
end, true)

RegisterCommand('ped_cleanup', function(source, args)
    if source > 0 then return end
    for _, ped in ipairs(TestPeds) do
        pedUntrack(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    TestPeds = {}
    print("^2[test] All test peds cleaned up^0")
end, true)

-- Delete all non-player peds within radius of a player
RegisterCommand('ped_nuke', function(source, args)
    if source > 0 then return end
    local playerId = tonumber(args[1])
    local radius = tonumber(args[2]) or 10.0
    if not playerId then print("^1Usage: ped_nuke <player_id> [radius]^0") return end

    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then print("^1Player not found^0") return end

    local coords = GetEntityCoords(playerPed)
    local r2 = radius * radius
    local players = {}
    for _, src in ipairs(GetPlayers()) do
        players[GetPlayerPed(tonumber(src))] = true
    end

    local count = 0
    for _, p in ipairs(GetAllPeds()) do
        if not players[p] and DoesEntityExist(p) then
            local pc = GetEntityCoords(p)
            local dx, dy, dz = pc.x - coords.x, pc.y - coords.y, pc.z - coords.z
            if (dx*dx + dy*dy + dz*dz) < r2 then
                DeleteEntity(p)
                count = count + 1
            end
        end
    end

    for i = #TestPeds, 1, -1 do
        if not DoesEntityExist(TestPeds[i]) then
            table.remove(TestPeds, i)
        end
    end

    print(("^2[test] Nuked %d peds within %.0fm^0"):format(count, radius))
end, true)

-- Collect emote names by filter from the indexed lookup tables
local function collectEmoteNames(filter)
    local names = {}
    for _, entry in pairs(EmoteDataLookup) do
        if not filter or filter(entry) then
            names[#names + 1] = entry.name
        end
    end
    return names
end

local function collectWalkNames()
    local names = {}
    for _, entry in pairs(WalkDataLookup) do
        names[#names + 1] = entry.name
    end
    return names
end

local function collectExpressionNames()
    local names = {}
    for _, entry in pairs(ExpressionDataLookup) do
        names[#names + 1] = entry.name
    end
    return names
end

-- Cycling state
local CycleState = { active = false, token = 0 }

local function stopCycling()
    CycleState.active = false
    CycleState.token = CycleState.token + 1
end

local function startCycle(label, items, interval, applyFn)
    stopCycling()
    if #items == 0 then
        print("^1[test] No items to cycle^0")
        return
    end
    if #TestPeds == 0 then
        print("^1[test] No test peds — run ped_spawn first^0")
        return
    end

    CycleState.active = true
    local token = CycleState.token
    local idx = 0

    print(("^2[test] Cycling %d %s every %ds on %d peds^0"):format(#items, label, interval / 1000, #TestPeds))

    CreateThread(function()
        while CycleState.active and CycleState.token == token do
            idx = (idx % #items) + 1
            print(("^3[test] [%d/%d] %s^0"):format(idx, #items, label))

            -- Each ped gets a different random item
            for i, ped in ipairs(TestPeds) do
                if DoesEntityExist(ped) then
                    local item = items[math.random(#items)]
                    applyFn(ped, item)
                end
            end

            Wait(interval)
        end
    end)
end

RegisterCommand('ped_cycle', function(source, args)
    if source > 0 then return end
    local category = args[1]
    local interval = (tonumber(args[2]) or 5) * 1000

    if not category then
        print("^1Usage: ped_cycle <emotes|dances|props|ptfx|walks|expr|all> [seconds]^0")
        return
    end

    category = string.lower(category)

    if category == 'emotes' then
        local items = collectEmoteNames(function(e) return e.emoteType == EmoteType.EMOTES end)
        startCycle('emotes', items, interval, function(ped, name) pedPlayEmote(ped, name) end)

    elseif category == 'dances' then
        local items = collectEmoteNames(function(e) return e.emoteType == EmoteType.DANCES end)
        startCycle('dances', items, interval, function(ped, name) pedPlayEmote(ped, name) end)

    elseif category == 'props' then
        local items = collectEmoteNames(function(e)
            return e.AnimationOptions and e.AnimationOptions.Prop
        end)
        startCycle('prop emotes', items, interval, function(ped, name) pedPlayEmote(ped, name) end)

    elseif category == 'ptfx' then
        local items = collectEmoteNames(function(e)
            return e.AnimationOptions and e.AnimationOptions.PtfxAsset
        end)
        startCycle('PTFX emotes', items, interval, function(ped, name) pedPlayEmote(ped, name) end)

    elseif category == 'walks' then
        local items = collectWalkNames()
        startCycle('walks', items, interval, function(ped, name) pedSetWalkstyle(ped, name) end)

    elseif category == 'expr' then
        local items = collectExpressionNames()
        startCycle('expressions', items, interval, function(ped, name) pedSetExpression(ped, name) end)

    elseif category == 'all' then
        -- Cycle emotes from every category
        local items = collectEmoteNames()
        startCycle('ALL emotes', items, interval, function(ped, name) pedPlayEmote(ped, name) end)

    else
        print("^1Unknown category: " .. category .. "^0")
        print("^1Options: emotes, dances, props, ptfx, walks, expr, all^0")
    end
end, true)

RegisterCommand('ped_cycle_stop', function(source)
    if source > 0 then return end
    stopCycling()
    print("^2[test] Cycling stopped^0")
end, true)

-- Each ped gets a different random emote + walk + expression
RegisterCommand('ped_random', function(source, args)
    if source > 0 then return end
    if #TestPeds == 0 then print("^1[test] No test peds — run ped_spawn first^0") return end
    stopCycling()

    local emotes = collectEmoteNames(function(e)
        return e.dict and (e.emoteType == EmoteType.EMOTES or e.emoteType == EmoteType.DANCES or e.emoteType == EmoteType.PROP_EMOTES)
    end)
    local walks = collectWalkNames()
    local exprs = collectExpressionNames()

    for i, ped in ipairs(TestPeds) do
        if DoesEntityExist(ped) then
            local e = emotes[math.random(#emotes)]
            local w = walks[math.random(#walks)]
            local x = exprs[math.random(#exprs)]
            pedSetWalkstyle(ped, w)
            pedSetExpression(ped, x)
            pedPlayEmote(ped, e)
            print(("^2[test] [%d] emote=%s walk=%s expr=%s^0"):format(i, e, w, x))
        end
    end
end, true)

-- Continuous random shuffle — every interval each ped gets a new random combo
RegisterCommand('ped_chaos', function(source, args)
    if source > 0 then return end
    if #TestPeds == 0 then print("^1[test] No test peds — run ped_spawn first^0") return end

    local interval = (tonumber(args[1]) or 5) * 1000
    stopCycling()

    local emotes = collectEmoteNames(function(e)
        return e.dict and (e.emoteType == EmoteType.EMOTES or e.emoteType == EmoteType.DANCES or e.emoteType == EmoteType.PROP_EMOTES)
    end)
    local walks = collectWalkNames()
    local exprs = collectExpressionNames()

    CycleState.active = true
    local token = CycleState.token

    print(("^2[test] Chaos mode — shuffling %d peds every %ds^0"):format(#TestPeds, interval / 1000))

    CreateThread(function()
        while CycleState.active and CycleState.token == token do
            for i, ped in ipairs(TestPeds) do
                if DoesEntityExist(ped) then
                    pedSetWalkstyle(ped, walks[math.random(#walks)])
                    pedSetExpression(ped, exprs[math.random(#exprs)])
                    pedPlayEmote(ped, emotes[math.random(#emotes)])
                end
            end
            Wait(interval)
        end
    end)
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    stopCycling()

    for _, ped in ipairs(TestPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    TestPeds = {}
end)
