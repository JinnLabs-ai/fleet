#!/usr/bin/env bash
#
# get-jetson-image.sh — download the JetPack 6.2 Orin Nano SD-card image from
# JinnLabs Azure Blob and verify its sha256. Run this on any laptop (macOS or
# Linux) before flashing SD cards per RUNBOOK.md.
#
# Requirements:
#   - azure-cli  (`az login` with access to the `jinn-dev` resource group)
#   - azcopy
# Install on macOS:  brew install azure-cli azcopy
# Install on Linux:  see https://learn.microsoft.com/cli/azure/install-azure-cli
#                    and https://aka.ms/downloadazcopy
#
# Usage:
#   ./get-jetson-image.sh [DEST_PATH]
# Default DEST_PATH: ~/Desktop/jp62-orin-nano-sd-blob.img
#
set -euo pipefail

ACCOUNT=jinndatastorage
RG=jinn-dev
CONTAINER=jinn-jetson-images
BLOB=jp62-orin-nano-sd-blob.img
SHA256=239035634896b6f4e99ea7ca4460978f1f4ba9f58889dc6a803b04618dbb07d7

DEST="${1:-$HOME/Desktop/$BLOB}"

command -v az      >/dev/null || { echo "ERROR: azure-cli not found. brew install azure-cli"; exit 1; }
command -v azcopy  >/dev/null || { echo "ERROR: azcopy not found. brew install azcopy"; exit 1; }
az account show >/dev/null 2>&1 || { echo "ERROR: not logged in. Run: az login"; exit 1; }

# Already present and valid? Skip the download.
if [ -f "$DEST" ]; then
  echo "Found existing $DEST — checking sha256..."
  ACTUAL=$(shasum -a 256 "$DEST" 2>/dev/null | awk '{print $1}' || sha256sum "$DEST" | awk '{print $1}')
  if [ "$ACTUAL" = "$SHA256" ]; then echo "✅ Already have a valid image at $DEST"; exit 0; fi
  echo "Existing file checksum differs — re-downloading."
fi

echo "Minting a short-lived read-only SAS for $CONTAINER/$BLOB ..."
KEY=$(az storage account keys list --account-name "$ACCOUNT" --resource-group "$RG" --query '[0].value' -o tsv)
# 6h expiry, cross-platform date math (macOS BSD date, then GNU date fallback)
EXPIRY=$(date -u -v+6H '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -d '+6 hours' '+%Y-%m-%dT%H:%MZ')
SAS=$(az storage blob generate-sas \
        --account-name "$ACCOUNT" --container-name "$CONTAINER" --name "$BLOB" \
        --account-key "$KEY" --permissions r --expiry "$EXPIRY" --https-only -o tsv)

echo "Downloading to $DEST ..."
azcopy copy "https://$ACCOUNT.blob.core.windows.net/$CONTAINER/$BLOB?$SAS" "$DEST" --overwrite=true

echo "Verifying sha256 (mandatory) ..."
ACTUAL=$(shasum -a 256 "$DEST" 2>/dev/null | awk '{print $1}' || sha256sum "$DEST" | awk '{print $1}')
if [ "$ACTUAL" = "$SHA256" ]; then
  echo "✅ sha256 OK: $ACTUAL"
  echo "Image ready at $DEST — proceed with RUNBOOK.md step 1 (flash)."
else
  echo "❌ sha256 MISMATCH"
  echo "   expected: $SHA256"
  echo "   actual:   $ACTUAL"
  echo "   Delete $DEST and re-run."
  exit 1
fi
