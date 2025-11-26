# Bicep Deployment Script for Security Reports Infrastructure
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "prod", "test", "poc")]
  [string]$Environment,

  [Parameter(Mandatory = $false)]
  [string]$Location = "Australia East",

  [Parameter(Mandatory = $false)]
  [switch]$WhatIf,

  [Parameter(Mandatory = $false)]
  [switch]$AutoDetectIP
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting deployment for Security Reports Infrastructure" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

try {
  # Auto-detect current public IP if requested
  $currentIP = $null
  if ($AutoDetectIP) {
    Write-Host "Auto-detecting your public IP address..." -ForegroundColor Blue
    try {
      $currentIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content.Trim()
      Write-Host "Detected IP: $currentIP" -ForegroundColor Green
    }
    catch {
      Write-Warning "Could not auto-detect IP address. You may need to manually configure allowedIpRanges."
    }
  }

  # Check if Azure CLI is installed and user is logged in
  Write-Host "Checking Azure CLI installation and authentication..." -ForegroundColor Blue
  az account show > $null
  if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI is not installed or you are not logged in. Please run 'az login' first."
  }

  # Remove the resource group creation section since we're deploying at subscription scope
  # The Bicep template will create the resource group

  # Get the script directory and set template and parameter file paths
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
  $templateFile = Join-Path $scriptDir "main.bicep"
  $parameterFile = Join-Path $scriptDir "parameters\$Environment.bicepparam"

  # Verify files exist
  if (-not (Test-Path $templateFile)) {
    throw "Template file not found: $templateFile"
  }

  if (-not (Test-Path $parameterFile)) {
    throw "Parameter file not found: $parameterFile. Please create $Environment.bicepparam in the parameters folder."
  }

  # Deploy the infrastructure at subscription scope
  $deploymentName = "secreports-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

  Write-Host "Deploying infrastructure at subscription scope..." -ForegroundColor Blue
  Write-Host "Template: $templateFile" -ForegroundColor Gray
  Write-Host "Parameters: $parameterFile" -ForegroundColor Gray
  Write-Host "Deployment Name: $deploymentName" -ForegroundColor Gray

  if ($WhatIf) {
    Write-Host "Running What-If analysis..." -ForegroundColor Magenta
    az deployment sub what-if --location "$Location" --template-file "$templateFile" --parameters "$parameterFile" --name "$deploymentName"
  }
  else {
    az deployment sub create --location "$Location" --template-file "$templateFile" --parameters "$parameterFile" --name "$deploymentName" --verbose

    if ($LASTEXITCODE -eq 0) {
      Write-Host "Deployment completed successfully!" -ForegroundColor Green

      # Get outputs
      Write-Host "Deployment Outputs:" -ForegroundColor Blue
      az deployment sub show `
        --name $deploymentName `
        --query properties.outputs `
        --output table
    }
    else {
      throw "Deployment failed. Please check the error messages above."
    }
  }
}
catch {
  Write-Host "Error occurred during deployment:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

Write-Host "Script completed successfully!" -ForegroundColor Green
