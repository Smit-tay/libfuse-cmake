# CMake developer team in Kitware Inc provides APT repositiory. It allows you to install latest CMake via apt-get.

#If you are using a minimal Ubuntu image or a Docker image, you may need to install the following packages:

sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates gnupg \
                         software-properties-common wget

# Obtain a copy of our signing key:

wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -

#Add the repository to your sources list and update.

#For Ubuntu Bionic Beaver (18.04):
#sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'
#sudo apt-get update

#For Ubuntu Xenial Xerus (16.04):
sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ xenial main'
sudo apt-get update

#Now call

sudo apt-get install cmake

# Reference: https://stackoverflow.com/questions/49859457/how-to-reinstall-the-latest-cmake-version
