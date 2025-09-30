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

## Running the application

Run the following command to start the application:

```shell
docker compose up -d
```

Open the application in a browser using the URL
`FRONTEND_PROTOCOL://FRONTEND_DOMAIN:FRONTEND_PORT`.

Default to [localhost:3000](http://localhost:3000)

