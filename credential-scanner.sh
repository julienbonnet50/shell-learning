#!/bin/bash

# Git History Credential Scanner
# This script iterates through every commit in a repository
# and checks for potential passwords, credentials, and sensitive information

# Detect if running in Git Bash on Windows and open in new window if needed
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Check if script was called directly without being sourced
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # Get the full path to this script
        SCRIPT_PATH=$(readlink -f "$0")
        
        # Check if we're not already in a new window
        if [[ -z "$GIT_CRED_SCANNER_WINDOW" ]]; then
            export GIT_CRED_SCANNER_WINDOW=1
            
            # Find Git Bash executable path
            if [[ -f "/c/Program Files/Git/git-bash.exe" ]]; then
                GIT_BASH="/c/Program Files/Git/git-bash.exe"
            elif [[ -f "/d/Program Files/Git/git-bash.exe" ]]; then
                GIT_BASH="/d/Program Files/Git/git-bash.exe"
            elif [[ -f "$PROGRAMFILES/Git/git-bash.exe" ]]; then
                GIT_BASH="$PROGRAMFILES/Git/git-bash.exe"
            else
                # Fallback to finding git-bash in PATH
                GIT_BASH_PATH=$(command -v git-bash.exe)
                if [[ -n "$GIT_BASH_PATH" ]]; then
                    GIT_BASH="$GIT_BASH_PATH"
                else
                    # If we can't find git-bash.exe, just use cmd to open a new bash
                    start cmd //c "bash \"$SCRIPT_PATH\" $* && echo 'Press any key to close window...' && pause > nul"
                    exit 0
                fi
            fi
            
            # Open new Git Bash window with the same script and arguments
            "$GIT_BASH" -c "\"$SCRIPT_PATH\" $*; echo 'Press any key to close window...'; read -n 1"
            exit 0
        fi
    fi
fi

# Function to display script usage
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -r, --repo PATH     Path to the repository (default: current directory)"
  echo "  -b, --branch NAME   Branch to scan (default: all branches)"
  echo "  -o, --output FILE   Output results to file"
  echo "  -v, --verbose       Show more details in the output"
  echo "  -h, --help          Display this help message"
}

# Default values
REPO_PATH="."
BRANCH="--all"
OUTPUT_FILE=""
VERBOSE=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -r|--repo)
      REPO_PATH="$2"
      shift 2
      ;;
    -b|--branch)
      BRANCH="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Check if repository exists
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Error: Not a git repository: $REPO_PATH"
  exit 1
fi

# Navigate to repository
cd "$REPO_PATH" || exit 1

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Define patterns to search for potential credentials - fixed to be compatible with basic grep
PATTERNS=(
  # Common credential variable names
  "password[[:punct:][:space:]]"
  "passwd[[:punct:][:space:]]"
  "pwd[[:punct:][:space:]]"
  "pass[[:punct:][:space:]]"
  "secret[[:punct:][:space:]]"
  "credential[[:punct:][:space:]]"
  "api.key"
  "api_key"
  "auth.token"
  "auth_token"
  
  # Common format patterns
  "AKIA[0-9A-Z]"  # AWS access key (simplified)
  "sk_live_[0-9a-zA-Z]"  # Stripe API key (simplified)
  "github_pat_"  # GitHub PAT (simplified)
  "ghp_"  # GitHub token
  "ghs_"  # GitHub token
  "eyJ[A-Za-z0-9_-]"  # JWT token pattern (simplified)
  
  # Private key patterns
  "BEGIN RSA PRIVATE KEY"
  "BEGIN EC PRIVATE KEY"
  "BEGIN DSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
  
  # Generic patterns (simplified)
  "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"  # Short hex strings that might be part of longer ones
)

echo "🔍 Scanning repository for credentials in commit history..."
echo "   Repository: $REPO_PATH"
echo "   Branch: $BRANCH"
echo ""

# Create pattern file for grep
PATTERN_FILE="$TEMP_DIR/patterns.txt"
for pattern in "${PATTERNS[@]}"; do
  echo "$pattern" >> "$PATTERN_FILE"
done

# Get list of all commits
echo "📋 Retrieving commit list..."
git log --pretty=format:"%H" $BRANCH > "$TEMP_DIR/commits.txt"
TOTAL_COMMITS=$(wc -l < "$TEMP_DIR/commits.txt")
echo "   Found $TOTAL_COMMITS commits to scan"
echo ""

# Initialize results file
if [ -n "$OUTPUT_FILE" ]; then
  echo "# Credential Scan Results - $(date)" > "$OUTPUT_FILE"
  echo "Repository: $REPO_PATH" >> "$OUTPUT_FILE"
  echo "Total commits: $TOTAL_COMMITS" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

# Function to output results to console or file
output() {
  if [ -n "$OUTPUT_FILE" ]; then
    echo "$1" >> "$OUTPUT_FILE"
  fi
  echo "$1"
}

# Function to process file findings safely
process_file_findings() {
  local results="$1"
  local verbose="$2"
  
  if [ "$verbose" -eq 1 ]; then
    echo "   Files with potential credentials:"
    echo "$results" | while IFS='|' read -r file line content; do
      echo "   - $file (line $line): $content"
    done
  else
    echo "   Files with potential credentials:"
    echo "$results" | cut -d'|' -f1 | sort -u | while read -r file; do
      echo "   - $file"
    done
  fi
}

# Main scan function
scan_commits() {
  # Inside scan_commits() near the top:
  local all_findings_file="$TEMP_DIR/all_findings.txt"
  touch "$all_findings_file"
  local commit_count=0
  local found_creds=0
  
  while IFS= read -r commit_hash; do
    ((commit_count++))
    
    # Progress indicator
    if [ $((commit_count % 10)) -eq 0 ] || [ "$commit_count" -eq 1 ]; then
      printf "\r⏳ Scanning commit %d/%d" $commit_count $TOTAL_COMMITS
    fi
    
    # Get commit details
    commit_date=$(git show -s --format=%ci "$commit_hash")
    commit_author=$(git show -s --format=%an "$commit_hash")
    commit_subject=$(git show -s --format=%s "$commit_hash")
    
    # Make a temp file to store results for this commit
    RESULT_FILE="$TEMP_DIR/result_$commit_hash"
    > "$RESULT_FILE" # Clear/create file
    
    # Get list of files in this commit
    git diff-tree --no-commit-id --name-only -r "$commit_hash" > "$TEMP_DIR/files_$commit_hash"
    
    # Check each file individually
    while IFS= read -r file; do
      # Skip binary files and deleted files
      if git cat-file -e "$commit_hash:$file" 2>/dev/null; then
        if ! git grep -I -q . "$commit_hash" -- "$file" 2>/dev/null; then
          continue # Skip binary file
        fi
        
        # Extract file content at this commit
        git show "$commit_hash:$file" 2>/dev/null > "$TEMP_DIR/content"
        
        # Check for patterns
        grep -n -f "$PATTERN_FILE" "$TEMP_DIR/content" | sed 's/:/|/' | sed "s|^|$file|" >> "$RESULT_FILE" || true
      fi
    done < "$TEMP_DIR/files_$commit_hash"
    
    # Check if we found anything
    if [ -s "$RESULT_FILE" ]; then
      ((found_creds++))
      
      # Print a newline for progress indicator clarity
      echo ""
      
      output "🚨 Found potential credentials in commit $commit_hash"
      output "   Date: $commit_date"
      output "   Author: $commit_author"
      output "   Subject: $commit_subject"
      
      # Process and display findings
      process_file_findings "$(cat "$RESULT_FILE")" "$VERBOSE"
      
      output ""

      while IFS= read -r finding; do
        IFS='|' read -r file line_number content <<< "$finding"
        echo "$commit_hash|$commit_date|$commit_author|$commit_subject|$file|$line_number|$content" >> "$all_findings_file"
      done < "$RESULT_FILE"
    fi
    
    # Clean up temp files
    rm -f "$TEMP_DIR/files_$commit_hash" "$TEMP_DIR/content" "$RESULT_FILE"
  done < "$TEMP_DIR/commits.txt"
  
  # Clear progress indicator
  echo -e "\r                                                          "
  
  return $found_creds
}

# Run scan
scan_commits
FOUND_CREDS=$?

# Print summary
echo ""
if [ "$FOUND_CREDS" -gt 0 ]; then
  output "🔴 Scan complete! Found potential credentials in $FOUND_CREDS commits."
else
  output "🟢 Scan complete! No potential credentials found in any commit."
fi

if [ -n "$OUTPUT_FILE" ]; then
  echo "Results saved to: $OUTPUT_FILE"
fi

# Replace the existing summary output with:
echo ""
if [ "$FOUND_CREDS" -gt 0 ]; then
  output "🔴 Scan complete! Found potential credentials in $FOUND_CREDS commits."
  
  # Print detailed summary
  output ""
  output "📋 Critical Findings Summary:"
  output "================================================================="
  
  # Group findings by commit
  declare -A commit_map
  while IFS='|' read -r hash date author subject file line content; do
    commit_map["$hash"]+="$file|$line|$content|"
  done < "$TEMP_DIR/all_findings.txt"
  
  # Print each commit's findings
  for commit_hash in "${!commit_map[@]}"; do
    IFS='|' read -r commit_date commit_author commit_subject <<< "$(git show -s --format="%ci|%an|%s" "$commit_hash")"
    
    output "🔍 Commit: $commit_hash"
    output "   Date:    $commit_date"
    output "   Author:  $commit_author"
    output "   Subject: $commit_subject"
    output "   Files:"
    
    # Process findings for this commit
    echo "${commit_map[$commit_hash]}" | tr '|' '\n' | while IFS='|' read -r file line content; do
      [ -z "$file" ] && continue
      output "     - File: $file (Line $line)"
      output "       Content: $content"
    done
    
    output "================================================================="
  done
  
else
  output "🟢 Scan complete! No potential credentials found in any commit."
fi

# If in Windows and in new window, wait before closing
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && [[ -n "$GIT_CRED_SCANNER_WINDOW" ]]; then
  echo ""
  echo "Press any key to close this window..."
  read -n 1
fi

exit 0