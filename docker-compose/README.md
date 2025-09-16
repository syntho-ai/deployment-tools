# One node deployment setup for Docker Compose

## Prerequisites

- Installation of Docker engine
- Installation of Docker compose
- Ports 3000 and 8000 exposed in firewall/network
  - Port 3000 for accessing the UI
  - Port 8000 for accessing the Backend API

## Steps for minimal setup

- Clone repository to machine
- Use `docker login` to log into the Syntho Container Registry, or `docker load` to load images from files. See Syntho Documentation under `Deploy Syntho` -> `Introduction` -> `Access Docker images`
- Copy over `example.env` to `.env` using command `cp example.env .env`
- Adjust the following variables in `.env` for a minimal setup:
  - `LICENSE_KEY`: The license key provided by Syntho.
  - `ADMIN_USERNAME`, `ADMIN_EMAIL` and `ADMIN_PASSWORD`: the credentials for the admin account that can be used once the application is setup. The email and password will be needed to login.

The `.env` file contains the image tag latest for all images, which is a rolling tag. Please adjust the following image tags with the tags provided by the Syntho Team in order to pin them to a certain version:
  - `RAY_IMAGE`
  - `CORE_IMAGE`
  - `BACKEND_IMAGE`
  - `FRONTEND_IMAGE`

In order to access the Backend API correctly, the domain should be set. If the application is being accessed on the same machine that deploys it, `localhost` should be fine for this domain. If you're using a different machine on your network, the IP address or hostname should be used for the following variables:

- `FRONTEND_HOST`: this should include the port as well. If port 3000 is used for the frontend, and it can be accessed on the same machine, the value would be `localhost:3000`. If another machine on the same network needs to access the frontend, the value will be `<IP-of-deployed-machine>:3000`
- `FRONTEND_DOMAIN`: will be either `localhost` or the IP of the machine running the Syntho Application

After the adjustment of these variables, the `docker compose` file should be ready for deployment. Additional variables can be adjusted as well, which are described in the Syntho documentation under `Deploy Syntho` -> `Deploy Syntho using Docker` -> `Deploy Syntho Application`

### [Optional] Set Docker limits for Ray image

In this example, we've set a limit of 12 CPUs and 100G for the AI cluster part (Ray). This limit can be increased or decreased by adjusting the variables `RAY_CPUS` and `RAY_MEMORY` in `.env`

## Deployment

Once the variables have been adjusted in `.env`, this should provide a minimal working version of the Syntho Application. The command `docker compose up -d` can be used to spawn the application. After some time, you should be able to go to the application using the following URL: <hostname/ip-of-machine>:3000. If you're accessing the application from the same machine, localhost can be used ([localhost:3000](localhost:3000)).
