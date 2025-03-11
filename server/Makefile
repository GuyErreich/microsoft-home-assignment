# IMPORTANT: Install make on the server copy this Makefile and
# 			use it to init the system for it to run the python script


.PHONY: init run

init:
	curl -sSL -O https://packages.microsoft.com/config/$(. /etc/os-release && echo ${ID})/$(. /etc/os-release && echo $VERSION_ID)/packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	rm packages-microsoft-prod.deb
	sudo apt-get update
	sudo apt-get install -y python3.8 python3.8-venv python3.8-dev python3-pip azcopy
	sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2
	sudo update-alternatives --set python3 /usr/bin/python3.8 
	python3 -m pip install --upgrade pip
	python3 -m pip install --user azure-identity azure-mgmt-storage azure-storage-blob argparse

run:
	python3 ./blob_transfer.py --storage-a "mynewstoragesa1" --storage-b "mynewstoragesa2" --container "my-container" --num-blobs 100