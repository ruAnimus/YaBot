# Реализация функции создания чата или канала (https://yandex.ru/dev/messenger/doc/ru/api-requests/chat-create#telo-zaprosa-json)
function New-YaBotChat {
    [CmdletBinding(DefaultParameterSetName = 'ModeChat')]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage="OAuthToken токен чатбота")]
        [string]$OAuthToken,

        [Parameter(Mandatory=$true,
        HelpMessage="Название чата (канала), Не более 200 символов")]
        [string]$Name,

        [Parameter(Mandatory=$true,
        HelpMessage="Описание чата (канала), не более 500 символов, допустима пустая строка")]
        [string]$Description,

        [Parameter(Mandatory=$false,
        HelpMessage="Иконка чата (канала), URL изображения")]
        [string]$AvatarUrl = "",

        [Parameter(Mandatory=$false,
        ValueFromPipeline=$false,
        ValueFromPipelineByPropertyName=$false,
        HelpMessage="Список администраторов чата (канала)")]
        [string[]]$Admins = @(),

        [Parameter(Mandatory=$false,
        ParameterSetName="ModeChat",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список участников чата")]
        [string[]]$Members = @(),

        [Parameter(Mandatory=$false,
        ParameterSetName="ModeChannel",
        ValueFromPipeline=$false,
        ValueFromPipelineByPropertyName=$false,
        HelpMessage="Флаг для создания канала вместо чата")]
        [switch]$Channel,

        [Parameter(Mandatory=$false,
        ParameterSetName="ModeChannel",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список участников канала")]
        [string[]]$Subscribers = @()
    )

    $Admins         = $Admins | Where-Object {$_}
    $Members        = $Members | Where-Object {$_}
    $Subscribers    = $Subscribers | Where-Object {$_}


    # Подготовка данных для запроса
    $requestData = @{
        name = $Name.Trim()
        description = $Description.trim()
    }
    if ($AvatarUrl) { $requestData.avatar_url = $AvatarUrl }

    if ($Admins) {
        $membersArray = @()
        foreach ($member in $Admins ) {
            $membersArray += @{ login = $member }
        }
        $requestData.admins = $membersArray
    }
    
    # Обработка передаваемого массива строк $Members и преобразование его в массив словарей
    if ($Members) {
        $membersArray = @()
        foreach ($member in $Members) {
            $membersArray += @{ login = $member }
        }
        $requestData.members = $membersArray
    }
    
    if ($Channel) { $requestData.channel = $true } else { $requestData.channel = $false }
    
    # Обработка передаваемого массива строк $Members и преобразование его в массив словарей
    if ($Subscribers) {
        $membersArray = @()
        foreach ($member in $Subscribers) {
            $membersArray += @{ login = $member }
        }
        $requestData.subscribers = $membersArray
    }
    $requestData = $requestData | ConvertTo-Json -Compress

    Write-Verbose $requestData

    # Выполнение HTTP-запроса
    $uri = "https://botapi.messenger.yandex.net/bot/v1/chats/create/"


    try {
        $response = Invoke-WebRequest -Uri $uri `
            -Method Post `
            -Body $requestData `
            -ContentType "application/json; charset=utf-8" `
            -Headers @{ 'Authorization' = "OAuth $OAuthToken" } `
            -UseBasicParsing `
            -TimeoutSec 120 `
            -ErrorAction Stop
        $responseData = $response.Content | ConvertFrom-Json -Depth 4
        return $responseData
    }
    catch {
        $err = $_
        
        if ($err.ErrorDetails.Message) {
            $errMessage = $err.ErrorDetails.Message | ConvertFrom-Json
            if ( $($errMessage.psobject.Properties.Name).Contains("ok") ) {
                # Обработка
                # {"ok": false, "description": "Bot is not a member of the chat"}
                # {
                #     "code": "permission_denied",
                #     "description": "Bot is not member of the chat",
                #     "ok": false
                # }
                # {"ok": false, "description": "Creating chat with user restricted by privacy settings"}
            }
        }
        

        Write-Error $err
        throw
    }
}

# Реализация функции создания чата или канала (https://yandex.ru/dev/messenger/doc/ru/api-requests/chat-members)
function Edit-YaBotChatMembers {
    [CmdletBinding(DefaultParameterSetName = 'ModeChat')]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage="OAuthToken токен чатбота")]
        [string]$OAuthToken,

        [Parameter(Mandatory=$true,
        HelpMessage="ID чата (канала)")]
        [string]$ChatId,

        [Parameter(Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список администраторов чата (канала)")]
        [string[]]$Admins = @(),

        [Parameter(Mandatory=$false,
        ParameterSetName="ModeChat",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список участников чата")]
        [string[]]$Members = @(),

        [Parameter(Mandatory=$false,
        ParameterSetName="ModeChannel",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список участников канала")]
        [string[]]$Subscribers = @(),

        [Parameter(Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Список участников для удаления из чата (канала)")]
        [string[]]$Remove = @()

    )

    # Чистим массивы от пустых элементов
    $Admins         = $Admins | Where-Object {$_}
    $Members        = $Members | Where-Object {$_}
    $Subscribers    = $Subscribers | Where-Object {$_}
    $Remove         = $Remove | Where-Object {$_}

    # Проверка наличия хотя бы одного из списков
    if (-not ($Members -or $Admins -or $Subscribers -or $Remove)) {
        Write-Error "Хотя бы один из списков (members, admins, subscribers, remove) должен быть задан."
        throw
    }

    # Подготовка данных для запроса
    $requestData = @{
        chat_id = $ChatId
    }

    if ($Members) {
        $membersArray = @()
        foreach ($member in $Members) {
            $membersArray += @{ login = $member }
        }
        $requestData.members = $membersArray
    }

    if ($Admins) {
        $adminsArray = @()
        foreach ($admin in $Admins) {
            $adminsArray += @{ login = $admin }
        }
        $requestData.admins = $adminsArray
    }

    if ($Subscribers) {
        $subscribersArray = @()
        foreach ($subscriber in $Subscribers) {
            $subscribersArray += @{ login = $subscriber }
        }
        $requestData.subscribers = $subscribersArray
    }

    if ($Remove) {
        $removeArray = @()
        foreach ($user in $Remove) {
            $removeArray += @{ login = $user }
        }
        $requestData.remove = $removeArray
    }

    $requestDataJson = $requestData | ConvertTo-Json
    Write-Verbose $requestDataJson

    # Выполнение HTTP-запроса
    $uri = "https://botapi.messenger.yandex.net/bot/v1/chats/updateMembers/"

    try {

        $response = Invoke-WebRequest -Uri $uri `
            -Method Post `
            -Body $requestDataJson `
            -ContentType "application/json; charset=utf-8" `
            -Headers @{ 'Authorization' = "OAuth $OAuthToken" } `
            -UseBasicParsing `
            -TimeoutSec 120 `
            -ErrorAction Stop
        $responseData = $response.Content | ConvertFrom-Json -Depth 4
        return $responseData
        
    }
    catch {
        $err = $_
        
        
        if ($err.ErrorDetails.Message) {
            $errMessage = $err.ErrorDetails.Message | ConvertFrom-Json
            if ( $($errMessage.psobject.Properties.Name).Contains("ok") ) {
                # обработка
                # {
                #     "code": "permission_denied",
                #     "description": "Bot is not member of the chat",
                #     "ok": false
                # }
                # {"ok": false, "description": "Creating chat with user restricted by privacy settings"}
            }
        }
        
        
        Write-Error $( $_ )
        throw
    }
}

# Реализация функции удаления сообщения (https://yandex.ru/dev/messenger/doc/ru/api-requests/message-delete)
<# .SYNOPSIS
Удаляет сообщение из чата в Яндекс.Мессенджере.

.DESCRIPTION
Функция Remove-YaBotMessage отправляет запрос к API Яндекс.Мессенджера для удаления конкретного сообщения в чате. Для этого требуется указать ID сообщения и, опционально, ID чата или логин пользователя. Также можно указать идентификатор треда, если сообщение принадлежит к определенному треду в чате.

.PARAMETER OAuthToken
OAuth токен чатбота, необходимый для аутентификации запроса в API.

.PARAMETER ChatId
Идентификатор чата, из которого нужно удалить сообщение. Не обязателен, если указан логин пользователя.

.PARAMETER Login
Логин пользователя, чье сообщение нужно удалить. Не обязателен, если указан ID чата.

.PARAMETER MessageId
Идентификатор сообщения, которое нужно удалить. Этот параметр обязателен.

.PARAMETER ThreadId
Идентификатор треда (временная метка сообщения), если сообщение принадлежит к определенному треду. Не обязателен.

.EXAMPLE
Remove-YaBotMessage -OAuthToken "ваш_токен" -ChatId "0/0/4f24b544-697c-4e18-a9c1-b39432ee9bf9" -MessageId 1695644763694005

Удаляет сообщение с ID 1695644763694005 из чата с ID 0/0/4f24b544-697c-4e18-a9c1-b39432ee9bf9, используя указанный OAuth токен.

.EXAMPLE
Remove-YaBotMessage -OAuthToken "ваш_токен" -Login "user_login" -MessageId 1695644763694005

Удаляет сообщение с ID 1695644763694005, отправленное пользователем с логином "user_login", используя указанный OAuth токен.

.NOTES
Более подробную информацию о работе с API Яндекс.Мессенджера можно найти в официальной документации.

.LINK
https://botapi.messenger.yandex.net/bot/v1/messages/delete/
 #>
function Remove-YaBotMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="OAuth токен чатбота")]
        [string]$OAuthToken,

        [Parameter(Mandatory=$false, HelpMessage="ID группового чата")]
        [string]$ChatId,

        [Parameter(Mandatory=$false, HelpMessage="Логин пользователя")]
        [string]$Login,

        [Parameter(Mandatory=$true, HelpMessage="ID сообщения, которое надо удалить")]
        [UInt64]$MessageId,

        [Parameter(Mandatory=$false, HelpMessage="Идентификатор треда (timestamp сообщения)")]
        [UInt64]$ThreadId
    )

    # Проверка, что задан хотя бы один из параметров: ChatId или Login
    if (-not $ChatId -and -not $Login) {
        Write-Error "Необходимо указать либо ChatId, либо Login."
        return $null
    }

    # Подготовка тела запроса
    $requestData = @{
        message_id = $MessageId
    }

    if ($ChatId) {
        $requestData.chat_id = $ChatId
    }

    if ($Login) {
        $requestData.login = $Login
    }

    if ($ThreadId) {
        $requestData.thread_id = $ThreadId
    }

    $requestDataJson = $requestData | ConvertTo-Json

    # URL для запроса
    $uri = "https://botapi.messenger.yandex.net/bot/v1/messages/delete/"

    try {
        # Выполнение HTTP-запроса
        $response = Invoke-WebRequest -Uri $uri `
            -Method Post `
            -Body $requestDataJson `
            -ContentType "application/json; charset=utf-8" `
            -Headers @{ Authorization = "OAuth $OAuthToken" } `
            -UseBasicParsing `
            -TimeoutSec 120 `
            -ErrorAction Stop

        $responseData = $response.Content | ConvertFrom-Json -ErrorAction Stop
        
        if ( -not $responseData.ok) {
            Write-Error "$($responseData.description)"
            throw
        }
    }
    catch {
        Write-Error "Invoke-WebRequest: $_"
        throw
    }
    return $responseData
}

<# .SYNOPSIS
Получает обновления сообщений для бота из Яндекс.Мессенджера.

.DESCRIPTION
Функция Get-YaBotMessages использует API Яндекс.Мессенджера для получения информации обо всех сообщениях, которые были доставлены боту с момента последнего обновления. Это позволяет боту реагировать на сообщения и команды от пользователей. Метод поддерживает как GET, так и POST HTTP-запросы для получения обновлений.

.PARAMETER OAuthToken
OAuth токен чатбота. Используется для аутентификации запроса в API. Этот параметр обязателен.

.PARAMETER Limit
Максимальное количество обновлений, которые должны быть возвращены в ответе. По умолчанию равно 100. Этот параметр не обязателен. Ограничение: не более 1000.

.PARAMETER Offset
Идентификатор первого обновления, которое должно быть получено. Используется для итерации через набор обновлений, чтобы избежать обработки уже полученных сообщений. По умолчанию равно 0. Этот параметр не обязателен.

.PARAMETER Method
HTTP метод, который будет использоваться для отправки запроса. Может быть "GET" или "POST". По умолчанию "GET". Этот параметр не обязателен.

.EXAMPLE
Get-YaBotMessages -OAuthToken "ваш_токен" -Limit 100 -Offset 0 -Method "GET"

Возвращает до 100 первых обновлений для бота, используя метод GET.

.EXAMPLE
Get-YaBotMessages -OAuthToken "ваш_токен" -Limit 50 -Offset 10 -Method "POST"

Возвращает до 50 обновлений, начиная с 11-го, для бота, используя метод POST.

.NOTES
Важно отметить, что использование метода getUpdates может привести к пропуску некоторых обновлений при высокой нагрузке на бота. Рассмотрите возможность использования вебхуков для получения обновлений в реальном времени.

.LINK
Официальная документация API Яндекс.Мессенджера: https://yandex.ru/dev/messenger/doc/ru/api-requests/update-polling
 #>
function Get-YaBotMessages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="OAuth токен чатбота для аутентификации запроса.")]
        [string]$OAuthToken,

        [Parameter(Mandatory=$false, HelpMessage="Максимальное количество обновлений в ответе. Не более 1000. По умолчанию: 100.")]
        [int]$Limit = 100,

        [Parameter(Mandatory=$false, HelpMessage="ID первого запрашиваемого обновления. По умолчанию: 0.")]
        [int]$Offset = 0,

        [Parameter(Mandatory=$false, HelpMessage="Выбор метода запроса: GET или POST. По умолчанию: GET.")]
        [ValidateSet("GET", "POST")]
        [string]$Method = "GET"
    )

    $uriBase = "https://botapi.messenger.yandex.net/bot/v1/messages/getUpdates/"
    $headers = @{
        Authorization = "OAuth $OAuthToken"
    }

    if ($Method -eq "GET") {
        $uri = "$($uriBase.trim("/"))?limit=$Limit&offset=$Offset"
        $headers = @{
            Authorization = "OAuth $OAuthToken"
        }
        try {
            $response = Invoke-WebRequest `
                -Uri $uri `
                -Method Get `
                -Headers $headers `
                -UseBasicParsing
            $result = $response.Content | ConvertFrom-Json
                        
            # return $result
        }
        catch {
            Write-Error "Ошибка при получении обновлений: $_"
            throw
        }
    }
    elseif ($Method -eq "POST") {
        $body = @{
            limit  = $Limit
            offset = $Offset
        } | ConvertTo-Json

        try {
            $response = Invoke-WebRequest -Uri $uriBase -Method Post -Headers $headers -Body $body -ContentType "application/json; charset=utf-8" -UseBasicParsing
            $result = $response.Content | ConvertFrom-Json
        }
        catch {
            Write-Error "Ошибка при получении обновлений: $_"
            throw
        }
    }
    
    if ($result.ok) {
        $result | ForEach-Object {
            $_.updates | ForEach-Object {
        
                $_.timestamp = Get-Date -UnixTimeSeconds $_.timestamp
                $_.message_id = [UInt64]$($_.message_id)
            }
        }
    }

    return $result
}

