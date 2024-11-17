defmodule Obanalyze.Hooks do
  import Phoenix.Component

  alias Phoenix.LiveDashboard.PageBuilder

  def on_mount(:default, _params, _session, socket) do
    {:cont, PageBuilder.register_after_opening_head_tag(socket, &after_opening_head_tag/1)}
  end

  defp after_opening_head_tag(assigns) do
    ~H"""
    <script nonce={@csp_nonces[:script]}>
      window.LiveDashboard.registerCustomHooks({
        Relativize: {
          mounted() {
            // Check if Intl.RelativeTimeFormat is supported
            if (!("Intl" in window && "RelativeTimeFormat" in Intl)) {
              return;
            }

            // Set an interval to update the innerHTML every second
            this.updateRelativeTime();
            this.interval = setInterval(() => this.updateRelativeTime(), 1000);
          },

          destroyed() {
            // Clear the interval when the hook is destroyed to avoid memory leaks
            clearInterval(this.interval);
          },

          updateRelativeTime() {
            // Update the innerHTML with the latest relative time
            this.el.textContent = this.getRelativeTimeString(this.el.dataset.timestamp, this.el.dataset.language);
          },

          getRelativeTimeString(unixTimestamp, lang, relativeMode) {
            // Default to user's language if not provided
            lang = lang || navigator.language;

            // Convert the Unix timestamp (in seconds) to milliseconds
            const timeMs = unixTimestamp * 1000;

            // Calculate the difference in seconds between the given timestamp and now
            const deltaSeconds = Math.round((timeMs - Date.now()) / 1000);

            // Time intervals in seconds for each unit: minute, hour, day, week, month, and year
            const cutoffs = [60, 3600, 86400, 86400 * 7, 86400 * 30, 86400 * 365, Infinity];

            // Corresponding units for each interval
            const units = ["second", "minute", "hour", "day", "week", "month", "year"];

            // Find the best-fitting time unit
            const unitIndex = cutoffs.findIndex(function(cutoff) {
              return cutoff > Math.abs(deltaSeconds);
            });

            // Get the divisor for the appropriate unit
            const divisor = unitIndex ? cutoffs[unitIndex - 1] : 1;

            // Calculate the relative time value
            const relativeValue = Math.floor(deltaSeconds / divisor);

            // Format the relative time string
            const rtf = new Intl.RelativeTimeFormat(lang, { numeric: "auto" });
            let formattedString = rtf.format(relativeValue, units[unitIndex]);

            return formattedString;
          }
        }
      });
    </script>
    """
  end
end
