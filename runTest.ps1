[CmdletBinding(DefaultParameterSetName = 'Path')]
param (
  [Parameter(Mandatory = $true, ParameterSetName = 'Versioning')]
  [string]$grmVersion,
  [Parameter(Mandatory = $false, ParameterSetName = 'Path')]
  [string]$grmPath,
  [ValidateNotNullOrEmpty()]
  [string]$githubToken = $env:GITHUB_TOKEN,
  [switch]$reset
)
$ErrorActionPreference = 'Stop'

$status = @{
  All     = $true
  Open    = $false
  Create  = $false
  Discard = $false
  Upload  = $false
  Publish = $false
  Close   = $false
}

if ($grmPath) {
  $grm = $grmPath
}
else {
  $grm = Resolve-path "tools/dotnet-gitreleasemanager*" -ea 0 | ForEach-Object Path
  if (!$grm) {
    $grm = Get-Command "dotnet-gitreleasemanager" -ea 0 | ForEach-Object Path
  }

  if (!$grm) {
    $grm = Get-Command "GitReleaseManager" -ea 0 | ForEach-Object Path
  }
}

if (!$grm) {
  throw "GitReleaseManager executable was not found"
}

"Using GitReleaseManager from '$grm'"
. $grm --version

$githubHeaders = @{
  Authorization = "token $githubToken"
}

"Deleting existing releases..."
$releases = Invoke-RestMethod -Headers $githubHeaders -Method Get -Uri "https://api.github.com/repos/AdmiringWorm/FakeTestRepository/releases" -UseBasicParsing

$releases | Where-Object { $_.tagName -ne '0.1.0' } | ForEach-Object {
  Invoke-RestMethod -Headers $githubHeaders -Method Delete -Uri $_.url -UseBasicParsing
}

"Removing existing comments..."

$comments = Invoke-RestMethod -Headers $githubHeaders -Method Get -Uri "https://api.github.com/repos/AdmiringWorm/FakeTestRepository/issues/comments" -UseBasicParsing

$comments | ForEach-Object {
  $matchContent = [regex]::Escape("<!-- GitReleaseManager release comment -->")
  $notMatchContent = [regex]::Escape("<!-- Should not be removed -->")
  if (($_.Body -match $matchContent) -and ($_.Body -notmatch $notMatchContent)) {
    Invoke-RestMethod -Headers $githubHeaders -Method Delete -Uri $_.url -UseBasicParsing
  }
}

if ($reset) {
  return;
}

"Opening the closed milestone"
. "$grm" open --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.open = $true
}

"Creating a new release..."
. "$grm" create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.Create = $true
}

"Discarding the release"
. "$grm" discard --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.Discard = $true
}

"Creating the new release again"
. "$grm" create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0"
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}

"Uploading new assets"
. "$grm" addasset --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --assets "LICENSE,README.md,runTest.ps1" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.Upload = $true
}

"Publishing created release"
. "$grm" publish --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.Publish = $true
}

"Closing milestone"
. "$grm" close --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  $status.All = $false
}
else {
  $status.Close = $true
}

$prId = $grmVersion -replace ".*PullRequest0?(\d+)\-.*", "`${1}"

if ($prId -and $env:APPVEYOR) {
  $successMarkdown = ":heavy_check_mark:"
  $failureMarkdown = ":x:"
  $buildUrl = "$env:APPVEYOR_URL/project/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/builds/$env:APPVEYOR_BUILD_ID/job/$env:APPVEYOR_JOB_ID"

  $statusMarkdown = @"
- [$(if ($status.All) { "$successMarkdown" } else { "$failureMarkdown" }) Image $env:APPVEYOR_BUILD_WORKER_IMAGE (Updated $([System.DateTime]::UtcNow.ToString('s')))]($buildUrl)
  - $(if ($status.Open) { "$successMarkdown" } else { "$failureMarkdown" } ) Open Milestone
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Creating Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Discarding Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Uploading Assets
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Publishing Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Closing Milestone
"@


  "$statusMarkdown" -replace $successMarkdown, "[TRUE]" -replace $failureMarkdown, "[FALSE]"

  $prComments = Invoke-RestMethod -Headers $githubHeaders -Method Get -Uri "https://api.github.com/repos/GitTools/GitReleaseManager/issues/${prId}/comments"
  $details = $prComments | Where-Object Body -Match "<!-- INTEGRATION TEST STATUS -->" | Select-Object -First 1

  if (!$details) {
    $markdown = "<!-- INTEGRATION TEST STATUS -->`nIntegration tests have been run for this Pull Request.`nThe status for these are shown below`n`n"
  }
  else {
    $re = "- \[(?:$successMarkdown|$failureMarkdown)\s*Image $env:APPVEYOR_BUILD_WORKER_IMAGE(?:[^\[]*|[\r\n]*)(\- \[:heavy_check_mark:|:x:|$)"
    $re
    $details.body = $details.body -replace "✔️", ":heavy_check_mark:" -replace "❌", ":x:"
    $markdown = $details | ForEach-Object { $_.Body -replace $re, "`${1}" }
  }

  $markdown = "${markdown}${statusMarkdown}`n"

  if ($details) {
    $url = $details.url
    $method = 'PATCH'
  }
  else {
    $url = "https://api.github.com/repos/GitTools/GitReleaseManager/issues/${prId}/comments"
    $method = 'POST'
  }

  $markdown

  $bodyContent = @{
    "body" = $markdown
  } | ConvertTo-Json

  Invoke-RestMethod -Headers $githubHeaders -Uri $url -Method $method -ContentType "application/json" -Body $bodyContent
}
