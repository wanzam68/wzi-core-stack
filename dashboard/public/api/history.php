<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

$allowedRanges = [
    '24h' => 'history.json',
    '7d'  => 'history-7d.json',
    '30d' => 'history-30d.json',
];

$requestedRange = isset($_GET['range'])
    ? strtolower(trim((string) $_GET['range']))
    : '24h';

if (!array_key_exists($requestedRange, $allowedRanges)) {
    http_response_code(400);

    echo json_encode([
        'ok' => false,
        'error' => [
            'code' => 'INVALID_HISTORY_RANGE',
            'message' => 'Supported history ranges are 24h, 7d and 30d.',
        ],
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

$historyFile = dirname(__DIR__, 2)
    . '/dashboard-data/'
    . $allowedRanges[$requestedRange];

if (!is_file($historyFile) || !is_readable($historyFile)) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'error' => [
            'code' => 'HISTORY_NOT_AVAILABLE',
            'message' => 'Historical telemetry is not available for the requested range.',
            'range' => $requestedRange,
        ],
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

$raw = file_get_contents($historyFile);

if ($raw === false) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'error' => [
            'code' => 'HISTORY_READ_FAILED',
            'message' => 'Historical telemetry could not be read.',
            'range' => $requestedRange,
        ],
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

$data = json_decode($raw, true);

if (!is_array($data) || json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(500);

    echo json_encode([
        'ok' => false,
        'error' => [
            'code' => 'INVALID_HISTORY_DOCUMENT',
            'message' => 'Historical telemetry document is invalid.',
            'range' => $requestedRange,
        ],
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

$effectiveRange = $data['range']['name'] ?? null;

if ($effectiveRange !== $requestedRange) {
    http_response_code(503);

    echo json_encode([
        'ok' => false,
        'error' => [
            'code' => 'HISTORY_RANGE_MISMATCH',
            'message' => 'Historical telemetry does not match the requested range.',
            'requested_range' => $requestedRange,
            'effective_range' => $effectiveRange,
        ],
    ], JSON_UNESCAPED_SLASHES);

    exit;
}

echo json_encode([
    'ok' => true,
    'data' => $data,
], JSON_UNESCAPED_SLASHES);
