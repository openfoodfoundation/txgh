require 'octokit'

module Txgh
  class GithubApi
    class << self
      def create_from_credentials(login, access_token)
        create_from_client(
          Octokit::Client.new(login: login, access_token: access_token)
        )
      end

      def create_from_client(client)
        new(client)
      end
    end

    attr_reader :client

    def initialize(client)
      @client = client
    end

    def tree(repo, sha)
      client.tree(repo, sha, recursive: 1)
    end

    def blob(repo, sha)
      client.blob(repo, sha)
    end

    def create_ref(repo, branch, sha)
      client.create_ref(repo, branch, sha) rescue false
    end

    def commit(repo, branch, path, content)
      blob = client.create_blob(repo, content)
      master = client.ref(repo, branch)
      base_commit = get_commit(repo, master[:object][:sha])

      tree_data = [{ path: path, mode: '100644', type: 'blob', sha: blob }]
      tree_options = { base_tree: base_commit[:commit][:tree][:sha] }

      tree = client.create_tree(repo, tree_data, tree_options)
      commit = client.create_commit(
        repo, "Updating translations for #{path}", tree[:sha], master[:object][:sha]
      )

      force_push = false
      client.update_ref(repo, branch, commit[:sha], force_push)
    end

    def commit_or_create_branch(repo, branch, path, content)
      blob = client.create_blob(repo, content)
      base = base_commit(repo, branch)
      base_sha = base[:object][:sha]

      tree_data = [{ path: path, mode: '100644', type: 'blob', sha: blob }]
      tree_options = { base_tree: base_sha }

      tree = client.create_tree(repo, tree_data, tree_options)
      commit = client.create_commit(
        repo, "Updating translations for #{path}", tree[:sha], base_sha
      )

      if base[:ref] == "refs/#{branch}"
        client.update_ref(repo, branch, commit[:sha])
      else
        client.create_ref(repo, branch, commit[:sha])
      end
    end

    def base_commit(repo, branch, base = "heads/master")
      client.ref(repo, branch)
    rescue Octokit::NotFound
      client.ref(repo, base)
    end

    def get_commit(repo, sha)
      client.commit(repo, sha)
    end

    def create_pull_request(repo, branch)
      base = "master"
      head = branch.split("/", 2).last
      title = "Transifex"
      body = "Automatically created by our CI server."
      client.create_pull_request(repo, base, head, title, body)
    end

    def pull_request_open?(repo, branch)
      repo_user_name = repo.split("/", 2).first
      branch_name = branch.split("/", 2).last
      head = "#{repo_user_name}:#{branch_name}"
      ! client.pulls(repo, {state: "open", head: head}).empty?
    end

    def commit_to_pull_request(repo, branch, path, content)
      commit_or_create_branch(repo, branch, path, content)
      create_pull_request(repo, branch) unless pull_request_open?(repo, branch)
    end
  end
end
