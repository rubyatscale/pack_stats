# typed: strict

module PackStats
  module Private
    class SourceCodeFile < T::Struct
      extend T::Sig

      const :is_componentized_file, T::Boolean
      const :is_packaged_file, T::Boolean
      const :team_owner, T.nilable(CodeTeams::Team)
      const :pathname, Pathname

      sig { returns(T::Boolean) }
      def componentized_file?
        self.is_componentized_file
      end

      sig { returns(T::Boolean) }
      def packaged_file?
        self.is_packaged_file
      end
    end
  end
end
