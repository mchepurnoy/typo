# Never store typed text; network only for updates

typo sees every keystroke, so its privacy promise is the product. Typed text lives only in memory for the current word and is never written to disk or logs; on disk we keep settings, exceptions and learned words only (the last two are words the user chose to keep, by reverting or converting them, and can review and remove in settings). There is no telemetry, and the only network traffic is the Sparkle update check. Crash reporting, analytics or cloud AI would each need a new decision that supersedes this one.
