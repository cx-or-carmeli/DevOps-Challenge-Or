terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.40.0"
    }
  }
}

provider "grafana" {
  url     = "http://grafana.local"
  auth    = var.grafana_auth
  timeout = "60s"
}

# PostgreSQL Data Source
resource "grafana_data_source" "postgresql" {
  type          = "postgres"
  name          = "PostgreSQL"
  url           = "postgres-postgresql:5432"
  username      = "myuser"
  database_name = "mydatabase"
  is_default    = true
  access_mode   = "proxy"

  json_data_encoded = jsonencode({
    sslmode = "disable"
  })
  secure_json_data_encoded = jsonencode({
    password = var.postgres_password
  })
}

# Wait for Grafana to be accessible
resource "null_resource" "wait_for_grafana" {
  provisioner "local-exec" {
    command = <<-EOT
      max_attempts=30
      attempt=0
      while [ $attempt -lt $max_attempts ]; do
        echo "Attempt $((attempt+1))/$max_attempts: Checking if Grafana is accessible..."
        if curl -s http://grafana.local/api/health | grep -q "ok"; then
          echo "Grafana is accessible!"
          exit 0
        fi
        echo "Waiting 15 seconds before next attempt..."
        sleep 15
        ((attempt++))
      done
      echo "ERROR: Grafana health check failed after $max_attempts attempts"
      exit 1
    EOT
  }
}

# Dashboard Configuration
resource "grafana_dashboard" "datetime_records" {
  config_json = jsonencode({
    annotations = {
      list = [
        {
          builtIn = 1
          datasource = "-- Grafana --"
          enable = true
          hide = true
          iconColor = "rgba(0, 211, 255, 1)"
          name = "Annotations & Alerts"
          type = "dashboard"
        }
      ]
    }
    editable = true
    graphTooltip = 0
    panels = [
      {
        datasource = "PostgreSQL"
        fieldConfig = {
          defaults = {
            color = { mode = "palette-classic" }
            custom = {
              axisPlacement = "auto"
              drawStyle = "line"
              fillOpacity = 0
              lineInterpolation = "linear"
              lineWidth = 1
              pointSize = 5
              showPoints = "auto"
              spanNulls = false
              stacking = { group = "A", mode = "none" }
              thresholdsStyle = { mode = "off" }
            }
            thresholds = { mode = "absolute", steps = [{ color = "green", value = null }] }
          }
          overrides = []
        }
        gridPos = { h = 9, w = 12, x = 0, y = 0 }
        id = 2
        options = {
          legend = { displayMode = "list", placement = "bottom" }
          tooltip = { mode = "single" }
        }
        title = "DateTime Records Timeline"
        type = "timeseries"
        targets = [
          {
            format = "time_series"
            rawQuery = true
            rawSql = "SELECT created_at AS \"time\", 1 as value, 'Record Added' as metric FROM datetime_records ORDER BY created_at"
            refId = "A"
            timeColumn = "time"
          }
        ]
      },
      {
        datasource = "PostgreSQL"
        fieldConfig = {
          defaults = {
            color = { mode = "thresholds" }
            thresholds = { mode = "absolute", steps = [{ color = "green", value = null }] }
          }
          overrides = []
        }
        gridPos = { h = 9, w = 12, x = 12, y = 0 }
        id = 4
        options = {
          colorMode = "value"
          graphMode = "area"
          justifyMode = "auto"
          orientation = "auto"
          reduceOptions = { calcs = ["lastNotNull"], fields = "", values = false }
        }
        title = "Total Records"
        type = "stat"
        targets = [
          {
            format = "time_series"
            rawQuery = true
            rawSql = "SELECT NOW() as time, COUNT(*) as value FROM datetime_records WHERE $__timeFilter(created_at)"
            refId = "A"
            timeColumn = "time"
          }
        ]
      },
      {
        datasource = "PostgreSQL"
        fieldConfig = {
          defaults = {
            color = { mode = "palette-classic" }
            custom = { align = "auto", displayMode = "auto" }
            thresholds = { mode = "absolute", steps = [{ color = "green", value = null }] }
          }
          overrides = []
        }
        gridPos = { h = 8, w = 24, x = 0, y = 9 }
        id = 6
        options = {
          showHeader = true
          sortBy = [{ desc = true, displayName = "Time" }]
        }
        title = "Recent Records"
        type = "table"
        targets = [
          {
            format = "table"
            rawQuery = true
            rawSql = "SELECT id, recorded_at, created_at AS \"Time\" FROM datetime_records ORDER BY created_at DESC LIMIT 10"
            refId = "A"
            timeColumn = "Time"
          }
        ]
      }
    ]
    refresh = "5s"
    schemaVersion = 30
    style = "dark"
    tags = []
    templating = { list = [] }
    time = { from = "now-6h", to = "now" }
    timepicker = {
      refresh_intervals = ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"]
    }
    timezone = "browser"
    title = "PostgreSQL DateTime Records"
    uid = "datetime-records"
    version = 1
  })
  depends_on = [null_resource.wait_for_grafana, grafana_data_source.postgresql]
}
