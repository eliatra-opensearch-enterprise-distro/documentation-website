---
layout: default
title: Cloud Lock - Encryption at Rest
nav_order: 1000
has_children: false
has_toc: false
redirect_from:
  - /security/encryption-at-rest/index/
  - /security-plugin/encryption-at-rest/index/
---

# Cloud Lock - Encryption at Rest for OpenSearch
**Introduced ee2**
{: .label .label-purple }

---

<details closed markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

Eliatra Cloud Lock provides encryption at rest for OpenSearch indices and snapshots – encrypting all your OpenSearch data that resides on disk. 

It is the missing piece to regain complete control over your data in OpenSearch deployments, especially in public clouds. Eliatra Cloud Lock can also be used in private clouds or on-premises installations to protect your data at rest.


## Enable Cloud Lock:

1. Download [Cloud Lock Control Tool (clctl)](https://eliatra.com/downloads/) and unpack it

2. Create a new cluster key pair on a client machine

   This is typically done by a system administrator and is only necessary once per cluster. You can use tools like openssl to generate the key pair, or simply use earctl like:
   
   ```sh
   clctl.sh create-cluster-keypair

   Created a new RSA key pair with UUID <uuid>
   Public key will be stored in public_cluster_key_<uuid>.pubkey
   Public key config template will be stored in opensearch_yaml_<uuid>.yml
   Secret key will be stored in secret_cluster_key_<uuid>.seckey
   ```

   This key pair needs to be backed up in a safe location. If keys are lost, it is not possible to decrypt the data stored in encrypted indices on this cluster.

3. Add the following lines to `opensearch.yml` on each node:

   ```yml
   eliatra.cloud_lock.enabled: true
   eliatra.cloud_lock.public_cluster_key: MIICIjAN...EAAQ==
   ```

   The `<public key>` can be found in the `public_cluster_key_<uuid>.pubkey` file. 
   There is also a “copy and paste” ready variant in `opensearch_yaml_<uuid>.yml`.

4. Restart each node.
5. Initialize the Cloud Lock

   This needs only be done once after installing the plugin, or after a full cluster restart. 
   It is usually performed by a system administrator from a client machine:

   ```sh
   clctl.sh initialize-cluster -h osnode.company.com -p 9200 --pk-file secret_cluster_key_<uuid>.seckey

   Cluster initialized
   ```

## Create an Encrypted Index

Creating an `encrypted index` is the same as creating any other index:

```sh
curl "https://osnode.company.com:9200/my_encrypted_index?pretty" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "encryption_enabled": true,
    "store.type": "encrypted",
    ...
    ...
  },
  "mappings": {
      "properties": {
        "_encrypted_tl_content": {
          "type": "binary"
        },
      ...
      ...
  }
}
'
```

This curl command creates an encrypted index named `my_encrypted_index`. There is nothing special about it except two settings and one mapping:

- The index settings `encryption_enable: true` and `store.type: encrypted` defines this index as an encrypted index.
- The mapping `_encrypted_tl_content` with type `binary` is required and only used internally, as explained above.

After the index `my_encrypted_index` was created, it can be used to index and search data like any other index, but its contents are never stored in plaintext on disk. To list all your encrypted indices, use earctl with the list-encrypted-indices command:

```sh
$ clctl.sh -h osnode.company.com -p 9200 list-encrypted-indices

my_encrypted_index
my_other_encrypted_index
```

## Create and Restore an Encrypted Snapshot

First, register the encrypted snapshot repository. This delegates to a previously registered repository like S3 and needs only be done once:

```sh
curl "https://osnode.company.com:9200/_snapshot/my_encrypted_s3_backup?pretty" -H 'Content-Type: application/json' -d '
{
  "type": "encrypted",
  "settings": {
    "delegate": "my_s3_backup"
  }
}'

```

You can now create or restore snapshots as usual, referencing the encrypted snapshot repository `my_encrypted_s3_backup` like:

```sh
_snapshot/my_encrypted_s3_backup/snapshot_1

_snapshot/my_encrypted_s3_backup/snapshot_1/_restore
```


## Simplify With Index Templates

When you need to create a lot of encrypted indices, we recommend using an index template for that:

```sh
curl "https://osnode.company.com:9200/_index_template/encrypted_index_template?pretty" -H 'Content-Type: application/json' -d '
{
  "index_patterns": ["*encrypted*","*dashboards_sample*"],
  "priority": 300,
  "template": {
    "mappings": {
      "properties": {
        "_encrypted_tl_content": {
          "type": "binary"
        }
      }
    },
    "settings":{
      "encryption_enabled": true,
      "number_of_shards": 3,
      "number_of_replicas": 2,
      "store.type": "encrypted"
    }
  }
}'
```

This will create indices whose name match `encrypted` or `dashboards_sample` as encrypted indices.

## How it Works

All data which resides in an encrypted index is stored encrypted on disk. No one without the correct decryption key can read or modify the data of encrypted indices. The decryption key is only held in memory on the cluster nodes and never stored on the disk of the server.

In addition to the encrypted indices feature, the plugin also provides the functionality to encrypt snapshots, which are typically used to back up your data. An encrypted snapshot can contain encrypted and non-encrypted indices and is therefore independent of using encrypted indices.
So, if you have only regular non-encrypted indices in your cluster, and you want to snapshot and store them safely and encrypted on S3 or NFS, then encrypted snapshots are for you.

## Preconditions and Limitations

There are only a few preconditions and limitations with encrypted indices:

- Realtime get actions are executed as non-realtime actions
- There is a slight performance impact when indexing and searching in encrypted indices
- The mapping must include a metadata field _encrypted_tl_content of type binary. This field will never appear in any search results, and you can otherwise completely ignore it
- After a full cluster restart (shutting down all nodes at once), which happens rarely, the plugin must be initialized again before encrypted indices can be accessed

Apart from the limitations mentioned above, an encrypted index works like any other index and supports all queries and mappings.