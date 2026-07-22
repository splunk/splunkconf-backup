#!/bin/bash


# Copyright 2026 Cisco Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributor :
#
# Matthieu Araman, Splunk/Cisco


#
# Script to find and copy previous versions of splunkconf backup files from an S3 bucket


# 20260722 initial version
# 20260722 add date command version detection and fallback for date command on macos
# 20260722 fix PREFIX variable expansion in S3 queries; use unique backup basenames
# 20260722 show latest backup info; skip rollback when latest already older than target
# 20260722 preserve original backup date in object metadata on restore; idempotent re-run via ETag/effective date
VERSION="20260722e"

# TODO autodetect from bucket name if s3, azure or gcp then auto adapt requirement and commands

set -e

# Check number of arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <bucket_name> <host> <date>"
  echo "this script help to find previous versions of splunkconf backup files from an S3 bucket for a given host prior to a given date"
  echo "The script inform about backup then propose to make the version current so it will be used for the next recover"
  echo "bucket_name: s3 bucket name"
  echo "host: host directory under splunkconf-backup prefix"
  echo "date: date threshold (absolute YYYY-MM-DD or relative like -3d)"
  exit 1
fi

BUCKET="$1"
HOST="$2"
DATE_INPUT="$3"
PREFIX="splunkconf-backup/$HOST/"
REQUIRED_CMDS=("aws" "jq" "date")

# Check required commands
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Required command '$cmd' is not installed. Please install it and retry."
    exit 1
  fi
done

# Check if bucket exists and list permission under prefix
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Error: Bucket '$BUCKET' does not exist or you do not have access."
  exit 1
fi

if ! aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "splunkconf-backup/" --max-items 1 &>/dev/null; then
  echo "Error: You do not have permission to list objects under prefix 'splunkconf-backup/' in bucket '$BUCKET'. Please check your IAM permissions."
  exit 1
fi

# Check write permission by attempting a dry-run copy (copy to a temp key and delete)
TMP_TEST_KEY="splunkconf-backup/${HOST}/.permission_test_$(date +%s)"
if ! aws s3 cp "s3://${BUCKET}/${PREFIX}" "s3://${BUCKET}/${TMP_TEST_KEY}" --recursive --dryrun &>/dev/null; then
  echo "Warning: You may lack write permission to copy objects in bucket '$BUCKET' under prefix '$PREFIX'."
fi

# Cross-platform date helpers (GNU date on Linux, BSD date on macOS)
is_gnu_date() {
  date --version >/dev/null 2>&1
}

parse_date_to_epoch() {
  local input="$1"
  local epoch=""

  if [[ "$input" =~ ^-?([0-9]+)d$ ]]; then
    local days="${BASH_REMATCH[1]}"
    if is_gnu_date; then
      epoch=$(date -d "${days} days ago" +%s)
    else
      epoch=$(date -v-"${days}"d +%s)
    fi
  elif [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    if is_gnu_date; then
      epoch=$(date -d "$input" +%s 2>/dev/null || true)
    else
      epoch=$(date -j -f "%Y-%m-%d" "$input" +%s 2>/dev/null || true)
    fi
  fi

  echo "$epoch"
}

format_epoch_date() {
  local epoch="$1"
  if is_gnu_date; then
    date -d "@${epoch}" '+%Y-%m-%d'
  else
    date -r "${epoch}" '+%Y-%m-%d'
  fi
}

aws_date_to_epoch() {
  echo "$1" | jq -R 'gsub("\\+00:00$"; "Z") | fromdateiso8601'
}

DATE_EPOCH=$(parse_date_to_epoch "$DATE_INPUT")
if [ -z "$DATE_EPOCH" ]; then
  echo "Error: Invalid date format '$DATE_INPUT'. Use YYYY-MM-DD or relative like -3d."
  exit 1
fi

echo "Looking for backups in bucket '$BUCKET' under prefix '$PREFIX' older than $(format_epoch_date "$DATE_EPOCH")."

# List all versions of objects starting with backupconfsplunk- under the prefix
# We will process each backup type separately
# Backup types start with backupconfsplunk-

# Get list of backup files present (unique basenames under the host prefix)
backup_types=$(aws s3api list-object-versions --bucket "$BUCKET" --prefix "$PREFIX" --query "Versions[?starts_with(Key, '${PREFIX}backupconfsplunk-')].Key" --output text | tr '\t' '\n' | awk -F/ '{print $NF}' | sort -u)

if [ -z "$backup_types" ]; then
  echo "No backups found under prefix '$PREFIX'."
  exit 0
fi

for backup_type in $backup_types; do
  echo "Processing backup type: $backup_type"

  backup_key="${PREFIX}${backup_type}"

  # List versions of this backup file
  versions_json=$(aws s3api list-object-versions --bucket "$BUCKET" --prefix "$backup_key" --query "Versions[?Key=='${backup_key}']" --output json)

  latest_version=$(echo "$versions_json" | jq -r '
    map(select(.IsLatest == true)) | first // empty
  ')

  if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
    echo "  No current backup for $backup_type (object deleted or missing), skipping."
    continue
  fi

  latest_version_id=$(echo "$latest_version" | jq -r '.VersionId')
  latest_modified=$(echo "$latest_version" | jq -r '.LastModified')

  latest_head=$(aws s3api head-object --bucket "$BUCKET" --key "$backup_key" --version-id "$latest_version_id")
  backup_date=$(echo "$latest_head" | jq -r '.Metadata["splunkconf-backup-date"] // empty')
  if [ "$backup_date" = "null" ]; then
    backup_date=""
  fi

  if [ -n "$backup_date" ] && [ "$backup_date" != "$latest_modified" ]; then
    echo "  Latest backup: VersionId: $latest_version_id, Backup date: $backup_date, S3 LastModified: $latest_modified"
  else
    echo "  Latest backup: VersionId: $latest_version_id, Date: $latest_modified"
  fi

  if [ -n "$backup_date" ]; then
    effective_date="$backup_date"
  else
    effective_date="$latest_modified"
  fi
  effective_epoch=$(aws_date_to_epoch "$effective_date")
  if [ "$effective_epoch" -lt "$DATE_EPOCH" ]; then
    echo "  Latest is already older than restore target ($(format_epoch_date "$DATE_EPOCH")), no action needed."
    continue
  fi

  # Newest version older than DATE_EPOCH (closest restore point before the threshold)
  selected_version=$(echo "$versions_json" | jq -r --argjson date_epoch "$DATE_EPOCH" '
    def aws_epoch: gsub("\\+00:00$"; "Z") | fromdateiso8601;
    map(select(.LastModified | aws_epoch < $date_epoch)) |
    sort_by(.LastModified) |
    last // empty
  ')

  if [ -z "$selected_version" ] || [ "$selected_version" = "null" ]; then
    echo "  No version older than restore target ($(format_epoch_date "$DATE_EPOCH")), no action needed."
    continue
  fi

  key=$(echo "$selected_version" | jq -r '.Key')
  version_id=$(echo "$selected_version" | jq -r '.VersionId')
  last_modified=$(echo "$selected_version" | jq -r '.LastModified')

  latest_etag=$(echo "$latest_version" | jq -r '.ETag')
  candidate_etag=$(echo "$selected_version" | jq -r '.ETag')
  if [ "$latest_etag" = "$candidate_etag" ]; then
    echo "  Latest already matches restore candidate (same content), no action needed."
    continue
  fi

  echo "  Restore candidate (newest before target): VersionId: $version_id, Date: $last_modified"
  read -p "  Do you want to copy this version as the latest? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Copy the selected version to the same key (overwrite current latest)
    echo "  Copying version $version_id of $key to latest..."
    aws s3api copy-object \
      --bucket "$BUCKET" \
      --copy-source "$BUCKET/$key?versionId=$version_id" \
      --key "$key" \
      --metadata-directive REPLACE \
      --metadata "splunkconf-backup-date=${last_modified},splunkconf-restored-from-version=${version_id}"
    if [ $? -eq 0 ]; then
      echo "  Copy successful."
    else
      echo "  Copy failed. Check permissions."
    fi
  else
    echo "  Skipping copy for $backup_type."
  fi
done

echo "$0 Script completed."
