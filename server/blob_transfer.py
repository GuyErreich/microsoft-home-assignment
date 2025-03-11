#!/usr/bin/env python3

import os
import argparse
import logging
import time
import tempfile
import shutil
import subprocess
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient, generate_blob_sas, generate_container_sas, BlobSasPermissions
from azure.identity import DefaultAzureCredential
from datetime import datetime, timedelta

# Configure logging
def configure_logging(debug):
    log_level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[logging.StreamHandler()]
    )
    logger = logging.getLogger("azure")
    if not debug:
        logger.setLevel(logging.WARNING)  # Suppress detailed Azure SDK logs unless debug mode is enabled
    return logging.getLogger(__name__)

def az_login():
    """Ensure Azure is authenticated using Managed Identity."""
    logger.info("Logging into Azure with Managed Identity")
    subprocess.run(["az", "login", "--identity"], check=True)

def get_blob_service_client(storage_account):
    """Create a BlobServiceClient using DefaultAzureCredential for authentication."""
    account_url = f"https://{storage_account}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    return BlobServiceClient(account_url=account_url, credential=credential)

def get_storage_account_key(storage_account):
    """Retrieve the storage account key using Azure CLI."""
    logger.info(f"Retrieving storage account key for {storage_account}")
    try:
        command = ["az", "storage", "account", "keys", "list",
                   "--account-name", storage_account,
                   "--query", "[0].value",
                   "--output", "tsv"]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logger.error("Failed to retrieve storage account key")
        raise Exception("Error retrieving storage account key") from e

def ensure_container_exists(storage_account, container_name):
    """Ensure a container exists in the storage account."""
    logger.info(f"Checking if container '{container_name}' exists in {storage_account}")
    client = get_blob_service_client(storage_account)
    container_client = client.get_container_client(container_name)
    if not container_client.exists():
        logger.info(f"Creating container '{container_name}' in {storage_account}")
        container_client.create_container()
        logger.info(f"Container '{container_name}' created.")

def generate_sas_token(storage_account, container_name):
    """Generate a SAS token for a blob using the storage account key."""
    account_key = get_storage_account_key(storage_account)
    sas_token = generate_container_sas(
        account_name=storage_account,
        container_name=container_name,
        permission=BlobSasPermissions(read=True),
        expiry=datetime.utcnow() + timedelta(hours=1),  # Token valid for 1 hour
        account_key=account_key  # Use storage account key for SAS generation
    )

    return sas_token

def upload_blobs(storage_account, container_name, local_path, num_blobs):
    """Upload blobs to storage account using Azure SDK."""
    logger.info(f"Starting upload process for {num_blobs} blobs to {storage_account}")
    ensure_container_exists(storage_account, container_name)
    client = get_blob_service_client(storage_account)
    container_client = client.get_container_client(container_name)
    blob_names = []

    for i in range(1, num_blobs + 1):
        blob_name = f"blob{i}.txt"
        file_path = os.path.join(local_path, blob_name)
        with open(file_path, "w") as f:
            f.write(f"This is blob file {i}")
        logger.info(f"Uploading blob: {blob_name} to {storage_account}/{container_name}")
        blob_client = container_client.get_blob_client(blob_name)
        with open(file_path, "rb") as data:
            blob_client.upload_blob(data, overwrite=True)
        logger.info(f"Successfully uploaded blob: {blob_name}")
        blob_names.append(blob_name)

    return blob_names

def copy_blobs_with_sdk(source_storage, dest_storage, container_name, blob_names):
    """Copy blobs between storage accounts using Azure SDK with a per-blob SAS token."""
    logger.info(f"Starting blob copy from {source_storage} to {dest_storage}")
    ensure_container_exists(dest_storage, container_name)
    dest_client = get_blob_service_client(dest_storage)
    sas_token = generate_sas_token(source_storage, container_name)
    
    for blob_name in blob_names:
        source_blob_url = f"https://{source_storage}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
        logger.info(f"Copying {blob_name} from {source_storage} to {dest_storage} using SAS token")
        dest_container_client = dest_client.get_container_client(container_name)
        dest_blob_client = dest_container_client.get_blob_client(blob_name)
        copy_operation = dest_blob_client.start_copy_from_url(source_blob_url)
        copy_id = copy_operation['copy_id']
        
        # Check copy status
        while True:
            properties = dest_blob_client.get_blob_properties()
            copy_status = properties.copy.status
            if copy_status.lower() == 'success':
                logger.info(f"Successfully copied {blob_name}")
                break
            elif copy_status.lower() == 'failed':
                logger.error(f"Failed to copy {blob_name}")
                break
            logger.debug(f"Copy of {blob_name} is still in progress (status: {copy_status}), waiting...")
            time.sleep(2)

def main():
    """Main function to parse arguments and execute operations."""
    parser = argparse.ArgumentParser(description="Upload and copy blobs between Azure Storage Accounts using Azure SDK.")
    parser.add_argument("--storage-a", required=True, help="Source storage account name")
    parser.add_argument("--storage-b", required=True, help="Destination storage account name")
    parser.add_argument("--container", required=True, help="Storage container name")
    parser.add_argument("--num-blobs", type=int, default=5, help="Number of blobs to process")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = parser.parse_args()
    
    global logger
    logger = configure_logging(args.debug)
    az_login()
    temp_dir = tempfile.mkdtemp()
    try:
        blob_names = upload_blobs(args.storage_a, args.container, temp_dir, args.num_blobs)
        copy_blobs_with_sdk(args.storage_a, args.storage_b, args.container, blob_names)
        logger.info("Blob transfer process completed successfully")
        return 0
    except Exception as e:
        logger.error(f"Error during blob transfer: {str(e)}")
        return 1
    finally:
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    exit(main())
