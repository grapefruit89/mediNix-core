<!-- Vendored from https://llm-coding.github.io/Semantic-Anchors/anchor/separation-of-concerns (English original, anchors/separation-of-concerns.txt)
     Fetched: 2026-10-16 . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding
     Modification: none to the text below; only this wrapper header was added. -->

# Separation of Concerns

***Also known as***: SoC

[discrete]
## **Core Concepts**:

***Concern***: A distinct aspect or responsibility of a system — correctness vs. efficiency, business logic vs. presentation, persistence vs. domain rules

***Isolation***: Each concern is studied, designed, and changed in isolation, so that one aspect can be reasoned about without interference from the others

***Modularity***: Separating concerns into distinct units is the structural basis for modular software — high cohesion within a unit, low coupling between units

***Independent change***: When concerns are cleanly separated, a change to one aspect ripples minimally into the others

***Manifestations***: The principle shows up concretely as layering, modularization, MVC, microservices boundaries, and aspect-oriented programming

***Relation to information hiding***: David Parnas's information hiding (1972) is the complementary mechanism — Dijkstra separates concerns to **think** clearly, Parnas hides design decisions to **change** safely

***Relation to SRP***: The Single Responsibility Principle applies Separation of Concerns at the class/module granularity — "a module should have one reason to change"

***Key Proponent***: Edsger W. Dijkstra coined the term in https://www.cs.utexas.edu/~EWD/transcriptions/EWD04xx/EWD447.html["On the role of scientific thought" (EWD447, 1974)]: "the separation of concerns ... even if not perfectly possible, is yet the only available technique for effective ordering of one's thoughts"

[discrete]
## **When to Use**:

* Decomposing a system into modules, layers, or services with clear boundaries
* Reviewing code for tangled responsibilities (e.g. business logic mixed with I/O or presentation)
* Justifying architectural seams — why persistence, domain, and UI are kept apart
* Teaching why high cohesion and low coupling matter
* Prompting an LLM to structure code into well-bounded, independently changeable units

[discrete]
## **Related Anchors**:

* Cohesion Criteria
* Unix Philosophy
* Single Responsibility Principle
* Don't Repeat Yourself
* Clean Architecture
