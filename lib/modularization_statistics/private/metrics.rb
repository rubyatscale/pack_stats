# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      extend T::Sig
      UNKNOWN_OWNER = T.let('Unknown', String)

      sig { params(team_name: T.nilable(String)).returns(T::Array[Tag]) }
      def self.tags_for_team(team_name)
        [Tag.for('team', team_name || UNKNOWN_OWNER)]
      end
    end
  end
end
