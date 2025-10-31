#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error.
set -u
# Pipe commands should fail if any command in the pipe fails.
set -o pipefail
# set -x # Uncomment for debugging

# Configuration
FCOPY_URL="https://github.com/akhenakh/fcopy/releases/download/v0.1/fcopy_0.1_linux_amd64.tar.gz"
# This will hold the path to the fcopy executable
FCOPY_CMD=""

# Usage and Argument Parsing
usage() {
  echo "Usage: $0 [options] <yaml_file> [output_filename]"
  echo
  echo "Options:"
  echo "  --no-clean   Do not remove the existing ./docs/ directory before generating files."
  echo "  -h, --help   Show this help message."
  echo
  echo "Modes:"
  echo "  1. Multi-file (default): $0 <yaml_file>"
  echo "     Generates one compressed file per repository defined in the YAML."
  echo "     All output is placed in the ./docs/ directory."
  echo "     Output format: docs/{repo_name}-{version}.md.zstd"
  echo
  echo "  2. Single-file (aggregate): $0 <yaml_file> <output_filename>"
  echo "     Combines all documentation into a single compressed file in ./docs/."
  exit 1
}

# Dependency Management
check_deps() {
  local missing_deps=0
  for dep in git yq zstd curl tar; do
    if ! command -v "$dep" &> /dev/null; then
      echo "Error: Required dependency '$dep' is not installed." >&2
      missing_deps=1
    fi
  done
  if [[ $missing_deps -eq 1 ]]; then
    exit 1
  fi
}

# Download and set up fcopy if not found in PATH
setup_fcopy() {
  if command -v fcopy &> /dev/null; then
    echo "fcopy found in PATH."
    FCOPY_CMD="fcopy"
    return
  fi

  echo "fcopy not found in PATH. Downloading pre-compiled binary..."
  local fcopy_archive
  fcopy_archive=$(basename "$FCOPY_URL")
  
  local fcopy_dir="$TMP_DIR/fcopy_bin"
  mkdir -p "$fcopy_dir"

  curl -sSL "$FCOPY_URL" -o "$TMP_DIR/$fcopy_archive"
  tar -xzf "$TMP_DIR/$fcopy_archive" -C "$fcopy_dir"
  
  FCOPY_CMD="$fcopy_dir/fcopy"
  if [[ ! -f "$FCOPY_CMD" ]]; then
    echo "Error: Failed to find 'fcopy' executable in the downloaded archive." >&2
    exit 1
  fi

  chmod +x "$FCOPY_CMD"
  echo "fcopy is ready at $FCOPY_CMD"
}

main() {
  local CLEAN_OUTPUT=true
  local positional_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-clean)
        CLEAN_OUTPUT=false
        shift # past argument
        ;;
      -h|--help)
        usage
        ;;
      -*)
        echo "Error: Unknown option '$1'" >&2
        usage
        ;;
      *)
        positional_args+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done

  # Restore positional arguments
  set -- "${positional_args[@]}"
  
  # Argument Validation
  local MODE
  local YAML_FILE
  local SINGLE_OUTPUT_FILE=""

  if [[ $# -eq 1 ]]; then
    MODE="multi"
    YAML_FILE="$1"
    echo "--- Running in Multi-File Mode"
  elif [[ $# -eq 2 ]]; then
    MODE="single"
    YAML_FILE="$1"
    SINGLE_OUTPUT_FILE="$2"
    echo "--- Running in Single-File (Aggregate) Mode"
  else
    usage
  fi

  check_deps

  local initial_pwd=$(pwd)
  local ABS_YAML_FILE="$initial_pwd/$YAML_FILE"
  if [[ ! -f "$ABS_YAML_FILE" ]]; then
    echo "Error: YAML file not found at '$ABS_YAML_FILE'" >&2
    exit 1
  fi

  local OUTPUT_DIR="$initial_pwd/docs"
  echo "--- Preparing output directory: $OUTPUT_DIR"
  if [[ "$CLEAN_OUTPUT" == true && -d "$OUTPUT_DIR" ]]; then
    echo "Removing existing output directory (use --no-clean to prevent this)."
    rm -rf "$OUTPUT_DIR"
  else
    echo "Ensuring output directory exists (will not clean existing files)."
  fi
  mkdir -p "$OUTPUT_DIR"

  TMP_DIR=$(mktemp -d)
  trap 'echo "--- Cleaning up temporary directory"; rm -rf "$TMP_DIR"' EXIT
  echo "Created temporary directory at $TMP_DIR"

  setup_fcopy

  local repo_count
  repo_count=$(yq -r '.repositories | length' "$ABS_YAML_FILE")
  echo "Found $repo_count repositories to process in '$YAML_FILE'."

  local single_output_md=""
  if [[ "$MODE" == "single" ]]; then
    single_output_md="$initial_pwd/${SINGLE_OUTPUT_FILE%.zstd}"
    : > "$single_output_md" 
  fi

  for i in $(seq 0 $((repo_count - 1))); do
    local repo_url
    repo_url=$(yq -r ".repositories[$i].url" "$ABS_YAML_FILE")
    local repo_doc_path
    repo_doc_path=$(yq -r ".repositories[$i].path" "$ABS_YAML_FILE")
    local repo_name
    repo_name=$(basename "$repo_url" .git)

    local repo_version
    repo_version=$(yq -r ".repositories[$i].version" "$ABS_YAML_FILE")

    local git_clone_args=("--depth" "1")
    local display_version
    local safe_version

    if [[ -z "$repo_version" || "$repo_version" == "null" ]]; then
      display_version="default branch"
      safe_version="main" 
      echo "Version not specified for '$repo_name', cloning default branch."
    else
      display_version="$repo_version"
      safe_version=$(echo "$repo_version" | tr '/' '_')
      git_clone_args+=("--branch" "$repo_version")
    fi

    echo ""
    echo "--- Processing repository: $repo_name (version: $display_version)"

    local clone_path="$TMP_DIR/$repo_name"
    echo "Cloning $repo_url..."
    git clone "${git_clone_args[@]}" "$repo_url" "$clone_path"

    local doc_path="$clone_path/$repo_doc_path"
    if [[ ! -d "$doc_path" ]]; then
      echo "Warning: Documentation path '$repo_doc_path' not found in '$repo_name'. Skipping."
      continue
    fi
    cd "$doc_path"

    local fcopy_cmd=("$FCOPY_CMD" "-s")
    
    local skip_patterns
    skip_patterns=$(yq -r "if .repositories[$i].skip then .repositories[$i].skip | join(\",\") else \"\" end" "$ABS_YAML_FILE")
    
    if [[ -n "$skip_patterns" ]]; then
        echo "Applying skip patterns: $skip_patterns"
        fcopy_cmd+=("-x" "$skip_patterns")
    fi
    
    fcopy_cmd+=(".")

    if [[ "$MODE" == "multi" ]]; then
      local output_zstd="$OUTPUT_DIR/${repo_name}-${safe_version}.md.zstd"
      local output_md="$TMP_DIR/${repo_name}-${safe_version}.md"
      
      echo "Generating individual file: $output_zstd"
      
      {
        echo "# Documentation from ${repo_name} @ ${display_version}"
        echo ""
      } > "$output_md"

      "${fcopy_cmd[@]}" >> "$output_md"

      zstd -f -o "$output_zstd" "$output_md"
      rm "$output_md"
      echo "✅ Created $output_zstd"

    elif [[ "$MODE" == "single" ]]; then
      echo "Appending to aggregate file: $single_output_md"
      {
        echo "# Documentation from ${repo_name} @ ${display_version}"
        echo ""
        echo "Source Path: \`$repo_doc_path\`"
        echo ""
        echo "---"
        echo ""
      } >> "$single_output_md"
      
      "${fcopy_cmd[@]}" >> "$single_output_md"
    fi

    echo "Finished processing $repo_name."
    cd - > /dev/null
  done

  if [[ "$MODE" == "single" ]]; then
    echo ""
    echo "--- Compressing the final aggregate markdown file"
    if [[ ! -s "$single_output_md" ]]; then
        echo "Warning: The generated markdown file '$single_output_md' is empty."
    else
        local final_file_path="$OUTPUT_DIR/$SINGLE_OUTPUT_FILE"
        zstd -f -o "$final_file_path" "$single_output_md"
        rm "$single_output_md"
        echo "✅ Success! Aggregated and compressed documentation created at: $final_file_path"
    fi
  fi
}

main "$@"
