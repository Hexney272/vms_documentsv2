library = {}

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

function library.RegisterCallback(name, cb, ...)
    if Config.Core == 'ESX' then
        Core.RegisterServerCallback(name, cb, ...)
    elseif Config.Core == 'QB-Core' then
        Core.Functions.CreateCallback(name, cb, ...)
    end
end

local function serialExists(serialNumber)
    local waiting = true
    local exists = false

    MySQL.Async.fetchAll(
        'SELECT serial_number FROM player_documents WHERE serial_number = @serial_number LIMIT 1',
        {['@serial_number'] = serialNumber},
        function(result)
            exists = result and result[1] ~= nil
            waiting = false
        end
    )

    while waiting do
        Citizen.Wait(50)
    end

    return exists
end

function library.CreateIdentificationId(documentName)
    local document = Config.Documents[documentName]
    local prefix = document and document.identificationIdPrefix or ''

    prefix = string.upper(prefix or '')

    local serialNumber = nil

    repeat
        serialNumber = ('%s%s'):format(prefix, math.random(10000000, 99999999))
    until not serialExists(serialNumber)

    return serialNumber
end
