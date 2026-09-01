#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty

BUILD_ID="0193c2f1-2c9a-7f3e-9f21-5a6b7c8d9e0f"

setup() {
    export BUILDKITE_JOB_ID="1-2-3-4"
    export BUILDKITE_AGENT_ID="1234"
    export BUILDKITE_AGENT_NAME="agent"
    export BUILDKITE_BUILD_NUMBER=1
    export BUILDKITE_LABEL="Test Job"
    export BUILDKITE_ORGANIZATION_SLUG="acme-corp"
    export BUILDKITE_PIPELINE_NAME="test-pipeline"
    export BUILDKITE_PIPELINE_SLUG="test-pipeline"
    export BUILDKITE_API_TOKEN="testtoken"
    unset BUILDKITE_PLUGIN_BASE_BRANCH_BUILD_BRANCH
}

@test "Skips if not a PR" {
    export BUILDKITE_PULL_REQUEST=false

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "Not a pull request and no branch option, skipping base branch build lookup"
}

@test "Uses the branch option when the build is not a pull request" {
    export BUILDKITE_PULL_REQUEST=false
    export BUILDKITE_PLUGIN_BASE_BRANCH_BUILD_BRANCH="main"

    stub curl \
        "--silent --show-error --fail --max-time 30 --retry 3 --config - --get --data-urlencode branch=main --data-urlencode state=passed --data-urlencode per_page=1 https://api.buildkite.com/v2/organizations/acme-corp/pipelines/test-pipeline/builds : echo '[{\"number\": 42, \"id\": \"$BUILD_ID\"}]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "Found successful build #42 ($BUILD_ID) for branch main"

    unstub curl
}

@test "The branch option replaces the base branch of the pull request" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="feature/parent"
    export BUILDKITE_PLUGIN_BASE_BRANCH_BUILD_BRANCH="main"

    stub curl \
        "--silent --show-error --fail --max-time 30 --retry 3 --config - --get --data-urlencode branch=main --data-urlencode state=passed --data-urlencode per_page=1 https://api.buildkite.com/v2/organizations/acme-corp/pipelines/test-pipeline/builds : echo '[]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "No successful builds found for branch main"

    unstub curl
}

@test "Does not need a base branch when the branch option is set" {
    export BUILDKITE_PULL_REQUEST=123
    unset BUILDKITE_PULL_REQUEST_BASE_BRANCH
    export BUILDKITE_PLUGIN_BASE_BRANCH_BUILD_BRANCH="main"

    stub curl "::echo '[]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "No successful builds found for branch main"

    unstub curl
}

@test "Fails without base branch" {
    export BUILDKITE_PULL_REQUEST=123
    unset BUILDKITE_PULL_REQUEST_BASE_BRANCH

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: BUILDKITE_PULL_REQUEST_BASE_BRANCH environment variable is required"
}

@test "Fails without API token" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"
    unset BUILDKITE_API_TOKEN

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: BUILDKITE_API_TOKEN environment variable is required"
}

@test "Fails without organization slug" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"
    unset BUILDKITE_ORGANIZATION_SLUG

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: BUILDKITE_ORGANIZATION_SLUG environment variable is required"
}

@test "Fails on a token that can add a header" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"
    export BUILDKITE_API_TOKEN='token"
header = "X-Injected: yes'

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: BUILDKITE_API_TOKEN contains characters that are not valid"
}

@test "Fails on a pipeline slug that changes the request path" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"
    export BUILDKITE_PIPELINE_SLUG="test-pipeline/../../other-org/pipelines/other"

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: BUILDKITE_PIPELINE_SLUG contains characters that are not valid"
}

@test "Handles successful API response" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::echo '[{\"number\": 42, \"id\": \"$BUILD_ID\"}]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "Found successful build #42 ($BUILD_ID) for branch main"

    unstub curl
}

@test "Exports the build id" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::echo '[{\"number\": 42, \"id\": \"$BUILD_ID\"}]'"

    run bash -c "source '$PWD/hooks/environment' && echo \"exported=\$BASE_BRANCH_LAST_SUCCESSFUL_BUILD\""

    assert_success
    assert_output --partial "exported=$BUILD_ID"

    unstub curl
}

@test "Passes the branch as an encoded parameter and reads the token from stdin" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH='release&state=failed'

    stub curl \
        "--silent --show-error --fail --max-time 30 --retry 3 --config - --get --data-urlencode 'branch=release&state=failed' --data-urlencode state=passed --data-urlencode per_page=1 https://api.buildkite.com/v2/organizations/acme-corp/pipelines/test-pipeline/builds : echo '[]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "No successful builds found for branch release&state=failed"

    unstub curl
}

@test "Passes the token on stdin and writes no file" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::cat >'$BATS_TEST_TMPDIR/config'; echo '[]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_equal "$(cat "$BATS_TEST_TMPDIR/config")" 'header = "Authorization: Bearer testtoken"'

    unstub curl
}

@test "Handles no successful builds" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::echo '[]'"

    run "$PWD/hooks/environment"

    assert_success
    assert_output --partial "No successful builds found for branch main"

    unstub curl
}

@test "Fails when the API request fails" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::exit 22"

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: the request to the Buildkite API failed"

    unstub curl
}

@test "Fails when the API response is not a list of builds" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::echo '{\"message\": \"Not Found\"}'"

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: the Buildkite API sent a response that is not a list of builds"

    unstub curl
}

@test "Fails on a build id that is not a UUID" {
    export BUILDKITE_PULL_REQUEST=123
    export BUILDKITE_PULL_REQUEST_BASE_BRANCH="main"

    stub curl "::echo '[{\"number\": 42, \"id\": \"\$(whoami)\"}]'"

    run "$PWD/hooks/environment"

    assert_failure
    assert_output --partial "Error: the Buildkite API returned a build id that is not a UUID"

    unstub curl
}
