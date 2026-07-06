---
inclusion: manual
---
# Prompt Templates

Reusable templates for common agent interactions. Invoke with `#prompt-templates`.

## Review Prompt

```
## Role
You are in Reviewer mode per `.kiro/steering/reviewer-mode.md`.

## Context
[1-2 sentences: what feature/change is being reviewed and why]

## Scope
Review these files: [list files, or "changes since commit X", or "diff of branch X vs main"]
Do NOT review: [anything explicitly out of scope]

## References
Check alignment with:
- [list specific docs and decision IDs]

## Criteria
[numbered list of specific things to verify]

## Output
For each finding: What, Where, Why it matters, Suggestion.
Categorize: [MUST FIX], [SHOULD FIX], [CONSIDER].
```

## Spec Mode Feature Prompt

```
## Context
[1-2 sentences: what feature this is and where it fits in the product]

## Goal
[what the user needs to accomplish]

## Scope
In scope: [what to build]
Out of scope: [what NOT to build]

## References
- [list specific docs and decision IDs the agent should read]

## Constraints
[non-obvious decisions or rules that affect this feature]
```

## General Prompting Principles

- Be as concise as possible while being as specific as necessary
- Every sentence should add new information — no redundancy
- Point to files rather than restating their contents
- Cite decisions by ID (e.g., D012) so the agent can look them up
- Explicitly state what is out of scope
- One example outperforms three sentences of description
