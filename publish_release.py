import os
import sys
import json
import base64
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

TOKEN = get_token()
OWNER = "ajwan14"
REPO = "Hyper-Charging-Release"
TAG = "v2.1-viva"
ZIP_PATH = r"D:\BACKUPS\Everythings\MAGISKMODULE\HYPER_CHARGING_PLUS_v2.1_viva_67W.zip"
ASSET_NAME = "HYPER_CHARGING_PLUS_2.1-viva_67W.zip"

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

def main():
    print(f"[*] Publishing release to {OWNER}/{REPO}...")

    # 1. Sync update.json
    sync_file_to_repo("update.json", "update.json", "update: sync Magisk update.json [skip ci]")

    # 2. Sync changelog.md
    if os.path.exists("changelog.md"):
        sync_file_to_repo("changelog.md", "changelog.md", "docs: sync changelog.md [skip ci]")

    # 3. Read changelog for release body
    release_body = "Hyper Charging+ v2.1-viva for Xiaomi Redmi Note 11 Pro 4G\n\nFeatures:\n- Specialized 67W Turbo Charge\n- Companion Notification Service\n- Anti-flapping thermal ladder\n- Game bypass support"
    if os.path.exists("changelog.md"):
        with open("changelog.md", "r", encoding="utf-8") as f:
            release_body = f.read()[:2000]

    # 4. Check existing release
    rel_url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/tags/{TAG}"
    existing_rel = api_request(rel_url)
    
    release_id = None
    upload_url_template = None

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
                del_res = api_request(del_url, method="DELETE")
                print(f"[+] Deleted old asset {ASSET_NAME} (ID: {asset_id})")
    else:
        # Create new release
        print(f"[*] Creating new release for tag {TAG}...")
        create_url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases"
        new_rel = api_request(create_url, method="POST", data={
            "tag_name": TAG,
            "name": f"Hyper Charging+ 2.1-viva [Redmi Note 11 Pro 4G viva]",
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

    # 5. Upload ZIP Asset
    if not os.path.exists(ZIP_PATH):
        print(f"[-] Zip file not found at: {ZIP_PATH}")
        sys.exit(1)

    clean_upload_url = upload_url_template.split("{")[0] + f"?name={ASSET_NAME}"
    print(f"[*] Uploading {ASSET_NAME} ({os.path.getsize(ZIP_PATH):,} bytes)...")

    with open(ZIP_PATH, "rb") as f:
        zip_bytes = f.read()

    upload_res = api_request(clean_upload_url, method="POST", data=zip_bytes, content_type="application/zip")
    if "_error" in upload_res and upload_res["_error"] not in (200, 201):
        print(f"[-] Upload failed: {upload_res['detail']}")
    else:
        download_url = upload_res.get("browser_download_url")
        print(f"[+] SUCCESS! Asset uploaded: {download_url}")
        print(f"[+] Auto-update JSON is live at: https://raw.githubusercontent.com/{OWNER}/{REPO}/main/update.json")
        print("\nAll tasks finished. Magisk in-app auto-update is active!")

if __name__ == "__main__":
    main()
