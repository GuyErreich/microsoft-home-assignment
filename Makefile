.PHONY: key copy connect check-env-%

VAULT_NAME ?= myPersonalKeyVault2
SSH_KEY ?= ~/.ssh/microsoft_test
SKIP_FINGERPRINT = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
VM_USER = azureuser

INIT_SCRIPT = sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 && \
               sudo update-alternatives --set python3 /usr/bin/python3.6 && \
               sudo apt-get update && \
               sudo apt install -y make

key:
	@if [ ! -f "${SSH_KEY}" ]; then \
		echo "Fetching SSH key from Azure Key Vault..."; \
		az keyvault secret show --name mySSHKey --vault-name ${VAULT_NAME} --query value -o tsv > ${SSH_KEY}; \
		sudo chmod 600 ${SSH_KEY}; \
	else \
		echo "SSH key already exists."; \
	fi

copy: key check-env-VM_IP
	scp ${SKIP_FINGERPRINT} -r -i ${SSH_KEY} ./server ${VM_USER}@${VM_IP}:/home/${VM_USER}/

init: copy check-env-VM_IP
	ssh ${SKIP_FINGERPRINT} -i ${SSH_KEY} ${VM_USER}@${VM_IP} "${INIT_SCRIPT}"

connect: init check-env-VM_IP
	ssh ${SKIP_FINGERPRINT} -i ${SSH_KEY} ${VM_USER}@${VM_IP}

run:
	ssh ${SKIP_FINGERPRINT} -i ${SSH_KEY} ${VM_USER}@${VM_IP} "${COMMAND}"

check-env-%:
	@if [ -z "$($*)" ]; then \
		echo "Error: $* is not set"; \
		exit 1; \
	fi

