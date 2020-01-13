[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$githubToken = $env:GITHUB_TOKEN
)
$ErrorActionPreference = 'Stop'

"Opening the closed milestone"
dotnet gitreleasemanager open --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Creating a new release..."
dotnet gitreleasemanager create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Discarding the release"
dotnet gitreleasemanager discard --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Creating the new release again"
dotnet gitreleasemanager create --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Uploading new assets"
dotnet gitreleasemanager addasset --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --assets "LICENSE,README.md,runTest.ps1" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Publishing created release"
dotnet gitreleasemanager publish --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --tagName "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

"Closing milestone"
dotnet gitreleasemanager close --token $githubToken --owner "AdmiringWorm" --repository "FakeTestRepository" --milestone "1.0.0" --verbose --debug
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}


Write-Warning "Remember to remove the created release, any any comments created before running this script again"
