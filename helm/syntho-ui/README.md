## Syntho Application Helm Chart ##

To install:
1. Copy `values.yaml` to your own values file.
2. Modify your own values file with your own values.
3. Execute `helm install syntho . -n syntho`.

## Redis configuration

Only a single primary is supported (`redis.replicaCount: 1`, enforced at render time).
There is no Redis HA/failover. Existing labels, Service selectors, data/config PVCs,
and storage-class/PV-label selection are retained.

| Value | Default | Purpose |
| --- | --- | --- |
| `redis.maxmemory` | `512mb` | Data budget; not a bound on total Redis RSS |
| `redis.persistence.appendonly` | `true` | Persist writes in AOF |
| `redis.persistence.appendfsync` | `everysec` | `everysec`, `always`, or `no` |
| `redis.persistence.noAppendfsyncOnRewrite` | `false` | Continue fsync during AOF rewrites |
| `redis.persistence.size` | `1Gi` | Legacy-compatible `redis-data` claim size, not workload sizing |
| `redis.persistence.storageClassName` | `null` | Inherit legacy `redis.storageClassName` (`default`); explicit values override it |
| `redis.resources.requests` | `cpu: 100m`, `memory: 512Mi` | Scheduling requests |
| `redis.resources.limits` | `cpu: "1"`, `memory: 2Gi` | Container limits |
| `redis.startupProbe` | 10s period, 5s timeout, 180 failures | Up to 30 minutes to load AOF |
| `redis.readinessProbe` | 10s period, 5s timeout, 3 failures | Remove unready pod from Service |
| `redis.livenessProbe` | 30s period, 5s timeout, 5 failures | Restart an unresponsive Redis after startup |

All probes use an exec check requiring exactly `PONG`, so `LOADING` is not readiness.
Startup probes suppress readiness/liveness until loading succeeds; increase the
startup failure budget for large datasets or slow disks. A ConfigMap checksum on
the pod template restarts Redis on configuration changes and reruns the init
container that copies config onto the existing config PVC.
The checksum hashes only the rendered Redis ConfigMap, not all chart values or
application Secrets. That ConfigMap contains Redis operational settings only;
the annotation stores a SHA-256 digest, not the config contents or credentials.

The wizard asks for the memory budget, memory limit, data PVC size, and
`everysec`/`always` fsync policy. Other settings remain adjustable in generated values.
Older wizard environment files use these new defaults if values are absent.
The storage default remains 1Gi to preserve existing 1Gi StatefulSet claim
templates without a new upgrade override. It is not a production capacity guarantee.
For fresh installs, choose a workload-appropriate size (for example, 10Gi) via
`REDIS_DATA_STORAGE_SIZE` in the wizard resources file or `redis.persistence.size`
in values. Preserve the existing template size for upgrades of installations
with custom claim sizes. Changing Helm values does not resize existing claims.
`redis.persistence.size` and `redis.persistence.storageClassName` are the canonical
storage keys. The legacy `redis.storageClassName` remains supported when the new
key is null; an explicit empty new key preserves PV-label selection when
`redis.pvLabelKey` is set. Storage-class selection continues to apply to both PVCs.
Keep the `noeviction` policy: rejecting writes at capacity is preferable to silently
evicting queued work. Tune retention and capacity instead. These defaults are not
customer workload sizing; read the shared
[durability, capacity, volume boundaries, and upgrade guidance](../../README.md#redis-durability-and-upgrades).

### Existing PVCs and upgrades

Both `redis-claim` and `redis-data` retain their legacy 1Gi default requests.
The data size is tunable for fresh installs, but must match the existing claim
template on routine upgrades, including installations with custom sizes.
Do not change `redis.persistence.size`, `redis.persistence.storageClassName`,
the legacy `redis.storageClassName`, or `redis.pvLabelKey`
on a routine upgrade of an existing release: StatefulSet `volumeClaimTemplates`
are immutable, and changing values neither resizes nor migrates bound PVCs.

For expansion, check that the existing StorageClass has `allowVolumeExpansion`
and that its provisioner supports expansion. Expand the actual bound `redis-data-redis-0`
PVC separately, wait for provisioned capacity and filesystem resize to complete
(a remount/restart may be needed), and verify disk space from Redis. Keep Helm's
claim template unchanged for routine upgrades, or deliberately recreate the
StatefulSet in a maintenance window while preserving both existing PVCs to align
the template for future claims. Never delete PVCs as an upgrade workaround.
Shrinking is not supported. Static preprovisioned PVs must have adequate capacity
and match the existing selector; increasing a request does not enlarge the disk.

StorageClass changes require a separate migration/backup-and-restore to suitably
provisioned volumes; existing claims cannot simply switch StorageClass. Confirm
PV reclaim policy, node affinity, attachment behavior, and backup recovery before
maintenance. Quiesce/drain the old Redis and persist or back up queues **before**
applying the config-driven restart, as described in the shared upgrade procedure.
