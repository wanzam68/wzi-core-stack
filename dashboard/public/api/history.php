<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');

$dataFile = '/var/www/dashboard-data/history.json';

function failResponse(
    int $statusCode,
    string $status,
    string $message
): never {
    http_response_code($statusCode);

    echo json_encode([
        'ok' => false,
        'status' => $status,
        'message' => $message
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

if (!is_readable($dataFile)) {
    failResponse(
        503,
        'UNAVAILABLE',
        'Historical telemetry is unavailable.'
    );
}

$contents = file_get_contents($dataFile);

if ($contents === false) {
    failResponse(
        503,
        'UNAVAILABLE',
        'Historical telemetry could not be read.'
    );
}

$data = json_decode($contents, true);

if (!is_array($data)) {
    failResponse(
        503,
        'INVALID',
        'Historical telemetry is invalid.'
    );
}

if (($data['schema_version'] ?? null) !== 1) {
    failResponse(
        503,
        'INVALID_SCHEMA',
        'Unsupported historical telemetry schema.'
    );
}

$required = [
    'generated_at',
    'range',
    'summary',
    'series'
];

foreach ($required as $field) {
    if (!array_key_exists($field, $data)) {
        failResponse(
            503,
            'INVALID_CONTRACT',
            'Historical telemetry contract is incomplete.'
        );
    }
}

echo json_encode([
    'ok' => true,
    'data' => $data
], JSON_UNESCAPED_SLASHES);
