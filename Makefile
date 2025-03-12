.PHONY: key copy init connect populate check-env-%

WORKDIR = /home/$(VM_USER)

VAULT_NAME ?= myPersonalKeyVault2
SSH_KEY ?= ~/.ssh/microsoft_test
SKIP_FINGERPRINT = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
SCRIPT_FOLDER ?= server
VM_USER = azureuser

STORAGE_A ?= mynewstoragesa1
STORAGE_B ?= mynewstoragesa2
CONTAINER_NAME ?= my-container
NUM_OF_BLOBS ?= 100

VENV_PATH = $(WORKDIR)/.venv
VENV_ACTIVATE = $(VENV_PATH)/bin/activate
INIT_SCRIPT = 'sudo apt install -y python3.12-venv && \
				python3 -m venv $(VENV_PATH) && \
				source $(VENV_ACTIVATE) && \
				pip install --upgrade pip && \
				pip install azure-identity azure-storage-blob argparse'
				

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
	scp $(SKIP_FINGERPRINT) -r -i $(SSH_KEY) $(SCRIPT_FOLDER) $(VM_USER)@$(VM_IP):$(WORKDIR)

init: copy check-env-VM_IP
	ssh $(SKIP_FINGERPRINT) -i $(SSH_KEY) $(VM_USER)@$(VM_IP) $(INIT_SCRIPT)

connect: check-env-VM_IP
	ssh $(SKIP_FINGERPRINT) -i $(SSH_KEY) $(VM_USER)@$(VM_IP) $(CMD)

populate:
	make connect CMD='$(VENV_PATH)/bin/python $(WORKDIR)/$(SCRIPT_FOLDER)/blob_transfer.py --storage-a "$(STORAGE_A)" --storage-b "$(STORAGE_B)" --container "$(CONTAINER_NAME)" --num-blobs $(NUM_OF_BLOBS)'
check-env-%:
	@if [ -z "$($*)" ]; then \
		echo "Error: $* is not set"; \
		exit 1; \
	fi

