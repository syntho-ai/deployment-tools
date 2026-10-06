# Docker Compose deployment of Syntho Application

This folder contains a `docker compose` file that can be used to deploy the Syntho
Application using Docker Compose.
For more information on how to use Syntho with Docker Compose, please refer to
the [Syntho documentation](https://docs.syntho.ai/deploy-syntho/deploy-syntho-using-docker).

## Prerequisites

- Docker and Docker Compose installed on the machine
- Access to the Syntho Container Registry
- License key from Syntho
- Minimum 32GB of RAM and 8 CPUs on the machine

## Configuring the application

Adjust the following variables in the `.env` file as described below:

- `APPLICATION_VERSION`: The version of the Syntho Application to deploy. Consult Syntho
  documentation for the latest version.
- `LICENSE_KEY`: The license key provided by Syntho.
- `SECRET_KEY`: The secret key provided by Syntho.
- `USER_EMAIL` and `USER_PASSWORD`: The credentials for the initial admin account. This
  needs to be defined by the user.

> Note: Is necessary to restart the application after changing the `.env` file.

### Optional configuration

#### Domain and port configuration

In case the application needs to run under a specific domain or IP other than `localhost`,
the changes described below need to be made.

Change the following variables in `.env` to the right domain or IP address:

- `FRONTEND_DOMAIN`: will be either `localhost`, the IP or domain of the machine running
  the Syntho Application

Furthermore, if the application is using a secure domain (https), the following variable
needs to be set:

- `FRONTEND_PROTOCOL`: should be set to `https`
- `SECURE_COOKIES`: should be set to `True`

Finally, if the application needs to run under a specific port other than `3000`, change
the following variable in `.env`:

- `FRONTEND_PORT`: will be either `3000`, the port of the machine running the Syntho
  Application.
- `BACKEND_PORT`: will be either `8000`, the port of the machine running the Syntho
  Application.

#### AI engine resources configuration

The following variables can be added to the `.env` file if needed:

- `RAY_MEMORY`: it defaults to `32G` which is the minimum amount of memory required to run
  the application.
- `RAY_CPUS`: it defaults to `8` which is the minimum number of CPUs required to run the
  application.

#### Redis resources and persistence

The queue stores AOF (Append Only File) data in `queue-data:/data`, separate from application `data-storage`.
It always uses AOF, `appendfsync everysec`, fsync during rewrites, and `noeviction`.
Set these optional `.env` variables (also included in the environment sample):

| Variable | Default | Purpose |
| --- | --- | --- |
| `REDIS_MAXMEMORY` | `512mb` | Redis data memory budget, not total RSS |
| `REDIS_MEMORY_LIMIT` | `2g` | Container memory limit including rewrite headroom |
| `REDIS_MEMORY_REQUEST` | `512m` | Memory reservation (512MiB) |
| `REDIS_CPU_LIMIT` | `1` | CPU limit in cores |
| `REDIS_CPU_REQUEST` | `0.1` | CPU reservation in cores (100m) |
| `REDIS_START_PERIOD` | `30m` | Healthcheck startup grace for AOF loading |

These are starting defaults, not workload sizing. Reservations and CPU settings can be adjusted in the generated `.env`.
Keep reservations at or below limits. Allow additional host RAM and disk space for
AOF rewrites. Health checks require `PONG`, not just a successful redis-cli exit code;
increase startup grace if the dataset needs longer to load. Compose health checks
mark health status; they do not themselves restart unhealthy containers. The queue
uses `restart: unless-stopped` to recover after the process exits or Docker daemon
restarts, unless intentionally stopped; Redis reloads AOF from the retained volume.

Recreate the queue container to apply command/resource changes, reusing the volume.
Do not run `down -v` unless intentional data deletion is acceptable. Read the
[durability and upgrade procedure](../README.md#redis-durability-and-upgrades) before
restarting an existing nonpersistent queue or switching to the new named volume.

## Running the application

Run the following command to start the application:

```shell
docker compose up -d
```

Open the application in a browser using the URL
`FRONTEND_PROTOCOL://FRONTEND_DOMAIN:FRONTEND_PORT`.

Default to [localhost:3000](http://localhost:3000)
