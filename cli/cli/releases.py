import requests


def fetch_releases():
    url = "https://api.github.com/repos/syntho-ai/deployment-tools/releases"
    response = requests.get(url, timeout=10)
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to fetch releases: {response.status_code}")


def get_releases():
    releases = []
    raw_releases = fetch_releases()
    for raw_release in raw_releases:
        name = raw_release["name"]
        if name.startswith("syntho-cli"):
            continue

        asset_url = None
        for asset in raw_release["assets"]:
            if asset["name"].endswith(".tar.gz"):
                asset_url = asset["browser_download_url"]

        releases.append(
            {
                "name": name,
                "notes": raw_release["body"] if raw_release["body"] else "No release notes.",
                "published_at": raw_release["published_at"],
                "asset_url": asset_url,
            }
        )

        return releases
