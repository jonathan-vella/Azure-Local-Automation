**Azure Local cluster update incident**

| Field    | Value |
|----------|-------|
| Cluster  | {{cluster.name}} |
| Resource | {{cluster.resourceId}} |
| Update   | {{run.updateName}} |
| Status   | {{trigger.status}} |
| Severity | {{trigger.severity}} |
| Run      | {{run.platform}} run {{run.id}} ({{run.url}}) |

---

**Details**

{{message}}

---

_This ticket was opened automatically by `AzLocal.UpdateManagement` via
the ITSM Connector. If the underlying cluster recovers (manual remediation
or the next scheduled retry succeeds), the connector will post a work-note
on this incident on the next pipeline run. Do not close manually unless
you have verified the cluster is healthy._
