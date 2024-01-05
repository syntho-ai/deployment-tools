# [WIP] syntho-cli [WIP]

`syntho-cli` is a command line tool to deploy multiple components of `Syntho` when abstracting the
toil from the user.

## Development Setup

- `pip install . --no-cache`

## Helpful Commands

- `syntho-cli --help`

```

Usage: syntho-cli [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  k8s  Manages Kubernetes deployments

```

- `syntho-cli k8s --help`

```

Usage: syntho-cli k8s [OPTIONS] COMMAND [ARGS]...

  Manages Kubernetes deployments

Options:
  --help  Show this message and exit.

Commands:
  deployment   Deploys the Syntho Stack into the given cluster
  deployments  Shows existing deployments and their statuses
  destroy      Destroys a deployment and its components
  status       Shows the deployment status of the given deployment
```

- Deploy the entire stack into given k8s cluster: `syntho-cli k8s deployment --license-key a-key --registry-user a-user --registry-pwd a-pwd --kubeconfig $KUBECONFIG --version 0.1.0 --skip-configuration (optional)`
- List deployments: `syntho-cli k8s deployments`

```
- cluster_name: kind-syntho-development
  finished_at: '2023-11-17T08:14:52.668980'
  id: fb5c7d6708bfbf1011119c5fe835f84f
  started_at: '2023-11-17T08:13:39.981938'
  status: completed
  version: 0.1.0
```

- Deployment status for a specific deployment: `syntho-cli k8s status --deployment-id fb5c7d6708bfbf1011119c5fe835f84f`
- Destroying a deployment: `syntho-cli k8s destroy --deployment-id fb5c7d6708bfbf1011119c5fe835f84f`
