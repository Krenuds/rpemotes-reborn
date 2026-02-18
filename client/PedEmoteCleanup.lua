local API = PedEmoteHandlerAPI

-- Retry pending state bag changes for entities that weren't streamed in yet
CreateThread(function()
    while true do
        Wait(250)

        for bagName, pending in pairs(API.PedPending) do
            local entity = GetEntityFromStateBagName(bagName)

            if entity ~= 0 and DoesEntityExist(entity) then
                if pending.emote then
                    API.spawnPedProps(entity, pending.emote)
                    API.playPedAnim(entity, pending.emote)
                    API.applySharedPositioning(entity, pending.emote)
                end
                if pending.ptfx then
                    API.applyPtfx(entity, pending.ptfx)
                end
                if pending.walk then
                    API.applyWalk(entity, pending.walk)
                end
                if pending.expression then
                    API.applyExpression(entity, pending.expression)
                end
                if pending.emoji then
                    API.showPedEmoji(entity, pending.emoji)
                end

                DebugPrint("[rpemotes:ped] Deferred applied for " .. bagName)
                API.PedPending[bagName] = nil
            end
        end
    end
end)

-- Clean up props/PTFX for entities that no longer exist
CreateThread(function()
    while true do
        Wait(5000)

        for entity, props in pairs(API.PedProps) do
            if not DoesEntityExist(entity) then
                for _, prop in ipairs(props) do
                    if DoesEntityExist(prop) then
                        SetEntityAsMissionEntity(prop, false, false)
                        DeleteEntity(prop)
                    end
                end
                API.PedProps[entity] = nil
            else
                local alive = {}
                for _, prop in ipairs(props) do
                    if DoesEntityExist(prop) then
                        alive[#alive + 1] = prop
                    end
                end
                if #alive ~= #props then
                    API.PedProps[entity] = #alive > 0 and alive or nil
                end
            end
        end

        for entity in pairs(API.PedPtfx) do
            if not DoesEntityExist(entity) then
                API.stopPedPtfx(entity)
            end
        end
    end
end)
