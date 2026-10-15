<!-- Vendored from https://llm-coding.github.io/Semantic-Anchors/anchor/gof-template-method-pattern (English original, anchors/gof-template-method-pattern.txt)
     Fetched: 2026-10-16 . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding
     Modification: none to the text below; only this wrapper header was added. -->

# GoF-Template Method Pattern

***Full Name***: GoF Template Method Pattern (Behavioral)

[discrete]
## **Intent**:
Define the skeleton of an algorithm in an operation, deferring some steps to subclasses.

[discrete]
## **When to Use**:
* When you want to implement the invariant parts of an algorithm once and leave it to subclasses to implement varying behavior
* When common behavior among subclasses should be factored and localized in a common class

[discrete]
## **Prompt Example**:
"Refactore die Report-Generierung nach dem GoF-Template Method Pattern. Der Algorithmus (Daten laden, transformieren, formatieren) bleibt fix, aber die einzelnen Schritte sind austauschbar."

[discrete]
## **Related Anchors**:
* GoF Design Patterns (Umbrella)
