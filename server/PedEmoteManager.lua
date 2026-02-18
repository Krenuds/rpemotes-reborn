local PedStates = {}
local EmoteDataLookup = {}
local WalkDataLookup = {}
local ExpressionDataLookup = {}

local EmoteCategories = {
    Emotes       = EmoteType.EMOTES,
    PropEmotes   = EmoteType.PROP_EMOTES,
    Dances       = EmoteType.DANCES,
    AnimalEmotes = EmoteType.ANIMAL_EMOTES,
    Exits        = EmoteType.EXITS,
    Shared       = EmoteType.SHARED,
}

local function loadAnimFile(path, returnVar)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw then return nil end

    local f, err = load(raw .. " return " .. returnVar)
    if err then
        print(("^1[rpemotes:ped] Syntax error in %s: %s^0"):format(path, tostring(err)))
        return nil
    end

    local ok, result = pcall(f)
    if not ok then
        print(("^1[rpemotes:ped] Runtime error in %s: %s^0"):format(path, tostring(result)))
        return nil
    end

    return result
end

local function indexEmoteCategory(categoryName, emoteTable)
    local eType = EmoteCategories[categoryName]
    local count = 0
    for name, data in pairs(emoteTable) do
        local entry = {
            name      = name,
            emoteType = eType,
        }

        if type(data[1]) == "string" then
            if data[1] == ScenarioType.MALE
                or data[1] == ScenarioType.SCENARIO
                or data[1] == ScenarioType.OBJECT
            then
                entry.scenario     = data[2]
                entry.scenarioType = data[1]
            else
                entry.dict = data[1]
                entry.anim = data[2]
            end
        end

        if data.dict         then entry.dict         = data.dict end
        if data.anim         then entry.anim         = data.anim end
        if data.scenario     then entry.scenario     = data.scenario end
        if data.scenarioType then entry.scenarioType = data.scenarioType end

        entry.label              = data[3] or data.label or name
        entry.secondPlayersAnim  = data[4] or data.secondPlayersAnim
        entry.AnimationOptions   = data.AnimationOptions

        EmoteDataLookup[string.lower(name)] = entry
        count = count + 1
    end
    return count
end

local function indexWalks(walkTable)
    local count = 0
    for name, data in pairs(walkTable) do
        WalkDataLookup[string.lower(name)] = {
            name     = name,
            clipset  = data[1],
            label    = data[2] or name,
            abusable = data.abusable or false,
        }
        count = count + 1
    end
    return count
end

local function indexExpressions(exprTable)
    local count = 0
    for name, data in pairs(exprTable) do
        ExpressionDataLookup[string.lower(name)] = {
            name  = name,
            anim  = data[1],
            label = data[2] or name,
        }
        count = count + 1
    end
    return count
end

local function indexAllFromSource(source)
    local emoteCount, walkCount, exprCount = 0, 0, 0

    for categoryName in pairs(EmoteCategories) do
        if source[categoryName] and type(source[categoryName]) == "table" then
            emoteCount = emoteCount + indexEmoteCategory(categoryName, source[categoryName])
        end
    end

    if source.Walks then
        walkCount = indexWalks(source.Walks)
    end
    if source.Expressions then
        exprCount = indexExpressions(source.Expressions)
    end

    return emoteCount, walkCount, exprCount
end

local function loadEmoteData()
    print("^3[rpemotes:ped] Loading emote data for ped system...^0")

    local RP = loadAnimFile("client/AnimationList.lua", "RP")
    if not RP then
        print("^1[rpemotes:ped] Failed to load AnimationList.lua^0")
        return false
    end

    local CustomDP = loadAnimFile("client/AnimationListCustom.lua", "CustomDP")

    local ec, wc, xc = indexAllFromSource(RP)
    if CustomDP then
        local ec2, wc2, xc2 = indexAllFromSource(CustomDP)
        ec, wc, xc = ec + ec2, wc + wc2, xc + xc2
    end

    print(("^2[rpemotes:ped] Indexed %d emotes, %d walks, %d expressions^0"):format(ec, wc, xc))
    return true
end

loadEmoteData()

local function resolveProps(animOpt, textureVariation)
    if not animOpt.Prop then return nil end

    local props = {
        prop            = animOpt.Prop,
        propBone        = animOpt.PropBone,
        propPlacement   = animOpt.PropPlacement,
        propNoCollision = animOpt.PropNoCollision or false,
        textureVariation = textureVariation,
    }

    if animOpt.SecondProp then
        props.secondProp            = animOpt.SecondProp
        props.secondPropBone        = animOpt.SecondPropBone
        props.secondPropPlacement   = animOpt.SecondPropPlacement
        props.secondPropNoCollision = animOpt.SecondPropNoCollision or false
    end

    return props
end

local function resolvePtfx(animOpt)
    if not (animOpt.PtfxAsset and animOpt.PtfxName and animOpt.PtfxPlacement) then
        return nil
    end

    local pl = animOpt.PtfxPlacement
    return {
        asset  = animOpt.PtfxAsset,
        name   = animOpt.PtfxName,
        offset = { x = pl[1] or 0.0, y = pl[2] or 0.0, z = pl[3] or 0.0 },
        rot    = { x = pl[4] or 0.0, y = pl[5] or 0.0, z = pl[6] or 0.0 },
        bone   = animOpt.PtfxBone,
        scale  = pl[7] or 1.0,
        color  = animOpt.PtfxColor,
        noProp = animOpt.PtfxNoProp or false,
        wait   = animOpt.PtfxWait,
    }
end

local function resolveEmoteData(emoteEntry, textureVariation)
    local resolved = {}

    if emoteEntry.scenario then
        resolved.scenario     = emoteEntry.scenario
        resolved.scenarioType = emoteEntry.scenarioType
    else
        resolved.dict = emoteEntry.dict
        resolved.anim = emoteEntry.anim
    end

    local animOpt = emoteEntry.AnimationOptions
    if not animOpt then
        resolved.flags    = 0
        resolved.duration = -1
        resolved.blendIn  = 5.0
        resolved.blendOut = 5.0
        return resolved
    end

    resolved.flags    = animOpt.Flag or animOpt.onFootFlag or 0
    resolved.duration = animOpt.EmoteDuration or -1
    resolved.blendIn  = animOpt.BlendInSpeed  or 5.0
    resolved.blendOut = animOpt.BlendOutSpeed  or 5.0

    local props = resolveProps(animOpt, textureVariation)
    if props then
        for k, v in pairs(props) do resolved[k] = v end
    end

    resolved.ptfx = resolvePtfx(animOpt)

    -- SyncOffset positioning (for shared emotes)
    if animOpt.SyncOffsetFront or animOpt.SyncOffsetSide then
        resolved.syncOffset = {
            side    = animOpt.SyncOffsetSide    or 0.0,
            front   = animOpt.SyncOffsetFront   or 1.0,
            height  = animOpt.SyncOffsetHeight  or 0.0,
            heading = animOpt.SyncOffsetHeading or 180.0,
        }
    end

    -- Attachto positioning (for shared emotes)
    if animOpt.Attachto then
        resolved.attachTo = {
            bone = animOpt.bone or 0,
            pos  = animOpt.pos or vector3(animOpt.xPos or 0.0, animOpt.yPos or 0.0, animOpt.zPos or 0.0),
            rot  = animOpt.rot or vector3(animOpt.xRot or 0.0, animOpt.yRot or 0.0, animOpt.zRot or 0.0),
        }
    end

    return resolved
end

local function validateEntity(entityId)
    if not entityId or type(entityId) ~= "number" then return false end
    if not DoesEntityExist(entityId) then return false end

    for _, src in ipairs(GetPlayers()) do
        if GetPlayerPed(tonumber(src)) == entityId then
            return false
        end
    end

    return true
end

local function buildPedState(entityId, entry, resolved)
    local existing = PedStates[entityId]
    PedStates[entityId] = {
        emoteName  = entry.name,
        emoteType  = entry.emoteType,
        resolved   = resolved,
        ptfxActive = resolved.ptfx ~= nil,
        walk       = existing and existing.walk or nil,
        expression = existing and existing.expression or nil,
    }
end

local function clearAllPedStateBags(entityId)
    if not DoesEntityExist(entityId) then return end
    local state = Entity(entityId).state
    state:set('rpemotes:ped:emote', nil, true)
    state:set('rpemotes:ped:ptfx', nil, true)
    state:set('rpemotes:ped:walk', nil, true)
    state:set('rpemotes:ped:expression', nil, true)
    state:set('rpemotes:ped:emoji', nil, true)
end

local function autoStartPtfx(entityId, resolved)
    if resolved.ptfx then
        Entity(entityId).state:set('rpemotes:ped:ptfx', resolved.ptfx, true)
    end
end

local function pedPlayEmote(entityId, emoteName, textureVariation, options)
    if not validateEntity(entityId) then return false end

    local entry = EmoteDataLookup[string.lower(emoteName)]
    if not entry then
        print(string.format("^1[rpemotes:ped] Emote '%s' not found^0", tostring(emoteName)))
        return false
    end

    if not entry.dict and not entry.scenario then
        print(string.format("^1[rpemotes:ped] Emote '%s' has no animation data^0", emoteName))
        return false
    end

    if PedStates[entityId] then
        Entity(entityId).state:set('rpemotes:ped:emote', nil, true)
    end

    local opts = options or {}
    local resolved = resolveEmoteData(entry, textureVariation)
    resolved.blockEvents = opts.blockEvents ~= false
    Entity(entityId).state:set('rpemotes:ped:emote', resolved, true)

    autoStartPtfx(entityId, resolved)
    buildPedState(entityId, entry, resolved)

    return true
end

local function pedCancelEmote(entityId)
    if not entityId or type(entityId) ~= "number" then return false end

    if DoesEntityExist(entityId) then
        Entity(entityId).state:set('rpemotes:ped:ptfx', nil, true)
        Entity(entityId).state:set('rpemotes:ped:emote', nil, true)
    end

    local state = PedStates[entityId]
    if state then
        state.emoteName  = nil
        state.emoteType  = nil
        state.resolved   = nil
        state.ptfxActive = nil
        if not state.walk and not state.expression then
            PedStates[entityId] = nil
        end
    end
    return true
end

local function pedGetState(entityId)
    return PedStates[entityId]
end

local function pedUntrack(entityId)
    if not entityId then return false end

    clearAllPedStateBags(entityId)
    PedStates[entityId] = nil
    return true
end

local function pedStartPtfx(entityId)
    if not entityId or type(entityId) ~= "number" then return false end

    local state = PedStates[entityId]
    if not state or not state.resolved or not state.resolved.ptfx then
        return false
    end

    if not DoesEntityExist(entityId) then return false end

    Entity(entityId).state:set('rpemotes:ped:ptfx', state.resolved.ptfx, true)
    state.ptfxActive = true
    return true
end

local function pedStopPtfx(entityId)
    if not entityId or type(entityId) ~= "number" then return false end

    if DoesEntityExist(entityId) then
        Entity(entityId).state:set('rpemotes:ped:ptfx', nil, true)
    end

    local state = PedStates[entityId]
    if state then
        state.ptfxActive = false
    end
    return true
end

local function pedSetWalkstyle(entityId, walkName)
    if not validateEntity(entityId) then return false end

    if not walkName or walkName == "" then
        if DoesEntityExist(entityId) then
            Entity(entityId).state:set('rpemotes:ped:walk', nil, true)
        end
        local state = PedStates[entityId]
        if state then
            state.walk = nil
            if not state.emoteName and not state.expression then
                PedStates[entityId] = nil
            end
        end
        return true
    end

    local entry = WalkDataLookup[string.lower(walkName)]
    if not entry then
        print(string.format("^1[rpemotes:ped] Walk style '%s' not found^0", tostring(walkName)))
        return false
    end

    Entity(entityId).state:set('rpemotes:ped:walk', entry.clipset, true)

    if not PedStates[entityId] then PedStates[entityId] = {} end
    PedStates[entityId].walk = entry.name
    return true
end

local function pedSetExpression(entityId, expressionName)
    if not validateEntity(entityId) then return false end

    if not expressionName or expressionName == "" then
        if DoesEntityExist(entityId) then
            Entity(entityId).state:set('rpemotes:ped:expression', nil, true)
        end
        local state = PedStates[entityId]
        if state then
            state.expression = nil
            if not state.emoteName and not state.walk then
                PedStates[entityId] = nil
            end
        end
        return true
    end

    local entry = ExpressionDataLookup[string.lower(expressionName)]
    if not entry then
        print(string.format("^1[rpemotes:ped] Expression '%s' not found^0", tostring(expressionName)))
        return false
    end

    Entity(entityId).state:set('rpemotes:ped:expression', entry.anim, true)

    if not PedStates[entityId] then PedStates[entityId] = {} end
    PedStates[entityId].expression = entry.name
    return true
end

local function pedShowEmoji(entityId, emojiName)
    if not validateEntity(entityId) then return false end
    if not emojiName or type(emojiName) ~= "string" or emojiName == "" then return false end

    Entity(entityId).state:set('rpemotes:ped:emoji', { emoji = emojiName, expire = 5000 }, true)

    SetTimeout(5000, function()
        if DoesEntityExist(entityId) then
            Entity(entityId).state:set('rpemotes:ped:emoji', nil, true)
        end
    end)

    return true
end

local function pedPlaySharedEmote(entityId1, entityId2, emoteName, textureVariation)
    if not validateEntity(entityId1) then return false end
    if not validateEntity(entityId2) then return false end
    if entityId1 == entityId2 then return false end

    local entry1 = EmoteDataLookup[string.lower(emoteName)]
    if not entry1 then
        print(string.format("^1[rpemotes:ped] Shared emote '%s' not found^0", tostring(emoteName)))
        return false
    end

    local secondAnimName = entry1.secondPlayersAnim
    if not secondAnimName then
        print(string.format("^1[rpemotes:ped] Emote '%s' has no secondPlayersAnim^0", emoteName))
        return false
    end

    local entry2 = EmoteDataLookup[string.lower(secondAnimName)]
    if not entry2 then
        print(string.format("^1[rpemotes:ped] Secondary emote '%s' not found^0", secondAnimName))
        return false
    end

    -- Cancel any existing emotes on both peds
    pedCancelEmote(entityId1)
    pedCancelEmote(entityId2)

    local resolved1 = resolveEmoteData(entry1, textureVariation)
    local resolved2 = resolveEmoteData(entry2, textureVariation)

    -- Upstream: source (ped1) always gets positioned relative to target (ped2)
    -- SyncOffset always applied to ped1; Attachto may apply to either ped

    -- Ped1 (source): always gets syncOffset positioning relative to ped2
    resolved1.partnerNetId = NetworkGetNetworkIdFromEntity(entityId2)
    resolved1.syncOffset = resolved1.syncOffset or { side = 0.0, front = 1.0, height = 0.0, heading = 180.0 }

    -- Ped1 may also get Attachto if primary entry has it
    -- (resolved1.attachTo already set by resolveEmoteData)

    -- Ped2 (target): gets Attachto only if secondary has it AND primary doesn't
    if resolved2.attachTo and not resolved1.attachTo then
        resolved2.partnerNetId = NetworkGetNetworkIdFromEntity(entityId1)
    elseif resolved2.attachTo and resolved1.attachTo then
        -- Primary takes precedence; don't double-attach
        resolved2.attachTo = nil
    end

    -- Debug: log positioning mode for both peds
    local mode1, mode2 = 'syncOffset', 'none'
    local off = resolved1.syncOffset
    mode1 = string.format('syncOffset(side=%.2f front=%.2f height=%.2f heading=%.1f)',
        off.side, off.front, off.height, off.heading)
    if resolved1.attachTo then
        local att = resolved1.attachTo
        mode1 = mode1 .. string.format(' + attachTo(bone=%d)', att.bone)
    end
    if resolved2.attachTo then
        local att = resolved2.attachTo
        mode2 = string.format('attachTo(bone=%d pos=%.2f,%.2f,%.2f)', att.bone, att.pos.x, att.pos.y, att.pos.z)
    end
    print(string.format('^3[rpemotes:ped] SharedEmote: %s + %s | ped1=%d(%s) ped2=%d(%s)^0',
        entry1.name, entry2.name, entityId1, mode1, entityId2, mode2))

    resolved1.blockEvents = true
    resolved2.blockEvents = true

    -- Set state bags on both simultaneously
    Entity(entityId1).state:set('rpemotes:ped:emote', resolved1, true)
    Entity(entityId2).state:set('rpemotes:ped:emote', resolved2, true)

    autoStartPtfx(entityId1, resolved1)
    autoStartPtfx(entityId2, resolved2)

    buildPedState(entityId1, entry1, resolved1)
    buildPedState(entityId2, entry2, resolved2)

    return true
end

exports('pedShowEmoji',        pedShowEmoji)
exports('pedPlaySharedEmote',  pedPlaySharedEmote)
exports('pedPlayEmote',        pedPlayEmote)
exports('pedCancelEmote',   pedCancelEmote)
exports('pedGetState',      pedGetState)
exports('pedUntrack',       pedUntrack)
exports('pedStartPtfx',    pedStartPtfx)
exports('pedStopPtfx',     pedStopPtfx)
exports('pedSetWalkstyle',  pedSetWalkstyle)
exports('pedSetExpression', pedSetExpression)

-- Prune stale PedStates entries 
CreateThread(function()
    while true do
        Wait(5000)
        for entityId in pairs(PedStates) do
            if not DoesEntityExist(entityId) then
                PedStates[entityId] = nil
            end
        end
    end
end)

-- Global API for commands.lua and other consumers
PedEmoteManagerAPI = {
    pedPlayEmote       = pedPlayEmote,
    pedCancelEmote     = pedCancelEmote,
    pedGetState        = pedGetState,
    pedUntrack         = pedUntrack,
    pedSetWalkstyle    = pedSetWalkstyle,
    pedSetExpression   = pedSetExpression,
    pedShowEmoji       = pedShowEmoji,
    pedPlaySharedEmote = pedPlaySharedEmote,
    EmoteDataLookup      = EmoteDataLookup,
    WalkDataLookup       = WalkDataLookup,
    ExpressionDataLookup = ExpressionDataLookup,
}

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for entityId in pairs(PedStates) do
        clearAllPedStateBags(entityId)
    end

    PedStates = {}
end)
