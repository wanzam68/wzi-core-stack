<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

$dataFile = '/var/www/dashboard-data/status.json';

if (!is_readable($dataFile)) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'status' => 'UNAVAILABLE',
        'message' => 'Monitoring snapshot is unavailable.'
    ]);

    exit;
}

$contents = file_get_contents($dataFile);

if ($contents === false) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'status' => 'UNAVAILABLE',
        'message' => 'Monitoring snapshot could not be read.'
    ]);

    exit;
}

$data = json_decode($contents, true);

if (!is_array($data)) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'status' => 'INVALID',
        'message' => 'Monitoring snapshot is invalid.'
    ]);

    exit;
}

echo json_encode([
    'ok' => true,
    'data' => $data
], JSON_UNESCAPED_SLASHES);
