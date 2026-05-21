#!/bin/bash -x

set -e


cmake -G "Unix Makefiles" -DOPTION_BUILD_UTILS=ON -DOPTION_BUILD_EXAMPLES=ON -DCMAKE_INSTALL_PREFIX=${PREFIX_DIR} -DCMAKE_BUILD_TYPE=Debug "${SOURCE_DIR}" 
make
    
sudo chown root:root util/fusermount3
sudo chmod 4755 util/fusermount3

pytest -v --maxfail=1 --log-level=DEBUG --log-cli-level=DEBUG test/



