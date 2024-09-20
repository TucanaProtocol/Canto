#!/bin/bash

# Directory containing Solidity contracts
CONTRACTS_DIR="./contracts"
# Directory for outputting ABI and BIN files
BUILD_DIR="./build"
# Directory for outputting Go binding files
GO_BINDINGS_DIR="./go_bindings"
# Temporary log file for solc output
SOLC_LOG=$(mktemp)

# Ensure the build and Go bindings directories exist
mkdir -p "$BUILD_DIR"
mkdir -p "$GO_BINDINGS_DIR"

# Iterate over all .sol files in the contracts directory
for contract in "$CONTRACTS_DIR"/*.sol; do
    # Extract the contract name (remove path and extension)
    contract_name=$(basename "$contract" .sol)

    echo "Compiling $contract_name.sol..."

    # Compile the contract using solc to generate ABI and BIN files
    solc --abi --bin --overwrite --include-path node_modules/ --base-path . "$contract" -o "$BUILD_DIR" > "$SOLC_LOG" 2>&1

    # Display solc output for debugging
    echo "Solidity compiler output for $contract_name:"
    cat "$SOLC_LOG"

    # Check if the ABI and BIN files were generated successfully
    if [[ -f "$BUILD_DIR/$contract_name.abi" && -f "$BUILD_DIR/$contract_name.bin" ]]; then
        echo "ABI and BIN files for $contract_name have been generated successfully."

        echo "Generating Go bindings for $contract_name..."

        # Remove existing Go binding file if it exists
        if [[ -f "$GO_BINDINGS_DIR/$contract_name.go" ]]; then
            echo "Deleting existing Go binding file: $contract_name.go..."
            rm "$GO_BINDINGS_DIR/$contract_name.go"
        fi

        # Generate Go binding files using abigen with fixed package name 'go_bindings'
        abigen --bin="$BUILD_DIR/$contract_name.bin" --abi="$BUILD_DIR/$contract_name.abi" \
               --pkg="go_bindings" --out="$GO_BINDINGS_DIR/$contract_name.go"
        echo "Go binding file for $contract_name has been generated."
    else
        echo "Error: Failed to generate ABI or BIN files for $contract_name."
        echo "Contents of the build directory:"
        ls -l "$BUILD_DIR"
    fi
done

# Clean up temporary solc log file
rm "$SOLC_LOG"

echo "All contract Go bindings have been generated."
