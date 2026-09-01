let
  tempoDatasource = {
    type = "tempo";
    uid = "$tempo";
  };

  lokiDatasource = {
    type = "loki";
    uid = "bepis-production-loki";
  };

  tempoVariable = {
    current = {
      selected = true;
      text = "Bepis Development Tempo";
      value = "bepis-development-tempo";
    };
    hide = 0;
    includeAll = false;
    label = "Tempo source";
    multi = false;
    name = "tempo";
    options = [ ];
    query = "tempo";
    refresh = 1;
    regex = "/^Bepis (Production|Development) Tempo$/";
    type = "datasource";
  };

  tempoPanel =
    {
      id,
      title,
      description,
      query,
      x ? 0,
      y,
      width ? 12,
      height ? 9,
      limit ? 50,
    }:
    {
      inherit
        id
        title
        description
        ;
      datasource = tempoDatasource;
      fieldConfig = {
        defaults = { };
        overrides = [ ];
      };
      gridPos = {
        h = height;
        w = width;
        inherit x y;
      };
      options = { };
      targets = [
        {
          datasource = tempoDatasource;
          inherit limit query;
          queryType = "traceql";
          refId = "A";
          tableType = "traces";
        }
      ];
      type = "traces";
    };

  logsPanel =
    {
      id,
      title,
      description,
      expression,
      x ? 0,
      y,
      width ? 12,
      height ? 10,
    }:
    {
      inherit
        id
        title
        description
        ;
      datasource = lokiDatasource;
      fieldConfig = {
        defaults = { };
        overrides = [ ];
      };
      gridPos = {
        h = height;
        w = width;
        inherit x y;
      };
      options = {
        dedupStrategy = "none";
        enableLogDetails = true;
        prettifyLogMessage = false;
        showCommonLabels = false;
        showLabels = false;
        showTime = true;
        sortOrder = "Descending";
        wrapLogMessage = true;
      };
      targets = [
        {
          datasource = lokiDatasource;
          editorMode = "code";
          expr = expression;
          queryType = "range";
          refId = "A";
        }
      ];
      type = "logs";
    };

  textPanel =
    {
      id,
      title,
      markdown,
      y,
      height ? 4,
    }:
    {
      inherit id title;
      datasource = {
        type = "datasource";
        uid = "grafana";
      };
      gridPos = {
        h = height;
        w = 24;
        x = 0;
        inherit y;
      };
      options = {
        content = markdown;
        mode = "markdown";
      };
      type = "text";
    };

  tempoDashboard =
    {
      uid,
      title,
      description,
      panels,
      tags,
    }:
    {
      annotations.list = [ ];
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
      liveNow = false;
      inherit
        panels
        tags
        title
        uid
        ;
      refresh = "30s";
      schemaVersion = 41;
      templating.list = [ tempoVariable ];
      time = {
        from = "now-1h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      version = 1;
      weekStart = "";
      inherit description;
    };

  logsDashboard =
    {
      uid,
      title,
      description,
      panels,
      tags,
    }:
    {
      annotations.list = [ ];
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
      liveNow = false;
      inherit
        panels
        tags
        title
        uid
        ;
      refresh = "30s";
      schemaVersion = 41;
      templating.list = [ ];
      time = {
        from = "now-1h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      version = 1;
      weekStart = "";
      inherit description;
    };
in
[
  (tempoDashboard {
    uid = "bepis-request-traces";
    title = "Bepis request traces";
    description = "Bounded request/action trace views for latency, failures, and HTMX request shape.";
    tags = [
      "bepis"
      "observability"
      "requests"
    ];
    panels = [
      (textPanel {
        id = 1;
        title = "How to use this dashboard";
        y = 0;
        markdown = ''
          Select the development or production Tempo source above. Open a trace to inspect named action, response, render, provider, and job spans. Production sampling is intentionally incomplete; use this dashboard for diagnosis, not exact traffic totals.

          Production trace details include a **Logs for this span** link. It searches privacy-redacted service logs in a bounded ±30 second window. The link is temporal evidence and does not claim causal trace-ID correlation.
        '';
      })
      (tempoPanel {
        id = 2;
        title = "Slow Bepis actions (>500 ms)";
        description = "Bepis action spans above 500 ms, ordered by Tempo within the selected dashboard range.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.action != nil && span:duration > 500ms }'';
        x = 0;
        y = 4;
      })
      (tempoPanel {
        id = 3;
        title = "Failed spans";
        description = "Spans whose OpenTelemetry status is error. IHP response-control exits are not treated as application errors.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:status = error }'';
        x = 12;
        y = 4;
      })
      (tempoPanel {
        id = 4;
        title = "HTMX fragment responses";
        description = "Fragment response spans for spotting duplicate or unexpectedly slow browser follow-up requests.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.response.kind = "htmx-fragment" }'';
        x = 0;
        y = 13;
      })
      (tempoPanel {
        id = 5;
        title = "Recent Bepis actions";
        description = "All instrumented Bepis action spans in the selected interval.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.action != nil }'';
        x = 12;
        y = 13;
      })
    ];
  })

  (tempoDashboard {
    uid = "bepis-roster-hot-paths";
    title = "Bepis roster hot paths";
    description = "Roster action, read-model, projection, and server-render spans.";
    tags = [
      "bepis"
      "observability"
      "roster"
    ];
    panels = [
      (textPanel {
        id = 1;
        title = "Roster diagnosis";
        y = 0;
        markdown = ''
          These panels expose the retained low-cardinality roster boundaries. Compare repeated child span counts within one trace to detect duplicate fetch/render work. Exact SQL counts remain in isolated diagnostic profile artifacts rather than production traces.
        '';
      })
      (tempoPanel {
        id = 2;
        title = "Slow roster spans (>250 ms)";
        description = "Roster and roster-render spans whose duration exceeds 250 ms.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "(roster|render\\.roster)\\..*" && span:duration > 250ms }'';
        x = 0;
        y = 4;
      })
      (tempoPanel {
        id = 3;
        title = "Roster actions";
        description = "All controller actions whose closed action name contains Roster.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.action =~ ".*Roster.*Action" }'';
        x = 12;
        y = 4;
      })
      (tempoPanel {
        id = 4;
        title = "Roster read-model and projection spans";
        description = "Server-side fetch/build/project boundaries for the roster surface.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "roster\\.(direct|read_model|visible_window|build|predict).*" }'';
        x = 0;
        y = 13;
      })
      (tempoPanel {
        id = 5;
        title = "Roster render spans";
        description = "Named roster render components and response boundaries.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "render\\.roster\\..*" }'';
        x = 12;
        y = 13;
      })
    ];
  })

  (tempoDashboard {
    uid = "bepis-runtime-boundaries";
    title = "Bepis jobs and provider boundaries";
    description = "Privacy-safe background job, provider, live-update, and export spans.";
    tags = [
      "bepis"
      "observability"
      "runtime"
    ];
    panels = [
      (textPanel {
        id = 1;
        title = "Runtime boundary contract";
        y = 0;
        markdown = ''
          One semantic span is emitted per claimed job attempt, selected provider operation, decoded live-update command, or fixed export request. Unknown operations collapse to `unknown`; URLs, payloads, customer identifiers, and exception text are excluded.
        '';
      })
      (tempoPanel {
        id = 2;
        title = "Failed jobs and provider calls";
        description = "Failed semantic boundaries without raw exception content.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "(bepis\\.job\\.run|provider\\..*)" && span:status = error }'';
        x = 0;
        y = 4;
      })
      (tempoPanel {
        id = 3;
        title = "Background job attempts";
        description = "One root-capable span per claimed durable job attempt.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name = "bepis.job.run" }'';
        x = 12;
        y = 4;
      })
      (tempoPanel {
        id = 4;
        title = "External provider operations";
        description = "Selected Stripe, Xero, FWC MAPD, and SMTP operation spans.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "provider\\..*" }'';
        x = 0;
        y = 13;
      })
      (tempoPanel {
        id = 5;
        title = "Live updates and exports";
        description = "Decoded live-update commands and fixed export requests.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span:name =~ "bepis\\.(live_update\\.process|export\\.generate)" }'';
        x = 12;
        y = 13;
      })
    ];
  })

  (tempoDashboard {
    uid = "bepis-diagnostic-profiles";
    title = "Bepis diagnostic profile traces";
    description = "Diagnostic-only action, query-boundary, and render evidence from controlled profiling runs.";
    tags = [
      "bepis"
      "observability"
      "profiling"
    ];
    panels = [
      (textPanel {
        id = 1;
        title = "Controlled diagnostics only";
        y = 0;
        markdown = ''
          `bepis.profile.diagnostic=true` is emitted only when `IHP_ROSTER_PROFILING=1`. Production should leave profiling disabled except for an intentional bounded diagnostic window. Query totals, runtime resources, and render counters remain authoritative in the common profile artifacts.
        '';
      })
      (tempoPanel {
        id = 2;
        title = "Slow diagnostic spans (>100 ms)";
        description = "Diagnostic spans above 100 ms for controlled local or operator-enabled runs.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.profile.diagnostic = true && span:duration > 100ms }'';
        x = 0;
        y = 4;
      })
      (tempoPanel {
        id = 3;
        title = "Diagnostic render spans";
        description = "Profile-gated render boundaries, including bounded HTML-byte and render-counter evidence where present.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.profile.diagnostic = true && span:name =~ "render\\..*" }'';
        x = 12;
        y = 4;
      })
      (tempoPanel {
        id = 4;
        title = "All diagnostic spans";
        description = "Every profile-gated diagnostic span in the selected time range.";
        query = ''{ resource.service.name =~ "ihp-roster.*" && span.bepis.profile.diagnostic = true }'';
        x = 0;
        y = 13;
        width = 24;
      })
    ];
  })

  (logsDashboard {
    uid = "bepis-production-logs";
    title = "Bepis production log occurrence";
    description = "Privacy-redacted production app and worker journal occurrence, severity, service, and timing evidence.";
    tags = [
      "bepis"
      "observability"
      "logs"
    ];
    panels = [
      (textPanel {
        id = 1;
        title = "Privacy and correlation boundary";
        y = 0;
        markdown = ''
          Production journal bodies are replaced with `[redacted production journal event]` before Loki ingestion. Only allowlisted systemd metadata and resource labels remain. Trace links search this stream by service in a bounded ±30 second window; nearby rows are related temporal evidence, not proof that a row came from that trace.
        '';
      })
      (logsPanel {
        id = 2;
        title = "Error-severity journal events";
        description = "Redacted app/worker journal events carrying error-or-higher OpenTelemetry severity metadata.";
        expression = ''{ service_name = "ihp-roster" } | severity_text =~ "(?i)(error|fatal|critical|alert|emergency)"'';
        x = 0;
        y = 4;
      })
      (logsPanel {
        id = 3;
        title = "Recent redacted app and worker events";
        description = "All retained production Bepis journal occurrence evidence in the selected interval.";
        expression = ''{ service_name = "ihp-roster" }'';
        x = 12;
        y = 4;
      })
    ];
  })
]
