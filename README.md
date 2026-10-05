<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->


<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/syntho-ai/deployment-tools">
    <img src="https://www.syntho.ai/wp-content/uploads/2023/02/syntho_logo_horizontal.svg" alt="Logo" width="600" height="100">
  </a>

<h3 align="center">Syntho Deployment Tools</h3>

  <p align="center">
    Monorepo containing all deployment related tools: Deployment CLI, Helm Charts, Docker Compose files
    <br />
    <a href="https://docs.syntho.ai/"><strong>Explore the docs »</strong></a>
    <br />
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#usage">Usage</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#project-overview">Project Overview</a></li>
      </ul>
    </li>
    <li>
      <a href="#syntho-cli">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#releasing">Releasing</a><li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>


## Usage

### Docker Compose


_The Docker Compose documentation can be found in the Syntho [Documentation](https://docs.syntho.ai/deploy-syntho/deploy-syntho-using-docker)_

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Helm charts

_The Helm chart documentation can be found in the Syntho [Documentation](https://docs.syntho.ai/deploy-syntho/deploy-syntho-using-kubernetes)_

### Redis durability and upgrades

Both deployments default to one Redis primary, AOF persistence, `appendfsync everysec`,
`no-appendfsync-on-rewrite no`, and `maxmemory-policy noeviction`. The Redis image remains
`7.2-rc2`. This is **not HA**: restarts and node/storage outages interrupt queue availability.
Helm rejects `redis.replicaCount` other than `1`; its Service must not route writes to replicas.

AOF survives process/container restarts only when the same intact volume is reused.
`everysec` can lose roughly the last second of acknowledged writes on a crash; stalled
storage, hardware failures, or loss of the volume can cause greater loss. It is not a
backup or an exactly-once job guarantee. Helm allows `always` for more frequent fsync
at higher latency, and `no` for OS-managed flushing with a larger loss window. Disabling
`redis.persistence.appendonly` or enabling `noAppendfsyncOnRewrite` weakens durability.
The default keeps fsync active during rewrites.

`noeviction` protects queue keys from memory-pressure eviction, **not** from TTL expiry,
application deletion, or result-retention settings. At the memory budget Redis rejects
writes with OOM errors; producers may fail to enqueue tasks or record results. Monitor
queue depth, errors, memory, disk space, and AOF write/rewrite status, and tune capacity
and application retention deliberately rather than switching back to LRU eviction.

The 512mb data budget, 2GiB container limit, 512MiB memory request, 100m CPU request,
one-core CPU limit, and Helm 1Gi data PVC are starting defaults,
**not sized for a customer workload**. The 1Gi storage default preserves legacy
claim templates on upgrades. For fresh production installs, configure storage for
measured AOF growth/rewrite needs (for example, choose 10Gi); existing PVCs require
separate expansion, not just changed Helm values.
Redis `maxmemory` is not total process memory: fragmentation, clients, persistence buffers, and
copy-on-write during AOF/RDB rewrites require additional RAM. A rewrite may approach
twice the dataset's memory, plus overhead; measure peak RSS and adjust container limits
and requests with headroom. Keep requests at or below limits. AOF can grow much larger
than the in-memory dataset; provision room for the old AOF, new rewritten files,
concurrent writes, and RDB snapshots, and monitor disk latency as well as free space.

Compose uses a dedicated `queue-data` named volume at `/data`; Helm reuses its existing
`redis-data` PVC at `/data` and retains the separate `redis-claim` configuration PVC.
No new application shared volume is introduced. A Compose local volume survives
container replacement, but does not follow a deployment to another host. A Kubernetes
PVC survives pod replacement, but recovery on another node depends on the provisioner
and volume topology: local-path/local PV storage is node-bound, unlike suitably
reattachable network/block storage. Volume deletion, `docker compose down -v`,
PV reclaim policies, or host/node disk loss can destroy data. Protect and back up the
volumes independently.

**Before upgrading an existing non-AOF Redis**, stop new job submissions and pause
producers/schedulers. Let workers finish or safely drain queued/in-flight work according
to the application's acknowledgement/retry behavior; account for beat schedules,
results, and other Redis databases too. Do not blindly restart the old Redis: this
change cannot retroactively persist its in-memory queues. If state must be retained,
enable AOF on the running old instance (`CONFIG SET appendonly yes`) and wait for the
initial rewrite to finish successfully. Check `INFO persistence` for
`aof_rewrite_in_progress:0`, `aof_rewrite_scheduled:0`, successful
`aof_last_bgrewrite_status`/`aof_last_write_status`, and no pending fsyncs, then quiesce
all clients, cleanly stop Redis, and back up its complete data directory.

For Compose, the new named volume is initially empty: migrate the stopped instance's
data directory (including the Redis 7 multipart AOF directory/manifest and any RDB)
to `queue-data`, preserving ownership, before starting with the new configuration.
Do not delete the old container/anonymous volume until recovery is verified.
For Helm, retain the same bound PVCs and release/namespace. Prepare persistent state
before the config checksum triggers a rollout; changing Redis config intentionally
restarts the pod. Restore/verify retained keys and queue counts and Redis persistence
health before resuming producers and workers. Protect against duplicate/retried jobs;
if uncertain, use a maintenance window and a tested backup/restore procedure.

See [Compose settings](docker-compose/README.md#redis-resources-and-persistence) and
[Helm settings and PVC upgrades](helm/syntho-ui/README.md#redis-configuration).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

A few things have been implemented for this project:

- Pre-commit hooks in order to check your files
- A VScode workspace file to correctly create VSCode workspaces
- The Docker Compose file and Helm charts to deploy the Syntho Application with
- The source code of the Syntho CLI (The deployment CLI for the Syntho Application)

### Project overview

```
deployment-tools
│   README.md
|
└───cli
|
└───docker-compose
│   └───config
│   └───postgres
|
└───helm
│   └───config
│   └───ray
│   └───syntho-ui

```
## Syntho CLI

### Prerequisites

* Install `Python 11.*` or higher and make sure it is the default one

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/syntho-ai/deployment-tools.git
   ```
2. Install [Poetry](https://python-poetry.org/docs/#installing-with-the-official-installer)
   ```sh
   curl -sSL https://install.python-poetry.org | python3 -
   ```
3. Install Python packages in root
   ```sh
   poetry install --no-root
   ```
4. Run pre-commit install:
    ```sh
    pre-commit install
    ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Releasing

This project uses [commitizen](https://commitizen-tools.github.io/commitizen/) to bump the version and create a new release. For every commit on main, we check whether a release can be created by seeing in any commits were made that either increase the patch, minor or major version. If that's the case, a Github release will be created with the new version and the changelog. After that, the Syntho CLI wheel will be uploaded to PyPI.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Syntho B.V. - info@syntho.ai

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/syntho-ai/deployment-tools.svg?style=for-the-badge
[contributors-url]: https://github.com/syntho-ai/deployment-tools/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/syntho-ai/deployment-tools.svg?style=for-the-badge
[forks-url]: https://github.com/syntho-ai/deployment-tools/network/members
[stars-shield]: https://img.shields.io/github/stars/syntho-ai/deployment-tools.svg?style=for-the-badge
[stars-url]: https://github.com/syntho-ai/deployment-tools/stargazers
[issues-shield]: https://img.shields.io/github/issues/syntho-ai/deployment-tools.svg?style=for-the-badge
[issues-url]: https://github.com/syntho-ai/deployment-tools/issues
[license-shield]: https://img.shields.io/github/license/syntho-ai/deployment-tools.svg?style=for-the-badge
[license-url]: https://github.com/syntho-ai/deployment-tools/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/linkedin_username
[product-screenshot]: images/demo_screenshot.png
[Next.js]: https://img.shields.io/badge/next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white
[Next-url]: https://nextjs.org/
[React.js]: https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB
[React-url]: https://reactjs.org/
[Vue.js]: https://img.shields.io/badge/Vue.js-35495E?style=for-the-badge&logo=vuedotjs&logoColor=4FC08D
[Vue-url]: https://vuejs.org/
[Angular.io]: https://img.shields.io/badge/Angular-DD0031?style=for-the-badge&logo=angular&logoColor=white
[Angular-url]: https://angular.io/
[Svelte.dev]: https://img.shields.io/badge/Svelte-4A4A55?style=for-the-badge&logo=svelte&logoColor=FF3E00
[Svelte-url]: https://svelte.dev/
[Laravel.com]: https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white
[Laravel-url]: https://laravel.com
[Bootstrap.com]: https://img.shields.io/badge/Bootstrap-563D7C?style=for-the-badge&logo=bootstrap&logoColor=white
[Bootstrap-url]: https://getbootstrap.com
[JQuery.com]: https://img.shields.io/badge/jQuery-0769AD?style=for-the-badge&logo=jquery&logoColor=white
[JQuery-url]: https://jquery.com
[Python.org]: https://img.shields.io/badge/Python-14354C?style=for-the-badge&logo=python&logoColor=white
[Python-url]: [https://www.python.org/]
[Django]: https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white
[Django-url]: https://www.djangoproject.com/
[Fastapi]: https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=FastAPI&logoColor=white
[Fastapi-url]: https://fastapi.tiangolo.com/
