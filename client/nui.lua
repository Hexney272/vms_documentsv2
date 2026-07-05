local function collectDocumentLabels()
    local labels = {}

    if not Config.DocumentsMenu or not next(Config.DocumentsMenu) then
        return labels
    end

    for _, menu in pairs(Config.DocumentsMenu) do
        if menu.documentsList then
            for _, document in pairs(menu.documentsList) do
                if document.name and document.label and not labels[document.name] then
                    labels[document.name] = document.label
                end
            end
        end
    end

    return labels
end

RegisterNUICallback('loaded', function(_, cb)
    SendNUIMessage({
        action = 'loaded',
        lang = Config.Language,
        documentsNames = collectDocumentLabels(),
    })

    cb(true)
end)

RegisterNUICallback('close', function(data, cb)
    if data.menu == 'documents_menu' then
        currentDocumentsMenu = nil

        SendNUIMessage({
            action = 'closeDocumentsMenu',
        })
    elseif data.menu == 'check_document_menu' then
        openedMenu = nil

        SendNUIMessage({
            action = 'closeCheckDocumentsMenu',
        })
    end

    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('compressedPhoto', function(data, cb)
    if data.compressedBase64 then
        if data.documentName then
            TriggerServerEvent(
                'vms_documentsv2:sv:giveDocumentByExport',
                data.documentName,
                data.compressedBase64,
                data.cancelCurrentActive
            )
        else
            TriggerServerEvent('vms_documentsv2:sv:makePhoto', makingPhoto, data.compressedBase64)
        end
    end

    makingPhoto = false
    cb(true)
end)

RegisterNUICallback('orderDocument', function(data, cb)
    if data.name and currentDocumentsMenu then
        TriggerServerEvent('vms_documentsv2:sv:orderDocument', currentDocumentsMenu, data.name, data.photoId)
    end

    cb(true)
end)

RegisterNUICallback('invalidateDocument', function(data, cb)
    if data.serialNumber then
        TriggerServerEvent('vms_documentsv2:sv:invalidateDocument', data.serialNumber)
    end

    cb(true)
end)

RegisterNUICallback('removePhoto', function(data, cb)
    if data.id then
        TriggerServerEvent('vms_documentsv2:sv:removePhoto', data.id)
    end

    cb(true)
end)

RegisterNUICallback('getInfoBySerialNumber', function(data, cb)
    if data.serialNumber then
        TriggerServerEvent('vms_documentsv2:sv:getInfoBySerialNumber', data.serialNumber)
    end

    cb(true)
end)
