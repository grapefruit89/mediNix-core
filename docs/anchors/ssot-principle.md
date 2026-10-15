<!-- Vendored from https://llm-coding.github.io/Semantic-Anchors/anchor/ssot-principle (English original, anchors/ssot-principle.txt)
     Fetched: 2026-10-16 . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding
     Modification: none to the text below; only this wrapper header was added. -->

# SSOT (Single Source of Truth)

***Full Name***: Single Source of Truth

[discrete]
## **Core Concepts**:

***Conceptual principle***: Focuses on establishing trust and authority for data

***Authoritative source***: One canonical, trusted location for each piece of data

***Data integrity***: All consumers reference the same trusted source

***Version control***: Single source ensures consistent versioning

***Derived data***: Other representations are derived from the single source

***Trust and reliability***: The source is the definitive version when conflicts arise

***System of record***: The primary data store for critical business information

***Organizational practice***: Applied at the architecture and business process level

[discrete]
## **Key Application Areas**:

* Version control systems (Git as SSOT for code)
* Database design and data warehousing
* Documentation and knowledge management
* Configuration management
* Master data management (MDM)

[discrete]
## **When to Use**:

* Designing data architecture for enterprise systems
* Establishing documentation standards and knowledge bases
* Building data pipelines and ETL processes
* Implementing microservices with clear data ownership
* Creating audit trails and ensuring compliance
* Resolving conflicts between multiple data sources

***Difference from SPOT***: SSOT emphasizes the authoritative, trusted nature of a data source and is used at the architecture/organizational level, while SPOT focuses on the implementation pattern

***Related Concepts***: DRY, SPOT, Event sourcing, Data lakes, Master data management
