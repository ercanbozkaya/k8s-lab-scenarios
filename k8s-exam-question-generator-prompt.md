# Prompt: Kubernetes Exam Practice Question Generator for Local Lab Cluster

Attached is the README for my local Kubernetes lab cluster (Multipass-based, 3-node
cluster — `k8slab-controller`, `k8slab-node01`, `k8slab-node02` — with mixed
kubeadm versions and Cilium CNI). All `kubectl` access happens **inside the
controller VM** or via `multipass exec ... -- sudo kubectl --kubeconfig
/etc/kubernetes/admin.conf ...` from the host — there is no local kubectl on
the Mac, so any scripts you write must respect that constraint.

I want you to help me build a **certification practice question system** on
top of this cluster. Here's how it should work:

## 1. Input: questions I give you

I'll give you individual exam-style questions (e.g. "create a Deployment with
a specific resource limit that's currently missing," "fix a broken kubelet
config on node02," "a NetworkPolicy that isn't correctly restricting
traffic"). For each question, you will generate a **self-contained question
package** with three modular scripts:

- **`setup.sh` (break/seed script):** Provisions the broken, missing, or
  incomplete environment (install from internet if needed) the trainee 
  needs to fix or build against. Idempotent where possible, and safe to re-run.
- **`validate.sh` (grading script):** Checks whether the trainee's solution
  meets the question's requirements and outputs a clear pass/fail result
  (plus which specific checks failed, for feedback).
- **`cleanup.sh` (teardown script):** Removes everything the question created,
  leaving the cluster clean for the next question or a re-attempt.

All three scripts for a given question must operate against **its own
dedicated namespace** (e.g. `q-<id>`), so questions never collide with each
other and can be provisioned/graded/cleaned up independently or in bulk.

## 2. Metadata per question

Each question package should carry metadata so it can be filtered and
composed later:

- `id` (unique, stable identifier)
- `exam_domains`: one or more of `CKA`, `CKAD`, `CKS` (a question may belong
  to more than one exam simultaneously)
- `exam_topic`: the specific curriculum domain within that exam (e.g. for CKA:
  Cluster Architecture/Installation/Configuration, Workloads & Scheduling,
  Services & Networking, Storage, Troubleshooting)
- `weight`/`difficulty` (optional, to help match real exam blueprint
  proportions)
- `namespace`: derived from `id`
- short human-readable title and the full question prompt text shown to the
  trainee

## 3. Two levels of scripts

- **Question-level (single question):** a trainee can run `setup.sh` for one
  question, attempt it, run `validate.sh` to get graded, then `cleanup.sh`
  when done — all independent of any other question.
- **Exam-level (orchestrator):** a higher-level script that simulates a full
  exam (e.g. "CKA practice exam") by:
  - Selecting questions from the pool that match the requested exam type and
    (optionally) specific domains
  - Choosing them **randomly but reproducibly** — e.g. via a seed — so the
    same seed always reproduces the same question set, but different seeds
    give different exams
  - Respecting realistic per-domain weighting/counts if possible (mirroring
    the real exam's domain proportions)
  - Running `setup.sh` for every selected question (each into its own
    namespace) so the trainee gets one consistent broken/incomplete cluster
    state to work through end-to-end
  - Later running `validate.sh` across all selected questions to produce an
    aggregate score/report
  - Running `cleanup.sh` across all selected questions to reset the cluster

## 4. What I need from you

Please propose:

1. A directory/file layout convention for storing question packages (metadata
   + the three scripts) so they're easy to add to and discover programmatically.
2. We will develop The orchestrator script's interface later  
   (e.g. `./exam.sh --type CKA --seed 42 --count 17 setup|validate|cleanup`). 
   Now we will focus on creating question database.
3. Conventions the setup/validate/cleanup scripts should follow so they're
   consistent with this repo's existing style (sourcing `config.sh`, using
   `multipass exec` against the controller, namespace-scoped `kubectl`
   commands, `set -euo pipefail`, logging via `log_info`/`log_warn`/`log_error`).
4. Once we agree on the structure, I'll start feeding you individual questions
   one at a time (or in batches) and you'll generate the corresponding
   question packages following this convention.

Let me know if anything about this design needs clarification before we
start.
