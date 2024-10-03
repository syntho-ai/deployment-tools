import requests

# from requests.auth import HTTPBasicAuth


# def fetch_releases():
#     url = "https://api.github.com/repos/syntho-ai/deployment-tools/releases"
#     auth = HTTPBasicAuth("baranbartu", "************")
#     response = requests.get(url, auth=auth, timeout=10)
#     if response.status_code == 200:
#         return response.json()
#     else:
#         raise Exception(f"Failed to fetch releases: {response.status_code}")


def fetch_releases():
    url = "https://api.github.com/repos/syntho-ai/deployment-tools/releases"
    response = requests.get(url, timeout=10)
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to fetch releases: {response.status_code}")


def get_releases(with_compatibility=None):
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

    if with_compatibility:
        major_ver, _, _ = with_compatibility.split(".")
        compatible_releases = list(filter(lambda r: r["name"].startswith(major_ver), releases))
        releases = compatible_releases

    return releases
