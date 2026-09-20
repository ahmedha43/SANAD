#!/usr/bin/env python3
"""
SANAD Unified Server Config Updater
Synchronizes the server IP and ports across all client apps, configs, and deploy scripts.
Single source of truth: server_config.json
"""

import sys
import os
import re
import json
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(ROOT_DIR, "server_config.json")

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print(f"[!] Config file not found: {CONFIG_FILE}")
        sys.exit(1)
    with open(CONFIG_FILE, "r", encoding="utf-8-sig") as f:
        return json.load(f)

def save_config(cfg):
    cfg["last_updated"] = datetime.now(timezone.utc).isoformat()
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    print(f"[OK] Saved updated config to {CONFIG_FILE}")

def replace_in_file(file_path, replacements):
    """
    replacements is a list of tuples: (regex_pattern, replacement_string, flags)
    """
    if not os.path.exists(file_path):
        print(f"[-] Skipping (file not found): {file_path}")
        return False
    
    with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
        content = f.read()

    new_content = content
    modified = False
    for item in replacements:
        pattern = item[0]
        repl = item[1]
        flags = item[2] if len(item) > 2 else 0
        res, count = re.subn(pattern, repl, new_content, flags=flags)
        if count > 0:
            new_content = res
            modified = True
            
    if modified:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        rel_path = os.path.relpath(file_path, ROOT_DIR) if file_path.startswith(ROOT_DIR) else file_path
        print(f"[OK] Updated: {rel_path}")
        return True
    else:
        rel_path = os.path.relpath(file_path, ROOT_DIR) if file_path.startswith(ROOT_DIR) else file_path
        print(f"[-] No changes needed: {rel_path}")
        return False

def update_all(server_ip=None, backend_port=None):
    cfg = load_config()

    if server_ip:
        cfg["server_ip"] = str(server_ip).strip()
    if backend_port:
        cfg["backend_port"] = int(backend_port)

    # Save any command line updates to server_config.json
    if server_ip or backend_port:
        save_config(cfg)

    ip = cfg.get("server_ip", "192.168.88.54").strip()
    port = cfg.get("backend_port", 8080)
    coturn_port = cfg.get("coturn_port", 3478)
    coturn_tls_port = cfg.get("coturn_tls_port", 5349)
    admin_port = cfg.get("admin_panel_port", 8088)

    print("=" * 60)
    print(f" SANAD CONFIG SYNC -> Server IP: {ip} | Port: {port}")
    print("=" * 60)

    # 1. Windows Agent Model (AgentConfig.cs)
    agent_config_cs = os.path.join(ROOT_DIR, "windows-agent", "src", "Sanad.Core", "Models", "AgentConfig.cs")
    replace_in_file(agent_config_cs, [
        (r'public string ServerUrl \{ get; set; \} = "[^"]+";', f'public string ServerUrl {{ get; set; }} = "http://{ip}:{port}";'),
        (r'public string WsUrl \{ get; set; \} = "[^"]+";', f'public string WsUrl {{ get; set; }} = "ws://{ip}:{port}/ws";')
    ])

    # 2. Windows Agent Live WebRTC (WebRtcLiveStreamService.cs)
    webrtc_service_cs = os.path.join(ROOT_DIR, "windows-agent", "src", "Sanad.Core", "Services", "WebRtcLiveStreamService.cs")
    replace_in_file(webrtc_service_cs, [
        (r'urls = "stun:(?!stun\.l\.google\.com)[^"]+"', f'urls = "stun:{ip}:{coturn_port}"'),
        (r'urls = "turn:[^"]+"', f'urls = "turn:{ip}:{coturn_port}"'),
        (r'urls = "turns:[^"]+"', f'urls = "turns:{ip}:{coturn_tls_port}"')
    ])

    # 3. Active Windows Agent Runtime Config (C:\ProgramData\SANAD\config.json)
    program_data_config = r"C:\ProgramData\SANAD\config.json"
    if os.path.exists(program_data_config):
        try:
            with open(program_data_config, "r", encoding="utf-8-sig") as f:
                p_cfg = json.load(f)
            p_cfg["ServerUrl"] = f"http://{ip}:{port}"
            p_cfg["WsUrl"] = f"ws://{ip}:{port}/ws"
            with open(program_data_config, "w", encoding="utf-8") as f:
                json.dump(p_cfg, f, indent=2)
            print(f"[OK] Updated Windows Agent Runtime: {program_data_config}")
        except Exception as e:
            print(f"[!] Warning: Could not update ProgramData config: {e}")

    # 4. Flutter Parent App Constants (api_constants.dart)
    api_constants = os.path.join(ROOT_DIR, "parent-app", "lib", "core", "constants", "api_constants.dart")
    replace_in_file(api_constants, [
        (r"static const String defaultBaseUrl = '[^']+';", f"static const String defaultBaseUrl = 'http://{ip}:{port}';"),
        (r"static const String defaultWsUrl = '[^']+';", f"static const String defaultWsUrl = 'ws://{ip}:{port}';")
    ])

    # 5. Flutter Parent App WebRTC (live_stream_screen.dart)
    live_stream_screen = os.path.join(ROOT_DIR, "parent-app", "lib", "features", "monitoring", "live_stream_screen.dart")
    replace_in_file(live_stream_screen, [
        (r"\{'urls': 'stun:(?!stun\.l\.google\.com)[^']+'\}", f"{{'urls': 'stun:{ip}:{coturn_port}'}}"),
        (r"'urls': 'turn:[^']+'", f"'urls': 'turn:{ip}:{coturn_port}'")
    ])

    # 6. Flutter Unit Test (app_unit_test.dart)
    app_unit_test = os.path.join(ROOT_DIR, "parent-app", "test", "app_unit_test.dart")
    replace_in_file(app_unit_test, [
        (r"ApiConstants\.baseUrl = 'http://[^']+';", f"ApiConstants.baseUrl = 'http://{ip}:{port}';"),
        (r"expect\(ApiConstants\.loginUrl, 'http://[^']+/api/v1/auth/login'\);", f"expect(ApiConstants.loginUrl, 'http://{ip}:{port}/api/v1/auth/login');"),
        (r"expect\(ApiConstants\.pairCodeUrl\('child-123'\), 'http://[^']+/api/v1/devices/children/child-123/pair-code'\);", f"expect(ApiConstants.pairCodeUrl('child-123'), 'http://{ip}:{port}/api/v1/devices/children/child-123/pair-code');"),
        (r"expect\(ApiConstants\.commandUrl\('dev-456'\), 'http://[^']+/api/v1/devices/dev-456/command'\);", f"expect(ApiConstants.commandUrl('dev-456'), 'http://{ip}:{port}/api/v1/devices/dev-456/command');")
    ])

    # 7. Android Kid Agent UI (MainActivity.kt)
    main_activity = os.path.join(ROOT_DIR, "kids-agent", "app", "src", "main", "java", "com", "parentalcontrol", "kidsagent", "ui", "MainActivity.kt")
    replace_in_file(main_activity, [
        (r'setText\("http://[^"]+"\)', f'setText("http://{ip}:{port}")')
    ])

    # 8. Android Kid Agent WebSocket Client (AgentWebSocketClient.kt)
    agent_ws = os.path.join(ROOT_DIR, "kids-agent", "app", "src", "main", "java", "com", "parentalcontrol", "kidsagent", "data", "network", "AgentWebSocketClient.kt")
    replace_in_file(agent_ws, [
        (r'var serverUrl = app\.prefs\.getString\(KidsAgentApp\.KEY_SERVER_URL, "ws://[^"]+"\)\s*\?:\s*"ws://[^"]+"',
         f'var serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, "ws://{ip}:{port}") ?: "ws://{ip}:{port}"')
    ])

    # 9. Docker Compose (deploy/docker-compose.yml)
    docker_compose = os.path.join(ROOT_DIR, "deploy", "docker-compose.yml")
    replace_in_file(docker_compose, [
        (r'TURN_STUN_URL:\s*"stun:[^"]+"', f'TURN_STUN_URL: "stun:{ip}:{coturn_port}"'),
        (r'TURN_URL:\s*"turn:[^"]+"', f'TURN_URL: "turn:{ip}:{coturn_port}"')
    ])

    # 10. Coturn Config (deploy/coturn/turnserver.conf)
    coturn_conf = os.path.join(ROOT_DIR, "deploy", "coturn", "turnserver.conf")
    replace_in_file(coturn_conf, [
        (r'^external-ip=.*$', f'external-ip={ip}', re.MULTILINE)
    ])

    # 11. PHP Admin Panel App Controller (admin-panel/assets/js/admin.js)
    admin_js = os.path.join(ROOT_DIR, "admin-panel", "assets", "js", "admin.js")
    replace_in_file(admin_js, [
        (r'`\$\{window\.location\.protocol\}//\$\{window\.location\.hostname\}:\d+/api/v1`',
         f'`${{window.location.protocol}}//${{window.location.hostname}}:{port}/api/v1`')
    ])

    # 12. PHP Parent Dashboard REST API (web-php/assets/js/api.js)
    web_php_api_js = os.path.join(ROOT_DIR, "web-php", "assets", "js", "api.js")
    replace_in_file(web_php_api_js, [
        (r'`\$\{location\.protocol\}//\$\{location\.hostname\}:\d+/api/v1`',
         f'`${{location.protocol}}//${{location.hostname}}:{port}/api/v1`')
    ])

    # 13. PHP Parent Dashboard WebSocket (web-php/assets/js/ws.js)
    web_php_ws_js = os.path.join(ROOT_DIR, "web-php", "assets", "js", "ws.js")
    replace_in_file(web_php_ws_js, [
        (r'`\$\{proto\}//\$\{location\.hostname\}:\d+/ws\?token=',
         f'`${{proto}}//${{location.hostname}}:{port}/ws?token=')
    ])

    print("=" * 60)
    print(" [OK] SANAD configuration update completed successfully!")
    print("=" * 60)

if __name__ == "__main__":
    new_ip = sys.argv[1] if len(sys.argv) > 1 else None
    new_port = sys.argv[2] if len(sys.argv) > 2 else None
    update_all(new_ip, new_port)
