require 'parser/current'
require 'astrolabe/builder'

module Rails5
  module SpecConverter
    class TestTypeIdentifier
      DIRECTORY_TO_TYPE_MAP = {
        'controllers' => :controller,
        'requests'    => :request,
        'integration' => :request,
        'api'         => :request
      }

      def initialize(content, options = TextTransformerOptions.new)
        @options = options
        @content = content

        @source_buffer = Parser::Source::Buffer.new('(string)')
        @source_buffer.source = @content

        ast_builder = Astrolabe::Builder.new
        @parser = Parser::CurrentRuby.new(ast_builder)

        @source_rewriter = Parser::Source::Rewriter.new(@source_buffer)
      end

      def test_type
        test_type_from_content || test_type_from_filename || test_type_default
      end

      private

      def test_type_default
        :request
      end

      def test_type_from_content
        root_node = @parser.parse(@source_buffer)
        root_node.each_node(:send) do |node|
          target, method, test_name, params = node.children
          next unless target.nil? || target == :RSpec
          next unless method == :describe

          return type_from_params_hash(params)
        end

        nil
      end

      def test_type_from_filename
        return nil unless @options.file_path

        dirs = @options.file_path.split('/')
        spec_folder_index = dirs.index('spec')
        return nil unless spec_folder_index
        DIRECTORY_TO_TYPE_MAP[dirs[spec_folder_index + 1]]
      end

      def type_from_params_hash(params)
        return nil unless params && params.hash_type?

        params.children.each do |node|
          if node.pair_type? && node.children.all?(&:sym_type?)
            key, value = node.children.map { |sym| sym.children.first }
            return :controller if key == :type && value == :controller
            return :request if key == :type && value == :request
          end
        end

        nil
      end
    end
  end
end