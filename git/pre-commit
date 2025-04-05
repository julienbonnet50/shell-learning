#!/bin/bash

# Git pre-commit hook to check for passwords and sensitive information
# Save this file as .git/hooks/pre-commit and make it executable (chmod +x .git/hooks/pre-commit)

echo "🔍 Checking for potential passwords and sensitive data..."

# Get list of all files staged for commit
files=$(git diff --cached --name-only --diff-filter=ACM)

# Exit if no files are staged
if [ -z "$files" ]; then
    echo "No files staged for commit."
    exit 0
fi

# Define patterns to search for
patterns=(
    # Common password variable names
    'password[^_a-zA-Z0-9]'
    'passwd[^_a-zA-Z0-9]'
    'pwd[^_a-zA-Z0-9]'
    'pass[^_a-zA-Z0-9]'
    'secret[^_a-zA-Z0-9]'
    'credential[^_a-zA-Z0-9]'
    'api[-_]?key[^_a-zA-Z0-9]'
    'auth[-_]?token[^_a-zA-Z0-9]'
    
    # Suspicious patterns that might indicate hardcoded secrets
    '[^a-zA-Z]token[^_a-zA-Z0-9]'
    'apikey[^_a-zA-Z0-9]'
    
    # Common password/credential formats
    '[A-Za-z0-9_\-\.]{20,}'  # Long strings that might be keys/tokens
    'eyJ[A-Za-z0-9_-]{10,}\.'  # JWT token pattern
    'ssh-rsa [A-Za-z0-9+/=]+'  # SSH keys
    '[A-Za-z0-9+/]{40,}'  # Base64 encoded data (potential secrets)
    
    # AWS keys and similar patterns
    'AKIA[0-9A-Z]{16}'  # AWS access key pattern
    '[0-9a-f]{32}'  # MD5 hash or similar hex string
    'BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY'  # Private key headers
)

# Function to check for patterns
check_patterns() {
    local file="$1"
    local line_num=1
    local violations=0
    
    # Skip binary files
    if $(file "$file" | grep -q "binary"); then
        return 0
    fi
    
    # Read file line by line
    while IFS= read -r line; do
        for pattern in "${patterns[@]}"; do
            if echo "$line" | grep -Eq "$pattern"; then
                # Highlight the matching part
                highlighted=$(echo "$line" | grep -E --color=always "$pattern")
                echo -e "\e[31m❌ Potential sensitive data in $file:$line_num:\e[0m"
                echo -e "   $highlighted"
                ((violations++))
            fi
        done
        ((line_num++))
    done < "$file"
    
    return $violations
}

# Check all staged files
total_violations=0
for file in $files; do
    # Skip if file doesn't exist (e.g., deleted)
    [ -f "$file" ] || continue
    
    # Check patterns in this file
    check_patterns "$file"
    violations=$?
    total_violations=$((total_violations + violations))
done

# If violations found, provide feedback and prevent commit
if [ $total_violations -gt 0 ]; then
    echo -e "\e[31m❌ Found $total_violations potential password/sensitive data issues.\e[0m"
    echo "Please remove sensitive data before committing."
    echo "If this is a false positive, you can use 'git commit --no-verify' to bypass this check."
    exit 1
else
    echo -e "\e[32m✅ No potential passwords or sensitive data found.\e[0m"
    exit 0
fi