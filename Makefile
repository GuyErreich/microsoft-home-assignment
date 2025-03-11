.PHONY: key copy connect check-env-%

VAULT_NAME ?= myPersonalKeyVault2
SSH_KEY ?= ~/.ssh/microsoft_test

INIT_SCRIPT = sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 && \
	sudo update-alternatives --set python3 /usr/bin/python3.6 && \
	sudo apt-get update && \
	sudo apt install -y make

key:
	az keyvault secret show --name mySSHKey --vault-name ${VAULT_NAME} --query value -o tsv > ~/.ssh/microsoft_test
	sudo chmod 600 ~/.ssh/microsoft_test

copy: key check-env-VM_IP
	scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r -i ${SSH_KEY} ./server azureuser@${VM_IP}:/home/azureuser/

init: copy check-env-VM_IP
	ssh -i ${SSH_KEY} azureuser@${VM_IP} "${INIT_SCRIPT}"

connect: init check-env-VM_IP
	ssh -i ${SSH_KEY} azureuser@${VM_IP}

run:
	ssh -i ${SSH_KEY} azureuser@${VM_IP} "${COMMAND}"

check-env-%:
	@ if [ -z "$($*)" ]; then \
		echo "$* is not set"; \
		exit 1; \
	fi

