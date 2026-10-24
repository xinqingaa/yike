const focusHalfHourSeconds = 1800;
const focusNinetyMinuteSeconds = 5400;

/// 0 none, 1 up to 30 minutes, 2 up to 90 minutes, 3 longer.
int focusDurationLevel(num seconds) => seconds <= 0
    ? 0
    : seconds <= focusHalfHourSeconds
    ? 1
    : seconds <= focusNinetyMinuteSeconds
    ? 2
    : 3;

/// One real duration in each bucket: none, 30 minutes, 90 minutes, 3 hours.
const focusDurationLegendSeconds = <double>[0, 1800, 5400, 3 * 3600];
