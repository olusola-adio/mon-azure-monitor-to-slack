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
