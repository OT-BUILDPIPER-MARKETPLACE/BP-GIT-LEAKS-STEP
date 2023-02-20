#  BP-GIT-LEAKS-STEP

Gitleaks is a SAST tool for detecting and preventing hardcoded secrets like passwords, api keys, and tokens in git repos.

## Setup
* Clone the code available at [ BP-GIT-LEAKS-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-LEAKS-STEP.git)
* Build the docker image
```
git submodule init
git submodule update
docker build -t ot/gitleaks:0.1 .