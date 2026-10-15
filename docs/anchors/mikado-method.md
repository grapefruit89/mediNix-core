<!-- Vendored from https://llm-coding.github.io/Semantic-Anchors/anchor/mikado-method (English original, anchors/mikado-method.txt)
     Fetched: 2026-10-16 . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding
     Modification: none to the text below; only this wrapper header was added. -->

# Mikado Method

***Also known as***: Mikado Graph Method

[discrete]
## **Core Concepts**:

***Mikado Goal***: The clear desired future state of the code after refactoring; the root of the dependency graph and success criterion of the change

***Prerequisite discovery***: Reveal blocking dependencies by attempting the change and noting what breaks

***Use experiments***: Prefer quick or time-boxed empirical attempts over long upfront analysis

***Always revert***: **IMPORTANT**: After discovering a prerequisite, **always** revert to the last known working state before addressing it

***Mikado Graph***: A directed acyclic graph where goals and prerequisites are nodes and arrows show dependencies

***Leaf-first resolution***: Resolve the leaf nodes (no further prerequisites) first, working back to the root goal

***Small reversible steps***: Revert failed experiments immediately; keep or commit only coherent healthy changes

***Meaningful commits***: Commit only when the code compiles, tests run, the product is in a good state, and the change makes sense on its own

***Key Proponents***: Ola Ellnestam, Daniel Brolund ("The Mikado Method", 2012)

[discrete]
## **When to Use**:

* Tackling large refactorings in legacy or complex codebases
* When a direct change breaks too many things to fix at once
* Coordinating multi-developer refactoring efforts safely
* Making incremental improvements without blocking the team
* Brownfield development with hidden dependencies

[[mikado-method-recipe-canonical-form]]
[discrete]
## **Mikado Method Recipe (Canonical Form)**

1. Start here: Draw the Mikado Goal.
1. Implement the goal or prerequisite naively.
1. Are there any errors?

--
** Examples: compiler errors, failing tests, runtime errors, broken builds.
** If **Yes**, go to step 4.
** If **No**, go to step 9.
--
1. Come up with immediate solutions to the errors.
1. Draw the solutions as new prerequisites in the Mikado Graph.
1. Revert all changes and return to the last known good state.
1. Select the next prerequisite to work with.
1. Go to step 2.
1. Does the change make sense?

--
** Examples: understandable, internally consistent, safe to keep, useful on its own.
** If **Yes**, go to step 10.
** If **No**, go to step 7.
--
1. Commit the change.
1. Is the Mikado Goal met?

--
** If **Yes**, go to step 12.
** If **No**, go to step 7.
--
1. DONE!

[discrete]
## **Related Anchors**:

* TDD, Chicago School
* TDD, London School
