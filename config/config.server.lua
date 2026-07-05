SV = {}

local function getESXVariable(xPlayer, key)
    if not xPlayer then
        return nil
    end

    if xPlayer.variables and xPlayer.variables[key] ~= nil then
        return xPlayer.variables[key]
    end

    if xPlayer.get then
        return xPlayer.get(key)
    end

    return nil
end

local function getQBCoreCharInfo(xPlayer, key)
    return xPlayer
        and xPlayer.PlayerData
        and xPlayer.PlayerData.charinfo
        and xPlayer.PlayerData.charinfo[key]
        or nil
end

SV.Webhooks = {
    ['GET_DOCUMENT'] = "",
    ['INVALIDATION_DOCUMENT'] = "",
}

SV.WebhookText = {
    ['TITLE.GET_DOCUMENT'] = "",
    ['DESCRIPTION.GET_DOCUMENT'] = [[
        Player %s [%s] took the document %s, serial number %s.
    ]],

    ['TITLE.INVALIDATION_DOCUMENT'] = "",
    ['DESCRIPTION.INVALIDATION_DOCUMENT'] = [[
        Player %s [%s] invalidated document serial number %s.
    ]],
}

SV.Webhook = function(webhook_id, title, description, color, footer)
    local DiscordWebHook = SV.Webhooks[webhook_id]
    local embeds = {{
        ["title"] = title,
        ["type"] = "rich",
        ["description"] = description,
        ["color"] = color,
        ["footer"] = {
            ["text"] = tostring(footer or 'vms_documentsv2')..' - '..os.date(),
        },
    }}
    PerformHttpRequest(DiscordWebHook, function(err, text, headers) end, 'POST', json.encode({embeds = embeds}), {['Content-Type'] = 'application/json'})
end

SV.getDocumentsData = {
    ['firstName'] = {
        dataName = 'firstName',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
    ['lastName'] = {
        dataName = 'lastName',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
    ['dateOfBirth'] = {
        dataName = 'dateOfBirth',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
    ['badgeNumber'] = {
        dataName = 'badgeNumber',
        getData = function(self, src, xPlayer)
            if GetResourceState('vms_bossmenu') == 'started' then
                local badgeNumber = nil
                local response = false
    
                local playerJob = Config.Core == "ESX" and xPlayer.job.name or xPlayer.PlayerData.job.name

                exports['vms_bossmenu']:getPlayerBadge(src, playerJob, function(badge)
                    badgeNumber = badge
                    response = true
                end)
    
                local timeoutAt = GetGameTimer() + 5000

                while not response and GetGameTimer() < timeoutAt do
                    Citizen.Wait(200)
                end
                
                return badgeNumber or 'NONE'
                
            else
                local data = SV.getPlayerData(xPlayer, self.dataName);
                return data
                
            end
        end
    },
    ['jobGrade'] = {
        dataName = 'jobGrade',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerJobGradeLabel(xPlayer)
            return data
        end
    },
    ['height'] = {
        dataName = 'height',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
    ['nationality'] = {
        dataName = 'nationality',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
    ['ssn'] = {
        dataName = 'ssn',
        getData = function(self, src, xPlayer)
            local data = SV.getPlayerData(xPlayer, self.dataName)
            return data
        end
    },
}

SV.getDocumentsLicense = {
    ['drive_a'] = {
        licenseName = 'drive_a',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'A'
                end
                cb(text)
            end)
        end,
    },
    ['drive_b'] = {
        licenseName = 'drive_b',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'B'
                end
                cb(text)
            end)
        end,
    },
    ['drive_c'] = {
        licenseName = 'drive_c',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'C'
                end
                cb(text)
            end)
        end,
    },
    ['practical_plane'] = {
        licenseName = 'practical_plane',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'Plane'
                end
                cb(text)
            end)
        end,
    },
    ['practical_helicopter'] = {
        licenseName = 'practical_helicopter',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'Helicopter'
                end
                cb(text)
            end)
        end,
    },
    ['practical_boat'] = {
        licenseName = 'practical_boat',
        getLicense = function(self, src, xPlayer, cb)
            SV.getLicense(src, xPlayer, self.licenseName, function(haveLicense)
                local text = ''
                if haveLicense then
                    text = 'Completed'
                end
                cb(text)
            end)
        end,
    },
}

SV.getLicense = function(src, xPlayer, licenseName, cb)
    if GetResourceState('esx_license') == 'started' then
        TriggerEvent('esx_license:checkLicense', src, licenseName, function(haveLicense)
            cb(haveLicense)
        end)

    else
        if Config.Core == "QB-Core" then
            local licences = xPlayer.PlayerData.metadata and xPlayer.PlayerData.metadata.licences or {}
            cb(licences[licenseName] == true)
        else
            cb(false)
        end

    end
end

SV.getIdentifier = function(xPlayer)
    if Config.Core == "ESX" then
        return xPlayer.identifier
    elseif Config.Core == "QB-Core" then
        return xPlayer.PlayerData.citizenid
    end
end

SV.getCharacterName = function(xPlayer)
    if Config.Core == "ESX" then
        return xPlayer.getName()
    elseif Config.Core == "QB-Core" then
        return (getQBCoreCharInfo(xPlayer, 'firstname') or '')..' '..(getQBCoreCharInfo(xPlayer, 'lastname') or '')
    end
end

SV.getPlayer = function(src)
    if not Core and Config.CoreExport then
        Core = Config.CoreExport()
    end

    if not Core then
        return nil
    end

    if Config.Core == "ESX" then
        return Core.GetPlayerFromId(src)
    elseif Config.Core == "QB-Core" then
        return Core.Functions.GetPlayer(src)
    end

    return nil
end

SV.getPlayerData = function(xPlayer, name)
    if Config.Core == "ESX" then
        if name == 'firstName' then
            return getESXVariable(xPlayer, 'firstName') or getESXVariable(xPlayer, 'firstname') or ''

        elseif name == 'lastName' then
            return getESXVariable(xPlayer, 'lastName') or getESXVariable(xPlayer, 'lastname') or ''

        elseif name == 'dateOfBirth' then
            return getESXVariable(xPlayer, 'dateofbirth') or getESXVariable(xPlayer, 'dateOfBirth') or ''

        elseif name == 'height' then
            return getESXVariable(xPlayer, 'height') or ''
            
        elseif name == 'nationality' then
            return getESXVariable(xPlayer, 'nationality') or ''
            
        elseif name == 'ssn' then
            return getESXVariable(xPlayer, 'ssn') or SV.getIdentifier(xPlayer)

        elseif name == 'badgeNumber' then
            -- Ide kösd be a saját badge rendszered exportját, ha nem vms_bossmenu-t használsz.
            return 'NONE'

        end
    elseif Config.Core == "QB-Core" then
        if name == 'firstName' then
            return getQBCoreCharInfo(xPlayer, 'firstname') or ''

        elseif name == 'lastName' then
            return getQBCoreCharInfo(xPlayer, 'lastname') or ''

        elseif name == 'dateOfBirth' then
            return getQBCoreCharInfo(xPlayer, 'birthdate') or ''

        elseif name == 'height' then
            return getQBCoreCharInfo(xPlayer, 'height') or 0
            
        elseif name == 'nationality' then
            return getQBCoreCharInfo(xPlayer, 'nationality') or ''
            
        elseif name == 'ssn' then
            return xPlayer.PlayerData.citizenid

        elseif name == 'badgeNumber' then
            -- Ide kösd be a saját badge rendszered exportját, ha nem vms_bossmenu-t használsz.
            return 'NONE'

        end
    end

    return ''
end

SV.getPlayerJob = function(xPlayer)
    if Config.Core == "ESX" then
        return xPlayer.job.name
    elseif Config.Core == "QB-Core" then
        return xPlayer.PlayerData.job.name
    end
end

SV.getPlayerJobGradeLabel = function(xPlayer)
    if Config.Core == "ESX" then
        return xPlayer.job.grade_label
    elseif Config.Core == "QB-Core" then
        return xPlayer.PlayerData.job.grade.name
    end
end

SV.getMoney = function(xPlayer, moneyType)
    if Config.Core == "ESX" then
        if moneyType == 'cash' or moneyType == 'money' then
            return xPlayer.getMoney and xPlayer.getMoney() or 0
        end

        local account = xPlayer.getAccount and xPlayer.getAccount(moneyType) or nil
        return account and account.money or 0
    elseif Config.Core == "QB-Core" then
        return xPlayer.Functions.GetMoney(moneyType) or 0
    end

    return 0
end

SV.removeMoney = function(xPlayer, moneyType, count)
    count = tonumber(count) or 0

    if count <= 0 then
        return
    end

    if Config.Core == "ESX" then
        if moneyType == 'cash' or moneyType == 'money' then
            if xPlayer.removeMoney then
                xPlayer.removeMoney(count)
            end
            return
        end

        if xPlayer.removeAccountMoney then
            xPlayer.removeAccountMoney(moneyType, count)
        end
    elseif Config.Core == "QB-Core" then
        xPlayer.Functions.RemoveMoney(moneyType, count)
    end
end


-- Items:
SV.registerUsableItem = function(name, cb)
    if GetResourceState('ox_inventory') == 'started' then
        -- RealRPG / custom ox_inventory compatibility:
        -- Prefer the inventory's own usable-item bridge when it exists, because
        -- right-click -> Use goes through ox_inventory, not always ESX.UseItem.
        local registeredWithOx = false

        local ok, err = pcall(function()
            exports['ox_inventory']:RegisterUsableItem(name, function(src, item)
                item = item or {}
                cb(src, item.name or name, {
                    metadata = item.metadata or item.info or {},
                    slot = item.slot,
                    count = item.count,
                })
            end)
            registeredWithOx = true
        end)

        if not ok then
            print(('[vms_documentsv2] ox_inventory RegisterUsableItem failed for %s: %s'):format(tostring(name), tostring(err)))
        end

        if registeredWithOx then
            return
        end

        if Config.Core == "ESX" then
            Core.RegisterUsableItem(name, function(src, itemName, itemData)
                cb(src, itemName or name, {metadata = itemData and itemData.metadata or {}})
            end)
    
        elseif Config.Core == "QB-Core" then
            Core.Functions.CreateUseableItem(name, function(src, item)
                cb(src, item and item.name or name, {metadata = item and item.metadata or {}})
            end)
    
        end

    elseif GetResourceState('qs-inventory') == 'started' then
        exports['qs-inventory']:CreateUsableItem(name, function(src, item)
            cb(src, item.name, {metadata = item and item.info or {}})
        end)

    elseif GetResourceState('origen_inventory') == 'started' then
        exports['origen_inventory']:CreateUseableItem(name, function(src, item)
            cb(src, item.name, {metadata = item and item.metadata or {}})
        end)

    else
        if Config.Core == "ESX" then
            Core.RegisterUsableItem(name, function(src, itemName, itemData)
                cb(src, itemName, {metadata = itemData and itemData.metadata or {}})
            end)
    
        elseif Config.Core == "QB-Core" then
            Core.Functions.CreateUseableItem(name, function(src, item)
                cb(src, item.name, {metadata = item and item.info or {}})
            end)
    
        end
    end
end

SV.addItem = function(src, xPlayer, name, count, metadata)
    if GetResourceState('ox_inventory') == 'started' then
        exports['ox_inventory']:AddItem(src, name, count, metadata, nil)
        
    elseif GetResourceState('qb-inventory') == 'started' then
        exports['qb-inventory']:AddItem(src, name, count, false, metadata)

    elseif GetResourceState('qs-inventory') == 'started' then
        exports['qs-inventory']:AddItem(src, name, count, false, metadata)

    elseif GetResourceState('tgiann-inventory') == 'started' then
        exports["tgiann-inventory"]:AddItem(src, name, count, false, metadata, false)

    elseif GetResourceState('core_inventory') == 'started' then
        exports['core_inventory']:addItem(src, name, count, metadata)

    elseif GetResourceState('origen_inventory') == 'started' then
        exports['origen_inventory']:addItem(src, name, count, metadata)
        
    else
        if Config.Core == "ESX" then
            xPlayer.addInventoryItem(name, count)

        elseif Config.Core == "QB-Core" then
            xPlayer.Functions.AddItem(name, count, false, metadata)

        end
    end
    
end