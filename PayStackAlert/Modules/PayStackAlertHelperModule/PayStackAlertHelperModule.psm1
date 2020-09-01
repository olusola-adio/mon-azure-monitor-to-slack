<#
.SYNOPSIS
Helper functions for the MonitorAlert Azure Function

.DESCRIPTION
A module full of helper functions for the MonitorAlert Azure Function

#>


function EncodeSlackHtmlEntities {
<#
.SYNOPSIS

Encodes HTML entities

.DESCRIPTION

Encodes the HTML entities according to slack guidelines (https://api.slack.com/docs/message-formatting)

.Parameter ToEncode

The string to encode

.OUTPUTS

System.String. The encoded string

#>      
    param(
        [Parameter(Mandatory = $true)]
        [string] $ToEncode
    )
  
    
    $encoded = $ToEncode.Replace("&", "&amp;"). `
        Replace("<", "&lt;"). `
        Replace(">", "&gt;")

    return $encoded
}

function New-SlackMessageFromAlert
{
<#
.SYNOPSIS

Creates a slack message object from alert data

.DESCRIPTION

Creates an object representing a slack message from given azure monitor alert message data.

.Parameter channel

The slack channel to pipe the alert into

.Parameter alert

An object representing the alert 

.OUTPUTS

hashtable. The slack message
#>

    param(
        [Parameter(Mandatory=$true)]
        [string] $Channel,
        [Parameter(Mandatory=$true)]
        [hashtable] $Alert
    )
    

    $alertAttachmentColours = @{
        "charge.success" = "#00a86b"
        "subscription.create" = "#00a86b"
        "transfer.success" = "#00a86b"
        "transfer.reversed" = "#00a86b"
        "invoice.create" = "#00a86b"
        "invoice.update" = "#00a86b"
        "paymentrequest.success" ="#00a86b"
        "paymentrequest.pending" = "#ff7e00"
        "transfer.failed" = "#ff0000"
        "invoice.payment_failed" = "#ff0000"
    }

    $encodedEvent = EncodeSlackHtmlEntities -ToEncode $Alert.event
    $AlertJsonData = $Alert.Data | ConvertTo-Json  -Depth 4
    
    $slackMessage = @{ 
        channel = "#$($Channel)"
        attachments = @(
            @{
                color=  $alertAttachmentColours[$encodedEvent]
                title = "$($encodedEvent) for $($Alert.Data.amount / 100)Naira from $($Alert.Data.customer.first_name) $($Alert.Data.customer.last_name)"
                text = "$($AlertJsonData)"
            }
        ) 
    }

    return $slackMessage
}


function Test-SlackMessage
{
<#
.SYNOPSIS

Tests whether a slack message should be sent

.DESCRIPTION

Creates an object representing a slack message from given azure monitor alert message data.

.Parameter alert

An object representing the alert 

.OUTPUTS

boolean. 
#>

    param(
        [Parameter(Mandatory=$true)]
        [hashtable] $Alert
    )
    



    $tableName = "paystackmessages"
    $appSharedStorageAccountName = "mondevappsharedstr"
    $appSharedResourceGroupName = "mon-dev-app-sharedresources-rg"
    $subscriptionName ="cb5ab4a7-dd08-4be3-9d7e-9f68ae30f224"

    # Install-Module -Name AzTable -Force
    # Import-Module AzTable
    # Log on to Azure and set the active subscription
    Connect-AzAccount -Identity
    Select-AzSubscription -SubscriptionId $subscriptionName

    # Get the storage key for the storage account
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $appSharedResourceGroupName -Name $appSharedStorageAccountName).Value[0]

    # Get a storage context
    $ctx = New-AzStorageContext -StorageAccountName $appSharedStorageAccountName -StorageAccountKey $storageAccountKey

    $cloudTable = (Get-AzStorageTable –Name $tableName –Context $ctx).CloudTable

    $result = Get-AzTableRow -table $cloudTable -rowKey "$($Alert.Data.id)" -partitionKey "$($Alert.event)" 

    if ($null -eq $result) {

        Write-Information "Adding new record"
        Add-AzTableRow -table $cloudTable -partitionKey $($Alert.event) -rowKey $($Alert.Data.id) -property @{"payStackId"=$($Alert.Data.id)} 

        Write-Information "return true"
        return $true
    }
    

    Write-Information "return false"
    return $false
}

function Test-SlackMessage2
{
<#
.SYNOPSIS

Tests whether a slack message should be sent

.DESCRIPTION

Creates an object representing a slack message from given azure monitor alert message data.

.Parameter alert

An object representing the alert 

.OUTPUTS

boolean. 
#>

    param(
        [Parameter(Mandatory=$true)]
        [hashtable] $Alert
    )
    



    $storageAccountName = "mondevappsharedstr"
    $storageAccountkey = "jt3lAdSS9ij0OQzFv+LBS5NwM82wHPF94I6/bMaFWgRJUTxGw+l6ek7Wqss9Y1A8Vx3G2QFHR6g0vDV6vM2/ug=="
    $tableName = "paystackmessages"
    $apiVersion = "2017-04-17"
    $tableURL = "https://$($storageAccountName).table.core.windows.net/$($tableName)"
    $GMTime = (Get-Date).ToUniversalTime().toString('R')
    $string = "$($GMTime)`n/$($storageAccountName)/$($tableName)"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($storageAccountkey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($string))
    $signature = [Convert]::ToBase64String($signature)
    $headers = @{    
        Authorization  = "SharedKeyLite " + $storageAccountName + ":" + $signature
        Accept         = "application/json;odata=fullmetadata"
        'x-ms-date'    = $GMTime
        "x-ms-version" = $apiVersion
    }
    
    $queryURL = "$($tableURL)?`$filter=(payStackId eq '$($Alert.Data.Id)')"
    Write-Information " query $($queryURL)"
    $NICitem = Invoke-RestMethod -Method GET -Uri $queryURL -Headers $headers -ContentType application/json
    $NICitem.value

    $bob = $NICitem.value | ConvertTo-Json  -Depth 4

    Write-Information " result $($NICitem)"

    Write-Information " result value $($NICitem.value)"

    Write-Information "result json $($bob)"

    if ($null -eq $NICitem.value) {

        # Write-Information "Adding new record"
        # Add-AzTableRow -table $cloudTable -partitionKey $($Alert.event) -rowKey $($Alert.Data.id) -property @{"payStackId"=$($Alert.Data.id)} 

        Write-Information "return true"
        return $true
    }
    

    Write-Information "return false"
    return $false
}

function Push-OutputBindingWrapper 
{
<#
.SYNOPSIS

A wrapper for pushing an HTTP Status and Body text to the azure functions output binding

.DESCRIPTION

A wrapper for pushing an HTTP Status and Body text to the azure functions output binding

.Parameter Status

HttpStatusCode. A member of the HttpStatusCode enumberation to send as the result of the current operation 

.Parameter Body

String.  The text to return to the client.

#>

    param(
        [Parameter(Mandatory=$true)]
        [HttpStatusCode] $Status,
        [Parameter(Mandatory=$true)]
        [string] $Body
    )


    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = $Status
        Body = $Body
    })
}

function Send-MessageToSlack 
{
<#
.SYNOPSIS

Sends a message to Slack

.DESCRIPTION

Sends an hashtable to slack using the given token.

.Parameter slackToken

String. The slack token to use to communicate with slack.

.Parameter $message

hashtable.  A hashtable representing the message to send to slack.
#>

    param(
        [Parameter(Mandatory = $true)]
        [string] $SlackToken,
        [Parameter(Mandatory=$true)]
        [hashtable] $Message
    )

    $serializedMessage = "payload=$($Message | ConvertTo-Json)"

    Invoke-RestMethod -Uri https://hooks.slack.com/services/$($SlackToken) -Method POST -UseBasicParsing -Body $serializedMessage
}
