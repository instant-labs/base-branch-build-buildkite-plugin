# Base Branch Build Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/plugins) that finds the last successful build of the base branch of a pull request. It exports the UUID of that build as `BASE_BRANCH_LAST_SUCCESSFUL_BUILD`, so that later steps can download the artifacts of the base branch.

The `branch` option selects a branch such as `main` instead of the base branch. Use it to read the artifacts of `main` in a build that is not a pull request build.

The plugin does nothing in these two cases:

- The build is not a pull request build and the `branch` option is not set.
- The branch has no successful build.

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - label: ":typescript: lint"
    command: "bun run lint"
    plugins:
      - instant-labs/base-branch-build#v1.0.0:
```

The value is available to the steps that run after the hook:

```yml
steps:
  - label: ":typescript: lint"
    command: "buildkite-agent artifact download --build \"$BASE_BRANCH_LAST_SUCCESSFUL_BUILD\" 'dist/*' ."
    plugins:
      - instant-labs/base-branch-build#v1.0.0:
```

A step that runs the command in a container must pass the variable into the container. For example, with the `docker` plugin:

```yml
steps:
  - label: ":typescript: lint"
    command: "bun run lint"
    plugins:
      - instant-labs/base-branch-build#v1.0.0:
      - docker#v5.11.0:
          image: node
          environment:
            - BASE_BRANCH_LAST_SUCCESSFUL_BUILD
```

## Configuration

### `branch` (optional, string)

The branch to look up. The plugin uses `BUILDKITE_PULL_REQUEST_BASE_BRANCH` when you do not set this option, and it does nothing when the build is not a pull request build.

Set the option to look up one branch in every build:

```yml
steps:
  - label: ":typescript: lint"
    command: "bun run lint"
    plugins:
      - instant-labs/base-branch-build#v1.0.0:
          branch: main
```

## Environment

| Variable | Description |
| :------- | :---------- |
| `BUILDKITE_API_TOKEN` | Required. A Buildkite API access token with the `read_builds` scope. |

The agent sets the other variables that the plugin reads: `BUILDKITE_PULL_REQUEST`, `BUILDKITE_PULL_REQUEST_BASE_BRANCH`, `BUILDKITE_ORGANIZATION_SLUG` and `BUILDKITE_PIPELINE_SLUG`.

## Security

- Give the token the `read_builds` scope only. The plugin reads the build list of one pipeline.
- Pin the plugin to a tag, as the examples show. A branch reference lets a new commit run in your pipeline.
- The plugin passes the token to `curl` in a file, not in an argument. An argument is visible in the process list of the agent, and the agent prints every command when it runs in debug mode.
- The plugin runs in the `environment` hook, which is before the checkout. It reads no file from the repository.

## Requirements

- `bash`
- `curl`
- `jq`

## Developing

Run the tests, the linter and shellcheck with Docker:

```bash
make test
make lint
make shellcheck
```

## License

MIT (see [LICENSE](LICENSE))
