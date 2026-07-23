# Kubernetes Lab Scenarios — Exam Practice Question Bank

A collection of certification practice questions that run against a **LocalKubernetesLabInfraMacOS** cluster (Multipass-based, 3-node).

## Quick Start

```bash
# Build the global manifest from all question packages:
./scripts/build-manifest.sh

# Run setup for one question (inside its directory):
cd questions/0001-create-networkpolicy-allow-traffic-to-db && ./setup.sh

# Grade the solution:
./validate.sh                  # fast path — JSON lines on stdout
./validate.sh --with-evidence  # heavy capture + artifacts dir

# Teardown:
./cleanup.sh
```

## Structure

```
k8s-lab-scenarios/
├── lib/                        # Shared libraries (source only, never execute)
│   ├── cluster.sh              # k8s_exec, namespace helpers, logging
│   └── question.sh             # Q_ID auto-derived from metadata.yaml
│
├── questions/                  # Question packages (one dir each)
│   └── 0001-create-networkpolicy-allow-traffic-to-db/
│       ├── metadata.yaml           # Question-level metadata (id, domains, topic)
│       ├── setup.sh                # Provision broken/incomplete state
│       ├── validate.sh             # Grade solution (JSON lines + summary)
│       └── cleanup.sh              # Remove question artifacts
│
├── scripts/
│   └── build-manifest.sh       # scans questions/*/metadata.yaml → _manifest.yaml
│
├── _manifest.yaml              # Auto-generated index (do not edit manually)
└── README.md
```

## Metadata format (each question's metadata.yaml)

| Field | Required? | Description |
|---|---|---|
| `id` | **yes** | Unique, stable identifier (e.g. `0001-slug`) |
| `exam_domains` | **yes** | Array — e.g. `[CKA, CKAD, CKS]` (can be multi-tagged) |
| `exam_topic` | **yes** | Curriculum domain, e.g. "Services & Networking" |
| `weight` | no | Exam-style weighting (realistic blueprint proportion) |
| `difficulty` | no | human-readable: easy / medium / hard |
| `title` | **yes** | Short title shown to the trainee |
| `prompt` | **yes** | Full question text (heredoc-friendly string) |

## Script conventions

- Every script begins with `set -euo pipefail` and sources both `cluster.sh` + `question.sh`.
- All kubectl calls go through `k8s_exec` — the wrapper handles multipass exec/kubeconfig plumbing.
- All resources are scoped to their own namespace (`q-<id>`), derived automatically from `metadata.yaml`.
- Use `log_info`/`log_warn`/`log_error`, never raw `echo`.
- Cleanup scripts exit 0 always (`--ignore-not-found` on deletes).

## Adding a new question

1. Create `questions/<SEQ>-<slug>/` directory.
2. Add `metadata.yaml`, `setup.sh`, `validate.sh`, `cleanup.sh` following the conventions above.
3. Run `./scripts/build-manifest.sh` to refresh `_manifest.yaml`.

## Orchestrator (TODO)

Planned interface when the exam-level orchestrator is built:

```bash
./orchestrator.sh --type CKA --seed 42 --count 17 setup|validate|cleanup
```

## Lab connection

Set `$LAB_REPO_PATH` to point at your LocalKubernetesLabInfraMacOS repo if you want question scripts to inherit its config.sh defaults:

```bash
export LAB_REPO_PATH=../LocalKubernetesLabInfraMacOS
./scripts/build-manifest.sh
```

Otherwise `lib/cluster.sh` falls back to sensible defaults (`CONTROLLER_NAME=k8slab-controller`).