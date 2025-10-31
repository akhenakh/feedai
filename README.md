# Automated Documentation Aggregator for LLM Context

This repository contains a toolchain to automatically fetch, aggregate, and compress documentation from various Git repositories. The primary goal is to create version-specific, comprehensive context files that can be fed to Large Language Models (LLMs) to get highly accurate and context-aware answers.

## The Problem It Solves

LLMs like ChatGPT, Claude, and Gemini are incredibly powerful, but they have limitations:
-   **Knowledge Cut-offs:** They don't know about changes or new software versions released after their training date.
-   **Lack of Specificity:** They may not have indexed the documentation for a specific, niche version (e.g., `v1.12.1`) of a library.
-   **No Access to Private Code:** They have no knowledge of your internal or private repositories.

Asking a generic question like, "How do I use the streaming API in Bento v1.12.1?" might result in a hallucinated answer based on a different version or a complete guess.

This tool solves that problem by creating a single, authoritative text file for an entire documentation set at a specific version.

## ⭐ The Core Use Case: Providing Context to LLMs

The generated `.md.zstd` files are designed for a technique called **Retrieval-Augmented Generation (RAG)**, or more simply, "context-stuffing." By providing the LLM with the *exact* documentation as context, you force it to base its answers on ground truth, dramatically improving accuracy.

### How to Use the Generated Files with an LLM

1.  **Find the Right File:** Navigate to the `docs/` directory or the [live documentation browser](https://akhenakh.github.io/feedai/) to find the file for the project and version you need (e.g., `bento-v1.12.1.md.zstd`).

2.  **Download and Decompress:** Download the file and decompress it using the `zstd` command-line tool.
    ```bash
    # This will create a file named bento-v1.12.1.md
    zstd -d docs/bento-v1.12.1.md.zstd
    # or cat
    zstdcat - docs/bento-v1.12.1.md.zstd
    ```

3.  **Copy the Content:** Open the resulting `.md` file and copy its entire contents to your clipboard.

4.  **Construct Your LLM Prompt:** In your chat interface (ChatGPT, Claude, etc.), structure your query using the following template. This instructs the model to ignore its internal knowledge and rely solely on the context you provide.


This process ensures you get answers that are accurate, version-specific, and free from hallucinations.

## How It Works

The automation is powered by a `generate-docs.sh` script and a GitHub Action.

1.  **Configuration:** A `docs.yaml` file lists the Git repositories, versions, and paths to the documentation.
2.  **Execution:** On a push to the `main` branch, a GitHub Action triggers.
3.  **Cloning:** The script clones each repository at the specified version (or the default branch if no version is given).
4.  **Aggregation:** It uses the `fcopy` utility to concatenate all relevant markdown files from the specified documentation path into a single file, respecting any `skip` patterns.
5.  **Compression:** The resulting massive markdown file is compressed using `zstd` for efficient storage.
6.  **Webpage Manifest:** It generates a `manifest.json` file, which lists all the available documentation archives for the web viewer.
7.  **Commit:** The action automatically commits the new or updated files in the `docs/` directory back to the repository.

## Configuration (`docs.yaml`)

The `docs.yaml` file drives the entire process.

```yaml
repositories:
  - url: "https://github.com/my-org/my-project.git"
    version: "v2.5.1"
    path: "docs/source" # Path to the documentation source
    skip:
      - "**/_index.md" # Glob patterns to skip

  - url: "https://github.com/another-org/another-repo.git"
    # No version specified: will clone the default branch
    # and name the output file with '-main.md.zstd'
    path: "documentation"
```

## Manual Usage

You can also run the script locally.

```bash
# Generate one file per repository entry in ./docs/
./generate-docs.sh docs.yaml

# Aggregate all entries into a single file in ./docs/
./generate-docs.sh docs.yaml all-docs-aggregated.md.zstd
```
