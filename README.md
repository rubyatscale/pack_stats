# ModularizationStatistics

This gem is used to report opinionated statistics about modularization to DataDog and other observability systems.

# Usage
The main method to this gem is `ModularizationStatistics#report_to_datadog!`. Refer to the Sorbet signature for this method for the exact types to be passed in.

This is an example of how to use this API:

```ruby
ModularizationStatistics.report_to_datadog!(
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
  # 
  # A file is determined to be packaged if it exists in any of these directories.
  # This is an array of `Pathname`. `Pathname` can be relative or absolute paths.
  #
  # Example: [Pathname.new("./packs")]
  #
  packaged_source_code_locations: packaged_source_code_locations,
)
```

# Using Other Observability Tools

Right now this tool sends metrics to DataDog early. However, if you want to use this with other tools, you can call `ModularizationStatistics.get_metrics(...)` to get generic metrics that you can then send to whatever observability provider you use.

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
