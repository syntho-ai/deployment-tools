#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os
from setuptools import setup, find_packages

README = open(os.path.join(os.path.dirname(__file__), "README.md")).read()

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

version = "0.1.0"

setup(
    name="syntho-cli",
    version=version,
    description="Syntho Stack Deployment CLI",
    long_description=README,
    url="https://github.com/syntho-ai/syntho-cli",
    download_url="https://github.com/syntho-ai/syntho-cli/tarball/%s" % version,
    author="Baran Bartu Demirci",
    author_email="bbartu.demirci@gmail.com",
    license="MIT",
    keywords="ray, syntho, synthetic data",
    packages=find_packages(),
    entry_points={
        "console_scripts": ["syntho-cli = cli.syntho_cli:cli"]
    },
    package_data={"cli": ["scripts/deploy-kubernetes.sh", "scripts/pre-requirements-kubernetes.sh",
                          "scripts/utils.sh", "scripts/cleanup-kubernetes.sh",
                          "scripts/get-k8s-cluster-context-name.sh",
                          "scripts/configuration-questions.sh",
                          "scripts/download-syntho-charts-release.sh",
                          "scripts/major-pre-deployment-operations.sh"]},
    include_package_data=True,
    install_requires=[
        "click==8.1.7",
        "pyyaml==6.0.1",
        "ipdb",
    ]
)
