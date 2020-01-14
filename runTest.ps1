[CmdletBinding()]
param (
  ##[Parameter(Mandatory = $true)]
  [string]$grmVersion = "0.11.0-PullRequest0196-0155",
  [ValidateNotNullOrEmpty()]
  [string]$githubToken = $env:GITHUB_TOKEN
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

$grm = Resolve-path "tools/**/dotnet-gitreleasemanager*" -ea 0 | % Path
if (!$grm) {
  $grm = Get-Command "dotnet-gitreleasemanager" -ea 0 | % Path
}

if (!$grm) {
  $grm = Get-Command "GitReleaseManager" -ea 0 | % Path
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

$releases | % {
  Invoke-RestMethod -Headers $githubHeaders -Method Delete -Uri $_.url -UseBasicParsing
}

"Removing existing comments..."

$comments = Invoke-RestMethod -Headers $githubHeaders -Method Get -Uri "https://api.github.com/repos/AdmiringWorm/FakeTestRepository/issues/comments" -UseBasicParsing

$comments | % {
  $matchContent = [regex]::Escape("<!-- GitReleaseManager release comment -->")
  $notMatchContent = [regex]::Escape("<!-- Should not be removed -->")
  if (($_.Body -match $matchContent) -and ($_.Body -notmatch $notMatchContent)) {
    Invoke-RestMethod -Headers $githubHeaders -Method Delete -Uri $_.url -UseBasicParsing
  }
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

$prId = $grmVersion -replace ".*PullRequest0?(\d+)\-.*","`${1}"

if ($prId -and $env:APPVEYOR) {
  $successMarkdown = "✔️"
  $failureMarkdown = "❌"
  $buildUrl = "$env:APPVEYOR_URL/project/$env:APPVEYOR_PROJECT_SLUG/builds/$env:APPVEYOR_BUILD_ID/job/$env:APPVEYOR_JOB_ID"

  $statusMarkdown = @"
- [$(if ($status.All) { "$successMarkdown" } else { "$failureMarkdown" }) Image $env:APPVEYOR_BUILD_WORKER_IMAGE]($buildUrl)
  - $(if ($status.Open) { "$successMarkdown" } else { "$failureMarkdown" } ) Open Milestone
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Creating Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Discarding Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Uploading Assets
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Publishing Release
  - $(if ($status.Create) { "$successMarkdown" } else { "$failureMarkdown" } ) Closing Milestone
"@


  "$statusMarkdown"

  $markdown = $null
  #$prComments = Invoke-RestMethod -Headers $githubHeaders -Method Get -Uri "https://api.github.com/repos/GitTools/GitReleaseManager/issues/${prId}/comments"
  #$details = $prComments | ? Body -Match "<!-- INTEGRATION TEST STATUS -->" | select -First 1
  $details = $null

  if (!$details) {
    $markdown = "<!-- INTEGRATION TEST STATUS -->`nIntegration tests have been run for this Pull Request.`nThe status for these are shown below`n"
  } else {
    $markdown = $details | % { $_.Body -replace "- \[($successMarkdown|$failureMarkdown)\s*Image $env:APPVEYOR_BUILD_WORKER_IMAGE.*[\r\n]*(- \[Image |$)","`${1}" }
  }

  $markdown = "${markdown}`n${statusMarkdown}"
}
