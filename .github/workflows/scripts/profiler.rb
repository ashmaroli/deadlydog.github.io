# frozen_string_literal: true

require "jekyll"
require "memory_profiler"

class Profiler
  def self.report
    report = MemoryProfiler.report { yield }

    Jekyll.logger.info "", "and done. Generating results.."
    Jekyll.logger.info ""

    total_allocated_output = report.scale_bytes(report.total_allocated_memsize)
    total_retained_output  = report.scale_bytes(report.total_retained_memsize)

    Jekyll.logger.info "Total allocated: #{total_allocated_output} (#{report.total_allocated} objects)"
    Jekyll.logger.info "Total retained:  #{total_retained_output} (#{report.total_retained} objects)"
  end
end

# --

case ARGV[0]
when "jemoji"
  Profiler.report do
    Jekyll.logger.info "Profiling..."
    Jekyll.logger.info "Emojify via plugin jemoji"
    require "html/pipeline"
    "".match?(HTML::Pipeline::EmojiFilter.emoji_pattern)
    nil
  end
else
  Profiler.report do
    site = Jekyll::Site.new(Jekyll.configuration)
    Jekyll.logger.info "Source:", site.source
    Jekyll.logger.info "Destination:", site.dest
    Jekyll.logger.info "Profiling..."
    site.process
  end
end
