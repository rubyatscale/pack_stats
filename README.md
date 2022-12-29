# PackStats

This gem is used to report opinionated statistics about modularization to DataDog and other observability systems.

# Configuring Ownership
The gem reports metrics per-team, where each team is configured based on metadata included in Packwerk package.yml files.

Define your teams as described in the [Code Team - Package Based Ownership](https://github.com/rubyatscale/code_ownership#package-based-ownership) documentation.

# Usage
The main method to this gem is `PackStats#report_to_datadog!`. Refer to the Sorbet signature for this method for the exact types to be passed in.

This is an example of how to use this API:

```ruby
PackStats.report_to_datadog!(
  #
  # A properly initialized `Dogapi::Client`
  # Example: Dogapi::Client.new(ENV.fetch('DATADOG_API_KEY')
  #
  datadog_client: datadog_client,
  #
  # Time attached to the metrics
  # Example: Time.now
  #
  report_time: report_time
  #
  # This is used to determine what files to look at for building statistics about what types of files are packaged, componentized, or unpackaged.
  # This is an array of `Pathname`. `Pathname` can be relative or absolute paths.
  #
  # Example: source_code_pathnames = Pathname.glob('./**/**.rb')
  #
  source_code_pathnames: source_code_pathnames,
  #
  # A file is determined to be componentized if it exists in any of these directories.
  # This is an array of `Pathname`. `Pathname` can be relative or absolute paths.
  #
  # Example: [Pathname.new("./gems")]
  #
  componentized_source_code_locations: componentized_source_code_locations,
)
```

It's recommended to run this in CI on the main/development branch so each new commit has metrics emitted for it.

# Tracking Privacy and Dependency Violations Reliably
With [`packwerk`](https://github.com/Shopify/packwerk), privacy and dependency violations do not show up until a package has set `enforce_privacy` and `enforce_dependency` (respectively) to `true`. As such, when you're first starting off, you'll see no violations, and then periodic large increases as teams start using these protections. If you're interested in looking at privacy and dependency violations over time as if all packages were enforcing dependencies and privacy the whole time, we recommend setting these values to be true before running modularization statistics in your CI.

```ruby
require 'pack_stats'

namespace(:modularization) do
  desc(
    'Publish modularization stats to datadog. ' \
      'Example: bin/rails "modularization:upload_statistics"'
  )
  task(:upload_statistics, [:verbose] => :environment) do |_, args|
    ignored_paths = Pathname.glob('spec/fixtures/**/**')
    source_code_pathnames = Pathname.glob('{app,components,lib,packs,spec}/**/**').select(&:file?) - ignored_paths

    # To correctly track violations, we rewrite all `package.yml` files with
    # `enforce_dependencies` and `enforce_privacy` set to true, then update deprecations.
    old_packages = ParsePackwerk.all
    old_packages.each do |package|
      new_package = ParsePackwerk::Package.new(
        dependencies: package.dependencies,
        enforce_dependencies: true,
        enforce_privacy: true,
        metadata: package.metadata,
        name: package.name
      )
      ParsePackwerk.write_package_yml!(new_package)
    end

    Packwerk::Cli.new.execute_command(['update-deprecations'])

    # Now we reset it back so that the protection values are the same as the native packwerk configuration
    old_packages.each do |package|
      new_package = ParsePackwerk::Package.new(
        dependencies: package.dependencies,
        enforce_dependencies: package.enforce_dependencies,
        enforce_privacy: package.enforce_privacy,
        metadata: package.metadata,
        name: package.name
      )
      ParsePackwerk.write_package_yml!(new_package)
    end

    PackStats.report_to_datadog!(
      datadog_client: Dogapi::Client.new(ENV.fetch('DATADOG_API_KEY')),
      app_name: Rails.application.class.module_parent_name,
      source_code_pathnames: source_code_pathnames,
      verbose: args[:verbose] == 'true' || false
    )
  end
end
```

# Using Other Observability Tools

Right now this tool sends metrics to DataDog early. However, if you want to use this with other tools, you can call `PackStats.get_metrics(...)` to get generic metrics that you can then send to whatever observability provider you use.

# Setting Up Your Dashboards

Gusto has two dashboards that we've created to view these metrics. We've also exported and released the Dashboard JSON for each of these dashboards. You can create a new dashboard and then click "import dashboard JSON" to get a jump start on tracking your metrics. Note you may want to make some tweaks to these dashboards to better fit your organization's circumstances and goals.

## [Modularization] Executive Summary

This helps answer questions like:
- How are we doing on reducing dependency and privacy violations in your monolith overall?
- How are we doing overall on adopting package protections?

[Dashboard JSON](docs/executive_summary.json)

## [Modularization] Per-Package and Per-Team
- How is each team and package doing on reducing dependency and privacy violations in your monolith?
- What is the total count of dependency/privacy violations for each pack/team and what's the change since last month?
- Which pack/team does my pack/team have the most dependency/privacy violations on?

[Dashboard JSON](docs/per_package_and_per_team.json)
