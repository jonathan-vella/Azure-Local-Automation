# Test the 'Update Run History and Error Details' ARG/KQL query
# against the live fleet using az cli, to verify the data shape and the
# columns we want to surface in the v0.7.70 Step.6 pipeline JUnit output.
$ErrorActionPreference = 'Stop'

# ARG/KQL query for fleet-scale update-run failure details (removes workbook-specific
# parameter binding {ResourceGroupFilter}, {ClusterTagName}, {ClusterTagValue},
# {UpdateHistoryClusterFilter}, {UpdateHistoryUpdateNameFilter},
# {UpdateHistoryStateFilter}, {UpdateHistoryStatusFilter},
# {UpdateHistoryTimeRange}). Keeps the 7-level mv-expand + 8th-level synthetic
# step + raised-an-exception regex fallback + Failed-only dedup + portal
# deep-link construction.
$kql = @'
extensibilityresources
| where type == 'microsoft.azurestackhci/clusters/updates/updateruns'
| extend hciClusterName = tostring(split(id, '/')[8])
| extend updateName = tostring(split(id, '/')[10])
| extend runName = name
| extend state = tostring(properties.state)
| extend timeStarted = todatetime(properties.timeStarted)
| extend lastUpdatedTime = todatetime(properties.lastUpdatedTime)
| extend duration = tostring(properties.duration)
| extend durationHours = iff(duration contains 'H', toint(extract('([0-9]+)H', 1, duration)), 0)
| extend durationMinutes = iff(duration contains 'M', toint(extract('([0-9]+)M', 1, duration)), 0)
| extend durationSeconds = iff(duration contains 'S', toint(extract('([0-9]+)', 1, extract('([0-9.]+)S', 1, duration))), 0)
| extend durationFormatted = strcat(iff(durationHours > 0, strcat(tostring(durationHours), 'h '), ''), iff(durationMinutes > 0 or durationHours > 0, strcat(tostring(durationMinutes), 'm '), ''), tostring(durationSeconds), 's')
| extend progressObj = properties.progress
| extend progressJson = tostring(properties.progress)
| extend progressStatus = tostring(progressObj.status)
| extend progressDescription = tostring(progressObj.description)
| mv-expand s1 = progressObj.steps
| mv-expand s2 = s1.steps
| mv-expand s3 = s2.steps
| mv-expand s4 = s3.steps
| mv-expand s5 = s4.steps
| mv-expand s6 = iff(array_length(s5.steps) > 0, s5.steps, dynamic([null]))
| mv-expand s7 = iff(isnotnull(s6) and array_length(s6.steps) > 0, s6.steps, dynamic([null]))
| extend e5Msg = tostring(s5.errorMessage), e5Name = tostring(s5.name), e5Status = tostring(s5.status)
| extend e4Msg = tostring(s4.errorMessage), e4Name = tostring(s4.name), e4Status = tostring(s4.status)
| extend e3Msg = tostring(s3.errorMessage), e3Name = tostring(s3.name), e3Status = tostring(s3.status)
| extend e2Msg = tostring(s2.errorMessage), e2Name = tostring(s2.name), e2Status = tostring(s2.status)
| extend e1Msg = tostring(s1.errorMessage), e1Name = tostring(s1.name), e1Status = tostring(s1.status), e1Desc = tostring(s1.description)
| extend e6Msg = iff(isnotnull(s6), tostring(s6.errorMessage), ''), e6Name = iff(isnotnull(s6), tostring(s6.name), ''), e6Status = iff(isnotnull(s6), tostring(s6.status), '')
| extend e7Msg = iff(isnotnull(s7), tostring(s7.errorMessage), ''), e7Name = iff(isnotnull(s7), tostring(s7.name), ''), e7Status = iff(isnotnull(s7), tostring(s7.status), '')
| extend e8Arr = iff(isnotnull(s7), s7.steps, dynamic(null))
| extend e8First = iff(isnotnull(e8Arr) and array_length(e8Arr) > 0, e8Arr[0], dynamic(null))
| extend e8Msg = tostring(e8First.errorMessage), e8Name = tostring(e8First.name), e8Status = tostring(e8First.status)
| extend mvExpandErrMsg = coalesce(iff(strlen(e8Msg) > 0, e8Msg, ''), iff(strlen(e7Msg) > 0, e7Msg, ''), iff(strlen(e6Msg) > 0, e6Msg, ''), iff(strlen(e5Msg) > 0, e5Msg, ''), iff(strlen(e4Msg) > 0, e4Msg, ''), iff(strlen(e3Msg) > 0, e3Msg, ''), iff(strlen(e2Msg) > 0, e2Msg, ''), iff(strlen(e1Msg) > 0, iff(strlen(e1Desc) > strlen(e1Msg), strcat(e1Msg, ' | ', e1Desc), e1Msg), ''))
| extend deepExceptionMsg = extract(@'raised an exception:[\s\S]{0,1500}', 0, progressJson)
| extend deepestErrMsg = iff(strlen(mvExpandErrMsg) > 10, mvExpandErrMsg, deepExceptionMsg)
| extend errorBasedStep = case(deepestErrMsg has 'UpdateSecuredCore', 'Update Secured-core', deepestErrMsg has 'CAU' or deepestErrMsg has 'Cluster-Aware', 'CAU Update', deepestErrMsg has 'RotateSecrets' or deepestErrMsg has 'Rotate Secrets', 'Rotate Secrets', deepestErrMsg has 'MocArb' or deepestErrMsg has 'CliExtensions', 'Update Arc Prerequisites', deepestErrMsg has 'certificate rotation', 'Certificate Rotation', '')
| extend deepestErrDepth = case(strlen(e8Msg) > 0, 8, strlen(e7Msg) > 0, 7, strlen(e6Msg) > 0, 6, strlen(e5Msg) > 0, 5, strlen(e4Msg) > 0, 4, strlen(e3Msg) > 0, 3, strlen(e2Msg) > 0, 2, strlen(e1Msg) > 0, 1, e8Status == 'Error', 8, e7Status == 'Error', 7, e6Status == 'Error', 6, e5Status == 'Error', 5, e4Status == 'Error', 4, e3Status == 'Error', 3, e2Status == 'Error', 2, e1Status == 'Error', 1, e8Status == 'Failed', 8, e7Status == 'Failed', 7, e6Status == 'Failed', 6, e5Status == 'Failed', 5, e4Status == 'Failed', 4, e3Status == 'Failed', 3, e2Status == 'Failed', 2, e1Status == 'Failed', 1, strlen(errorBasedStep) > 0, 1, 0)
| extend deepestErrStep = case(deepestErrDepth == 8, e8Name, deepestErrDepth == 7, e7Name, deepestErrDepth == 6, e6Name, deepestErrDepth == 5, e5Name, deepestErrDepth == 4, e4Name, deepestErrDepth == 3, e3Name, deepestErrDepth == 2, e2Name, deepestErrDepth == 1, iff(isnotempty(errorBasedStep), errorBasedStep, e1Name), '')
| summarize arg_max(deepestErrDepth, deepestErrStep), ErrorStepMessage = max(deepestErrMsg), state = max(state), timeStarted = max(timeStarted), lastUpdatedTime = max(lastUpdatedTime), durationFormatted = max(durationFormatted), progressStatus = max(progressStatus), progressDescription = max(progressDescription), subscriptionId = max(subscriptionId), resourceGroup = max(resourceGroup) by hciClusterName, updateName, id
| extend CurrentStep = iff(state == 'Failed', iff(isnotempty(deepestErrStep), deepestErrStep, progressDescription), '')
| extend ErrorMessageClean = replace_string(replace_string(ErrorStepMessage, '\r\n', ' '), '\n', ' ')
| extend ErrorMessageDisplay = iff(strlen(ErrorMessageClean) > 0, ErrorMessageClean, iff(state == 'Failed' and progressStatus == 'Error', 'No Error Details available - click Update Name link to view in Azure portal', ''))
| extend clusterResourceId = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup, '/providers/microsoft.azurestackhci/clusters/', hciClusterName)
| extend encodedResourceId = replace_string(replace_string(clusterResourceId, '/', '%2F'), ' ', '%20')
| extend PortalLink = strcat('https://portal.azure.com/#view/Microsoft_AzureStackHCI_PortalExtension/SingleInstanceHistoryDetails.ReactView/resourceId/', encodedResourceId, '/updateName~/null/updateRunName~/null/refresh~/false')
| join kind=leftouter (
    extensibilityresources
    | where type == 'microsoft.azurestackhci/clusters/updates/updateruns'
    | extend _rState = tostring(properties.state)
    | where _rState == 'Succeeded'
    | extend _rCluster = tostring(split(id, '/')[8])
    | extend _rStarted = todatetime(properties.timeStarted)
    | summarize _latestSucceeded = max(_rStarted) by _rCluster
) on $left.hciClusterName == $right._rCluster
| where not(state == 'Failed' and isnotnull(_latestSucceeded) and timeStarted < _latestSucceeded)
| extend _dedup = iff(state == 'Failed', hciClusterName, id)
| summarize arg_max(timeStarted, *) by _dedup
| project-away _dedup
| where state == 'Failed'
| project ClusterName = hciClusterName, UpdateName = updateName, PortalLink, State = state, Status = progressStatus, CurrentStep, ErrorMessage = ErrorMessageDisplay, Duration = durationFormatted, TimeStarted = timeStarted, LastUpdated = lastUpdatedTime
| order by TimeStarted desc
'@

Write-Host "Running ARG query against subscription fbaf508b-cb61-4383-9cda-a42bfa0c7bc9..." -ForegroundColor Cyan
$json = az graph query -q $kql --subscriptions 'fbaf508b-cb61-4383-9cda-a42bfa0c7bc9' --first 100 -o json
if ($LASTEXITCODE -ne 0) { throw 'ARG query failed' }
$result = $json | ConvertFrom-Json
Write-Host "Total rows: $($result.total_records); returned: $($result.count); skip_token: $($result.skip_token)"
Write-Host ""
$result.data | Format-Table ClusterName, UpdateName, State, Status, CurrentStep, Duration, TimeStarted -AutoSize -Wrap | Out-String -Width 200 | Write-Host
Write-Host ""
Write-Host "First row full property dump:" -ForegroundColor Cyan
$result.data[0] | Format-List | Out-String -Width 200 | Write-Host
Write-Host ""
Write-Host "Verbose Error Details on first row (truncated to 400 chars):" -ForegroundColor Cyan
$msg = $result.data[0].ErrorMessage
if ($msg.Length -gt 400) { Write-Host ($msg.Substring(0,400) + ' ... (truncated)') } else { Write-Host $msg }
Write-Host ""
Write-Host "PortalLink on first row:" -ForegroundColor Cyan
Write-Host $result.data[0].PortalLink
