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


## License

The licenses for the documentation packs are to be found in the respective repositories.
