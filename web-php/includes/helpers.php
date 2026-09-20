<?php
/**
 * Parental Control Platform - Helper Utilities
 */

declare(strict_types=1);

/**
 * Escape HTML special characters safely
 */
function e(?string $str): string {
    return htmlspecialchars($str ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/**
 * Format timestamp into Arabic friendly date/time
 */
function formatDateTime(string|int|null $time): string {
    if (!$time) return 'غير محدد';
    $timestamp = is_numeric($time) ? (int)$time : strtotime($time);
    if (!$timestamp) return 'غير محدد';
    return date('Y-m-d H:i:s', $timestamp);
}

/**
 * Format call type into Arabic label and badge class
 */
function formatCallType(string $type): array {
    return match (strtolower($type)) {
        'incoming' => ['label' => 'واردة', 'class' => 'badge-success', 'icon' => 'fa-arrow-down-left'],
        'outgoing' => ['label' => 'صادرة', 'class' => 'badge-primary', 'icon' => 'fa-arrow-up-right'],
        'missed'   => ['label' => 'فائتة', 'class' => 'badge-danger', 'icon' => 'fa-phone-slash'],
        'rejected' => ['label' => 'مرفوضة', 'class' => 'badge-warning', 'icon' => 'fa-ban'],
        default    => ['label' => $type, 'class' => 'badge-secondary', 'icon' => 'fa-phone'],
    };
}

/**
 * Format risk level
 */
function formatRiskLevel(string $level): array {
    return match (strtolower($level)) {
        'critical', 'high' => ['label' => 'خطورة عالية', 'class' => 'risk-critical', 'icon' => 'fa-triangle-exclamation'],
        'medium', 'warning' => ['label' => 'متوسطة', 'class' => 'risk-warning', 'icon' => 'fa-circle-exclamation'],
        default => ['label' => 'معلومات', 'class' => 'risk-info', 'icon' => 'fa-circle-info'],
    };
}
