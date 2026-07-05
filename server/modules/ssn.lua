if GetResourceState('vms_cityhall') ~= 'missing' then
    return
end

local dateOfBirthFormat = 'DD.MM.YYYY' -- DD.MM.YYYY / MM.DD.YYYY / YYYY.MM.DD / YYYY.DD.MM
local ssnFormat = 'YYMMDDRRRRG'

local function fetchScalarSync(query, params)
    local waiting = true
    local value = nil

    MySQL.Async.fetchScalar(query, params or {}, function(result)
        value = result
        waiting = false
    end)

    local timeoutAt = GetGameTimer() + 10000

    while waiting do
        if GetGameTimer() > timeoutAt then
            print(('^8[MODULE:SSN_GENERATE]^7 Database timeout: %s'):format(query))
            break
        end

        Citizen.Wait(50)
    end

    return value
end

local function executeSync(query, params)
    local waiting = true
    local affectedRows = 0

    MySQL.Async.execute(query, params or {}, function(result)
        affectedRows = result or 0
        waiting = false
    end)

    local timeoutAt = GetGameTimer() + 10000

    while waiting do
        if GetGameTimer() > timeoutAt then
            print(('^8[MODULE:SSN_GENERATE]^7 Database timeout: %s'):format(query))
            break
        end

        Citizen.Wait(50)
    end

    return affectedRows
end

local function parseDate(date)
    if type(date) ~= 'string' then
        return nil, nil, nil
    end

    local part1, part2, part3 = date:match('(%d+)%p(%d+)%p(%d+)')

    if not part1 or not part2 or not part3 then
        return nil, nil, nil
    end

    if dateOfBirthFormat == 'DD.MM.YYYY' then
        return part1, part2, part3
    elseif dateOfBirthFormat == 'MM.DD.YYYY' then
        return part2, part1, part3
    elseif dateOfBirthFormat == 'YYYY.MM.DD' then
        return part3, part2, part1
    elseif dateOfBirthFormat == 'YYYY.DD.MM' then
        return part2, part3, part1
    end

    error('Unknown format for date of birth: ' .. tostring(dateOfBirthFormat))
end

local function pad2(value)
    value = tonumber(value) or 0
    return ('%02d'):format(value)
end

local function genderDigit(gender)
    if gender == 'male' or gender == 'm' or gender == 0 or gender == '0' then
        return '0'
    end

    return '1'
end

local function buildCandidate(dateOfBirth, gender)
    local day, month, year = parseDate(dateOfBirth)

    if not day or not month or not year then
        return nil
    end

    local candidate = ssnFormat
    candidate = candidate:gsub('YYYY', tostring(year))
    candidate = candidate:gsub('YY', tostring(year):sub(-2))
    candidate = candidate:gsub('MM', pad2(month))
    candidate = candidate:gsub('DD', pad2(day))
    candidate = candidate:gsub('G', genderDigit(gender))
    candidate = candidate:gsub('R', function()
        return tostring(math.random(0, 9))
    end)

    return candidate
end

local function ensureUsersSsnColumn()
    executeSync('ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `ssn` VARCHAR(32) DEFAULT NULL')
end

local function GenerateSSN(dateOfBirth, gender)
    ensureUsersSsnColumn()

    for _ = 1, 25 do
        local candidate = buildCandidate(dateOfBirth, gender)

        if candidate and not fetchScalarSync('SELECT 1 FROM `users` WHERE `ssn` = @ssn LIMIT 1', {['@ssn'] = candidate}) then
            return candidate
        end
    end

    return tostring(math.random(10000000000, 99999999999))
end
exports('GenerateSSN', GenerateSSN)

RegisterCommand('_generatessn', function(src)
    if src ~= 0 then
        return
    end

    ensureUsersSsnColumn()
    print('^3[MODULE:SSN_GENERATE]^8 Do not restart server!^7')
    Citizen.Wait(200)

    MySQL.Async.fetchAll('SELECT identifier, dateofbirth, sex, ssn FROM `users`', {}, function(result)
        if not result or not result[1] then
            print('^3[MODULE:SSN_GENERATE]^7 No users found!')
            return
        end

        local remaining = #result

        for _, player in pairs(result) do
            remaining = remaining - 1

            if not player.ssn or player.ssn == '' then
                local playerSSN = GenerateSSN(player.dateofbirth, player.sex)

                MySQL.Async.execute(
                    'UPDATE `users` SET `ssn` = @ssn WHERE `identifier` = @identifier',
                    {
                        ['@ssn'] = playerSSN,
                        ['@identifier'] = player.identifier,
                    },
                    function(rowsChanged)
                        if rowsChanged and rowsChanged > 0 then
                            print(('^2[SUCCESS]^7 Generated SSN ^4%s^7 for ^5%s^7 (Remaining: %s)^7'):format(playerSSN, player.identifier, remaining))
                        else
                            print(('^8[ERROR]^7 Not generated SSN ^4%s^7 for ^5%s^7 (Remaining: %s)^7'):format(playerSSN, player.identifier, remaining))
                        end
                    end
                )

                Citizen.Wait(300)
            end
        end

        print('^3[MODULE:SSN_GENERATE]^7 Correctly generated SSN for each user!')
    end)
end, true)
