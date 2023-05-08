# typed: strict

module PackStats
  module Private
    extend T::Sig

    sig { params(package: ParsePackwerk::Package).returns(T.nilable(String) )}
    def self.package_owner(package)
      pack = Packs.find(package.name)
      return nil if pack.nil?
      CodeOwnership.for_package(pack)&.name
    end
  end

  private_constant :Private
end
