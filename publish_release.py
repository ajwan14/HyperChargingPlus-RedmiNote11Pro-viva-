import os
import sys
import json
import base64
import zipfile
import urllib.request
import urllib.error

def get_token():
    if "GITHUB_TOKEN" in os.environ and os.environ["GITHUB_TOKEN"]:
        return os.environ["GITHUB_TOKEN"]
    token_file = os.path.join(os.path.dirname(__file__), ".github_token")
    if os.path.exists(token_file):
        with open(token_file, "r") as f:
            return f.read().strip()
    return ""

def get_module_prop():
    props = {}
    prop_path = os.path.join(os.path.dirname(__file__), "module.prop")
    if os.path.exists(prop_path):
        with open(prop_path, "r", encoding="utf-8") as f:
            for line in f:
                if "=" in line and not line.startswith("#"):
                    k, v = line.strip().split("=", 1)
                    props[k] = v
    return props

TOKEN = get_token()
OWNER = "ajwan14"
REPO = "Hyper-Charging-Release"

PROPS = get_module_prop()
VERSION = PROPS.get("version", "2.1.1-viva")
VERSION_CODE = int(PROPS.get("versionCode", 22))
TAG = f"v{VERSION}"
ASSET_NAME = f"HYPER_CHARGING_PLUS_{VERSION}_67W.zip"

HEADERS = {
    "Authorization": f"token {TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "HyperCharge-Release-Script"
}

def api_request(url, method="GET", data=None, content_type="application/json"):
    headers = dict(HEADERS)
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, headers=headers, method=method)
    if data is not None:
        if isinstance(data, dict):
            req.data = json.dumps(data).encode("utf-8")
        elif isinstance(data, (bytes, bytearray)):
            req.data = data
        elif isinstance(data, str):
            req.data = data.encode("utf-8")
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            return {"_error": e.code, "detail": json.loads(err_body)}
        except Exception:
            return {"_error": e.code, "detail": err_body}

def sync_file_to_repo(file_path, repo_path, commit_message):
    with open(file_path, "rb") as f:
        content_b64 = base64.b64encode(f.read()).decode("utf-8")
    
    check_url = f"https://api.github.com/repos/{OWNER}/{REPO}/contents/{repo_path}"
    existing = api_request(check_url)
    sha = None
    if isinstance(existing, dict) and "sha" in existing:
        sha = existing["sha"]

    payload = {
        "message": commit_message,
        "content": content_b64
    }
    if sha:
        payload["sha"] = sha

    put_url = f"https://api.github.com/repos/{OWNER}/{REPO}/contents/{repo_path}"
    res = api_request(put_url, method="PUT", data=payload)
    if "_error" in res and res["_error"] not in (200, 201):
        print(f"[-] Failed to sync {repo_path}: {res['detail']}")
    else:
        print(f"[+] Successfully synced {repo_path} to {OWNER}/{REPO}")

def build_zip(out_zip):
    print(f"[*] Packaging flashable zip: {out_zip}...")
    root_dir = os.path.dirname(os.path.abspath(__file__))
    items = [
        'META-INF', 'system', 'customize.sh', 'service.sh',
        'module.prop', 'system.prop', 'uninstall.sh', 'game_list.sh',
        'banner.png', 'changelog.md', 'README.md', 'LICENSE'
    ]
    with zipfile.ZipFile(out_zip, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for item in items:
            full_path = os.path.join(root_dir, item)
            if os.path.isdir(full_path):
                for dirpath, dirnames, filenames in os.walk(full_path):
                    for fn in filenames:
                        fp = os.path.join(dirpath, fn)
                        arcname = os.path.relpath(fp, root_dir).replace('\\', '/')
                        zinfo = zipfile.ZipInfo.from_file(fp, arcname)
                        if arcname.endswith('.sh') or 'update-binary' in arcname:
                            zinfo.external_attr = 0o100755 << 16
                        else:
                            zinfo.external_attr = 0o100644 << 16
                        with open(fp, 'rb') as f:
                            zf.writestr(zinfo, f.read())
            elif os.path.isfile(full_path):
                zinfo = zipfile.ZipInfo.from_file(full_path, item)
                if item.endswith('.sh'):
                    zinfo.external_attr = 0o100755 << 16
                else:
                    zinfo.external_attr = 0o100644 << 16
                with open(full_path, 'rb') as f:
                    zf.writestr(zinfo, f.read())
    print(f"[+] Zip built successfully ({os.path.getsize(out_zip):,} bytes)")

def main():
    print(f"[*] Preparing release {TAG} (versionCode: {VERSION_CODE}) for {OWNER}/{REPO}...")

    # 1. Generate update.json
    update_data = {
        "version": VERSION,
        "versionCode": VERSION_CODE,
        "zipUrl": f"https://github.com/{OWNER}/{REPO}/releases/download/{TAG}/{ASSET_NAME}",
        "changelog": f"https://raw.githubusercontent.com/{OWNER}/{REPO}/main/changelog.md"
    }
    with open("update.json", "w", encoding="utf-8") as f:
        json.dump(update_data, f, indent=2)
    print(f"[+] Generated update.json: version {VERSION}, code {VERSION_CODE}")

    # 2. Build ZIP file
    out_zip = os.path.join(r"D:\BACKUPS\Everythings\MAGISKMODULE", ASSET_NAME)
    build_zip(out_zip)

    # 3. Also keep a copy for backward compatibility
    legacy_zip = os.path.join(r"D:\BACKUPS\Everythings\MAGISKMODULE", "HYPER_CHARGING_PLUS_v2.1_viva_67W.zip")
    with open(out_zip, "rb") as src, open(legacy_zip, "wb") as dst:
        dst.write(src.read())

    # 4. Sync update.json
    sync_file_to_repo("update.json", "update.json", f"update: release {VERSION} (code {VERSION_CODE}) [skip ci]")

    # 5. Sync changelog.md
    if os.path.exists("changelog.md"):
        sync_file_to_repo("changelog.md", "changelog.md", f"docs: update changelog for {VERSION} [skip ci]")

    # 6. Check existing release
    rel_url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/tags/{TAG}"
    existing_rel = api_request(rel_url)
    
    release_id = None
    upload_url_template = None

    release_body = f"Hyper Charging+ {VERSION} for Xiaomi Redmi Note 11 Pro 4G viva\n\n- Fix notification persistence on charger disconnect\n- Higher thermal ceiling 6.5A 67W Turbo\n- Instant ACTION_POWER_DISCONNECTED listener"
    if os.path.exists("changelog.md"):
        with open("changelog.md", "r", encoding="utf-8") as f:
            release_body = f.read()[:2000]

    if isinstance(existing_rel, dict) and "id" in existing_rel:
        release_id = existing_rel["id"]
        upload_url_template = existing_rel["upload_url"]
        print(f"[!] Found existing release {TAG} (ID: {release_id}). Overwriting assets...")

        # Delete existing asset if it exists
        assets = existing_rel.get("assets", [])
        for asset in assets:
            if asset.get("name") == ASSET_NAME:
                asset_id = asset["id"]
                del_url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/assets/{asset_id}"
                api_request(del_url, method="DELETE")
                print(f"[+] Deleted old asset {ASSET_NAME} (ID: {asset_id})")
    else:
        # Create new release
        print(f"[*] Creating new release for tag {TAG}...")
        create_url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases"
        new_rel = api_request(create_url, method="POST", data={
            "tag_name": TAG,
            "name": f"Hyper Charging+ {VERSION} [Redmi Note 11 Pro 4G viva]",
            "body": release_body,
            "draft": False,
            "prerelease": False
        })
        if "_error" in new_rel:
            print(f"[-] Failed to create release: {new_rel['detail']}")
            sys.exit(1)
        release_id = new_rel["id"]
        upload_url_template = new_rel["upload_url"]
        print(f"[+] Created release {TAG} (ID: {release_id})")

    # 7. Upload ZIP Asset
    clean_upload_url = upload_url_template.split("{")[0] + f"?name={ASSET_NAME}"
    print(f"[*] Uploading {ASSET_NAME} ({os.path.getsize(out_zip):,} bytes)...")

    with open(out_zip, "rb") as f:
        zip_bytes = f.read()

    upload_res = api_request(clean_upload_url, method="POST", data=zip_bytes, content_type="application/zip")
    if "_error" in upload_res and upload_res["_error"] not in (200, 201):
        print(f"[-] Upload failed: {upload_res['detail']}")
    else:
        download_url = upload_res.get("browser_download_url")
        print(f"[+] SUCCESS! Asset uploaded: {download_url}")
        print(f"[+] Auto-update JSON is live: https://raw.githubusercontent.com/{OWNER}/{REPO}/main/update.json")
        print(f"\nVersion bump to {VERSION} (code {VERSION_CODE}) complete!")

if __name__ == "__main__":
    main()
