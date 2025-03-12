.PHONY: key copy connect check-env-%

VAULT_NAME ?= myPersonalKeyVault2
SSH_KEY ?= ~/.ssh/microsoft_test
SKIP_FINGERPRINT = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
SCRIPT_FOLDER ?= ./server
VM_USER = azureuser

STORAGE_A ?= mynewstoragesa1
STORAGE_B ?= mynewstoragesa2
CONTAINER_NAME ?= my_container
NUM_OF_BLOBS ?= 100


OS_ID := $(shell . /etc/os-release && echo $$ID)
OS_VERSION := $(shell . /etc/os-release && echo $$VERSION_ID)
INIT_SCRIPT = curl -sSL -O https://packages.microsoft.com/config/$$(. /etc/os-release && echo $$ID)/$$(. /etc/os-release && echo $$VERSION_ID)/packages-microsoft-prod.deb && \
				sudo dpkg -i packages-microsoft-prod.deb && \
				rm packages-microsoft-prod.deb && \
				sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 && \
				sudo update-alternatives --set python3 /usr/bin/python3.6 && \
				sudo apt-get update && \
				sudo apt install -y \
					make \
					python3.8 \
					python3.8-venv \
					python3.8-dev \
					python3-pip \
				sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2 && \
				sudo update-alternatives --set python3 /usr/bin/python3.8 && \
				python3 -m pip install --upgrade pip && \
				python3 -m pip install --user azure-identity azure-mgmt-storage azure-storage-blob argparse

key:
	@if [ ! -f "$(SSH_KEY)" ]; then \
		echo "Fetching SSH key from Azure Key Vault..."; \
		mkdir -p ~/.ssh && chmod 700 ~/.ssh; \
		az keyvault secret show --name mySSHKey --vault-name $(VAULT_NAME) --query value -o tsv > $(SSH_KEY); \
		if [ -s $(SSH_KEY) ]; then \
			chmod 600 $(SSH_KEY); \
		else \
			echo "Error: SSH key is empty or failed to download."; \
			rm -f $(SSH_KEY); \
			exit 1; \
		fi; \
	else \
		echo "SSH key already exists."; \
	fi

copy: key check-env-VM_IP
	scp $(SKIP_FINGERPRINT) -r -i $(SSH_KEY) $(SCRIPT_FOLDER) $(VM_USER)@$(VM_IP):/home/$(VM_USER)/

init: copy check-env-VM_IP
	ssh $(SKIP_FINGERPRINT) -i $(SSH_KEY) $(VM_USER)@$(VM_IP) "$(INIT_SCRIPT)"

connect: check-env-VM_IP
	ssh $(SKIP_FINGERPRINT) -i $(SSH_KEY) $(VM_USER)@$(VM_IP) $(CMD)

populate:
	make connect CMD="cd $(SCRIPT_FOLDER) && python3 ./blob_transfer.py --storage-a '$(STORAGE_A)' --storage-b '$(STORAGE_B)' --container '$(CONTAINER_NAME)' --num-blobs $(NUM_OF_BLOBS)"

check-env-%:
	@if [ -z "$($*)" ]; then \
		echo "Error: $* is not set"; \
		exit 1; \
	fi

