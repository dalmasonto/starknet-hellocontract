#!/usr/bin/bash

# First, lets delete the open zeppelin accounts json file
file_path="$HOME/.starknet_accounts/starknet_open_zeppelin_accounts.json"
rm -rf $file_path

# An array of accounts you want to add
accounts_json=$(
    cat <<EOF
[
    {
        "name": "account1",
        "address": "0x7f61fa3893ad0637b2ff76fed23ebbb91835aacd4f743c2347716f856438429",
        "private_key": "0x259f4329e6f4590b9a164106cf6a659e"
    },
    {
        "name": "account2",
        "address": "0x53c615080d35defd55569488bc48c1a91d82f2d2ce6199463e095b4a4ead551",
        "private_key": "0xb4862b21fb97d43588561712e8e5216a"
    }
]
EOF
)

PROFILE_NAME="account1"       # This profile will be used to make the sign the calls
CONTRACT_NAME="HelloStarknet" # Contract name here
CLASS_HASH=""
FAILED_TESTS=false

# Step 1: Testing
echo " "
echo "Testing the contract..."
testing_result=$(snforge 2>&1)
if echo "$testing_result" | grep -q "Failure"; then
    echo "Tests failed to pass!!!"
    echo ""
    snforge
    echo " "
    echo "Make sure your tests are passing"
    echo " "
    FAILED_TESTS=true
fi

if [ "$FAILED_TESTS" != "true" ]; then
    echo "Tests passed!!!"
    echo " "
    echo "Creating account(s)"

    # Step 2: Add a new account(s)
    for row in $(echo "${accounts_json}" | jq -c '.[]'); do
        # Extract values from JSON
        name=$(echo "${row}" | jq -r '.name')
        address=$(echo "${row}" | jq -r '.address')
        private_key=$(echo "${row}" | jq -r '.private_key')
        # Call the sncast command for each account
        account_creation_result=$(sncast --url http://localhost:5050/rpc account add --name "$name" --address "$address" --private-key "$private_key" --add-profile 2>&1)
        if echo "$account_creation_result" | grep -q "error:"; then
            echo "Account $name already exists"
        else
            echo "Account: $name created successfully."
        fi
    done

    # Step 3: Build the contract
    echo " "
    echo "Building the contract"
    scarb build

    # Step 4: Declare the contract
    echo " "
    echo "Declaring the contract..."
    declaration_output=$(sncast --profile $PROFILE_NAME --wait declare --contract-name $CONTRACT_NAME 2>&1)
    if echo "$declaration_output" | grep -q "error: Class with hash"; then
        echo "Class hash already declared"
        class_hash=$(echo "$declaration_output" | sed -n 's/.*Class with hash \([^ ]*\).*/\1/p')
        CLASS_HASH=$class_hash
    else
        echo "New class hash declaration"
        class_hash=$(echo "$declaration_output" | grep -o 'class_hash: 0x[^ ]*' | sed 's/class_hash: //')
        CLASS_HASH=$class_hash
    fi

    echo "Class Hash: $CLASS_HASH"

    # Step 5: Deploy the contract
    echo " "
    echo "Deploying the contract..."
    deployment_result=$(sncast --profile $PROFILE_NAME deploy --class-hash "$CLASS_HASH")
    CONTRACT_ADDRESS=$(echo "$deployment_result" | grep -o "contract_address: 0x[^ ]*" | awk '{print $2}')
    echo "Contract address: $CONTRACT_ADDRESS"

    # Step 6: Perform a multicall
    echo " "
    echo "Performing a multicall..."

    # Create a multicall .toml file and add some calls there.
    MULTICALL_FILE="multicall.toml"
    echo "[[call]]" >"$MULTICALL_FILE"
    echo "call_type = 'invoke'" >>"$MULTICALL_FILE"
    echo "contract_address = '$CONTRACT_ADDRESS'" >>"$MULTICALL_FILE"
    echo "function = 'increase_balance'" >>"$MULTICALL_FILE"
    echo "inputs = ['0x1']" >>"$MULTICALL_FILE"

    # Create some space between the two calls
    echo " " >>"$MULTICALL_FILE"

    echo "[[call]]" >>"$MULTICALL_FILE"
    echo "call_type = 'invoke'" >>"$MULTICALL_FILE"
    echo "contract_address = '$CONTRACT_ADDRESS'" >>"$MULTICALL_FILE"
    echo "function = 'increase_balance'" >>"$MULTICALL_FILE"
    echo "inputs = ['0x2']" >>"$MULTICALL_FILE"

    # Run the multicall
    sncast --profile $PROFILE_NAME multicall run --path "$MULTICALL_FILE"

    echo " "

    echo "Checking balance"
    sncast --profile $PROFILE_NAME call --contract-address $CONTRACT_ADDRESS --function get_balance
    echo " "

    # Step 7: Clean up
    # Clean up the multicall file by deleting it
    [ -e "$MULTICALL_FILE" ] && rm "$MULTICALL_FILE"

    echo "Script completed successfully"
    echo " "
fi
