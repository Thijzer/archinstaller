



### testing
docker build -t archinstaller .
docker run --rm -v $(pwd):/workdir --privileged=true archinstaller:latest /bin/bash -x build.sh

## TODO
- /etx/fstab for .img
