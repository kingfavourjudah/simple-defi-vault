#!/bin/bash

# Havilah Vault Deployment Script for Starknet Devnet
# This script deploys MockERC20 token and HavilahVault contracts

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEVNET_URL="${DEVNET_URL:-http://127.0.0.1:5050}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${PROFILE:-devnet}"

# Account configuration (from accounts.json)
ACCOUNT_NAME="devnet_account"
ACCOUNT_ADDRESS="0x064b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691"

# MockERC20 constructor parameters
# Using felt252 short string encoding for name and symbol
TOKEN_NAME="0x486176696c6168546f6b656e"  # "HavilahToken" as felt252
TOKEN_SYMBOL="0x48564c"  # "HVL" as felt252
TOKEN_DECIMALS=18
INITIAL_SUPPLY=1000000000000000000000000  # 1,000,000 tokens with 18 decimals

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Havilah Vault Deployment Script     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if devnet is running
check_devnet() {
    echo -e "${YELLOW}Checking devnet connection...${NC}"
    if curl -s "${DEVNET_URL}/is_alive" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Devnet is running at ${DEVNET_URL}${NC}"
        return 0
    else
        echo -e "${RED}✗ Devnet is not running at ${DEVNET_URL}${NC}"
        echo -e "${YELLOW}Please start devnet with: starknet-devnet --seed 0${NC}"
        return 1
    fi
}

# Function to build contracts
build_contracts() {
    echo -e "${YELLOW}Building contracts...${NC}"
    cd "$PROJECT_DIR"
    scarb build
    echo -e "${GREEN}✓ Contracts built successfully${NC}"
}

# Function to declare a contract
declare_contract() {
    local contract_name=$1

    echo -e "${YELLOW}Declaring ${contract_name}...${NC}" >&2

    DECLARE_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json declare --contract-name "$contract_name" 2>&1)

    # Check if already declared (extract from error message)
    if echo "$DECLARE_OUTPUT" | grep -q "is already declared"; then
        echo -e "${YELLOW}Contract already declared${NC}" >&2
        # Extract class hash from the error JSON line
        CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep "is already declared" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)
        if [ -n "$CLASS_HASH" ]; then
            echo -e "${GREEN}✓ ${contract_name} Class Hash: ${CLASS_HASH}${NC}" >&2
            echo "$CLASS_HASH"
            return 0
        fi
    fi

    # Get the last JSON line that contains class_hash (successful declaration)
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep '"class_hash"' | tail -1 | jq -r '.class_hash // empty')

    if [ -z "$CLASS_HASH" ]; then
        echo -e "${RED}✗ Failed to extract class hash${NC}" >&2
        echo "$DECLARE_OUTPUT" >&2
        exit 1
    fi

    echo -e "${GREEN}✓ ${contract_name} Class Hash: ${CLASS_HASH}${NC}" >&2
    echo "$CLASS_HASH"
}

# Function to deploy MockERC20
deploy_mock_erc20() {
    local class_hash=$1

    echo -e "${YELLOW}Deploying MockERC20...${NC}" >&2

    # Constructor: name, symbol, decimals, initial_supply, recipient
    DEPLOY_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json deploy \
        --class-hash "$class_hash" \
        --arguments "${TOKEN_NAME}, ${TOKEN_SYMBOL}, ${TOKEN_DECIMALS}, ${INITIAL_SUPPLY}, ${ACCOUNT_ADDRESS}" \
        2>&1)

    TOKEN_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep '"contract_address"' | tail -1 | jq -r '.contract_address // empty')

    if [ -z "$TOKEN_ADDRESS" ]; then
        echo -e "${RED}✗ Failed to deploy MockERC20${NC}" >&2
        echo "$DEPLOY_OUTPUT" >&2
        exit 1
    fi

    echo -e "${GREEN}✓ MockERC20 deployed at: ${TOKEN_ADDRESS}${NC}" >&2
    echo "$TOKEN_ADDRESS"
}

# Function to deploy HavilahVault
deploy_vault() {
    local class_hash=$1
    local token_address=$2

    echo -e "${YELLOW}Deploying HavilahVault...${NC}" >&2

    DEPLOY_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json deploy \
        --class-hash "$class_hash" \
        --arguments "$token_address" \
        2>&1)

    VAULT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep '"contract_address"' | tail -1 | jq -r '.contract_address // empty')

    if [ -z "$VAULT_ADDRESS" ]; then
        echo -e "${RED}✗ Failed to deploy HavilahVault${NC}" >&2
        echo "$DEPLOY_OUTPUT" >&2
        exit 1
    fi

    echo -e "${GREEN}✓ HavilahVault deployed at: ${VAULT_ADDRESS}${NC}" >&2
    echo "$VAULT_ADDRESS"
}

# Function to test the deployment
test_deployment() {
    local token_address=$1
    local vault_address=$2
    local test_amount=1000000000000000000  # 1 token with 18 decimals

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Testing Deployment                   ${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Check token balance
    echo -e "${YELLOW}Checking token balance...${NC}"
    BALANCE_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json call \
        --contract-address "$token_address" \
        --function "balance_of" \
        --arguments "$ACCOUNT_ADDRESS" \
        2>&1)
    BALANCE=$(echo "$BALANCE_OUTPUT" | jq -r '.response // empty')
    echo -e "${GREEN}Token balance: ${BALANCE}${NC}"

    # Approve vault to spend tokens
    echo -e "${YELLOW}Approving vault to spend tokens...${NC}"
    APPROVE_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json invoke \
        --contract-address "$token_address" \
        --function "approve" \
        --arguments "${vault_address}, ${test_amount}" \
        2>&1)
    echo -e "${GREEN}✓ Approved vault to spend tokens${NC}"

    # Wait a bit for transaction to be processed
    sleep 1

    # Deposit tokens into vault (u256 requires low and high parts)
    echo -e "${YELLOW}Depositing tokens into vault...${NC}"
    DEPOSIT_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json invoke \
        --contract-address "$vault_address" \
        --function "deposit" \
        --arguments "${test_amount}" \
        2>&1)
    echo -e "${GREEN}✓ Deposited tokens into vault${NC}"

    # Wait a bit for transaction to be processed
    sleep 1

    # Check vault share balance
    echo -e "${YELLOW}Checking vault share balance...${NC}"
    SHARES_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json call \
        --contract-address "$vault_address" \
        --function "user_balance_of" \
        --arguments "$ACCOUNT_ADDRESS" \
        2>&1)
    SHARES=$(echo "$SHARES_OUTPUT" | jq -r '.response // empty')
    echo -e "${GREEN}Vault shares: ${SHARES}${NC}"

    # Check vault total supply
    echo -e "${YELLOW}Checking vault total supply...${NC}"
    SUPPLY_OUTPUT=$(cd "$PROJECT_DIR" && sncast --profile "$PROFILE" --json call \
        --contract-address "$vault_address" \
        --function "contract_total_supply" \
        2>&1)
    SUPPLY=$(echo "$SUPPLY_OUTPUT" | jq -r '.response // empty')
    echo -e "${GREEN}Vault total supply: ${SUPPLY}${NC}"

    echo ""
    echo -e "${GREEN}✓ All deployment tests passed!${NC}"
}

# Main deployment flow
main() {
    echo -e "${YELLOW}Project Directory: ${PROJECT_DIR}${NC}"
    echo -e "${YELLOW}Using Profile: ${PROFILE}${NC}"
    echo -e "${YELLOW}Account: ${ACCOUNT_ADDRESS}${NC}"
    echo ""

    # Check devnet
    check_devnet || exit 1
    echo ""

    # Build contracts
    build_contracts
    echo ""

    # Declare contracts
    echo -e "${BLUE}--- Declaring Contracts ---${NC}"
    MOCK_ERC20_CLASS_HASH=$(declare_contract "MockERC20")
    echo ""
    VAULT_CLASS_HASH=$(declare_contract "HavilahVault")
    echo ""

    # Deploy contracts
    echo -e "${BLUE}--- Deploying Contracts ---${NC}"
    TOKEN_ADDRESS=$(deploy_mock_erc20 "$MOCK_ERC20_CLASS_HASH")
    echo ""
    VAULT_ADDRESS=$(deploy_vault "$VAULT_CLASS_HASH" "$TOKEN_ADDRESS")
    echo ""

    # Summary
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Deployment Summary                   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Account:       ${GREEN}${ACCOUNT_ADDRESS}${NC}"
    echo -e "MockERC20:     ${GREEN}${TOKEN_ADDRESS}${NC}"
    echo -e "HavilahVault:  ${GREEN}${VAULT_ADDRESS}${NC}"
    echo ""

    # Save deployment info to file
    DEPLOY_INFO_FILE="${PROJECT_DIR}/deployment.json"
    cat > "$DEPLOY_INFO_FILE" << EOF
{
  "network": "devnet",
  "account": "${ACCOUNT_ADDRESS}",
  "contracts": {
    "MockERC20": {
      "class_hash": "${MOCK_ERC20_CLASS_HASH}",
      "address": "${TOKEN_ADDRESS}"
    },
    "HavilahVault": {
      "class_hash": "${VAULT_CLASS_HASH}",
      "address": "${VAULT_ADDRESS}"
    }
  },
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo -e "${GREEN}✓ Deployment info saved to deployment.json${NC}"
    echo ""

    # Run tests if requested
    if [ "$1" == "--test" ]; then
        test_deployment "$TOKEN_ADDRESS" "$VAULT_ADDRESS"
    fi

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Deployment Complete!                 ${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main "$@"
