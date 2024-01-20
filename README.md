#  BP-GIT-LEAKS-STEP

Gitleaks is a SAST tool for detecting and preventing hardcoded secrets like passwords, api keys, and tokens in git repos.

## Setup
* Clone the code available at [ BP-GIT-LEAKS-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-LEAKS-STEP)

* Build the docker image
```
git submodule init
git submodule update
docker build -t registry.buildpiper.in/gitleaks:0.1 .
```

* Do local testing
```
docker run -it --rm -v $PWD:/src -e WORKSPACE=/ -e CODEBASE_DIR=src registry.buildpiper.in/gitleaks:0.1
```


## Debug
docker run -it --rm -v $PWD:/src --entrypoint bash registry.buildpiper.in/gitleaks:0.1 


#Cred scanning AWS_ACCESS_KEY_ID=ASIAIOSFODNN7EXAMPLE AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY