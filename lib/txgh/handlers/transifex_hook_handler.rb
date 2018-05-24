require 'logger'

module Txgh
  module Handlers
    class TransifexHookHandler
      include Txgh::CategorySupport

      attr_reader :project, :repo, :resource_slug, :language, :tx_hook_trigger, :logger

      def initialize(options = {})
        @project = options.fetch(:project)
        @repo = options.fetch(:repo)
        @resource_slug = options.fetch(:resource_slug)
        @language = options.fetch(:language)
        @tx_hook_trigger = options.fetch(:tx_hook_trigger)
        @logger = options.fetch(:logger) { Logger.new(STDOUT) }
      end

      def execute
        logger.info(resource_slug)
        # Check if push trigger is set in project config
        if project.push_trigger_set?
          trigger = project.push_trigger
        # If not set trigger to current payload trigger value
        else
          trigger = tx_hook_trigger
        end
        # Only execute if trigger matches TX hook trigger
        if tx_resource && tx_hook_trigger==trigger
        # Do not update the source
          unless language == tx_resource.source_lang
            logger.info('request language matches resource')

            translations = project.api.download(tx_resource, language)

            translation_path = if tx_resource.lang_map(language) != language
              logger.info('request language is in lang_map and is not in request')
              tx_resource.translation_path(tx_resource.lang_map(language))
            else
              logger.info('request language is in lang_map and is in request or is nil')
              tx_resource.translation_path(project.lang_map(language))
            end

            logger.info("make github commit for branch: #{branch}")

            repo.api.commit_to_pull_request(
              repo.name, branch, translation_path, translations
            )
          end
        elsif 
          tx_hook_trigger!=project.push_trigger
          logger.info("did not process changes because trigger was '#{tx_hook_trigger}' and push trigger was set to '#{project.push_trigger}'")
        else
          raise TxghError,
            "Could not find configuration for resource '#{resource_slug}'"
        end
      end

      private

      def branch
        branch_candidate = if process_all_branches?
          tx_resource.branch
        else
          repo.branch || 'master'
        end

        if branch_candidate.include?('tags/')
          branch_candidate
        elsif branch_candidate.include?('heads/')
          branch_candidate
        else
          "heads/#{branch_candidate}"
        end
      end

      def tx_resource
        @tx_resource ||= if process_all_branches?
          resource = project.api.get_resource(project.name, resource_slug)
          categories = deserialize_categories(Array(resource['categories']))
          project.resource(resource_slug, categories['branch'])
        else
          project.resource(resource_slug)
        end
      end

      def process_all_branches?
        repo.branch == 'all'
      end
    end
  end
end
