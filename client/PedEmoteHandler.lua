local PedProps = {}
local PedPtfx = {}
local PedPtfxAssets = {}
local PedPtfxRepeat = {} -- tokens for repeating one-shot PTFX threads
local PedPending = {}

local function loadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = 2000
    while not HasAnimDictLoaded(dict) and timeout > 0 do
        Wait(5)
        timeout = timeout - 5
    end
    return timeout > 0
end

local function loadPropModel(model)
    local hash = GetHashKey(model)
    if HasModelLoaded(hash) then return true end
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = 2000
    while not HasModelLoaded(hash) and timeout > 0 do
        Wait(5)
        timeout = timeout - 5
    end
    return timeout > 0
end

local function loadClipset(clipset)
    RequestAnimSet(clipset)
    local timeout = 5000
    while not HasAnimSetLoaded(clipset) and timeout > 0 do
        RequestAnimSet(clipset)
        Wait(5)
        timeout = timeout - 5
    end
    return timeout > 0
end

local function loadPtfxAsset(asset)
    RequestNamedPtfxAsset(asset)
    local timeout = 2000
    while not HasNamedPtfxAssetLoaded(asset) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end
    return timeout > 0
end

local function cleanupPedProps(entity)
    local props = PedProps[entity]
    if not props then return end
    for _, prop in ipairs(props) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, false, false)
            DeleteEntity(prop)
        end
    end
    PedProps[entity] = nil
end

local function attachProp(entity, model, bone, placement, noCollision, textureVariation)
    if not loadPropModel(model) then return nil end

    local coords = GetEntityCoords(entity)
    local prop = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z + 0.2, false, false, false)

    if textureVariation then
        SetObjectTextureVariation(prop, textureVariation)
    end

    if noCollision then
        SetEntityCollision(prop, false, false)
    end

    local pl = placement or {}
    AttachEntityToEntity(
        prop, entity, GetPedBoneIndex(entity, bone),
        pl[1] or 0.0, pl[2] or 0.0, pl[3] or 0.0,
        pl[4] or 0.0, pl[5] or 0.0, pl[6] or 0.0,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(model)

    if not PedProps[entity] then PedProps[entity] = {} end
    PedProps[entity][#PedProps[entity] + 1] = prop
    return prop
end

local function playPedAnim(entity, data)
    if data.scenario then
        ClearPedTasks(entity)
        if data.scenarioType == 'ScenarioObject' then
            local behind = GetOffsetFromEntityInWorldCoords(entity, 0.0, -0.5, -0.5)
            TaskStartScenarioAtPosition(
                entity, data.scenario,
                behind.x, behind.y, behind.z,
                GetEntityHeading(entity), 0, true, false
            )
        else
            TaskStartScenarioInPlace(entity, data.scenario, 0, true)
        end
        return
    end

    if not data.dict or not data.anim then
        DebugPrint("[rpemotes:ped] No dict/anim for entity " .. entity)
        return
    end
    if not loadAnimDict(data.dict) then
        DebugPrint("[rpemotes:ped] Failed to load anim dict '" .. data.dict .. "'")
        return
    end

    TaskPlayAnim(entity, data.dict, data.anim,
        data.blendIn  or 5.0,
        data.blendOut or 5.0,
        data.duration or -1,
        data.flags    or 0,
        0.0, false, false, false
    )

    RemoveAnimDict(data.dict)
end

local function spawnPedProps(entity, data)
    cleanupPedProps(entity)

    if not data.prop then return end

    attachProp(
        entity, data.prop, data.propBone,
        data.propPlacement, data.propNoCollision,
        data.textureVariation
    )
    if data.secondProp then
        attachProp(
            entity, data.secondProp, data.secondPropBone,
            data.secondPropPlacement, data.secondPropNoCollision,
            data.textureVariation
        )
    end
end

local function stopPedPtfx(entity)
    -- Kill repeating one-shot thread if any
    if PedPtfxRepeat[entity] then
        PedPtfxRepeat[entity] = nil
    end
    local handle = PedPtfx[entity]
    if handle then
        StopParticleFxLooped(handle, false)
        PedPtfx[entity] = nil
    end
    local asset = PedPtfxAssets[entity]
    if asset then
        RemoveNamedPtfxAsset(asset)
        PedPtfxAssets[entity] = nil
    end
end

local function getPtfxTarget(entity, value)
    local target = entity
    if not value.noProp and PedProps[entity] and #PedProps[entity] > 0 then
        local propHandle = PedProps[entity][#PedProps[entity]]
        if DoesEntityExist(propHandle) then
            target = propHandle
        end
    end

    local boneIndex = 0
    if value.bone then
        boneIndex = GetPedBoneIndex(entity, value.bone)
    elseif target == entity then
        boneIndex = GetEntityBoneIndexByName(entity, "VFX")
    end

    return target, boneIndex
end

local function applyPtfx(entity, value)
    stopPedPtfx(entity)

    if not loadPtfxAsset(value.asset) then
        DebugPrint("[rpemotes:ped] Failed to load PTFX asset '" .. tostring(value.asset) .. "'")
        return
    end

    PedPtfxAssets[entity] = value.asset
    local target, boneIndex = getPtfxTarget(entity, value)
    local o = value.offset or {}
    local r = value.rot or {}

    -- Repeating one-shot PTFX (e.g. fireworks with PtfxWait) — start/stop pulse like upstream
    if value.wait then
        local token = {}
        PedPtfxRepeat[entity] = token

        CreateThread(function()
            while PedPtfxRepeat[entity] == token do
                if not DoesEntityExist(entity) then break end

                UseParticleFxAsset(value.asset)
                local h = StartNetworkedParticleFxLoopedOnEntityBone(
                    value.name, target,
                    o.x or 0.0, o.y or 0.0, o.z or 0.0,
                    r.x or 0.0, r.y or 0.0, r.z or 0.0,
                    boneIndex, (value.scale or 1.0) + 0.0,
                    false, false, false
                )

                local color = value.color
                if color then
                    if color[1] and type(color[1]) == 'table' then
                        color = color[math.random(1, #color)]
                    end
                    SetParticleFxLoopedAlpha(h, color.A)
                    SetParticleFxLoopedColour(h, color.R / 255, color.G / 255, color.B / 255, false)
                end

                Wait(value.wait)
                StopParticleFxLooped(h, false)
            end
        end)
        return
    end

    -- Standard looped PTFX
    UseParticleFxAsset(value.asset)
    local handle = StartNetworkedParticleFxLoopedOnEntityBone(
        value.name, target,
        o.x or 0.0, o.y or 0.0, o.z or 0.0,
        r.x or 0.0, r.y or 0.0, r.z or 0.0,
        boneIndex, (value.scale or 1.0) + 0.0,
        false, false, false
    )
    PedPtfx[entity] = handle

    local color = value.color
    if color then
        if color[1] and type(color[1]) == 'table' then
            color = color[math.random(1, #color)]
        end
        SetParticleFxLoopedAlpha(handle, color.A)
        SetParticleFxLoopedColour(handle, color.R / 255, color.G / 255, color.B / 255, false)
    end
end

local function applyWalk(entity, clipset)
    if loadClipset(clipset) then
        SetPedMovementClipset(entity, clipset, 0.2)
        RemoveAnimSet(clipset)
    else
        DebugPrint("[rpemotes:ped] Failed to load walk clipset '" .. clipset .. "'")
    end
end

local function applyExpression(entity, anim)
    SetFacialIdleAnimOverride(entity, anim, 0)
end

local function cancelPedVisuals(entity)
    stopPedPtfx(entity)
    cleanupPedProps(entity)
end

local function cancelPedTasks(entity)
    if DoesEntityExist(entity) then
        ClearPedTasks(entity)
    end
end

-- State bag listeners: entity owner applies visuals when server sets rpemotes:ped:* bags
AddStateBagChangeHandler('rpemotes:ped:emote', '', function(bagName, key, value, _unused, replicated)
    if not bagName:find('^entity:') then return end

    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or not DoesEntityExist(entity) then
        if value then
            if not PedPending[bagName] then PedPending[bagName] = {} end
            PedPending[bagName].emote = value
        end
        return
    end

    if value then
        DebugPrint(string.format("[rpemotes:ped] Emote on entity %d — dict=%s anim=%s",
            entity, tostring(value.dict), tostring(value.anim)))

        spawnPedProps(entity, value)
        playPedAnim(entity, value)
    else
        DebugPrint("[rpemotes:ped] Cancelling emote on entity " .. entity)

        cancelPedVisuals(entity)
        cancelPedTasks(entity)
    end
end)

AddStateBagChangeHandler('rpemotes:ped:ptfx', '', function(bagName, key, value, _unused, replicated)
    if not bagName:find('^entity:') then return end

    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or not DoesEntityExist(entity) then
        if value then
            if not PedPending[bagName] then PedPending[bagName] = {} end
            PedPending[bagName].ptfx = value
        end
        return
    end

    if value then
        applyPtfx(entity, value)
    else
        stopPedPtfx(entity)
    end
end)

AddStateBagChangeHandler('rpemotes:ped:walk', '', function(bagName, key, value, _unused, replicated)
    if not bagName:find('^entity:') then return end

    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or not DoesEntityExist(entity) then
        if value then
            if not PedPending[bagName] then PedPending[bagName] = {} end
            PedPending[bagName].walk = value
        end
        return
    end

    if value then
        applyWalk(entity, value)
    else
        ResetPedMovementClipset(entity, 0.0)
    end
end)

AddStateBagChangeHandler('rpemotes:ped:expression', '', function(bagName, key, value, _unused, replicated)
    if not bagName:find('^entity:') then return end

    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or not DoesEntityExist(entity) then
        if value then
            if not PedPending[bagName] then PedPending[bagName] = {} end
            PedPending[bagName].expression = value
        end
        return
    end

    if value then
        applyExpression(entity, value)
    else
        ClearFacialIdleAnimOverride(entity)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for entity in pairs(PedPtfx) do
        stopPedPtfx(entity)
    end

    for entity, props in pairs(PedProps) do
        for _, prop in ipairs(props) do
            if DoesEntityExist(prop) then
                SetEntityAsMissionEntity(prop, false, false)
                DeleteEntity(prop)
            end
        end
    end

    PedPtfx = {}
    PedPtfxAssets = {}
    PedProps = {}
    PedPending = {}
end)

-- Global API consumed by PedEmoteCleanup.lua (loaded after this file)
PedEmoteHandlerAPI = {
    cleanupPedProps  = cleanupPedProps,
    stopPedPtfx      = stopPedPtfx,
    spawnPedProps    = spawnPedProps,
    applyPtfx        = applyPtfx,
    cancelPedVisuals = cancelPedVisuals,
    cancelPedTasks   = cancelPedTasks,
    playPedAnim      = playPedAnim,
    applyWalk        = applyWalk,
    applyExpression  = applyExpression,
    PedProps         = PedProps,
    PedPtfx          = PedPtfx,
    PedPtfxAssets    = PedPtfxAssets,
    PedPending       = PedPending,
}
