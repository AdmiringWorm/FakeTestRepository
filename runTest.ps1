[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$githubToken = $env:GITHUB_TOKEN
)
$ErrorActionPreference = 'Stop'

$status = @{
  Open = $false
  Create = $false
  Discard = $false
  upload = $false
  publish = $false
  close = $false
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
  exit $LASTEXITCODE
}

"Creating a new release..."
. "$grm" create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Discarding the release"
. "$grm" discard --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Creating the new release again"
. "$grm" create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Uploading new assets"
. "$grm" addasset --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --assets "LICENSE,README.md,runTest.ps1" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Publishing created release"
. "$grm" publish --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Closing milestone"
. "$grm" close --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
