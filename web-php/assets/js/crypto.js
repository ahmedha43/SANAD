/**
 * Zero-Knowledge E2EE Crypto Engine (AES-256-GCM + PBKDF2)
 * Works entirely in the browser — server never sees plaintext.
 */

const CryptoEngine = {
    _keyCache: {},

    async deriveKey(passphrase) {
        if (this._keyCache[passphrase]) return this._keyCache[passphrase];
        const enc = new TextEncoder();
        const keyMaterial = await window.crypto.subtle.importKey(
            'raw', enc.encode(passphrase), 'PBKDF2', false, ['deriveKey']
        );
        const key = await window.crypto.subtle.deriveKey(
            { name: 'PBKDF2', salt: enc.encode(window.APP_CONFIG.defaultSalt || 'ParentalControlSalt2026'), iterations: 100000, hash: 'SHA-256' },
            keyMaterial,
            { name: 'AES-GCM', length: 256 },
            false,
            ['encrypt', 'decrypt']
        );
        this._keyCache[passphrase] = key;
        return key;
    },

    async decryptText(encryptedStr) {
        if (!encryptedStr || !encryptedStr.startsWith('enc:v1:')) return encryptedStr;
        try {
            const parts = encryptedStr.split(':');
            if (parts.length < 4) return encryptedStr;
            const iv = Uint8Array.from(atob(parts[2]), c => c.charCodeAt(0));
            const ciphertext = Uint8Array.from(atob(parts[3]), c => c.charCodeAt(0));
            const key = await this.deriveKey(window.STATE?.familyKey || 'ParentSecretPassphrase2026');
            const decrypted = await window.crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertext);
            return new TextDecoder().decode(decrypted);
        } catch (e) {
            return encryptedStr; // Return as-is if decryption fails
        }
    },

    async decryptIfNeeded(value) {
        if (typeof value !== 'string') return value;
        if (value.startsWith('enc:v1:')) return await this.decryptText(value);
        return value;
    }
};

window.CryptoEngine = CryptoEngine;
