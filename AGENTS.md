This file provides guidance to AI coding agents when working with code in this repository.

## What this project is

`pack_stats` collects and reports modularization statistics about a Rails application using packwerk. It sends opinionated metrics (e.g. violation counts, pack sizes, ownership breakdown) to DataDog and other observability systems.

## Commands

```bash
bundle install

# Run all tests (RSpec)
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/path/to/spec.rb

# Type checking (Sorbet)
bundle exec srb tc
```

## Architecture

- `lib/pack_stats.rb` — entry point; `PackStats.report_to_datadog!` is the primary public method
- `lib/pack_stats/` — metric collectors (per-pack and per-team stats), DataDog gauge/distribution reporters, and configuration
- `spec/` — RSpec tests
