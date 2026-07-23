---
layout: default
title: Restoring S3 backup versions
parent: Restoring Backups
nav_order: 4
---

# Context

In object store contexts (AWS S3 with versioning enabled), splunkconf-backup remote backups keep the same object key for each backup type. Older content is retained as S3 object versions rather than as separate dated filenames.

The `splunkconf-backup-restore-version.sh` utility helps you find a backup version prior to a given date and either:

* promote that version back to the **latest** object (so the next cloud recovery or restore picks it up), or
* **download** a copy locally for manual inspection or restoration.

This is useful when you need to roll back to a recovery point before a bad change, without hunting through the S3 console version list by hand.

# Prerequisites

* AWS CLI (`aws`), `jq`, and `date` available on the host where you run the script
* S3 bucket versioning enabled on the backup bucket
* IAM permissions to:
  * `head-bucket` and `list-objects-v2` under the `splunkconf-backup/` prefix
  * `list-object-versions`, `head-object`, and `get-object` on backup objects
  * `copy-object` if you choose to promote a version to latest (restore in place)

The script is located in the app at:

```
$SPLUNK_HOME/etc/apps/splunkconf-backup/bin/splunkconf-backup-restore-version.sh
```

# Usage

```
splunkconf-backup-restore-version.sh <bucket_name> <host> <date>
```

| Argument | Description |
|----------|-------------|
| `bucket_name` | S3 bucket that holds splunkconf backups |
| `host` | Host directory name under the `splunkconf-backup/` prefix (usually the instance hostname used at backup time) |
| `date` | Restore threshold: absolute `YYYY-MM-DD` or relative such as `-3d` (days ago) |

Example — find backups for host `splunk-prod-01` older than three days ago:

```
splunkconf-backup-restore-version.sh my-backup-bucket splunk-prod-01 -3d
```

Example — find backups older than a specific date:

```
splunkconf-backup-restore-version.sh my-backup-bucket splunk-prod-01 2026-07-01
```

Objects are expected under:

```
s3://<bucket_name>/splunkconf-backup/<host>/backupconfsplunk-*
```

# How it works

For each backup type (`backupconfsplunk-rel-etc-targeted-*.tar.zst`, kvdump, state, scripts, and so on) the script:

1. Lists S3 object versions for that key.
2. Shows information about the **current latest** version (including `splunkconf-backup-date` metadata when present).
3. Skips action if the latest is already older than your target date, or if the latest already matches the restore candidate (same ETag).
4. Selects the **newest version whose LastModified is before** the target date.
5. Prompts for what to do next.

If the current object was deleted (delete marker is latest), the script reports the deletion date and the last available version, then skips that backup type (no in-place restore is possible without a current object).

# Interactive prompts

When a restore candidate is found, you are prompted:

```
Copy this version as latest? (y=yes, n=skip, d=download, q=quit):
```

| Choice | Action |
|--------|--------|
| `y` | Copy the selected version to the same S3 key as a new latest object. Metadata is set to preserve the original backup date and record the restored version id. |
| `n` | Skip this backup type and continue with the next one. |
| `d` | Download the selected version to the current directory. The local filename includes a timestamp derived from the version date (for example `./backupconfsplunk-rel-etc-targeted-20260715-1430.tar.zst`). |
| `q` | Exit the script immediately. |

Promoting a version (`y`) does **not** restore Splunk by itself. It makes that backup the object recovery will use on the next automated restore (for example via `splunkconf-cloud-recovery` or rsync autorestore). For manual restore steps, see [Restoring Backups](./Restoring-backups.md#manually-restore).

# Metadata and idempotency

When copying a version to latest, the script sets object metadata:

* `splunkconf-backup-date` — original version timestamp (so lifecycle and reporting stay consistent)
* `splunkconf-restored-from-version` — S3 VersionId that was promoted

Re-running the script after a successful promote is safe: if latest already matches the candidate content, or is already older than the target date, no further action is proposed.

# Limitations

* **S3 only** — the script uses AWS CLI S3 APIs. Azure Blob and GCS support is not implemented yet.
* **Versioning required** — without S3 versioning, previous backup content is not available through this tool.
* **Interactive** — the script prompts per backup type; it is intended for operator-driven rollback, not unattended cron use.

# Related pages

* [Restoring Backups](./Restoring-backups.md) — manual and automatic restore overview
* [Restoring Methods](./Restoring-Methods.md) — terraform and cloud recovery paths
* [Debugging recovery](./Debugging-recovery.md) — troubleshooting cloud recovery after a version rollback
