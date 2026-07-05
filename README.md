# tickdistill-commitment

Public integrity-commitment chain for TickDistill L2 order-flow capture.

This repository holds only cryptographic hashes: never signal data, formulas, or trading logic. Each day the capture service computes a Merkle root over that days captured files and appends a hash-linked record to digest/<venue>/<instrument>/digest_chain.jsonl, additionally timestamped with OpenTimestamps (https://opentimestamps.org/) for independent, public proof of when the data existed.

This proves the exact hash existed, unmodified, as of that timestamp: an auditable, tamper-evident record that capture history is not rewritten after the fact.

This repo is updated automatically by the capture box. No action required here.
