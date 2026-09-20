<?php
/**
 * Parental Control Platform - Session & Authentication State
 */

declare(strict_types=1);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

/**
 * Check if the user is authenticated in the current session
 */
function isAuthenticated(): bool {
    return !empty($_SESSION['parent_token']);
}

/**
 * Set user authentication session
 */
function setUserSession(string $token, array $user = []): void {
    $_SESSION['parent_token'] = $token;
    $_SESSION['parent_user'] = $user;
    $_SESSION['auth_time'] = time();
}

/**
 * Clear session
 */
function destroyUserSession(): void {
    $_SESSION = [];
    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $params["path"], $params["domain"],
            $params["secure"], $params["httponly"]
        );
    }
    session_destroy();
}
