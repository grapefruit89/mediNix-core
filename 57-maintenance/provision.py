import os
import json
import urllib.request
import urllib.error
import ssl

def request(url, method="GET", headers=None, data=None):
    if headers is None: headers = {}
    if data is not None:
        data = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"
    
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl._create_unverified_context()) as response:
            body = response.read()
            if body:
                return json.loads(body)
            return {}
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8')
        print(f"HTTPError: {e.code} {e.reason} - {body}")
        raise

def get_api_key(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

def extract_xml_key(path):
    import re
    try:
        with open(path, 'r') as f:
            content = f.read()
            match = re.search(r'<ApiKey>([^<]+)</ApiKey>', content)
            if match: return match.group(1)
    except FileNotFoundError:
        pass
    return None

def check_sabnzbd_exists(port, api_key):
    url = f"http://127.0.0.1:{port}/api/v3/downloadclient"
    clients = request(url, headers={"X-Api-Key": api_key})
    for client in clients:
        if client.get('implementation') == 'Sabnzbd':
            return True
    return False

def add_sabnzbd(port, api_key, category, sab_port, sab_api):
    if check_sabnzbd_exists(port, api_key):
        print(f"[Port {port}] SABnzbd already exists.")
        return

    print(f"[Port {port}] Adding SABnzbd...")
    url = f"http://127.0.0.1:{port}/api/v3/downloadclient"
    payload = {
        "enable": True,
        "protocol": "usenet",
        "implementation": "Sabnzbd",
        "name": "SABnzbd",
        "settings": {
            "host": "127.0.0.1",
            "port": sab_port,
            "apiKey": sab_api,
            "category": category
        }
    }
    request(url, method="POST", headers={"X-Api-Key": api_key}, data=payload)

def check_prowlarr_app_exists(prowlarr_port, prowlarr_api, app_name):
    url = f"http://127.0.0.1:{prowlarr_port}/api/v1/applications"
    apps = request(url, headers={"X-Api-Key": prowlarr_api})
    for app in apps:
        if app.get('name') == app_name:
            return app.get('id')
    return None

def add_prowlarr_app(prowlarr_port, prowlarr_api, app_name, app_impl, app_port, app_api, sync_categories):
    app_id = check_prowlarr_app_exists(prowlarr_port, prowlarr_api, app_name)
    if app_id:
        print(f"[Prowlarr] App {app_name} already exists.")
        return

    print(f"[Prowlarr] Adding {app_name}...")
    url = f"http://127.0.0.1:{prowlarr_port}/api/v1/applications"
    payload = {
        "name": app_name,
        "implementation": app_impl,
        "configContract": f"{app_impl}Settings",
        "appProfileId": 1,
        "fields": [
            {"name": "prowlarrUrl", "value": f"http://127.0.0.1:{prowlarr_port}"},
            {"name": "baseUrl", "value": f"http://127.0.0.1:{app_port}"},
            {"name": "apiKey", "value": app_api}
        ],
        "syncLevel": "fullSync",
        "syncCategories": sync_categories
    }
    request(url, method="POST", headers={"X-Api-Key": prowlarr_api}, data=payload)

def add_root_folder(port, api_key, root_folder_path):
    url = f"http://127.0.0.1:{port}/api/v3/rootFolder"
    folders = request(url, headers={"X-Api-Key": api_key})
    for folder in folders:
        if folder.get('path') == root_folder_path:
            print(f"[Port {port}] RootFolder {root_folder_path} already exists.")
            return

    print(f"[Port {port}] Adding RootFolder {root_folder_path}...")
    request(url, method="POST", headers={"X-Api-Key": api_key}, data={"path": root_folder_path})

def main():
    SAB_API = get_api_key(os.environ.get('SAB_API_FILE'))
    PROWLARR_API = get_api_key(os.environ.get('PROWLARR_API_FILE'))
    SAB_PORT = int(os.environ.get('SAB_PORT', 5410))
    PROWLARR_PORT = int(os.environ.get('PROWLARR_PORT', 5360))

    if not SAB_API or not PROWLARR_API:
        print("Missing SABnzbd or Prowlarr API key. Skipping.")
        return

    # Provision Sonarr
    sonarr_port_env = os.environ.get('SONARR_PORT')
    if sonarr_port_env:
        sonarr_port = int(sonarr_port_env)
        sonarr_api = extract_xml_key(f"/var/lib/sonarr-{sonarr_port}/config.xml")
        if sonarr_api:
            add_sabnzbd(sonarr_port, sonarr_api, 'tv', SAB_PORT, SAB_API)
            root = os.environ.get('SONARR_ROOT')
            if root: add_root_folder(sonarr_port, sonarr_api, root)
            add_prowlarr_app(PROWLARR_PORT, PROWLARR_API, "Sonarr", "Sonarr", sonarr_port, sonarr_api, [5000, 5030, 5040])
        else:
            print("Sonarr API key not found. Skipping Sonarr provisioning.")

    # Provision Radarr
    radarr_port_env = os.environ.get('RADARR_PORT')
    if radarr_port_env:
        radarr_port = int(radarr_port_env)
        radarr_api = extract_xml_key(f"/var/lib/radarr-{radarr_port}/config.xml")
        if radarr_api:
            add_sabnzbd(radarr_port, radarr_api, 'movies', SAB_PORT, SAB_API)
            root = os.environ.get('RADARR_ROOT')
            if root: add_root_folder(radarr_port, radarr_api, root)
            add_prowlarr_app(PROWLARR_PORT, PROWLARR_API, "Radarr", "Radarr", radarr_port, radarr_api, [2000, 2010, 2020])
        else:
            print("Radarr API key not found. Skipping Radarr provisioning.")

    # Finalize
    flag_file = os.environ.get('FLAG_FILE')
    if flag_file:
        with open(flag_file, 'w') as f:
            f.write("provisioned")
        print("Provisioning completed and flag written.")

if __name__ == "__main__":
    main()
