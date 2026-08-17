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

/* ==========================================================
   WZI v1.6.0 Milestone 6C
   Operational Intelligence - DEV-2.4D temporary candidate
   ========================================================== */

(function () {
    "use strict";

    const STATUS_URL = "/api/status.php";
    const HISTORY_URL = "/api/history.php";

    const SERVICES = [
        "caddy",
        "dashboard",
        "docker",
        "n8n",
        "postgresql",
        "redis"
    ];

    const THRESHOLDS = {
        cpu:    { warning: 70, critical: 85 },
        memory: { warning: 70, critical: 85 },
        disk:   { warning: 75, critical: 90 }
    };

    function numeric(value) {
        if (
            value === null ||
            value === undefined ||
            typeof value === "boolean" ||
            (typeof value === "string" && value.trim() === "")
        ) {
            return null;
        }

        const n = Number(value);

        return Number.isFinite(n) ? n : null;
    }

    function readMetric(obj, names) {
        if (!obj || typeof obj !== "object") {
            return null;
        }

        for (const name of names) {
            if (Object.prototype.hasOwnProperty.call(obj, name)) {
                const value = numeric(obj[name]);
                if (value !== null) {
                    return value;
                }
            }
        }

        return null;
    }

    function hostMetric(host, metric) {
        const aliases = {
            cpu: [
                "cpu_percent",
                "cpu",
                "cpu_usage",
                "cpu_usage_percent"
            ],
            memory: [
                "memory_percent",
                "memory",
                "memory_usage",
                "memory_usage_percent"
            ],
            disk: [
                "disk_percent",
                "disk",
                "disk_usage",
                "disk_usage_percent"
            ]
        };

        return readMetric(host, aliases[metric] || []);
    }

    function thresholdState(metric, value) {
        const threshold = THRESHOLDS[metric];

        if (!threshold || value === null) {
            return "UNKNOWN";
        }

        if (value >= threshold.critical) {
            return "CRITICAL";
        }

        if (value >= threshold.warning) {
            return "WARNING";
        }

        return "NORMAL";
    }

    function comparisonState(current, previous) {
        if (current === null || previous === null) {
            return "UNKNOWN";
        }

        const delta = current - previous;

        if (Math.abs(delta) <= 1) {
            return "STABLE";
        }

        return delta < 0 ? "IMPROVED" : "DEGRADED";
    }

    function historicalMetric(series, metric) {
        if (!Array.isArray(series) || series.length === 0) {
            return null;
        }

        /*
         * Use the most recent historical point before the current
         * observation. Search backwards to tolerate sparse points.
         */
        for (let i = series.length - 1; i >= 0; i -= 1) {
            const value = hostMetric(series[i], metric);

            if (value !== null) {
                return value;
            }
        }

        return null;
    }

    function restartValue(point) {
        return readMetric(point, [
            "restart_count",
            "restarts",
            "restartCount"
        ]);
    }

    function historicalRestart(series) {
        if (!Array.isArray(series)) {
            return null;
        }

        for (let i = series.length - 1; i >= 0; i -= 1) {
            const value = restartValue(series[i]);

            if (value !== null) {
                return value;
            }
        }

        return null;
    }

    function restartTrend(current, historical) {
        if (current === null) {
            return "UNKNOWN";
        }

        if (historical === null) {
            return current === 0 ? "STABLE" : "DEGRADED";
        }

        if (current > historical) {
            return "DEGRADED";
        }

        if (current < historical) {
            return "IMPROVED";
        }

        return "STABLE";
    }

    function calculateOperationalScore(statusData) {
        const host = statusData && statusData.host;
        const services = statusData && statusData.services;

        if (!host || !services || typeof services !== "object") {
            return {
                score: 0,
                state: "CRITICAL",
                valid: false
            };
        }

        const metrics = {
            cpu: hostMetric(host, "cpu"),
            memory: hostMetric(host, "memory"),
            disk: hostMetric(host, "disk")
        };

        if (
            metrics.cpu === null ||
            metrics.memory === null ||
            metrics.disk === null
        ) {
            return {
                score: 0,
                state: "CRITICAL",
                valid: false
            };
        }

        let score = 100;

        Object.entries(metrics).forEach(([metric, value]) => {
            const state = thresholdState(metric, value);

            if (state === "WARNING") {
                score -= 8;
            } else if (state === "CRITICAL") {
                score -= 20;
            }
        });

        for (const serviceName of SERVICES) {
            const service = services[serviceName];

            if (!service || typeof service !== "object") {
                score -= 15;
                continue;
            }

            const status = String(
                service.status ||
                service.health ||
                service.state ||
                ""
            ).toUpperCase();

            if (
                status &&
                ![
                    "HEALTHY",
                    "RUNNING",
                    "OK",
                    "UP"
                ].includes(status)
            ) {
                score -= 15;
            }

            const restarts = restartValue(service);

            if (restarts !== null && restarts > 0) {
                score -= Math.min(10, restarts * 2);
            }
        }

        score = Math.max(0, Math.min(100, Math.round(score)));

        let state = "CRITICAL";

        if (score >= 85) {
            state = "HEALTHY";
        } else if (score >= 60) {
            state = "ATTENTION";
        }

        return {
            score,
            state,
            valid: true
        };
    }

    function unwrap(payload) {
        if (
            payload &&
            typeof payload === "object" &&
            payload.data &&
            typeof payload.data === "object"
        ) {
            return payload.data;
        }

        return null;
    }

    async function fetchJson(url) {
        const response = await fetch(url, {
            cache: "no-store",
            headers: {
                "Accept": "application/json"
            }
        });

        if (!response.ok) {
            throw new Error(
                "HTTP " + response.status + " from " + url
            );
        }

        const payload = await response.json();
        const data = unwrap(payload);

        if (!data) {
            throw new Error(
                "Invalid API wrapper from " + url
            );
        }

        return data;
    }

    function setText(id, text) {
        const node = document.getElementById(id);

        if (node) {
            node.textContent = text;
        }
    }

    function setState(id, state) {
        const node = document.getElementById(id);

        if (node) {
            node.dataset.state = state;
            node.textContent = state;
        }
    }

    function renderMetric(metric, current, historical) {
        const prefix = "wzi-" + metric;

        setText(
            prefix + "-current",
            current === null ? "--" : current.toFixed(1) + "%"
        );

        const threshold = thresholdState(metric, current);
        setState(prefix + "-threshold", threshold);

        const comparison = comparisonState(
            current,
            historical
        );

        let label = comparison;

        if (
            current !== null &&
            historical !== null
        ) {
            const delta = current - historical;
            const sign = delta > 0 ? "+" : "";

            label += " (" + sign + delta.toFixed(1) + "%)";
        }

        setText(
            prefix + "-comparison",
            "Previous: " +
            (historical === null
                ? "unavailable"
                : historical.toFixed(1) + "%") +
            " — " +
            label
        );
    }

    function renderRestartTrends(statusData, historyData) {
        const body = document.getElementById(
            "wzi-restart-trend-body"
        );

        if (!body) {
            return;
        }

        body.innerHTML = "";

        const liveServices =
            statusData.services &&
            typeof statusData.services === "object"
                ? statusData.services
                : {};

        const historyServices =
            historyData.series &&
            historyData.series.services &&
            typeof historyData.series.services === "object"
                ? historyData.series.services
                : {};

        SERVICES.forEach((serviceName) => {
            const live = liveServices[serviceName] || {};
            const historySeries =
                historyServices[serviceName] || [];

            const current = restartValue(live);
            const historical =
                historicalRestart(historySeries);

            const trend =
                restartTrend(current, historical);

            const row = document.createElement("tr");

            const serviceCell =
                document.createElement("td");
            serviceCell.textContent = serviceName;

            const currentCell =
                document.createElement("td");
            currentCell.textContent =
                current === null ? "N/A" : String(current);

            const historicalCell =
                document.createElement("td");
            historicalCell.textContent =
                historical === null
                    ? "N/A"
                    : String(historical);

            const trendCell =
                document.createElement("td");

            const badge =
                document.createElement("span");

            badge.className = "wzi-state-badge";
            badge.dataset.state = trend;
            badge.textContent = trend;

            trendCell.appendChild(badge);

            row.appendChild(serviceCell);
            row.appendChild(currentCell);
            row.appendChild(historicalCell);
            row.appendChild(trendCell);

            body.appendChild(row);
        });
    }

    function renderScore(statusData) {
        const result =
            calculateOperationalScore(statusData);

        setText(
            "wzi-health-score-value",
            String(result.score)
        );

        setText(
            "wzi-health-score-state",
            result.state
        );

        const scoreNode =
            document.getElementById("wzi-health-score");

        if (scoreNode) {
            scoreNode.dataset.state = result.state;
        }

        return result;
    }

    function renderDegraded(message) {
        const messageNode =
            document.getElementById(
                "wzi-intelligence-message"
            );

        if (messageNode) {
            messageNode.dataset.state = "ERROR";
            messageNode.textContent = message;
        }

        setState(
            "wzi-cpu-threshold",
            "UNKNOWN"
        );

        setState(
            "wzi-memory-threshold",
            "UNKNOWN"
        );

        setState(
            "wzi-disk-threshold",
            "UNKNOWN"
        );

        setText("wzi-health-score-value", "0");
        setText("wzi-health-score-state", "CRITICAL");

        const scoreNode =
            document.getElementById("wzi-health-score");

        if (scoreNode) {
            scoreNode.dataset.state = "CRITICAL";
        }
    }

    async function loadOperationalIntelligence() {
        const root =
            document.getElementById(
                "wzi-operational-intelligence"
            );

        if (!root) {
            return;
        }

        try {
            /*
             * Fetch live status first so base intelligence can
             * still render if historical telemetry is unavailable.
             */
            const statusData =
                await fetchJson(STATUS_URL);

            const host = statusData.host || {};

            const current = {
                cpu: hostMetric(host, "cpu"),
                memory: hostMetric(host, "memory"),
                disk: hostMetric(host, "disk")
            };

            renderMetric(
                "cpu",
                current.cpu,
                null
            );

            renderMetric(
                "memory",
                current.memory,
                null
            );

            renderMetric(
                "disk",
                current.disk,
                null
            );

            renderScore(statusData);

            let historyData = null;

            try {
                historyData =
                    await fetchJson(HISTORY_URL);
            } catch (historyError) {
                setText(
                    "wzi-intelligence-message",
                    "Live intelligence available. " +
                    "Historical comparison is temporarily unavailable."
                );

                renderRestartTrends(
                    statusData,
                    {}
                );

                return;
            }

            const hostSeries =
                historyData.series &&
                Array.isArray(historyData.series.host)
                    ? historyData.series.host
                    : [];

            renderMetric(
                "cpu",
                current.cpu,
                historicalMetric(
                    hostSeries,
                    "cpu"
                )
            );

            renderMetric(
                "memory",
                current.memory,
                historicalMetric(
                    hostSeries,
                    "memory"
                )
            );

            renderMetric(
                "disk",
                current.disk,
                historicalMetric(
                    hostSeries,
                    "disk"
                )
            );

            renderRestartTrends(
                statusData,
                historyData
            );

            setText(
                "wzi-intelligence-message",
                "Operational intelligence current."
            );
        } catch (error) {
            console.error(
                "Operational intelligence failure:",
                error
            );

            renderDegraded(
                "Operational intelligence unavailable. " +
                "Base dashboard remains available."
            );
        }
    }

    window.WZIOperationalIntelligence = {
        thresholdState,
        comparisonState,
        restartTrend,
        calculateOperationalScore,
        loadOperationalIntelligence
    };

    if (document.readyState === "loading") {
        document.addEventListener(
            "DOMContentLoaded",
            loadOperationalIntelligence
        );
    } else {
        loadOperationalIntelligence();
    }
})();
