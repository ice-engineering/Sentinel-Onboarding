param(
    [Parameter(Mandatory=$true)][string]$ResourceGroup,
    [Parameter(Mandatory=$true)][string]$Workspace,
    [Parameter(Mandatory=$true)][string]$Location,
    [Parameter(Mandatory=$true)][string[]]$CustomWorkbooksList,
    [Parameter(Mandatory=$true)][string]$ArtifactsLocation
)

$context = Get-AzContext

if(!$context){
    Connect-AzAccount
    $context = Get-AzContext
}

$SubscriptionId = $context.Subscription.Id

Write-Host "Connected to Azure with subscription: " + $context.Subscription

$workbookUri = "/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroup}/providers/Microsoft.Insights/workbooks/"

if ($CustomWorkbooksList){
    foreach ($workbook in $CustomWorkbooksList){

        $workbookName = $workbook.replace(' ','')

        $serializedData = (Invoke-webrequest -URI "${ArtifactsLocation}/Workbooks/${workbookName}.json").Content

        $guid = New-Guid

        $sourceId = "/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroup}/providers/Microsoft.OperationalInsights/workspaces/${Workspace}"

        $properties = @{
            displayName = $workbook
            serializedData = $serializedData
            version = "1.0"
            sourceId = $sourceId
            category = "sentinel"
        }

        $workbookUriGuid = $workbookUri + $guid + '?api-version=2021-08-01'

        $workbookBody = @{}
        $workbookBody | Add-Member -NotePropertyName name -NotePropertyValue $guid
        $workbookBody | Add-Member -NotePropertyName type -NotePropertyValue "microsoft.insights/workbooks"
        $workbookBody | Add-Member -NotePropertyName location -NotePropertyValue $Location
        $workbookBody | Add-Member -NotePropertyName kind -NotePropertyValue "shared"
        $workbookBody | Add-Member -NotePropertyName properties -NotePropertyValue $properties

        try{
            Invoke-AzRestMethod -Path $workbookUriGuid -Method PUT -Payload ($workbookBody | ConvertTo-Json -Depth 3)
        }
        catch {
            Write-Verbose $_
            Write-Error "Unable to create workbook with error code: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}