# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those
roles to the labels that actually exist in `openkazoo/kazoo`.

**Only one of the five has a counterpart.** This repo does not currently model
triage state with labels, so most roles map to nothing. Do not invent a label to
fill a gap — `gh issue edit --add-label` fails on a label that does not exist.

| Role in mattpocock/skills | Label in our tracker | Notes                                          |
| ------------------------- | -------------------- | ---------------------------------------------- |
| `needs-triage`            | _(none)_             | Untriaged is the absence of a decision, not a label. |
| `needs-info`              | _(none)_             | Ask in a comment; leave the issue open.        |
| `ready-for-agent`         | _(none)_             | No agent/human split is modelled today.        |
| `ready-for-human`         | _(none)_             | `Help Wanted` means "we want outside help", which is not the same thing. |
| `wontfix`                 | `Won't Fix`          | Note the spacing and apostrophe.               |

When a skill asks for a role that maps to _(none)_, take the action the role
implies — comment, close, assign — and skip the label.

## The labels this repo does use

| Label              | Meaning                                                            |
| ------------------ | ------------------------------------------------------------------ |
| `Bug`              | Something isn't working                                            |
| `Duplicate`        | This issue or pull request already exists                          |
| `Feature Request`  | Improvements to existing behavior                                  |
| `Help Wanted`      | Extra attention is needed                                          |
| `Proposal`         | Significant changes to the architecture, behavior, or configuration |
| `Won't Fix`        | This will not be worked on                                         |

`wayfinder:*` labels (`map`, `research`, `grilling`, `prototype`, `task`) are
reserved for `/wayfinder`; see `docs/agents/issue-tracker.md`.

Verify against the live set before relying on this table:

```sh
gh label list --limit 100
```
