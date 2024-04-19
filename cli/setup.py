#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os

from setuptools import find_packages, setup

README = open(os.path.join(os.path.dirname(__file__), "README.md")).read()

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

# Read dependencies from requirements.txt
with open(os.path.join(os.path.dirname(__file__), "requirements.txt")) as f:
    requirements = f.read().splitlines()

version = "{{VERSION_PLACEHOLDER}}"

setup(
    name="syntho-cli",
    version=version,
    description="Syntho Stack Deployment CLI",
    long_description=README,
    long_description_content_type="text/markdown",
    url="https://github.com/syntho-ai/syntho-cli",
    download_url="https://github.com/syntho-ai/syntho-cli/tarball/%s" % version,
    author="Syntho B.V.",
    author_email="info@syntho.ai",
    license="MIT",
    keywords="syntho, synthetic data, deployment",
    packages=find_packages(),
    entry_points={"console_scripts": ["syntho-cli = cli.syntho_cli:cli"]},
    package_data={
        "cli": [
            "scripts/deploy-kubernetes.sh",
            "scripts/pre-requirements-kubernetes.sh",
            "scripts/utils.sh",
            "scripts/cleanup-kubernetes.sh",
            "scripts/get-k8s-cluster-context-name.sh",
            "scripts/configuration-questions.sh",
            "scripts/download-syntho-charts-release.sh",
            "scripts/major-pre-deployment-operations.sh",
            "scripts/deploy-ray-and-syntho-stack.sh",
            "scripts/k8s-deployment-preparation.sh",
            "scripts/cleanup-docker-compose.sh",
            "scripts/pre-requirements-dc.sh",
            "scripts/configuration-questions-dc.sh",
            "scripts/download-syntho-charts-release-dc.sh",
            "scripts/deploy-ray-and-syntho-stack-dc.sh",
        ]
    },
    include_package_data=True,
    install_requires=requirements,
)
