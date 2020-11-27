


# provisions
docker build -t archinstaller .
docker run --rm -v $(pwd):/workdir --privileged=true archinstaller:latest

### testing
docker run --rm -v $(pwd):/workdir -w /workdir --privileged=true archlinux:latest /bin/bash -x /workdir/tests/build_test.sh

## TODO
- /etx/fstab for .img
