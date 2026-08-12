"use strict";

(function () {
    const clock = document.getElementById("utc-clock");

    function updateClock() {
        if (!clock) return;

        const now = new Date();

        clock.textContent =
            "UTC " +
            now.toLocaleTimeString("en-GB", {
                timeZone: "UTC",
                hour12: false
            });
    }

    function setText(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = value;
    }

    function setProgress(id, value) {
        const el = document.getElementById(id);
        if (!el) return;

        const safe = Math.max(0, Math.min(100, Number(value) || 0));
        el.style.width = safe + "%";
    }

    function applyStatusClass(el, status) {
        if (!el) return;

        el.classList.remove(
            "text-healthy",
            "text-warning",
            "text-critical"
        );

        switch (status) {
            case "HEALTHY":
                el.classList.add("text-healthy");
                break;
            case "WARNING":
                el.classList.add("text-warning");
                break;
            case "CRITICAL":
            case "MISSING":
                el.classList.add("text-critical");
                break;
        }
    }

    function updateService(key, service) {
        const card = document.querySelector(
            '[data-service="' + key + '"]'
        );

        if (!card || !service) return;

        const text = card.querySelector(".service-status-text");
        const dot = card.querySelector(".status-dot");

        if (text) {
            text.textContent = service.status;
        }

        if (dot) {
            dot.classList.remove(
                "healthy",
                "warning",
                "critical",
                "info"
            );

            if (service.status === "HEALTHY") {
                dot.classList.add("healthy");
            } else if (service.status === "WARNING") {
                dot.classList.add("warning");
            } else {
                dot.classList.add("critical");
            }
        }
    }

    function formatGeneratedAt(value) {
        const date = new Date(value);

        if (Number.isNaN(date.getTime())) {
            return value || "Unknown";
        }

        return date.toLocaleString();
    }

    function render(data) {
        setText("kpi-infrastructure", data.overall_status);
        applyStatusClass(
            document.getElementById("kpi-infrastructure"),
            data.overall_status
        );

        setText(
            "kpi-infrastructure-detail",
            "Live monitoring snapshot"
        );

        setText(
            "kpi-last-refresh",
            "Updated " + formatGeneratedAt(data.generated_at)
        );

        setText("kpi-release", data.release);

        if (data.services) {
            updateService("docker", data.services.docker);
            updateService("postgresql", data.services.postgresql);
            updateService("redis", data.services.redis);
            updateService("n8n", data.services.n8n);
            updateService("caddy", data.services.caddy);
        }

        if (data.host) {
            setText("metric-cpu", data.host.cpu_percent + "%");
            setText("metric-memory", data.host.memory_percent + "%");
            setText("metric-disk", data.host.disk_percent + "%");

            setProgress("bar-cpu", data.host.cpu_percent);
            setProgress("bar-memory", data.host.memory_percent);
            setProgress("bar-disk", data.host.disk_percent);

            setText("metric-load", data.host.load_1);
            setText("metric-uptime", data.host.uptime);
        }

        if (data.backup) {
            setText("kpi-backup", data.backup.status);
            setText(
                "kpi-backup-detail",
                "Age " + data.backup.age_hours + " hour(s)"
            );

            setText("backup-latest", data.backup.size);
            setText(
                "backup-age",
                data.backup.age_hours + " hour(s)"
            );
            setText("backup-status", data.backup.status);

            applyStatusClass(
                document.getElementById("kpi-backup"),
                data.backup.status
            );

            applyStatusClass(
                document.getElementById("backup-status"),
                data.backup.status
            );
        }

        if (data.ssl) {
            setText("kpi-ssl", data.ssl.status);
            setText(
                "kpi-ssl-detail",
                data.ssl.days_remaining + " days remaining"
            );

            setText("ssl-hostname", data.ssl.hostname);
            setText("ssl-days", data.ssl.days_remaining + " days");
            setText("ssl-expiry", data.ssl.expires_at);
            setText("ssl-status", data.ssl.status);

            applyStatusClass(
                document.getElementById("kpi-ssl"),
                data.ssl.status
            );

            applyStatusClass(
                document.getElementById("ssl-status"),
                data.ssl.status
            );
        }

        if (data.release_info) {
            setText("release-version", data.release);
            setText("release-branch", data.release_info.branch);
            setText("release-commit", data.release_info.commit);

            setText(
                "kpi-release-detail",
                data.release_info.branch
            );
        }
    }

    async function loadStatus() {
        try {
            const response = await fetch(
                "api/status.php",
                {
                    cache: "no-store"
                }
            );

            if (!response.ok) {
                throw new Error(
                    "API HTTP " + response.status
                );
            }

            const payload = await response.json();

            if (!payload.ok || !payload.data) {
                throw new Error("Invalid monitoring response");
            }

            render(payload.data);

        } catch (error) {
            console.error(
                "WZI monitoring API unavailable:",
                error
            );

            setText(
                "kpi-infrastructure",
                "UNAVAILABLE"
            );

            applyStatusClass(
                document.getElementById("kpi-infrastructure"),
                "CRITICAL"
            );

            setText(
                "kpi-infrastructure-detail",
                "Live telemetry unavailable"
            );
        }
    }


    /* =====================================================
       Historical telemetry
       ===================================================== */

    const historicalCharts = {};

    function historySetText(id, value) {
        const element = document.getElementById(id);

        if (element) {
            element.textContent = value;
        }
    }

    function historicalTimeLabel(timestamp) {
        const date = new Date(timestamp);

        if (Number.isNaN(date.getTime())) {
            return timestamp;
        }

        return date.toLocaleTimeString("en-GB", {
            hour: "2-digit",
            minute: "2-digit",
            hour12: false
        });
    }

    function chartTheme() {
        const styles =
            getComputedStyle(document.documentElement);

        return {
            text:
                styles.getPropertyValue("--muted").trim()
                || "#8ea2b7",

            border:
                styles.getPropertyValue("--border").trim()
                || "#20344a",

            healthy:
                styles.getPropertyValue("--healthy").trim()
                || "#34d399",

            info:
                styles.getPropertyValue("--info").trim()
                || "#60a5fa",

            warning:
                styles.getPropertyValue("--warning").trim()
                || "#fbbf24",

            accent:
                styles.getPropertyValue("--accent").trim()
                || "#38bdf8"
        };
    }

    function destroyHistoricalChart(name) {
        if (historicalCharts[name]) {
            historicalCharts[name].destroy();
            delete historicalCharts[name];
        }
    }

    function commonChartOptions(yTitle) {
        const theme = chartTheme();

        return {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,

            interaction: {
                mode: "index",
                intersect: false
            },

            plugins: {
                legend: {
                    position: "bottom",

                    labels: {
                        color: theme.text,
                        boxWidth: 12,
                        boxHeight: 2
                    }
                },

                tooltip: {
                    mode: "index",
                    intersect: false
                }
            },

            scales: {
                x: {
                    grid: {
                        color: theme.border
                    },

                    ticks: {
                        color: theme.text,
                        maxTicksLimit: 8
                    }
                },

                y: {
                    beginAtZero: true,

                    grid: {
                        color: theme.border
                    },

                    ticks: {
                        color: theme.text
                    },

                    title: {
                        display: true,
                        text: yTitle,
                        color: theme.text
                    }
                }
            }
        };
    }

    function renderResourceTrend(series) {
        const canvas =
            document.getElementById(
                "resource-trend-chart"
            );

        if (
            !canvas ||
            typeof Chart === "undefined"
        ) {
            return;
        }

        const theme = chartTheme();

        const labels = series.map(
            point =>
                historicalTimeLabel(
                    point.timestamp
                )
        );

        destroyHistoricalChart("resources");

        historicalCharts.resources =
            new Chart(canvas, {
                type: "line",

                data: {
                    labels: labels,

                    datasets: [
                        {
                            label: "CPU",

                            data: series.map(
                                point =>
                                    point.cpu_percent
                            ),

                            borderColor: theme.accent,
                            backgroundColor: theme.accent,
                            borderWidth: 2,
                            pointRadius: 0,
                            tension: 0.2
                        },

                        {
                            label: "Memory",

                            data: series.map(
                                point =>
                                    point.memory_percent
                            ),

                            borderColor: theme.info,
                            backgroundColor: theme.info,
                            borderWidth: 2,
                            pointRadius: 0,
                            tension: 0.2
                        },

                        {
                            label: "Disk",

                            data: series.map(
                                point =>
                                    point.disk_percent
                            ),

                            borderColor: theme.healthy,
                            backgroundColor: theme.healthy,
                            borderWidth: 2,
                            pointRadius: 0,
                            tension: 0.2
                        }
                    ]
                },

                options:
                    commonChartOptions("Percent")
            });
    }

    function renderSingleTrend(
        chartName,
        canvasId,
        series,
        dataField,
        label,
        unit,
        color
    ) {
        const canvas =
            document.getElementById(canvasId);

        if (
            !canvas ||
            typeof Chart === "undefined"
        ) {
            return;
        }

        const labels = series.map(
            point =>
                historicalTimeLabel(
                    point.timestamp
                )
        );

        destroyHistoricalChart(chartName);

        historicalCharts[chartName] =
            new Chart(canvas, {
                type: "line",

                data: {
                    labels: labels,

                    datasets: [
                        {
                            label: label,

                            data: series.map(
                                point =>
                                    point[dataField]
                            ),

                            borderColor: color,
                            backgroundColor: color,
                            borderWidth: 2,
                            pointRadius: 0,
                            tension: 0.2
                        }
                    ]
                },

                options:
                    commonChartOptions(unit)
            });
    }

    function renderHistoricalSummary(data) {
        const summary = data.summary || {};
        const host = summary.host || {};
        const backup = summary.backup || {};
        const ssl = summary.ssl || {};
        const range = data.range || {};

        historySetText(
            "history-range",
            String(
                range.name || "24h"
            ).toUpperCase()
        );

        historySetText(
            "history-generated",
            "Generated " +
                formatGeneratedAt(
                    data.generated_at
                )
        );

        historySetText(
            "history-availability",
            Number(
                summary.availability_percent || 0
            ).toFixed(2) + "%"
        );

        historySetText(
            "history-cpu-max",
            Number(
                host.cpu_max || 0
            ).toFixed(2) + "%"
        );

        historySetText(
            "history-cpu-avg",
            "Average " +
                Number(
                    host.cpu_avg || 0
                ).toFixed(2) +
                "%"
        );

        historySetText(
            "history-memory-max",
            Number(
                host.memory_max || 0
            ).toFixed(2) + "%"
        );

        historySetText(
            "history-memory-avg",
            "Average " +
                Number(
                    host.memory_avg || 0
                ).toFixed(2) +
                "%"
        );

        historySetText(
            "history-load-max",
            Number(
                host.load_1_max || 0
            ).toFixed(2)
        );

        historySetText(
            "history-backup-max",
            String(
                backup.max_age_hours ?? "--"
            ) + " h"
        );

        historySetText(
            "history-backup-status",
            "Status " +
                String(
                    backup.current_status
                    || "UNKNOWN"
                )
        );

        historySetText(
            "history-ssl-min",
            String(
                ssl.minimum_days_remaining
                ?? "--"
            ) + " days"
        );

        historySetText(
            "history-ssl-status",
            "Status " +
                String(
                    ssl.current_status
                    || "UNKNOWN"
                )
        );
    }

    function renderHistoricalCharts(data) {
        if (!data.series) {
            return;
        }

        const theme = chartTheme();

        renderResourceTrend(
            data.series.host || []
        );

        renderSingleTrend(
            "load",
            "load-trend-chart",
            data.series.host || [],
            "load_1",
            "Load 1",
            "Load",
            theme.warning
        );

        renderSingleTrend(
            "backup",
            "backup-trend-chart",
            data.series.backup || [],
            "age_hours",
            "Backup Age",
            "Hours",
            theme.info
        );

        renderSingleTrend(
            "ssl",
            "ssl-trend-chart",
            data.series.ssl || [],
            "days_remaining",
            "SSL Days Remaining",
            "Days",
            theme.healthy
        );
    }

    async function loadHistoricalStatus() {
        const message =
            document.getElementById(
                "history-message"
            );

        try {
            const response = await fetch(
                "api/history.php",
                {
                    cache: "no-store"
                }
            );

            if (!response.ok) {
                throw new Error(
                    "Historical API HTTP " +
                    response.status
                );
            }

            const payload =
                await response.json();

            if (
                !payload.ok ||
                !payload.data
            ) {
                throw new Error(
                    "Invalid historical response"
                );
            }

            renderHistoricalSummary(
                payload.data
            );

            renderHistoricalCharts(
                payload.data
            );

            if (message) {
                message.textContent =
                    "Historical telemetry loaded successfully.";
            }

        } catch (error) {
            console.error(
                "WZI historical API unavailable:",
                error
            );

            if (message) {
                message.textContent =
                    "Historical telemetry is currently unavailable.";
            }
        }
    }


    updateClock();
    window.setInterval(updateClock, 1000);

    loadStatus();
    window.setInterval(loadStatus, 30000);

    loadHistoricalStatus();

    const links = document.querySelectorAll(".sidebar a");

    links.forEach(function (link) {
        link.addEventListener("click", function () {
            links.forEach(function (item) {
                item.classList.remove("active");
            });

            link.classList.add("active");
        });
    });
})();
