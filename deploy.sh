#!/usr/bin/env bash
# Bicep Deployment Script for Security Reports Infrastructure (Linux/macOS)
# Mirrors logic in deploy.ps1
#
# Features:
#  - Mandatory environment selection: dev|prod|test
#  - Optional: --location (default australiaeast)
#  - Optional: --what-if (preview changes only)
#  - Optional: --auto-detect-ip (retrieves your current public IPv4)
#  - Shows deployment outputs on success
#  - Optional pre-compilation to JSON to bypass broken embedded bicep binary (e.g. on NixOS)
#  - Basic pre-flight checks (Azure CLI + login + template/param files)
#
# Usage examples:
#   ./deploy.sh --env dev
#   ./deploy.sh --env test --location "australiaeast" --what-if
#   ./deploy.sh --env prod --auto-detect-ip
#
# To pass extra template parameters (override values) you can append after a `--` separator:
#   ./deploy.sh --env dev -- --someParam value --anotherParam value
# These will be appended to the `az deployment` command after the parameter file.

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
VERSION="1.0.0"

# ANSI colors (fallback if not a TTY)
if [[ -t 1 ]]; then
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[1;33m'
  COLOR_BLUE='\033[0;34m'
  COLOR_MAGENTA='\033[0;35m'
  COLOR_RED='\033[0;31m'
  COLOR_GRAY='\033[0;37m'
  COLOR_RESET='\033[0m'
else
  COLOR_GREEN='' ; COLOR_YELLOW='' ; COLOR_BLUE='' ; COLOR_MAGENTA='' ; COLOR_RED='' ; COLOR_GRAY='' ; COLOR_RESET=''
fi

print_header() {
  echo -e "${COLOR_GREEN}== Security Reports Bicep Deployment ==${COLOR_RESET}" >&2
  echo -e "${COLOR_YELLOW}Script:${COLOR_RESET} ${SCRIPT_NAME}  ${COLOR_YELLOW}Version:${COLOR_RESET} ${VERSION}" >&2
}

usage() {
  cat >&2 <<EOF
${SCRIPT_NAME} - Deploy subscription-scope Bicep infrastructure

Required:
  --env, -e <dev|prod|test>    Deployment environment (selects parameters/<env>.bicepparam)

Optional:
  --location, -l <azure-location>   Azure location for deployment metadata (default: australiaeast)
  --what-if                         Run what-if (no changes applied)
  --auto-detect-ip                  Attempt to discover your public IPv4 (prints value only)
  --compile-json                    Pre-build Bicep + parameter file to JSON (avoids az invoking its bundled bicep)
  --help, -h                        Show this help
  --version                         Show script version

Advanced:
  -- (double dash)                  Everything after this is passed directly to 'az deployment' as extra --parameters KEY=VALUE pairs or flags.

Examples:
  # Standard deployment
  ./${SCRIPT_NAME} --env dev

  # Preview (what-if)
  ./${SCRIPT_NAME} --env test --what-if

  # Override / add template parameters
  ./${SCRIPT_NAME} --env dev -- --myParam foo --anotherParam bar

EOF
}

log()       { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2; }
warn()      { echo -e "${COLOR_MAGENTA}[WARN]${COLOR_RESET} $*" >&2; }
error()     { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }
success()   { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*" >&2; }

ENVIRONMENT=""
LOCATION="australiaeast"
WHAT_IF=false
AUTO_DETECT_IP=false
EXTRA_PARAMS=()
COMPILE_JSON=false
DEBUG_CLI=false
SKIP_VALIDATE=false

# Parse args
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|-e)
      ENVIRONMENT=${2:-}
      shift 2 || { error "--env requires a value"; exit 1; }
      ;;
    --location|-l)
      LOCATION=${2:-}
      shift 2 || { error "--location requires a value"; exit 1; }
      ;;
    --what-if)
      WHAT_IF=true
      shift
      ;;
    --auto-detect-ip)
      AUTO_DETECT_IP=true
      shift
      ;;
    --compile-json)
      COMPILE_JSON=true
      shift
      ;;
    --debug-cli)
      DEBUG_CLI=true
      shift
      ;;
    --skip-validate)
      SKIP_VALIDATE=true
      shift
      ;;
    --version)
      echo "$VERSION"; exit 0
      ;;
    --help|-h)
      usage; exit 0
      ;;
    --) # Remaining go to EXTRA_PARAMS
      shift
      while [[ $# -gt 0 ]]; do
        EXTRA_PARAMS+=("$1")
        shift
      done
      break
      ;;
    *)
      error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

print_header

# Validate environment
case "$ENVIRONMENT" in
  dev|prod|test|poc) ;;
  "") error "--env is required"; exit 1 ;;
  *) error "Invalid environment: '$ENVIRONMENT' (expected dev|prod|test|poc)"; exit 1 ;;
esac

log "Environment: ${ENVIRONMENT}"
log "Location: ${LOCATION}"

# Optionally detect IP
if $AUTO_DETECT_IP; then
  log "Attempting to detect public IP via api.ipify.org"
  if CURRENT_IP=$(curl -4 -s --max-time 10 https://api.ipify.org); then
    if [[ -n "$CURRENT_IP" ]]; then
      success "Detected IP: $CURRENT_IP"
    else
      warn "Empty response when detecting IP"
    fi
  else
    warn "Failed to detect IP (network or service issue)"
  fi
fi

# Pre-flight: Azure CLI installed
if ! command -v az >/dev/null 2>&1; then
  error "Azure CLI 'az' not found in PATH. Install from https://learn.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi

# Check login
if ! az account show >/dev/null 2>&1; then
  error "Not logged into Azure CLI. Run: az login"
  exit 1
fi
success "Azure CLI authenticated"

# (Optional) Show az & bicep version info (non-fatal if bicep not separate)
az --version | head -n 1 >&2 || true
if az bicep version >/dev/null 2>&1; then
  log "Embedded az bicep: $(az bicep version)"
fi
if command -v bicep >/dev/null 2>&1; then
  log "Standalone bicep: $(bicep --version 2>/dev/null)"
fi

# Paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/main.bicep"
PARAM_FILE="${SCRIPT_DIR}/parameters/${ENVIRONMENT}.bicepparam"
COMPILED_TEMPLATE_FILE="${SCRIPT_DIR}/main.compiled.json"
COMPILED_PARAM_FILE="${SCRIPT_DIR}/parameters/${ENVIRONMENT}.compiled.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  error "Template file not found: $TEMPLATE_FILE"
  exit 1
fi
if [[ ! -f "$PARAM_FILE" ]]; then
  error "Parameter file not found: $PARAM_FILE"
  exit 1
fi

DEPLOYMENT_NAME="secreports-deploy-$(date +%Y%m%d-%H%M%S)"

if $COMPILE_JSON; then
  if ! command -v bicep >/dev/null 2>&1; then
    error "--compile-json requested but standalone 'bicep' CLI not found in PATH. Install via Nix (nix profile install nixpkgs#bicep) or see https://learn.microsoft.com/azure/azure-resource-manager/bicep/install"
    exit 1
  fi
  log "Pre-compiling Bicep template to JSON: $COMPILED_TEMPLATE_FILE"
  # Use only --outfile (cannot combine with --outdir across versions)
  bicep build "$TEMPLATE_FILE" --outfile "$COMPILED_TEMPLATE_FILE"
  if command -v bicep >/dev/null 2>&1 && bicep --help 2>&1 | grep -q build-params; then
  log "Pre-compiling parameter file to JSON: $COMPILED_PARAM_FILE"
  bicep build-params "$PARAM_FILE" --outfile "$COMPILED_PARAM_FILE"
    PARAM_ARG="@${COMPILED_PARAM_FILE}"
  else
    warn "This bicep CLI does not support 'build-params'; falling back to original .bicepparam (az will attempt to invoke embedded bicep)."
    PARAM_ARG="$PARAM_FILE"
  fi
  TEMPLATE_TO_USE="$COMPILED_TEMPLATE_FILE"
else
  TEMPLATE_TO_USE="$TEMPLATE_FILE"
  PARAM_ARG="$PARAM_FILE"
fi

log "Template: ${TEMPLATE_TO_USE}"
log "Parameters: ${PARAM_ARG}"
log "Deployment Name: ${DEPLOYMENT_NAME}"

# Pre-validation (subscription scope) to surface template/parameter issues early
if ! $SKIP_VALIDATE; then
  log "Running template validation (subscription scope)"
  set +e
  if ! az deployment sub validate \
      --location "$LOCATION" \
      --template-file "$TEMPLATE_TO_USE" \
      --parameters "$PARAM_ARG" "${EXTRA_PARAMS[@]}" >/tmp/deploy_validate.out 2>&1; then
    error "Validation failed. Output:" && cat /tmp/deploy_validate.out >&2
    error "You can bypass validation with --skip-validate if needed (not recommended)."
    exit 1
  else
    success "Validation passed"
  fi
  set -e
fi

set +e
if $WHAT_IF; then
  log "Running What-If analysis (no resources changed)"
  az deployment sub what-if \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_TO_USE" \
    --parameters "$PARAM_ARG" "${EXTRA_PARAMS[@]}" \
    --name "$DEPLOYMENT_NAME" \
    $($DEBUG_CLI && echo --debug)
  EXIT_CODE=$?
else
  log "Starting subscription-scope deployment"
  az deployment sub create \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_TO_USE" \
    --parameters "$PARAM_ARG" "${EXTRA_PARAMS[@]}" \
    --name "$DEPLOYMENT_NAME" \
    --verbose $($DEBUG_CLI && echo --debug) 2> >(tee /tmp/deploy_err.log >&2)
  EXIT_CODE=$?
fi
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  if grep -q "NoneType" /tmp/deploy_err.log 2>/dev/null; then
    error "Deployment command failed with a Python NoneType attribute error (exit code $EXIT_CODE)."
    warn "This is often an Azure CLI bug triggered by parameter parsing. Suggestions:"
    warn "  - Re-run with --debug-cli to capture full stack"
    warn "  - Try without --compile-json (let 'az' invoke embedded bicep)"
    warn "  - Ensure your Azure CLI is up to date: az upgrade"
    warn "  - If persists, file an issue with captured --debug output"
  else
    error "Deployment command failed (exit code $EXIT_CODE)"
  fi
  exit $EXIT_CODE
fi

if ! $WHAT_IF; then
  success "Deployment completed successfully"
  log "Fetching deployment outputs"
  # Show outputs as a table if possible; fall back to JSON
  if ! az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs --output table 2>/dev/null; then
    az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs --output json || true
  fi
else
  success "What-If completed"
fi

success "Script finished"
