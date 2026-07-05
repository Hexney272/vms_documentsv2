waitingForLoadAfterRestart = false
openedMenu = nil
PlayerData = {}
myIdentifier = nil
currentDocumentsMenu = nil

if Config.Core == 'ESX' then
    ESX = Config.CoreExport()
elseif Config.Core == 'QB-Core' then
    QBCore = Config.CoreExport()
end

local function refreshPlayerData()
    if Config.Core == 'ESX' then
        while not ESX do
            Citizen.Wait(200)
            ESX = Config.CoreExport()
        end

        if not ESX.IsPlayerLoaded or ESX.IsPlayerLoaded() then
            PlayerData = CL.GetPlayerData() or {}
        end
    elseif Config.Core == 'QB-Core' then
        while not QBCore do
            Citizen.Wait(200)
            QBCore = Config.CoreExport()
        end

        PlayerData = CL.GetPlayerData() or {}
    end
end

local function removeTargetZones(entries)
    if not entries then
        return
    end

    for _, entry in pairs(entries) do
        if entry.__target then
            CL.Target('remove-zone', entry.__target)
            entry.__target = nil
        end
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    refreshPlayerData()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if deletePeds then
        deletePeds()
    end

    if Config.UseTarget then
        removeTargetZones(Config.DocumentsMenu)
        removeTargetZones(Config.Photographers)
    end
end)

RegisterNetEvent(Config.PlayerLoaded, function(playerData)
    if Config.Core == 'ESX' and playerData then
        PlayerData = playerData
        return
    end

    PlayerData = CL.GetPlayerData() or {}
end)

RegisterNetEvent(Config.PlayerSetJob, function(job)
    PlayerData = PlayerData or {}
    PlayerData.job = job
end)

RegisterNetEvent('vms_documentsv2:notification', function(message, time, notifyType)
    CL.Notification(message, time, notifyType)
end)

local function resolveDocumentName(documentName, isConfigName)
    if isConfigName or not documentName then
        return documentName
    end

    for configName, document in pairs(Config.Documents) do
        if document.itemName == documentName then
            return configName
        end
    end

    return documentName
end

RegisterNetEvent('vms_documentsv2:cl:showDocument', function(documentName, metadata, photo, isConfigName)
    showDocument(resolveDocumentName(documentName, isConfigName), metadata, photo, isConfigName)
end)

RegisterNetEvent('vms_documentsv2:cl:updateDocumentsMenu', function(ownedPhotos, ownedDocuments)
    if currentDocumentsMenu then
        SendNUIMessage({
            action = 'updateDocumentsMenu',
            ownedDocuments = ownedDocuments,
            ownedPhotos = ownedPhotos,
        })
    end
end)

RegisterNetEvent('vms_documentsv2:cl:foundDocument', function()
    if openedMenu then
        SendNUIMessage({
            action = 'updateCheckDocumentsMenu',
        })
    end
end)

RegisterNetEvent('vms_documentsv2:cl:takeDocumentPhoto', function(documentName, cancelCurrentActive)
    local base64 = CL.CaptureMugshotBase64()

    if not base64 then
        TriggerServerEvent('vms_documentsv2:sv:cancelPendingDocumentPhoto', documentName)
        return
    end

    SendNUIMessage({
        action = 'compressPhoto',
        base64 = base64,
        documentName = documentName,
        cancelCurrentActive = cancelCurrentActive,
    })
end)

local function hasRequiredSerialCheckJob()
    local settings = Config.CheckDocumentBySerial

    if not settings.useRequiredJob then
        return true
    end

    local jobName = CL.GetPlayerJob('name')
    local jobGrade = CL.GetPlayerJob('grade')
    local allowedRule = settings.requiredJob[jobName]

    if not allowedRule then
        return false
    end

    if allowedRule == true then
        return true
    end

    if type(allowedRule) == 'number' then
        return allowedRule == jobGrade
    end

    if type(allowedRule) == 'table' then
        for _, grade in ipairs(allowedRule) do
            if grade == jobGrade then
                return true
            end
        end
    end

    return false
end

local function openCheckDocumentMenu()
    if not hasRequiredSerialCheckJob() then
        CL.Notification(TRANSLATE('notify.you_are_not_allowed'), 4500, 'error')
        return
    end

    openedMenu = true

    SendNUIMessage({
        action = 'openCheckDocumentsMenu',
    })

    SetNuiFocus(true, true)
end

if Config.CheckDocumentBySerial and Config.CheckDocumentBySerial.enabled then
    exports('checkDocumentMenu', openCheckDocumentMenu)

    if Config.CheckDocumentBySerial.command then
        RegisterCommand(Config.CheckDocumentBySerial.command, openCheckDocumentMenu)

        if Config.CheckDocumentBySerial.key then
            RegisterKeyMapping(
                Config.CheckDocumentBySerial.command,
                Config.CheckDocumentBySerial.description,
                'keyboard',
                Config.CheckDocumentBySerial.key
            )
        end
    end
end
