<!-- Vendored from https://llm-coding.github.io/Semantic-Anchors/anchor/testing-pyramid (English original, anchors/testing-pyramid.txt)
     Fetched: 2026-10-16 . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding
     Modification: none to the text below; only this wrapper header was added. -->

# Testing Pyramid

***Full Name***: Testing Pyramid according to Mike Cohn

[discrete]
## **Core Concepts**:

***Three layers***
* **Unit tests** (base): Many fast, isolated tests
* **Integration tests** (middle): Moderate number, test component interaction
* **End-to-end tests** (top): Few, test complete user journeys

***Proportional distribution***: More unit tests, fewer E2E tests

***Cost and speed***: Unit tests cheap and fast, E2E tests expensive and slow

***Feedback loops***: Faster feedback from lower levels

***Anti-pattern: Ice cream cone***: Too many E2E tests, too few unit tests

***Test at the right level***: Don't test through UI what can be tested in isolation

***Confidence gradient***: Balance confidence with execution speed

***Key Proponent***: Mike Cohn ("Succeeding with Agile", 2009)

[discrete]
## **When to Use**:

* Planning test strategy for projects
* Balancing test types in CI/CD pipelines
* Evaluating existing test suites
* Guiding team testing practices

[discrete]
## **Criticism**:

* Kent C. Dodds, https://kentcdodds.com/blog/write-tests["Write tests. Not too many. Mostly integration."] (2019) — proposes the **Testing Trophy**: integration tests give the best confidence per cost, so the pyramid's unit-heavy base optimises for the wrong metric
* Spotify Engineering, https://engineering.atspotify.com/2018/01/testing-of-microservices/["Testing of Microservices"] (2018) — proposes the **honeycomb** shape for microservices: unit-heavy suites couple tests to implementation details and break under refactoring
* The layer boundaries blur in modern stacks — fast in-memory "integration" tests undermine the pyramid's core assumption that higher-level tests are necessarily slow and expensive
