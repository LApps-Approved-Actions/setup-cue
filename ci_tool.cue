package action

import (
	"encoding/yaml"
	"strings"
	"path"
	"tool/http"
	"tool/file"
	"tool/exec"
)

_goos: *"unix" | string @tag(os,var=os)

#repoRoot: exec.Run & {
	cmd:    "git rev-parse --show-toplevel"
	stdout: string
}

// vendorgithubschema "vendors" 'cue import'-ed versions of the GitHub
// action and workflow schemas into cue.mod/pkg
//
// Under the proposal for CUE packagemanagement, this command is
// redundant.
command: vendorgithubschema: {
	repoRoot: #repoRoot

	getActionJSONSchema: http.Get & {
		// Tip link for humans:
		// https://github.com/SchemaStore/schemastore/blob/master/src/schemas/json/github-action.json
		url: "https://raw.githubusercontent.com/SchemaStore/schemastore/c3d4b35e7bbd40b2a95191e393f8c0bad340e97f/src/schemas/json/github-action.json"
	}

	importActionJSONSchema: exec.Run & {
		stdin:  getActionJSONSchema.response.body
		cmd:    "cue import -f -p github -l #Action: jsonschema: - -o -"
		stdout: string
	}

	vendorGitHubActionSchema: file.Create & {
		_path: path.FromSlash("cue.mod/pkg/json.schemastore.org/github/github-action.cue", "unix")
		filename: path.Join([strings.TrimSpace(repoRoot.stdout), _path], _goos)
		contents: importActionJSONSchema.stdout
	}

	getWorkflowJSONSchema: http.Get & {
		// Tip link for humans:
		// https://github.com/SchemaStore/schemastore/blob/master/src/schemas/json/github-workflow.json
		url: "https://raw.githubusercontent.com/SchemaStore/schemastore/6fe4707b9d1c5d45cfc8d5b6d56968e65d2bdc38/src/schemas/json/github-workflow.json"
	}

	importWorkflowJSONSchema: exec.Run & {
		stdin:  getWorkflowJSONSchema.response.body
		cmd:    "cue import -f -p github -l #Workflow: jsonschema: - -o -"
		stdout: string
	}

	vendorGitHubWorkflowSchema: file.Create & {
		_path: path.FromSlash("cue.mod/pkg/json.schemastore.org/github/github-workflow.cue", "unix")
		filename: path.Join([strings.TrimSpace(repoRoot.stdout), _path], _goos)
		contents: importWorkflowJSONSchema.stdout
	}
}

// genworkflows exports workflow configurations to .yml files.
//
// When the as-yet-unpublished embeding example is implemented,
// this command will become superfluous and could be replaced
// by a cue export call.
command: genworkflows: {
	repoRoot: #repoRoot

	for _, w in workflows {
		"\(w.filename)": file.Create & {
			_path: path.FromSlash(".github/workflows", "unix")
			filename: path.Join([strings.TrimSpace(repoRoot.stdout), _path, w.filename], _goos)
			contents: """
					# Generated by cue cmd genworkflows; do not edit

					\(yaml.Marshal(w.workflow))
					"""
		}
	}
}
