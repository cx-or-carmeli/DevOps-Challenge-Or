terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.40.0"
    }
  }
}

provider "grafana" {
  url  = "http://grafana.local"
  auth = var.grafana_auth
}

# Create PostgreSQL data source to match deployment.sh configuration
resource "grafana_data_source" "postgresql" {
  type          = "postgres"
  name          = "PostgreSQL"
  url = "postgresql://postgres-postgresql:5432"
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

resource "null_resource" "wait_for_grafana" {
  provisioner "local-exec" {
    command = <<-EOT
      max_attempts=30
      attempt=0
      while [ $attempt -lt $max_attempts ]; do
        echo "Attempt $((attempt+1))/$max_attempts: Checking if Grafana is accessible..."
        if curl -v http://grafana.localapi/health; then
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

# Create dashboard for PostgreSQL datetime records
resource "grafana_dashboard" "datetime_records" {
  config_json = jsonencode({
    "annotations": {
      "list": [
        {
          "builtIn": 1,
          "datasource": "-- Grafana --",
          "enable": true,
          "hide": true,
          "iconColor": "rgba(0, 211, 255, 1)",
          "name": "Annotations & Alerts",
          "type": "dashboard"
        }
      ]
    },
    "editable": true,
    "gnetId": null,
    "graphTooltip": 0,
    "id": null,
    "links": [],
    "panels": [
      {
        "datasource": "PostgreSQL",
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "drawStyle": "line",
              "fillOpacity": 0,
              "gradientMode": "none",
              "hideFrom": {
                "legend": false,
                "tooltip": false,
                "viz": false
              },
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {
                "type": "linear"
              },
              "showPoints": "auto",
              "spanNulls": false,
              "stacking": {
                "group": "A",
                "mode": "none"
              },
              "thresholdsStyle": {
                "mode": "off"
              }
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                }
              ]
            }
          },
          "overrides": []
        },
        "gridPos": {
          "h": 9,
          "w": 12,
          "x": 0,
          "y": 0
        },
        "id": 2,
        "options": {
          "legend": {
            "calcs": [],
            "displayMode": "list",
            "placement": "bottom"
          },
          "tooltip": {
            "mode": "single"
          }
        },
        "title": "DateTime Records Timeline",
        "type": "timeseries",
        "targets": [
          {
            "format": "time_series",
            "group": [],
            "metricColumn": "none",
            "rawQuery": true,
            "rawSql": "SELECT\n  created_at AS \"time\",\n  1 as value,\n  'Record Added' as metric\nFROM datetime_records\nORDER BY created_at",
            "refId": "A",
            "select": [
              [
                {
                  "params": [
                    "value"
                  ],
                  "type": "column"
                }
              ]
            ],
            "timeColumn": "time",
            "where": []
          }
        ]
      },
      {
        "datasource": "PostgreSQL",
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                }
              ]
            }
          },
          "overrides": []
        },
        "gridPos": {
          "h": 9,
          "w": 12,
          "x": 12,
          "y": 0
        },
        "id": 4,
        "options": {
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto",
          "orientation": "auto",
          "reduceOptions": {
            "calcs": [
              "lastNotNull"
            ],
            "fields": "",
            "values": false
          },
          "text": {},
          "textMode": "auto"
        },
        "pluginVersion": "8.0.6",
        "title": "Total Records",
        "type": "stat",
        "targets": [
          {
            "format": "table",
            "group": [],
            "metricColumn": "none",
            "rawQuery": true,
            "rawSql": "SELECT COUNT(*) FROM datetime_records",
            "refId": "A",
            "select": [
              [
                {
                  "params": [
                    "value"
                  ],
                  "type": "column"
                }
              ]
            ],
            "timeColumn": "time",
            "where": []
          }
        ]
      },
      {
        "datasource": "PostgreSQL",
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "align": "auto",
              "displayMode": "auto"
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                }
              ]
            }
          },
          "overrides": []
        },
        "gridPos": {
          "h": 8,
          "w": 24,
          "x": 0,
          "y": 9
        },
        "id": 6,
        "options": {
          "showHeader": true,
          "sortBy": [
            {
              "desc": true,
              "displayName": "Time"
            }
          ]
        },
        "pluginVersion": "8.0.6",
        "title": "Recent Records",
        "type": "table",
        "targets": [
          {
            "format": "table",
            "group": [],
            "metricColumn": "none",
            "rawQuery": true,
            "rawSql": "SELECT id, recorded_at, created_at AS \"Time\" FROM datetime_records ORDER BY created_at DESC LIMIT 10",
            "refId": "A",
            "select": [
              [
                {
                  "params": [
                    "value"
                  ],
                  "type": "column"
                }
              ]
            ],
            "timeColumn": "time",
            "where": []
          }
        ],
        "timeFrom": null,
        "timeShift": null
      }
    ],
    "refresh": "5s",
    "schemaVersion": 30,
    "style": "dark",
    "tags": [],
    "templating": {
      "list": []
    },
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "timepicker": {
      "refresh_intervals": [
        "5s",
        "10s",
        "30s",
        "1m",
        "5m",
        "15m",
        "30m",
        "1h",
        "2h",
        "1d"
      ]
    },
    "timezone": "",
    "title": "PostgreSQL DateTime Records",
    "uid": "datetime-records",
    "version": 1
  })
  depends_on = [null_resource.wait_for_grafana, grafana_data_source.postgresql]
}
