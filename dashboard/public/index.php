<?php
declare(strict_types=1);

$dashboard = [
    'title'       => 'WZI Enterprise Operations Center',
    'environment' => 'Production',
    'release'     => 'v1.5.0',
    'status'      => 'HEALTHY',
];

$services = [
    ['name' => 'Docker',     'status' => 'HEALTHY', 'detail' => 'Container runtime'],
    ['name' => 'PostgreSQL', 'status' => 'HEALTHY', 'detail' => 'Primary database'],
    ['name' => 'Redis',      'status' => 'HEALTHY', 'detail' => 'Cache & queue'],
    ['name' => 'n8n',        'status' => 'HEALTHY', 'detail' => 'Automation engine'],
    ['name' => 'Caddy',      'status' => 'HEALTHY', 'detail' => 'Reverse proxy & TLS'],
];

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title><?= e($dashboard['title']) ?></title>
    <link rel="stylesheet" href="assets/css/wzi-dashboard.css">
</head>

<body>

<header class="topbar">
    <div>
        <div class="brand-row">
            <div class="brand-mark">WZI</div>

            <div>
                <h1><?= e($dashboard['title']) ?></h1>
                <p>Core Stack Infrastructure & Operations</p>
            </div>
        </div>
    </div>

    <div class="topbar-meta">
        <span class="badge badge-production">
            <?= e($dashboard['environment']) ?>
        </span>

        <span class="release">
            Release <?= e($dashboard['release']) ?>
        </span>

        <span id="utc-clock">UTC --:--:--</span>
    </div>
</header>


<div class="app-shell">

    <aside class="sidebar">

        <nav>
            <a class="active" href="#overview">Overview</a>
            <a href="#services">Services</a>
            <a href="#resources">Host Resources</a>
            <a href="#trends">Historical Trends</a>
            <a href="#backup">Backup</a>
            <a href="#ssl">SSL Certificate</a>
            <a href="#alerts">Alerts</a>
            <a href="#operations">Operations</a>
            <a href="#release">Release</a>
        </nav>

        <div class="sidebar-footer">
            <span class="status-dot healthy"></span>
            Core Stack Healthy
        </div>

    </aside>


    <main class="content">

        <section id="overview">

            <div class="section-heading">
                <div>
                    <span class="eyebrow">Executive Overview</span>
                    <h2>Infrastructure Command Center</h2>
                </div>

                <span class="last-update">
                    Dashboard Foundation
                </span>
            </div>


            <div class="kpi-grid">

                <article class="kpi-card">
                    <span>Infrastructure</span>
                    <strong id="kpi-infrastructure" class="text-healthy">HEALTHY</strong>
                    <small id="kpi-infrastructure-detail">Loading live status...</small>
                </article>

                <article class="kpi-card">
                    <span>Availability</span>
                    <strong id="kpi-availability">LIVE</strong>
                    <small id="kpi-last-refresh">Waiting for telemetry...</small>
                </article>

                <article class="kpi-card">
                    <span>Backup</span>
                    <strong id="kpi-backup" class="text-healthy">CURRENT</strong>
                    <small id="kpi-backup-detail">Loading backup status...</small>
                </article>

                <article class="kpi-card">
                    <span>SSL</span>
                    <strong id="kpi-ssl" class="text-healthy">VALID</strong>
                    <small id="kpi-ssl-detail">Loading certificate status...</small>
                </article>

                <article class="kpi-card">
                    <span>Active Incidents</span>
                    <strong>0</strong>
                    <small>No active critical incidents</small>
                </article>

                <article class="kpi-card">
                    <span>Current Release</span>
                    <strong id="kpi-release"><?= e($dashboard['release']) ?></strong>
                    <small id="kpi-release-detail">Dashboard development</small>
                </article>

            </div>

        </section>


        <section id="services" class="panel">

            <div class="panel-header">
                <div>
                    <span class="eyebrow">Infrastructure</span>
                    <h2>Service Health</h2>
                </div>

                <span class="badge badge-healthy">
                    All Systems Operational
                </span>
            </div>


            <div class="service-grid">

                <?php foreach ($services as $service): ?>

                    <article class="service-card" data-service="<?= e(strtolower($service['name'])) ?>">

                        <div class="service-icon">
                            <?= e(substr($service['name'], 0, 1)) ?>
                        </div>

                        <div class="service-info">
                            <h3><?= e($service['name']) ?></h3>
                            <p><?= e($service['detail']) ?></p>
                        </div>

                        <span class="service-status">
                            <span class="status-dot healthy"></span>
                            <span class="service-status-text"><?= e($service['status']) ?></span>
                        </span>

                    </article>

                <?php endforeach; ?>

            </div>

        </section>


        <div class="two-column">

            <section id="resources" class="panel">

                <div class="panel-header">
                    <div>
                        <span class="eyebrow">Server</span>
                        <h2>Host Resources</h2>
                    </div>
                </div>

                <div class="metric">
                    <div>
                        <span>CPU</span>
                        <strong id="metric-cpu">--%</strong>
                    </div>
                    <div class="progress">
                        <span id="bar-cpu" style="width:0%"></span>
                    </div>
                </div>

                <div class="metric">
                    <div>
                        <span>Memory</span>
                        <strong id="metric-memory">--%</strong>
                    </div>
                    <div class="progress">
                        <span id="bar-memory" style="width:0%"></span>
                    </div>
                </div>

                <div class="metric">
                    <div>
                        <span>Disk</span>
                        <strong id="metric-disk">--%</strong>
                    </div>
                    <div class="progress">
                        <span id="bar-disk" style="width:0%"></span>
                    </div>
                </div>

                <div class="mini-grid">
                    <div>
                        <span>Load Average</span>
                        <strong id="metric-load">--</strong>
                    </div>

                    <div>
                        <span>Uptime</span>
                        <strong id="metric-uptime">--</strong>
                    </div>
                </div>

            </section>


            <section id="backup" class="panel">

                <div class="panel-header">
                    <div>
                        <span class="eyebrow">Data Protection</span>
                        <h2>PostgreSQL Backup</h2>
                    </div>

                    <span class="badge badge-healthy">
                        HEALTHY
                    </span>
                </div>

                <div class="detail-list">

                    <div>
                        <span>Latest Backup</span>
                        <strong id="backup-latest">--</strong>
                    </div>

                    <div>
                        <span>Backup Age</span>
                        <strong id="backup-age">--</strong>
                    </div>

                    <div>
                        <span>Status</span>
                        <strong id="backup-status" class="text-healthy">--</strong>
                    </div>

                    <div>
                        <span>DR Status</span>
                        <strong class="text-healthy">VALIDATED</strong>
                    </div>

                </div>

            </section>

        </div>


        <div class="two-column">

            <section id="ssl" class="panel">

                <div class="panel-header">
                    <div>
                        <span class="eyebrow">Security</span>
                        <h2>SSL Certificate</h2>
                    </div>

                    <span class="badge badge-healthy">
                        VALID
                    </span>
                </div>

                <div class="detail-list">

                    <div>
                        <span>Endpoint</span>
                        <strong id="ssl-hostname">--</strong>
                    </div>

                    <div>
                        <span>Days Remaining</span>
                        <strong id="ssl-days">--</strong>
                    </div>

                    <div>
                        <span>Expiry</span>
                        <strong id="ssl-expiry">--</strong>
                    </div>

                    <div>
                        <span>Status</span>
                        <strong id="ssl-status" class="text-healthy">--</strong>
                    </div>

                </div>

            </section>


            <section id="alerts" class="panel">

                <div class="panel-header">
                    <div>
                        <span class="eyebrow">Observability</span>
                        <h2>Recent Alerts</h2>
                    </div>
                </div>

                <div class="timeline">

                    <div class="timeline-item">
                        <span class="status-dot healthy"></span>
                        <div>
                            <strong>RECOVERY</strong>
                            <p>Core Stack returned to HEALTHY.</p>
                        </div>
                    </div>

                    <div class="timeline-item">
                        <span class="status-dot critical"></span>
                        <div>
                            <strong>CRITICAL TEST</strong>
                            <p>Synthetic alert validation completed.</p>
                        </div>
                    </div>

                    <div class="timeline-item">
                        <span class="status-dot info"></span>
                        <div>
                            <strong>TELEGRAM</strong>
                            <p>Notification gateway operational.</p>
                        </div>
                    </div>

                </div>

            </section>

        </div>



        <section id="trends" class="panel">

            <div class="panel-header">
                <div>
                    <span class="eyebrow">Historical Telemetry</span>
                    <h2>24-Hour Infrastructure Trends</h2>
                </div>

                <div class="trend-header-meta">
                    <span id="history-range" class="badge badge-readonly">
                        24H
                    </span>

                    <span id="history-generated" class="last-update">
                        Loading history...
                    </span>
                </div>
            </div>

            <div class="historical-kpi-grid">

                <article class="history-stat">
                    <span>Availability</span>
                    <strong id="history-availability">--%</strong>
                    <small>Non-critical historical buckets</small>
                </article>

                <article class="history-stat">
                    <span>Peak CPU</span>
                    <strong id="history-cpu-max">--%</strong>
                    <small id="history-cpu-avg">Average --%</small>
                </article>

                <article class="history-stat">
                    <span>Peak Memory</span>
                    <strong id="history-memory-max">--%</strong>
                    <small id="history-memory-avg">Average --%</small>
                </article>

                <article class="history-stat">
                    <span>Peak Load</span>
                    <strong id="history-load-max">--</strong>
                    <small>1-minute load average</small>
                </article>

                <article class="history-stat">
                    <span>Backup Max Age</span>
                    <strong id="history-backup-max">-- h</strong>
                    <small id="history-backup-status">Status --</small>
                </article>

                <article class="history-stat">
                    <span>SSL Minimum</span>
                    <strong id="history-ssl-min">-- days</strong>
                    <small id="history-ssl-status">Status --</small>
                </article>

            </div>

            <div class="chart-grid">

                <article class="chart-panel">
                    <div class="chart-heading">
                        <div>
                            <span class="chart-label">Resources</span>
                            <h3>CPU, Memory & Disk</h3>
                        </div>
                        <span class="chart-unit">Percent</span>
                    </div>

                    <div class="chart-container">
                        <canvas
                            id="resource-trend-chart"
                            aria-label="CPU memory and disk utilization over time"
                            role="img"></canvas>
                    </div>
                </article>

                <article class="chart-panel">
                    <div class="chart-heading">
                        <div>
                            <span class="chart-label">Performance</span>
                            <h3>Load Average</h3>
                        </div>
                        <span class="chart-unit">Load 1</span>
                    </div>

                    <div class="chart-container">
                        <canvas
                            id="load-trend-chart"
                            aria-label="Server load average over time"
                            role="img"></canvas>
                    </div>
                </article>

                <article class="chart-panel">
                    <div class="chart-heading">
                        <div>
                            <span class="chart-label">Data Protection</span>
                            <h3>Backup Age</h3>
                        </div>
                        <span class="chart-unit">Hours</span>
                    </div>

                    <div class="chart-container">
                        <canvas
                            id="backup-trend-chart"
                            aria-label="PostgreSQL backup age over time"
                            role="img"></canvas>
                    </div>
                </article>

                <article class="chart-panel">
                    <div class="chart-heading">
                        <div>
                            <span class="chart-label">Certificate</span>
                            <h3>SSL Validity</h3>
                        </div>
                        <span class="chart-unit">Days Remaining</span>
                    </div>

                    <div class="chart-container">
                        <canvas
                            id="ssl-trend-chart"
                            aria-label="SSL certificate days remaining over time"
                            role="img"></canvas>
                    </div>
                </article>

            </div>

            <p id="history-message"
               class="security-note"
               aria-live="polite">
                Historical telemetry is loading.
            </p>

        </section>


<section id="operations" class="panel">

            <div class="panel-header">
                <div>
                    <span class="eyebrow">Operations</span>
                    <h2>Quick Actions</h2>
                </div>

                <span class="badge badge-readonly">
                    READ-ONLY FOUNDATION
                </span>
            </div>

            <div class="action-grid">

                <button type="button" disabled>
                    Run Health Check
                </button>

                <button type="button" disabled>
                    Run Backup
                </button>

                <button type="button" disabled>
                    View Logs
                </button>

                <button type="button" disabled>
                    Telegram Test
                </button>

            </div>

            <p class="security-note">
                Administrative actions remain disabled until the
                authenticated Operations Gateway is implemented.
            </p>

        </section>


        <section id="release" class="panel">

            <div class="panel-header">
                <div>
                    <span class="eyebrow">Governance</span>
                    <h2>Release Information</h2>
                </div>
            </div>

            <div class="release-grid">

                <div>
                    <span>Release</span>
                    <strong id="release-version">v1.5.0</strong>
                </div>

                <div>
                    <span>Branch</span>
                    <strong id="release-branch">release/v1.5.0</strong>
                </div>

                <div>
                    <span>Baseline</span>
                    <strong id="release-commit">--</strong>
                </div>

                <div>
                    <span>Milestone</span>
                    <strong>Dashboard Foundation</strong>
                </div>

            </div>

        </section>


        <footer>
            WZI Core Stack · Enterprise Operations Dashboard ·
            v1.5.0 Development
        </footer>


<!-- =========================================================
     WZI v1.6.0 Milestone 6C - Operational Intelligence
     Temporary DEV-2.4D Candidate
     ========================================================= -->
<section id="wzi-operational-intelligence"
         class="wzi-intelligence-section"
         aria-labelledby="wzi-intelligence-title">

    <div class="wzi-intelligence-heading">
        <div>
            <p class="wzi-intelligence-eyebrow">Operational Intelligence</p>
            <h2 id="wzi-intelligence-title">Infrastructure Intelligence</h2>
            <p>
                Live and historical operational analysis derived from
                certified WZI telemetry.
            </p>
        </div>

        <div id="wzi-health-score"
             class="wzi-health-score"
             data-state="ATTENTION"
             aria-live="polite">
            <span class="wzi-health-score-label">Operational Score</span>
            <strong id="wzi-health-score-value">--</strong>
            <span id="wzi-health-score-state">ATTENTION</span>
        </div>
    </div>

    <div id="wzi-intelligence-message"
         class="wzi-intelligence-message"
         role="status"
         aria-live="polite">
        Loading operational intelligence…
    </div>

    <div class="wzi-intelligence-grid"
         aria-label="Host operational intelligence">

        <article class="wzi-intelligence-card"
                 data-metric="cpu">
            <h3>CPU Utilization</h3>
            <div class="wzi-intelligence-value"
                 id="wzi-cpu-current">--</div>
            <div class="wzi-state-badge"
                 id="wzi-cpu-threshold"
                 data-state="UNKNOWN">UNKNOWN</div>
            <div class="wzi-comparison"
                 id="wzi-cpu-comparison">Comparison unavailable</div>
        </article>

        <article class="wzi-intelligence-card"
                 data-metric="memory">
            <h3>Memory Utilization</h3>
            <div class="wzi-intelligence-value"
                 id="wzi-memory-current">--</div>
            <div class="wzi-state-badge"
                 id="wzi-memory-threshold"
                 data-state="UNKNOWN">UNKNOWN</div>
            <div class="wzi-comparison"
                 id="wzi-memory-comparison">Comparison unavailable</div>
        </article>

        <article class="wzi-intelligence-card"
                 data-metric="disk">
            <h3>Disk Utilization</h3>
            <div class="wzi-intelligence-value"
                 id="wzi-disk-current">--</div>
            <div class="wzi-state-badge"
                 id="wzi-disk-threshold"
                 data-state="UNKNOWN">UNKNOWN</div>
            <div class="wzi-comparison"
                 id="wzi-disk-comparison">Comparison unavailable</div>
        </article>
    </div>

    <div class="wzi-restart-intelligence">
        <h3>Service Restart Trend</h3>

        <div class="wzi-restart-table-wrap">
            <table class="wzi-restart-table">
                <thead>
                    <tr>
                        <th scope="col">Service</th>
                        <th scope="col">Current</th>
                        <th scope="col">Historical</th>
                        <th scope="col">Trend</th>
                    </tr>
                </thead>
                <tbody id="wzi-restart-trend-body">
                    <tr>
                        <td colspan="4">Loading restart intelligence…</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>

</main>

</div>

<script src="assets/vendor/chartjs/chart.umd.min.js"></script>
<script src="assets/js/wzi-dashboard.js"></script>

</body>
</html>
