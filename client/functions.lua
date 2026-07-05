local isSelectingDocumentTarget = false

local function forEachDocumentsMenu(cb)
    if Config.UseDocumentsOnlyInCityhall or not Config.DocumentsMenu then
        return
    end

    for index, menu in pairs(Config.DocumentsMenu) do
        cb(index, menu)
    end
end

local function spawnPed(entry)
    if not entry.ped or not entry.ped.model or not entry.ped.coords then
        return
    end

    if entry.__ped and DoesEntityExist(entry.__ped) then
        return
    end

    entry.__ped = library.SpawnPed({
        model = entry.ped.model,
        coords = entry.ped.coords,
        animation = entry.ped.animation,
    })
end

local function createBlip(entry)
    if not entry.blip or not entry.blipCoords or entry.__blip then
        return
    end

    entry.__blip = library.CreateBlip({
        coords = entry.blipCoords,
        sprite = entry.blip.sprite,
        display = entry.blip.display,
        scale = entry.blip.scale,
        color = entry.blip.color,
        name = entry.blip.name,
    })
end

local function deleteSpawnedEntity(entry)
    if entry.__ped and DoesEntityExist(entry.__ped) then
        DeleteEntity(entry.__ped)
    end

    entry.__ped = nil

    if entry.__blip then
        entry.__blip = library.DeleteBlip(entry.__blip)
    end
end

function initialSpawns()
    for _, photographer in pairs(Config.Photographers or {}) do
        spawnPed(photographer)
        createBlip(photographer)
    end

    forEachDocumentsMenu(function(_, menu)
        spawnPed(menu)
        createBlip(menu)
    end)
end

function deletePeds()
    for _, photographer in pairs(Config.Photographers or {}) do
        deleteSpawnedEntity(photographer)
    end

    forEachDocumentsMenu(function(_, menu)
        deleteSpawnedEntity(menu)
    end)
end

local function drawConfiguredMarker(marker, coords)
    if not marker or not coords then
        return
    end

    local rotation = marker.rotation or vec(0.0, 0.0, 0.0)
    local scale = marker.scale or vec(0.2, 0.2, 0.2)
    local color = marker.color or {255, 255, 255, 175}

    DrawMarker(
        marker.type or 20,
        coords.x,
        coords.y,
        coords.z,
        0.0,
        0.0,
        0.0,
        rotation.x or 0.0,
        rotation.y or 0.0,
        rotation.z or 0.0,
        scale.x or 0.2,
        scale.y or 0.2,
        scale.z or 0.2,
        color[1] or 255,
        color[2] or 255,
        color[3] or 255,
        color[4] or 175,
        marker.bobUpAndDown or false,
        false,
        false,
        marker.rotate or false,
        marker.textureDict,
        marker.textureName,
        marker.drawOnEnts or false
    )
end

local function getPhotographerLabel(prefix)
    if Config.PhotosPrices >= 1 then
        return TRANSLATE(prefix .. '.photographer', Config.PhotosPrices)
    end

    return TRANSLATE(prefix .. '.photographer_free')
end

local function canUseDocumentsMenu(menu)
    if not menu.requiredJob then
        return true
    end

    return menu.requiredJob == CL.GetPlayerJob('name')
end

local function showHelpNotification(message)
    if Config.Core == 'ESX' and Config.UseHelpNotify then
        ESX.ShowHelpNotification(message)
    end
end

local function openTextUI(message, isOpen)
    if message and not isOpen then
        CL.TextUI.Open(message)
        return true
    end

    if not message and isOpen then
        CL.TextUI.Close()
        return false
    end

    return isOpen
end

function registerTargets()
    forEachDocumentsMenu(function(index, menu)
        if not menu.targetCoords then
            library.Debug('You have not configured targetCoords in Config.DocumentsMenu', 'error')
            return
        end

        menu.__target = CL.Target('zone', {
            coords = menu.targetCoords.xyz,
            rotation = menu.targetCoords.w,
            size = menu.targetSize,
            name = 'documents' .. math.random(100000, 9999999),
            icon = 'fa-solid fa-id-card',
            label = TRANSLATE('target.documents_menu'),
            action = function()
                documentsMenu(index)
            end,
            job = menu.requiredJob,
        })
    end)

    for index, photographer in pairs(Config.Photographers or {}) do
        if not photographer.targetCoords then
            library.Debug('You have not configured targetCoords in Config.Photographers', 'error')
            return
        end

        photographer.__target = CL.Target('zone', {
            coords = photographer.targetCoords.xyz,
            rotation = photographer.targetCoords.w,
            size = photographer.targetSize,
            name = 'photograph' .. math.random(100000, 9999999),
            icon = 'fa-solid fa-camera',
            label = getPhotographerLabel('target'),
            action = function()
                makePhoto(index)
            end,
            job = photographer.requiredJob,
        })
    end
end

local function handlePhotographerPoint(index, photographer, playerCoords)
    local distance = #(playerCoords - photographer.accessCoords)

    if distance > photographer.distanceSee then
        return nil, true
    end

    if makingPhoto then
        return nil, false
    end

    if Config.UseMarkers then
        drawConfiguredMarker(photographer.markerData, photographer.accessCoords)
    end

    if Config.UseText3D then
        CL.DrawText3D(photographer.accessCoords, getPhotographerLabel('3dtext'))
    end

    if distance > photographer.distanceAccess then
        return nil, false
    end

    if CL.TextUI.Enabled then
        if Config.PhotosPrices >= 1 then
            return TRANSLATE('textui.photographer', Config.PhotosPrices), false
        end

        return TRANSLATE('textui.photographer_free'), false
    end

    showHelpNotification(getPhotographerLabel('help'))

    if IsControlJustPressed(0, 38) then
        makePhoto(index)
    end

    return nil, false
end

local function handleDocumentsMenuPoint(index, menu, playerCoords)
    if not canUseDocumentsMenu(menu) then
        return nil, true
    end

    local distance = #(playerCoords - menu.menuCoords)

    if distance > menu.distanceSee then
        return nil, true
    end

    if Config.UseMarkers then
        drawConfiguredMarker(menu.markerData, menu.menuCoords)
    end

    if Config.UseText3D then
        CL.DrawText3D(menu.menuCoords, TRANSLATE('3dtext.documents_menu'))
    end

    if distance > menu.distanceAccess then
        return nil, false
    end

    if CL.TextUI.Enabled then
        return TRANSLATE('textui.documents_menu'), false
    end

    showHelpNotification(TRANSLATE('help.documents_menu'))

    if IsControlJustPressed(0, 38) then
        documentsMenu(index)
    end

    return nil, false
end

function runMainThread()
    Citizen.CreateThread(function()
        initialSpawns()
        Citizen.Wait(4000)

        if Config.UseTarget then
            registerTargets()
            return
        end

        local textUiOpen = false

        while not Config.UseTarget do
            local textUiMessage = nil
            local shouldSleep = true
            local playerCoords = GetEntityCoords(PlayerPedId())

            for index, photographer in pairs(Config.Photographers or {}) do
                local message, canSleep = handlePhotographerPoint(index, photographer, playerCoords)

                textUiMessage = textUiMessage or message
                shouldSleep = shouldSleep and canSleep
            end

            forEachDocumentsMenu(function(index, menu)
                local message, canSleep = handleDocumentsMenuPoint(index, menu, playerCoords)

                textUiMessage = textUiMessage or message
                shouldSleep = shouldSleep and canSleep
            end)

            if CL.TextUI.Enabled then
                textUiOpen = openTextUI(textUiMessage, textUiOpen)
            end

            Citizen.Wait(shouldSleep and 1000 or 1)
        end

        if CL.TextUI.Enabled and textUiOpen then
            CL.TextUI.Close()
        end
    end)
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    runMainThread()
end)

local function disableControlsDuringPhoto()
    Citizen.CreateThread(function()
        while makingPhoto do
            DisableAllControlActions(0)
            Citizen.Wait(1)
        end
    end)
end

local function waitUntilPedCloseToCoords(ped, coords, maxDistance, timeoutMs, debugTemplate, timeoutMessage)
    local distance = #(GetEntityCoords(ped).xyz - coords.xyz)
    local timeoutAt = GetGameTimer() + timeoutMs

    while distance > maxDistance do
        Citizen.Wait(100)

        distance = #(GetEntityCoords(ped).xyz - coords.xyz)
        library.Debug(debugTemplate:format(distance, maxDistance))

        if GetGameTimer() > timeoutAt then
            library.Debug(timeoutMessage)
            break
        end
    end
end

local function playPhotographerAnimation(photographer)
    if not photographer.__ped or not DoesEntityExist(photographer.__ped) then
        return
    end

    library.PlayAnimation(
        photographer.__ped,
        'amb@world_human_paparazzi@male@base',
        'base',
        -1,
        1,
        {
            model = 'prop_pap_camera_01',
            isNetwork = false,
            attachData = {
                attachTo = photographer.__ped,
                boneIndex = GetPedBoneIndex(photographer.__ped, 28422),
                placement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
            },
            disableCollisions = true,
        }
    )
end

local function playCameraFlashes()
    for _ = 1, Config.CountOfPhotos do
        library.LoadParticles({
            asset = 'scr_bike_business',
            name = 'scr_bike_cfid_camera_flash',
            placement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0},
            rgb = {1.0, 1.0, 1.0},
        })

        Citizen.Wait(math.random(900, 1450))
    end
end

local function performPhotoScene(photographer)
    disableControlsDuringPhoto()

    local playerPed = PlayerPedId()
    local originalCoords = GetEntityCoords(playerPed)
    local originalHeading = GetEntityHeading(playerPed)
    local cameraData = photographer.camera

    photographer.__camera = library.CreateCamera(cameraData)

    Citizen.Wait(500)
    SetTimecycleModifier('MP_corona_heist_DOF')
    SetTimecycleModifierStrength(1.0)

    TaskPedSlideToCoord(
        playerPed,
        cameraData.playerCoords.x,
        cameraData.playerCoords.y,
        cameraData.playerCoords.z,
        cameraData.playerCoords.w,
        1.0
    )

    waitUntilPedCloseToCoords(
        playerPed,
        cameraData.playerCoords,
        tonumber(Config.DistanceToStartPhotosProcess),
        Config.MaxTimeWalkIn,
        'Your distance to photograph point is %.2fm. (The distance to start the process is min. %.2fm)',
        'The player travel time to the photo point has passed'
    )

    library.Debug('The process of photography has begun..')
    playPhotographerAnimation(photographer)

    Citizen.Wait(1300)
    SetEntityCoords(playerPed, cameraData.playerCoords.x, cameraData.playerCoords.y, cameraData.playerCoords.z)
    SetEntityHeading(playerPed, cameraData.playerCoords.w)
    FreezeEntityPosition(playerPed, true)

    Citizen.Wait(math.random(1500, 2200))
    playCameraFlashes()
    Citizen.Wait(math.random(800, 2200))

    FreezeEntityPosition(playerPed, false)
    Citizen.Wait(1000)

    if photographer.__ped and DoesEntityExist(photographer.__ped) then
        library.StopAnimation(photographer.__ped)
    end

    Citizen.Wait(200)
    library.ParticleRemove()

    TaskPedSlideToCoord(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, originalHeading, 1.0)

    waitUntilPedCloseToCoords(
        playerPed,
        originalCoords,
        tonumber(Config.DistanceToStartPhotosProcess) + 0.2,
        Config.MaxTimeWalkOut,
        'Your distance to photographer is %.2fm. (The distance to end the process is min. %.2fm)',
        'The player travel time to the photographer has passed'
    )

    Citizen.Wait(200)
    photographer.__camera = library.RemoveCamera(photographer.__camera)
    ClearTimecycleModifier()
end

function makePhoto(photographerIndex)
    if makingPhoto then
        return
    end

    local photographer = Config.Photographers[photographerIndex]

    if not photographer then
        return
    end

    library.Callback('vms_documentsv2:canDoPhotos', function(canStart)
        if not canStart then
            return
        end

        CL.GetPlayerClothesParts(function(canUsePhotographer)
            if not canUsePhotographer then
                TriggerServerEvent('vms_documentsv2:sv:cannotMakePhoto', photographerIndex)
                CL.Notification(TRANSLATE('notify.take_of_head_accessories'), 4000, 'info')
                return
            end

            makingPhoto = photographerIndex

            if photographer.camera then
                performPhotoScene(photographer)
            end

            local base64 = CL.CaptureMugshotBase64()

            if not base64 then
                makingPhoto = false
                TriggerServerEvent('vms_documentsv2:sv:cannotMakePhoto', photographerIndex)
                return
            end

            SendNUIMessage({
                action = 'compressPhoto',
                base64 = base64,
            })
        end)
    end, photographerIndex)
end

function closeDocumentThread()
    Citizen.CreateThread(function()
        while documentOnScreen do
            if IsControlJustPressed(0, Config.Controls.hide_document) then
                hideDocument()
            end

            Citizen.Wait(1)
        end
    end)
end

local function removeSelfFromPlayers(players)
    local playerId = PlayerId()

    for index = #players, 1, -1 do
        if players[index] == playerId then
            table.remove(players, index)
        end
    end

    return players
end

local function drawSelectionMarker(playerPed, targetPed, selectedSelf)
    local marker = Config.Marker.selecting_player
    local ped = selectedSelf and playerPed or targetPed

    if not ped or ped == -1 then
        return
    end

    local coords = GetPedBoneCoords(ped, 12844, 0.3, 0.0, 0.0)
    drawConfiguredMarker(marker, coords.xyz)
end

local function closeSelectionTextUi(isOpen)
    if CL.TextUI.Enabled and isOpen then
        CL.TextUI.Close()
    end
end

local function selectDocumentTarget(documentName, metadata, photo)
    local playerPed = PlayerPedId()
    local selectedSelf = false
    local textUiOpen = false

    isSelectingDocumentTarget = true

    while isSelectingDocumentTarget do
        local closestPlayer, closestDistance = CL.GetClosestPlayer()
        local targetPed = closestPlayer and closestPlayer ~= -1 and GetPlayerPed(closestPlayer) or nil
        local targetIsClose = closestPlayer and closestPlayer ~= -1 and closestDistance <= Config.ShowDocumentDistance

        if CL.TextUI.Enabled then
            if not textUiOpen then
                CL.TextUI.Open(TRANSLATE('textui.selecting_menu'))
                textUiOpen = true
            end
        else
            showHelpNotification(TRANSLATE('help.selecting_menu'))
        end

        if targetIsClose then
            drawSelectionMarker(playerPed, targetPed, selectedSelf)
        else
            selectedSelf = true
            drawSelectionMarker(playerPed, nil, true)
        end

        if Config.Controls['selecting_menu.cancel'] and IsControlJustPressed(0, Config.Controls['selecting_menu.cancel']) then
            closeSelectionTextUi(textUiOpen)
            isSelectingDocumentTarget = false
            return false, true
        end

        if Config.Controls['selecting_menu.change_player'] and IsControlJustPressed(0, Config.Controls['selecting_menu.change_player']) then
            selectedSelf = not selectedSelf
        end

        if Config.Controls['selecting_menu.show_document'] and IsControlJustPressed(0, Config.Controls['selecting_menu.show_document']) then
            closeSelectionTextUi(textUiOpen)
            isSelectingDocumentTarget = false

            if selectedSelf then
                return true, false
            end

            if targetIsClose then
                TriggerServerEvent(
                    'vms_documentsv2:sv:showDocumentToPlayers',
                    GetPlayerServerId(closestPlayer),
                    documentName,
                    metadata,
                    photo
                )

                return false, false
            end
        end

        Citizen.Wait(1)
    end

    closeSelectionTextUi(textUiOpen)
    return false, true
end

local function showToClosestPlayer(documentName, metadata, photo)
    local closestPlayer, closestDistance = CL.GetClosestPlayer()

    if not closestPlayer or closestPlayer == -1 or closestDistance > Config.ShowDocumentDistance then
        return true
    end

    TriggerServerEvent(
        'vms_documentsv2:sv:showDocumentToPlayers',
        GetPlayerServerId(closestPlayer),
        documentName,
        metadata,
        photo
    )

    return false
end

local function showToNearbyPlayers(players, documentName, metadata, photo)
    local serverIds = {}

    for _, player in pairs(players) do
        serverIds[#serverIds + 1] = GetPlayerServerId(player)
    end

    if #serverIds == 0 then
        return true
    end

    TriggerServerEvent('vms_documentsv2:sv:showDocumentToPlayers', serverIds, documentName, metadata, photo)
    return false
end

local function playDocumentAnimation(documentName, document, shouldViewSelf)
    if not document.animations then
        return
    end

    local anim = document.animations[shouldViewSelf and 'view' or 'show']

    if not anim or not anim[1] then
        return
    end

    local playerPed = PlayerPedId()
    local propData = nil

    if document.prop then
        propData = {
            model = document.prop,
            isNetwork = true,
            attachData = {
                attachTo = playerPed,
                boneIndex = GetPedBoneIndex(playerPed, anim[5]),
                placement = anim[6],
            },
            disableCollisions = true,
        }
    end

    library.PlayAnimation(playerPed, anim[1], anim[2], anim[3], anim[4], propData)

    if anim[3] and anim[3] >= 1 then
        Citizen.CreateThread(function()
            Citizen.Wait(anim[3])
            library.StopAnimation(PlayerPedId())
        end)
    end
end

function showDocument(documentName, metadata, photo, shownFromServer)
    if documentOnScreen or (not shownFromServer and isSelectingDocumentTarget) then
        return
    end

    local document = Config.Documents[documentName]

    if not document or not metadata then
        return
    end

    local shouldViewSelf = true
    documentOnScreen = metadata.document_id or true

    if not shownFromServer then
        local nearbyPlayers = removeSelfFromPlayers(CL.GetClosestPlayers() or {})

        if nearbyPlayers and next(nearbyPlayers) then
            if Config.ShowDocumentMode == 1 then
                local cancelled
                shouldViewSelf, cancelled = selectDocumentTarget(documentName, metadata, photo)

                if cancelled then
                    documentOnScreen = nil
                    return
                end
            elseif Config.ShowDocumentMode == 2 then
                shouldViewSelf = showToClosestPlayer(documentName, metadata, photo)
            elseif Config.ShowDocumentMode == 3 then
                shouldViewSelf = showToNearbyPlayers(nearbyPlayers, documentName, metadata, photo)
            end
        end

        playDocumentAnimation(documentName, document, shouldViewSelf)
    end

    if shownFromServer or shouldViewSelf or Config.ViewDocumentAlways then
        SendNUIMessage({
            action = 'showDocument',
            type = document.type,
            badgeImage = document.badgeImage,
            photo = photo,
            image = document.image,
            name = documentName,
            data = metadata,
        })

        closeDocumentThread()
    end
end

function hideDocument()
    library.StopAnimation(PlayerPedId())

    SendNUIMessage({
        action = 'closeDocument',
    })

    documentOnScreen = nil
end

function documentsMenu(menuIndex)
    library.Callback('vms_documentsv2:getPlayerDocuments', function(ownedDocuments, ownedPhotos)
        currentDocumentsMenu = menuIndex

        SendNUIMessage({
            action = 'openDocumentsMenu',
            documentsList = Config.DocumentsMenu[menuIndex].documentsList,
            ownedDocuments = ownedDocuments,
            ownedPhotos = ownedPhotos,
        })

        SetNuiFocus(true, true)
    end)
end
