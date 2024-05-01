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
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>


<!-- GETTING STARTED -->
## Getting Started

A few things have been implemented for this project:

- Pre-commit hooks in order to check your files

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

### Prerequisites

* Install `Python 12.*` and make sure it is the default one

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/syntho-ai/deployment-tools.git
   ```
2. Install [Poetry](https://python-poetry.org/docs/#installing-with-the-official-installer)
   ```sh
   curl -sSL https://install.python-poetry.org | python3 -
   ```
3. Install Python Packages in root
   ```sh
   poetry install --no-root
   ```
4. Run pre-commit install:
    ```sh
    pre-commit install
    ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

### Setting up Docker compose

*Add documentation*

_For more examples, please refer to the [Documentation](https://example.com)_

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Helm charts

*Add documentation*


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
