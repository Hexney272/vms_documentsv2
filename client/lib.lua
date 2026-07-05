library = library or {}
library.loadedParticles = {}
library.IsHaveProp = nil

local function resolveModel(model)
    if type(model) == 'number' then
        return model
    end

    return GetHashKey(model)
end

function library.Debug(message, level)
    if not Config.Debug then
        return
    end

    if level == 'error' then
        error(message)
    elseif level == 'warn' then
        warn(message)
    else
        print(message)
    end
end

function library.Callback(name, cb, ...)
    if Config.Core == 'ESX' then
        ESX.TriggerServerCallback(name, cb, ...)
    elseif Config.Core == 'QB-Core' then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    end
end

function library.CreateBlip(data)
    local blip = AddBlipForCoord(data.coords)

    SetBlipSprite(blip, data.sprite)
    SetBlipDisplay(blip, data.display)
    SetBlipScale(blip, data.scale)
    SetBlipColour(blip, data.color)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.name)
    EndTextCommandSetBlipName(blip)

    return blip
end

function library.DeleteBlip(blip)
    if not blip then
        return nil
    end

    RemoveBlip(blip)
    return nil
end

function library.RequestEntity(model)
    local modelHash = resolveModel(model)

    if not modelHash or not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        library.Debug(('Invalid model: %s'):format(tostring(model)), 'warn')
        return nil
    end

    local timeoutAt = GetGameTimer() + 5000
    RequestModel(modelHash)

    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timeoutAt then
            library.Debug(('Timed out loading model %s'):format(tostring(model)), 'warn')
            return nil
        end

        RequestModel(modelHash)
        Wait(1)
    end

    return modelHash
end

function library.SpawnPed(data)
    if not data or not data.model or not data.coords then
        return nil
    end

    local modelHash = library.RequestEntity(data.model)

    if not modelHash then
        return nil
    end

    local coords = data.coords
    local ped = CreatePed(
        4,
        modelHash,
        coords.x,
        coords.y,
        coords.z,
        coords.w or 0.0,
        false,
        true
    )

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(modelHash)

    if data.animation then
        library.PlayAnimation(ped, data.animation[1], data.animation[2], -1, 1)
    end

    return ped
end

function library.SpawnProp(model, coords, isNetwork, attachData, disableCollisions)
    local ped = PlayerPedId()
    local modelHash = library.RequestEntity(model)

    if not modelHash then
        return nil
    end

    local spawnCoords = coords and vec(coords.x, coords.y, coords.z) or GetEntityCoords(ped)
    local prop = CreateObject(
        modelHash,
        spawnCoords.x,
        spawnCoords.y,
        spawnCoords.z,
        isNetwork or false,
        false,
        true
    )

    if attachData and attachData.attachTo and attachData.boneIndex and attachData.placement then
        local placement = attachData.placement

        AttachEntityToEntity(
            prop,
            attachData.attachTo,
            attachData.boneIndex,
            placement[1],
            placement[2],
            placement[3],
            placement[4],
            placement[5],
            placement[6],
            true,
            true,
            false,
            true,
            1,
            true
        )
    end

    if disableCollisions then
        SetEntityCollision(prop, false, true)
    end

    SetModelAsNoLongerNeeded(modelHash)
    return prop
end

function library.LoadDict(dict)
    local timeoutAt = GetGameTimer() + 5000

    RequestAnimDict(dict)

    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeoutAt then
            library.Debug(('Timed out loading animation dict %s'):format(dict), 'warn')
            break
        end

        RequestAnimDict(dict)
        Wait(50)
    end
end

function library.PlayAnimation(ped, dict, anim, duration, flag, propData)
    if not ped or not DoesEntityExist(ped) or not dict or not anim then
        return
    end

    library.LoadDict(dict)

    if propData then
        library.IsHaveProp = library.SpawnProp(
            propData.model,
            propData.coords,
            propData.isNetwork,
            propData.attachData,
            propData.disableCollisions
        )
    end

    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, duration or -1, flag or 1, 0.0, false, false, false)
end

function library.StopAnimation(ped)
    if library.IsHaveProp and DoesEntityExist(library.IsHaveProp) then
        DeleteEntity(library.IsHaveProp)
        library.IsHaveProp = nil
    end

    if ped and DoesEntityExist(ped) then
        ClearPedTasks(ped)
    end
end

function library.CreateCamera(data)
    if not data or not data.coords or not data.playerCoords then
        return nil
    end

    local coords = data.coords
    local camera = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        coords.x,
        coords.y,
        coords.z,
        0.0,
        0.0,
        0.0,
        40.0,
        false,
        2
    )

    PointCamAtCoord(camera, data.playerCoords.x, data.playerCoords.y, data.playerCoords.z + 1.2)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 700, true, true)

    return camera
end

function library.RemoveCamera(camera)
    if not camera then
        RenderScriptCams(false, true, 700, true, true)
        return nil
    end

    SetCamActive(camera, false)
    DestroyCam(camera, false)
    RenderScriptCams(false, true, 700, true, true)

    return nil
end

function library.LoadParticle(asset)
    local timeoutAt = GetGameTimer() + 5000

    RequestNamedPtfxAsset(asset)

    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() > timeoutAt then
            library.Debug(('Timed out loading particle asset %s'):format(asset), 'warn')
            break
        end

        RequestNamedPtfxAsset(asset)
        Wait(50)
    end
end

function library.LoadParticles(data)
    if not data or not data.asset or not data.name or not data.placement then
        return
    end

    library.LoadParticle(data.asset)
    UseParticleFxAssetNextCall(data.asset)
    library.PtfxCreation(PlayerPedId(), library.IsHaveProp, data.name, data.asset, data.placement, data.rgb)
end

function library.PtfxCreation(ped, prop, effectName, asset, placement, rgb)
    local entity = prop or ped
    local boneIndex = GetEntityBoneIndexByName(entity, 'VFX')

    if boneIndex == -1 then
        boneIndex = 0
    end

    local particle = StartNetworkedParticleFxLoopedOnEntityBone(
        effectName,
        entity,
        (placement[1] or 0.0) + 0.0,
        (placement[2] or 0.0) + 0.0,
        (placement[3] or 0.0) + 0.0,
        (placement[4] or 0.0) + 0.0,
        (placement[5] or 0.0) + 0.0,
        (placement[6] or 0.0) + 0.0,
        boneIndex,
        (placement[7] or 1.0) + 0.0,
        false,
        false,
        false
    )

    if particle then
        SetParticleFxLoopedColour(
            particle,
            (rgb[1] or 1.0) + 0.0,
            (rgb[2] or 1.0) + 0.0,
            (rgb[3] or 1.0) + 0.0
        )

        library.loadedParticles[#library.loadedParticles + 1] = particle
    end

    RemoveNamedPtfxAsset(asset)
end

function library.ParticleRemove()
    for index = #library.loadedParticles, 1, -1 do
        StopParticleFxLooped(library.loadedParticles[index], false)
        table.remove(library.loadedParticles, index)
    end
end
