# Bepis Grafana

`nas.nix` owns the authenticated, tailnet-only Grafana frontend and its immutable
data sources. `dashboards.nix` is the source of truth for the provisioned **Bepis**
folder; dashboards are generated as JSON during the NixOS build and must not be
created or edited manually in Grafana.

The provisioned dashboards cover request traces, roster hot paths, jobs/provider
boundaries, controlled diagnostic profiles, and privacy-redacted production log
occurrence. Tempo dashboards can select the production or reverse-tunnelled
development data source. Production Loki is intentionally separate because the
development stack does not provide Loki.

Production Tempo links spans to Loki by the low-cardinality `service.name` to
`service_name` mapping and a bounded 30-second window on each side of the span.
`filterByTraceID` and `filterBySpanID` remain disabled: production journal bodies
are fully redacted and no trace context is retained in logs, so linked rows are
temporal evidence rather than causal evidence.

Dashboard changes must preserve stable UIDs, `editable = false`, low-cardinality
queries, and the privacy boundary. The `bepis-grafana-dashboard-contract` flake
check validates the dashboard inventory and rejects query text containing common
high-risk customer or endpoint terms.
