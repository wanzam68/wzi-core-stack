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
                    <strong class="text-healthy">HEALTHY</strong>
                    <small>8 / 8 monitors operational</small>
                </article>

                <article class="kpi-card">
                    <span>Availability</span>
                    <strong>100%</strong>
                    <small>Current monitoring window</small>
                </article>

                <article class="kpi-card">
                    <span>Backup</span>
                    <strong class="text-healthy">CURRENT</strong>
                    <small>PostgreSQL protection active</small>
                </article>

                <article class="kpi-card">
                    <span>SSL</span>
                    <strong class="text-healthy">VALID</strong>
                    <small>TLS certificate monitored</small>
                </article>

                <article class="kpi-card">
                    <span>Active Incidents</span>
                    <strong>0</strong>
                    <small>No active critical incidents</small>
                </article>

                <article class="kpi-card">
                    <span>Current Release</span>
                    <strong><?= e($dashboard['release']) ?></strong>
                    <small>Dashboard development</small>
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

                    <article class="service-card">

                        <div class="service-icon">
                            <?= e(substr($service['name'], 0, 1)) ?>
                        </div>

                        <div class="service-info">
                            <h3><?= e($service['name']) ?></h3>
                            <p><?= e($service['detail']) ?></p>
                        </div>

                        <span class="service-status">
                            <span class="status-dot healthy"></span>
                            <?= e($service['status']) ?>
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
                        <strong>18%</strong>
                    </div>
                    <div class="progress">
                        <span style="width:18%"></span>
                    </div>
                </div>

                <div class="metric">
                    <div>
                        <span>Memory</span>
                        <strong>42%</strong>
                    </div>
                    <div class="progress">
                        <span style="width:42%"></span>
                    </div>
                </div>

                <div class="metric">
                    <div>
                        <span>Disk</span>
                        <strong>31%</strong>
                    </div>
                    <div class="progress">
                        <span style="width:31%"></span>
                    </div>
                </div>

                <div class="mini-grid">
                    <div>
                        <span>Load Average</span>
                        <strong>0.34</strong>
                    </div>

                    <div>
                        <span>Uptime</span>
                        <strong>5 days</strong>
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
                        <strong>Available</strong>
                    </div>

                    <div>
                        <span>Backup Age</span>
                        <strong>Within Policy</strong>
                    </div>

                    <div>
                        <span>Verification</span>
                        <strong class="text-healthy">PASSED</strong>
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
                        <strong>n8n.wzisaas.com</strong>
                    </div>

                    <div>
                        <span>Issuer</span>
                        <strong>Let's Encrypt</strong>
                    </div>

                    <div>
                        <span>Renewal</span>
                        <strong>Automatic</strong>
                    </div>

                    <div>
                        <span>Monitoring</span>
                        <strong class="text-healthy">ACTIVE</strong>
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
                    <strong>v1.5.0</strong>
                </div>

                <div>
                    <span>Branch</span>
                    <strong>release/v1.5.0</strong>
                </div>

                <div>
                    <span>Baseline</span>
                    <strong>v1.4.0</strong>
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

    </main>

</div>

<script src="assets/js/wzi-dashboard.js"></script>

</body>
</html>
