Core = Config.CoreExport()
photosJsonData = {}

local DATABASE_TIMEOUT_MS = 10000
local DOCUMENT_VIEW_CACHE_SECONDS = 120
local MAX_COMPRESSED_PHOTO_LENGTH = Config.MaxCompressedPhotoLength or 850000

local activePhotographers = {}
local pendingPhotoDocuments = {}
local pendingPaidOrders = {}
local itemUseCooldown = {}
local documentViewCache = {}

local function notify(src, message, time, notifyType)
    TriggerClientEvent('vms_documentsv2:notification', src, message, time or 4500, notifyType or 'info')
end

local function isNonEmptyString(value)
    return type(value) == 'string' and value ~= ''
end

local function normalizeSerialNumber(serialNumber)
    if type(serialNumber) ~= 'string' and type(serialNumber) ~= 'number' then
        return nil
    end

    serialNumber = tostring(serialNumber):upper():gsub('%s+', '')

    if #serialNumber < 3 or #serialNumber > 64 then
        return nil
    end

    if not serialNumber:match('^[%w%-_]+$') then
        return nil
    end

    return serialNumber
end

local function isValidCompressedPhoto(value)
    return type(value) == 'string'
        and #value > 32
        and #value <= MAX_COMPRESSED_PHOTO_LENGTH
        and value:find('^data:image/') ~= nil
end

local function clearExpiredDocumentCache(src)
    local cache = documentViewCache[src]

    if not cache then
        return
    end

    local now = os.time()

    for serialNumber, entry in pairs(cache) do
        if not entry.expiresAt or entry.expiresAt <= now then
            cache[serialNumber] = nil
        end
    end

    if not next(cache) then
        documentViewCache[src] = nil
    end
end

local function cacheDocumentView(src, documentName, metadata, photo)
    if not metadata or not metadata.document_id then
        return
    end

    local serialNumber = normalizeSerialNumber(metadata.document_id)

    if not serialNumber then
        return
    end

    documentViewCache[src] = documentViewCache[src] or {}
    documentViewCache[src][serialNumber] = {
        documentName = documentName,
        metadata = metadata,
        photo = photo,
        expiresAt = os.time() + DOCUMENT_VIEW_CACHE_SECONDS,
    }
end

local function getCachedDocumentView(src, documentName, metadata)
    if not metadata or not metadata.document_id then
        return nil
    end

    clearExpiredDocumentCache(src)

    local serialNumber = normalizeSerialNumber(metadata.document_id)
    local cache = serialNumber and documentViewCache[src] and documentViewCache[src][serialNumber] or nil

    if not cache then
        return nil
    end

    if cache.documentName ~= documentName then
        return nil
    end

    return cache
end

local function loadPhotos()
    local content = LoadResourceFile(GetCurrentResourceName(), 'photos.json')
    photosJsonData = json.decode(content or '{}') or {}
end

local function savePhotos()
    SaveResourceFile(
        GetCurrentResourceName(),
        'photos.json',
        json.encode(photosJsonData, {indent = true}),
        -1
    )
end

local function ensurePlayerPhotos(identifier)
    photosJsonData[identifier] = photosJsonData[identifier] or {}
    return photosJsonData[identifier]
end

local function fetchAllSync(query, params)
    local waiting = true
    local result = {}
    local timeoutAt = GetGameTimer() + DATABASE_TIMEOUT_MS

    MySQL.Async.fetchAll(query, params or {}, function(rows)
        result = rows or {}
        waiting = false
    end)

    while waiting do
        if GetGameTimer() > timeoutAt then
            library.Debug(('Database fetch timeout: %s'):format(query), 'warn')
            break
        end

        Citizen.Wait(50)
    end

    return result
end

local function executeSync(query, params)
    local waiting = true
    local affectedRows = 0
    local timeoutAt = GetGameTimer() + DATABASE_TIMEOUT_MS

    MySQL.Async.execute(query, params or {}, function(result)
        affectedRows = result or 0
        waiting = false
    end)

    while waiting do
        if GetGameTimer() > timeoutAt then
            library.Debug(('Database execute timeout: %s'):format(query), 'warn')
            break
        end

        Citizen.Wait(50)
    end

    return affectedRows
end

local function ensureDatabaseTables()
    if not Config.AutoExecuteQuery then
        return
    end

    executeSync([[
        CREATE TABLE IF NOT EXISTS `player_documents` (
            `serial_number` varchar(64) NOT NULL,
            `owner` varchar(128) NOT NULL,
            `type` varchar(64) NOT NULL,
            `photo` longtext NULL,
            `valid` tinyint(1) NOT NULL DEFAULT 1,
            `for_pickup` tinyint(1) NOT NULL DEFAULT 0,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`serial_number`),
            KEY `idx_owner_valid` (`owner`, `valid`),
            KEY `idx_owner_type_valid` (`owner`, `type`, `valid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    executeSync('ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `photo` LONGTEXT NULL')
    executeSync('ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `valid` TINYINT(1) NOT NULL DEFAULT 1')
    executeSync('ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `for_pickup` TINYINT(1) NOT NULL DEFAULT 0')
    executeSync('ALTER TABLE `player_documents` ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP')
end

local function getPlayerContext(src)
    local xPlayer = SV.getPlayer(src)

    if not xPlayer then
        return nil, nil
    end

    return xPlayer, SV.getIdentifier(xPlayer)
end

local function getPhoto(identifier, photoId)
    photoId = tonumber(photoId)

    if not photoId or not photosJsonData[identifier] then
        return nil, nil
    end

    local photo = photosJsonData[identifier][photoId]

    if not photo or photo.used then
        return nil, nil
    end

    return photo, photoId
end

local function removeStoredPhoto(identifier, photoId)
    local photo, numericPhotoId = getPhoto(identifier, photoId)

    if not photo then
        return false
    end

    table.remove(photosJsonData[identifier], numericPhotoId)
    savePhotos()
    return true
end

local function countActivePhotos(identifier)
    local photos = ensurePlayerPhotos(identifier)
    local count = 0

    for _, photo in ipairs(photos) do
        if not photo.used then
            count = count + 1
        end
    end

    return count
end

local function getLicenseText(src, xPlayer, licenseName)
    local definition = SV.getDocumentsLicense[licenseName]

    if not definition then
        return ''
    end

    local waiting = true
    local value = ''
    local attempts = 0

    definition:getLicense(src, xPlayer, function(result)
        value = result or ''
        waiting = false
    end)

    while waiting and attempts < 100 do
        attempts = attempts + 1
        Citizen.Wait(50)
    end

    return value or ''
end

local function collectLicenseData(src, xPlayer, document)
    local licenseData = {}
    local hasAnyLicense = not document.licenses or #document.licenses == 0

    for _, licenseName in ipairs(document.licenses or {}) do
        local value = getLicenseText(src, xPlayer, licenseName)
        licenseData[licenseName] = value

        if value and value ~= '' and value ~= ' ' then
            hasAnyLicense = true
        end
    end

    return licenseData, hasAnyLicense
end

local function collectDocumentMetadata(src, xPlayer, document, serialNumber, licenseData)
    local metadata = {}

    for _, dataName in ipairs(document.data or {}) do
        local definition = SV.getDocumentsData[dataName]

        if definition then
            metadata[dataName] = definition:getData(src, xPlayer)
        end
    end

    for licenseName, value in pairs(licenseData or {}) do
        metadata[licenseName] = value
    end

    metadata.document_id = serialNumber

    return metadata
end

local function hasRequiredDocumentLicense(src, xPlayer, document)
    local licenseData, hasAnyLicense = collectLicenseData(src, xPlayer, document)

    if document.needAnyLicenseToGetDocument and not hasAnyLicense then
        notify(src, TRANSLATE('notify.you_have_no_license'), 6500, 'error')
        return false, licenseData
    end

    return true, licenseData
end

local function insertDocument(serialNumber, identifier, documentName, photo, forPickup)
    MySQL.Async.insert(
        'INSERT INTO player_documents (`serial_number`, `owner`, `type`, `photo`, `for_pickup`) VALUES (@serial_number, @owner, @type, @photo, @for_pickup)',
        {
            ['@serial_number'] = serialNumber,
            ['@owner'] = identifier,
            ['@type'] = documentName,
            ['@photo'] = photo,
            ['@for_pickup'] = forPickup and 1 or 0,
        }
    )
end

local function sendDocumentsMenuUpdate(src, identifier)
    TriggerClientEvent(
        'vms_documentsv2:cl:updateDocumentsMenu',
        src,
        getMyPhotos(identifier),
        getMyDocuments(identifier)
    )
end

local function sendGetDocumentWebhook(src, xPlayer, identifier, documentName, serialNumber)
    if not SV.Webhooks.GET_DOCUMENT or SV.Webhooks.GET_DOCUMENT == '' then
        return
    end

    SV.Webhook(
        'GET_DOCUMENT',
        SV.WebhookText['TITLE.GET_DOCUMENT'],
        SV.WebhookText['DESCRIPTION.GET_DOCUMENT']:format(
            SV.getCharacterName(xPlayer),
            src,
            documentName,
            serialNumber
        ),
        16053285,
        identifier
    )
end

local function sendInvalidationWebhook(src, xPlayer, identifier, serialNumber)
    if not SV.Webhooks.INVALIDATION_DOCUMENT or SV.Webhooks.INVALIDATION_DOCUMENT == '' then
        return
    end

    SV.Webhook(
        'INVALIDATION_DOCUMENT',
        SV.WebhookText['TITLE.INVALIDATION_DOCUMENT'],
        SV.WebhookText['DESCRIPTION.INVALIDATION_DOCUMENT']:format(
            SV.getCharacterName(xPlayer),
            src,
            serialNumber
        ),
        16053285,
        identifier
    )
end

local function getPlayerJobGrade(xPlayer)
    if Config.Core == 'ESX' then
        return xPlayer.job and xPlayer.job.grade or 0
    end

    if Config.Core == 'QB-Core' then
        return xPlayer.PlayerData
            and xPlayer.PlayerData.job
            and xPlayer.PlayerData.job.grade
            and xPlayer.PlayerData.job.grade.level
            or 0
    end

    return 0
end

local function canCheckDocumentSerial(xPlayer)
    local settings = Config.CheckDocumentBySerial

    if not settings or not settings.useRequiredJob then
        return true
    end

    local jobName = SV.getPlayerJob(xPlayer)
    local jobGrade = getPlayerJobGrade(xPlayer)
    local allowedRule = settings.requiredJob and settings.requiredJob[jobName]

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

Citizen.CreateThread(function()
    Citizen.Wait(1500)
    ensureDatabaseTables()
    loadPhotos()
end)

function registerToPickup(src, documentName, photoId, cb)
    local xPlayer, identifier = getPlayerContext(src)
    local document = Config.Documents[documentName]

    if not xPlayer or not document then
        return cb(false)
    end

    local canUseLicense = hasRequiredDocumentLicense(src, xPlayer, document)

    if not canUseLicense then
        return cb(false)
    end

    local photoBase64 = nil

    if photoId then
        local photo = getPhoto(identifier, photoId)

        if not photo then
            return cb(false)
        end

        photoBase64 = photo.img
    end

    local serialNumber = library.CreateIdentificationId(documentName)

    insertDocument(serialNumber, identifier, documentName, photoBase64, true)

    if photoId then
        removeStoredPhoto(identifier, photoId)
    end

    library.Debug(('Document %s was ordered by player %s.'):format(documentName, src))
    cb(serialNumber)
end
exports('registerToPickup', registerToPickup)

function pickupDocument(src, serialNumber, cb)
    local xPlayer, identifier = getPlayerContext(src)
    serialNumber = normalizeSerialNumber(serialNumber)

    if not xPlayer or not serialNumber then
        return cb(false)
    end

    local rows = fetchAllSync(
        'SELECT * FROM player_documents WHERE owner = @identifier AND serial_number = @serial_number AND for_pickup = 1',
        {
            ['@identifier'] = identifier,
            ['@serial_number'] = serialNumber,
        }
    )

    local row = rows[1]

    if not row then
        return cb(false)
    end

    local documentName = row.type
    local document = Config.Documents[documentName]

    if not document or not document.itemName then
        return cb(false)
    end

    executeSync(
        'UPDATE player_documents SET for_pickup = 0 WHERE serial_number = @serial_number',
        {['@serial_number'] = serialNumber}
    )

    local licenseData = collectLicenseData(src, xPlayer, document)
    local metadata = collectDocumentMetadata(src, xPlayer, document, serialNumber, licenseData)

    SV.addItem(src, xPlayer, document.itemName, 1, metadata)
    cb(true)
end
exports('pickupDocument', pickupDocument)

function removePhoto(identifier, photoId)
    return removeStoredPhoto(identifier, photoId)
end
exports('removePhoto', removePhoto)

function getMyPhotos(identifier)
    if not identifier then
        return {}
    end

    return ensurePlayerPhotos(identifier)
end
exports('getMyPhotos', getMyPhotos)

function getMyDocuments(identifier)
    if not identifier then
        return {}
    end

    return fetchAllSync(
        'SELECT * FROM player_documents WHERE owner = @identifier AND valid = 1 AND for_pickup = 0',
        {['@identifier'] = identifier}
    )
end
exports('getMyDocuments', getMyDocuments)

function giveDocument(src, documentName, photoId, cancelCurrentActive)
    local xPlayer, identifier = getPlayerContext(src)
    local document = Config.Documents[documentName]

    if not xPlayer or not document or not document.itemName then
        return false
    end

    if not photoId then
        pendingPhotoDocuments[src] = {
            documentName = documentName,
            cancelCurrentActive = cancelCurrentActive,
            expiresAt = os.time() + DOCUMENT_VIEW_CACHE_SECONDS,
        }

        Citizen.SetTimeout(DOCUMENT_VIEW_CACHE_SECONDS * 1000, function()
            local pendingDocument = pendingPhotoDocuments[src]

            if pendingDocument and pendingDocument.documentName == documentName and pendingDocument.expiresAt <= os.time() then
                pendingPhotoDocuments[src] = nil
                pendingPaidOrders[src] = nil
            end
        end)

        TriggerClientEvent('vms_documentsv2:cl:takeDocumentPhoto', src, documentName, cancelCurrentActive)
        return nil
    end

    local photo = getPhoto(identifier, photoId)

    if not photo then
        return false
    end

    local canUseLicense, licenseData = hasRequiredDocumentLicense(src, xPlayer, document)

    if not canUseLicense then
        return false
    end

    local serialNumber = library.CreateIdentificationId(documentName)

    if cancelCurrentActive then
        executeSync(
            'UPDATE player_documents SET valid = @valid WHERE owner = @owner AND type = @type',
            {
                ['@valid'] = 0,
                ['@owner'] = identifier,
                ['@type'] = documentName,
            }
        )
    end

    insertDocument(serialNumber, identifier, documentName, photo.img, false)
    removeStoredPhoto(identifier, photoId)

    sendGetDocumentWebhook(src, xPlayer, identifier, documentName, serialNumber)

    local metadata = collectDocumentMetadata(src, xPlayer, document, serialNumber, licenseData)

    SV.addItem(src, xPlayer, document.itemName, 1, metadata)
    notify(src, TRANSLATE('notify.received'), 4500, 'success')

    return true
end
exports('giveDocument', giveDocument)

function invalidateDocument(identifier, serialNumber)
    serialNumber = normalizeSerialNumber(serialNumber)

    if not identifier or not serialNumber then
        return false
    end

    local rows = fetchAllSync(
        'SELECT serial_number FROM player_documents WHERE owner = @identifier AND serial_number = @serial_number AND valid = 1 LIMIT 1',
        {
            ['@identifier'] = identifier,
            ['@serial_number'] = serialNumber,
        }
    )

    if not rows[1] then
        return false
    end

    executeSync(
        'UPDATE player_documents SET valid = 0 WHERE owner = @identifier AND serial_number = @serial_number',
        {
            ['@identifier'] = identifier,
            ['@serial_number'] = serialNumber,
        }
    )

    return true
end
exports('invalidateDocument', invalidateDocument)

function isAnyDocumentValid(identifier, documentName)
    if not identifier or not documentName then
        return false
    end

    local rows = fetchAllSync(
        'SELECT serial_number FROM player_documents WHERE type = @type AND owner = @identifier AND valid = 1 LIMIT 1',
        {
            ['@type'] = documentName,
            ['@identifier'] = identifier,
        }
    )

    return rows[1] and rows[1].serial_number or false
end
exports('isAnyDocumentValid', isAnyDocumentValid)

Citizen.CreateThread(function()
    for documentName, document in pairs(Config.Documents) do
        if document.itemName then
            local configuredDocumentName = documentName
            local configuredItemName = document.itemName

            SV.registerUsableItem(configuredItemName, function(src, itemName, itemData)
                if itemUseCooldown[src] then
                    notify(src, TRANSLATE('notify.wait'), 4500, 'info')
                    return
                end

                itemUseCooldown[src] = true

                local function releaseCooldownLater()
                    Citizen.CreateThread(function()
                        Citizen.Wait(6500)
                        itemUseCooldown[src] = nil
                    end)
                end

                local function finishWithDocument(row, metadata)
                    if not row then
                        notify(src, TRANSLATE('notify.didnt_found'), 4500, 'error')
                        releaseCooldownLater()
                        return
                    end

                    local documentConfig = Config.Documents[row.type]
                    local expectedItemName = documentConfig and documentConfig.itemName or configuredItemName

                    if documentConfig and expectedItemName == configuredItemName then
                        metadata = metadata or {}
                        metadata.document_id = normalizeSerialNumber(row.serial_number or metadata.document_id)

                        cacheDocumentView(src, row.type, metadata, row.photo)
                        TriggerClientEvent('vms_documentsv2:cl:showDocument', src, expectedItemName, metadata, row.photo)
                    else
                        notify(src, TRANSLATE('notify.didnt_found'), 4500, 'error')
                    end

                    releaseCooldownLater()
                end

                local xPlayer, identifier = getPlayerContext(src)
                local metadata = itemData and itemData.metadata or {}

                if not xPlayer or not identifier then
                    itemUseCooldown[src] = nil
                    return
                end

                -- Preferred path: proper document item with metadata.document_id.
                -- Compatibility path: older/manual items may not have document_id, so
                -- we fall back to the latest valid DB document of this type owned by the player.
                local serialNumber = normalizeSerialNumber(
                    metadata and (
                        metadata.document_id or
                        metadata.serial_number or
                        metadata.serial or
                        metadata.identificationId
                    )
                )

                if serialNumber then
                    MySQL.Async.fetchAll(
                        'SELECT type, serial_number, photo FROM player_documents WHERE owner = @identifier AND serial_number = @serial_number AND valid = 1 AND for_pickup = 0 LIMIT 1',
                        {
                            ['@identifier'] = identifier,
                            ['@serial_number'] = serialNumber,
                        },
                        function(result)
                            finishWithDocument(result and result[1], metadata)
                        end
                    )
                else
                    MySQL.Async.fetchAll(
                        'SELECT type, serial_number, photo FROM player_documents WHERE owner = @identifier AND type = @type AND valid = 1 AND for_pickup = 0 ORDER BY created_at DESC LIMIT 1',
                        {
                            ['@identifier'] = identifier,
                            ['@type'] = configuredDocumentName,
                        },
                        function(result)
                            finishWithDocument(result and result[1], metadata)
                        end
                    )
                end
            end)
        end
    end
end)

library.RegisterCallback('vms_documentsv2:canDoPhotos', function(src, cb, photographerIndex)
    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return cb(false)
    end

    local activeSrc = activePhotographers[photographerIndex]

    if activeSrc and SV.getPlayer(activeSrc) then
        notify(src, TRANSLATE('notify.photographer_is_busy'), 4500, 'error')
        return cb(false)
    end

    ensurePlayerPhotos(identifier)

    if Config.ActivePhotosLimitPerPlayer ~= -1 and countActivePhotos(identifier) >= Config.ActivePhotosLimitPerPlayer then
        notify(src, TRANSLATE('notify.reached_photos_limit'), 4500, 'error')
        return cb(false)
    end

    local price = Config.PhotosPrices or 0

    if price > 0 and SV.getMoney(xPlayer, 'cash') < price then
        notify(src, TRANSLATE('notify.no_money'), 4500, 'error')
        return cb(false)
    end

    activePhotographers[photographerIndex] = src
    cb(true)
end)

library.RegisterCallback('vms_documentsv2:getPlayerDocuments', function(src, cb)
    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return cb({}, {})
    end

    cb(getMyDocuments(identifier), getMyPhotos(identifier))
end)

RegisterNetEvent('vms_documentsv2:sv:makePhoto', function(photographerIndex, compressedBase64)
    local src = source

    if activePhotographers[photographerIndex] ~= src then
        return
    end

    if not isValidCompressedPhoto(compressedBase64) then
        activePhotographers[photographerIndex] = nil
        notify(src, TRANSLATE('notify.photo_error') or 'Invalid photo.', 4500, 'error')
        return
    end

    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        activePhotographers[photographerIndex] = nil
        return
    end

    local price = Config.PhotosPrices or 0

    if price > 0 and SV.getMoney(xPlayer, 'cash') < price then
        activePhotographers[photographerIndex] = nil
        return
    end

    local photos = ensurePlayerPhotos(identifier)

    for _ = 1, Config.CountOfPhotos do
        photos[#photos + 1] = {
            img = compressedBase64,
        }
    end

    library.Debug(('Player %s took %s photos with a photographer.'):format(src, Config.CountOfPhotos))
    activePhotographers[photographerIndex] = nil

    if price > 0 then
        SV.removeMoney(xPlayer, 'cash', price)
    end

    savePhotos()
end)

RegisterNetEvent('vms_documentsv2:sv:giveDocumentByExport', function(documentName, compressedBase64)
    local src = source
    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return
    end

    local pendingDocument = pendingPhotoDocuments[src]

    if not pendingDocument or pendingDocument.documentName ~= documentName then
        library.Debug(('Rejected unauthorized document photo upload from player %s for %s.'):format(src, tostring(documentName)), 'warn')
        return
    end

    if not isValidCompressedPhoto(compressedBase64) then
        pendingPhotoDocuments[src] = nil
        notify(src, TRANSLATE('notify.photo_error') or 'Invalid photo.', 4500, 'error')
        return
    end

    local photos = ensurePlayerPhotos(identifier)
    local photoId = #photos + 1

    photos[photoId] = {
        img = compressedBase64,
    }

    savePhotos()

    local success = giveDocument(src, documentName, photoId, pendingDocument.cancelCurrentActive)

    if not success then
        removeStoredPhoto(identifier, photoId)
        return
    end

    local pendingOrder = pendingPaidOrders[src]

    if pendingOrder and pendingOrder.documentName == documentName then
        if pendingOrder.price and pendingOrder.price > 0 then
            SV.removeMoney(xPlayer, 'cash', pendingOrder.price)
        end

        sendDocumentsMenuUpdate(src, identifier)
        pendingPaidOrders[src] = nil
    end

    pendingPhotoDocuments[src] = nil
end)

RegisterNetEvent('vms_documentsv2:sv:cannotMakePhoto', function(photographerIndex)
    local src = source

    if activePhotographers[photographerIndex] == src then
        activePhotographers[photographerIndex] = nil
    end
end)

RegisterNetEvent('vms_documentsv2:sv:cancelPendingDocumentPhoto', function(documentName)
    local src = source
    local pendingDocument = pendingPhotoDocuments[src]

    if pendingDocument and pendingDocument.documentName == documentName then
        pendingPhotoDocuments[src] = nil
        pendingPaidOrders[src] = nil
    end
end)

RegisterNetEvent('vms_documentsv2:sv:giveDocument', function()
    library.Debug(('Rejected public giveDocument event from player %s. Use the server export instead.'):format(source), 'warn')
end)

RegisterNetEvent('vms_documentsv2:sv:showDocumentToPlayers', function(targets, documentName, metadata)
    local src = source
    local cachedDocument = getCachedDocumentView(src, documentName, metadata)

    if not cachedDocument then
        library.Debug(('Rejected unverified document share from player %s.'):format(src), 'warn')
        return
    end

    local srcPed = GetPlayerPed(src)

    if not srcPed or srcPed == 0 then
        return
    end

    documentName = cachedDocument.documentName
    metadata = cachedDocument.metadata
    local photo = cachedDocument.photo

    local srcCoords = GetEntityCoords(srcPed)

    local function showToTarget(target)
        target = tonumber(target)

        if not target then
            return
        end

        local targetPed = GetPlayerPed(target)

        if not targetPed or targetPed == 0 then
            return
        end

        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(srcCoords.xyz - targetCoords.xyz)

        if distance < Config.ShowDocumentDistance then
            TriggerClientEvent('vms_documentsv2:cl:showDocument', target, documentName, metadata, photo, true)
        end
    end

    if type(targets) == 'table' then
        for _, target in pairs(targets) do
            showToTarget(target)
        end
    else
        showToTarget(targets)
    end
end)

RegisterNetEvent('vms_documentsv2:sv:orderDocument', function(menuIndex, documentName, photoId)
    local src = source
    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return
    end

    local menu = Config.DocumentsMenu[menuIndex]

    if not menu or not menu.documentsList then
        return
    end

    if menu.requiredJob and menu.requiredJob ~= SV.getPlayerJob(xPlayer) then
        notify(src, TRANSLATE('notify.you_dont_have_required_job'), 4500, 'info')
        return
    end

    local selectedDocument = nil

    for _, document in ipairs(menu.documentsList) do
        if document.name == documentName then
            selectedDocument = document
            break
        end
    end

    if not selectedDocument then
        return
    end

    if isAnyDocumentValid(identifier, selectedDocument.name) then
        notify(src, TRANSLATE('notify.you_already_have_valid_document'), 3500, 'error')
        return
    end

    local price = selectedDocument.price or 0

    if price > 0 and SV.getMoney(xPlayer, 'cash') < price then
        notify(src, TRANSLATE('notify.no_money'), 3500, 'error')
        return
    end

    if not photoId then
        pendingPaidOrders[src] = {
            documentName = selectedDocument.name,
            price = price,
            menuIndex = menuIndex,
        }
    end

    local success = giveDocument(src, selectedDocument.name, photoId)

    if success then
        if price > 0 then
            SV.removeMoney(xPlayer, 'cash', price)
        end

        sendDocumentsMenuUpdate(src, identifier)
    end
end)

RegisterNetEvent('vms_documentsv2:sv:invalidateDocument', function(serialNumber)
    local src = source

    if not serialNumber then
        return
    end

    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return
    end

    if not invalidateDocument(identifier, serialNumber) then
        return
    end

    sendInvalidationWebhook(src, xPlayer, identifier, serialNumber)
    sendDocumentsMenuUpdate(src, identifier)
end)

RegisterNetEvent('vms_documentsv2:sv:removePhoto', function(photoId)
    local src = source

    if not photoId then
        return
    end

    local xPlayer, identifier = getPlayerContext(src)

    if not xPlayer then
        return
    end

    if removePhoto(identifier, photoId) then
        sendDocumentsMenuUpdate(src, identifier)
    end
end)

RegisterNetEvent('vms_documentsv2:sv:getInfoBySerialNumber', function(serialNumber)
    local src = source
    serialNumber = normalizeSerialNumber(serialNumber)

    if not serialNumber then
        notify(src, TRANSLATE('notify.didnt_found'), 5000, 'error')
        return
    end

    local xPlayer = SV.getPlayer(src)

    if not xPlayer or not canCheckDocumentSerial(xPlayer) then
        notify(src, TRANSLATE('notify.you_are_not_allowed'), 4500, 'error')
        return
    end

    MySQL.Async.fetchAll(
        'SELECT valid, serial_number FROM player_documents WHERE serial_number = @serial_number LIMIT 1',
        {['@serial_number'] = serialNumber},
        function(result)
            local row = result and result[1]

            if not row then
                notify(src, TRANSLATE('notify.didnt_found'), 5000, 'error')
                return
            end

            TriggerClientEvent('vms_documentsv2:cl:foundDocument', src)

            if row.valid == 0 then
                notify(src, TRANSLATE('notify.found_invalid'), 5000, 'error')
            else
                notify(src, TRANSLATE('notify.found_valid'), 5000, 'success')
            end
        end
    )
end)
